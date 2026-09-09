begin;

create extension if not exists pgtap with schema extensions;
select plan(28);

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
    'terms_version', 'test-v1', 'privacy_version', 'test-v1', 'request_id', p_request_id
  )
$$;

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
  $$select api.booking_detail_v2((select id from public.bookings where public_booking_id = 'KPL-V2AAA-00001'))$$,
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
    '10000000-0000-4000-8000-000000000008'
  ) ->> 'status', 'processed', 'admin advances accepted booking to processed'
);
insert into pg_temp.tap_results(result)
select is(
  api.advance_booking_status_v1(
    (select id from public.bookings where public_booking_id = 'KPL-V2EEE-00005'), 'recycled',
    '10000000-0000-4000-8000-000000000009'
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
  api.cancel_or_delete_event_v2('e5555555-5555-4555-8555-555555555555', '10000000-0000-4000-8000-000000000010') ->> 'action',
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
  api.cancel_or_delete_event_v2('e6666666-6666-4666-8666-666666666666', '10000000-0000-4000-8000-000000000012') ->> 'status',
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

insert into pg_temp.tap_results(result)
select * from extensions.finish();

select result from pg_temp.tap_results order by sequence;
rollback;
