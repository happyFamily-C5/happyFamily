-- PostgreSQL does not infer an enum type for a CASE composed solely of text
-- literals. Recreate the v2 publisher with explicit event_status values.
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
    status = case when start_at <= now() then 'ongoing'::public.event_status else 'upcoming'::public.event_status end,
    published_at = now(), version = version + 1
  where id = v_event.id returning * into v_event;
  insert into public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
  values ('admin', v_actor_id::text, v_workspace.id, 'event', v_event.id, 'event.published', p_request_id);
  return private.event_user_json(v_event);
end;
$$;

drop policy if exists booking_status_events_select_admin on public.booking_status_events;
drop policy if exists booking_status_events_select_donor on public.booking_status_events;
create policy booking_status_events_select_visible on public.booking_status_events
for select to authenticated
using (
  workspace_id = private.current_workspace_id()
  or exists (
    select 1 from public.bookings as b
    where b.id = booking_status_events.booking_id
      and b.donor_user_id = (select auth.uid())
  )
);
