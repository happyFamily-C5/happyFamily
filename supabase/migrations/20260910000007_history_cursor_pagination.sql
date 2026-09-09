-- Cursor pagination for the booking/event history contracts. Callers that pass
-- no limit and no cursor keep receiving the legacy plain array; paginated
-- callers receive { items, next_cursor } keyed on (created_at, id) descending,
-- which is stable across pages because booking ids are unique sort keys.

create or replace function private.encode_history_cursor(
  p_created_at timestamptz,
  p_id uuid
)
returns text
language sql
immutable
set search_path = ''
as $$
  select rtrim(translate(
    replace(replace(encode(convert_to(jsonb_build_object(
      'created_at', p_created_at,
      'id', p_id
    )::text, 'UTF8'), 'base64'), E'\n', ''), E'\r', ''),
    '+/', '-_'
  ), '=')
$$;

create or replace function private.decode_history_cursor(p_cursor text)
returns table(created_at timestamptz, id uuid)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_base64 text;
  v_payload jsonb;
begin
  if p_cursor is null or length(p_cursor) < 12 or length(p_cursor) > 512
    or p_cursor !~ '^[A-Za-z0-9_-]+$'
  then
    raise exception using errcode = '22023', message = 'CURSOR_INVALID';
  end if;
  v_base64 := replace(replace(p_cursor, '-', '+'), '_', '/');
  v_base64 := v_base64 || repeat('=', (4 - length(v_base64) % 4) % 4);
  v_payload := convert_from(decode(v_base64, 'base64'), 'UTF8')::jsonb;
  if jsonb_typeof(v_payload) <> 'object'
    or not v_payload ?& array['created_at', 'id']
  then
    raise exception using errcode = '22023', message = 'CURSOR_INVALID';
  end if;
  return query
    select (v_payload ->> 'created_at')::timestamptz, (v_payload ->> 'id')::uuid;
end;
$$;

drop function if exists private.booking_history_impl(text, uuid);

create or replace function private.booking_history_impl(
  p_scope text,
  p_event_id uuid,
  p_limit integer,
  p_cursor text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_workspace uuid := private.current_workspace_id();
  v_after_created_at timestamptz;
  v_after_id uuid;
  v_return_limit integer;
  v_fetch integer;
  v_items jsonb;
  v_fetched bigint;
  v_last_created_at timestamptz;
  v_last_id uuid;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  if p_scope = 'donor' then perform private.require_role('donor');
  elsif p_scope = 'admin' then perform private.require_role('admin');
  else raise exception using errcode = '22023', message = 'INVALID_SCOPE';
  end if;
  if p_cursor is not null then
    select * into v_after_created_at, v_after_id from private.decode_history_cursor(p_cursor);
  end if;
  if p_limit is not null then
    v_return_limit := least(greatest(p_limit, 1), 100);
    v_fetch := v_return_limit + 1;
  end if;
  with page as (
    select jsonb_build_object(
      'booking_id', b.id,
      'public_booking_id', b.public_booking_id,
      'status', b.status,
      'estimated_weight_grams', b.estimated_weight_grams,
      'actual_weight_grams', r.actual_weight_grams,
      'event', b.event_snapshot,
      'created_at', b.created_at,
      'status_updated_at', b.status_updated_at
    ) as item,
      b.created_at as sort_created_at,
      b.id as sort_id
    from public.bookings as b
    left join public.receptions as r on r.booking_id = b.id
    where (p_scope = 'donor' and b.donor_user_id = v_actor
        or p_scope = 'admin' and b.workspace_id = v_workspace)
      and (p_event_id is null or b.event_id = p_event_id)
      and b.status in ('accepted', 'processed', 'recycled')
      and (v_after_created_at is null
        or (b.created_at, b.id) < (v_after_created_at, v_after_id))
    order by b.created_at desc, b.id desc
    limit v_fetch
  )
  select
    coalesce(jsonb_agg(page.item order by page.sort_created_at desc, page.sort_id desc), '[]'::jsonb),
    count(*),
    (array_agg(page.sort_created_at order by page.sort_created_at desc, page.sort_id desc))[
      least(count(*), v_return_limit)::int
    ],
    (array_agg(page.sort_id order by page.sort_created_at desc, page.sort_id desc))[
      least(count(*), v_return_limit)::int
    ]
  into v_items, v_fetched, v_last_created_at, v_last_id
  from page;

  if p_limit is null and p_cursor is null then
    return v_items;
  end if;
  return jsonb_build_object(
    'items', v_items,
    'next_cursor', case
      when v_return_limit is not null and v_fetched > v_return_limit
        then private.encode_history_cursor(v_last_created_at, v_last_id)
      else null end
  );
end;
$$;

drop function if exists private.event_history_impl(text, uuid);

create or replace function private.event_history_impl(
  p_scope text,
  p_event_id uuid,
  p_limit integer,
  p_cursor text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_workspace uuid := private.current_workspace_id();
  v_after_created_at timestamptz;
  v_after_id uuid;
  v_return_limit integer;
  v_fetch integer;
  v_items jsonb;
  v_fetched bigint;
  v_last_created_at timestamptz;
  v_last_id uuid;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  if p_scope = 'donor' then perform private.require_role('donor');
  elsif p_scope = 'admin' then perform private.require_role('admin');
  else raise exception using errcode = '22023', message = 'INVALID_SCOPE';
  end if;
  if p_cursor is not null then
    select * into v_after_created_at, v_after_id from private.decode_history_cursor(p_cursor);
  end if;
  if p_limit is not null then
    v_return_limit := least(greatest(p_limit, 1), 100);
    v_fetch := v_return_limit + 1;
  end if;
  with page as (
    select jsonb_build_object(
      'booking_id', b.id,
      'public_booking_id', b.public_booking_id,
      'status', b.status,
      'estimated_weight_grams', b.estimated_weight_grams,
      'actual_weight_grams', r.actual_weight_grams,
      'event', b.event_snapshot,
      'created_at', b.created_at,
      'status_updated_at', b.status_updated_at
    ) as item,
      b.created_at as sort_created_at,
      b.id as sort_id
    from public.bookings as b
    left join public.receptions as r on r.booking_id = b.id
    where (p_scope = 'donor' and b.donor_user_id = v_actor
        or p_scope = 'admin' and b.workspace_id = v_workspace)
      and (p_event_id is null or b.event_id = p_event_id)
      and b.status <> 'cancelled'
      and (v_after_created_at is null
        or (b.created_at, b.id) < (v_after_created_at, v_after_id))
    order by b.created_at desc, b.id desc
    limit v_fetch
  )
  select
    coalesce(jsonb_agg(page.item order by page.sort_created_at desc, page.sort_id desc), '[]'::jsonb),
    count(*),
    (array_agg(page.sort_created_at order by page.sort_created_at desc, page.sort_id desc))[
      least(count(*), v_return_limit)::int
    ],
    (array_agg(page.sort_id order by page.sort_created_at desc, page.sort_id desc))[
      least(count(*), v_return_limit)::int
    ]
  into v_items, v_fetched, v_last_created_at, v_last_id
  from page;

  if p_limit is null and p_cursor is null then
    return v_items;
  end if;
  return jsonb_build_object(
    'items', v_items,
    'next_cursor', case
      when v_return_limit is not null and v_fetched > v_return_limit
        then private.encode_history_cursor(v_last_created_at, v_last_id)
      else null end
  );
end;
$$;

drop function if exists api.user_donation_history_v1();
create or replace function api.user_donation_history_v1(
  p_limit integer default null,
  p_cursor text default null
)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.booking_history_impl('donor', null, p_limit, p_cursor) $$;

drop function if exists api.admin_donation_history_v1(uuid);
create or replace function api.admin_donation_history_v1(
  p_event_id uuid default null,
  p_limit integer default null,
  p_cursor text default null
)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.booking_history_impl('admin', p_event_id, p_limit, p_cursor) $$;

drop function if exists api.user_event_history_v1();
create or replace function api.user_event_history_v1(
  p_limit integer default null,
  p_cursor text default null
)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.event_history_impl('donor', null, p_limit, p_cursor) $$;

drop function if exists api.admin_event_history_v1(uuid);
create or replace function api.admin_event_history_v1(
  p_event_id uuid default null,
  p_limit integer default null,
  p_cursor text default null
)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.event_history_impl('admin', p_event_id, p_limit, p_cursor) $$;

revoke execute on function api.user_donation_history_v1(integer, text) from public, anon;
revoke execute on function api.admin_donation_history_v1(uuid, integer, text) from public, anon;
revoke execute on function api.user_event_history_v1(integer, text) from public, anon;
revoke execute on function api.admin_event_history_v1(uuid, integer, text) from public, anon;
grant execute on function api.user_donation_history_v1(integer, text) to authenticated, service_role;
grant execute on function api.admin_donation_history_v1(uuid, integer, text) to authenticated, service_role;
grant execute on function api.user_event_history_v1(integer, text) to authenticated, service_role;
grant execute on function api.admin_event_history_v1(uuid, integer, text) to authenticated, service_role;
