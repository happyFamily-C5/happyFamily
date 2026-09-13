-- Security invariant: "all exposed API wrappers are security invoker"
-- (supabase/tests/database/001_backend_contract_test.sql). The full
-- admin+user contract (20260908181836) and later RPC migrations wrote the
-- api.* wrappers as SECURITY DEFINER even though every one of them is a
-- thin delegate to an already-definer private impl (or carries logic that
-- belongs in one). Definer privileges on the exposed wrapper layer are
-- unnecessary because tenant isolation is enforced inside the private
-- impls, so this migration flips every api wrapper to SECURITY INVOKER:
--
-- - wrappers that only delegate keep their signature and gain invoker
--   semantics; callers receive EXECUTE on the impls they reach directly;
-- - api.my_profile_v1 carries its own body, so the logic moves to
--   private.my_profile_impl() (definer) and the wrapper becomes a
--   delegating invoker.

-- ---------------------------------------------------------------------
-- api.my_profile_v1: extract body into private.my_profile_impl()
-- ---------------------------------------------------------------------
create or replace function private.my_profile_impl()
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

create or replace function api.my_profile_v1()
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select private.my_profile_impl() $$;

-- ---------------------------------------------------------------------
-- Thin delegates: flip to invoker in place.
-- ---------------------------------------------------------------------
alter function api.admin_donation_history_v1(uuid, integer, text) security invoker;
alter function api.admin_event_history_v1(uuid, integer, text) security invoker;
alter function api.admin_recap_v2(uuid, date, date, integer) security invoker;
alter function api.advance_booking_status_v1(uuid, public.booking_status, text, uuid) security invoker;
alter function api.booking_detail_v2(uuid) security invoker;
alter function api.cancel_account_booking_v1(uuid, uuid, text, uuid) security invoker;
alter function api.cancel_or_delete_event_v2(uuid, text, uuid) security invoker;
alter function api.complete_onboarding_v1(public.app_role) security invoker;
alter function api.create_account_booking_v2(uuid, uuid, text, text, jsonb) security invoker;
alter function api.decide_reception_v2(uuid, public.reception_decision, bigint, text, uuid) security invoker;
alter function api.event_detail_v2(uuid) security invoker;
alter function api.my_bookings_v1() security invoker;
alter function api.publish_event_v2(uuid, text, uuid) security invoker;
alter function api.resolve_account_qr_v2(text) security invoker;
alter function api.update_user_profile_v1(text, text, text, text, double precision, double precision, text) security invoker;
alter function api.update_workspace_profile_v1(text, text, text, text, text) security invoker;
alter function api.upsert_event_draft_v2(uuid, uuid, jsonb) security invoker;
alter function api.user_dashboard_v1() security invoker;
alter function api.user_donation_history_v1(integer, text) security invoker;
alter function api.user_event_history_v1(boolean, integer, text) security invoker;
alter function api.workspace_profile_v1() security invoker;

-- ---------------------------------------------------------------------
-- Callers must hold EXECUTE on every impl referenced directly by an
-- invoker wrapper. Revoke the implicit PUBLIC grant first so the impls
-- stay reachable only through the intended roles.
-- ---------------------------------------------------------------------
revoke execute on function private.my_profile_impl() from public, anon;
revoke execute on function private.advance_booking_status_v2_impl(uuid, public.booking_status, text, uuid) from public, anon;
revoke execute on function private.booking_detail_impl(uuid) from public, anon;
revoke execute on function private.cancel_or_delete_event_v3_impl(uuid, text, uuid) from public, anon;
revoke execute on function private.event_detail_impl(uuid) from public, anon;
revoke execute on function private.publish_event_v3_impl(uuid, text, uuid) from public, anon;
revoke execute on function private.upsert_event_draft_v2_impl(uuid, uuid, jsonb) from public, anon;
revoke execute on function private.trim_history_page_v1(jsonb, integer) from public, anon;

grant execute on function private.my_profile_impl() to authenticated, service_role;
grant execute on function private.advance_booking_status_v2_impl(uuid, public.booking_status, text, uuid) to authenticated, service_role;
grant execute on function private.booking_detail_impl(uuid) to authenticated, service_role;
grant execute on function private.cancel_or_delete_event_v3_impl(uuid, text, uuid) to authenticated, service_role;
grant execute on function private.event_detail_impl(uuid) to authenticated, service_role;
grant execute on function private.publish_event_v3_impl(uuid, text, uuid) to authenticated, service_role;
grant execute on function private.upsert_event_draft_v2_impl(uuid, uuid, jsonb) to authenticated, service_role;
grant execute on function private.trim_history_page_v1(jsonb, integer) to authenticated, service_role;
