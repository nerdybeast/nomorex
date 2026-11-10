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
  DENO_VERSION="$(grep -m1 'deno-version:' "$workflow" | awk '{print $2}')"
  if [ -z "$FLUTTER_VERSION" ] || [ -z "$SUPABASE_VERSION" ] || [ -z "$DENO_VERSION" ]; then
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

# Deno for the edge functions' `deno task check`, at CI's pin (which matches
# the edge runtime). Without it verify.sh falls back to the denoland/deno
# Docker image, and Docker Hub rate-limits anonymous pulls (429), which leaves
# both function checks unproven. A single binary from the GitHub release.
deno_present() {
  command -v deno >/dev/null 2>&1 \
    && [ "$(deno --version 2>/dev/null | awk 'NR==1 {print $2}')" = "$DENO_VERSION" ]
}
install_deno() {
  deno_present && return 0
  local target
  case "$(uname -m)" in
    x86_64) target=x86_64-unknown-linux-gnu ;;
    aarch64|arm64) target=aarch64-unknown-linux-gnu ;;
    *) echo "unsupported arch $(uname -m)" >&2; return 1 ;;
  esac
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/deno.zip" \
    "https://github.com/denoland/deno/releases/download/v${DENO_VERSION}/deno-${target}.zip" || { rm -rf "$tmp"; return 1; }
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "$tmp/deno.zip" -d "$tmp" || { rm -rf "$tmp"; return 1; }
  else
    python3 -m zipfile -e "$tmp/deno.zip" "$tmp" || { rm -rf "$tmp"; return 1; }
  fi
  $SUDO install -m 0755 "$tmp/deno" /usr/local/bin/deno
  rm -rf "$tmp"
  deno_present
}

# Docker is pre-installed in cloud sessions but the daemon isn't running.
# Sets STARTED_DOCKERD=true when this call is what started it.
STARTED_DOCKERD=false

# remove_stale_pidfile <pidfile> <process name> — deletes the pidfile unless
# its PID is a live process called <process name>.
remove_stale_pidfile() {
  local file="$1" name="$2" pid
  pid="$(cat "$file" 2>/dev/null || true)"
  if [ -n "$pid" ] && [ "$(cat "/proc/$pid/comm" 2>/dev/null)" != "$name" ]; then
    echo "removing stale $file (PID $pid is not $name)"
    $SUDO rm -f "$file"
  fi
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y docker.io
  fi
  if docker info >/dev/null 2>&1; then return 0; fi
  # A resumed VM keeps the previous daemons' pidfiles. If a PID now belongs to
  # some other process, dockerd refuses to start ("process with PID N is still
  # running"), or, for containerd's, assumes its managed containerd is up and
  # times out waiting for it ("timeout waiting for containerd to start"). Only
  # a pidfile naming a live process of the right name is real.
  remove_stale_pidfile /var/run/docker.pid dockerd
  remove_stale_pidfile /var/run/docker/containerd/containerd.pid containerd
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
