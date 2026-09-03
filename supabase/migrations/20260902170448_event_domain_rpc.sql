-- Event domain functions. Exposed API wrappers remain SECURITY INVOKER and
-- delegate to non-exposed, explicitly granted SECURITY DEFINER functions.

create or replace function private.require_workspace()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  select w.id into v_workspace_id
  from public.workspaces as w
  where w.owner_user_id = (select auth.uid()) and w.status = 'active';
  if v_workspace_id is null then
    raise exception using errcode = '42501', message = 'WORKSPACE_UNAVAILABLE';
  end if;
  return v_workspace_id;
end;
$$;

create or replace function private.event_to_json(p_event public.events)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select to_jsonb(p_event) || jsonb_build_object(
    'criteria', coalesce((
      select jsonb_agg(ec.criterion order by ec.criterion)
      from public.event_criteria as ec where ec.event_id = p_event.id
    ), '[]'::jsonb)
  )
$$;

create or replace function private.guard_event_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status in ('completed', 'closed', 'cancelled') and new is distinct from old then
    raise exception using errcode = 'P0001', message = 'EVENT_TERMINAL';
  end if;
  if new.capacity_grams is not null and new.capacity_grams < new.received_weight_grams then
    raise exception using errcode = '23514', message = 'CAPACITY_BELOW_RECEIVED';
  end if;
  return new;
end;
$$;

revoke execute on function private.guard_event_update() from public, anon, authenticated;
create trigger events_guard_update before update on public.events
for each row execute function private.guard_event_update();

create or replace function private.reconcile_events(p_workspace_id uuid default null)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total bigint := 0;
  v_affected bigint := 0;
begin
  update public.events as e
  set status = 'completed', terminal_at = now(), version = e.version + 1
  where e.status in ('upcoming', 'ongoing') and e.end_at <= now()
    and (p_workspace_id is null or e.workspace_id = p_workspace_id);
  get diagnostics v_affected = row_count;
  v_total := v_total + v_affected;

  update public.bookings as b
  set status = 'expired', terminal_at = now(), terminal_reason_code = 'event_completed'
  from public.events as e
  where b.event_id = e.id and b.status = 'waiting' and e.status = 'completed'
    and (p_workspace_id is null or e.workspace_id = p_workspace_id);
  get diagnostics v_affected = row_count;
  v_total := v_total + v_affected;

  update public.events as e
  set status = 'ongoing', version = e.version + 1
  where e.status = 'upcoming' and e.start_at <= now() and e.end_at > now()
    and (p_workspace_id is null or e.workspace_id = p_workspace_id);
  get diagnostics v_affected = row_count;
  v_total := v_total + v_affected;

  update public.bookings as b
  set status = 'expired', terminal_at = now(), terminal_reason_code = 'booking_expired'
  where b.status = 'waiting' and b.expires_at <= now()
    and (p_workspace_id is null or b.workspace_id = p_workspace_id);
  get diagnostics v_affected = row_count;
  return v_total + v_affected;
end;
$$;

create or replace function private.list_events_impl(
  p_updated_after timestamptz default null,
  p_after_id uuid default null,
  p_limit integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid := private.require_workspace();
  v_items jsonb;
begin
  perform private.reconcile_events(v_workspace_id);
  select coalesce(jsonb_agg(private.event_to_json(q.event_row) order by q.updated_at, q.id), '[]'::jsonb)
  into v_items
  from (
    select e as event_row, e.updated_at, e.id
    from public.events as e
    where e.workspace_id = v_workspace_id
      and (
        p_updated_after is null or e.updated_at > p_updated_after
        or (e.updated_at = p_updated_after and p_after_id is not null and e.id > p_after_id)
      )
    order by e.updated_at, e.id
    limit greatest(1, least(coalesce(p_limit, 50), 100))
  ) as q;
  return jsonb_build_object('items', v_items, 'server_time', now());
end;
$$;

create or replace function private.get_event_impl(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid := private.require_workspace();
  v_event public.events;
begin
  perform private.reconcile_events(v_workspace_id);
  select e.* into v_event from public.events as e
  where e.id = p_event_id and e.workspace_id = v_workspace_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND';
  end if;
  return private.event_to_json(v_event);
end;
$$;

create or replace function private.upsert_event_draft_impl(
  p_event_id uuid,
  p_mutation_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid := private.require_workspace();
  v_actor_id uuid := (select auth.uid());
  v_event public.events;
  v_hash text := encode(extensions.digest(convert_to(p_payload::text, 'UTF8'), 'sha256'), 'hex');
  v_existing public.idempotency_keys;
  v_response jsonb;
begin
  if p_mutation_id is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_REQUEST';
  end if;
  select i.* into v_existing from public.idempotency_keys as i
  where i.scope = 'event-draft' and i.actor_scope = v_actor_id::text
    and i.key = p_mutation_id::text;
  if found then
    if v_existing.request_hash <> v_hash then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_CONFLICT';
    end if;
    return v_existing.response_payload;
  end if;

  if p_event_id is null then
    insert into public.events (
      workspace_id, name, description, start_at, end_at, timezone_name,
      operational_days, opens_at_local, closes_at_local, location_name,
      location_address, location_country_code, latitude, longitude,
      capacity_grams, banner_object_path, receiver_name, receiver_phone, receiver_address
    ) values (
      v_workspace_id, nullif(trim(p_payload ->> 'name'), ''),
      nullif(trim(p_payload ->> 'description'), ''),
      nullif(p_payload ->> 'start_at', '')::timestamptz,
      nullif(p_payload ->> 'end_at', '')::timestamptz,
      nullif(p_payload ->> 'timezone_name', ''),
      case when jsonb_typeof(p_payload -> 'operational_days') = 'array' then
        array(select jsonb_array_elements_text(p_payload -> 'operational_days')::smallint)
      end,
      nullif(p_payload ->> 'opens_at_local', '')::time,
      nullif(p_payload ->> 'closes_at_local', '')::time,
      nullif(trim(p_payload ->> 'location_name'), ''),
      nullif(trim(p_payload ->> 'location_address'), ''),
      upper(nullif(trim(p_payload ->> 'location_country_code'), '')),
      nullif(p_payload ->> 'latitude', '')::double precision,
      nullif(p_payload ->> 'longitude', '')::double precision,
      nullif(p_payload ->> 'capacity_grams', '')::bigint,
      nullif(trim(p_payload ->> 'banner_object_path'), ''),
      nullif(trim(p_payload ->> 'receiver_name'), ''),
      nullif(trim(p_payload ->> 'receiver_phone'), ''),
      nullif(trim(p_payload ->> 'receiver_address'), '')
    ) returning * into v_event;
  else
    select e.* into v_event from public.events as e
    where e.id = p_event_id and e.workspace_id = v_workspace_id for update;
    if not found then
      raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND';
    end if;
    if v_event.status in ('completed', 'closed', 'cancelled') then
      raise exception using errcode = 'P0001', message = 'EVENT_TERMINAL';
    end if;
    update public.events as e set
      name = case when p_payload ? 'name' then nullif(trim(p_payload ->> 'name'), '') else e.name end,
      description = case when p_payload ? 'description' then nullif(trim(p_payload ->> 'description'), '') else e.description end,
      start_at = case when p_payload ? 'start_at' then nullif(p_payload ->> 'start_at', '')::timestamptz else e.start_at end,
      end_at = case when p_payload ? 'end_at' then nullif(p_payload ->> 'end_at', '')::timestamptz else e.end_at end,
      timezone_name = case when p_payload ? 'timezone_name' then nullif(p_payload ->> 'timezone_name', '') else e.timezone_name end,
      operational_days = case when p_payload ? 'operational_days' then array(
        select jsonb_array_elements_text(p_payload -> 'operational_days')::smallint
      ) else e.operational_days end,
      opens_at_local = case when p_payload ? 'opens_at_local' then nullif(p_payload ->> 'opens_at_local', '')::time else e.opens_at_local end,
      closes_at_local = case when p_payload ? 'closes_at_local' then nullif(p_payload ->> 'closes_at_local', '')::time else e.closes_at_local end,
      location_name = case when p_payload ? 'location_name' then nullif(trim(p_payload ->> 'location_name'), '') else e.location_name end,
      location_address = case when p_payload ? 'location_address' then nullif(trim(p_payload ->> 'location_address'), '') else e.location_address end,
      location_country_code = case when p_payload ? 'location_country_code' then upper(nullif(trim(p_payload ->> 'location_country_code'), '')) else e.location_country_code end,
      latitude = case when p_payload ? 'latitude' then nullif(p_payload ->> 'latitude', '')::double precision else e.latitude end,
      longitude = case when p_payload ? 'longitude' then nullif(p_payload ->> 'longitude', '')::double precision else e.longitude end,
      capacity_grams = case when p_payload ? 'capacity_grams' then nullif(p_payload ->> 'capacity_grams', '')::bigint else e.capacity_grams end,
      banner_object_path = case when p_payload ? 'banner_object_path' then nullif(trim(p_payload ->> 'banner_object_path'), '') else e.banner_object_path end,
      receiver_name = case when p_payload ? 'receiver_name' then nullif(trim(p_payload ->> 'receiver_name'), '') else e.receiver_name end,
      receiver_phone = case when p_payload ? 'receiver_phone' then nullif(trim(p_payload ->> 'receiver_phone'), '') else e.receiver_phone end,
      receiver_address = case when p_payload ? 'receiver_address' then nullif(trim(p_payload ->> 'receiver_address'), '') else e.receiver_address end,
      version = e.version + 1
    where e.id = v_event.id returning * into v_event;
  end if;

  if p_payload ? 'criteria' then
    delete from public.event_criteria where event_id = v_event.id;
    insert into public.event_criteria (event_id, criterion)
    select v_event.id, value::public.criterion_code
    from jsonb_array_elements_text(p_payload -> 'criteria')
    on conflict do nothing;
  end if;
  v_response := private.event_to_json(v_event);
  insert into public.idempotency_keys (
    scope, actor_scope, key, request_hash, resource_type, resource_id, response_payload
  ) values ('event-draft', v_actor_id::text, p_mutation_id::text, v_hash,
    'event', v_event.id, v_response);
  return v_response;
end;
$$;

create or replace function private.publish_event_impl(
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
  v_workspace_id uuid := private.require_workspace();
  v_event public.events;
  v_invocation public.event_invocations;
  v_active_count integer;
begin
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
      return jsonb_build_object('event', private.event_to_json(v_event),
        'invocation_ciphertext', v_invocation.token_ciphertext,
        'invocation_nonce', v_invocation.token_nonce,
        'crypto_key_version', v_invocation.crypto_key_version);
    end if;
  end if;
  if v_event.status <> 'draft' then
    raise exception using errcode = 'P0001', message = 'EVENT_NOT_PUBLISHABLE';
  end if;
  if v_event.name is null or v_event.description is null or v_event.banner_object_path is null
    or v_event.start_at is null or v_event.end_at is null or v_event.end_at <= now()
    or v_event.timezone_name not in ('Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura')
    or v_event.operational_days is null or v_event.opens_at_local is null or v_event.closes_at_local is null
    or v_event.location_name is null or v_event.location_address is null
    or v_event.location_country_code is distinct from 'ID'
    or v_event.latitude is null or v_event.longitude is null
    or v_event.capacity_grams is null or v_event.receiver_name is null
    or v_event.receiver_phone is null or v_event.receiver_address is null
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
    status = case when e.start_at <= now() then 'ongoing'::public.event_status else 'upcoming'::public.event_status end,
    published_at = coalesce(e.published_at, now()), version = e.version + 1
  where e.id = v_event.id returning * into v_event;
  insert into public.event_invocations (
    event_id, token_hash, token_ciphertext, token_nonce, crypto_key_version, environment
  ) values (v_event.id, p_token_hash, p_token_ciphertext, p_token_nonce,
    p_crypto_key_version, p_environment)
  on conflict (event_id, environment) do update set
    token_hash = excluded.token_hash, token_ciphertext = excluded.token_ciphertext,
    token_nonce = excluded.token_nonce, crypto_key_version = excluded.crypto_key_version,
    revoked_at = null, created_at = now()
  returning * into v_invocation;
  insert into public.audit_events (
    actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id
  ) values ('organizer', (select auth.uid())::text, v_workspace_id,
    'event', v_event.id, 'event.published', p_request_id);
  return jsonb_build_object('event', private.event_to_json(v_event),
    'invocation_ciphertext', v_invocation.token_ciphertext,
    'invocation_nonce', v_invocation.token_nonce,
    'crypto_key_version', v_invocation.crypto_key_version);
end;
$$;

create or replace function private.terminate_event_impl(
  p_event_id uuid,
  p_status public.event_status,
  p_reason text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid := private.require_workspace();
  v_event public.events;
begin
  if p_status not in ('closed', 'cancelled') then
    raise exception using errcode = '22023', message = 'INVALID_EVENT_TRANSITION';
  end if;
  select e.* into v_event from public.events as e
  where e.id = p_event_id and e.workspace_id = v_workspace_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND'; end if;
  if v_event.status in ('completed', 'closed', 'cancelled') then
    raise exception using errcode = 'P0001', message = 'EVENT_TERMINAL';
  end if;
  update public.events as e set status = p_status, terminal_at = now(),
    terminal_reason = nullif(trim(p_reason), ''), version = e.version + 1
  where e.id = v_event.id returning * into v_event;
  update public.bookings set status = 'cancelled', terminal_at = now(),
    terminal_reason_code = 'event_' || p_status::text
  where event_id = v_event.id and status = 'waiting';
  update public.event_invocations set revoked_at = now()
  where event_id = v_event.id and revoked_at is null;
  insert into public.audit_events (
    actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id
  ) values ('organizer', (select auth.uid())::text, v_workspace_id, 'event', v_event.id,
    'event.' || p_status::text, p_request_id);
  return private.event_to_json(v_event);
end;
$$;

create or replace function api.list_events_v1(
  p_updated_after timestamptz default null, p_after_id uuid default null,
  p_limit integer default 50
) returns jsonb language sql security invoker set search_path = ''
as $$ select private.list_events_impl(p_updated_after, p_after_id, p_limit) $$;
create or replace function api.get_event_v1(p_event_id uuid)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.get_event_impl(p_event_id) $$;
create or replace function api.upsert_event_draft_v1(
  p_event_id uuid, p_mutation_id uuid, p_payload jsonb
) returns jsonb language sql security invoker set search_path = ''
as $$ select private.upsert_event_draft_impl(p_event_id, p_mutation_id, p_payload) $$;
create or replace function api.publish_event_v1(
  p_event_id uuid, p_token_hash text, p_token_ciphertext text, p_token_nonce text,
  p_crypto_key_version smallint, p_environment public.deployment_environment,
  p_request_id uuid
) returns jsonb language sql security invoker set search_path = ''
as $$ select private.publish_event_impl(p_event_id, p_token_hash, p_token_ciphertext,
  p_token_nonce, p_crypto_key_version, p_environment, p_request_id) $$;
create or replace function api.terminate_event_v1(
  p_event_id uuid, p_status public.event_status, p_reason text, p_request_id uuid
) returns jsonb language sql security invoker set search_path = ''
as $$ select private.terminate_event_impl(p_event_id, p_status, p_reason, p_request_id) $$;

revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.list_events_impl(timestamptz, uuid, integer) to authenticated;
grant execute on function private.get_event_impl(uuid) to authenticated;
grant execute on function private.upsert_event_draft_impl(uuid, uuid, jsonb) to authenticated;
grant execute on function private.publish_event_impl(uuid, text, text, text, smallint, public.deployment_environment, uuid) to authenticated;
grant execute on function private.terminate_event_impl(uuid, public.event_status, text, uuid) to authenticated;

revoke execute on all functions in schema api from public, anon;
grant execute on function api.list_events_v1(timestamptz, uuid, integer) to authenticated;
grant execute on function api.get_event_v1(uuid) to authenticated;
grant execute on function api.upsert_event_draft_v1(uuid, uuid, jsonb) to authenticated;
grant execute on function api.publish_event_v1(uuid, text, text, text, smallint, public.deployment_environment, uuid) to authenticated;
grant execute on function api.terminate_event_v1(uuid, public.event_status, text, uuid) to authenticated;
grant execute on all functions in schema api to service_role;
