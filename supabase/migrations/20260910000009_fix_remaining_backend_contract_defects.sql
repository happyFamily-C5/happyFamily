-- Close the final server-side contract gaps before the authenticated-only
-- cutover. These definitions follow the preceding 20260910000001..08
-- migrations and therefore deliberately preserve their public API names.

-- Receiver values are an immutable workspace snapshot. An existing draft must
-- not silently inherit later workspace profile edits.
CREATE OR replace function private.upsert_event_draft_v2_impl(p_event_id uuid,
  p_mutation_id uuid, p_payload jsonb) returns jsonb language plpgsql security
  definer SET search_path = '' AS $$
declare v_actor_id uuid := private.require_role('admin');
declare v_workspace public.workspaces;
declare v_event public.events;
declare v_max bigint;
declare v_legacy_response jsonb;
declare v_payload jsonb := p_payload - 'receiver_name' - 'receiver_phone' - 'receiver_address';
begin
  select * into v_workspace from public.workspaces
  where owner_user_id = v_actor_id and status = 'active';
  if not found then raise exception using errcode = '42501', message = 'WORKSPACE_UNAVAILABLE'; end if;
  select private.upsert_event_draft_impl(p_event_id, p_mutation_id, v_payload)
    into v_legacy_response;
  select * into v_event from public.events
  where id = (v_legacy_response ->> 'id')::uuid and workspace_id = v_workspace.id
  for update;
  if not found then raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND'; end if;
  if p_payload ? 'max_donation_per_user_grams' then
    v_max := nullif(p_payload ->> 'max_donation_per_user_grams', '')::bigint;
    if v_max is not null and v_max <= 0 then
      raise exception using errcode = '23514', message = 'INVALID_DONATION_LIMIT';
    end if;
    update public.events set max_donation_per_user_grams = v_max
    where id = v_event.id and workspace_id = v_workspace.id returning * into v_event;
  end if;
  update public.events set
    receiver_name = v_workspace.name,
    receiver_phone = v_workspace.office_phone_e164,
    receiver_address = v_workspace.office_address
  where id = v_event.id
    and receiver_name is null
    and receiver_phone is null
    and receiver_address is null
  returning * into v_event;
  if not found then
    select * into v_event from public.events
    where id = (v_legacy_response ->> 'id')::uuid;
  end if;
  return private.event_user_json(v_event);
end;
$$;

revoke execute ON function private.upsert_event_draft_v2_impl(uuid, uuid, jsonb)
FROM public, anon, authenticated;

-- A booking that already exists for this donor makes this event unavailable to
-- that donor, even when the event itself still has capacity.
CREATE OR replace function private.event_detail_impl(p_event_id uuid) returns
  jsonb language plpgsql security definer SET search_path = '' AS $$
declare
  v_actor_id uuid := private.require_role('donor');
  v_profile public.profiles;
  v_event public.events;
  v_distance double precision;
  v_booked boolean;
begin
  select * into v_profile from public.profiles where id = v_actor_id;
  select * into v_event from public.events
  where id = p_event_id and status in ('upcoming', 'ongoing');
  if not found then raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND'; end if;
  if v_profile.recommendation_latitude is not null and v_event.latitude is not null then
    v_distance := 6371.0 * acos(least(1.0, greatest(-1.0,
      cos(radians(v_profile.recommendation_latitude)) * cos(radians(v_event.latitude)) *
      cos(radians(v_event.longitude) - radians(v_profile.recommendation_longitude)) +
      sin(radians(v_profile.recommendation_latitude)) * sin(radians(v_event.latitude))
    )));
  end if;
  select exists (
    select 1 from public.bookings as b
    where b.event_id = p_event_id and b.donor_user_id = v_actor_id
      and b.status not in ('cancelled', 'rejected', 'expired')
  ) into v_booked;
  return private.event_user_json(v_event, v_distance) || jsonb_build_object(
    'availability', jsonb_build_object(
      'bookable',
      not v_booked
        and v_event.capacity_grams is not null
        and v_event.received_weight_grams + v_event.reserved_weight_grams < v_event.capacity_grams
        and v_event.end_at > now(),
      'available_weight_grams',
      case when v_event.capacity_grams is null then null
        else greatest(v_event.capacity_grams - v_event.received_weight_grams - v_event.reserved_weight_grams, 0)
      end
    ),
    'already_booked', v_booked
  );
end;
$$;

revoke execute ON function private.event_detail_impl(uuid)
FROM public, anon, authenticated;

-- Every non-idempotent Admin mutation now records a stable response under the
-- same (scope, actor_scope, key) protocol used by booking and reception.
CREATE OR replace function private.publish_event_v3_impl(p_event_id uuid,
  p_idempotency_key text, p_request_id uuid) returns jsonb language plpgsql
  security definer SET search_path = '' AS $$
declare
  v_actor uuid := private.require_role('admin');
  v_existing public.idempotency_keys;
  v_hash text := encode(extensions.digest(convert_to(
    jsonb_build_object('event_id', p_event_id)::text, 'UTF8'
  ), 'sha256'), 'hex');
  v_response jsonb;
begin
  if nullif(trim(p_idempotency_key), '') is null then
    raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUIRED';
  end if;
  insert into public.idempotency_keys(scope, actor_scope, key, request_hash, resource_type, resource_id)
  values ('publish-event-v3', v_actor::text, p_idempotency_key, v_hash, 'event', p_event_id)
  on conflict (scope, actor_scope, key) do nothing;
  if not found then
    select * into v_existing from public.idempotency_keys
    where scope = 'publish-event-v3' and actor_scope = v_actor::text and key = p_idempotency_key
    for update;
    if v_existing.request_hash <> v_hash then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_CONFLICT';
    end if;
    if v_existing.response_payload is null then
      raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_INCOMPLETE';
    end if;
    return v_existing.response_payload;
  end if;
  v_response := private.publish_event_v2_impl(p_event_id, p_request_id);
  update public.idempotency_keys set response_payload = v_response
  where scope = 'publish-event-v3' and actor_scope = v_actor::text and key = p_idempotency_key;
  return v_response;
end;
$$;

DROP function IF EXISTS api.publish_event_v2(uuid, uuid);
CREATE function api.publish_event_v2(p_event_id uuid, p_idempotency_key text,
  p_request_id uuid) returns jsonb language sql security definer SET search_path
  = '' AS
  $$ select private.publish_event_v3_impl(p_event_id, p_idempotency_key, p_request_id) $$;

revoke execute ON function private.publish_event_v2_impl(uuid, uuid)
FROM public, anon, authenticated;
revoke execute ON function private.publish_event_v3_impl(uuid, text, uuid)
FROM public, anon, authenticated;
revoke execute ON function api.publish_event_v2(uuid, text, uuid)
FROM public, anon;
grant execute ON function api.publish_event_v2(uuid, text, uuid) TO
  authenticated, service_role;

CREATE OR replace function private.cancel_or_delete_event_v3_impl(p_event_id
  uuid, p_idempotency_key text, p_request_id uuid) returns jsonb language
  plpgsql security definer SET search_path = '' AS $$
declare
  v_actor uuid := private.require_role('admin');
  v_existing public.idempotency_keys;
  v_hash text := encode(extensions.digest(convert_to(
    jsonb_build_object('event_id', p_event_id)::text, 'UTF8'
  ), 'sha256'), 'hex');
  v_response jsonb;
begin
  if nullif(trim(p_idempotency_key), '') is null then
    raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUIRED';
  end if;
  insert into public.idempotency_keys(scope, actor_scope, key, request_hash, resource_type, resource_id)
  values ('cancel-event-v3', v_actor::text, p_idempotency_key, v_hash, 'event', p_event_id)
  on conflict (scope, actor_scope, key) do nothing;
  if not found then
    select * into v_existing from public.idempotency_keys
    where scope = 'cancel-event-v3' and actor_scope = v_actor::text and key = p_idempotency_key
    for update;
    if v_existing.request_hash <> v_hash then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_CONFLICT';
    end if;
    if v_existing.response_payload is null then
      raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_INCOMPLETE';
    end if;
    return v_existing.response_payload;
  end if;
  v_response := private.cancel_or_delete_event_v2_impl(p_event_id, p_request_id);
  update public.idempotency_keys set response_payload = v_response
  where scope = 'cancel-event-v3' and actor_scope = v_actor::text and key = p_idempotency_key;
  return v_response;
end;
$$;

DROP function IF EXISTS api.cancel_or_delete_event_v2(uuid, uuid);
CREATE function api.cancel_or_delete_event_v2(p_event_id uuid, p_idempotency_key
  text, p_request_id uuid) returns jsonb language sql security definer SET
  search_path = '' AS
  $$ select private.cancel_or_delete_event_v3_impl(p_event_id, p_idempotency_key, p_request_id) $$;

revoke execute ON function private.cancel_or_delete_event_v2_impl(uuid, uuid)
FROM public, anon, authenticated;
revoke execute ON function private.cancel_or_delete_event_v3_impl(uuid, text,
  uuid)
FROM public, anon, authenticated;
revoke execute ON function api.cancel_or_delete_event_v2(uuid, text, uuid)
FROM public, anon;
grant execute ON function api.cancel_or_delete_event_v2(uuid, text, uuid) TO
  authenticated, service_role;

CREATE OR replace function private.advance_booking_status_v2_impl(p_booking_id
  uuid, p_status public.booking_status, p_idempotency_key text, p_request_id
  uuid) returns jsonb language plpgsql security definer SET search_path = '' AS
  $$
declare
  v_actor uuid := private.require_role('admin');
  v_existing public.idempotency_keys;
  v_hash text := encode(extensions.digest(convert_to(
    jsonb_build_object('booking_id', p_booking_id, 'status', p_status)::text, 'UTF8'
  ), 'sha256'), 'hex');
  v_response jsonb;
begin
  if nullif(trim(p_idempotency_key), '') is null then
    raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUIRED';
  end if;
  insert into public.idempotency_keys(scope, actor_scope, key, request_hash, resource_type, resource_id)
  values ('advance-booking-status-v2', v_actor::text, p_idempotency_key, v_hash, 'booking', p_booking_id)
  on conflict (scope, actor_scope, key) do nothing;
  if not found then
    select * into v_existing from public.idempotency_keys
    where scope = 'advance-booking-status-v2' and actor_scope = v_actor::text and key = p_idempotency_key
    for update;
    if v_existing.request_hash <> v_hash then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_CONFLICT';
    end if;
    if v_existing.response_payload is null then
      raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_INCOMPLETE';
    end if;
    return v_existing.response_payload;
  end if;
  v_response := private.advance_booking_status_impl(p_booking_id, p_status, p_request_id);
  update public.idempotency_keys set response_payload = v_response
  where scope = 'advance-booking-status-v2' and actor_scope = v_actor::text and key = p_idempotency_key;
  return v_response;
end;
$$;

DROP function IF EXISTS api.advance_booking_status_v1(uuid,
  public.booking_status, uuid);
CREATE function api.advance_booking_status_v1(p_booking_id uuid, p_status
  public.booking_status, p_idempotency_key text, p_request_id uuid) returns
  jsonb language sql security definer SET search_path = '' AS
  $$ select private.advance_booking_status_v2_impl(p_booking_id, p_status, p_idempotency_key, p_request_id) $$;

revoke execute ON function private.advance_booking_status_impl(uuid,
  public.booking_status, uuid)
FROM public, anon, authenticated;
revoke execute ON function private.advance_booking_status_v2_impl(uuid,
  public.booking_status, text, uuid)
FROM public, anon, authenticated;
revoke execute ON function api.advance_booking_status_v1(uuid,
  public.booking_status, text, uuid)
FROM public, anon;
grant execute ON function api.advance_booking_status_v1(uuid,
  public.booking_status, text, uuid) TO authenticated, service_role;

-- Legacy guest RPCs remain only as retention-compatible database artifacts;
-- they are no longer callable by unauthenticated or authenticated clients.
revoke execute ON function api.resolve_event_v1(text)
FROM public, anon, authenticated;
revoke execute ON function api.create_booking_v1(text, text, text, text, jsonb)
FROM public, anon, authenticated;
revoke execute ON function api.verify_donor_booking_v1(text, text)
FROM public, anon, authenticated;
revoke execute ON function api.donor_booking_status_v1(uuid)
FROM public, anon, authenticated;
