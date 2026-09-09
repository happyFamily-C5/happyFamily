-- Booking detail now carries the accepted actual weight and, for the owning
-- donor only, the opaque QR ciphertext needed to re-render the QR label. The
-- ciphertext never decrypts inside SQL; the authenticated Edge Function owns
-- decryption, matching resolve_account_qr_v2.

create or replace function private.booking_detail_impl(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  if not found or (v_booking.donor_user_id <> v_actor_id
    and v_booking.workspace_id <> private.current_workspace_id()) then
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
