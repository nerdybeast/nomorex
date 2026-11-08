#!/usr/bin/env bash
#
# Proves a change the way CI does, in the same order: analyze, widget tests,
# migrations (reset + lint + pgTAP tests), E2E, web build. Built for Claude Code on the web,
# where the SessionStart hook has already installed the toolchain, but it runs
# anywhere those tools exist.
#
# Usage:
#   ./scripts/verify.sh                 # everything
#   ./scripts/verify.sh --no-e2e        # skip the (slow) E2E suite
#   ./scripts/verify.sh --no-db         # skip supabase reset + lint
#   ./scripts/verify.sh --no-web        # skip the web build
#
# WARNING: the db stage runs `supabase db reset`, which drops and recreates the
# LOCAL database. It never passes --linked; never point it at production.

set -uo pipefail

cd "$(dirname "$0")/.."

RUN_DB=true
RUN_E2E=true
RUN_WEB=true
for arg in "$@"; do
  case "$arg" in
    --no-db) RUN_DB=false ;;
    --no-e2e) RUN_E2E=false ;;
    --no-web) RUN_WEB=false ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

ENV_FILE=".env.local.json"
results=()
failed=false

# stage <name> <command...> — runs it, records pass/fail, keeps going so one
# failure doesn't hide the rest.
stage() {
  local name="$1"; shift
  echo ""
  echo "=== $name"
  if "$@"; then
    results+=("PASS  $name")
  else
    results+=("FAIL  $name")
    failed=true
  fi
}

skip() { results+=("SKIP  $1 ($2)"); }

need_docker() { docker info >/dev/null 2>&1; }

stage "flutter analyze" flutter analyze
stage "flutter test" flutter test

if [[ "$RUN_DB" == true ]]; then
  if need_docker; then
    stage "supabase db reset (local)" supabase db reset
    stage "supabase db lint" supabase db lint
    # pgTAP tests under supabase/tests/. --local is the default; spelled out
    # because --linked would run them against production.
    stage "supabase test db (local)" supabase test db --local
  else
    skip "migrations" "Docker unavailable — NOT proven"
  fi
else
  skip "migrations" "--no-db"
fi

if [[ "$RUN_E2E" == true ]]; then
  if need_docker; then
    # Linux desktop needs a display; xvfb provides it (as in CI).
    stage "E2E (integration_test)" xvfb-run -a ./scripts/e2e.sh linux
  else
    skip "E2E" "Docker unavailable — NOT proven"
  fi
else
  skip "E2E" "--no-e2e"
fi

# Genkit edge function: fmt, lint, type-check, unit tests (deno task check).
# Same Deno version as CI and the edge runtime. Falls back to the pinned Docker
# image when Deno isn't installed.
DENO_VERSION="2.1.4"
deno_check_docker() {
  docker run --rm -v "$PWD/supabase/functions/ai:/app" -w /app \
    "denoland/deno:$DENO_VERSION" deno task check
}
if command -v deno >/dev/null 2>&1; then
  stage "edge functions (deno task check)" bash -c 'cd supabase/functions/ai && deno task check'
elif need_docker; then
  stage "edge functions (deno task check, docker)" deno_check_docker
else
  skip "edge functions" "neither Deno nor Docker available — NOT proven"
fi

if [[ "$RUN_WEB" == true ]]; then
  if [[ -f "$ENV_FILE" ]]; then
    stage "flutter build web --debug" flutter build web --debug --dart-define-from-file="$ENV_FILE"
  else
    # Same placeholder values CI uses: this only proves the target compiles.
    stage "flutter build web --debug" flutter build web --debug \
      --dart-define=SUPABASE_URL=https://placeholder.supabase.co \
      --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_placeholder
  fi
else
  skip "web build" "--no-web"
fi

echo ""
echo "=== Summary"
printf '  %s\n' "${results[@]}"

if [[ "$failed" == true ]]; then
  exit 1
fi
