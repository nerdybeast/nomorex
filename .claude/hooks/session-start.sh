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

STACK_UP=false
if run_step "Docker setup" ensure_docker; then
  # Already running after an idle-VM resume? Then there's nothing to start.
  if supabase status >/dev/null 2>&1; then
    STACK_UP=true
    note "Local Supabase stack already running"
  elif run_step "supabase start" supabase start; then
    STACK_UP=true
    note "Local Supabase stack running"
  else
    note "WARNING: 'supabase start' failed (details above) — likely image pulls blocked by the environment's network access level; see docs/build.md. E2E and migration proof NOT possible"
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
