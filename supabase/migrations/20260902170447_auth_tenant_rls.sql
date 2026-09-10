-- Auth bootstrap and defense-in-depth tenant isolation.

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_display_name text;
begin
  v_display_name := left(
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      split_part(coalesce(new.email, 'Pengelola'), '@', 1),
      'Pengelola'
    ),
    120
  );

  insert into public.profiles (id, display_name)
  values (new.id, v_display_name)
  on conflict (id) do update set display_name = excluded.display_name;

  insert into public.workspaces (owner_user_id, name)
  values (new.id, left(coalesce(nullif(v_display_name, ''), 'Workspace .kumpul'), 160))
  on conflict (owner_user_id) do nothing;

  return new;
end;
$$;

revoke execute on function private.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

create or replace function private.current_workspace_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select w.id
  from public.workspaces as w
  where w.owner_user_id = (select auth.uid())
    and w.status = 'active'
  limit 1
$$;

create or replace function private.event_in_current_workspace(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.events as e
    where e.id = p_event_id
      and e.workspace_id = private.current_workspace_id()
  )
$$;

create or replace function private.booking_in_current_workspace(p_booking_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.bookings as b
    where b.id = p_booking_id
      and b.workspace_id = private.current_workspace_id()
  )
$$;

revoke execute on function private.current_workspace_id() from public, anon;
revoke execute on function private.event_in_current_workspace(uuid) from public, anon;
revoke execute on function private.booking_in_current_workspace(uuid) from public, anon;
grant usage on schema private to authenticated, service_role;
grant execute on function private.current_workspace_id() to authenticated, service_role;
grant execute on function private.event_in_current_workspace(uuid) to authenticated, service_role;
grant execute on function private.booking_in_current_workspace(uuid) to authenticated, service_role;

alter table public.profiles enable row level security;
alter table public.workspaces enable row level security;
alter table public.events enable row level security;
alter table public.event_criteria enable row level security;
alter table public.event_invocations enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_items enable row level security;
alter table public.receptions enable row level security;
alter table public.idempotency_keys enable row level security;
alter table public.legal_document_versions enable row level security;
alter table public.audit_events enable row level security;
alter table public.impact_aggregates enable row level security;
alter table public.job_runs enable row level security;
alter table public.rate_limit_buckets enable row level security;

create policy profiles_select_owner on public.profiles for select to authenticated
using (id = (select auth.uid()));
create policy profiles_update_owner on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy workspaces_select_owner on public.workspaces for select to authenticated
using (owner_user_id = (select auth.uid()));
create policy workspaces_update_owner on public.workspaces for update to authenticated
using (owner_user_id = (select auth.uid()))
with check (owner_user_id = (select auth.uid()));

create policy events_select_owner on public.events for select to authenticated
using (workspace_id = private.current_workspace_id());
create policy events_insert_owner on public.events for insert to authenticated
with check (workspace_id = private.current_workspace_id());
create policy events_update_owner on public.events for update to authenticated
using (workspace_id = private.current_workspace_id())
with check (workspace_id = private.current_workspace_id());
create policy events_delete_owner on public.events for delete to authenticated
using (workspace_id = private.current_workspace_id() and status = 'draft');

create policy event_criteria_select_owner on public.event_criteria for select to authenticated
using (private.event_in_current_workspace(event_id));
create policy event_criteria_insert_owner on public.event_criteria for insert to authenticated
with check (private.event_in_current_workspace(event_id));
create policy event_criteria_update_owner on public.event_criteria for update to authenticated
using (private.event_in_current_workspace(event_id))
with check (private.event_in_current_workspace(event_id));
create policy event_criteria_delete_owner on public.event_criteria for delete to authenticated
using (private.event_in_current_workspace(event_id));

create policy event_invocations_select_owner on public.event_invocations for select to authenticated
using (private.event_in_current_workspace(event_id));
create policy event_invocations_insert_owner on public.event_invocations for insert to authenticated
with check (private.event_in_current_workspace(event_id));
create policy event_invocations_update_owner on public.event_invocations for update to authenticated
using (private.event_in_current_workspace(event_id))
with check (private.event_in_current_workspace(event_id));
create policy event_invocations_delete_owner on public.event_invocations for delete to authenticated
using (private.event_in_current_workspace(event_id));

create policy bookings_select_owner on public.bookings for select to authenticated
using (workspace_id = private.current_workspace_id());
create policy bookings_insert_owner on public.bookings for insert to authenticated
with check (workspace_id = private.current_workspace_id());
create policy bookings_update_owner on public.bookings for update to authenticated
using (workspace_id = private.current_workspace_id())
with check (workspace_id = private.current_workspace_id());
create policy bookings_delete_owner on public.bookings for delete to authenticated
using (workspace_id = private.current_workspace_id());

create policy booking_items_select_owner on public.booking_items for select to authenticated
using (private.booking_in_current_workspace(booking_id));
create policy booking_items_insert_owner on public.booking_items for insert to authenticated
with check (private.booking_in_current_workspace(booking_id));
create policy booking_items_update_owner on public.booking_items for update to authenticated
using (private.booking_in_current_workspace(booking_id))
with check (private.booking_in_current_workspace(booking_id));
create policy booking_items_delete_owner on public.booking_items for delete to authenticated
using (private.booking_in_current_workspace(booking_id));

create policy receptions_select_owner on public.receptions for select to authenticated
using (workspace_id = private.current_workspace_id());
create policy receptions_insert_owner on public.receptions for insert to authenticated
with check (workspace_id = private.current_workspace_id());
create policy receptions_update_owner on public.receptions for update to authenticated
using (workspace_id = private.current_workspace_id())
with check (workspace_id = private.current_workspace_id());
create policy receptions_delete_owner on public.receptions for delete to authenticated
using (workspace_id = private.current_workspace_id());

create policy audit_events_select_owner on public.audit_events for select to authenticated
using (workspace_id = private.current_workspace_id());
create policy audit_events_insert_owner on public.audit_events for insert to authenticated
with check (workspace_id = private.current_workspace_id());
create policy audit_events_update_owner on public.audit_events for update to authenticated
using (workspace_id = private.current_workspace_id())
with check (workspace_id = private.current_workspace_id());
create policy audit_events_delete_owner on public.audit_events for delete to authenticated
using (workspace_id = private.current_workspace_id());

create policy impact_aggregates_select_owner on public.impact_aggregates for select to authenticated
using (workspace_id = private.current_workspace_id());
create policy impact_aggregates_insert_owner on public.impact_aggregates for insert to authenticated
with check (workspace_id = private.current_workspace_id());
create policy impact_aggregates_update_owner on public.impact_aggregates for update to authenticated
using (workspace_id = private.current_workspace_id())
with check (workspace_id = private.current_workspace_id());
create policy impact_aggregates_delete_owner on public.impact_aggregates for delete to authenticated
using (workspace_id = private.current_workspace_id());

create policy legal_documents_read_active on public.legal_document_versions for select
to authenticated using (is_active);

-- The client receives only SELECT access to tenant rows. Domain mutations use
-- audited RPCs, so a future policy mistake cannot bypass transaction invariants.
grant select on public.profiles, public.workspaces, public.events,
  public.event_criteria, public.bookings, public.booking_items,
  public.receptions, public.impact_aggregates, public.legal_document_versions
to authenticated;
grant update (display_name) on public.profiles to authenticated;
grant update (name) on public.workspaces to authenticated;

revoke all on public.event_invocations, public.idempotency_keys,
  public.audit_events, public.job_runs, public.rate_limit_buckets
from anon, authenticated;
