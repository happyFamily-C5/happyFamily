-- Complete the authenticated Account booking boundary and event lifecycle.
-- All state-changing functions require a role from the server-controlled
-- profile row; the service-only account booking RPC continues to receive its
-- protected fields exclusively from the authenticated Edge Function.

create or replace function private.reconcile_events(p_workspace_id uuid default null)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total bigint := 0;
  v_completed bigint := 0;
  v_expired bigint := 0;
begin
  with completed as (
    update public.events e
    set status = 'completed', terminal_at = now(), terminal_reason = 'event_completed',
      version = e.version + 1
    where e.status in ('upcoming', 'ongoing') and e.end_at <= now()
      and (p_workspace_id is null or e.workspace_id = p_workspace_id)
    returning e.id, e.workspace_id
  ), audited as (
    insert into public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
    select 'system', null, workspace_id, 'event', id, 'event.completed', gen_random_uuid()
    from completed
  )
  select count(*) into v_completed from completed;

  with expired as (
    update public.bookings b
    set status = 'expired', terminal_at = now(), status_updated_at = now(),
      terminal_reason_code = 'event_completed'
    from public.events e
    where b.event_id = e.id and b.status = 'waiting' and e.status = 'completed'
      and (p_workspace_id is null or b.workspace_id = p_workspace_id)
    returning b.id, b.workspace_id
  ), timeline as (
    insert into public.booking_status_events(
      booking_id, workspace_id, previous_status, status, actor_type, actor_id, request_id, metadata
    )
    select id, workspace_id, 'waiting', 'expired', 'system', null, gen_random_uuid(),
      jsonb_build_object('reason', 'event_completed')
    from expired
  ), audited as (
    insert into public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
    select 'system', null, workspace_id, 'booking', id, 'booking.expired', gen_random_uuid()
    from expired
  )
  select count(*) into v_expired from expired;

  update public.events e
  set status = 'ongoing', version = e.version + 1
  where e.status = 'upcoming' and e.start_at <= now() and e.end_at > now()
    and (p_workspace_id is null or e.workspace_id = p_workspace_id);

  -- Authoritative recomputation makes retries and interrupted legacy jobs safe.
  update public.events e
  set reserved_weight_grams = coalesce(x.weight, 0), version = e.version + 1
  from (
    select e2.id, sum(b.estimated_weight_grams) filter (where b.status = 'waiting') as weight
    from public.events e2
    left join public.bookings b on b.event_id = e2.id
    where p_workspace_id is null or e2.workspace_id = p_workspace_id
    group by e2.id
  ) x
  where e.id = x.id and e.reserved_weight_grams is distinct from coalesce(x.weight, 0);

  return v_completed + v_expired;
end;
$$;

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
    version = version + 1
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

  update public.events e
  set reserved_weight_grams = coalesce(x.weight, 0), version = e.version + 1
  from (
    select sum(b.estimated_weight_grams) filter (where b.status = 'waiting') as weight
    from public.bookings b where b.event_id = v_event.id
  ) x
  where e.id = v_event.id and e.reserved_weight_grams is distinct from coalesce(x.weight, 0);

  insert into public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
  values ('admin', v_actor::text, v_workspace, 'event', v_event.id, 'event.cancelled', p_request_id);
  return jsonb_build_object(
    'event_id', v_event.id, 'status', v_event.status,
    'cancelled_waiting_bookings', v_cancelled_count
  );
end;
$$;

create or replace function api.cancel_or_delete_event_v2(p_event_id uuid, p_request_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.cancel_or_delete_event_v2_impl(p_event_id, p_request_id) $$;

revoke execute on function api.cancel_or_delete_event_v2(uuid, uuid) from public, anon;
grant execute on function api.cancel_or_delete_event_v2(uuid, uuid) to authenticated, service_role;
