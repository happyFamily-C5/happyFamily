#!/usr/bin/env bash
# Static cutover gate: fails when legacy guest endpoints, legacy RPC
# identifiers, deleted guest-layer Swift types, or QR/PII console logging
# appear in application code.
#
# Scope: App/, Core/, Features/, Tests/ Swift sources only. supabase/ is
# intentionally excluded — the legacy edge functions stay deployed for data
# retention until decommission and the TS test suites reference them by
# name; only *callers* in the app are forbidden.
#
# Run: bash Scripts/check_legacy_gate.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Whole-word Swift identifiers: legacy types must not reappear in any form.
word_patterns=(
  'PublicBackendServing'
  'PublicBackendClient'
  'FullAppBackendDependencies'
  'FullAppInvocationModel'
  'InvocationParser'
  'EventInvocation'
  'ResolveEventData'
  'CreateBookingRequest'
  'CreateBookingData'
  'DonorVerificationData'
  'DonorBookingStatusData'
  'PublicLegalDTO'
  'invalidInvocationURL'
  'invocation_token'
)

# Regex patterns: hyphenated guest endpoint paths and legacy RPC names are
# substrings of legitimate identifiers elsewhere (e.g. account's
# create_booking), so they are matched as raw regexes, not words.
regex_patterns=(
  'resolve-event'
  'verify-donor-booking'
  'donor-booking-status'
  'resolve_event_v1'
  'create_booking_v1'
  'verify_donor_booking_v1'
  'donor_booking_status_v1'
  # QR/PII console logging is forbidden by the booking contract.
  'print\("[^"]*[Qq][Rr]'
  'print\(.*[Tt]oken'
)

violations=0
report() {
  local pattern="$1"
  local hits
  hits="$(grep -RInE --include='*.swift' -e "$pattern" App Core Features Tests 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then
    while IFS= read -r line; do
      echo "LEGACY GATE [$pattern]: $line" >&2
    done <<<"$hits"
    violations=$((violations + 1))
  fi
}

for pattern in "${word_patterns[@]}"; do
  report "\\b${pattern}\\b"
done

for pattern in "${regex_patterns[@]}"; do
  report "$pattern"
done

# The account flow posts action "create_booking" (underscore) on /account;
# the legacy guest POST /functions/v1/create-booking (hyphen) is gone. Catch
# the hyphenated path only, word-boundary style, without flagging underscores.
if grep -RInE --include='*.swift' -e 'create-booking' App Core Features Tests 2>/dev/null; then
  echo "LEGACY GATE [create-booking]: legacy guest endpoint path found" >&2
  violations=$((violations + 1))
fi

if [[ "$violations" -gt 0 ]]; then
  echo "Legacy cutover gate failed with $violations pattern(s) matched." >&2
  exit 1
fi

echo "Legacy cutover gate passed: no guest callers, legacy RPCs, or QR logging in app code."
