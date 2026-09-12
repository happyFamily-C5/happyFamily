#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

for command in curl jq uuidgen; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

eval "$(supabase status -o env 2>/dev/null)"
PUBLISHABLE_KEY="${PUBLISHABLE_KEY:-$ANON_KEY}"
SMOKE_TMP="$(mktemp -d)"
USER_ID=""
OBJECT_PATH=""

cleanup() {
  if [[ -n "$OBJECT_PATH" ]]; then
    curl -sS -X DELETE \
      -H "apikey: $SERVICE_ROLE_KEY" \
      -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
      "$API_URL/storage/v1/object/event-banners/$OBJECT_PATH" >/dev/null || true
  fi
  if [[ -n "$USER_ID" ]]; then
    curl -sS -X DELETE \
      -H "apikey: $SERVICE_ROLE_KEY" \
      -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
      "$API_URL/auth/v1/admin/users/$USER_ID" >/dev/null || true
  fi
  rm -rf -- "$SMOKE_TMP"
}
trap cleanup EXIT

assert_status() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "$label: expected HTTP $expected, received $actual" >&2
    exit 1
  fi
}

assert_json() {
  local file="$1"
  local label="$2"
  shift 2
  if ! jq -e "$@" "$file" >/dev/null; then
    echo "$label: JSON assertion failed" >&2
    jq '{data, error, request_id, server_time}' "$file" >&2
    exit 1
  fi
}

iso_time() {
  local direction="$1"
  local hours="$2"
  if date -u -d '@0' '+%Y' >/dev/null 2>&1; then
    if [[ "$direction" == "ago" ]]; then
      date -u -d "$hours hours ago" '+%Y-%m-%dT%H:%M:%SZ'
    else
      date -u -d "+$hours hours" '+%Y-%m-%dT%H:%M:%SZ'
    fi
  else
    if [[ "$direction" == "ago" ]]; then
      date -u -v-"${hours}"H '+%Y-%m-%dT%H:%M:%SZ'
    else
      date -u -v+"${hours}"H '+%Y-%m-%dT%H:%M:%SZ'
    fi
  fi
}

SUFFIX="$(uuidgen | tr '[:upper:]' '[:lower:]')"
EMAIL="backend-smoke-$SUFFIX@example.invalid"
PASSWORD='BackendSmoke-2026-test'

CREATE_STATUS="$(curl -sS -o "$SMOKE_TMP/user.json" -w '%{http_code}' \
  "$API_URL/auth/v1/admin/users" \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H 'content-type: application/json' \
  --data "$(jq -nc --arg email "$EMAIL" --arg password "$PASSWORD" \
    '{email:$email,password:$password,email_confirm:true}')")"
assert_status "$CREATE_STATUS" 200 "create organizer"
USER_ID="$(jq -r '.id' "$SMOKE_TMP/user.json")"

LOGIN_STATUS="$(curl -sS -o "$SMOKE_TMP/session.json" -w '%{http_code}' \
  "$API_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H 'content-type: application/json' \
  --data "$(jq -nc --arg email "$EMAIL" --arg password "$PASSWORD" \
    '{email:$email,password:$password}')")"
assert_status "$LOGIN_STATUS" 200 "organizer login"
ACCESS_TOKEN="$(jq -r '.access_token' "$SMOKE_TMP/session.json")"

# Workspaces are provisioned during onboarding (admin role), not at signup.
ONBOARD_STATUS="$(curl -sS -o "$SMOKE_TMP/onboard.json" -w '%{http_code}' \
  "$REST_URL/rpc/complete_onboarding_v1" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'content-type: application/json' \
  -H 'content-profile: api' \
  -H 'accept-profile: api' \
  --data '{"p_role":"admin"}')"
assert_status "$ONBOARD_STATUS" 200 "organizer onboarding"
assert_json "$SMOKE_TMP/onboard.json" \
  "onboarding response" \
  '.error == null and .role == "admin"'

SERVICE_ROLE_BYPASS_STATUS="$(curl -sS -o "$SMOKE_TMP/service-role-bypass.json" \
  -w '%{http_code}' "$FUNCTIONS_URL/publish-event" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H 'content-type: application/json' \
  --data '{"event_id":"00000000-0000-4000-8000-000000000000"}')"
assert_status "$SERVICE_ROLE_BYPASS_STATUS" 401 "service-role organizer bypass"
assert_json "$SMOKE_TMP/service-role-bypass.json" \
  "service-role boundary denial" \
  '.error.code == "AUTH_INVALID"'

BANNER_FILE="$REPO_ROOT/Resources/Assets.xcassets/DummyImageBanner.imageset/1000_F_2012355683_JGiPfiDcCiBc10o0hubHvVA2eYzj42Mv.jpg"
UPLOAD_STATUS="$(curl -sS -o "$SMOKE_TMP/upload.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/upload-event-banner" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "file=@$BANNER_FILE;type=image/jpeg")"
assert_status "$UPLOAD_STATUS" 201 "validated banner upload"
assert_json "$SMOKE_TMP/upload.json" \
  "banner response" \
  '.error == null and .data.width == 1000 and .data.height == 667'
OBJECT_PATH="$(jq -r '.data.object_path' "$SMOKE_TMP/upload.json")"
WORKSPACE_ID="${OBJECT_PATH%%/*}"
[[ "$OBJECT_PATH" == "$WORKSPACE_ID/"* ]] || {
  echo "banner path is not workspace scoped" >&2
  exit 1
}

PUBLIC_READ_STATUS="$(curl -sS -o /dev/null -w '%{http_code}' \
  "$API_URL/storage/v1/object/public/event-banners/$OBJECT_PATH")"
assert_status "$PUBLIC_READ_STATUS" 200 "public banner read"

DIRECT_WRITE_STATUS="$(curl -sS -o "$SMOKE_TMP/direct-write.json" -w '%{http_code}' \
  -X POST "$API_URL/storage/v1/object/event-banners/$WORKSPACE_ID/bypass/banner.jpg" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'content-type: image/jpeg' \
  --data-binary "@$BANNER_FILE")"
assert_status "$DIRECT_WRITE_STATUS" 400 "direct Storage write denial"
assert_json "$SMOKE_TMP/direct-write.json" "Storage RLS denial" '.code == "AccessDenied"'

START_AT="$(iso_time ago 1)"
END_AT="$(iso_time from-now 6)"
MUTATION_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
DRAFT_BODY="$(jq -nc \
  --arg mutation "$MUTATION_ID" \
  --arg start "$START_AT" \
  --arg end "$END_AT" \
  --arg banner "$OBJECT_PATH" \
  '{
    p_event_id:null,
    p_mutation_id:$mutation,
    p_payload:{
      name:"HTTP Smoke Event",
      description:"Local full-boundary smoke test",
      start_at:$start,
      end_at:$end,
      timezone_name:"Asia/Jakarta",
      operational_days:[1,2,3,4,5,6,7],
      opens_at_local:"00:00:00",
      closes_at_local:"23:59:59",
      location_name:"Jakarta",
      location_address:"Jl. Smoke Test, Jakarta",
      location_country_code:"ID",
      latitude:-6.2,
      longitude:106.8,
      capacity_grams:100000,
      banner_object_path:$banner,
      receiver_name:"Penerima Smoke",
      receiver_phone:"+6281234567890",
      receiver_address:"Jl. Penerima Smoke",
      criteria:["cotton"]
    }
  }')"
DRAFT_STATUS="$(curl -sS -o "$SMOKE_TMP/draft.json" -w '%{http_code}' \
  "$REST_URL/rpc/upsert_event_draft_v1" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'content-type: application/json' \
  -H 'content-profile: api' \
  -H 'accept-profile: api' \
  --data "$DRAFT_BODY")"
assert_status "$DRAFT_STATUS" 200 "create event draft"
EVENT_ID="$(jq -r '.id' "$SMOKE_TMP/draft.json")"

PUBLISH_STATUS="$(curl -sS -o "$SMOKE_TMP/publish.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/publish-event" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'content-type: application/json' \
  --data "$(jq -nc --arg event "$EVENT_ID" '{event_id:$event}')")"
assert_status "$PUBLISH_STATUS" 200 "publish event"
assert_json "$SMOKE_TMP/publish.json" "publish envelope" '.error == null'
INVOCATION_URL="$(jq -r '.data.invocation_url' "$SMOKE_TMP/publish.json")"
INVOCATION_TOKEN="${INVOCATION_URL##*event=}"

GUESSED_TOKEN="$(uuidgen | tr -d '-')$(uuidgen | tr -d '-')"
GUESS_STATUS="$(curl -sS -o "$SMOKE_TMP/invocation-guess.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/resolve-event?token=$GUESSED_TOKEN" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "x-client-instance-id: invocation-guess-$SUFFIX")"
assert_status "$GUESS_STATUS" 404 "invocation token guessing"
assert_json "$SMOKE_TMP/invocation-guess.json" \
  "generic invocation guessing response" \
  '.error.code == "INVOCATION_INVALID"'

RESOLVE_STATUS="$(curl -sS -o "$SMOKE_TMP/resolve.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/resolve-event?token=$INVOCATION_TOKEN" \
  -H "apikey: $PUBLISHABLE_KEY")"
assert_status "$RESOLVE_STATUS" 200 "resolve event"
assert_json "$SMOKE_TMP/resolve.json" \
  "resolved event contract" \
  --arg event "$EVENT_ID" \
  '.data.event.id == $event and .data.legal.terms_version == "local-v1"'

BOOKING_KEY="booking-smoke-$SUFFIX"
BOOKING_BODY="$(jq -nc --arg token "$INVOCATION_TOKEN" '{
  invocation_token:$token,
  donor_name:"=2+2",
  phone:"081234567890",
  estimated_weight_grams:1200,
  item_count:1,
  items:[{
    ordinal:0,
    passed:true,
    scanner_model_version:"smoke-model-v1",
    metadata:{garment_type:"shirt",accessory_count:"0",sensitivity:"medium"}
  }],
  shipping_method:"direct",
  scan_model_version:"smoke-model-v1",
  terms_version:"local-v1",
  privacy_version:"local-v1"
}')"

MALFORMED_STATUS="$(curl -sS -o "$SMOKE_TMP/malformed.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/create-booking" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "idempotency-key: malformed-$SUFFIX" \
  -H 'content-type: application/json' \
  --data '{')"
assert_status "$MALFORMED_STATUS" 400 "malformed JSON"
assert_json "$SMOKE_TMP/malformed.json" "malformed JSON code" \
  '.error.code == "MALFORMED_JSON"'

PHOTO_STATUS="$(curl -sS -o "$SMOKE_TMP/photo.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/create-booking" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "idempotency-key: photo-$SUFFIX" \
  -H 'content-type: application/json' \
  --data "$(jq -c '. + {photo_base64:"forbidden"}' <<<"$BOOKING_BODY")")"
assert_status "$PHOTO_STATUS" 422 "photo payload rejection"
assert_json "$SMOKE_TMP/photo.json" "photo payload error" \
  '.error.code == "PHOTO_DATA_FORBIDDEN"'

jq -nc --arg value "$(head -c 33000 /dev/zero | tr '\0' x)" \
  '{oversized:$value}' >"$SMOKE_TMP/oversized.json"
OVERSIZED_STATUS=""
for _attempt in 1 2 3; do
  OVERSIZED_STATUS="$(curl -sS -o "$SMOKE_TMP/oversized-response.json" -w '%{http_code}' \
    "$FUNCTIONS_URL/create-booking" \
    -H "apikey: $PUBLISHABLE_KEY" \
    -H "idempotency-key: oversized-$SUFFIX" \
    -H 'content-type: application/json' \
    --data-binary "@$SMOKE_TMP/oversized.json")"
  # Cold edge isolates on slow CI runners can trip the gateway timeout;
  # retry on transient 5xx before evaluating the boundary assertion.
  [[ "$OVERSIZED_STATUS" =~ ^5 ]] || break
  sleep 2
done
assert_status "$OVERSIZED_STATUS" 413 "oversized booking payload"
assert_json "$SMOKE_TMP/oversized-response.json" "oversized payload error" \
  '.error.code == "PAYLOAD_TOO_LARGE"'

BOOKING_STATUS="$(curl -sS -o "$SMOKE_TMP/booking.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/create-booking" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "idempotency-key: $BOOKING_KEY" \
  -H 'content-type: application/json' \
  --data "$BOOKING_BODY")"
assert_status "$BOOKING_STATUS" 201 "create booking"
assert_json "$SMOKE_TMP/booking.json" \
  "booking envelope" \
  '.error == null and .data.idempotent_replay == false'
PUBLIC_BOOKING_ID="$(jq -r '.data.booking_id' "$SMOKE_TMP/booking.json")"
QR_TOKEN="$(jq -r '.data.qr_token' "$SMOKE_TMP/booking.json")"

REPLAY_STATUS="$(curl -sS -o "$SMOKE_TMP/booking-replay.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/create-booking" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "idempotency-key: $BOOKING_KEY" \
  -H 'content-type: application/json' \
  --data "$BOOKING_BODY")"
assert_status "$REPLAY_STATUS" 200 "idempotent booking replay"
assert_json "$SMOKE_TMP/booking-replay.json" \
  "booking replay" \
  --arg booking "$PUBLIC_BOOKING_ID" \
  '.data.booking_id == $booking and .data.idempotent_replay == true'

WRONG_PHONE_STATUS="$(curl -sS -o "$SMOKE_TMP/wrong-phone.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/verify-donor-booking" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "x-client-instance-id: wrong-phone-$SUFFIX" \
  -H 'content-type: application/json' \
  --data "$(jq -nc --arg booking "$PUBLIC_BOOKING_ID" \
    '{booking_id:$booking,phone:"081299999999"}')")"
assert_status "$WRONG_PHONE_STATUS" 401 "wrong donor phone"
assert_json "$SMOKE_TMP/wrong-phone.json" "generic wrong-phone response" \
  '.error.code == "BOOKING_CREDENTIALS_INVALID"'

for attempt in 1 2 3 4 5 6; do
  RATE_STATUS="$(curl -sS -o "$SMOKE_TMP/rate-limit.json" -w '%{http_code}' \
    "$FUNCTIONS_URL/verify-donor-booking" \
    -H "apikey: $PUBLISHABLE_KEY" \
    -H "x-client-instance-id: lookup-rate-$SUFFIX" \
    -H 'content-type: application/json' \
    --data "$(jq -nc --arg booking "$PUBLIC_BOOKING_ID" \
      '{booking_id:$booking,phone:"081288888888"}')")"
  if [[ "$attempt" -lt 6 ]]; then
    assert_status "$RATE_STATUS" 401 "donor lookup attempt $attempt"
  else
    assert_status "$RATE_STATUS" 429 "donor lookup rate limit"
    assert_json "$SMOKE_TMP/rate-limit.json" "donor rate-limit response" \
      '.error.code == "RATE_LIMITED" and .error.retryable == true'
  fi
done

VERIFY_STATUS="$(curl -sS -o "$SMOKE_TMP/verify.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/verify-donor-booking" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H 'content-type: application/json' \
  --data "$(jq -nc --arg booking "$PUBLIC_BOOKING_ID" \
    '{booking_id:$booking,phone:"081234567890"}')")"
assert_status "$VERIFY_STATUS" 200 "verify donor booking"
DONOR_TOKEN="$(jq -r '.data.access_token' "$SMOKE_TMP/verify.json")"

STATUS_STATUS="$(curl -sS -o "$SMOKE_TMP/donor-status.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/donor-booking-status" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $DONOR_TOKEN")"
assert_status "$STATUS_STATUS" 200 "donor booking status"
assert_json "$SMOKE_TMP/donor-status.json" \
  "donor status scope" \
  --arg booking "$PUBLIC_BOOKING_ID" \
  '.data.public_booking_id == $booking'

QR_STATUS="$(curl -sS -o "$SMOKE_TMP/qr.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/resolve-qr" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'content-type: application/json' \
  --data "$(jq -nc --arg token "$QR_TOKEN" '{qr_token:$token}')")"
assert_status "$QR_STATUS" 200 "resolve organizer QR"
assert_json "$SMOKE_TMP/qr.json" \
  "authorized QR PII" \
  --arg booking "$PUBLIC_BOOKING_ID" \
  '.data.public_booking_id == $booking and .data.donor_name == "=2+2"'
BOOKING_UUID="$(jq -r '.data.booking_id' "$SMOKE_TMP/qr.json")"

DECISION_STATUS="$(curl -sS -o "$SMOKE_TMP/decision.json" -w '%{http_code}' \
  "$REST_URL/rpc/decide_reception_v1" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'content-type: application/json' \
  -H 'content-profile: api' \
  -H 'accept-profile: api' \
  --data "$(jq -nc --arg booking "$BOOKING_UUID" --arg request "$(uuidgen)" '{
    p_booking_id:$booking,
    p_decision:"accepted",
    p_actual_weight_grams:1100,
    p_condition:"good",
    p_rejection_reason:null,
    p_rejection_note:null,
    p_idempotency_key:"reception-smoke-key",
    p_request_id:$request
  }')")"
assert_status "$DECISION_STATUS" 200 "accept reception"
assert_json "$SMOKE_TMP/decision.json" "reception result" '.status == "accepted"'

USED_QR_STATUS="$(curl -sS -o "$SMOKE_TMP/used-qr.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/resolve-qr" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'content-type: application/json' \
  --data "$(jq -nc --arg token "$QR_TOKEN" '{qr_token:$token}')")"
assert_status "$USED_QR_STATUS" 409 "used QR rejection"
assert_json "$SMOKE_TMP/used-qr.json" "used QR error" \
  '.error.code == "BOOKING_NOT_PROCESSABLE"'

RECAP_STATUS="$(curl -sS -o "$SMOKE_TMP/recap.json" -w '%{http_code}' \
  "$REST_URL/rpc/recap_v1" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'content-type: application/json' \
  -H 'content-profile: api' \
  -H 'accept-profile: api' \
  --data "$(jq -nc --arg event "$EVENT_ID" '{p_event_id:$event}')")"
assert_status "$RECAP_STATUS" 200 "event recap"
assert_json "$SMOKE_TMP/recap.json" \
  "actual-weight recap" \
  '.total_accepted_weight_grams == 1100 and .accepted_booking_count == 1'

EXPORT_STATUS="$(curl -sS -o "$SMOKE_TMP/report.csv" -w '%{http_code}' \
  "$FUNCTIONS_URL/export-report" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'content-type: application/json' \
  --data "$(jq -nc --arg event "$EVENT_ID" \
    '{event_id:$event,created_from:null,created_to:null}')")"
assert_status "$EXPORT_STATUS" 200 "CSV export"
grep -Fq "$PUBLIC_BOOKING_ID" "$SMOKE_TMP/report.csv"
grep -Fq "'=2+2" "$SMOKE_TMP/report.csv"

DELETE_STATUS="$(curl -sS -o "$SMOKE_TMP/delete.json" -w '%{http_code}' \
  -X DELETE "$FUNCTIONS_URL/delete-donor-data" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'content-type: application/json' \
  --data "$(jq -nc --arg booking "$BOOKING_UUID" '{booking_id:$booking}')")"
assert_status "$DELETE_STATUS" 200 "manual donor deletion"
assert_json "$SMOKE_TMP/delete.json" "donor deletion response" '.data.deleted == true'

LOOKUP_AFTER_DELETE="$(curl -sS -o "$SMOKE_TMP/verify-after-delete.json" -w '%{http_code}' \
  "$FUNCTIONS_URL/verify-donor-booking" \
  -H "apikey: $PUBLISHABLE_KEY" \
  -H 'content-type: application/json' \
  --data "$(jq -nc --arg booking "$PUBLIC_BOOKING_ID" \
    '{booking_id:$booking,phone:"081234567890"}')")"
assert_status "$LOOKUP_AFTER_DELETE" 401 "donor lookup after PII deletion"
assert_json "$SMOKE_TMP/verify-after-delete.json" \
  "generic deleted-PII lookup failure" \
  '.error.code == "BOOKING_CREDENTIALS_INVALID"'

echo "HTTP smoke passed: auth, banner, event, booking, donor, QR, reception, recap, CSV, deletion"
