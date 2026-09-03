#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

for command in deno supabase; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

eval "$(supabase status -o env 2>/dev/null)"
export API_URL REST_URL FUNCTIONS_URL ANON_KEY SERVICE_ROLE_KEY
export PUBLISHABLE_KEY="${PUBLISHABLE_KEY:-$ANON_KEY}"

deno run --config supabase/functions/deno.json \
  --allow-env=API_URL,REST_URL,FUNCTIONS_URL,PUBLISHABLE_KEY,ANON_KEY,SERVICE_ROLE_KEY,LOAD_BOOKING_COUNT,LOAD_CONCURRENCY,LOAD_RESOLVE_COUNT,LOAD_QR_COUNT,LOAD_DASHBOARD_COUNT \
  --allow-net \
  supabase/tests/load/run.ts
