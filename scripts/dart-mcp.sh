#!/bin/bash
#
# Starts the Dart and Flutter MCP server (`dart mcp-server`, bundled with the
# Dart SDK) for Claude Code. .mcp.json points here rather than at `dart`
# directly because the PATH an MCP server inherits isn't guaranteed: in cloud
# sessions Flutter lives in /opt/flutter and the SessionStart hook only adds it
# to PATH for later Bash commands.
#
# stdout is the MCP protocol stream, so nothing else may write to it.

set -euo pipefail

dart_bin=""
if command -v dart >/dev/null 2>&1; then
  dart_bin="$(command -v dart)"
elif [ -n "${FLUTTER_ROOT:-}" ] && [ -x "$FLUTTER_ROOT/bin/dart" ]; then
  dart_bin="$FLUTTER_ROOT/bin/dart"
elif [ -x /opt/flutter/bin/dart ]; then
  dart_bin=/opt/flutter/bin/dart
else
  echo "dart-mcp: no dart found on PATH, in \$FLUTTER_ROOT or /opt/flutter" >&2
  exit 1
fi

# --force-roots-fallback adds tools for setting the project roots, for clients
# that don't send MCP roots themselves; the server needs roots before its
# analysis and test tools can act on this project.
exec "$dart_bin" mcp-server --force-roots-fallback "$@"
