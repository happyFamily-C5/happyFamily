-- Terminal events are immutable. Release their waiting reservation as part of
-- the same state transition to `completed`, never as a later repair update.
create or replace function private.reconcile_events(p_workspace_id uuid default null)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_completed bigint := 0;
  v_expired bigint := 0;
begin
  with completed as (
    update public.events e
    set status = 'completed', terminal_at = now(), terminal_reason = 'event_completed',
      reserved_weight_grams = 0, version = e.version + 1
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

  update public.events e
  set reserved_weight_grams = coalesce(x.weight, 0), version = e.version + 1
  from (
    select e2.id, sum(b.estimated_weight_grams) filter (where b.status = 'waiting') as weight
    from public.events e2
    left join public.bookings b on b.event_id = e2.id
    where e2.status in ('draft', 'upcoming', 'ongoing')
      and (p_workspace_id is null or e2.workspace_id = p_workspace_id)
    group by e2.id
  ) x
  where e.id = x.id and e.reserved_weight_grams is distinct from coalesce(x.weight, 0);

  return v_completed + v_expired;
end;
$$;
