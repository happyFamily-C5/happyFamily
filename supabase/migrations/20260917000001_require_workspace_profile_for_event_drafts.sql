-- A workspace must be ready before its first event draft is created. Event
-- fields may still be incomplete while the draft is being authored.

create or replace function private.assert_workspace_profile_for_event_draft(
  p_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_role('admin');
  v_workspace public.workspaces;
begin
  select * into v_workspace
  from public.workspaces
  where owner_user_id = v_actor_id and status = 'active';
  if not found then
    raise exception using errcode = '42501', message = 'WORKSPACE_UNAVAILABLE';
  end if;

  if p_event_id is not null and exists (
    select 1 from public.events
    where id = p_event_id and workspace_id = v_workspace.id
  ) then
    return;
  end if;

  perform private.assert_workspace_publishable(v_workspace);
end;
$$;

create or replace function api.upsert_event_draft_v1(
  p_event_id uuid,
  p_mutation_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
begin
  perform private.assert_workspace_profile_for_event_draft(p_event_id);
  return private.upsert_event_draft_impl(p_event_id, p_mutation_id, p_payload);
end;
$$;

create or replace function api.upsert_event_draft_v2(
  p_event_id uuid,
  p_mutation_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
begin
  perform private.assert_workspace_profile_for_event_draft(p_event_id);
  return private.upsert_event_draft_v2_impl(p_event_id, p_mutation_id, p_payload);
end;
$$;

revoke execute on function private.assert_workspace_profile_for_event_draft(uuid)
  from public, anon;
grant execute on function private.assert_workspace_profile_for_event_draft(uuid)
  to authenticated, service_role;
