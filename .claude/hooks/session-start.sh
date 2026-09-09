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

# Point the app at a database. `supabase start` needs Docker to pull the
# postgres/gotrue/kong/etc. images, and on this Claude Code on the web
# environment's current network access level (Trusted), those image-blob
# downloads land on CDN hosts that aren't on the default allowlist (e.g.
# Docker Hub's production.cloudfront.docker.com, vs. the allowlisted
# production.cloudflare.docker.com) — so `supabase start` can't reliably
# come up here. *.supabase.co is also not on the Trusted default list, so
# even a hosted project needs the environment's network access widened
# (Custom with *.supabase.co added, or Full) before this actually connects
# — see https://code.claude.com/docs/en/cloud-environments#access-levels.
# Once that's done, .env.local.json below points at a small dedicated cloud
# dev Supabase project (schema migrated from supabase/migrations/, seeded
# with the predefined exercises and the same a@a.com / b@b.com / 123456
# test users from supabase/seed.sql), so `flutter run
# --dart-define-from-file=.env.local.json` and the E2E runner have
# something real to talk to. Never overwrite a file already there — if a
# genuine local stack's config exists, it wins.
ENV_LOCAL="$CLAUDE_PROJECT_DIR/.env.local.json"
if [ ! -f "$ENV_LOCAL" ]; then
  cat > "$ENV_LOCAL" <<'JSON'
{
  "SUPABASE_URL": "https://gjrxtxxxqqnjetzgjtwb.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_D4S0dnLemJkRrbdk_lKRBQ_vkdCuJYs"
}
JSON
fi
