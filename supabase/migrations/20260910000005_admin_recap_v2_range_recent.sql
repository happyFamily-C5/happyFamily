-- Recap contract completes the Sketch Rekap Bulanan cards: explicit from/to
-- calendar ranges, optional event scoping, the latest accepted donations, and
-- the unique donor count for the running month. p_days remains the default
-- window so existing callers keep their behaviour.

drop function if exists api.admin_recap_v2(integer);

create or replace function private.admin_recap_v2_impl(
  p_event_id uuid,
  p_from date,
  p_to date,
  p_days integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_workspace uuid := private.current_workspace_id();
  v_from date;
  v_to date;
begin
  perform private.require_role('admin');
  v_to := coalesce(p_to, (now() at time zone 'Asia/Jakarta')::date);
  v_from := coalesce(
    p_from,
    v_to - greatest(1, least(coalesce(p_days, 7), 31)) + 1
  );
  if v_from > v_to then
    raise exception using errcode = '22023', message = 'INVALID_DATE_RANGE';
  end if;
  return jsonb_build_object(
    'daily', coalesce((
      select jsonb_agg(jsonb_build_object(
        'date', d.day::date,
        'accepted_weight_grams', coalesce(x.weight, 0),
        'accepted_count', coalesce(x.count, 0)
      ) order by d.day)
      from generate_series(v_from, v_to, interval '1 day') as d(day)
      left join lateral (
        select sum(r.actual_weight_grams) as weight, count(*) as count
        from public.receptions as r
        where r.workspace_id = v_workspace
          and r.decision = 'accepted'
          and (p_event_id is null or r.event_id = p_event_id)
          and (r.processed_at at time zone 'Asia/Jakarta')::date = d.day::date
      ) as x on true
    ), '[]'::jsonb),
    'month', coalesce((
      select jsonb_build_object(
        'accepted_weight_grams', coalesce(sum(r.actual_weight_grams), 0),
        'accepted_count', count(*),
        'unique_donor_count', count(distinct b.donor_user_id)
      )
      from public.receptions as r
      join public.bookings as b on b.id = r.booking_id
      where r.workspace_id = v_workspace
        and r.decision = 'accepted'
        and (p_event_id is null or r.event_id = p_event_id)
        and date_trunc('month', r.processed_at at time zone 'Asia/Jakarta')
          = date_trunc('month', now() at time zone 'Asia/Jakarta')
    ), jsonb_build_object(
      'accepted_weight_grams', 0,
      'accepted_count', 0,
      'unique_donor_count', 0
    )),
    'recent_donations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'booking_id', x.booking_id,
        'public_booking_id', x.public_booking_id,
        'donor_name', x.donor_name,
        'actual_weight_grams', x.actual_weight_grams,
        'event_name', x.event_name,
        'received_at', x.received_at
      ) order by x.received_at desc)
      from (
        select b.id as booking_id, b.public_booking_id,
          p.display_name as donor_name,
          r.actual_weight_grams,
          e.name as event_name,
          r.processed_at as received_at
        from public.receptions as r
        join public.bookings as b on b.id = r.booking_id
        join public.events as e on e.id = r.event_id
        left join public.profiles as p on p.id = b.donor_user_id
        where r.workspace_id = v_workspace
          and r.decision = 'accepted'
          and (p_event_id is null or r.event_id = p_event_id)
        order by r.processed_at desc, b.id desc
        limit 5
      ) as x
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function api.admin_recap_v2(
  p_event_id uuid default null,
  p_from date default null,
  p_to date default null,
  p_days integer default 7
)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.admin_recap_v2_impl(p_event_id, p_from, p_to, p_days) $$;

revoke execute on function api.admin_recap_v2(uuid, date, date, integer) from public, anon;
grant execute on function api.admin_recap_v2(uuid, date, date, integer) to authenticated, service_role;
