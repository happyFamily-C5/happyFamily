-- Read contracts for the account and workspace profiles. Both mirror the
-- response shape of their update RPCs so clients share one decoder. The donor
-- profile read deliberately has no role gate: accounts that have not completed
-- onboarding may still read the onboarding/profile minimum per the product
-- contract.

create or replace function api.my_profile_v1()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_profile public.profiles;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  select * into v_profile from public.profiles where id = v_actor_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'PROFILE_NOT_FOUND';
  end if;
  return jsonb_build_object(
    'id', v_profile.id,
    'role', v_profile.account_role,
    'display_name', v_profile.display_name,
    'phone_e164', v_profile.phone_e164,
    'address', v_profile.address,
    'recommendation_location_label', v_profile.recommendation_location_label,
    'recommendation_latitude', v_profile.recommendation_latitude,
    'recommendation_longitude', v_profile.recommendation_longitude,
    'avatar_object_path', v_profile.avatar_object_path
  );
end;
$$;

create or replace function private.workspace_profile_impl()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.require_role('admin');
  v_workspace public.workspaces;
begin
  select * into v_workspace from public.workspaces
  where owner_user_id = v_actor_id and status = 'active';
  if not found then
    raise exception using errcode = 'P0002', message = 'WORKSPACE_NOT_FOUND';
  end if;
  return jsonb_build_object(
    'id', v_workspace.id,
    'name', v_workspace.name,
    'office_address', v_workspace.office_address,
    'office_phone_e164', v_workspace.office_phone_e164,
    'office_email', v_workspace.office_email,
    'logo_object_path', v_workspace.logo_object_path,
    'publishable',
    nullif(trim(v_workspace.name), '') is not null
      and nullif(trim(v_workspace.office_address), '') is not null
      and nullif(trim(v_workspace.office_phone_e164), '') is not null
      and nullif(trim(v_workspace.office_email), '') is not null
  );
end;
$$;

create or replace function api.workspace_profile_v1()
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.workspace_profile_impl() $$;

revoke execute on function api.my_profile_v1() from public, anon;
revoke execute on function api.workspace_profile_v1() from public, anon;
grant execute on function api.my_profile_v1() to authenticated, service_role;
grant execute on function api.workspace_profile_v1() to authenticated, service_role;
