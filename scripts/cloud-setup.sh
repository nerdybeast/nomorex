#!/bin/bash
#
# Provisions a Claude Code cloud VM so a session can prove a change the way CI
# does (analyze, tests, migrations, E2E, web build). Heavy, slow-changing work
# only: toolchains, system packages, Supabase images, headless Chromium.
#
# Meant to be the environment's *setup script* (claude.ai/code -> environment
# -> Setup script), whose result Anthropic snapshots and reuses, so new sessions
# skip it. Paste this stub into that dialog once:
#
#   #!/bin/bash
#   bash "${CLAUDE_PROJECT_DIR:-$PWD}/scripts/cloud-setup.sh" || true
#
# The SessionStart hook runs this same script itself when the toolchain is
# missing (no setup script configured, or the cache was rebuilt), so both paths
# end up identical. Everything here is idempotent.
#
# Constraints from the setup-script contract: it must exit 0 or the session
# fails to start, and it must finish in roughly five minutes or nothing is
# cached. So independent installs run in parallel, every failure is recorded
# rather than fatal, and the exit code is always 0. Results land in
# $STATUS_FILE for the hook to print.
#
# Environment variables are NOT set yet when a setup script runs, and PATH
# changes made here don't reach the session; the hook persists PATH.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/cloud.sh
source "$REPO_ROOT/scripts/lib/cloud.sh"

STATUS_FILE="/var/lib/nomorex-cloud-setup.status"
RESULTS_DIR="$(mktemp -d)"

if ! read_pins "$REPO_ROOT"; then
  echo "cloud-setup: cannot continue without version pins" >&2
  exit 0
fi

# record <name> <ok|WARNING> <message> — one result file per stage so parallel
# chains never interleave writes.
record() { echo "$2: $3" > "$RESULTS_DIR/$1"; }

# --- Chain A: Flutter ---------------------------------------------------------

setup_flutter() {
  if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
    $SUDO git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR" || return 1
  fi
  # The session may run as a different user than this script; make the tree
  # usable by both, and tell git it's a trusted checkout.
  $SUDO chmod -R a+rwX "$FLUTTER_DIR"
  $SUDO git config --system --add safe.directory "$FLUTTER_DIR"
  export PATH="$PATH:$FLUTTER_DIR/bin"
  flutter config --no-analytics --enable-linux-desktop --enable-web || return 1
  flutter precache --linux --web || return 1
  # Warm the pub cache so the hook's `pub get` is a no-op in new sessions.
  (cd "$REPO_ROOT" && flutter pub get) || return 1
}

chain_flutter() {
  if run_step "Flutter" setup_flutter; then
    record 1-flutter ok "Flutter $FLUTTER_VERSION installed and precached"
  else
    record 1-flutter WARNING "Flutter install failed — nothing can be analyzed or tested"
  fi
}

# --- Chain B: apt, then Playwright (both want the apt lock) -------------------

APT_PKGS=(clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
          libstdc++-12-dev libcurl4-openssl-dev xvfb curl ca-certificates)
install_apt_deps() {
  local missing=()
  for p in "${APT_PKGS[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  [ ${#missing[@]} -eq 0 ] && return 0
  $SUDO apt-get -o DPkg::Lock::Timeout=300 update
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y "${missing[@]}"
}

chain_apt_playwright() {
  if run_step "apt dependencies" install_apt_deps; then
    record 2-apt ok "Linux desktop build deps + xvfb installed (E2E can build)"
  else
    record 2-apt WARNING "apt dependencies failed — E2E cannot build"
  fi
  # Headless Chromium for rendering checks (claude-in-chrome isn't available in
  # cloud sessions). Used by scripts/web-shot.mjs. Needs hosts outside the
  # Trusted network list; see docs/build.md.
  if ! command -v npx >/dev/null 2>&1; then
    record 3-playwright WARNING "npx not found — web screenshots NOT possible"
  elif run_step "Playwright install" npx --yes "playwright@$PLAYWRIGHT_VERSION" install --with-deps chromium; then
    record 3-playwright ok "Playwright $PLAYWRIGHT_VERSION Chromium installed (web screenshots available)"
  else
    record 3-playwright WARNING "Playwright/Chromium install failed — web screenshots NOT possible"
  fi
}

# --- Chain C: Supabase CLI, then pre-pull the stack's images ------------------

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
    | tar -xz -C "$tmp" supabase || return 1
  $SUDO install -m 0755 "$tmp/supabase" /usr/local/bin/supabase
  rm -rf "$tmp"
}

# Pulled images live under /var/lib/docker, which the environment snapshot
# keeps. Starting and stopping the stack is the supported way to pull exactly
# the images this CLI version wants. Running containers don't survive the
# snapshot, so the stack is stopped (and the daemon, if we started it) before
# we finish.
prepull_images() {
  ensure_docker || return 1
  (cd "$REPO_ROOT" && supabase start) || { (cd "$REPO_ROOT" && supabase stop --no-backup) || true; return 1; }
  (cd "$REPO_ROOT" && supabase stop --no-backup) || return 1
  if [ "$STARTED_DOCKERD" = true ]; then
    $SUDO pkill -TERM dockerd || true
    for _ in $(seq 1 20); do pgrep -x dockerd >/dev/null || break; sleep 1; done
  fi
}

chain_supabase() {
  if run_step "Supabase CLI install" install_supabase_cli; then
    record 4-cli ok "Supabase CLI $SUPABASE_VERSION installed"
  else
    record 4-cli WARNING "Supabase CLI install failed — migrations/E2E unavailable"
    record 5-images WARNING "Supabase images not pre-pulled (no CLI)"
    return
  fi
  if run_step "Supabase image pre-pull" prepull_images; then
    record 5-images ok "Supabase images cached"
  else
    record 5-images WARNING "Supabase image pre-pull failed — each session will pull them (slow); check network access in docs/build.md"
  fi
}

# --- Run ----------------------------------------------------------------------

chain_flutter & pid_a=$!
chain_apt_playwright & pid_b=$!
chain_supabase & pid_c=$!
wait "$pid_a" "$pid_b" "$pid_c"

$SUDO mkdir -p "$(dirname "$STATUS_FILE")"
{
  for f in "$RESULTS_DIR"/*; do cat "$f"; done
} | $SUDO tee "$STATUS_FILE" >/dev/null

echo "cloud-setup summary:"
sed 's/^/  - /' "$STATUS_FILE"

# Setup scripts must exit zero; failures are in the status file and the output.
exit 0
