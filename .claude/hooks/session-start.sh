#!/bin/bash
#
# SessionStart hook for Claude Code on the web.
#
# Goal: a cloud session (e.g. started from a phone) can prove a change the same
# way CI does — analyze, widget tests, migration reset + lint, E2E, web build —
# so ./scripts/verify.sh works the moment the session opens.
#
# Idempotent: a cached container re-runs this and each stage short-circuits.
# Only the Flutter toolchain is fatal. Docker/Supabase/browser failures are
# reported loudly but don't stop the session, so analyze/test work still
# starts; the summary at the end says exactly what proof is unavailable.

set -euo pipefail

# Local dev machines already have everything.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

# Pins live in CI so there is one place to bump them. Floating versions have
# broken unrelated PRs before (see the comments in pr-checks.yml).
WORKFLOW=".github/workflows/pr-checks.yml"
FLUTTER_VERSION="$(grep -m1 'flutter-version:' "$WORKFLOW" | awk '{print $2}')"
SUPABASE_VERSION="$(grep -m1 -E '^[[:space:]]+version: [0-9]+\.[0-9]+\.[0-9]+$' "$WORKFLOW" | awk '{print $2}')"
PLAYWRIGHT_VERSION="1.55.0"
if [ -z "$FLUTTER_VERSION" ] || [ -z "$SUPABASE_VERSION" ]; then
  echo "session-start: could not read version pins from $WORKFLOW" >&2
  exit 1
fi

FLUTTER_DIR="/opt/flutter"
STATUS=()
note() { STATUS+=("$1"); echo "==> $1"; }

# Run a best-effort step with its output captured. A clean run stays quiet; a
# failure prints the exit code and the tail of the real output (to stdout, which
# is what the session shows) instead of a bare "failed". Returns the step's
# exit code so callers can still choose the warning to record.
LOG_DIR="$(mktemp -d)"
run_step() {
  local label="$1"; shift
  local log="$LOG_DIR/${label//[^A-Za-z0-9]/_}.log" rc=0
  "$@" >"$log" 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "!!! $label failed (exit $rc). Last 40 lines of output:"
    tail -n 40 "$log" | sed 's/^/    /'
    echo "!!! full log: $log"
  fi
  return "$rc"
}

# Append a line to the session env file once, however many times we re-run.
persist_env() {
  local line="$1"
  grep -qxF "$line" "$CLAUDE_ENV_FILE" 2>/dev/null || echo "$line" >> "$CLAUDE_ENV_FILE"
}

# --- Flutter (fatal) ---------------------------------------------------------

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  $SUDO git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  # flutter writes into its own tree (cache/, version stamps).
  $SUDO chown -R "$(id -un)" "$FLUTTER_DIR"
fi
export PATH="$PATH:$FLUTTER_DIR/bin"
persist_env "export PATH=\"\$PATH:$FLUTTER_DIR/bin\""

flutter config --no-analytics --enable-linux-desktop --enable-web
flutter precache --linux --web
flutter pub get   # *.g.dart are committed, so no build_runner here
note "Flutter $FLUTTER_VERSION ready; dependencies fetched"

# --- Everything below is best-effort ------------------------------------------

# Linux desktop build deps + xvfb: the same list the CI `e2e` job installs.
APT_PKGS=(clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
          libstdc++-12-dev libcurl4-openssl-dev xvfb curl ca-certificates)
install_apt_deps() {
  local missing=()
  for p in "${APT_PKGS[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  [ ${#missing[@]} -eq 0 ] && return 0
  $SUDO apt-get update
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
}
if run_step "apt dependencies" install_apt_deps; then
  note "Linux desktop build deps + xvfb installed (E2E can build)"
else
  note "WARNING: apt dependencies failed (details above) — E2E cannot build in this session"
fi

install_supabase_cli() {
  if command -v supabase >/dev/null 2>&1 \
     && [ "$(supabase --version 2>/dev/null)" = "$SUPABASE_VERSION" ]; then
    return 0
  fi
  local arch
  case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "unsupported arch $(uname -m)" >&2; return 1 ;;
  esac
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/supabase/cli/releases/download/v${SUPABASE_VERSION}/supabase_linux_${arch}.tar.gz" \
    | tar -xz -C "$tmp" supabase
  $SUDO install -m 0755 "$tmp/supabase" /usr/local/bin/supabase
  rm -rf "$tmp"
}
if run_step "Supabase CLI install" install_supabase_cli; then
  note "Supabase CLI $SUPABASE_VERSION installed"
else
  note "WARNING: Supabase CLI install failed (details above) — migrations/E2E unavailable"
fi

# Docker: the local Supabase stack runs in containers.
ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
  fi
  if docker info >/dev/null 2>&1; then return 0; fi
  $SUDO sh -c 'nohup dockerd >/var/log/dockerd.log 2>&1 &'
  for _ in $(seq 1 30); do
    docker info >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "dockerd did not become ready in 30s; last 20 lines of /var/log/dockerd.log:"
  tail -n 20 /var/log/dockerd.log || echo "(no dockerd log)"
  return 1
}

STACK_UP=false
if run_step "Docker setup" ensure_docker; then
  # `supabase start` pulls images from several registries. If the cloud
  # environment's network access level blocks them, this is where it shows up.
  if supabase start; then
    STACK_UP=true
    note "Local Supabase stack running"
  else
    note "WARNING: 'supabase start' failed — likely the environment's network access level; see docs/build.md. E2E and migration proof NOT possible"
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

# Headless Chromium for rendering checks (claude-in-chrome isn't available in
# cloud sessions). Used by scripts/web-shot.mjs.
if ! command -v npx >/dev/null 2>&1; then
  note "WARNING: npx not found — Playwright/Chromium not installed, web screenshots NOT possible"
elif run_step "Playwright install" npx --yes "playwright@$PLAYWRIGHT_VERSION" install --with-deps chromium; then
  note "Playwright $PLAYWRIGHT_VERSION Chromium installed (web screenshots available)"
else
  note "WARNING: Playwright/Chromium install failed (details above) — web screenshots NOT possible"
fi

echo ""
echo "Cloud environment summary:"
printf '  - %s\n' "${STATUS[@]}"
echo "Prove a change with: ./scripts/verify.sh"
