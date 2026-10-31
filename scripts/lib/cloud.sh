#!/bin/bash
# Shared helpers for the Claude Code cloud environment: scripts/cloud-setup.sh
# (provisioning, cached by the environment's setup script) and
# .claude/hooks/session-start.sh (per-session). Source this, don't run it.

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

FLUTTER_DIR="/opt/flutter"
PLAYWRIGHT_VERSION="1.55.0"

# Pins live in CI so there is one place to bump them. Floating versions have
# broken unrelated PRs before (see the comments in pr-checks.yml).
# Usage: read_pins <repo root>
read_pins() {
  local workflow="$1/.github/workflows/pr-checks.yml"
  FLUTTER_VERSION="$(grep -m1 'flutter-version:' "$workflow" | awk '{print $2}')"
  SUPABASE_VERSION="$(grep -m1 -E '^[[:space:]]+version: [0-9]+\.[0-9]+\.[0-9]+$' "$workflow" | awk '{print $2}')"
  if [ -z "$FLUTTER_VERSION" ] || [ -z "$SUPABASE_VERSION" ]; then
    echo "could not read version pins from $workflow" >&2
    return 1
  fi
}

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

# Docker is pre-installed in cloud sessions but the daemon isn't running.
# Sets STARTED_DOCKERD=true when this call is what started it.
STARTED_DOCKERD=false
ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y docker.io
  fi
  if docker info >/dev/null 2>&1; then return 0; fi
  $SUDO sh -c 'nohup dockerd >/var/log/dockerd.log 2>&1 &'
  STARTED_DOCKERD=true
  for _ in $(seq 1 30); do
    docker info >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "dockerd did not become ready in 30s; last 20 lines of /var/log/dockerd.log:"
  tail -n 20 /var/log/dockerd.log || echo "(no dockerd log)"
  return 1
}

# Is everything cloud-setup.sh installs already on disk? Cheap enough for the
# per-session hook to ask before deciding to provision itself.
toolchain_present() {
  [ -x "$FLUTTER_DIR/bin/flutter" ] \
    && command -v supabase >/dev/null 2>&1 \
    && [ "$(supabase --version 2>/dev/null)" = "$SUPABASE_VERSION" ] \
    && command -v xvfb-run >/dev/null 2>&1 \
    && command -v docker >/dev/null 2>&1
}
