-- Keep offline draft identity stable across uncertain retries and serialize
-- the idempotency claim before changing the event row.

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
  v_hash text;
  v_existing public.idempotency_keys;
  v_response jsonb;
  v_claimed integer := 0;
begin
  if p_mutation_id is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_REQUEST';
  end if;

  v_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'event_id', p_event_id,
    'payload', p_payload
  )::text, 'UTF8'), 'sha256'), 'hex');

  insert into public.idempotency_keys (
    scope, actor_scope, key, request_hash, resource_type, resource_id
  ) values (
    'event-draft', v_actor_id::text, p_mutation_id::text, v_hash, 'event', p_event_id
  ) on conflict (scope, actor_scope, key) do nothing;
  get diagnostics v_claimed = row_count;

  if v_claimed = 0 then
    select i.* into v_existing
    from public.idempotency_keys as i
    where i.scope = 'event-draft'
      and i.actor_scope = v_actor_id::text
      and i.key = p_mutation_id::text
    for update;
    if v_existing.request_hash <> v_hash then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_CONFLICT';
    end if;
    if v_existing.response_payload is null then
      raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_INCOMPLETE';
    end if;
    return v_existing.response_payload;
  end if;

  if p_event_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_event_id::text, 0)
    );
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
    select e.* into v_event
    from public.events as e
    where e.id = p_event_id and e.workspace_id = v_workspace_id
    for update;

    if not found then
      if exists(select 1 from public.events as e where e.id = p_event_id) then
        raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND';
      end if;
      insert into public.events (
        id, workspace_id, name, description, start_at, end_at, timezone_name,
        operational_days, opens_at_local, closes_at_local, location_name,
        location_address, location_country_code, latitude, longitude,
        capacity_grams, banner_object_path, receiver_name, receiver_phone, receiver_address
      ) values (
        p_event_id, v_workspace_id, nullif(trim(p_payload ->> 'name'), ''),
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
      where e.id = v_event.id
      returning * into v_event;
    end if;
  end if;

  if p_payload ? 'criteria' then
    delete from public.event_criteria where event_id = v_event.id;
    insert into public.event_criteria (event_id, criterion)
    select v_event.id, value::public.criterion_code
    from jsonb_array_elements_text(p_payload -> 'criteria')
    on conflict do nothing;
  end if;

  v_response := private.event_to_json(v_event);
  update public.idempotency_keys
  set resource_id = v_event.id, response_payload = v_response
  where scope = 'event-draft'
    and actor_scope = v_actor_id::text
    and key = p_mutation_id::text;
  return v_response;
end;
$$;
