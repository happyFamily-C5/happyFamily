-- As with automatic completion, the event guard makes terminal rows immutable.
-- Release all waiting reservation in the transition itself.
create or replace function private.cancel_or_delete_event_v2_impl(
  p_event_id uuid,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_role('admin');
  v_workspace uuid := private.current_workspace_id();
  v_event public.events;
  v_cancelled_count bigint := 0;
begin
  perform private.reconcile_events(v_workspace);
  select * into v_event from public.events
  where id = p_event_id and workspace_id = v_workspace
  for update;
  if not found then raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND'; end if;

  if v_event.status = 'draft' then
    if exists (select 1 from public.bookings where event_id = v_event.id) then
      raise exception using errcode = 'P0001', message = 'DRAFT_HAS_BOOKINGS';
    end if;
    insert into public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
    values ('admin', v_actor::text, v_workspace, 'event', v_event.id, 'event.draft_deleted', p_request_id);
    delete from public.events where id = v_event.id;
    return jsonb_build_object('event_id', p_event_id, 'action', 'draft_deleted');
  end if;

  if v_event.status not in ('upcoming', 'ongoing') then
    raise exception using errcode = 'P0001', message = 'EVENT_NOT_CANCELLABLE';
  end if;

  update public.events
  set status = 'cancelled', terminal_at = now(), terminal_reason = 'admin_cancelled',
    reserved_weight_grams = 0, version = version + 1
  where id = v_event.id
  returning * into v_event;

  with cancelled as (
    update public.bookings
    set status = 'cancelled', terminal_at = now(), status_updated_at = now(),
      terminal_reason_code = 'event_cancelled'
    where event_id = v_event.id and status = 'waiting'
    returning id, workspace_id
  ), timeline as (
    insert into public.booking_status_events(
      booking_id, workspace_id, previous_status, status, actor_type, actor_id, request_id, metadata
    )
    select id, workspace_id, 'waiting', 'cancelled', 'admin', v_actor, p_request_id,
      jsonb_build_object('reason', 'event_cancelled')
    from cancelled
  ), audited as (
    insert into public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
    select 'admin', v_actor::text, workspace_id, 'booking', id, 'booking.cancelled', p_request_id
    from cancelled
  )
  select count(*) into v_cancelled_count from cancelled;

  insert into public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
  values ('admin', v_actor::text, v_workspace, 'event', v_event.id, 'event.cancelled', p_request_id);
  return jsonb_build_object(
    'event_id', v_event.id, 'status', v_event.status,
    'cancelled_waiting_bookings', v_cancelled_count
  );
end;
$$;
