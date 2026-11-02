#!/usr/bin/env bash
#
# Renders the app icon and splash sources (assets/icon/*.svg) to PNG at each
# SVG's own width/height (1024 for icons, 480 or 1152 for splash images).
# flutter_launcher_icons and flutter_native_splash then turn those PNGs into
# every platform's assets.
#
# Usage:
#   ./scripts/render-icons.sh                  # SVG -> PNG
#   dart run flutter_launcher_icons            # PNG -> app icons
#   dart run flutter_native_splash:create      # PNG -> launch/splash screens
#
# Only needed after editing an SVG: the rendered PNGs are committed, so
# regenerating the platform assets doesn't require Node.
set -euo pipefail

cd "$(dirname "$0")/../assets/icon"

for svg in *.svg; do
  png="${svg%.svg}.png"
  npx --yes @resvg/resvg-js-cli@2.6.2-beta.1 "$svg" "$png" >/dev/null
  echo "rendered $png"
done
