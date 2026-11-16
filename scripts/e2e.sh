#!/usr/bin/env bash
#
# Runs the integration_test E2E suite against the local Supabase stack.
#
# Usage:
#   ./scripts/e2e.sh            # macOS desktop (default)
#   ./scripts/e2e.sh linux      # Linux desktop, as CI runs it
#   E2E_FILE_TIMEOUT=900 ./scripts/e2e.sh   # per-file limit in seconds (default 600)
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
#
# The same "Failed to foreground app" also shows up when macOS can't bring a
# window forward at all (screen locked, display asleep). Then every test fails
# within seconds or the run hangs, which has nothing to do with the code under
# test. So each file gets a time limit, and that message gets a hint.
FILE_TIMEOUT="${E2E_FILE_TIMEOUT:-600}"
FOREGROUND_ERROR="Failed to foreground app"
log_dir="$(mktemp -d)"
trap 'rm -rf "$log_dir"' EXIT

# Runs one test file with output shown and saved to $2. Stops it after
# $FILE_TIMEOUT seconds. Returns flutter's status, or 124 on a timeout.
run_with_timeout() {
  local test_file="$1" log="$2"
  flutter test "$test_file" -d "$DEVICE" "${DART_DEFINES[@]}" > >(tee "$log") 2>&1 &
  local pid=$!
  (
    sleep "$FILE_TIMEOUT"
    echo "" >> "$log"
    echo "==> TIMEOUT after ${FILE_TIMEOUT}s" | tee -a "$log"
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
  ) &
  local watchdog=$!
  local status=0
  wait "$pid" || status=$?
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  if grep -q "==> TIMEOUT" "$log"; then
    return 124
  fi
  return "$status"
}

failed=()
foreground_failures=0
for test_file in integration_test/*_test.dart; do
  echo ""
  echo "--- $test_file"
  log="$log_dir/$(basename "$test_file").log"
  if ! run_with_timeout "$test_file" "$log"; then
    failed+=("$test_file")
    if grep -q "$FOREGROUND_ERROR" "$log"; then
      foreground_failures=$((foreground_failures + 1))
    fi
  fi
done

echo ""
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "==> FAILED: ${failed[*]}"
  if [[ $foreground_failures -gt 0 ]]; then
    echo ""
    echo "==> WARNING: $foreground_failures failing file(s) logged \"$FOREGROUND_ERROR\"."
    echo "    The desktop couldn't bring the test app forward, so these failures may"
    echo "    say nothing about the code. Unlock the screen, keep the display awake,"
    echo "    close any leftover nomorex window, and run again."
    echo "    (Set E2E_FILE_TIMEOUT to change the ${FILE_TIMEOUT}s per-file limit.)"
  fi
  exit 1
fi
echo "==> All integration tests passed"
