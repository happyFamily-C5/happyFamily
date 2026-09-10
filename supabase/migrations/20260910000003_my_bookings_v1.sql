-- Donor booking list contract. Hidden cancelled bookings stay excluded; every
-- remaining lifecycle state is visible so tracking and history screens can be
-- served from one endpoint.

create or replace function private.my_bookings_impl()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_role('donor');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'booking_id', b.id,
      'public_booking_id', b.public_booking_id,
      'status', b.status,
      'estimated_weight_grams', b.estimated_weight_grams,
      'actual_weight_grams', r.actual_weight_grams,
      'expires_at', b.expires_at,
      'event', b.event_snapshot,
      'can_cancel', b.status = 'waiting',
      'created_at', b.created_at,
      'status_updated_at', b.status_updated_at
    ) order by b.created_at desc, b.id desc)
    from public.bookings as b
    left join public.receptions as r on r.booking_id = b.id
    where b.donor_user_id = v_actor_id
      and b.status <> 'cancelled'
  ), '[]'::jsonb);
end;
$$;

create or replace function api.my_bookings_v1()
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.my_bookings_impl() $$;

revoke execute on function api.my_bookings_v1() from public, anon;
grant execute on function api.my_bookings_v1() to authenticated, service_role;
