-- Authenticated Admin QR resolution. The RPC returns encrypted PII only to
-- the JWT-verified Edge Function; decryption never occurs in SQL or clients.
create or replace function private.resolve_account_qr_v2_impl(p_qr_token_hash text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_role('admin');
  v_workspace uuid := private.current_workspace_id();
  v_booking public.bookings;
begin
  if nullif(trim(p_qr_token_hash), '') is null then
    raise exception using errcode = '22023', message = 'QR_INVALID';
  end if;
  perform private.reconcile_events(v_workspace);
  select * into v_booking
  from public.bookings
  where qr_token_hash = p_qr_token_hash
    and workspace_id = v_workspace
    and donor_user_id is not null
    and pii_deleted_at is null
  for update;
  if not found then raise exception using errcode = 'P0002', message = 'QR_INVALID'; end if;
  if v_booking.status <> 'waiting' or v_booking.expires_at <= now() then
    raise exception using errcode = 'P0001', message = 'BOOKING_NOT_PROCESSABLE';
  end if;
  return jsonb_build_object(
    'booking_id', v_booking.id,
    'public_booking_id', v_booking.public_booking_id,
    'status', v_booking.status,
    'estimated_weight_grams', v_booking.estimated_weight_grams,
    'item_count', v_booking.item_count,
    'shipping_method', v_booking.shipping_method,
    'event_snapshot', v_booking.event_snapshot,
    'donor_name_ciphertext', v_booking.donor_name_ciphertext,
    'donor_name_nonce', v_booking.donor_name_nonce,
    'donor_phone_ciphertext', v_booking.donor_phone_ciphertext,
    'donor_phone_nonce', v_booking.donor_phone_nonce,
    'crypto_key_version', v_booking.crypto_key_version
  );
end;
$$;

create or replace function api.resolve_account_qr_v2(p_qr_token_hash text)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.resolve_account_qr_v2_impl(p_qr_token_hash) $$;

revoke execute on function api.resolve_account_qr_v2(text) from public, anon;
grant execute on function api.resolve_account_qr_v2(text) to authenticated, service_role;
