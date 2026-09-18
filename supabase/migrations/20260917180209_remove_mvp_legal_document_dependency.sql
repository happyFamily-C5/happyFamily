-- The MVP uses the in-app consent statement. It records consented_at, but has
-- no Terms/Privacy URL or version fields in the active donor contract.
alter table public.bookings
  alter column terms_version drop not null,
  alter column privacy_version drop not null;

create or replace function private.create_account_booking_impl(
  p_actor_id uuid, p_event_id uuid, p_idempotency_key text, p_request_hash text, p_booking jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles;
  v_event public.events;
  v_booking public.bookings;
  v_existing public.idempotency_keys;
  v_response jsonb;
  v_expiry timestamptz;
  v_item jsonb;
begin
  if p_actor_id is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
  select * into v_profile from public.profiles where id = p_actor_id and account_role = 'donor';
  if not found then raise exception using errcode = '42501', message = 'ROLE_FORBIDDEN'; end if;
  if nullif(trim(v_profile.display_name), '') is null or v_profile.phone_e164 is null then
    raise exception using errcode = '23514', message = 'PROFILE_INCOMPLETE';
  end if;
  insert into public.idempotency_keys(scope, actor_scope, key, request_hash, resource_type)
  values ('create-account-booking', p_actor_id::text, p_idempotency_key, p_request_hash, 'booking')
  on conflict (scope, actor_scope, key) do nothing;
  if not found then
    select * into v_existing from public.idempotency_keys where scope = 'create-account-booking'
      and actor_scope = p_actor_id::text and key = p_idempotency_key for update;
    if v_existing.request_hash <> p_request_hash then raise exception using errcode = '23505', message = 'IDEMPOTENCY_CONFLICT'; end if;
    if v_existing.resource_id is not null then
      select * into v_booking from public.bookings where id = v_existing.resource_id;
      return jsonb_build_object('booking_id', v_booking.id, 'public_booking_id', v_booking.public_booking_id,
        'status', v_booking.status, 'expires_at', v_booking.expires_at,
        'qr_token_ciphertext', v_booking.qr_token_ciphertext, 'qr_token_nonce', v_booking.qr_token_nonce,
        'crypto_key_version', v_booking.crypto_key_version, 'event_snapshot', v_booking.event_snapshot,
        'idempotent_replay', true);
    end if;
  end if;
  select * into v_event from public.events where id = p_event_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'EVENT_NOT_FOUND'; end if;
  if v_event.status not in ('upcoming', 'ongoing') or v_event.end_at <= now() then
    raise exception using errcode = 'P0001', message = 'EVENT_UNAVAILABLE';
  end if;
  if v_event.capacity_grams is null or v_event.max_donation_per_user_grams is null then
    raise exception using errcode = 'P0001', message = 'EVENT_UNAVAILABLE';
  end if;
  if (p_booking ->> 'estimated_weight_grams')::bigint <= 0
    or (p_booking ->> 'estimated_weight_grams')::bigint > v_event.max_donation_per_user_grams then
    raise exception using errcode = '23514', message = 'DONATION_LIMIT_EXCEEDED';
  end if;
  if jsonb_typeof(p_booking -> 'items') <> 'array' or jsonb_array_length(p_booking -> 'items') < 1
    or jsonb_array_length(p_booking -> 'items') > 100 then
    raise exception using errcode = '23514', message = 'INVALID_ITEMS';
  end if;
  if exists (select 1 from public.bookings where donor_user_id = p_actor_id and event_id = p_event_id
      and status not in ('cancelled', 'rejected', 'expired')) then
    raise exception using errcode = '23505', message = 'BOOKING_ALREADY_EXISTS';
  end if;
  if v_event.received_weight_grams + v_event.reserved_weight_grams
    + (p_booking ->> 'estimated_weight_grams')::bigint > v_event.capacity_grams then
    raise exception using errcode = 'P0001', message = 'CAPACITY_EXCEEDED';
  end if;
  v_expiry := v_event.end_at;
  insert into public.bookings(
    public_booking_id, event_id, workspace_id, donor_user_id,
    donor_name_ciphertext, donor_name_nonce, donor_phone_ciphertext, donor_phone_nonce,
    phone_lookup_hash, crypto_key_version, estimated_weight_grams, item_count,
    shipping_method, scan_model_version, status, event_snapshot, snapshot_schema_version,
    qr_token_hash, qr_token_ciphertext, qr_token_nonce, consented_at, expires_at
  ) values (
    p_booking ->> 'public_booking_id', v_event.id, v_event.workspace_id, p_actor_id,
    p_booking ->> 'donor_name_ciphertext', p_booking ->> 'donor_name_nonce',
    p_booking ->> 'donor_phone_ciphertext', p_booking ->> 'donor_phone_nonce',
    p_booking ->> 'phone_lookup_hash', (p_booking ->> 'crypto_key_version')::smallint,
    (p_booking ->> 'estimated_weight_grams')::bigint, jsonb_array_length(p_booking -> 'items'),
    (p_booking ->> 'shipping_method')::public.shipping_method, p_booking ->> 'scan_model_version',
    'waiting', private.event_user_json(v_event), 2,
    p_booking ->> 'qr_token_hash', p_booking ->> 'qr_token_ciphertext', p_booking ->> 'qr_token_nonce',
    now(), v_expiry
  ) returning * into v_booking;
  for v_item in select value from jsonb_array_elements(p_booking -> 'items') loop
    if coalesce((v_item ->> 'passed')::boolean, false) is not true then
      raise exception using errcode = '23514', message = 'ITEM_NOT_PASSED';
    end if;
    insert into public.booking_items(booking_id, ordinal, passed, scanner_model_version, metadata)
    values (v_booking.id, (v_item ->> 'ordinal')::smallint, true,
      coalesce(nullif(v_item ->> 'scanner_model_version', ''), v_booking.scan_model_version),
      coalesce(v_item -> 'metadata', '{}'::jsonb));
  end loop;
  update public.events set reserved_weight_grams = reserved_weight_grams + v_booking.estimated_weight_grams,
    version = version + 1 where id = v_event.id;
  insert into public.booking_status_events(booking_id, workspace_id, status, actor_type, actor_id, request_id)
  values (v_booking.id, v_booking.workspace_id, 'waiting', 'donor', p_actor_id,
    coalesce(nullif(p_booking ->> 'request_id', '')::uuid, gen_random_uuid()));
  insert into public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
  values ('donor', p_actor_id::text, v_booking.workspace_id, 'booking', v_booking.id, 'booking.created',
    coalesce(nullif(p_booking ->> 'request_id', '')::uuid, gen_random_uuid()));
  v_response := jsonb_build_object('booking_id', v_booking.id, 'public_booking_id', v_booking.public_booking_id,
    'status', v_booking.status, 'expires_at', v_booking.expires_at,
    'qr_token_ciphertext', v_booking.qr_token_ciphertext, 'qr_token_nonce', v_booking.qr_token_nonce,
    'crypto_key_version', v_booking.crypto_key_version, 'event_snapshot', v_booking.event_snapshot,
    'idempotent_replay', false);
  update public.idempotency_keys set resource_id = v_booking.id, response_payload = v_response
  where scope = 'create-account-booking' and actor_scope = p_actor_id::text and key = p_idempotency_key;
  return v_response;
end;
$$;
