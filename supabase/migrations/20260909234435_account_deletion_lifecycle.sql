-- Keep tenant history and impact data after an admin deletes their identity.
-- The workspace is disabled before the auth row disappears, while actor
-- references become anonymous instead of blocking the deletion.
alter table public.workspaces
  alter column owner_user_id drop not null,
  drop constraint workspaces_owner_user_id_fkey,
  add constraint workspaces_owner_user_id_fkey
    foreign key (owner_user_id) references auth.users(id) on delete set null;

alter table public.receptions
  alter column processed_by drop not null,
  drop constraint receptions_processed_by_fkey,
  add constraint receptions_processed_by_fkey
    foreign key (processed_by) references auth.users(id) on delete set null;

create or replace function private.disable_owned_workspace_before_user_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.workspaces
  set status = 'disabled'
  where owner_user_id = old.id;
  return old;
end;
$$;

revoke execute on function private.disable_owned_workspace_before_user_delete()
  from public, anon, authenticated;

drop trigger if exists before_auth_user_delete_disable_workspace on auth.users;
create trigger before_auth_user_delete_disable_workspace
before delete on auth.users
for each row execute function private.disable_owned_workspace_before_user_delete();

-- A deleted user's JWT may remain cryptographically valid until expiry.
-- Requiring the profile row makes those stale tokens unable to access or
-- create avatar objects after auth.users has been deleted.
drop policy if exists profile_avatars_owner_select on storage.objects;
create policy profile_avatars_owner_select on storage.objects
for select to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (select 1 from public.profiles where id = (select auth.uid()))
);

drop policy if exists profile_avatars_owner_insert on storage.objects;
create policy profile_avatars_owner_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (select 1 from public.profiles where id = (select auth.uid()))
);

drop policy if exists profile_avatars_owner_update on storage.objects;
create policy profile_avatars_owner_update on storage.objects
for update to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (select 1 from public.profiles where id = (select auth.uid()))
)
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (select 1 from public.profiles where id = (select auth.uid()))
);

drop policy if exists profile_avatars_owner_delete on storage.objects;
create policy profile_avatars_owner_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (select 1 from public.profiles where id = (select auth.uid()))
);
