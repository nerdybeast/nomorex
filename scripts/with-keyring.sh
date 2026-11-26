#!/usr/bin/env bash
#
# Runs a command with a D-Bus session and an unlocked GNOME Keyring, which the
# Linux desktop app needs for flutter_secure_storage (the AI keys, #185).
# Without one, the first keyring read takes the whole app down, so Linux E2E
# goes through this:
#
#   xvfb-run -a ./scripts/with-keyring.sh ./scripts/e2e.sh linux --reset
#
# The keyring is created on the fly with an empty password and lives only as
# long as the session. Needs the dbus and gnome-keyring packages.
set -euo pipefail

if [[ -z "${NOMOREX_IN_DBUS_SESSION:-}" ]]; then
  exec env NOMOREX_IN_DBUS_SESSION=1 dbus-run-session -- "$0" "$@"
fi

# --unlock reads the password (an empty line) from stdin, creating the login
# keyring if there isn't one, and prints the variable that points clients at
# it. Don't narrow it with --components: the daemon then tries to show a
# password prompt, which can't open without a desktop, and no keyring is made.
eval "$(printf '\n' | gnome-keyring-daemon --unlock)"
export GNOME_KEYRING_CONTROL

exec "$@"
