#!/bin/bash
set -euo pipefail

# Only needed in Claude Code on the web — local dev machines already have
# Flutter on PATH.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="/opt/flutter"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

echo "export PATH=\"\$PATH:$FLUTTER_DIR/bin\"" >> "$CLAUDE_ENV_FILE"
export PATH="$PATH:$FLUTTER_DIR/bin"

flutter config --no-analytics
flutter precache
cd "$CLAUDE_PROJECT_DIR"
flutter pub get
