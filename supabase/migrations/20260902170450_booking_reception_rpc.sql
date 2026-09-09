-- Public booking, donor lookup, QR, reception, capacity, recap, and deletion.

create or replace function private.public_event_json(p_event public.events, p_availability text)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_event.id,
    'name', p_event.name,
    'description', p_event.description,
    'status', p_event.status,
    'availability', p_availability,
    'start_at', p_event.start_at,
    'end_at', p_event.end_at,
    'timezone_name', p_event.timezone_name,
    'operational_days', p_event.operational_days,
    'opens_at_local', p_event.opens_at_local,
    'closes_at_local', p_event.closes_at_local,
    'location_name', p_event.location_name,
    'location_address', p_event.location_address,
    'latitude', p_event.latitude,
    'longitude', p_event.longitude,
    'capacity_grams', p_event.capacity_grams,
    'received_weight_grams', p_event.received_weight_grams,
    'banner_object_path', p_event.banner_object_path,
    'receiver_name', p_event.receiver_name,
    'receiver_phone', p_event.receiver_phone,
    'receiver_address', p_event.receiver_address,
    'criteria', coalesce((
      select jsonb_agg(ec.criterion order by ec.criterion)
      from public.event_criteria as ec where ec.event_id = p_event.id
    ), '[]'::jsonb),
    'version', p_event.version
  )
$$;

create or replace function private.resolve_event_impl(p_token_hash text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.events;
  v_availability text;
begin
  select e.* into v_event
  from public.event_invocations as i
  join public.events as e on e.id = i.event_id
  where i.token_hash = p_token_hash and i.revoked_at is null;
  if not found then
    raise exception using errcode = 'P0002', message = 'INVOCATION_INVALID';
  end if;
  perform private.reconcile_events(v_event.workspace_id);
  select e.* into v_event from public.events as e where e.id = v_event.id;
  v_availability := case
    when v_event.status = 'upcoming' then 'available_upcoming'
    when v_event.status = 'ongoing' and v_event.received_weight_grams < v_event.capacity_grams then 'available'
    when v_event.status = 'ongoing' then 'full'
    when v_event.status = 'completed' then 'completed'
    when v_event.status = 'closed' then 'closed'
    when v_event.status = 'cancelled' then 'cancelled'
    else 'unavailable'
  end;
  return jsonb_build_object(
    'event', private.public_event_json(v_event, v_availability),
    'server_time', now(),
    'cache_max_age_seconds', 60
  );
end;
$$;

create or replace function private.consume_rate_limit_impl(
  p_endpoint text,
  p_fingerprint_hash text,
  p_window_seconds integer,
  p_max_requests integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window_start timestamptz;
  v_count integer;
begin
  if p_window_seconds <= 0 or p_max_requests <= 0
    or char_length(p_fingerprint_hash) < 32 then
    raise exception using errcode = '22023', message = 'INVALID_RATE_LIMIT';
  end if;
  v_window_start := to_timestamp(
    floor(extract(epoch from clock_timestamp()) / p_window_seconds) * p_window_seconds
  );
  insert into public.rate_limit_buckets (
    endpoint, fingerprint_hash, window_started_at, request_count, expires_at
  ) values (
    p_endpoint, p_fingerprint_hash, v_window_start, 1,
    v_window_start + make_interval(secs => p_window_seconds * 2)
  )
  on conflict (endpoint, fingerprint_hash, window_started_at) do update
  set request_count = public.rate_limit_buckets.request_count + 1
  returning request_count into v_count;
  return jsonb_build_object(
    'allowed', v_count <= p_max_requests,
    'remaining', greatest(0, p_max_requests - v_count),
    'reset_at', v_window_start + make_interval(secs => p_window_seconds)
  );
end;
$$;

create or replace function private.create_booking_impl(
  p_invocation_token_hash text,
  p_actor_scope text,
  p_idempotency_key text,
  p_request_hash text,
  p_booking jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.events;
  v_invocation public.event_invocations;
  v_environment public.deployment_environment;
  v_booking public.bookings;
  v_existing public.idempotency_keys;
  v_claimed integer := 0;
  v_snapshot jsonb;
  v_expiry timestamptz;
  v_item jsonb;
  v_item_count integer;
begin
  if jsonb_typeof(p_booking) <> 'object' or jsonb_typeof(p_booking -> 'items') <> 'array' then
    raise exception using errcode = '22023', message = 'INVALID_REQUEST';
  end if;
  v_item_count := jsonb_array_length(p_booking -> 'items');
  if v_item_count < 1 or v_item_count > 100
    or v_item_count <> (p_booking ->> 'item_count')::integer then
    raise exception using errcode = '23514', message = 'INVALID_ITEMS';
  end if;

  insert into public.idempotency_keys (
    scope, actor_scope, key, request_hash, resource_type
  ) values ('create-booking', p_actor_scope, p_idempotency_key, p_request_hash, 'booking')
  on conflict (scope, actor_scope, key) do nothing;
  get diagnostics v_claimed = row_count;
  if v_claimed = 0 then
    select i.* into v_existing from public.idempotency_keys as i
    where i.scope = 'create-booking' and i.actor_scope = p_actor_scope
      and i.key = p_idempotency_key for update;
    if v_existing.request_hash <> p_request_hash then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_CONFLICT';
    end if;
    if v_existing.resource_id is not null then
      select b.* into v_booking from public.bookings as b where b.id = v_existing.resource_id;
      return jsonb_build_object(
        'booking_id', v_booking.id,
        'public_booking_id', v_booking.public_booking_id,
        'status', v_booking.status,
        'expires_at', v_booking.expires_at,
        'event_snapshot', v_booking.event_snapshot,
        'qr_token_ciphertext', v_booking.qr_token_ciphertext,
        'qr_token_nonce', v_booking.qr_token_nonce,
        'crypto_key_version', v_booking.crypto_key_version,
        'idempotent_replay', true
      );
    end if;
  end if;

  select i.* into v_invocation
  from public.event_invocations as i
  where i.token_hash = p_invocation_token_hash and i.revoked_at is null
  for share;
  if not found then raise exception using errcode = 'P0002', message = 'INVOCATION_INVALID'; end if;
  v_environment := v_invocation.environment;
  select e.* into v_event
  from public.events as e
  where e.id = v_invocation.event_id
  for update;
  if not found then raise exception using errcode = 'P0002', message = 'INVOCATION_INVALID'; end if;
  perform private.reconcile_events(v_event.workspace_id);
  select e.* into v_event from public.events as e where e.id = v_event.id for update;
  if v_event.status not in ('upcoming', 'ongoing') or v_event.end_at <= now() then
    raise exception using errcode = 'P0001', message = 'EVENT_UNAVAILABLE';
  end if;
  if v_event.received_weight_grams >= v_event.capacity_grams then
    raise exception using errcode = '23514', message = 'EVENT_FULL';
  end if;
  if not exists (
    select 1 from public.legal_document_versions as l
    where l.document_type = 'terms' and l.environment = v_environment and l.is_active
      and l.version_identifier = p_booking ->> 'terms_version'
  ) or not exists (
    select 1 from public.legal_document_versions as l
    where l.document_type = 'privacy' and l.environment = v_environment and l.is_active
      and l.version_identifier = p_booking ->> 'privacy_version'
  ) then
    raise exception using errcode = '23514', message = 'CONSENT_VERSION_INVALID';
  end if;

  v_expiry := least(now() + interval '12 hours', v_event.end_at);
  v_snapshot := private.public_event_json(v_event, 'available') ||
    jsonb_build_object('schema_version', 1, 'captured_at', now());
  insert into public.bookings (
    public_booking_id, event_id, workspace_id,
    donor_name_ciphertext, donor_name_nonce, donor_phone_ciphertext,
    donor_phone_nonce, phone_lookup_hash, crypto_key_version,
    estimated_weight_grams, item_count, shipping_method, scan_model_version,
    event_snapshot, qr_token_hash, qr_token_ciphertext, qr_token_nonce,
    terms_version, privacy_version, consented_at, expires_at
  ) values (
    p_booking ->> 'public_booking_id', v_event.id, v_event.workspace_id,
    p_booking ->> 'donor_name_ciphertext', p_booking ->> 'donor_name_nonce',
    p_booking ->> 'donor_phone_ciphertext', p_booking ->> 'donor_phone_nonce',
    p_booking ->> 'phone_lookup_hash', (p_booking ->> 'crypto_key_version')::smallint,
    (p_booking ->> 'estimated_weight_grams')::bigint, v_item_count,
    (p_booking ->> 'shipping_method')::public.shipping_method,
    p_booking ->> 'scan_model_version', v_snapshot,
    p_booking ->> 'qr_token_hash', p_booking ->> 'qr_token_ciphertext',
    p_booking ->> 'qr_token_nonce', p_booking ->> 'terms_version',
    p_booking ->> 'privacy_version', now(), v_expiry
  ) returning * into v_booking;

  for v_item in select value from jsonb_array_elements(p_booking -> 'items') loop
    if coalesce((v_item ->> 'passed')::boolean, false) is not true then
      raise exception using errcode = '23514', message = 'ITEM_NOT_PASSED';
    end if;
    insert into public.booking_items (
      booking_id, ordinal, passed, scanner_model_version, metadata
    ) values (
      v_booking.id, (v_item ->> 'ordinal')::smallint, true,
      v_item ->> 'scanner_model_version', coalesce(v_item -> 'metadata', '{}'::jsonb)
    );
  end loop;
  update public.idempotency_keys set resource_id = v_booking.id,
    response_payload = jsonb_build_object('public_booking_id', v_booking.public_booking_id)
  where scope = 'create-booking' and actor_scope = p_actor_scope and key = p_idempotency_key;
  insert into public.audit_events (
    actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id
  ) values ('donor', p_actor_scope, v_event.workspace_id, 'booking', v_booking.id,
    'booking.created', coalesce((p_booking ->> 'request_id')::uuid, gen_random_uuid()));
  return jsonb_build_object(
    'booking_id', v_booking.id,
    'public_booking_id', v_booking.public_booking_id,
    'status', v_booking.status,
    'expires_at', v_booking.expires_at,
    'event_snapshot', v_booking.event_snapshot,
    'qr_token_ciphertext', v_booking.qr_token_ciphertext,
    'qr_token_nonce', v_booking.qr_token_nonce,
    'crypto_key_version', v_booking.crypto_key_version,
    'idempotent_replay', false
  );
end;
$$;

create or replace function private.verify_donor_booking_impl(
  p_public_booking_id text,
  p_phone_lookup_hash text
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select b.id from public.bookings as b
  where b.public_booking_id = upper(p_public_booking_id)
    and b.phone_lookup_hash = p_phone_lookup_hash
    and b.pii_deleted_at is null
    and exists (
      select 1 from public.events as e where e.id = b.event_id
        and (e.terminal_at is null or e.terminal_at > now() - interval '30 days')
    )
  limit 1
$$;

create or replace function private.donor_booking_status_impl(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_reception public.receptions;
begin
  select b.* into v_booking from public.bookings as b
  where b.id = p_booking_id and b.pii_deleted_at is null;
  if not found then raise exception using errcode = 'P0002', message = 'BOOKING_UNAVAILABLE'; end if;
  select r.* into v_reception from public.receptions as r where r.booking_id = v_booking.id;
  return jsonb_build_object(
    'public_booking_id', v_booking.public_booking_id,
    'status', v_booking.status,
    'event', v_booking.event_snapshot,
    'expires_at', v_booking.expires_at,
    'processed_at', v_reception.processed_at,
    'condition', v_reception.condition,
    'rejection_reason', v_reception.rejection_reason
  );
end;
$$;

create or replace function private.resolve_qr_impl(p_actor_id uuid, p_qr_token_hash text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
begin
  select b.* into v_booking from public.bookings as b
  join public.workspaces as w on w.id = b.workspace_id
  where b.qr_token_hash = p_qr_token_hash and b.pii_deleted_at is null
    and w.owner_user_id = p_actor_id and w.status = 'active';
  if not found then raise exception using errcode = 'P0002', message = 'QR_INVALID'; end if;
  if v_booking.status <> 'waiting' or v_booking.expires_at <= now() then
    raise exception using errcode = 'P0001', message = 'BOOKING_NOT_PROCESSABLE';
  end if;
  return jsonb_build_object(
    'booking_id', v_booking.id,
    'public_booking_id', v_booking.public_booking_id,
    'status', v_booking.status,
    'estimated_weight_grams', v_booking.estimated_weight_grams,
    'item_count', v_booking.item_count,
    'shipping_method', v_booking.shipping_method,
    'event_snapshot', v_booking.event_snapshot,
    'donor_name_ciphertext', v_booking.donor_name_ciphertext,
    'donor_name_nonce', v_booking.donor_name_nonce,
    'donor_phone_ciphertext', v_booking.donor_phone_ciphertext,
    'donor_phone_nonce', v_booking.donor_phone_nonce,
    'crypto_key_version', v_booking.crypto_key_version
  );
end;
$$;

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
  v_hash text;
  v_response jsonb;
  v_unique_delta integer := 0;
begin
  v_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'booking_id', p_booking_id, 'decision', p_decision,
    'actual_weight_grams', p_actual_weight_grams, 'condition', p_condition,
    'rejection_reason', p_rejection_reason, 'rejection_note', p_rejection_note
  )::text, 'UTF8'), 'sha256'), 'hex');
  select i.* into v_existing from public.idempotency_keys as i
  where i.scope = 'reception' and i.actor_scope = v_actor_id::text
    and i.key = p_idempotency_key for update;
  if found then
    if v_existing.request_hash <> v_hash then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_CONFLICT';
    end if;
    return v_existing.response_payload;
  end if;
  perform private.reconcile_events(v_workspace_id);
  select b.* into v_booking from public.bookings as b
  where b.id = p_booking_id and b.workspace_id = v_workspace_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'BOOKING_NOT_FOUND'; end if;
  select e.* into v_event from public.events as e where e.id = v_booking.event_id for update;
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
    ) then v_unique_delta := 1; end if;
  end if;
  insert into public.receptions (
    booking_id, workspace_id, event_id, decision, actual_weight_grams,
    condition, rejection_reason, rejection_note, processed_by
  ) values (
    v_booking.id, v_workspace_id, v_event.id, p_decision, p_actual_weight_grams,
    p_condition, case when p_decision = 'rejected' then p_rejection_reason end,
    case when p_decision = 'rejected' then nullif(trim(p_rejection_note), '') end,
    v_actor_id
  );
  update public.bookings set status = p_decision::text::public.booking_status,
    terminal_at = now(), terminal_reason_code = coalesce(p_rejection_reason::text, p_decision::text)
  where id = v_booking.id returning * into v_booking;
  if p_decision = 'accepted' then
    update public.events as e set received_weight_grams = e.received_weight_grams + p_actual_weight_grams,
      version = e.version + 1 where e.id = v_event.id returning * into v_event;
    if v_event.received_weight_grams = v_event.capacity_grams then
      update public.bookings set status = 'cancelled', terminal_at = now(),
        terminal_reason_code = 'event_full'
      where event_id = v_event.id and status = 'waiting';
    end if;
  end if;
  insert into public.impact_aggregates (
    workspace_id, event_id, period_start, total_accepted_weight_grams,
    accepted_booking_count, rejected_booking_count, unique_donor_count
  ) values (
    v_workspace_id, v_event.id, date_trunc('month', now())::date,
    case when p_decision = 'accepted' then p_actual_weight_grams else 0 end,
    case when p_decision = 'accepted' then 1 else 0 end,
    case when p_decision = 'rejected' then 1 else 0 end,
    v_unique_delta
  ) on conflict (workspace_id, event_id, period_start) do update set
    total_accepted_weight_grams = public.impact_aggregates.total_accepted_weight_grams + excluded.total_accepted_weight_grams,
    accepted_booking_count = public.impact_aggregates.accepted_booking_count + excluded.accepted_booking_count,
    rejected_booking_count = public.impact_aggregates.rejected_booking_count + excluded.rejected_booking_count,
    unique_donor_count = public.impact_aggregates.unique_donor_count + excluded.unique_donor_count;
  v_response := jsonb_build_object(
    'booking_id', v_booking.id, 'public_booking_id', v_booking.public_booking_id,
    'status', v_booking.status, 'received_weight_grams', v_event.received_weight_grams,
    'capacity_grams', v_event.capacity_grams,
    'capacity_full', v_event.received_weight_grams = v_event.capacity_grams
  );
  insert into public.idempotency_keys (
    scope, actor_scope, key, request_hash, resource_type, resource_id, response_payload
  ) values ('reception', v_actor_id::text, p_idempotency_key, v_hash,
    'booking', v_booking.id, v_response);
  insert into public.audit_events (
    actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id
  ) values ('organizer', v_actor_id::text, v_workspace_id, 'booking', v_booking.id,
    'booking.' || p_decision::text, p_request_id);
  return v_response;
end;
$$;

create or replace function private.recap_impl(p_event_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid := private.require_workspace();
  v_result jsonb;
begin
  select jsonb_build_object(
    'total_accepted_weight_grams', coalesce(sum(a.total_accepted_weight_grams), 0),
    'accepted_booking_count', coalesce(sum(a.accepted_booking_count), 0),
    'rejected_booking_count', coalesce(sum(a.rejected_booking_count), 0),
    'unique_donor_count', coalesce(sum(a.unique_donor_count), 0),
    'completed_event_count', coalesce(sum(a.completed_event_count), 0)
  ) into v_result from public.impact_aggregates as a
  where a.workspace_id = v_workspace_id and (p_event_id is null or a.event_id = p_event_id);
  return v_result;
end;
$$;

create or replace function private.delete_donor_data_impl(
  p_actor_id uuid, p_booking_id uuid, p_request_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid;
begin
  select w.id into v_workspace_id from public.workspaces as w
  join public.bookings as b on b.workspace_id = w.id
  where w.owner_user_id = p_actor_id and w.status = 'active' and b.id = p_booking_id;
  if not found then raise exception using errcode = 'P0002', message = 'BOOKING_NOT_FOUND'; end if;
  update public.bookings set donor_name_ciphertext = null, donor_name_nonce = null,
    donor_phone_ciphertext = null, donor_phone_nonce = null, phone_lookup_hash = null,
    qr_token_hash = null, qr_token_ciphertext = null, qr_token_nonce = null,
    pii_deleted_at = now()
  where id = p_booking_id;
  delete from public.idempotency_keys where resource_type = 'booking' and resource_id = p_booking_id;
  insert into public.audit_events (
    actor_type, workspace_id, entity_type, entity_id, action_code, request_id
  ) values ('organizer', v_workspace_id, 'booking', p_booking_id,
    'booking.pii_deleted', p_request_id);
  return true;
end;
$$;

create or replace function private.export_report_rows_impl(
  p_actor_id uuid, p_event_id uuid default null,
  p_created_from timestamptz default null, p_created_to timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid;
  v_rows jsonb;
begin
  select w.id into v_workspace_id from public.workspaces as w
  where w.owner_user_id = p_actor_id and w.status = 'active';
  if not found then raise exception using errcode = '42501', message = 'WORKSPACE_UNAVAILABLE'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'public_booking_id', b.public_booking_id, 'event_name', e.name,
    'created_at', b.created_at, 'status', b.status,
    'estimated_weight_grams', b.estimated_weight_grams,
    'actual_weight_grams', r.actual_weight_grams, 'condition', r.condition,
    'rejection_reason', r.rejection_reason, 'shipping_method', b.shipping_method,
    'donor_name_ciphertext', b.donor_name_ciphertext, 'donor_name_nonce', b.donor_name_nonce,
    'donor_phone_ciphertext', b.donor_phone_ciphertext, 'donor_phone_nonce', b.donor_phone_nonce,
    'crypto_key_version', b.crypto_key_version
  ) order by b.created_at), '[]'::jsonb) into v_rows
  from public.bookings as b join public.events as e on e.id = b.event_id
  left join public.receptions as r on r.booking_id = b.id
  where b.workspace_id = v_workspace_id and b.pii_deleted_at is null
    and (p_event_id is null or b.event_id = p_event_id)
    and (p_created_from is null or b.created_at >= p_created_from)
    and (p_created_to is null or b.created_at < p_created_to);
  return v_rows;
end;
$$;

create or replace function api.resolve_event_v1(p_token_hash text)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.resolve_event_impl(p_token_hash) $$;
create or replace function api.consume_rate_limit_v1(
  p_endpoint text, p_fingerprint_hash text, p_window_seconds integer, p_max_requests integer
) returns jsonb language sql security invoker set search_path = ''
as $$ select private.consume_rate_limit_impl(p_endpoint, p_fingerprint_hash, p_window_seconds, p_max_requests) $$;
create or replace function api.create_booking_v1(
  p_invocation_token_hash text, p_actor_scope text, p_idempotency_key text,
  p_request_hash text, p_booking jsonb
) returns jsonb language sql security invoker set search_path = ''
as $$ select private.create_booking_impl(p_invocation_token_hash, p_actor_scope,
  p_idempotency_key, p_request_hash, p_booking) $$;
create or replace function api.verify_donor_booking_v1(p_public_booking_id text, p_phone_lookup_hash text)
returns uuid language sql security invoker set search_path = ''
as $$ select private.verify_donor_booking_impl(p_public_booking_id, p_phone_lookup_hash) $$;
create or replace function api.donor_booking_status_v1(p_booking_id uuid)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.donor_booking_status_impl(p_booking_id) $$;
create or replace function api.resolve_qr_v1(p_actor_id uuid, p_qr_token_hash text)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.resolve_qr_impl(p_actor_id, p_qr_token_hash) $$;
create or replace function api.decide_reception_v1(
  p_booking_id uuid, p_decision public.reception_decision,
  p_actual_weight_grams bigint, p_condition public.item_condition,
  p_rejection_reason public.rejection_reason, p_rejection_note text,
  p_idempotency_key text, p_request_id uuid
) returns jsonb language sql security invoker set search_path = ''
as $$ select private.decide_reception_impl(p_booking_id, p_decision,
  p_actual_weight_grams, p_condition, p_rejection_reason, p_rejection_note,
  p_idempotency_key, p_request_id) $$;
create or replace function api.recap_v1(p_event_id uuid default null)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.recap_impl(p_event_id) $$;
create or replace function api.delete_donor_data_v1(p_actor_id uuid, p_booking_id uuid, p_request_id uuid)
returns boolean language sql security invoker set search_path = ''
as $$ select private.delete_donor_data_impl(p_actor_id, p_booking_id, p_request_id) $$;
create or replace function api.export_report_rows_v1(
  p_actor_id uuid, p_event_id uuid default null,
  p_created_from timestamptz default null, p_created_to timestamptz default null
) returns jsonb language sql security invoker set search_path = ''
as $$ select private.export_report_rows_impl(p_actor_id, p_event_id, p_created_from, p_created_to) $$;

revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.decide_reception_impl(uuid, public.reception_decision,
  bigint, public.item_condition, public.rejection_reason, text, text, uuid) to authenticated;
grant execute on function private.recap_impl(uuid) to authenticated;

revoke execute on all functions in schema api from public, anon;
grant execute on function api.decide_reception_v1(uuid, public.reception_decision,
  bigint, public.item_condition, public.rejection_reason, text, text, uuid) to authenticated;
grant execute on function api.recap_v1(uuid) to authenticated;
grant execute on function api.resolve_event_v1(text) to service_role;
grant execute on function api.consume_rate_limit_v1(text, text, integer, integer) to service_role;
grant execute on function api.create_booking_v1(text, text, text, text, jsonb) to service_role;
grant execute on function api.verify_donor_booking_v1(text, text) to service_role;
grant execute on function api.donor_booking_status_v1(uuid) to service_role;
grant execute on function api.resolve_qr_v1(uuid, text) to service_role;
grant execute on function api.delete_donor_data_v1(uuid, uuid, uuid) to service_role;
grant execute on function api.export_report_rows_v1(uuid, uuid, timestamptz, timestamptz) to service_role;
