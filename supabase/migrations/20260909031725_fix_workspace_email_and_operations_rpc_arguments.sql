-- Correct the workspace email check. The original pattern used two literal
-- backslashes, which made ordinary email addresses fail validation.
alter table public.workspaces
  drop constraint if exists workspaces_email_format;

alter table public.workspaces
  add constraint workspaces_email_format check (
    office_email is null
    or office_email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  );

-- PostgREST resolves RPC arguments by name. Preserve the existing function
-- identities while assigning names to the parameters used by operations.
drop function if exists api.decide_reception_v2(
  uuid, public.reception_decision, bigint, text, uuid
);

create function api.decide_reception_v2(
  p_booking_id uuid,
  p_decision public.reception_decision,
  p_actual_weight_grams bigint,
  p_idempotency_key text,
  p_request_id uuid
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.decide_reception_v2_impl(
    p_booking_id,
    p_decision,
    p_actual_weight_grams,
    p_idempotency_key,
    p_request_id
  )
$$;

revoke execute on function api.decide_reception_v2(
  uuid, public.reception_decision, bigint, text, uuid
) from public, anon;
grant execute on function api.decide_reception_v2(
  uuid, public.reception_decision, bigint, text, uuid
) to authenticated, service_role;

drop function if exists api.advance_booking_status_v1(
  uuid, public.booking_status, uuid
);

create function api.advance_booking_status_v1(
  p_booking_id uuid,
  p_status public.booking_status,
  p_request_id uuid
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.advance_booking_status_impl(
    p_booking_id,
    p_status,
    p_request_id
  )
$$;

revoke execute on function api.advance_booking_status_v1(
  uuid, public.booking_status, uuid
) from public, anon;
grant execute on function api.advance_booking_status_v1(
  uuid, public.booking_status, uuid
) to authenticated, service_role;
