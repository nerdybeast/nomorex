#!/usr/bin/env bash
#
# Runs the integration_test E2E suite against the local Supabase stack.
#
# Usage:
#   ./scripts/e2e.sh                     # macOS desktop, stack as it is
#   ./scripts/e2e.sh linux               # Linux desktop, as CI runs it
#   ./scripts/e2e.sh --reset             # reset the local DB to the seed first
#   ./scripts/e2e.sh --file integration_test/app_test.dart   # just one file
#   E2E_TIMEOUT=1200 ./scripts/e2e.sh    # time limit in seconds (default 900)
#
# The app is built and launched once for the whole suite (every file is listed
# in integration_test/all_tests.dart). The suite signs in as its own seeded user,
# e2e@e2e.com, so it doesn't need a fresh database and doesn't touch a@a.com's
# data. That's why the DB is only reset with --reset: CI and verify.sh pass it,
# so they start from a known state; locally, a reset would wipe your own test data.
#
# The app cannot reach Supabase without the compile-time dart-defines (see
# docs/build.md), so always launch the suite through this script rather than
# calling `flutter test integration_test` directly.
#
# WARNING: --reset runs `supabase db reset`, which drops and recreates the LOCAL
# database. It never passes --linked; never point it at a hosted project.

set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE="macos"
RESET=0
TARGET="integration_test/all_tests.dart"
ENV_FILE=".env.local.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset) RESET=1 ;;
    --file)
      shift
      TARGET="${1:?--file needs a path}"
      ;;
    --file=*) TARGET="${1#--file=}" ;;
    -*)
      echo "error: unknown option $1" >&2
      exit 2
      ;;
    *) DEVICE="$1" ;;
  esac
  shift
done

# Every test file must be in all_tests.dart, or the full run would skip it.
missing=()
for test_file in integration_test/*_test.dart; do
  grep -q "$(basename "$test_file")" integration_test/all_tests.dart || missing+=("$test_file")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "error: not listed in integration_test/all_tests.dart: ${missing[*]}" >&2
  echo "       Import each one there and call its main(), or the full run skips it." >&2
  exit 1
fi

echo "==> Starting local Supabase stack"
supabase start

if [[ "$RESET" == 1 ]]; then
  echo "==> Resetting local database (replays migrations + seed.sql)"
  supabase db reset
fi

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

# Without --reset the stack may predate the e2e user (seed.sql only runs on a
# reset), and every test would fail at sign-in with a confusing auth error.
if [[ "$RESET" == 0 ]]; then
  # Only block when the DB could be read and the user is really absent.
  if has_user="$(docker exec supabase_db_nomorex psql -U postgres -tAc \
    "select count(*) from auth.users where email = 'e2e@e2e.com'" 2>/dev/null)" \
    && [[ "$has_user" == "0" ]]; then
    echo "error: the local database has no e2e@e2e.com user (seed.sql adds it)." >&2
    echo "       Run ./scripts/e2e.sh --reset once. That replaces your local data with the seed." >&2
    exit 1
  fi
fi

echo "==> Running $TARGET on $DEVICE"

# On desktop the suite launches a real app window. When macOS can't bring a
# window forward at all (screen locked, display asleep), the run fails within
# seconds or hangs with "Failed to foreground app", which says nothing about
# the code under test. So the run gets a time limit, and that message a hint.
TIMEOUT="${E2E_TIMEOUT:-900}"
FOREGROUND_ERROR="Failed to foreground app"
log="$(mktemp)"
# The watchdog records a timeout in its own file. Appending a marker to $log
# doesn't work: tee keeps writing at its own offset and overwrites it.
timed_out="$(mktemp)"
rm -f "$timed_out"
trap 'rm -f "$log" "$timed_out"' EXIT

# macOS has a flavor per environment (like iOS and Android); the suite runs as
# local. Linux and web have no flavors. The ${...+...} form keeps an empty array
# from tripping `set -u` in the bash 3.2 macOS ships.
FLAVOR_ARGS=()
if [[ "$DEVICE" == "macos" ]]; then FLAVOR_ARGS=(--flavor local); fi

# The expanded reporter prints every test and any error raised outside one in
# full. In CI, flutter test otherwise picks the GitHub reporter, which folds
# such an error away and leaves only a failed exit code.
flutter test "$TARGET" -d "$DEVICE" --reporter expanded ${FLAVOR_ARGS[@]+"${FLAVOR_ARGS[@]}"} "${DART_DEFINES[@]}" > >(tee "$log") 2>&1 &
pid=$!
(
  sleep "$TIMEOUT"
  touch "$timed_out"
  echo ""
  echo "==> TIMEOUT after ${TIMEOUT}s"
  pkill -TERM -P "$pid" 2>/dev/null || true
  kill -TERM "$pid" 2>/dev/null || true
) &
watchdog=$!
status=0
wait "$pid" || status=$?
kill "$watchdog" 2>/dev/null || true
wait "$watchdog" 2>/dev/null || true
# tee finishes writing after flutter exits; give it a moment before grepping.
sleep 1

if [[ -f "$timed_out" ]]; then
  status=124
fi
# flutter test can exit 0 after being stopped mid-run, so its own summary of a
# failure counts too.
if [[ "$status" -eq 0 ]] && grep -qE "Some tests failed|\(did not complete\)" "$log"; then
  status=1
fi

echo ""
if [[ "$status" -ne 0 ]]; then
  echo "==> FAILED ($TARGET, exit $status)"
  if grep -q "$FOREGROUND_ERROR" "$log"; then
    echo ""
    echo "==> WARNING: the run logged \"$FOREGROUND_ERROR\"."
    echo "    The desktop couldn't bring the test app forward, so this failure may"
    echo "    say nothing about the code. Unlock the screen, keep the display awake,"
    echo "    close any leftover nomorex window, and run again."
    echo "    (Set E2E_TIMEOUT to change the ${TIMEOUT}s limit.)"
  fi
  exit 1
fi
echo "==> All integration tests passed"
