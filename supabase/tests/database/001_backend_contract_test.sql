begin;

create extension if not exists pgtap with schema extensions;
select plan(75);

create or replace function pg_temp.make_event(
  p_id uuid,
  p_owner uuid,
  p_name text,
  p_status public.event_status default 'draft',
  p_start_at timestamptz default now() - interval '1 hour',
  p_end_at timestamptz default now() + interval '6 hours',
  p_capacity bigint default 100000,
  p_received bigint default 0
)
returns uuid
language plpgsql
as $$
declare
  v_workspace_id uuid;
begin
  select id into v_workspace_id from public.workspaces where owner_user_id = p_owner;
  insert into public.events (
    id, workspace_id, name, description, status, published_at, terminal_at,
    start_at, end_at, timezone_name, operational_days, opens_at_local,
    closes_at_local, location_name, location_address, location_country_code,
    latitude, longitude, capacity_grams, received_weight_grams,
    banner_object_path, receiver_name, receiver_phone, receiver_address
  ) values (
    p_id, v_workspace_id, p_name, 'Test event description', p_status,
    case when p_status in ('upcoming', 'ongoing') then now() else null end,
    case when p_status in ('completed', 'closed', 'cancelled') then p_end_at else null end,
    p_start_at, p_end_at, 'Asia/Jakarta', array[1,2,3,4,5]::smallint[],
    '08:00'::time, '17:00'::time, 'Jakarta drop point',
    'Jl. Test No. 1, Jakarta', 'ID', -6.2, 106.8, p_capacity, p_received,
    v_workspace_id::text || '/' || p_id::text || '/banner.png',
    'Penerima Test', '+6281234567890', 'Jl. Gudang Test, Jakarta'
  );
  insert into public.event_criteria (event_id, criterion) values (p_id, 'cotton');
  return p_id;
end;
$$;

create or replace function pg_temp.booking_payload(
  p_public_id text,
  p_phone_hash text,
  p_qr_hash text,
  p_request_id uuid
)
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    'public_booking_id', p_public_id,
    'donor_name_ciphertext', 'encrypted-name',
    'donor_name_nonce', 'name-nonce',
    'donor_phone_ciphertext', 'encrypted-phone',
    'donor_phone_nonce', 'phone-nonce',
    'phone_lookup_hash', p_phone_hash,
    'crypto_key_version', 1,
    'estimated_weight_grams', 500,
    'item_count', 1,
    'items', jsonb_build_array(jsonb_build_object(
      'ordinal', 0,
      'passed', true,
      'scanner_model_version', 'test-model-v1',
      'metadata', jsonb_build_object('category', 'shirt')
    )),
    'shipping_method', 'direct',
    'scan_model_version', 'test-model-v1',
    'qr_token_hash', p_qr_hash,
    'qr_token_ciphertext', 'encrypted-qr',
    'qr_token_nonce', 'qr-nonce',
    'terms_version', 'local-v1',
    'privacy_version', 'local-v1',
    'request_id', p_request_id
  )
$$;

create or replace function pg_temp.event_draft_payload(p_name text)
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    'name', p_name,
    'timezone_name', 'Asia/Jakarta',
    'operational_days', jsonb_build_array(1, 2, 3, 4, 5),
    'opens_at_local', '08:00:00',
    'closes_at_local', '17:00:00',
    'location_country_code', 'ID',
    'capacity_grams', 100000,
    'criteria', jsonb_build_array('cotton')
  )
$$;

insert into auth.users (id, email, raw_user_meta_data, raw_app_meta_data)
values
  (
    '11111111-1111-4111-8111-111111111111',
    'organizer-one@example.invalid',
    '{"display_name":"Organizer One"}'::jsonb,
    '{"provider":"email","providers":["email"]}'::jsonb
  ),
  (
    '22222222-2222-4222-8222-222222222222',
    'organizer-two@example.invalid',
    '{"display_name":"Organizer Two"}'::jsonb,
    '{"provider":"email","providers":["email"]}'::jsonb
  );

select is(
  (select count(*) from public.profiles where id in (
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222'
  )),
  2::bigint,
  'signup creates one profile for each organizer'
);

-- Workspaces are provisioned during onboarding (admin role), not at signup.
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select is(
  api.complete_onboarding_v1('admin') ->> 'role',
  'admin',
  'organizer one onboards as admin'
);
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select is(
  api.complete_onboarding_v1('admin') ->> 'role',
  'admin',
  'organizer two onboards as admin'
);
reset role;

select is(
  (select count(*) from public.workspaces where owner_user_id in (
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222'
  )),
  2::bigint,
  'onboarding creates one workspace for each organizer'
);
select is(
  (select count(distinct owner_user_id) from public.workspaces where owner_user_id in (
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222'
  )),
  2::bigint,
  'workspace ownership remains one-to-one'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'api.publish_event_v1(uuid,uuid,text,text,text,smallint,public.deployment_environment,uuid)',
    'execute'
  ),
  'authenticated clients cannot bypass the publish Edge Function'
);
select ok(
  not has_function_privilege('authenticated', 'api.resolve_event_v1(text)', 'execute'),
  'authenticated clients cannot call public invocation internals directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.events', 'update'),
  'event mutation is RPC-only'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select is(
  api.upsert_event_draft_v1(
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000030',
    '10000000-0000-4000-8000-000000000030',
    pg_temp.event_draft_payload('Offline draft')
  ) ->> 'id',
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000030',
  'new draft preserves its client-generated UUID'
);
select is(
  api.upsert_event_draft_v1(
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000030',
    '10000000-0000-4000-8000-000000000030',
    pg_temp.event_draft_payload('Offline draft')
  ) ->> 'version',
  '1',
  'same draft mutation retry returns the original result'
);
select throws_ok(
  $test$
    select api.upsert_event_draft_v1(
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000030',
      '10000000-0000-4000-8000-000000000030',
      pg_temp.event_draft_payload('Conflicting payload')
    )
  $test$,
  '23505',
  'IDEMPOTENCY_CONFLICT',
  'same draft mutation ID rejects a different payload'
);
select is(
  api.upsert_event_draft_v1(
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000030',
    '10000000-0000-4000-8000-000000000031',
    pg_temp.event_draft_payload('Latest server commit')
  ) ->> 'name',
  'Latest server commit',
  'a newer mutation becomes the latest server draft commit'
);
reset role;

select pg_temp.make_event(
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000001',
  '11111111-1111-4111-8111-111111111111',
  'Published ongoing event'
);
set local role service_role;
select is(
  api.publish_event_v1(
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000001',
    repeat('a', 64), 'encrypted-invocation-1', 'nonce-1', 1::smallint,
    'local'::public.deployment_environment,
    '10000000-0000-4000-8000-000000000001'
  ) -> 'event' ->> 'status',
  'ongoing',
  'publish derives ongoing from server time'
);
select is(
  api.resolve_event_v1(repeat('a', 64)) -> 'legal' ->> 'terms_version',
  'local-v1',
  'public event context carries the invocation environment legal version'
);
reset role;

insert into public.events (id, workspace_id, name)
values (
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000002',
  (select id from public.workspaces where owner_user_id = '11111111-1111-4111-8111-111111111111'),
  'Incomplete event'
);
set local role service_role;
select throws_ok(
  $test$
    select api.publish_event_v1(
      '11111111-1111-4111-8111-111111111111',
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000002',
      repeat('b', 64), 'encrypted-invocation-2', 'nonce-2', 1::smallint,
      'local'::public.deployment_environment,
      '10000000-0000-4000-8000-000000000002'
    )
  $test$,
  '23514',
  'EVENT_PUBLISH_FIELDS_REQUIRED',
  'publish rejects an incomplete draft'
);
reset role;

select pg_temp.make_event(
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
  '11111111-1111-4111-8111-111111111111',
  'Published upcoming event',
  'draft', now() + interval '2 hours', now() + interval '8 hours'
);
set local role service_role;
select is(
  api.publish_event_v1(
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
    repeat('c', 64), 'encrypted-invocation-9', 'nonce-9', 1::smallint,
    'local'::public.deployment_environment,
    '10000000-0000-4000-8000-000000000009'
  ) -> 'event' ->> 'status',
  'upcoming',
  'publish derives upcoming from server time'
);
reset role;

select pg_temp.make_event(
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000003',
  '11111111-1111-4111-8111-111111111111',
  'Existing active event 3', 'upcoming', now() + interval '1 day', now() + interval '2 days'
);
select pg_temp.make_event(
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000004',
  '11111111-1111-4111-8111-111111111111',
  'Existing active event 4', 'upcoming', now() + interval '1 day', now() + interval '2 days'
);
select pg_temp.make_event(
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000005',
  '11111111-1111-4111-8111-111111111111',
  'Existing active event 5', 'upcoming', now() + interval '1 day', now() + interval '2 days'
);
select pg_temp.make_event(
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000007',
  '11111111-1111-4111-8111-111111111111',
  'Sixth active event candidate'
);
set local role service_role;
select throws_ok(
  $test$
    select api.publish_event_v1(
      '11111111-1111-4111-8111-111111111111',
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000007',
      repeat('d', 64), 'encrypted-invocation-7', 'nonce-7', 1::smallint,
      'local'::public.deployment_environment,
      '10000000-0000-4000-8000-000000000007'
    )
  $test$,
  '23514',
  'ACTIVE_EVENT_LIMIT',
  'sixth active event is rejected'
);
reset role;

select pg_temp.make_event(
  'bbbbbbbb-bbbb-4bbb-8bbb-000000000001',
  '22222222-2222-4222-8222-222222222222',
  'Other tenant event'
);
select pg_temp.make_event(
  'cccccccc-cccc-4ccc-8ccc-000000000002',
  '22222222-2222-4222-8222-222222222222',
  'Other tenant event with matching timestamp'
);

select ok(
  has_function_privilege('authenticated', 'api.list_events_v2(text,integer)', 'execute'),
  'authenticated clients can use the opaque event cursor RPC'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select is(
  jsonb_array_length(api.list_events_v2(null, 1) -> 'items'),
  1,
  'opaque cursor RPC applies the requested page limit'
);
select ok(
  length(api.list_events_v2(null, 1) ->> 'cursor') > 16,
  'opaque cursor RPC returns a server-generated cursor'
);
select is(
  api.list_events_v2(
    api.list_events_v2(null, 1) ->> 'cursor', 1
  ) -> 'items' -> 0 ->> 'id',
  'cccccccc-cccc-4ccc-8ccc-000000000002',
  'cursor includes UUID ordering so equal timestamps do not skip rows'
);
select throws_ok(
  $test$select api.list_events_v2('not-a-valid-cursor', 1)$test$,
  '22023',
  'CURSOR_INVALID',
  'malformed event cursors are rejected safely'
);
reset role;

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname in (
        'event_banners_owner_insert',
        'event_banners_owner_update',
        'event_banners_owner_delete'
      )
  ),
  0::bigint,
  'authenticated clients have no direct banner write policy'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select ok(
  exists(select 1 from public.events where id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000001'),
  'owner can read own event through RLS'
);
select ok(
  not exists(select 1 from public.events where id = 'bbbbbbbb-bbbb-4bbb-8bbb-000000000001'),
  'owner cannot read another tenant event through RLS'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select ok(
  not exists(select 1 from public.events where id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000001'),
  'second tenant cannot read first tenant event'
);
select throws_ok(
  $test$select api.get_event_v1('aaaaaaaa-aaaa-4aaa-8aaa-000000000001')$test$,
  'P0002',
  'EVENT_NOT_FOUND',
  'cross-tenant event RPC returns not found'
);
reset role;

select pg_temp.make_event(
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000008',
  '11111111-1111-4111-8111-111111111111',
  'Reception event', 'ongoing', now() - interval '1 hour', now() + interval '4 hours', 1000
);
insert into public.event_invocations (
  event_id, token_hash, token_ciphertext, token_nonce, environment
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000008', repeat('8', 64),
  'encrypted-invocation-8', 'nonce-8', 'local'
);

set local role service_role;
select is(
  api.create_booking_v1(
    repeat('8', 64), repeat('f', 64), 'booking-key-0001', repeat('1', 64),
    pg_temp.booking_payload(
      'KPL-ABCDE-FGHJK', repeat('p', 64), repeat('q', 64),
      '20000000-0000-4000-8000-000000000001'
    )
  ) ->> 'status',
  'waiting',
  'booking is created in waiting state'
);
select is(
  (select received_weight_grams from public.events where id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000008'),
  0::bigint,
  'booking estimated weight does not consume capacity'
);
select ok(
  (select b.expires_at <= e.end_at
   from public.bookings as b join public.events as e on e.id = b.event_id
   where b.public_booking_id = 'KPL-ABCDE-FGHJK'),
  'booking expiry never exceeds event end'
);
select is(
  api.create_booking_v1(
    repeat('8', 64), repeat('f', 64), 'booking-key-0001', repeat('1', 64),
    pg_temp.booking_payload(
      'KPL-ZZZZZ-ZZZZZ', repeat('p', 64), repeat('z', 64),
      '20000000-0000-4000-8000-000000000009'
    )
  ) ->> 'idempotent_replay',
  'true',
  'booking retry returns the original result'
);
select is(
  (select count(*) from public.bookings where event_id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000008'),
  1::bigint,
  'booking retry does not create a duplicate row'
);
select throws_ok(
  $test$
    select api.create_booking_v1(
      repeat('8', 64), repeat('f', 64), 'booking-key-0001', repeat('2', 64),
      pg_temp.booking_payload(
        'KPL-ZZZZZ-YYYYY', repeat('p', 64), repeat('y', 64),
        '20000000-0000-4000-8000-000000000010'
      )
    )
  $test$,
  '23505',
  'IDEMPOTENCY_CONFLICT',
  'same booking key rejects a different payload hash'
);
select is(
  api.create_booking_v1(
    repeat('8', 64), repeat('g', 64), 'booking-key-0002', repeat('3', 64),
    pg_temp.booking_payload(
      'KPL-MNPQR-STVWX', repeat('r', 64), repeat('s', 64),
      '20000000-0000-4000-8000-000000000002'
    )
  ) ->> 'status',
  'waiting',
  'a second distinct booking can be created'
);
reset role;

update public.events set name = 'Reception event edited'
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000008';
select is(
  (select event_snapshot ->> 'name' from public.bookings where public_booking_id = 'KPL-ABCDE-FGHJK'),
  'Reception event',
  'event edit does not mutate an existing booking snapshot'
);
select throws_ok(
  $test$
    update public.bookings set event_snapshot = '{"schema_version":99}'::jsonb
    where public_booking_id = 'KPL-ABCDE-FGHJK'
  $test$,
  'P0001',
  'BOOKING_SNAPSHOT_IMMUTABLE',
  'database trigger rejects snapshot mutation'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select is(
  api.decide_reception_v1(
    (select id from public.bookings where public_booking_id = 'KPL-ABCDE-FGHJK'),
    'accepted', 1000, 'good', null, null, 'reception-key-0001',
    '30000000-0000-4000-8000-000000000001'
  ) ->> 'status',
  'accepted',
  'accept decision processes the whole booking'
);
select is(
  (select received_weight_grams from public.events where id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000008'),
  1000::bigint,
  'accepted actual weight updates the capacity ledger exactly'
);
select is(
  (select status::text from public.bookings where public_booking_id = 'KPL-MNPQR-STVWX'),
  'cancelled',
  'exact capacity cancels remaining waiting bookings'
);
select is(
  api.decide_reception_v1(
    (select id from public.bookings where public_booking_id = 'KPL-ABCDE-FGHJK'),
    'accepted', 1000, 'good', null, null, 'reception-key-0001',
    '30000000-0000-4000-8000-000000000001'
  ) ->> 'status',
  'accepted',
  'reception retry returns the original response'
);
select is(
  (select count(*) from public.receptions where event_id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000008'),
  1::bigint,
  'reception retry does not duplicate reception or weight'
);
reset role;
set local role service_role;
select throws_ok(
  $test$
    select api.resolve_qr_v1(
      '11111111-1111-4111-8111-111111111111', repeat('q', 64)
    )
  $test$,
  'P0001',
  'BOOKING_NOT_PROCESSABLE',
  'a used QR cannot be processed again'
);
reset role;

select pg_temp.make_event(
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000010',
  '11111111-1111-4111-8111-111111111111',
  'Overflow event', 'ongoing', now() - interval '1 hour', now() + interval '4 hours', 500
);
insert into public.event_invocations (
  event_id, token_hash, token_ciphertext, token_nonce, environment
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000010', repeat('a', 63) || '0',
  'encrypted-invocation-10', 'nonce-10', 'local'
);
set local role service_role;
select api.create_booking_v1(
  repeat('a', 63) || '0', repeat('h', 64), 'booking-key-0010', repeat('4', 64),
  pg_temp.booking_payload(
    'KPL-12345-6789A', repeat('t', 64), repeat('u', 64),
    '20000000-0000-4000-8000-000000000010'
  )
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select throws_ok(
  $test$
    select api.decide_reception_v1(
      (select id from public.bookings where public_booking_id = 'KPL-12345-6789A'),
      'accepted', 600, 'good', null, null, 'reception-key-0010',
      '30000000-0000-4000-8000-000000000010'
    )
  $test$,
  '23514',
  'CAPACITY_EXCEEDED',
  'overflow acceptance rolls back'
);
reset role;
select is(
  (select count(*) from public.receptions where event_id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000010'),
  0::bigint,
  'overflow leaves no partial reception'
);

select pg_temp.make_event(
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000011',
  '11111111-1111-4111-8111-111111111111',
  'Rejected event', 'ongoing', now() - interval '1 hour', now() + interval '4 hours', 1000
);
insert into public.event_invocations (
  event_id, token_hash, token_ciphertext, token_nonce, environment
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000011', repeat('b', 63) || '1',
  'encrypted-invocation-11', 'nonce-11', 'local'
);
set local role service_role;
select api.create_booking_v1(
  repeat('b', 63) || '1', repeat('i', 64), 'booking-key-0011', repeat('5', 64),
  pg_temp.booking_payload(
    'KPL-BCDEF-GHJKM', repeat('v', 64), repeat('w', 64),
    '20000000-0000-4000-8000-000000000011'
  )
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select is(
  api.decide_reception_v1(
    (select id from public.bookings where public_booking_id = 'KPL-BCDEF-GHJKM'),
    'rejected', 250, 'damaged', null, null, 'reception-key-0011',
    '30000000-0000-4000-8000-000000000011'
  ) ->> 'status',
  'rejected',
  'rejection can omit a reason and remains whole-booking'
);
select is(
  (select received_weight_grams from public.events where id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000011'),
  0::bigint,
  'rejected reception does not change capacity'
);
reset role;

select pg_temp.make_event(
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000012',
  '11111111-1111-4111-8111-111111111111',
  'Close event', 'ongoing', now() - interval '1 hour', now() + interval '4 hours', 1000
);
insert into public.event_invocations (
  event_id, token_hash, token_ciphertext, token_nonce, environment
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000012', repeat('c', 63) || '2',
  'encrypted-invocation-12', 'nonce-12', 'local'
);
set local role service_role;
select api.create_booking_v1(
  repeat('c', 63) || '2', repeat('j', 64), 'booking-key-0012', repeat('6', 64),
  pg_temp.booking_payload(
    'KPL-NPQRS-TVWXY', repeat('x', 64), repeat('y', 64),
    '20000000-0000-4000-8000-000000000012'
  )
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select is(
  api.terminate_event_v1(
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000012', 'closed', null,
    '30000000-0000-4000-8000-000000000012'
  ) ->> 'status',
  'closed',
  'organizer can close a nonterminal event'
);
select is(
  (select status::text from public.bookings where public_booking_id = 'KPL-NPQRS-TVWXY'),
  'cancelled',
  'closing an event atomically cancels waiting bookings'
);
reset role;

select pg_temp.make_event(
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000013',
  '11111111-1111-4111-8111-111111111111',
  'Retained aggregate event', 'completed',
  now() - interval '40 days', now() - interval '35 days', 5000, 777
);
insert into public.bookings (
  id, public_booking_id, event_id, workspace_id,
  donor_name_ciphertext, donor_name_nonce, donor_phone_ciphertext, donor_phone_nonce,
  phone_lookup_hash, estimated_weight_grams, item_count, shipping_method,
  scan_model_version, status, terminal_reason_code, event_snapshot,
  qr_token_hash, qr_token_ciphertext, qr_token_nonce,
  terms_version, privacy_version, consented_at, expires_at, terminal_at, created_at
) values (
  '40000000-0000-4000-8000-000000000013', 'KPL-ZYXWV-TSRQP',
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000013',
  (select id from public.workspaces where owner_user_id = '11111111-1111-4111-8111-111111111111'),
  'encrypted-old-name', 'old-name-nonce', 'encrypted-old-phone', 'old-phone-nonce',
  repeat('o', 64), 700, 1, 'direct', 'test-model-v1', 'recycled', 'recycled',
  '{"schema_version":1,"name":"Retained aggregate event"}'::jsonb,
  repeat('z', 64), 'encrypted-old-qr', 'old-qr-nonce',
  'local-v1', 'local-v1', now() - interval '40 days', now() - interval '35 days',
  now() - interval '35 days', now() - interval '40 days'
);
insert into public.booking_items (
  booking_id, ordinal, passed, scanner_model_version, metadata
) values (
  '40000000-0000-4000-8000-000000000013', 0, true, 'test-model-v1', '{}'
);
insert into public.receptions (
  booking_id, workspace_id, event_id, decision, actual_weight_grams,
  condition, processed_by, processed_at
) values (
  '40000000-0000-4000-8000-000000000013',
  (select id from public.workspaces where owner_user_id = '11111111-1111-4111-8111-111111111111'),
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000013', 'accepted', 777, 'good',
  '11111111-1111-4111-8111-111111111111', now() - interval '35 days'
);
insert into public.event_invocations (
  event_id, token_hash, token_ciphertext, token_nonce, environment, revoked_at
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-000000000013', repeat('d', 63) || '3',
  'encrypted-old-invocation', 'old-invocation-nonce', 'local', now() - interval '35 days'
);
insert into public.audit_events (
  actor_type, workspace_id, entity_type, entity_id, action_code, request_id, created_at
) values (
  'organizer',
  (select id from public.workspaces where owner_user_id = '11111111-1111-4111-8111-111111111111'),
  'booking', '40000000-0000-4000-8000-000000000013', 'old.audit',
  '50000000-0000-4000-8000-000000000013', now() - interval '31 days'
);
select is(
  private.run_retention_job() ->> 'status',
  'succeeded',
  'retention job succeeds for eligible terminal data'
);
select ok(
  not exists(select 1 from public.bookings where id = '40000000-0000-4000-8000-000000000013'),
  'retention removes eligible raw bookings and cascaded detail'
);
select is(
  (select sum(total_accepted_weight_grams) from public.impact_aggregates
   where event_id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000013'),
  777::numeric,
  'actual accepted aggregate survives raw-data retention'
);
select ok(
  not exists(select 1 from public.audit_events where request_id = '50000000-0000-4000-8000-000000000013'),
  'audit cleanup uses audit creation age'
);
select is(
  private.run_retention_job() ->> 'status',
  'succeeded',
  'retention job is safe to rerun'
);
select is(
  (select count(*) from cron.job where jobname = 'kumpul-lifecycle-expiry'),
  1::bigint,
  'lifecycle reconciliation is scheduled once'
);
select is(
  (select count(*) from cron.job where jobname = 'kumpul-retention'),
  1::bigint,
  'retention is scheduled once'
);
select is(
  (select count(*) from cron.job where jobname = 'kumpul-banner-orphan-cleanup'),
  1::bigint,
  'banner orphan cleanup is scheduled once'
);

set local role service_role;
select is(
  api.consume_rate_limit_v1('test', repeat('l', 64), 60, 1) ->> 'allowed',
  'true',
  'rate limiter allows the first request'
);
select is(
  api.consume_rate_limit_v1('test', repeat('l', 64), 60, 1) ->> 'allowed',
  'false',
  'rate limiter atomically rejects a request over quota'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select is((select count(*) from public.bookings), 0::bigint, 'second tenant cannot read first tenant bookings');
select is((select count(*) from public.receptions), 0::bigint, 'second tenant cannot read first tenant receptions');
select is((select count(*) from public.impact_aggregates), 0::bigint, 'second tenant cannot read first tenant aggregates');
reset role;

select ok(
  (
    select bool_and(c.relrowsecurity)
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and c.relname in (
        'profiles', 'workspaces', 'events', 'event_criteria', 'event_invocations',
        'bookings', 'booking_items', 'receptions', 'idempotency_keys',
        'legal_document_versions', 'audit_events', 'impact_aggregates',
        'job_runs', 'rate_limit_buckets'
      )
  ),
  'all Data API domain tables have RLS enabled'
);
select ok(
  (
    select bool_and(not p.prosecdef)
    from pg_proc as p join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'api'
  ),
  'all exposed API wrappers are security invoker'
);
select ok(
  (
    select bool_and('search_path=""' = any(coalesce(p.proconfig, array[]::text[])))
    from pg_proc as p join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.prosecdef
  ),
  'all private security-definer functions pin an empty search path'
);
select is(
  (
    select count(*) from information_schema.columns
    where table_schema = 'public'
      and column_name ~* '(photo|image|exif|embedding|scan_history|attempt_history)'
  ),
  0::bigint,
  'database schema has no donor photo or scan-history columns'
);
select ok(
  not has_table_privilege('anon', 'public.bookings', 'select'),
  'anonymous clients cannot enumerate bookings'
);
select ok(
  not has_table_privilege('authenticated', 'public.audit_events', 'select'),
  'raw audit records are not exposed to clients'
);
select ok(
  has_function_privilege(
    'service_role',
    'api.publish_event_v1(uuid,uuid,text,text,text,smallint,public.deployment_environment,uuid)',
    'execute'
  ),
  'publish Edge boundary has its required service-role grant'
);
select is(
  (select count(*) from public.receptions where booking_id = '40000000-0000-4000-8000-000000000013'),
  0::bigint,
  'retention cascades old reception rows'
);
select ok(
  not exists(
    select 1 from public.event_invocations where event_id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000013'
  ),
  'retention removes old invocation token material'
);
select is(
  (select total_accepted_weight_grams from public.impact_aggregates
   where event_id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000008'),
  1000::bigint,
  'recap aggregate uses actual accepted weight'
);
select is(
  (select unique_donor_count from public.impact_aggregates
   where event_id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000008'),
  1::bigint,
  'unique donor aggregate counts one accepted phone hash per event'
);

select ok(
  not has_table_privilege('authenticated', 'api.operational_health_v1', 'select'),
  'operational health is hidden from organizer clients'
);
select ok(
  has_table_privilege('service_role', 'api.operational_health_v1', 'select'),
  'service role can read operational health'
);
set local role service_role;
select is(
  (select capacity_invariant_violations from api.operational_health_v1),
  0::bigint,
  'operational health reports no capacity invariant violation'
);
reset role;

select * from finish();
rollback;
