-- Forward-fix two defects found by the hosted pgTAP suite.  Keep the public
-- API signatures stable so already-deployed authenticated adapters continue
-- to work after this migration.

CREATE OR replace function private.booking_detail_impl(p_booking_id uuid)
  returns jsonb language plpgsql security definer SET search_path = '' AS $$
declare
  v_actor_id uuid := auth.uid();
  v_booking public.bookings;
  v_actual_weight bigint;
  v_response jsonb;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  select * into v_booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'BOOKING_NOT_FOUND';
  end if;
  if v_booking.donor_user_id is distinct from v_actor_id
    and (
      private.current_account_role() <> 'admin'
      or v_booking.workspace_id is distinct from private.current_workspace_id()
    )
  then
    raise exception using errcode = 'P0002', message = 'BOOKING_NOT_FOUND';
  end if;
  select r.actual_weight_grams into v_actual_weight
  from public.receptions as r where r.booking_id = p_booking_id;
  v_response := jsonb_build_object(
    'id', v_booking.id,
    'public_booking_id', v_booking.public_booking_id,
    'status', v_booking.status,
    'estimated_weight_grams', v_booking.estimated_weight_grams,
    'actual_weight_grams', v_actual_weight,
    'expires_at', v_booking.expires_at,
    'event', v_booking.event_snapshot,
    'can_cancel', v_booking.donor_user_id = v_actor_id and v_booking.status = 'waiting',
    'timeline', coalesce((
      select jsonb_agg(jsonb_build_object(
        'previous_status', s.previous_status,
        'status', s.status,
        'actor_type', s.actor_type,
        'created_at', s.created_at
      ) order by s.created_at, s.id)
      from public.booking_status_events as s where s.booking_id = v_booking.id
    ), '[]'::jsonb)
  );
  if v_booking.donor_user_id = v_actor_id and v_booking.pii_deleted_at is null then
    v_response := v_response || jsonb_build_object(
      'qr_token_ciphertext', v_booking.qr_token_ciphertext,
      'qr_token_nonce', v_booking.qr_token_nonce,
      'crypto_key_version', v_booking.crypto_key_version
    );
  end if;
  return v_response;
end;
$$;

revoke execute ON function private.booking_detail_impl(uuid)
FROM public, anon, authenticated;

-- The previous private history implementations deliberately fetched one extra
-- row to determine next_cursor, but accidentally returned it. Trim only the
-- response payload; next_cursor continues to point at the last returned row.
CREATE OR replace function private.trim_history_page_v1(p_response jsonb,
  p_limit integer) returns jsonb language sql immutable SET search_path = '' AS
  $$
  select case
    when p_limit is null then p_response
    else p_response || jsonb_build_object(
      'items', coalesce((
        select jsonb_agg(item.value order by item.ordinality)
        from jsonb_array_elements(coalesce(p_response -> 'items', '[]'::jsonb))
          with ordinality as item(value, ordinality)
        where item.ordinality <= least(greatest(p_limit, 1), 100)
      ), '[]'::jsonb)
    )
  end
$$;

CREATE OR replace function api.user_donation_history_v1(p_limit integer DEFAULT
  NULL, p_cursor text DEFAULT NULL) returns jsonb language sql security definer
  SET search_path = '' AS $$
  select private.trim_history_page_v1(
    private.booking_history_impl('donor', null, p_limit, p_cursor), p_limit
  )
$$;

CREATE OR replace function api.admin_donation_history_v1(p_event_id uuid DEFAULT
  NULL, p_limit integer DEFAULT NULL, p_cursor text DEFAULT NULL) returns jsonb
  language sql security definer SET search_path = '' AS $$
  select private.trim_history_page_v1(
    private.booking_history_impl('admin', p_event_id, p_limit, p_cursor), p_limit
  )
$$;

CREATE OR replace function api.user_event_history_v1(p_terminal boolean DEFAULT
  NULL, p_limit integer DEFAULT NULL, p_cursor text DEFAULT NULL) returns jsonb
  language sql security definer SET search_path = '' AS $$
  select private.trim_history_page_v1(
    private.event_history_impl('donor', null, p_limit, p_cursor, p_terminal), p_limit
  )
$$;

CREATE OR replace function api.admin_event_history_v1(p_event_id uuid DEFAULT
  NULL, p_limit integer DEFAULT NULL, p_cursor text DEFAULT NULL) returns jsonb
  language sql security definer SET search_path = '' AS $$
  select private.trim_history_page_v1(
    private.event_history_impl('admin', p_event_id, p_limit, p_cursor, null), p_limit
  )
$$;

revoke execute ON function private.trim_history_page_v1(jsonb, integer)
FROM public, anon, authenticated;
revoke execute ON function api.user_donation_history_v1(integer, text)
FROM public, anon;
revoke execute ON function api.admin_donation_history_v1(uuid, integer, text)
FROM public, anon;
revoke execute ON function api.user_event_history_v1(boolean, integer, text)
FROM public, anon;
revoke execute ON function api.admin_event_history_v1(uuid, integer, text)
FROM public, anon;
grant execute ON function api.user_donation_history_v1(integer, text) TO
  authenticated, service_role;
grant execute ON function api.admin_donation_history_v1(uuid, integer, text) TO
  authenticated, service_role;
grant execute ON function api.user_event_history_v1(boolean, integer, text) TO
  authenticated, service_role;
grant execute ON function api.admin_event_history_v1(uuid, integer, text) TO
  authenticated, service_role;
