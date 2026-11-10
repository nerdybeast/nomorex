#!/bin/bash
#
# SessionStart hook for Claude Code on the web.
#
# Goal: a cloud session (e.g. started from a phone) can prove a change the same
# way CI does — analyze, widget tests, migration reset + lint, E2E, web build —
# so ./scripts/verify.sh works the moment the session opens.
#
# This hook is the light, per-session half. The heavy half (Flutter, apt
# packages, Supabase CLI + images, Chromium) lives in scripts/cloud-setup.sh,
# which the environment's setup script runs once and Anthropic snapshots. If
# that snapshot isn't there (no setup script configured, or it was rebuilt
# without one) this hook runs cloud-setup.sh itself, so it works either way —
# just slower. Processes don't survive the snapshot, so starting Docker and the
# Supabase stack stays here.
#
# Only the Flutter toolchain is fatal. Docker/Supabase failures are reported
# loudly but don't stop the session, so analyze/test work still starts; the
# summary at the end says exactly what proof is unavailable.

set -euo pipefail

# Local dev machines already have everything.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"
# shellcheck source=../../scripts/lib/cloud.sh
source "$CLAUDE_PROJECT_DIR/scripts/lib/cloud.sh"

if ! read_pins "$CLAUDE_PROJECT_DIR"; then
  echo "session-start: cannot read version pins" >&2
  exit 1
fi

STATUS=()
note() { STATUS+=("$1"); echo "==> $1"; }

# Append a line to the session env file once, however many times we re-run.
persist_env() {
  local line="$1"
  grep -qxF "$line" "$CLAUDE_ENV_FILE" 2>/dev/null || echo "$line" >> "$CLAUDE_ENV_FILE"
}

# --- Provisioning (normally already done by the cached setup script) ---------

if toolchain_present; then
  note "Toolchain found (cached setup)"
else
  echo "==> Toolchain missing; running scripts/cloud-setup.sh (slow path)"
  $SUDO bash "$CLAUDE_PROJECT_DIR/scripts/cloud-setup.sh" || true
fi

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "session-start: Flutter is not installed; see output above" >&2
  exit 1
fi

# Deno came after the first cached setups, which don't rerun on their own, so
# fill it in here when it's missing. One binary; not fatal.
if deno_present; then
  :
elif run_step "Deno install" install_deno; then
  note "Deno $DENO_VERSION installed"
else
  note "WARNING: Deno install failed — verify.sh falls back to Docker for the edge function checks"
fi
export PATH="$PATH:$FLUTTER_DIR/bin"
persist_env "export PATH=\"\$PATH:$FLUTTER_DIR/bin\""

# pubspec.lock can move between sessions, so this stays per-session. With a
# warm pub cache it's quick.
flutter pub get   # *.g.dart are committed, so no build_runner here
note "Flutter $FLUTTER_VERSION ready; dependencies fetched"

# Whatever provisioning recorded, surfaced so a failed stage isn't silent.
SETUP_STATUS="/var/lib/nomorex-cloud-setup.status"
if [ -f "$SETUP_STATUS" ]; then
  while IFS= read -r line; do note "$line"; done < "$SETUP_STATUS"
fi

# --- Local Supabase stack (per-session: processes don't survive the cache) ---

# Polls until `supabase status` reports a healthy stack, up to ~2 minutes.
wait_for_stack() {
  local _
  for _ in $(seq 1 60); do
    supabase status >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

# True when the stack's containers already exist (a resumed VM: Docker brings
# them back up by itself, but Postgres spends a few seconds in "starting").
stack_containers_exist() {
  [ -n "$(docker ps -aq --filter 'name=^supabase_db_' 2>/dev/null)" ]
}

STACK_UP=false
if run_step "Docker setup" ensure_docker; then
  if supabase status >/dev/null 2>&1; then
    STACK_UP=true
    note "Local Supabase stack already running"
  # After a resume, `supabase start` on a still-booting database fails with
  # "container is not ready: starting" even though nothing is wrong, so wait
  # for it instead of starting over it.
  elif stack_containers_exist && wait_for_stack; then
    STACK_UP=true
    note "Local Supabase stack running (resumed)"
  elif run_step "supabase start" supabase start; then
    STACK_UP=true
    note "Local Supabase stack running"
  # A failed start can still leave the containers booting; give them the same
  # grace period, then one more start attempt.
  elif wait_for_stack || run_step "supabase start (retry)" supabase start; then
    STACK_UP=true
    note "Local Supabase stack running (after a slow start)"
  elif [ -z "$(docker images -q 'public.ecr.aws/supabase/postgres' 2>/dev/null)" ] \
    && [ -z "$(docker images -q 'supabase/postgres' 2>/dev/null)" ]; then
    note "WARNING: 'supabase start' failed and the Supabase images are not on disk — likely image pulls blocked by the environment's network access level; see docs/build.md. E2E and migration proof NOT possible"
  else
    note "WARNING: 'supabase start' failed with the images already on disk, so this is not a network problem — see the log above. E2E and migration proof NOT possible"
  fi
else
  note "WARNING: Docker daemon unavailable (details above) — E2E and migration proof NOT possible in this session"
fi

# Point the app at the local stack, exactly as a developer's machine does.
# Never overwrite a file that is already there. SENTRY_DSN is left unset on
# purpose: an empty DSN disables Sentry, so cloud runs add no noise to either
# Sentry project.
ENV_LOCAL="$CLAUDE_PROJECT_DIR/.env.local.json"
if [ "$STACK_UP" = true ] && [ ! -f "$ENV_LOCAL" ]; then
  sb_status="$(supabase status -o env)"
  api_url="$(sed -n 's/^API_URL="\(.*\)"$/\1/p' <<<"$sb_status")"
  pub_key="$(sed -n 's/^PUBLISHABLE_KEY="\(.*\)"$/\1/p' <<<"$sb_status")"
  if [ -n "$api_url" ] && [ -n "$pub_key" ]; then
    printf '{\n  "SUPABASE_URL": "%s",\n  "SUPABASE_PUBLISHABLE_KEY": "%s"\n}\n' \
      "$api_url" "$pub_key" > "$ENV_LOCAL"
    note ".env.local.json written for the local stack"
  else
    note "WARNING: could not read API_URL/PUBLISHABLE_KEY from 'supabase status'"
  fi
fi

echo ""
echo "Cloud environment summary:"
printf '  - %s\n' "${STATUS[@]}"
echo "Prove a change with: ./scripts/verify.sh"
