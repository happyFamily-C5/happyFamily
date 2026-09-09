-- Full Admin + User contract. This migration is intentionally additive so
-- legacy guest bookings can remain available to retention jobs while all new
-- bookings are owned by an authenticated donor account.

create type public.app_role as enum ('admin', 'donor');

alter table public.profiles
  add column account_role public.app_role,
  add column phone_e164 text,
  add column address text,
  add column recommendation_location_label text,
  add column recommendation_latitude double precision,
  add column recommendation_longitude double precision,
  add column avatar_object_path text;

alter table public.workspaces
  add column office_address text,
  add column office_phone_e164 text,
  add column office_email text,
  add column logo_object_path text;

alter table public.events
  add column max_donation_per_user_grams bigint,
  add column reserved_weight_grams bigint not null default 0;

alter table public.bookings
  add column donor_user_id uuid references auth.users(id) on delete set null,
  add column status_updated_at timestamptz not null default now();

update public.profiles as p
set account_role = 'admin'
where exists (
  select 1 from public.workspaces as w where w.owner_user_id = p.id
);

alter table public.events drop constraint if exists events_capacity;
alter table public.events add constraint events_capacity check (
  received_weight_grams >= 0
  and reserved_weight_grams >= 0
  and (capacity_grams is null or capacity_grams > 0)
  and (capacity_grams is null or received_weight_grams + reserved_weight_grams <= capacity_grams)
  and (
    max_donation_per_user_grams is null
    or (max_donation_per_user_grams > 0
      and (capacity_grams is null or max_donation_per_user_grams <= capacity_grams))
  )
);

alter table public.bookings drop constraint if exists bookings_terminal_timestamp;
alter table public.bookings add constraint bookings_terminal_timestamp check (
  (status in ('waiting', 'accepted', 'processed') and terminal_at is null)
  or (status in ('rejected', 'expired', 'cancelled', 'recycled') and terminal_at is not null)
) not valid;

-- This must follow replacement of the original terminal-status constraint:
-- accepted is now an in-progress tracking state rather than terminal.
update public.bookings
set terminal_at = null,
    status_updated_at = coalesce(terminal_at, created_at)
where status = 'accepted';
alter table public.bookings validate constraint bookings_terminal_timestamp;

alter table public.receptions alter column actual_weight_grams drop not null;
alter table public.receptions alter column condition drop not null;
alter table public.receptions drop constraint if exists receptions_weight;
alter table public.receptions drop constraint if exists receptions_rejection_shape;
alter table public.receptions add constraint receptions_shape check (
  (decision = 'accepted' and actual_weight_grams is not null and actual_weight_grams > 0)
  or (decision = 'rejected' and actual_weight_grams is null and condition is null
    and rejection_reason is null and rejection_note is null)
);

alter table public.profiles add constraint profiles_phone_format check (
  phone_e164 is null or phone_e164 ~ '^\\+62[0-9]{8,13}$'
);
alter table public.profiles add constraint profiles_location_pair check (
  (recommendation_latitude is null and recommendation_longitude is null)
  or (recommendation_latitude between -11.5 and 6.5
    and recommendation_longitude between 94.0 and 142.0)
);
alter table public.workspaces add constraint workspaces_phone_format check (
  office_phone_e164 is null or office_phone_e164 ~ '^\\+62[0-9]{8,13}$'
);
alter table public.workspaces add constraint workspaces_email_format check (
  office_email is null or office_email ~ '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$'
);

create table public.booking_status_events (
  id bigint generated always as identity primary key,
  booking_id uuid not null references public.bookings(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  previous_status public.booking_status,
  status public.booking_status not null,
  actor_type text not null check (actor_type in ('donor', 'admin', 'system')),
  actor_id uuid references auth.users(id) on delete set null,
  request_id uuid not null,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create index booking_status_events_booking_created_idx
  on public.booking_status_events (booking_id, created_at, id);
create index bookings_donor_history_idx
  on public.bookings (donor_user_id, created_at desc, id)
  where donor_user_id is not null;
create unique index bookings_one_nonfailed_per_donor_event_idx
  on public.bookings (donor_user_id, event_id)
  where donor_user_id is not null and status not in ('cancelled', 'rejected', 'expired');

insert into public.booking_status_events (
  booking_id, workspace_id, previous_status, status, actor_type, actor_id,
  request_id, metadata, created_at
)
select b.id, b.workspace_id, null, 'waiting', 'system', null,
  gen_random_uuid(), '{}'::jsonb, b.created_at
from public.bookings as b
on conflict do nothing;

insert into public.booking_status_events (
  booking_id, workspace_id, previous_status, status, actor_type, actor_id,
  request_id, metadata, created_at
)
select b.id, b.workspace_id, 'waiting', b.status,
  case when b.status = 'expired' then 'system' else 'admin' end,
  r.processed_by, gen_random_uuid(), '{}'::jsonb,
  coalesce(r.processed_at, b.terminal_at, b.status_updated_at)
from public.bookings as b
left join public.receptions as r on r.booking_id = b.id
where b.status <> 'waiting'
on conflict do nothing;

create or replace function private.current_account_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.account_role from public.profiles as p where p.id = (select auth.uid())
$$;

create or replace function private.require_role(p_role public.app_role)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  if private.current_account_role() is distinct from p_role then
    raise exception using errcode = '42501', message = 'ROLE_FORBIDDEN';
  end if;
  return v_actor_id;
end;
$$;

create or replace function private.current_workspace_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select w.id
  from public.workspaces as w
  join public.profiles as p on p.id = w.owner_user_id
  where w.owner_user_id = (select auth.uid())
    and w.status = 'active'
    and p.account_role = 'admin'
  limit 1
$$;

revoke execute on function private.current_account_role() from public, anon;
revoke execute on function private.require_role(public.app_role) from public, anon;
grant execute on function private.current_account_role() to authenticated, service_role;
grant execute on function private.require_role(public.app_role) to authenticated, service_role;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_display_name text;
begin
  v_display_name := left(coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    split_part(coalesce(new.email, 'Pengguna'), '@', 1),
    'Pengguna'
  ), 120);
  insert into public.profiles (id, display_name)
  values (new.id, v_display_name)
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function private.complete_onboarding_impl(p_role public.app_role)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_profile public.profiles;
  v_workspace public.workspaces;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  select * into v_profile from public.profiles where id = v_actor_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'PROFILE_NOT_FOUND';
  end if;
  if v_profile.account_role is not null and v_profile.account_role <> p_role then
    raise exception using errcode = '42501', message = 'ROLE_IMMUTABLE';
  end if;
  if v_profile.account_role is null then
    update public.profiles set account_role = p_role where id = v_actor_id
    returning * into v_profile;
  end if;
  if p_role = 'admin' then
    insert into public.workspaces (owner_user_id, name)
    values (v_actor_id, left(coalesce(nullif(v_profile.display_name, ''), 'Workspace .kumpul'), 160))
    on conflict (owner_user_id) do update set name = public.workspaces.name
    returning * into v_workspace;
  end if;
  return jsonb_build_object(
    'role', p_role,
    'profile_id', v_actor_id,
    'workspace_id', v_workspace.id
  );
end;
$$;

create or replace function api.complete_onboarding_v1(p_role public.app_role)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.complete_onboarding_impl(p_role) $$;

create or replace function private.update_user_profile_impl(
  p_display_name text,
  p_phone_e164 text,
  p_address text,
  p_location_label text,
  p_latitude double precision,
  p_longitude double precision,
  p_avatar_object_path text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor_id uuid := auth.uid();
declare v_profile public.profiles;
begin
  if v_actor_id is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
  update public.profiles set
    display_name = left(coalesce(nullif(trim(p_display_name), ''), display_name), 120),
    phone_e164 = nullif(trim(p_phone_e164), ''),
    address = nullif(trim(p_address), ''),
    recommendation_location_label = nullif(trim(p_location_label), ''),
    recommendation_latitude = p_latitude,
    recommendation_longitude = p_longitude,
    avatar_object_path = nullif(trim(p_avatar_object_path), '')
  where id = v_actor_id
  returning * into v_profile;
  if v_profile.account_role is null then
    raise exception using errcode = '42501', message = 'ONBOARDING_REQUIRED';
  end if;
  return jsonb_build_object(
    'id', v_profile.id, 'role', v_profile.account_role,
    'display_name', v_profile.display_name, 'phone_e164', v_profile.phone_e164,
    'address', v_profile.address, 'recommendation_location_label', v_profile.recommendation_location_label,
    'recommendation_latitude', v_profile.recommendation_latitude,
    'recommendation_longitude', v_profile.recommendation_longitude,
    'avatar_object_path', v_profile.avatar_object_path
  );
end;
$$;

create or replace function api.update_user_profile_v1(
  p_display_name text, p_phone_e164 text, p_address text,
  p_location_label text, p_latitude double precision, p_longitude double precision,
  p_avatar_object_path text
)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.update_user_profile_impl(
  p_display_name, p_phone_e164, p_address, p_location_label, p_latitude, p_longitude, p_avatar_object_path
) $$;

create or replace function private.update_workspace_profile_impl(
  p_name text, p_address text, p_phone_e164 text, p_email text, p_logo_object_path text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor_id uuid := private.require_role('admin');
declare v_workspace public.workspaces;
begin
  update public.workspaces set
    name = left(coalesce(nullif(trim(p_name), ''), name), 160),
    office_address = nullif(trim(p_address), ''),
    office_phone_e164 = nullif(trim(p_phone_e164), ''),
    office_email = nullif(lower(trim(p_email)), ''),
    logo_object_path = nullif(trim(p_logo_object_path), '')
  where owner_user_id = v_actor_id and status = 'active'
  returning * into v_workspace;
  if not found then raise exception using errcode = '42501', message = 'WORKSPACE_UNAVAILABLE'; end if;
  return jsonb_build_object(
    'id', v_workspace.id, 'name', v_workspace.name,
    'office_address', v_workspace.office_address,
    'office_phone_e164', v_workspace.office_phone_e164,
    'office_email', v_workspace.office_email,
    'logo_object_path', v_workspace.logo_object_path
  );
end;
$$;

create or replace function api.update_workspace_profile_v1(
  p_name text, p_address text, p_phone_e164 text, p_email text, p_logo_object_path text
)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.update_workspace_profile_impl(p_name, p_address, p_phone_e164, p_email, p_logo_object_path) $$;

create or replace function private.event_user_json(p_event public.events, p_distance_km double precision default null)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_event.id, 'name', p_event.name, 'description', p_event.description,
    'status', p_event.status, 'start_at', p_event.start_at, 'end_at', p_event.end_at,
    'timezone_name', p_event.timezone_name, 'location_name', p_event.location_name,
    'location_address', p_event.location_address, 'latitude', p_event.latitude,
    'longitude', p_event.longitude, 'capacity_grams', p_event.capacity_grams,
    'received_weight_grams', p_event.received_weight_grams,
    'reserved_weight_grams', p_event.reserved_weight_grams,
    'used_weight_grams', p_event.received_weight_grams + p_event.reserved_weight_grams,
    'max_donation_per_user_grams', p_event.max_donation_per_user_grams,
    'banner_object_path', p_event.banner_object_path,
    'receiver_name', p_event.receiver_name, 'receiver_phone', p_event.receiver_phone,
    'receiver_address', p_event.receiver_address,
    'organization_name', w.name, 'organization_logo_object_path', w.logo_object_path,
    'distance_km', p_distance_km,
    'criteria', coalesce((select jsonb_agg(ec.criterion order by ec.criterion)
      from public.event_criteria as ec where ec.event_id = p_event.id), '[]'::jsonb)
  )
  from public.workspaces as w where w.id = p_event.workspace_id
$$;

create or replace function private.assert_workspace_publishable(p_workspace public.workspaces)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if nullif(trim(p_workspace.name), '') is null
    or nullif(trim(p_workspace.office_address), '') is null
    or nullif(trim(p_workspace.office_phone_e164), '') is null
    or nullif(trim(p_workspace.office_email), '') is null
  then
    raise exception using errcode = '23514', message = 'WORKSPACE_PROFILE_INCOMPLETE';
  end if;
end;
$$;

create or replace function private.upsert_event_draft_v2_impl(
  p_event_id uuid,
  p_mutation_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor_id uuid := private.require_role('admin');
declare v_workspace public.workspaces;
declare v_event public.events;
declare v_max bigint;
declare v_legacy_response jsonb;
begin
  select * into v_workspace from public.workspaces
  where owner_user_id = v_actor_id and status = 'active';
  if not found then raise exception using errcode = '42501', message = 'WORKSPACE_UNAVAILABLE'; end if;
  -- v1 owns the durable draft-idempotency protocol and returns JSON.  Resolve
  -- the event row after it has committed its mutation rather than assigning a
  -- JSON response to an events composite value.
  select private.upsert_event_draft_impl(p_event_id, p_mutation_id, p_payload)
    into v_legacy_response;
  select * into v_event from public.events
  where id = (v_legacy_response ->> 'id')::uuid and workspace_id = v_workspace.id
  for update;
  if not found then raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND'; end if;
  if p_payload ? 'max_donation_per_user_grams' then
    v_max := nullif(p_payload ->> 'max_donation_per_user_grams', '')::bigint;
    if v_max is not null and v_max <= 0 then raise exception using errcode = '23514', message = 'INVALID_DONATION_LIMIT'; end if;
    update public.events set max_donation_per_user_grams = v_max
    where id = v_event.id and workspace_id = v_workspace.id returning * into v_event;
  end if;
  -- Receiver is a workspace snapshot; event payloads must never override it.
  update public.events set
    receiver_name = v_workspace.name,
    receiver_phone = v_workspace.office_phone_e164,
    receiver_address = v_workspace.office_address
  where id = v_event.id returning * into v_event;
  return private.event_user_json(v_event);
end;
$$;

create or replace function api.upsert_event_draft_v2(
  p_event_id uuid, p_mutation_id uuid, p_payload jsonb
)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.upsert_event_draft_v2_impl(p_event_id, p_mutation_id, p_payload) $$;

create or replace function private.publish_event_v2_impl(p_event_id uuid, p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor_id uuid := private.require_role('admin');
declare v_workspace public.workspaces;
declare v_event public.events;
declare v_active_count integer;
begin
  select * into v_workspace from public.workspaces
  where owner_user_id = v_actor_id and status = 'active' for update;
  if not found then raise exception using errcode = '42501', message = 'WORKSPACE_UNAVAILABLE'; end if;
  perform private.assert_workspace_publishable(v_workspace);
  select * into v_event from public.events
  where id = p_event_id and workspace_id = v_workspace.id for update;
  if not found then raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND'; end if;
  if v_event.status <> 'draft' then raise exception using errcode = 'P0001', message = 'EVENT_NOT_PUBLISHABLE'; end if;
  if v_event.name is null or v_event.description is null or v_event.banner_object_path is null
    or v_event.start_at is null or v_event.end_at is null or v_event.end_at <= now()
    or v_event.timezone_name <> 'Asia/Jakarta' or v_event.operational_days is null
    or v_event.opens_at_local is null or v_event.closes_at_local is null
    or v_event.location_name is null or v_event.location_address is null
    or v_event.capacity_grams is null or v_event.max_donation_per_user_grams is null
  then raise exception using errcode = '23514', message = 'EVENT_PUBLISH_FIELDS_REQUIRED'; end if;
  select count(*) into v_active_count from public.events
  where workspace_id = v_workspace.id and status in ('upcoming', 'ongoing');
  if v_active_count >= 5 then raise exception using errcode = 'P0001', message = 'ACTIVE_EVENT_LIMIT'; end if;
  update public.events set
    status = case when start_at <= now() then 'ongoing' else 'upcoming' end,
    published_at = now(), version = version + 1
  where id = v_event.id returning * into v_event;
  insert into public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
  values ('admin', v_actor_id::text, v_workspace.id, 'event', v_event.id, 'event.published', p_request_id);
  return private.event_user_json(v_event);
end;
$$;

create or replace function api.publish_event_v2(p_event_id uuid, p_request_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.publish_event_v2_impl(p_event_id, p_request_id) $$;

create or replace function private.user_dashboard_impl()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor_id uuid := private.require_role('donor');
declare v_profile public.profiles;
declare v_active jsonb;
declare v_recommended jsonb;
declare v_trending jsonb;
begin
  select * into v_profile from public.profiles where id = v_actor_id;
  select coalesce(jsonb_agg(private.event_user_json(e) order by e.start_at, e.id), '[]'::jsonb)
    into v_active
  from public.events e join public.bookings b on b.event_id = e.id
  where b.donor_user_id = v_actor_id and b.status in ('waiting', 'accepted', 'processed');

  select coalesce(jsonb_agg(item.payload order by item.distance_km nulls last, item.start_at, item.id), '[]'::jsonb)
    into v_recommended
  from (
    select e.id, e.start_at,
      case when v_profile.recommendation_latitude is null then null else
        6371.0 * acos(least(1.0, greatest(-1.0,
          cos(radians(v_profile.recommendation_latitude)) * cos(radians(e.latitude)) *
          cos(radians(e.longitude) - radians(v_profile.recommendation_longitude)) +
          sin(radians(v_profile.recommendation_latitude)) * sin(radians(e.latitude))
        ))) end as distance_km,
      private.event_user_json(e, case when v_profile.recommendation_latitude is null then null else
        6371.0 * acos(least(1.0, greatest(-1.0,
          cos(radians(v_profile.recommendation_latitude)) * cos(radians(e.latitude)) *
          cos(radians(e.longitude) - radians(v_profile.recommendation_longitude)) +
          sin(radians(v_profile.recommendation_latitude)) * sin(radians(e.latitude))
        ))) end) as payload
    from public.events e
    where e.status in ('upcoming', 'ongoing')
      and e.capacity_grams is not null
      and e.received_weight_grams + e.reserved_weight_grams < e.capacity_grams
      and not exists (
        select 1 from public.bookings b where b.event_id = e.id and b.donor_user_id = v_actor_id
          and b.status not in ('cancelled', 'rejected', 'expired')
      )
    order by distance_km nulls last, e.start_at, e.id
    limit 20
  ) item;

  select coalesce(jsonb_agg(item.payload order by item.booking_count desc, item.start_at, item.id), '[]'::jsonb)
    into v_trending
  from (
    select e.id, e.start_at, count(b.id) as booking_count, private.event_user_json(e) as payload
    from public.events e
    left join public.bookings b on b.event_id = e.id
      and b.created_at >= (date_trunc('day', now() at time zone 'Asia/Jakarta') at time zone 'Asia/Jakarta') - interval '6 days'
      and b.status not in ('cancelled', 'rejected', 'expired')
    where e.status in ('upcoming', 'ongoing')
      and e.capacity_grams is not null
      and e.received_weight_grams + e.reserved_weight_grams < e.capacity_grams
    group by e.id
    order by booking_count desc, e.start_at, e.id
    limit 20
  ) item;
  return jsonb_build_object(
    'profile_complete', v_profile.display_name <> '' and v_profile.phone_e164 is not null,
    'active_events', v_active, 'recommended_events', v_recommended, 'trending_events', v_trending
  );
end;
$$;

create or replace function api.user_dashboard_v1()
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.user_dashboard_impl() $$;

create or replace function private.create_account_booking_impl(
  p_actor_id uuid, p_event_id uuid, p_idempotency_key text, p_request_hash text, p_booking jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles;
  v_event public.events;
  v_booking public.bookings;
  v_existing public.idempotency_keys;
  v_response jsonb;
  v_expiry timestamptz;
  v_item jsonb;
begin
  if p_actor_id is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
  select * into v_profile from public.profiles where id = p_actor_id and account_role = 'donor';
  if not found then raise exception using errcode = '42501', message = 'ROLE_FORBIDDEN'; end if;
  if nullif(trim(v_profile.display_name), '') is null or v_profile.phone_e164 is null then
    raise exception using errcode = '23514', message = 'PROFILE_INCOMPLETE';
  end if;
  insert into public.idempotency_keys(scope, actor_scope, key, request_hash, resource_type)
  values ('create-account-booking', p_actor_id::text, p_idempotency_key, p_request_hash, 'booking')
  on conflict (scope, actor_scope, key) do nothing;
  if not found then
    select * into v_existing from public.idempotency_keys where scope = 'create-account-booking'
      and actor_scope = p_actor_id::text and key = p_idempotency_key for update;
    if v_existing.request_hash <> p_request_hash then raise exception using errcode = '23505', message = 'IDEMPOTENCY_CONFLICT'; end if;
    if v_existing.resource_id is not null then
      select * into v_booking from public.bookings where id = v_existing.resource_id;
      return jsonb_build_object('booking_id', v_booking.id, 'public_booking_id', v_booking.public_booking_id,
        'status', v_booking.status, 'expires_at', v_booking.expires_at,
        'qr_token_ciphertext', v_booking.qr_token_ciphertext, 'qr_token_nonce', v_booking.qr_token_nonce,
        'crypto_key_version', v_booking.crypto_key_version, 'event_snapshot', v_booking.event_snapshot,
        'idempotent_replay', true);
    end if;
  end if;
  select * into v_event from public.events where id = p_event_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND'; end if;
  if v_event.status not in ('upcoming', 'ongoing') or v_event.end_at <= now() then
    raise exception using errcode = 'P0001', message = 'EVENT_UNAVAILABLE';
  end if;
  if v_event.capacity_grams is null or v_event.max_donation_per_user_grams is null then
    raise exception using errcode = 'P0001', message = 'EVENT_UNAVAILABLE';
  end if;
  if (p_booking ->> 'estimated_weight_grams')::bigint <= 0
    or (p_booking ->> 'estimated_weight_grams')::bigint > v_event.max_donation_per_user_grams then
    raise exception using errcode = '23514', message = 'DONATION_LIMIT_EXCEEDED';
  end if;
  if jsonb_typeof(p_booking -> 'items') <> 'array' or jsonb_array_length(p_booking -> 'items') < 1
    or jsonb_array_length(p_booking -> 'items') > 100 then
    raise exception using errcode = '23514', message = 'INVALID_ITEMS';
  end if;
  if exists (select 1 from public.bookings where donor_user_id = p_actor_id and event_id = p_event_id
      and status not in ('cancelled', 'rejected', 'expired')) then
    raise exception using errcode = '23505', message = 'BOOKING_ALREADY_EXISTS';
  end if;
  if v_event.received_weight_grams + v_event.reserved_weight_grams
    + (p_booking ->> 'estimated_weight_grams')::bigint > v_event.capacity_grams then
    raise exception using errcode = 'P0001', message = 'CAPACITY_EXCEEDED';
  end if;
  v_expiry := v_event.end_at;
  insert into public.bookings(
    public_booking_id, event_id, workspace_id, donor_user_id,
    donor_name_ciphertext, donor_name_nonce, donor_phone_ciphertext, donor_phone_nonce,
    phone_lookup_hash, crypto_key_version, estimated_weight_grams, item_count,
    shipping_method, scan_model_version, status, event_snapshot, snapshot_schema_version,
    qr_token_hash, qr_token_ciphertext, qr_token_nonce, terms_version, privacy_version,
    consented_at, expires_at
  ) values (
    p_booking ->> 'public_booking_id', v_event.id, v_event.workspace_id, p_actor_id,
    p_booking ->> 'donor_name_ciphertext', p_booking ->> 'donor_name_nonce',
    p_booking ->> 'donor_phone_ciphertext', p_booking ->> 'donor_phone_nonce',
    p_booking ->> 'phone_lookup_hash', (p_booking ->> 'crypto_key_version')::smallint,
    (p_booking ->> 'estimated_weight_grams')::bigint, jsonb_array_length(p_booking -> 'items'),
    (p_booking ->> 'shipping_method')::public.shipping_method, p_booking ->> 'scan_model_version',
    'waiting', private.event_user_json(v_event), 2,
    p_booking ->> 'qr_token_hash', p_booking ->> 'qr_token_ciphertext', p_booking ->> 'qr_token_nonce',
    p_booking ->> 'terms_version', p_booking ->> 'privacy_version', now(), v_expiry
  ) returning * into v_booking;
  for v_item in select value from jsonb_array_elements(p_booking -> 'items') loop
    if coalesce((v_item ->> 'passed')::boolean, false) is not true then
      raise exception using errcode = '23514', message = 'ITEM_NOT_PASSED';
    end if;
    insert into public.booking_items(booking_id, ordinal, passed, scanner_model_version, metadata)
    values (v_booking.id, (v_item ->> 'ordinal')::smallint, true,
      coalesce(nullif(v_item ->> 'scanner_model_version', ''), v_booking.scan_model_version),
      coalesce(v_item -> 'metadata', '{}'::jsonb));
  end loop;
  update public.events set reserved_weight_grams = reserved_weight_grams + v_booking.estimated_weight_grams,
    version = version + 1 where id = v_event.id;
  insert into public.booking_status_events(booking_id, workspace_id, status, actor_type, actor_id, request_id)
  values (v_booking.id, v_booking.workspace_id, 'waiting', 'donor', p_actor_id,
    coalesce(nullif(p_booking ->> 'request_id', '')::uuid, gen_random_uuid()));
  insert into public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
  values ('donor', p_actor_id::text, v_booking.workspace_id, 'booking', v_booking.id, 'booking.created',
    coalesce(nullif(p_booking ->> 'request_id', '')::uuid, gen_random_uuid()));
  v_response := jsonb_build_object('booking_id', v_booking.id, 'public_booking_id', v_booking.public_booking_id,
    'status', v_booking.status, 'expires_at', v_booking.expires_at,
    'qr_token_ciphertext', v_booking.qr_token_ciphertext, 'qr_token_nonce', v_booking.qr_token_nonce,
    'crypto_key_version', v_booking.crypto_key_version, 'event_snapshot', v_booking.event_snapshot,
    'idempotent_replay', false);
  update public.idempotency_keys set resource_id = v_booking.id, response_payload = v_response
  where scope = 'create-account-booking' and actor_scope = p_actor_id::text and key = p_idempotency_key;
  return v_response;
end;
$$;

create or replace function api.create_account_booking_v2(
  p_actor_id uuid, p_event_id uuid, p_idempotency_key text, p_request_hash text, p_booking jsonb
)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.create_account_booking_impl(p_actor_id, p_event_id, p_idempotency_key, p_request_hash, p_booking) $$;

create or replace function private.cancel_account_booking_impl(
  p_actor_id uuid, p_booking_id uuid, p_idempotency_key text, p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_booking public.bookings;
declare v_event public.events;
declare v_existing public.idempotency_keys;
declare v_hash text := encode(extensions.digest(convert_to(jsonb_build_object('booking_id', p_booking_id)::text, 'UTF8'), 'sha256'), 'hex');
declare v_response jsonb;
begin
  if p_actor_id is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
  if nullif(trim(p_idempotency_key), '') is null then raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  insert into public.idempotency_keys(scope, actor_scope, key, request_hash, resource_type, resource_id)
  values ('cancel-account-booking', p_actor_id::text, p_idempotency_key, v_hash, 'booking', p_booking_id)
  on conflict (scope, actor_scope, key) do nothing;
  if not found then
    select * into v_existing from public.idempotency_keys where scope = 'cancel-account-booking'
      and actor_scope = p_actor_id::text and key = p_idempotency_key for update;
    if v_existing.request_hash <> v_hash then raise exception using errcode = '23505', message = 'IDEMPOTENCY_CONFLICT'; end if;
    if v_existing.response_payload is null then raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_INCOMPLETE'; end if;
    return v_existing.response_payload;
  end if;
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found or v_booking.donor_user_id <> p_actor_id then
    raise exception using errcode = 'P0002', message = 'BOOKING_NOT_FOUND';
  end if;
  if v_booking.status <> 'waiting' then raise exception using errcode = 'P0001', message = 'BOOKING_NOT_CANCELLABLE'; end if;
  select * into v_event from public.events where id = v_booking.event_id for update;
  update public.bookings set status = 'cancelled', terminal_at = now(), status_updated_at = now(),
    terminal_reason_code = 'donor_cancelled' where id = v_booking.id returning * into v_booking;
  update public.events set reserved_weight_grams = reserved_weight_grams - v_booking.estimated_weight_grams,
    version = version + 1 where id = v_event.id;
  insert into public.booking_status_events(booking_id, workspace_id, previous_status, status, actor_type, actor_id, request_id)
  values (v_booking.id, v_booking.workspace_id, 'waiting', 'cancelled', 'donor', p_actor_id, p_request_id);
  insert into public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
  values ('donor', p_actor_id::text, v_booking.workspace_id, 'booking', v_booking.id, 'booking.cancelled', p_request_id);
  v_response := jsonb_build_object('booking_id', v_booking.id, 'status', v_booking.status, 'hidden_from_operational_lists', true);
  update public.idempotency_keys set response_payload = v_response
  where scope = 'cancel-account-booking' and actor_scope = p_actor_id::text and key = p_idempotency_key;
  return v_response;
end;
$$;

create or replace function api.cancel_account_booking_v1(
  p_actor_id uuid, p_booking_id uuid, p_idempotency_key text, p_request_id uuid
)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.cancel_account_booking_impl(p_actor_id, p_booking_id, p_idempotency_key, p_request_id) $$;

create or replace function private.booking_detail_impl(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor_id uuid := auth.uid();
declare v_booking public.bookings;
begin
  if v_actor_id is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
  select * into v_booking from public.bookings where id = p_booking_id;
  if not found or (v_booking.donor_user_id <> v_actor_id and v_booking.workspace_id <> private.current_workspace_id()) then
    raise exception using errcode = 'P0002', message = 'BOOKING_NOT_FOUND';
  end if;
  return jsonb_build_object(
    'id', v_booking.id, 'public_booking_id', v_booking.public_booking_id,
    'status', v_booking.status, 'estimated_weight_grams', v_booking.estimated_weight_grams,
    'expires_at', v_booking.expires_at, 'event', v_booking.event_snapshot,
    'can_cancel', v_booking.donor_user_id = v_actor_id and v_booking.status = 'waiting',
    'timeline', coalesce((select jsonb_agg(jsonb_build_object(
      'previous_status', s.previous_status, 'status', s.status, 'actor_type', s.actor_type,
      'created_at', s.created_at) order by s.created_at, s.id)
      from public.booking_status_events s where s.booking_id = v_booking.id), '[]'::jsonb)
  );
end;
$$;

create or replace function api.booking_detail_v2(p_booking_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.booking_detail_impl(p_booking_id) $$;

alter table public.booking_status_events enable row level security;
create policy booking_status_events_select_admin on public.booking_status_events for select to authenticated
using (workspace_id = private.current_workspace_id());
create policy booking_status_events_select_donor on public.booking_status_events for select to authenticated
using (exists (select 1 from public.bookings b where b.id = booking_id and b.donor_user_id = auth.uid()));

revoke update, insert, delete on public.profiles, public.workspaces from authenticated;
revoke execute on function api.complete_onboarding_v1(public.app_role) from public, anon;
revoke execute on function api.update_user_profile_v1(text, text, text, text, double precision, double precision, text) from public, anon;
revoke execute on function api.update_workspace_profile_v1(text, text, text, text, text) from public, anon;
revoke execute on function api.upsert_event_draft_v2(uuid, uuid, jsonb) from public, anon;
revoke execute on function api.publish_event_v2(uuid, uuid) from public, anon;
revoke execute on function api.user_dashboard_v1() from public, anon;
revoke execute on function api.create_account_booking_v2(uuid, uuid, text, text, jsonb) from public, anon;
revoke execute on function api.cancel_account_booking_v1(uuid, uuid, text, uuid) from public, anon;
revoke execute on function api.booking_detail_v2(uuid) from public, anon;
grant execute on function api.complete_onboarding_v1(public.app_role) to authenticated, service_role;
grant execute on function api.update_user_profile_v1(text, text, text, text, double precision, double precision, text) to authenticated, service_role;
grant execute on function api.update_workspace_profile_v1(text, text, text, text, text) to authenticated, service_role;
grant execute on function api.upsert_event_draft_v2(uuid, uuid, jsonb) to authenticated, service_role;
grant execute on function api.publish_event_v2(uuid, uuid) to authenticated, service_role;
grant execute on function api.user_dashboard_v1() to authenticated, service_role;
grant execute on function api.create_account_booking_v2(uuid, uuid, text, text, jsonb) to service_role;
grant execute on function api.cancel_account_booking_v1(uuid, uuid, text, uuid) to service_role;
grant execute on function api.booking_detail_v2(uuid) to authenticated, service_role;

-- Lifecycle v2: waiting reservations are released exactly once when an event
-- ends. Accepted material deliberately remains operational until recycled.
create or replace function private.reconcile_events(p_workspace_id uuid default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_total bigint := 0; v_affected bigint := 0;
begin
  update public.events e set status = 'ongoing', version = e.version + 1
  where e.status = 'upcoming' and e.start_at <= now() and e.end_at > now()
    and (p_workspace_id is null or e.workspace_id = p_workspace_id);
  get diagnostics v_affected = row_count; v_total := v_total + v_affected;

  update public.bookings b set status = 'expired', terminal_at = now(),
    status_updated_at = now(), terminal_reason_code = 'event_completed'
  from public.events e where b.event_id = e.id and b.status = 'waiting'
    and e.end_at <= now() and (p_workspace_id is null or b.workspace_id = p_workspace_id);
  get diagnostics v_affected = row_count; v_total := v_total + v_affected;

  update public.events e set reserved_weight_grams = greatest(0, e.reserved_weight_grams - x.weight),
    version = e.version + 1
  from (select b.event_id, sum(b.estimated_weight_grams) as weight from public.bookings b
    where b.status = 'expired' and b.terminal_reason_code = 'event_completed'
      and b.status_updated_at >= now() - interval '1 minute'
    group by b.event_id) x where e.id = x.event_id;
  -- Recalculate from authoritative booking rows as a defensive correction for
  -- jobs interrupted between a status and capacity update in an old release.
  update public.events e set reserved_weight_grams = coalesce(x.weight, 0)
  from (select e2.id, sum(b.estimated_weight_grams) filter (where b.status = 'waiting') as weight
    from public.events e2 left join public.bookings b on b.event_id = e2.id
    where p_workspace_id is null or e2.workspace_id = p_workspace_id group by e2.id) x
  where e.id = x.id and e.reserved_weight_grams is distinct from coalesce(x.weight, 0);
  return v_total;
end; $$;

create or replace function private.decide_reception_v2_impl(
  p_booking_id uuid, p_decision public.reception_decision, p_actual_weight_grams bigint,
  p_idempotency_key text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := private.require_role('admin'); v_workspace uuid := private.current_workspace_id();
  v_booking public.bookings; v_event public.events; v_existing public.idempotency_keys;
  v_hash text := encode(extensions.digest(convert_to(jsonb_build_object('booking_id',p_booking_id,'decision',p_decision,'actual_weight_grams',p_actual_weight_grams)::text,'UTF8'),'sha256'),'hex');
  v_response jsonb;
begin
  if nullif(trim(p_idempotency_key), '') is null then raise exception using errcode='22023', message='IDEMPOTENCY_KEY_REQUIRED'; end if;
  insert into public.idempotency_keys(scope,actor_scope,key,request_hash,resource_type,resource_id)
  values ('reception-v2',v_actor::text,p_idempotency_key,v_hash,'booking',p_booking_id)
  on conflict (scope,actor_scope,key) do nothing;
  if not found then
    select * into v_existing from public.idempotency_keys where scope='reception-v2' and actor_scope=v_actor::text and key=p_idempotency_key for update;
    if v_existing.request_hash <> v_hash then raise exception using errcode='23505', message='IDEMPOTENCY_CONFLICT'; end if;
    if v_existing.response_payload is null then raise exception using errcode='P0001', message='IDEMPOTENCY_INCOMPLETE'; end if;
    return v_existing.response_payload;
  end if;
  perform private.reconcile_events(v_workspace);
  select * into v_booking from public.bookings where id=p_booking_id and workspace_id=v_workspace for update;
  if not found then raise exception using errcode='P0002',message='BOOKING_NOT_FOUND'; end if;
  if v_booking.status <> 'waiting' then raise exception using errcode='P0001',message='BOOKING_NOT_PROCESSABLE'; end if;
  select * into v_event from public.events where id=v_booking.event_id for update;
  if v_event.status <> 'ongoing' or v_event.end_at <= now() then raise exception using errcode='P0001',message='EVENT_NOT_OPERATIONAL'; end if;
  if p_decision = 'accepted' then
    if p_actual_weight_grams is null or p_actual_weight_grams <= 0 then raise exception using errcode='23514',message='INVALID_ACTUAL_WEIGHT'; end if;
    if p_actual_weight_grams > v_event.max_donation_per_user_grams then raise exception using errcode='23514',message='DONATION_LIMIT_EXCEEDED'; end if;
    if v_event.received_weight_grams + v_event.reserved_weight_grams - v_booking.estimated_weight_grams + p_actual_weight_grams > v_event.capacity_grams then raise exception using errcode='23514',message='CAPACITY_EXCEEDED'; end if;
    insert into public.receptions(booking_id,workspace_id,event_id,decision,actual_weight_grams,processed_by)
      values(v_booking.id,v_workspace,v_event.id,'accepted',p_actual_weight_grams,v_actor);
    update public.events set received_weight_grams=received_weight_grams+p_actual_weight_grams,
      reserved_weight_grams=reserved_weight_grams-v_booking.estimated_weight_grams,version=version+1 where id=v_event.id;
    update public.bookings set status='accepted',status_updated_at=now() where id=v_booking.id returning * into v_booking;
  else
    if p_actual_weight_grams is not null then raise exception using errcode='23514',message='INVALID_REJECTION'; end if;
    insert into public.receptions(booking_id,workspace_id,event_id,decision,processed_by)
      values(v_booking.id,v_workspace,v_event.id,'rejected',v_actor);
    update public.events set reserved_weight_grams=reserved_weight_grams-v_booking.estimated_weight_grams,version=version+1 where id=v_event.id;
    update public.bookings set status='rejected',terminal_at=now(),status_updated_at=now(),terminal_reason_code='admin_rejected' where id=v_booking.id returning * into v_booking;
  end if;
  insert into public.booking_status_events(booking_id,workspace_id,previous_status,status,actor_type,actor_id,request_id)
    values(v_booking.id,v_workspace,'waiting',v_booking.status,'admin',v_actor,p_request_id);
  insert into public.audit_events(actor_type,actor_id,workspace_id,entity_type,entity_id,action_code,request_id)
    values('admin',v_actor::text,v_workspace,'booking',v_booking.id,'booking.'||v_booking.status::text,p_request_id);
  v_response:=jsonb_build_object('booking_id',v_booking.id,'public_booking_id',v_booking.public_booking_id,'status',v_booking.status);
  update public.idempotency_keys set response_payload=v_response where scope='reception-v2' and actor_scope=v_actor::text and key=p_idempotency_key;
  return v_response;
end; $$;

create or replace function api.decide_reception_v2(uuid,public.reception_decision,bigint,text,uuid)
returns jsonb language sql security definer set search_path='' as $$ select private.decide_reception_v2_impl($1,$2,$3,$4,$5) $$;

create or replace function private.advance_booking_status_impl(p_booking_id uuid,p_status public.booking_status,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=private.require_role('admin'); v_workspace uuid:=private.current_workspace_id(); v_booking public.bookings;
begin
  select * into v_booking from public.bookings where id=p_booking_id and workspace_id=v_workspace for update;
  if not found then raise exception using errcode='P0002',message='BOOKING_NOT_FOUND'; end if;
  if (v_booking.status='accepted' and p_status='processed') or (v_booking.status='processed' and p_status='recycled') then null;
  else raise exception using errcode='P0001',message='INVALID_BOOKING_TRANSITION'; end if;
  update public.bookings set status=p_status,status_updated_at=now(),terminal_at=case when p_status='recycled' then now() else null end where id=v_booking.id returning * into v_booking;
  insert into public.booking_status_events(booking_id,workspace_id,previous_status,status,actor_type,actor_id,request_id) values(v_booking.id,v_workspace,case when p_status='processed' then 'accepted'::public.booking_status else 'processed'::public.booking_status end,p_status,'admin',v_actor,p_request_id);
  insert into public.audit_events(actor_type,actor_id,workspace_id,entity_type,entity_id,action_code,request_id) values('admin',v_actor::text,v_workspace,'booking',v_booking.id,'booking.'||p_status::text,p_request_id);
  return jsonb_build_object('booking_id',v_booking.id,'status',v_booking.status,'status_updated_at',v_booking.status_updated_at);
end; $$;
create or replace function api.advance_booking_status_v1(uuid,public.booking_status,uuid) returns jsonb language sql security definer set search_path='' as $$ select private.advance_booking_status_impl($1,$2,$3) $$;

create or replace function private.booking_history_impl(p_scope text,p_event_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_workspace uuid:=private.current_workspace_id();
begin
  if v_actor is null then raise exception using errcode='42501',message='AUTH_REQUIRED'; end if;
  if p_scope='donor' then perform private.require_role('donor');
  elsif p_scope='admin' then perform private.require_role('admin'); else raise exception using errcode='22023',message='INVALID_SCOPE'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('booking_id',b.id,'public_booking_id',b.public_booking_id,'status',b.status,'estimated_weight_grams',b.estimated_weight_grams,'actual_weight_grams',r.actual_weight_grams,'event',b.event_snapshot,'created_at',b.created_at,'status_updated_at',b.status_updated_at) order by b.created_at desc)
    from public.bookings b left join public.receptions r on r.booking_id=b.id
    where (p_scope='donor' and b.donor_user_id=v_actor or p_scope='admin' and b.workspace_id=v_workspace)
      and (p_event_id is null or b.event_id=p_event_id)
      and b.status in ('accepted','processed','recycled')), '[]'::jsonb);
end; $$;
create or replace function api.user_donation_history_v1() returns jsonb language sql security definer set search_path='' as $$ select private.booking_history_impl('donor') $$;
create or replace function api.admin_donation_history_v1(p_event_id uuid default null) returns jsonb language sql security definer set search_path='' as $$ select private.booking_history_impl('admin',$1) $$;
create or replace function private.event_history_impl(p_scope text,p_event_id uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_workspace uuid:=private.current_workspace_id();
begin
  if p_scope='donor' then perform private.require_role('donor'); elsif p_scope='admin' then perform private.require_role('admin'); else raise exception using errcode='22023',message='INVALID_SCOPE'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('booking_id',b.id,'public_booking_id',b.public_booking_id,'status',b.status,'estimated_weight_grams',b.estimated_weight_grams,'actual_weight_grams',r.actual_weight_grams,'event',b.event_snapshot,'created_at',b.created_at,'status_updated_at',b.status_updated_at) order by b.created_at desc) from public.bookings b left join public.receptions r on r.booking_id=b.id where ((p_scope='donor' and b.donor_user_id=v_actor) or (p_scope='admin' and b.workspace_id=v_workspace)) and (p_event_id is null or b.event_id=p_event_id) and b.status <> 'cancelled'),'[]'::jsonb);
end; $$;
create or replace function api.user_event_history_v1() returns jsonb language sql security definer set search_path='' as $$ select private.event_history_impl('donor') $$;
create or replace function api.admin_event_history_v1(p_event_id uuid default null) returns jsonb language sql security definer set search_path='' as $$ select private.event_history_impl('admin',$1) $$;

create or replace function private.admin_recap_v2_impl(p_days integer default 7) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_workspace uuid:=private.current_workspace_id(); v_start date:=(now() at time zone 'Asia/Jakarta')::date-greatest(1,least(coalesce(p_days,7),31))+1;
begin
  perform private.require_role('admin');
  return jsonb_build_object('daily',coalesce((select jsonb_agg(jsonb_build_object('date',d.day,'accepted_weight_grams',coalesce(x.weight,0),'accepted_count',coalesce(x.count,0)) order by d.day) from generate_series(v_start,(now() at time zone 'Asia/Jakarta')::date,interval '1 day') d(day) left join lateral (select sum(r.actual_weight_grams) weight,count(*) count from public.receptions r where r.workspace_id=v_workspace and r.decision='accepted' and (r.processed_at at time zone 'Asia/Jakarta')::date=d.day::date) x on true),'[]'::jsonb), 'month',coalesce((select jsonb_build_object('accepted_weight_grams',sum(r.actual_weight_grams),'accepted_count',count(*)) from public.receptions r where r.workspace_id=v_workspace and r.decision='accepted' and date_trunc('month',r.processed_at at time zone 'Asia/Jakarta')=date_trunc('month',now() at time zone 'Asia/Jakarta')),jsonb_build_object('accepted_weight_grams',0,'accepted_count',0)));
end; $$;
create or replace function api.admin_recap_v2(p_days integer default 7) returns jsonb language sql security definer set search_path='' as $$ select private.admin_recap_v2_impl($1) $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
  ('profile-avatars','profile-avatars',false,5242880,array['image/jpeg','image/png']),
  ('workspace-logos','workspace-logos',true,5242880,array['image/jpeg','image/png'])
on conflict(id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy profile_avatars_owner_select on storage.objects for select to authenticated using(bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy profile_avatars_owner_insert on storage.objects for insert to authenticated with check(bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy profile_avatars_owner_update on storage.objects for update to authenticated using(bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text) with check(bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy profile_avatars_owner_delete on storage.objects for delete to authenticated using(bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy workspace_logos_public_read on storage.objects for select to anon,authenticated using(bucket_id='workspace-logos');
create policy workspace_logos_admin_write on storage.objects for all to authenticated using(bucket_id='workspace-logos' and (storage.foldername(name))[1]=private.current_workspace_id()::text) with check(bucket_id='workspace-logos' and (storage.foldername(name))[1]=private.current_workspace_id()::text);

revoke execute on function api.decide_reception_v2(uuid,public.reception_decision,bigint,text,uuid) from public,anon;
revoke execute on function api.advance_booking_status_v1(uuid,public.booking_status,uuid) from public,anon;
revoke execute on function api.user_donation_history_v1() from public,anon;
revoke execute on function api.user_event_history_v1() from public,anon;
revoke execute on function api.admin_donation_history_v1(uuid) from public,anon;
revoke execute on function api.admin_event_history_v1(uuid) from public,anon;
revoke execute on function api.admin_recap_v2(integer) from public,anon;
grant execute on function api.decide_reception_v2(uuid,public.reception_decision,bigint,text,uuid),api.advance_booking_status_v1(uuid,public.booking_status,uuid),api.user_donation_history_v1(),api.user_event_history_v1(),api.admin_donation_history_v1(uuid),api.admin_event_history_v1(uuid),api.admin_recap_v2(integer) to authenticated,service_role;
