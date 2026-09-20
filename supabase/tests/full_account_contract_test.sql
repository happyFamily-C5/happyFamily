begin;

create extension if not exists pgtap with schema extensions;
select plan(70);

-- The hosted Management API returns only the final result set. Capture every
-- TAP assertion so this suite remains diagnosable without a local Docker-based
-- pg_prove runner.
create temporary table tap_results (
  sequence bigint generated always as identity,
  result text not null
);
grant all privileges on table pg_temp.tap_results to authenticated, service_role;
grant usage, select on sequence pg_temp.tap_results_sequence_seq to authenticated, service_role;

create or replace function pg_temp.account_booking(
  p_public_id text, p_qr_hash text, p_weight bigint, p_request_id uuid
)
returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'public_booking_id', p_public_id,
    'donor_name_ciphertext', 'encrypted-name', 'donor_name_nonce', 'name-nonce',
    'donor_phone_ciphertext', 'encrypted-phone', 'donor_phone_nonce', 'phone-nonce',
    'phone_lookup_hash', 'phone-' || p_public_id, 'crypto_key_version', 1,
    'estimated_weight_grams', p_weight, 'item_count', 1,
    'items', jsonb_build_array(jsonb_build_object(
      'ordinal', 0, 'passed', true, 'scanner_model_version', 'test-v2', 'metadata', '{}'::jsonb
    )),
    'shipping_method', 'direct', 'scan_model_version', 'test-v2',
    'qr_token_hash', p_qr_hash, 'qr_token_ciphertext', 'encrypted-qr', 'qr_token_nonce', 'qr-nonce',
    'request_id', p_request_id
  )
$$;

-- Test-only fixture lookup bypasses user-facing RLS so ownership assertions
-- exercise the RPC rather than accidentally passing a NULL argument.
create or replace function pg_temp.booking_id(p_public_booking_id text)
returns uuid
language sql
security definer
as $$ select id from public.bookings where public_booking_id = p_public_booking_id $$;
grant execute on function pg_temp.booking_id(text) to authenticated, service_role;

create or replace function pg_temp.make_v2_event(
  p_id uuid, p_owner uuid, p_status public.event_status, p_start timestamptz,
  p_end timestamptz, p_capacity bigint default 1000, p_max bigint default 700
)
returns uuid language plpgsql as $$
declare v_workspace uuid;
begin
  select id into v_workspace from public.workspaces where owner_user_id = p_owner;
  insert into public.events(
    id, workspace_id, name, description, status, published_at, terminal_at, start_at, end_at,
    timezone_name, operational_days, opens_at_local, closes_at_local, location_name,
    location_address, location_country_code, latitude, longitude, capacity_grams,
    max_donation_per_user_grams, banner_object_path, receiver_name, receiver_phone, receiver_address
  ) values (
    p_id, v_workspace, 'V2 test event', 'Contract test event', p_status,
    case when p_status in ('upcoming', 'ongoing') then now() else null end,
    case when p_status in ('completed', 'closed', 'cancelled') then now() else null end,
    p_start, p_end, 'Asia/Jakarta', array[1,2,3,4,5]::smallint[], '08:00', '17:00',
    'Jakarta', 'Jl. Test Jakarta', 'ID', -6.2, 106.8, p_capacity, p_max,
    v_workspace::text || '/' || p_id::text || '/banner.jpg',
    'Receiver Test', '+6281234567890', 'Jl. Receiver Test'
  );
  return p_id;
end;
$$;

insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data)
values
  ('a1111111-1111-4111-8111-111111111111', 'v2-admin@example.invalid', '{"display_name":"V2 Admin"}', '{"provider":"email","providers":["email"]}'),
  ('d1111111-1111-4111-8111-111111111111', 'v2-donor-one@example.invalid', '{"display_name":"V2 Donor One"}', '{"provider":"email","providers":["email"]}'),
  ('d2222222-2222-4222-8222-222222222222', 'v2-donor-two@example.invalid', '{"display_name":"V2 Donor Two"}', '{"provider":"email","providers":["email"]}');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true);
select api.complete_onboarding_v1('admin');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1111111-1111-4111-8111-111111111111', true);
select api.complete_onboarding_v1('donor');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd2222222-2222-4222-8222-222222222222', true);
select api.complete_onboarding_v1('donor');
reset role;

update public.profiles set account_role = 'admin', phone_e164 = '+6281111111111'
where id = 'a1111111-1111-4111-8111-111111111111';
update public.profiles set account_role = 'donor', phone_e164 = '+6281222222222'
where id = 'd1111111-1111-4111-8111-111111111111';
update public.profiles set account_role = 'donor', phone_e164 = '+6281333333333'
where id = 'd2222222-2222-4222-8222-222222222222';

insert into pg_temp.tap_results(result)
select is(
  (select count(*) from public.profiles where account_role in ('admin', 'donor') and id in (
    'a1111111-1111-4111-8111-111111111111', 'd1111111-1111-4111-8111-111111111111', 'd2222222-2222-4222-8222-222222222222'
  )), 3::bigint, 'account fixtures have immutable roles'
);

select pg_temp.make_v2_event(
  'e1111111-1111-4111-8111-111111111111', 'a1111111-1111-4111-8111-111111111111',
  'ongoing', now() - interval '1 hour', now() + interval '2 hours', 1000, 700
);

set local role service_role;
insert into pg_temp.tap_results(result)
select is(
  api.create_account_booking_v2(
    'd1111111-1111-4111-8111-111111111111', 'e1111111-1111-4111-8111-111111111111',
    'v2-capacity-one', 'request-hash-one',
    pg_temp.account_booking('KPL-V2AAA-00001', repeat('1', 64), 500, '10000000-0000-4000-8000-000000000001')
  ) ->> 'status', 'waiting', 'account booking reserves capacity'
);
insert into pg_temp.tap_results(result)
select is(
  (select reserved_weight_grams from public.events where id = 'e1111111-1111-4111-8111-111111111111'),
  500::bigint, 'reservation equals estimate'
);
insert into pg_temp.tap_results(result)
select is(
  (select consented_at is not null and terms_version is null and privacy_version is null
   from public.bookings where public_booking_id = 'KPL-V2AAA-00001'),
  true, 'MVP booking records consent without legal versions'
);
insert into pg_temp.tap_results(result)
select is(
  api.create_account_booking_v2(
    'd1111111-1111-4111-8111-111111111111', 'e1111111-1111-4111-8111-111111111111',
    'v2-capacity-one', 'request-hash-one',
    pg_temp.account_booking('KPL-V2AAA-00001', repeat('1', 64), 500, '10000000-0000-4000-8000-000000000001')
  ) ->> 'idempotent_replay', 'true', 'same account booking request replays'
);
insert into pg_temp.tap_results(result)
select is(
  (select count(*) from public.bookings where event_id = 'e1111111-1111-4111-8111-111111111111'),
  1::bigint, 'replay does not duplicate a booking'
);
insert into pg_temp.tap_results(result)
select throws_ok(
  $$select api.create_account_booking_v2(
    'd2222222-2222-4222-8222-222222222222', 'e1111111-1111-4111-8111-111111111111',
    'v2-capacity-two', 'request-hash-two',
    pg_temp.account_booking('KPL-V2BBB-00002', repeat('2', 64), 600, '10000000-0000-4000-8000-000000000002')
  )$$,
  'P0001', 'CAPACITY_EXCEEDED', 'capacity prevents an over-reservation'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd2222222-2222-4222-8222-222222222222', true);
insert into pg_temp.tap_results(result)
select is_empty(
  $$select * from public.bookings where event_id = 'e1111111-1111-4111-8111-111111111111'$$,
  'donor cannot read an organizer operational booking list through RLS'
);
insert into pg_temp.tap_results(result)
select throws_ok(
  $$select api.booking_detail_v2(pg_temp.booking_id('KPL-V2AAA-00001'))$$,
  'P0002', 'BOOKING_NOT_FOUND', 'donor cannot read another donor booking detail'
);
reset role;

set local role service_role;
select pg_temp.make_v2_event(
  'e2222222-2222-4222-8222-222222222222', 'a1111111-1111-4111-8111-111111111111',
  'ongoing', now() - interval '1 hour', now() + interval '2 hours'
);
select api.create_account_booking_v2(
  'd1111111-1111-4111-8111-111111111111', 'e2222222-2222-4222-8222-222222222222',
  'v2-cancel', 'request-hash-cancel',
  pg_temp.account_booking('KPL-V2CCC-00003', repeat('3', 64), 400, '10000000-0000-4000-8000-000000000003')
);
reset role;

set local role service_role;
insert into pg_temp.tap_results(result)
select is(
  api.cancel_account_booking_v1(
    'd1111111-1111-4111-8111-111111111111',
    (select id from public.bookings where public_booking_id = 'KPL-V2CCC-00003'),
    'v2-cancel', '10000000-0000-4000-8000-000000000004'
  ) ->> 'status', 'cancelled', 'donor may cancel a waiting booking'
);
insert into pg_temp.tap_results(result)
select is(
  (select reserved_weight_grams from public.events where id = 'e2222222-2222-4222-8222-222222222222'),
  0::bigint, 'cancel releases the reservation'
);
insert into pg_temp.tap_results(result)
select is(
  (select actor_type from public.booking_status_events where booking_id = (
    select id from public.bookings where public_booking_id = 'KPL-V2CCC-00003'
  ) order by id desc limit 1), 'donor', 'cancel has donor timeline actor'
);
reset role;

set local role service_role;
select pg_temp.make_v2_event(
  'e3333333-3333-4333-8333-333333333333', 'a1111111-1111-4111-8111-111111111111',
  'ongoing', now() - interval '1 hour', now() + interval '1 hour'
);
select api.create_account_booking_v2(
  'd1111111-1111-4111-8111-111111111111', 'e3333333-3333-4333-8333-333333333333',
  'v2-expiry', 'request-hash-expiry',
  pg_temp.account_booking('KPL-V2DDD-00004', repeat('4', 64), 300, '10000000-0000-4000-8000-000000000005')
);
update public.events set end_at = now() - interval '1 minute'
where id = 'e3333333-3333-4333-8333-333333333333';
insert into pg_temp.tap_results(result)
select lives_ok($$select private.run_lifecycle_job()$$, 'authorized lifecycle job runs idempotently');
insert into pg_temp.tap_results(result)
select is((select status::text from public.events where id = 'e3333333-3333-4333-8333-333333333333'), 'completed', 'reconciliation completes ended events');
insert into pg_temp.tap_results(result)
select is((select status::text from public.bookings where public_booking_id = 'KPL-V2DDD-00004'), 'expired', 'reconciliation expires waiting bookings');
insert into pg_temp.tap_results(result)
select is((select count(*) from public.booking_status_events where booking_id = (select id from public.bookings where public_booking_id = 'KPL-V2DDD-00004') and actor_type = 'system' and status = 'expired'), 1::bigint, 'expiry has one system timeline record');
insert into pg_temp.tap_results(result)
select is((select reserved_weight_grams from public.events where id = 'e3333333-3333-4333-8333-333333333333'), 0::bigint, 'expiry releases reservation');
reset role;

set local role service_role;
select pg_temp.make_v2_event(
  'e4444444-4444-4444-8444-444444444444', 'a1111111-1111-4111-8111-111111111111',
  'ongoing', now() - interval '1 hour', now() + interval '2 hours'
);
select api.create_account_booking_v2(
  'd1111111-1111-4111-8111-111111111111', 'e4444444-4444-4444-8444-444444444444',
  'v2-reception', 'request-hash-reception',
  pg_temp.account_booking('KPL-V2EEE-00005', repeat('5', 64), 500, '10000000-0000-4000-8000-000000000006')
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  api.resolve_account_qr_v2(repeat('5', 64)) ->> 'public_booking_id',
  'KPL-V2EEE-00005', 'admin resolves an account QR only within its workspace'
);
insert into pg_temp.tap_results(result)
select is(
  api.decide_reception_v2(
    (select id from public.bookings where public_booking_id = 'KPL-V2EEE-00005'), 'accepted', 500,
    'v2-reception', '10000000-0000-4000-8000-000000000007'
  ) ->> 'status', 'accepted', 'admin accepts a waiting booking'
);
insert into pg_temp.tap_results(result)
select is(
  api.advance_booking_status_v1(
    (select id from public.bookings where public_booking_id = 'KPL-V2EEE-00005'), 'processed',
    'v2-tracking-processed', '10000000-0000-4000-8000-000000000008'
  ) ->> 'status', 'processed', 'admin advances accepted booking to processed'
);
insert into pg_temp.tap_results(result)
select is(
  api.advance_booking_status_v1(
    (select id from public.bookings where public_booking_id = 'KPL-V2EEE-00005'), 'recycled',
    'v2-tracking-recycled', '10000000-0000-4000-8000-000000000009'
  ) ->> 'status', 'recycled', 'admin advances processed booking to recycled'
);
reset role;
set local role service_role;
insert into pg_temp.tap_results(result)
select ok(
  (select terminal_at is not null from public.bookings where public_booking_id = 'KPL-V2EEE-00005'),
  'recycled booking has terminal timestamp'
);
insert into pg_temp.tap_results(result)
select is(
  (select count(*) from public.booking_status_events where booking_id = (
    select id from public.bookings where public_booking_id = 'KPL-V2EEE-00005'
  ) and actor_type = 'admin'), 3::bigint, 'reception and tracking retain admin audit timeline'
);
reset role;

set local role service_role;
select pg_temp.make_v2_event(
  'e5555555-5555-4555-8555-555555555555', 'a1111111-1111-4111-8111-111111111111',
  'draft', now() + interval '1 hour', now() + interval '2 hours'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  api.cancel_or_delete_event_v2('e5555555-5555-4555-8555-555555555555', 'v2-draft-delete', '10000000-0000-4000-8000-000000000010') ->> 'action',
  'draft_deleted', 'draft event is hard deleted'
);
insert into pg_temp.tap_results(result)
select is((select count(*) from public.events where id = 'e5555555-5555-4555-8555-555555555555'), 0::bigint, 'deleted draft no longer exists');
reset role;

set local role service_role;
select pg_temp.make_v2_event(
  'e6666666-6666-4666-8666-666666666666', 'a1111111-1111-4111-8111-111111111111',
  'ongoing', now() - interval '1 hour', now() + interval '2 hours'
);
select api.create_account_booking_v2(
  'd2222222-2222-4222-8222-222222222222', 'e6666666-6666-4666-8666-666666666666',
  'v2-event-cancel', 'request-hash-event-cancel',
  pg_temp.account_booking('KPL-V2FFF-00006', repeat('6', 64), 400, '10000000-0000-4000-8000-000000000011')
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  api.cancel_or_delete_event_v2('e6666666-6666-4666-8666-666666666666', 'v2-event-cancel', '10000000-0000-4000-8000-000000000012') ->> 'status',
  'cancelled', 'published event is soft cancelled'
);
reset role;
set local role service_role;
insert into pg_temp.tap_results(result)
select is((select status::text from public.bookings where public_booking_id = 'KPL-V2FFF-00006'), 'cancelled', 'event cancel cancels waiting booking');
insert into pg_temp.tap_results(result)
select is((select reserved_weight_grams from public.events where id = 'e6666666-6666-4666-8666-666666666666'), 0::bigint, 'event cancel releases all waiting reservations');
insert into pg_temp.tap_results(result)
select is((select actor_type from public.booking_status_events where booking_id = (select id from public.bookings where public_booking_id = 'KPL-V2FFF-00006') order by id desc limit 1), 'admin', 'event cancellation records admin actor');
reset role;

-- ── Gap-closure contracts ────────────────────────────────────────

-- Task 1: event_detail_v2 for the authenticated donor.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  api.event_detail_v2('e1111111-1111-4111-8111-111111111111') -> 'availability' ->> 'bookable',
  'false', 'event detail is not bookable after this donor already has a booking'
);
insert into pg_temp.tap_results(result)
select is(
  api.event_detail_v2('e1111111-1111-4111-8111-111111111111') ->> 'already_booked',
  'true', 'event detail reports the donor existing booking'
);
insert into pg_temp.tap_results(result)
select is(
  api.event_detail_v2('e1111111-1111-4111-8111-111111111111')
    -> 'availability' ->> 'available_weight_grams',
  '500', 'event detail carries the remaining capacity after reservation'
);
insert into pg_temp.tap_results(result)
select is(
  api.event_detail_v2('e1111111-1111-4111-8111-111111111111') -> 'operational_days',
  '[1, 2, 3, 4, 5]'::jsonb, 'event detail carries the admin operational days'
);
insert into pg_temp.tap_results(result)
select is(
  api.event_detail_v2('e1111111-1111-4111-8111-111111111111') ->> 'opens_at_local',
  '08:00:00', 'event detail carries the admin opening time'
);
insert into pg_temp.tap_results(result)
select is(
  api.event_detail_v2('e1111111-1111-4111-8111-111111111111') ->> 'closes_at_local',
  '17:00:00', 'event detail carries the admin closing time'
);
reset role;

-- Task 9: immutable receiver snapshot and Admin mutation idempotency.
set local role service_role;
select pg_temp.make_v2_event(
  'e9999999-9999-4999-8999-999999999999', 'a1111111-1111-4111-8111-111111111111',
  'draft', now() + interval '1 hour', now() + interval '2 hours'
);
update public.workspaces set
  name = 'Workspace Changed Later',
  office_phone_e164 = '+6281999999999',
  office_address = 'Jl. Workspace Baru'
where owner_user_id = 'a1111111-1111-4111-8111-111111111111';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  api.upsert_event_draft_v2(
    'e9999999-9999-4999-8999-999999999999',
    '10000000-0000-4000-8000-000000000013',
    '{}'::jsonb
  ) ->> 'receiver_name',
  'Receiver Test', 'draft keeps its receiver snapshot after workspace edits'
);
insert into pg_temp.tap_results(result)
select is(
  api.cancel_or_delete_event_v2(
    'e6666666-6666-4666-8666-666666666666',
    'v2-event-cancel', '10000000-0000-4000-8000-000000000014'
  ) ->> 'status',
  'cancelled', 'same event cancellation key replays its original result'
);
insert into pg_temp.tap_results(result)
select throws_ok(
  $$select api.cancel_or_delete_event_v2(
    'e4444444-4444-4444-8444-444444444444',
    'v2-event-cancel', '10000000-0000-4000-8000-000000000015'
  )$$,
  '23505', 'IDEMPOTENCY_CONFLICT', 'event cancellation rejects a reused key with another event'
);
reset role;

-- Task 10: tracking replay and payload conflict.
set local role service_role;
select pg_temp.make_v2_event(
  'e8888888-8888-4888-8888-888888888888', 'a1111111-1111-4111-8111-111111111111',
  'ongoing', now() - interval '1 hour', now() + interval '2 hours'
);
select api.create_account_booking_v2(
  'd1111111-1111-4111-8111-111111111111', 'e8888888-8888-4888-8888-888888888888',
  'v2-tracking-replay-booking', 'request-hash-tracking-replay',
  pg_temp.account_booking('KPL-V2GGG-00007', repeat('7', 64), 300, '10000000-0000-4000-8000-000000000016')
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true);
select api.decide_reception_v2(
  (select id from public.bookings where public_booking_id = 'KPL-V2GGG-00007'), 'accepted', 300,
  'v2-tracking-replay-reception', '10000000-0000-4000-8000-000000000017'
);
insert into pg_temp.tap_results(result)
select is(
  api.advance_booking_status_v1(
    (select id from public.bookings where public_booking_id = 'KPL-V2GGG-00007'), 'processed',
    'v2-tracking-replay', '10000000-0000-4000-8000-000000000018'
  ) ->> 'status',
  'processed', 'tracking mutation accepts its initial idempotent request'
);
insert into pg_temp.tap_results(result)
select is(
  api.advance_booking_status_v1(
    (select id from public.bookings where public_booking_id = 'KPL-V2GGG-00007'), 'processed',
    'v2-tracking-replay', '10000000-0000-4000-8000-000000000019'
  ) ->> 'status',
  'processed', 'tracking mutation replays the initial result'
);
insert into pg_temp.tap_results(result)
select throws_ok(
  $$select api.advance_booking_status_v1(
    (select id from public.bookings where public_booking_id = 'KPL-V2GGG-00007'), 'recycled',
    'v2-tracking-replay', '10000000-0000-4000-8000-000000000020'
  )$$,
  '23505', 'IDEMPOTENCY_CONFLICT', 'tracking rejects a changed payload for the same key'
);
reset role;
select pg_temp.make_v2_event(
  'e7777777-7777-4777-8777-777777777777', 'a1111111-1111-4111-8111-111111111111',
  'draft', now() + interval '1 hour', now() + interval '2 hours'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select throws_ok(
  $$select api.event_detail_v2('e7777777-7777-4777-8777-777777777777')$$,
  'P0002', 'EVENT_NOT_FOUND', 'event detail hides a draft event'
);
reset role;

-- Task 2: profile read contracts.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  api.my_profile_v1() ->> 'display_name', 'V2 Donor One', 'my profile returns the owner display name'
);
insert into pg_temp.tap_results(result)
select is(
  api.my_profile_v1() ->> 'phone_e164', '+6281222222222', 'my profile returns the owner phone'
);
insert into pg_temp.tap_results(result)
select throws_ok(
  $$select api.workspace_profile_v1()$$,
  '42501', 'ROLE_FORBIDDEN', 'workspace profile rejects a donor role'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  api.workspace_profile_v1() ->> 'publishable', 'false',
  'workspace publishable stays false until the profile is complete'
);
reset role;

-- Task 3: my_bookings_v1 for the donor.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  jsonb_array_length(api.my_bookings_v1()), 4,
  'my bookings lists every non-cancelled booking'
);
insert into pg_temp.tap_results(result)
select is(
  (select count(*) from jsonb_array_elements(api.my_bookings_v1()) as b
    where (b ->> 'can_cancel')::boolean),
  1::bigint, 'only the waiting booking can be cancelled'
);
insert into pg_temp.tap_results(result)
select is(
  (select b ->> 'actual_weight_grams' from jsonb_array_elements(api.my_bookings_v1()) as b
    where b ->> 'public_booking_id' = 'KPL-V2EEE-00005'),
  '500', 'my bookings carries the accepted actual weight'
);
reset role;

-- Task 4: booking detail QR payload (owner only) and actual weight.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  api.booking_detail_v2(pg_temp.booking_id('KPL-V2EEE-00005'))
    ->> 'qr_token_ciphertext',
  'encrypted-qr', 'booking detail returns the QR ciphertext to its owner'
);
insert into pg_temp.tap_results(result)
select is(
  api.booking_detail_v2(pg_temp.booking_id('KPL-V2EEE-00005'))
    ->> 'actual_weight_grams',
  '500', 'booking detail carries the accepted actual weight'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  api.booking_detail_v2(pg_temp.booking_id('KPL-V2EEE-00005'))
    ->> 'qr_token_ciphertext',
  null, 'booking detail never leaks the QR ciphertext to the workspace'
);
reset role;

-- Task 5: admin_recap_v2 range, recent donations, and unique donors.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  api.admin_recap_v2() -> 'recent_donations' -> 0 ->> 'donor_name',
  'V2 Donor One', 'recap recent donations resolve the active profile name'
);
insert into pg_temp.tap_results(result)
select is(
  api.admin_recap_v2() -> 'month' ->> 'unique_donor_count',
  '1', 'recap month counts unique donors by account id'
);
insert into pg_temp.tap_results(result)
select is(
  (select d ->> 'accepted_weight_grams'
    from jsonb_array_elements(api.admin_recap_v2() -> 'daily') as d
    where d ->> 'date' = ((now() at time zone 'Asia/Jakarta')::date)::text),
  '800', 'recap daily aggregates actual accepted weight for today'
);
insert into pg_temp.tap_results(result)
select is(
  jsonb_array_length(
    api.admin_recap_v2(
      null, (now() at time zone 'Asia/Jakarta')::date,
      (now() at time zone 'Asia/Jakarta')::date, null
    ) -> 'daily'
  ),
  1, 'explicit from/to recap returns exactly the requested calendar days'
);
insert into pg_temp.tap_results(result)
select throws_ok(
  $$select api.admin_recap_v2(
    null, (now() at time zone 'Asia/Jakarta')::date,
    (now() at time zone 'Asia/Jakarta')::date - 1, null
  )$$,
  '22023', 'INVALID_DATE_RANGE', 'recap rejects an inverted date range'
);
reset role;

-- Task 6: direct table writes are rejected for authenticated roles.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select throws_ok(
  $$update public.bookings set status = 'rejected'
    where public_booking_id = 'KPL-V2AAA-00001'$$,
  '42501', 'permission denied for table bookings',
  'direct booking status write is denied before RLS evaluation'
);
insert into pg_temp.tap_results(result)
select is(
  (select status::text from public.bookings where public_booking_id = 'KPL-V2AAA-00001'),
  'waiting', 'direct booking status write is rejected by RLS'
);
insert into pg_temp.tap_results(result)
select throws_ok(
  $$insert into public.receptions(
    booking_id, workspace_id, event_id, decision, actual_weight_grams, processed_by
  ) values (
    (select id from public.bookings where public_booking_id = 'KPL-V2AAA-00001'),
    (select workspace_id from public.bookings where public_booking_id = 'KPL-V2AAA-00001'),
    'e1111111-1111-4111-8111-111111111111', 'accepted', 100,
    'a1111111-1111-4111-8111-111111111111'
  )$$,
  '42501', 'permission denied for table receptions', 'direct reception insert is denied before RLS evaluation'
);
insert into pg_temp.tap_results(result)
select throws_ok(
  $$update public.events set capacity_grams = 999999
    where id = 'e1111111-1111-4111-8111-111111111111'$$,
  '42501', 'permission denied for table events',
  'direct event capacity write is denied before RLS evaluation'
);
insert into pg_temp.tap_results(result)
select is(
  (select capacity_grams from public.events where id = 'e1111111-1111-4111-8111-111111111111'),
  1000::bigint, 'direct capacity write is rejected by RLS'
);
reset role;

-- Task 7: cursor pagination for the donor event history.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  jsonb_array_length(api.user_event_history_v1()), 4,
  'legacy history call without limit keeps the plain array shape'
);
insert into pg_temp.tap_results(result)
select is(
  jsonb_array_length(api.user_event_history_v1(p_limit => 2) -> 'items'), 2,
  'history page limit applies'
);
insert into pg_temp.tap_results(result)
select is(
  (select api.user_event_history_v1(p_limit => 2) ->> 'next_cursor' is not null), true,
  'history page announces the next cursor'
);
insert into pg_temp.tap_results(result)
select is(
  (with page1 as (
     select api.user_event_history_v1(p_limit => 2) as r
   ), page2 as (
     select api.user_event_history_v1(
       p_limit => 2, p_cursor => (select r ->> 'next_cursor' from page1)
     ) as r
   )
   select count(*)
   from page1, page2,
    jsonb_array_elements((page1.r -> 'items') || (page2.r -> 'items')) as item),
  4::bigint, 'cursor walk returns every non-cancelled booking exactly once'
);
insert into pg_temp.tap_results(result)
select is(
  (select api.user_event_history_v1(
     p_limit => 2, p_cursor => (select api.user_event_history_v1(p_limit => 2) ->> 'next_cursor')
   ) ->> 'next_cursor'),
  null, 'history cursor terminates after the final page'
);
insert into pg_temp.tap_results(result)
select throws_ok(
  $$select api.user_event_history_v1(p_limit => 2, p_cursor => 'not-a-valid-cursor!')$$,
  '22023', 'CURSOR_INVALID', 'history rejects a malformed cursor'
);
reset role;

-- Task 8: terminal filter for Acara Sebelumnya.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1111111-1111-4111-8111-111111111111', true);
insert into pg_temp.tap_results(result)
select is(
  jsonb_array_length(api.user_event_history_v1(p_terminal => true)), 2,
  'terminal history keeps only finished bookings and events'
);
insert into pg_temp.tap_results(result)
select is(
  jsonb_array_length(api.user_event_history_v1(p_terminal => false)), 2,
  'active history keeps only trackable bookings on live events'
);
reset role;

insert into pg_temp.tap_results(result)
select * from extensions.finish();

select result from pg_temp.tap_results order by sequence;
rollback;
