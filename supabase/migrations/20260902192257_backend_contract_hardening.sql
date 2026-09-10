-- Close the remaining contract gaps found by executable local verification.

-- A later least-privilege sweep revoked helpers used by authenticated RLS and
-- event wrappers. Restore only the exact execution paths clients require.
grant execute on function private.current_workspace_id() to authenticated;
grant execute on function private.event_in_current_workspace(uuid) to authenticated;
grant execute on function private.booking_in_current_workspace(uuid) to authenticated;
grant execute on function private.list_events_impl(timestamptz, uuid, integer) to authenticated;
grant execute on function private.get_event_impl(uuid) to authenticated;
grant execute on function private.upsert_event_draft_impl(uuid, uuid, jsonb) to authenticated;
grant execute on function private.terminate_event_impl(
  uuid, public.event_status, text, uuid
) to authenticated;
grant execute on function private.resolve_event_impl(text) to service_role;
grant execute on function private.consume_rate_limit_impl(text, text, integer, integer)
to service_role;
grant execute on function private.create_booking_impl(text, text, text, text, jsonb)
to service_role;
grant execute on function private.verify_donor_booking_impl(text, text) to service_role;
grant execute on function private.donor_booking_status_impl(uuid) to service_role;
grant execute on function private.resolve_qr_impl(uuid, text) to service_role;
grant execute on function private.delete_donor_data_impl(uuid, uuid, uuid) to service_role;
grant execute on function private.export_report_rows_impl(uuid, uuid, timestamptz, timestamptz)
to service_role;

create or replace function private.guard_booking_snapshot_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.event_snapshot is distinct from old.event_snapshot
    or new.snapshot_schema_version is distinct from old.snapshot_schema_version
    or new.event_id is distinct from old.event_id
    or new.workspace_id is distinct from old.workspace_id
  then
    raise exception using errcode = 'P0001', message = 'BOOKING_SNAPSHOT_IMMUTABLE';
  end if;
  return new;
end;
$$;

revoke execute on function private.guard_booking_snapshot_update()
from public, anon, authenticated;

create trigger bookings_guard_snapshot_update
before update on public.bookings
for each row execute function private.guard_booking_snapshot_update();

-- Public event context includes the exact active consent versions for the
-- invocation environment, so an App Clip never hardcodes legal metadata.
create or replace function private.resolve_event_impl(p_token_hash text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.events;
  v_invocation public.event_invocations;
  v_environment public.deployment_environment;
  v_availability text;
  v_legal jsonb;
begin
  select i.* into v_invocation
  from public.event_invocations as i
  where i.token_hash = p_token_hash and i.revoked_at is null;
  if not found then
    raise exception using errcode = 'P0002', message = 'INVOCATION_INVALID';
  end if;
  v_environment := v_invocation.environment;
  select e.* into v_event
  from public.events as e
  where e.id = v_invocation.event_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'INVOCATION_INVALID';
  end if;
  perform private.reconcile_events(v_event.workspace_id);
  select e.* into v_event from public.events as e where e.id = v_event.id;
  v_availability := case
    when v_event.status = 'upcoming' then 'available_upcoming'
    when v_event.status = 'ongoing' and v_event.received_weight_grams < v_event.capacity_grams
      then 'available'
    when v_event.status = 'ongoing' then 'full'
    when v_event.status = 'completed' then 'completed'
    when v_event.status = 'closed' then 'closed'
    when v_event.status = 'cancelled' then 'cancelled'
    else 'unavailable'
  end;
  select jsonb_build_object(
    'terms_version', max(l.version_identifier) filter (where l.document_type = 'terms'),
    'terms_url', max(l.public_url) filter (where l.document_type = 'terms'),
    'privacy_version', max(l.version_identifier) filter (where l.document_type = 'privacy'),
    'privacy_url', max(l.public_url) filter (where l.document_type = 'privacy')
  ) into v_legal
  from public.legal_document_versions as l
  where l.environment = v_environment and l.is_active;
  return jsonb_build_object(
    'event', private.public_event_json(v_event, v_availability),
    'legal', v_legal,
    'server_time', now(),
    'cache_max_age_seconds', 60
  );
end;
$$;

-- Publishing is an Edge Function boundary. The public Data API wrapper is
-- service-role-only and derives the workspace from the verified actor ID.
drop function api.publish_event_v1(
  uuid, text, text, text, smallint, public.deployment_environment, uuid
);
drop function private.publish_event_impl(
  uuid, text, text, text, smallint, public.deployment_environment, uuid
);

create or replace function private.publish_event_impl(
  p_actor_id uuid,
  p_event_id uuid,
  p_token_hash text,
  p_token_ciphertext text,
  p_token_nonce text,
  p_crypto_key_version smallint,
  p_environment public.deployment_environment,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid;
  v_event public.events;
  v_invocation public.event_invocations;
  v_active_count integer;
begin
  if p_actor_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  select w.id into v_workspace_id
  from public.workspaces as w
  where w.owner_user_id = p_actor_id and w.status = 'active';
  if v_workspace_id is null then
    raise exception using errcode = '42501', message = 'WORKSPACE_UNAVAILABLE';
  end if;

  perform 1 from public.workspaces where id = v_workspace_id for update;
  perform private.reconcile_events(v_workspace_id);
  select e.* into v_event from public.events as e
  where e.id = p_event_id and e.workspace_id = v_workspace_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND';
  end if;
  if v_event.status in ('upcoming', 'ongoing') then
    select i.* into v_invocation from public.event_invocations as i
    where i.event_id = v_event.id and i.environment = p_environment and i.revoked_at is null;
    if found then
      return jsonb_build_object(
        'event', private.event_to_json(v_event),
        'invocation_ciphertext', v_invocation.token_ciphertext,
        'invocation_nonce', v_invocation.token_nonce,
        'crypto_key_version', v_invocation.crypto_key_version
      );
    end if;
  end if;
  if v_event.status <> 'draft' then
    raise exception using errcode = 'P0001', message = 'EVENT_NOT_PUBLISHABLE';
  end if;
  if v_event.name is null or v_event.description is null or v_event.banner_object_path is null
    or v_event.start_at is null or v_event.end_at is null or v_event.end_at <= now()
    or v_event.timezone_name not in ('Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura')
    or v_event.operational_days is null or v_event.opens_at_local is null
    or v_event.closes_at_local is null or v_event.location_name is null
    or v_event.location_address is null or v_event.location_country_code is distinct from 'ID'
    or v_event.latitude is null or v_event.longitude is null or v_event.capacity_grams is null
    or v_event.receiver_name is null or v_event.receiver_phone is null
    or v_event.receiver_address is null
    or not exists (select 1 from public.event_criteria where event_id = v_event.id)
  then
    raise exception using errcode = '23514', message = 'EVENT_PUBLISH_FIELDS_REQUIRED';
  end if;
  select count(*) into v_active_count from public.events as e
  where e.workspace_id = v_workspace_id and e.status in ('upcoming', 'ongoing');
  if v_active_count >= 5 then
    raise exception using errcode = '23514', message = 'ACTIVE_EVENT_LIMIT';
  end if;
  update public.events as e set
    status = case
      when e.start_at <= now() then 'ongoing'::public.event_status
      else 'upcoming'::public.event_status
    end,
    published_at = coalesce(e.published_at, now()),
    version = e.version + 1
  where e.id = v_event.id returning * into v_event;
  insert into public.event_invocations (
    event_id, token_hash, token_ciphertext, token_nonce, crypto_key_version, environment
  ) values (
    v_event.id, p_token_hash, p_token_ciphertext, p_token_nonce,
    p_crypto_key_version, p_environment
  )
  on conflict (event_id, environment) do update set
    token_hash = excluded.token_hash,
    token_ciphertext = excluded.token_ciphertext,
    token_nonce = excluded.token_nonce,
    crypto_key_version = excluded.crypto_key_version,
    revoked_at = null,
    created_at = now()
  returning * into v_invocation;
  insert into public.audit_events (
    actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id
  ) values (
    'organizer', p_actor_id::text, v_workspace_id, 'event', v_event.id,
    'event.published', p_request_id
  );
  return jsonb_build_object(
    'event', private.event_to_json(v_event),
    'invocation_ciphertext', v_invocation.token_ciphertext,
    'invocation_nonce', v_invocation.token_nonce,
    'crypto_key_version', v_invocation.crypto_key_version
  );
end;
$$;

create or replace function api.publish_event_v1(
  p_actor_id uuid,
  p_event_id uuid,
  p_token_hash text,
  p_token_ciphertext text,
  p_token_nonce text,
  p_crypto_key_version smallint,
  p_environment public.deployment_environment,
  p_request_id uuid
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.publish_event_impl(
    p_actor_id, p_event_id, p_token_hash, p_token_ciphertext, p_token_nonce,
    p_crypto_key_version, p_environment, p_request_id
  )
$$;

revoke execute on function private.publish_event_impl(
  uuid, uuid, text, text, text, smallint, public.deployment_environment, uuid
) from public, anon, authenticated;
revoke execute on function api.publish_event_v1(
  uuid, uuid, text, text, text, smallint, public.deployment_environment, uuid
) from public, anon, authenticated;
grant execute on function private.publish_event_impl(
  uuid, uuid, text, text, text, smallint, public.deployment_environment, uuid
) to service_role;
grant execute on function api.publish_event_v1(
  uuid, uuid, text, text, text, smallint, public.deployment_environment, uuid
) to service_role;

-- Claim reception idempotency before locking domain rows. A concurrent replay
-- waits for the first transaction and receives its original response.
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
  )::text, 'UTF8'), 'sha256'), 'hex');
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
    v_booking.id, v_workspace_id, v_event.id, p_decision, p_actual_weight_grams,
    p_condition,
    case when p_decision = 'rejected' then p_rejection_reason end,
    case when p_decision = 'rejected' then nullif(trim(p_rejection_note), '') end,
    v_actor_id
  );
  update public.bookings set
    status = p_decision::text::public.booking_status,
    terminal_at = now(),
    terminal_reason_code = coalesce(p_rejection_reason::text, p_decision::text)
  where id = v_booking.id returning * into v_booking;
  if p_decision = 'accepted' then
    update public.events as e set
      received_weight_grams = e.received_weight_grams + p_actual_weight_grams,
      version = e.version + 1
    where e.id = v_event.id returning * into v_event;
    if v_event.received_weight_grams = v_event.capacity_grams then
      update public.bookings set
        status = 'cancelled',
        terminal_at = now(),
        terminal_reason_code = 'event_full'
      where event_id = v_event.id and status = 'waiting';
    end if;
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
