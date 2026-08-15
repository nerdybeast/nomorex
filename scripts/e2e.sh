#!/usr/bin/env bash
#
# Runs the integration_test E2E suite against the local Supabase stack.
#
# Usage:
#   ./scripts/e2e.sh            # macOS desktop (default)
#   ./scripts/e2e.sh linux      # Linux desktop, as CI runs it
#
# The app cannot reach Supabase without the compile-time dart-defines (see
# docs/build.md), so always launch the suite through this script rather than
# calling `flutter test integration_test` directly.
#
# WARNING: this runs `supabase db reset`, which drops and recreates the LOCAL
# database. It never passes --linked; never point it at the production project.

set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE="${1:-macos}"
ENV_FILE=".env.local.json"

echo "==> Starting local Supabase stack"
supabase start

echo "==> Resetting local database (replays migrations + seed.sql)"
supabase db reset

# Locally, use the same .env.local.json the app is normally run with. In CI
# that file doesn't exist (it's gitignored and created per machine), so read
# the connection details straight off the running stack instead.
if [[ -f "$ENV_FILE" ]]; then
  echo "==> Using $ENV_FILE"
  DART_DEFINES=(--dart-define-from-file="$ENV_FILE")
else
  echo "==> No $ENV_FILE; reading config from the running stack"
  sb_status="$(supabase status -o env)"
  api_url="$(sed -n 's/^API_URL="\(.*\)"$/\1/p' <<<"$sb_status")"
  pub_key="$(sed -n 's/^PUBLISHABLE_KEY="\(.*\)"$/\1/p' <<<"$sb_status")"
  if [[ -z "$api_url" || -z "$pub_key" ]]; then
    echo "error: could not read API_URL / PUBLISHABLE_KEY from supabase status" >&2
    exit 1
  fi
  DART_DEFINES=(
    --dart-define=SUPABASE_URL="$api_url"
    --dart-define=SUPABASE_PUBLISHABLE_KEY="$pub_key"
  )
fi

echo "==> Running integration tests on $DEVICE"

# One `flutter test` invocation per file, rather than pointing it at the whole
# directory. On desktop the suite launches a real app window per file, and the
# second launch inside a single invocation fails with "Failed to foreground
# app; open returned 1" / "Unable to start the app on the device" because the
# previous instance hasn't fully released. Separate invocations avoid that.
failed=()
for test_file in integration_test/*_test.dart; do
  echo ""
  echo "--- $test_file"
  if ! flutter test "$test_file" -d "$DEVICE" "${DART_DEFINES[@]}"; then
    failed+=("$test_file")
  fi
done

echo ""
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "==> FAILED: ${failed[*]}"
  exit 1
fi
echo "==> All integration tests passed"
