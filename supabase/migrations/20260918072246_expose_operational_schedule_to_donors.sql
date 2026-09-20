-- Donor event payloads previously omitted the explicit operational schedule,
-- causing clients to infer opening hours from event start/end timestamps.
-- Keep one canonical event_user_json shape for dashboard, detail, and booking
-- snapshots while exposing the same local schedule that Admin reads.
create or replace function private.event_user_json(
  p_event public.events,
  p_distance_km double precision default null
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_event.id, 'name', p_event.name, 'description', p_event.description,
    'status', p_event.status, 'start_at', p_event.start_at, 'end_at', p_event.end_at,
    'timezone_name', p_event.timezone_name,
    'operational_days', p_event.operational_days,
    'opens_at_local', p_event.opens_at_local,
    'closes_at_local', p_event.closes_at_local,
    'location_name', p_event.location_name,
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
