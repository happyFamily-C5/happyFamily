#!/usr/bin/env bash
set -euo pipefail

DB_CONTAINER="${SUPABASE_DB_CONTAINER:-$(docker ps --format '{{.Names}}' | awk '/^supabase_db_/ {print; exit}')}"
if [[ -z "$DB_CONTAINER" ]]; then
  echo "Supabase database container is not running" >&2
  exit 1
fi

KUMPUL_CONCURRENCY_TMP="$(mktemp -d)"
cleanup() {
  rm -rf -- "$KUMPUL_CONCURRENCY_TMP"
}
trap cleanup EXIT

psql_exec() {
  docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d postgres "$@"
}

psql_exec <<'SQL'
insert into auth.users (id, email, raw_user_meta_data, raw_app_meta_data)
values (
  '33333333-3333-4333-8333-333333333333',
  'concurrency@example.invalid',
  '{"display_name":"Concurrency Test"}'::jsonb,
  '{"provider":"email","providers":["email"]}'::jsonb
);

with workspace as (
  select id from public.workspaces
  where owner_user_id = '33333333-3333-4333-8333-333333333333'
), candidates(id, name, status) as (
  values
    ('c0000000-0000-4000-8000-000000000001'::uuid, 'Active 1', 'upcoming'::public.event_status),
    ('c0000000-0000-4000-8000-000000000002'::uuid, 'Active 2', 'upcoming'::public.event_status),
    ('c0000000-0000-4000-8000-000000000003'::uuid, 'Active 3', 'upcoming'::public.event_status),
    ('c0000000-0000-4000-8000-000000000004'::uuid, 'Active 4', 'upcoming'::public.event_status),
    ('c0000000-0000-4000-8000-000000000005'::uuid, 'Candidate 5', 'draft'::public.event_status),
    ('c0000000-0000-4000-8000-000000000006'::uuid, 'Candidate 6', 'draft'::public.event_status)
)
insert into public.events (
  id, workspace_id, name, description, status, published_at, start_at, end_at,
  timezone_name, operational_days, opens_at_local, closes_at_local,
  location_name, location_address, location_country_code, latitude, longitude,
  capacity_grams, banner_object_path, receiver_name, receiver_phone, receiver_address
)
select c.id, w.id, c.name, 'Concurrency test event', c.status,
  case when c.status = 'upcoming' then now() else null end,
  now() + interval '1 hour', now() + interval '1 day', 'Asia/Jakarta',
  array[1,2,3,4,5]::smallint[], '08:00'::time, '17:00'::time,
  'Jakarta', 'Jl. Test Jakarta', 'ID', -6.2, 106.8, 10000,
  w.id::text || '/' || c.id::text || '/banner.png',
  'Penerima Test', '+6281234567890', 'Jl. Gudang Test'
from candidates as c cross join workspace as w;

insert into public.event_criteria (event_id, criterion)
select id, 'cotton'::public.criterion_code
from public.events
where id between 'c0000000-0000-4000-8000-000000000001'
  and 'c0000000-0000-4000-8000-000000000006';
SQL

upsert_same_draft() {
  psql_exec >"$1" 2>&1 <<'SQL'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select api.upsert_event_draft_v1(
  'c0000000-0000-4000-8000-000000000030',
  'c1000000-0000-4000-8000-000000000030',
  '{
    "name":"Concurrent offline draft",
    "timezone_name":"Asia/Jakarta",
    "operational_days":[1,2,3,4,5],
    "opens_at_local":"08:00:00",
    "closes_at_local":"17:00:00",
    "location_country_code":"ID",
    "capacity_grams":100000,
    "criteria":["cotton"]
  }'::jsonb
);
commit;
SQL
}

upsert_same_draft "$KUMPUL_CONCURRENCY_TMP/draft-1.log" &
draft_1_pid=$!
upsert_same_draft "$KUMPUL_CONCURRENCY_TMP/draft-2.log" &
draft_2_pid=$!
wait "$draft_1_pid"
wait "$draft_2_pid"

psql_exec -At <<'SQL' >"$KUMPUL_CONCURRENCY_TMP/draft-result.txt"
select
  (select count(*) from public.events
    where id = 'c0000000-0000-4000-8000-000000000030') || ':' ||
  (select version from public.events
    where id = 'c0000000-0000-4000-8000-000000000030') || ':' ||
  (select count(*) from public.idempotency_keys
    where scope = 'event-draft'
      and actor_scope = '33333333-3333-4333-8333-333333333333'
      and key = 'c1000000-0000-4000-8000-000000000030');
SQL
if [[ "$(tr -d '[:space:]' <"$KUMPUL_CONCURRENCY_TMP/draft-result.txt")" != "1:1:1" ]]; then
  echo "Concurrent draft retry created a duplicate or extra version" >&2
  cat "$KUMPUL_CONCURRENCY_TMP"/draft-*.log >&2
  cat "$KUMPUL_CONCURRENCY_TMP/draft-result.txt" >&2
  exit 1
fi

publish() {
  local event_id="$1"
  local token_hash="$2"
  local request_id="$3"
  psql_exec >"$4" 2>&1 <<SQL
begin;
set local role service_role;
select pg_sleep(0.1);
select api.publish_event_v1(
  '33333333-3333-4333-8333-333333333333',
  '$event_id', '$token_hash', 'ciphertext-$event_id', 'nonce-$event_id',
  1::smallint, 'local'::public.deployment_environment, '$request_id'
);
commit;
SQL
}

publish \
  'c0000000-0000-4000-8000-000000000005' \
  "$(printf '5%.0s' {1..64})" \
  'c1000000-0000-4000-8000-000000000005' \
  "$KUMPUL_CONCURRENCY_TMP/publish-5.log" &
publish_5_pid=$!
publish \
  'c0000000-0000-4000-8000-000000000006' \
  "$(printf '6%.0s' {1..64})" \
  'c1000000-0000-4000-8000-000000000006' \
  "$KUMPUL_CONCURRENCY_TMP/publish-6.log" &
publish_6_pid=$!

set +e
wait "$publish_5_pid"
publish_5_status=$?
wait "$publish_6_pid"
publish_6_status=$?
set -e

publish_successes=0
[[ "$publish_5_status" -eq 0 ]] && publish_successes=$((publish_successes + 1))
[[ "$publish_6_status" -eq 0 ]] && publish_successes=$((publish_successes + 1))
if [[ "$publish_successes" -ne 1 ]]; then
  echo "Expected exactly one concurrent publish to succeed" >&2
  cat "$KUMPUL_CONCURRENCY_TMP"/publish-*.log >&2
  exit 1
fi
if ! grep -q 'ACTIVE_EVENT_LIMIT' "$KUMPUL_CONCURRENCY_TMP"/publish-*.log; then
  echo "Expected the other concurrent publish to hit ACTIVE_EVENT_LIMIT" >&2
  cat "$KUMPUL_CONCURRENCY_TMP"/publish-*.log >&2
  exit 1
fi

psql_exec <<'SQL'
with workspace as (
  select id from public.workspaces
  where owner_user_id = '33333333-3333-4333-8333-333333333333'
)
insert into public.events (
  id, workspace_id, name, description, status, published_at, start_at, end_at,
  timezone_name, operational_days, opens_at_local, closes_at_local,
  location_name, location_address, location_country_code, latitude, longitude,
  capacity_grams, banner_object_path, receiver_name, receiver_phone, receiver_address
)
select 'c0000000-0000-4000-8000-000000000010', id, 'Capacity race',
  'Capacity race event', 'ongoing', now(), now() - interval '1 hour',
  now() + interval '4 hours', 'Asia/Jakarta', array[1,2,3,4,5]::smallint[],
  '08:00'::time, '17:00'::time, 'Jakarta', 'Jl. Test Jakarta', 'ID',
  -6.2, 106.8, 1000, id::text || '/capacity/banner.png',
  'Penerima Test', '+6281234567890', 'Jl. Gudang Test'
from workspace;

insert into public.event_criteria (event_id, criterion)
values ('c0000000-0000-4000-8000-000000000010', 'cotton');

insert into public.bookings (
  id, public_booking_id, event_id, workspace_id,
  donor_name_ciphertext, donor_name_nonce, donor_phone_ciphertext, donor_phone_nonce,
  phone_lookup_hash, estimated_weight_grams, item_count, shipping_method,
  scan_model_version, event_snapshot, qr_token_hash, qr_token_ciphertext, qr_token_nonce,
  terms_version, privacy_version, consented_at, expires_at
)
select b.id, b.public_id, 'c0000000-0000-4000-8000-000000000010', w.id,
  'name-cipher', 'name-nonce', 'phone-cipher', 'phone-nonce', b.phone_hash,
  700, 1, 'direct', 'test-model-v1', '{"schema_version":1}'::jsonb,
  b.qr_hash, 'qr-cipher', 'qr-nonce', 'local-v1', 'local-v1', now(), now() + interval '3 hours'
from public.workspaces as w
cross join (values
  ('c2000000-0000-4000-8000-000000000001'::uuid, 'KPL-CDEFG-HJKMN', repeat('1', 64), repeat('3', 64)),
  ('c2000000-0000-4000-8000-000000000002'::uuid, 'KPL-PQRST-VWXYZ', repeat('2', 64), repeat('4', 64))
) as b(id, public_id, phone_hash, qr_hash)
where w.owner_user_id = '33333333-3333-4333-8333-333333333333';
SQL

accept_booking() {
  local booking_id="$1"
  local key="$2"
  local request_id="$3"
  psql_exec >"$4" 2>&1 <<SQL
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select pg_sleep(0.1);
select api.decide_reception_v1(
  '$booking_id', 'accepted'::public.reception_decision, 700::bigint,
  'good'::public.item_condition, null::public.rejection_reason, null,
  '$key', '$request_id'
);
commit;
SQL
}

accept_booking \
  'c2000000-0000-4000-8000-000000000001' 'capacity-race-key-1' \
  'c3000000-0000-4000-8000-000000000001' \
  "$KUMPUL_CONCURRENCY_TMP/accept-1.log" &
accept_1_pid=$!
accept_booking \
  'c2000000-0000-4000-8000-000000000002' 'capacity-race-key-2' \
  'c3000000-0000-4000-8000-000000000002' \
  "$KUMPUL_CONCURRENCY_TMP/accept-2.log" &
accept_2_pid=$!

set +e
wait "$accept_1_pid"
accept_1_status=$?
wait "$accept_2_pid"
accept_2_status=$?
set -e

accept_successes=0
[[ "$accept_1_status" -eq 0 ]] && accept_successes=$((accept_successes + 1))
[[ "$accept_2_status" -eq 0 ]] && accept_successes=$((accept_successes + 1))
if [[ "$accept_successes" -ne 1 ]]; then
  echo "Expected exactly one capacity-race acceptance to succeed" >&2
  cat "$KUMPUL_CONCURRENCY_TMP"/accept-*.log >&2
  exit 1
fi
if ! grep -q 'CAPACITY_EXCEEDED' "$KUMPUL_CONCURRENCY_TMP"/accept-*.log; then
  echo "Expected the other capacity-race acceptance to be rejected" >&2
  cat "$KUMPUL_CONCURRENCY_TMP"/accept-*.log >&2
  exit 1
fi

psql_exec -At <<'SQL' >"$KUMPUL_CONCURRENCY_TMP/capacity-result.txt"
select received_weight_grams || ':' ||
  (select count(*) from public.receptions where event_id = e.id)
from public.events as e
where e.id = 'c0000000-0000-4000-8000-000000000010';
SQL
if [[ "$(tr -d '[:space:]' <"$KUMPUL_CONCURRENCY_TMP/capacity-result.txt")" != "700:1" ]]; then
  echo "Capacity invariant failed" >&2
  cat "$KUMPUL_CONCURRENCY_TMP/capacity-result.txt" >&2
  exit 1
fi

psql_exec <<'SQL'
with workspace as (
  select id from public.workspaces
  where owner_user_id = '33333333-3333-4333-8333-333333333333'
)
insert into public.events (
  id, workspace_id, name, description, status, published_at, start_at, end_at,
  timezone_name, operational_days, opens_at_local, closes_at_local,
  location_name, location_address, location_country_code, latitude, longitude,
  capacity_grams, banner_object_path, receiver_name, receiver_phone, receiver_address
)
select 'c0000000-0000-4000-8000-000000000020', id, 'Idempotency race',
  'Idempotency race event', 'ongoing', now(), now() - interval '1 hour',
  now() + interval '4 hours', 'Asia/Jakarta', array[1,2,3,4,5]::smallint[],
  '08:00'::time, '17:00'::time, 'Jakarta', 'Jl. Test Jakarta', 'ID',
  -6.2, 106.8, 1000, id::text || '/idempotency/banner.png',
  'Penerima Test', '+6281234567890', 'Jl. Gudang Test'
from workspace;

insert into public.event_criteria (event_id, criterion)
values ('c0000000-0000-4000-8000-000000000020', 'cotton');

insert into public.bookings (
  id, public_booking_id, event_id, workspace_id,
  donor_name_ciphertext, donor_name_nonce, donor_phone_ciphertext, donor_phone_nonce,
  phone_lookup_hash, estimated_weight_grams, item_count, shipping_method,
  scan_model_version, event_snapshot, qr_token_hash, qr_token_ciphertext, qr_token_nonce,
  terms_version, privacy_version, consented_at, expires_at
)
select 'c2000000-0000-4000-8000-000000000020', 'KPL-56789-ABCDE',
  'c0000000-0000-4000-8000-000000000020', id,
  'name-cipher', 'name-nonce', 'phone-cipher', 'phone-nonce', repeat('5', 64),
  400, 1, 'direct', 'test-model-v1', '{"schema_version":1}'::jsonb,
  repeat('6', 64), 'qr-cipher', 'qr-nonce', 'local-v1', 'local-v1',
  now(), now() + interval '3 hours'
from public.workspaces
where owner_user_id = '33333333-3333-4333-8333-333333333333';
SQL

accept_booking \
  'c2000000-0000-4000-8000-000000000020' 'same-reception-key' \
  'c3000000-0000-4000-8000-000000000020' \
  "$KUMPUL_CONCURRENCY_TMP/replay-1.log" &
replay_1_pid=$!
accept_booking \
  'c2000000-0000-4000-8000-000000000020' 'same-reception-key' \
  'c3000000-0000-4000-8000-000000000020' \
  "$KUMPUL_CONCURRENCY_TMP/replay-2.log" &
replay_2_pid=$!
wait "$replay_1_pid"
wait "$replay_2_pid"

psql_exec -At <<'SQL' >"$KUMPUL_CONCURRENCY_TMP/replay-result.txt"
select received_weight_grams || ':' ||
  (select count(*) from public.receptions where event_id = e.id)
from public.events as e
where e.id = 'c0000000-0000-4000-8000-000000000020';
SQL
if [[ "$(tr -d '[:space:]' <"$KUMPUL_CONCURRENCY_TMP/replay-result.txt")" != "700:1" ]]; then
  echo "Concurrent idempotent reception duplicated weight or reception" >&2
  cat "$KUMPUL_CONCURRENCY_TMP/replay-result.txt" >&2
  exit 1
fi

psql_exec <<'SQL'
delete from public.idempotency_keys
where actor_scope = '33333333-3333-4333-8333-333333333333';
delete from public.workspaces
where owner_user_id = '33333333-3333-4333-8333-333333333333';
delete from auth.users where id = '33333333-3333-4333-8333-333333333333';
SQL

echo "Concurrency tests passed: draft retry, publish limit, capacity invariant, and idempotent reception"
