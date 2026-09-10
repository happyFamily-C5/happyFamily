-- Discovery contract: authenticated donor event detail. The response carries the
-- capacity breakdown from event_user_json plus explicit availability fields so
-- the client never recomputes booking eligibility from partial data.

create or replace function private.event_detail_impl(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  if not found then
    raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND';
  end if;
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
      v_event.capacity_grams is not null
        and v_event.received_weight_grams + v_event.reserved_weight_grams < v_event.capacity_grams
        and v_event.end_at > now(),
      'available_weight_grams',
      case when v_event.capacity_grams is null then null
        else greatest(
          v_event.capacity_grams - v_event.received_weight_grams - v_event.reserved_weight_grams, 0
        ) end
    ),
    'already_booked', v_booked
  );
end;
$$;

create or replace function api.event_detail_v2(p_event_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.event_detail_impl(p_event_id) $$;

revoke execute on function api.event_detail_v2(uuid) from public, anon;
grant execute on function api.event_detail_v2(uuid) to authenticated, service_role;
