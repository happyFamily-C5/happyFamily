-- `bookings_terminal_timestamp` and `events_capacity` were reworked
-- (20260908181836): `accepted`/`processed` are in-progress tracking states
-- (terminal_at NULL), and the event ledger now tracks
-- received_weight_grams + reserved_weight_grams <= capacity_grams, where
-- reserved_weight_grams is the sum of estimates over waiting bookings.
-- The v1 reception decision impl still used the legacy model (terminal_at
-- on every decision, received-only capacity math), which now violates both
-- constraints. Align it: acceptance leaves the booking in-progress so the
-- organizer can advance it (accepted -> processed -> recycled), releases
-- the accepted booking's reservation, and cancels remaining waiting
-- bookings (releasing their reservations) when capacity fills exactly.

create or replace function private.decide_reception_impl(
  p_booking_id uuid,
  p_decision public.reception_decision,
  p_actual_weight_grams bigint,
  p_condition public.item_condition,
  p_rejection_reason public.rejection_reason,
  p_rejection_note text,
  p_idempotency_key text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid := private.require_workspace();
  v_actor_id uuid := (select auth.uid());
  v_booking public.bookings;
  v_event public.events;
  v_existing public.idempotency_keys;
  v_claimed integer := 0;
  v_hash text;
  v_response jsonb;
  v_unique_delta integer := 0;
begin
  v_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'booking_id', p_booking_id,
    'decision', p_decision,
    'actual_weight_grams', p_actual_weight_grams,
    'condition', p_condition,
    'rejection_reason', p_rejection_reason,
    'rejection_note', p_rejection_note
  )::text, 'UTF-8'), 'sha256'), 'hex');
  insert into public.idempotency_keys (
    scope, actor_scope, key, request_hash, resource_type, resource_id
  ) values (
    'reception', v_actor_id::text, p_idempotency_key, v_hash, 'booking', p_booking_id
  ) on conflict (scope, actor_scope, key) do nothing;
  get diagnostics v_claimed = row_count;
  if v_claimed = 0 then
    select i.* into v_existing from public.idempotency_keys as i
    where i.scope = 'reception' and i.actor_scope = v_actor_id::text
      and i.key = p_idempotency_key
    for update;
    if v_existing.request_hash <> v_hash then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_CONFLICT';
    end if;
    if v_existing.response_payload is null then
      raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_INCOMPLETE';
    end if;
    return v_existing.response_payload;
  end if;

  perform private.reconcile_events(v_workspace_id);
  select b.* into v_booking from public.bookings as b
  where b.id = p_booking_id and b.workspace_id = v_workspace_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'BOOKING_NOT_FOUND';
  end if;
  select e.* into v_event from public.events as e
  where e.id = v_booking.event_id for update;
  if v_booking.status <> 'waiting' or v_booking.expires_at <= now() then
    raise exception using errcode = 'P0001', message = 'BOOKING_NOT_PROCESSABLE';
  end if;
  if v_event.status <> 'ongoing' or v_event.start_at > now() or v_event.end_at <= now() then
    raise exception using errcode = 'P0001', message = 'EVENT_NOT_OPERATIONAL';
  end if;
  if p_actual_weight_grams <= 0 then
    raise exception using errcode = '23514', message = 'INVALID_ACTUAL_WEIGHT';
  end if;
  if p_decision = 'accepted' then
    if p_rejection_reason is not null or p_rejection_note is not null then
      raise exception using errcode = '23514', message = 'INVALID_ACCEPTANCE';
    end if;
    if v_event.received_weight_grams + p_actual_weight_grams > v_event.capacity_grams then
      raise exception using errcode = '23514', message = 'CAPACITY_EXCEEDED';
    end if;
    if not exists (
      select 1 from public.bookings as prior
      where prior.event_id = v_event.id and prior.status = 'accepted'
        and prior.phone_lookup_hash = v_booking.phone_lookup_hash
    ) then
      v_unique_delta := 1;
    end if;
  end if;
  insert into public.receptions (
    booking_id, workspace_id, event_id, decision, actual_weight_grams,
    condition, rejection_reason, rejection_note, processed_by
  ) values (
    v_booking.id, v_workspace_id, v_event.id, p_decision,
    case when p_decision = 'accepted' then p_actual_weight_grams end,
    case when p_decision = 'accepted' then p_condition end,
    null,
    null,
    v_actor_id
  );
  update public.bookings set
    status = p_decision::text::public.booking_status,
    status_updated_at = now(),
    terminal_at = case when p_decision = 'accepted' then null else now() end,
    terminal_reason_code = case when p_decision = 'accepted'
      then null else coalesce(p_rejection_reason::text, p_decision::text) end
  where id = v_booking.id returning * into v_booking;
  if p_decision = 'accepted' then
    -- Exact-capacity fill cancels every remaining waiting booking and
    -- releases their reservations in the same logical step, keeping
    -- received + reserved <= capacity true at statement boundaries.
    if v_event.received_weight_grams + p_actual_weight_grams = v_event.capacity_grams then
      update public.bookings set
        status = 'cancelled',
        status_updated_at = now(),
        terminal_at = now(),
        terminal_reason_code = 'event_full'
      where event_id = v_event.id and status = 'waiting';
    end if;
    update public.events as e set
      received_weight_grams = e.received_weight_grams + p_actual_weight_grams,
      reserved_weight_grams = coalesce((
        select sum(b.estimated_weight_grams)
        from public.bookings as b
        where b.event_id = e.id and b.status = 'waiting'
      ), 0),
      version = e.version + 1
    where e.id = v_event.id returning * into v_event;
  else
    -- Rejected bookings release their reservation immediately.
    update public.events as e set
      reserved_weight_grams = coalesce((
        select sum(b.estimated_weight_grams)
        from public.bookings as b
        where b.event_id = e.id and b.status = 'waiting'
      ), 0),
      version = e.version + 1
    where e.id = v_event.id returning * into v_event;
  end if;
  insert into public.impact_aggregates (
    workspace_id, event_id, period_start, total_accepted_weight_grams,
    accepted_booking_count, rejected_booking_count, unique_donor_count
  ) values (
    v_workspace_id,
    v_event.id,
    date_trunc('month', now())::date,
    case when p_decision = 'accepted' then p_actual_weight_grams else 0 end,
    case when p_decision = 'accepted' then 1 else 0 end,
    case when p_decision = 'rejected' then 1 else 0 end,
    v_unique_delta
  ) on conflict (workspace_id, event_id, period_start) do update set
    total_accepted_weight_grams = public.impact_aggregates.total_accepted_weight_grams
      + excluded.total_accepted_weight_grams,
    accepted_booking_count = public.impact_aggregates.accepted_booking_count
      + excluded.accepted_booking_count,
    rejected_booking_count = public.impact_aggregates.rejected_booking_count
      + excluded.rejected_booking_count,
    unique_donor_count = public.impact_aggregates.unique_donor_count
      + excluded.unique_donor_count;
  v_response := jsonb_build_object(
    'booking_id', v_booking.id,
    'public_booking_id', v_booking.public_booking_id,
    'status', v_booking.status,
    'received_weight_grams', v_event.received_weight_grams,
    'capacity_grams', v_event.capacity_grams,
    'capacity_full', v_event.received_weight_grams = v_event.capacity_grams
  );
  update public.idempotency_keys
  set response_payload = v_response
  where scope = 'reception' and actor_scope = v_actor_id::text
    and key = p_idempotency_key;
  insert into public.audit_events (
    actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id
  ) values (
    'organizer', v_actor_id::text, v_workspace_id, 'booking', v_booking.id,
    'booking.' || p_decision::text, p_request_id
  );
  return v_response;
end;
$$;
