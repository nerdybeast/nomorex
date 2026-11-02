#!/usr/bin/env bash
#
# Renders the app icon sources (assets/icon/*.svg) to 1024px PNGs, which
# flutter_launcher_icons then turns into every platform's icon set.
#
# Usage:
#   ./scripts/render-icons.sh            # SVG -> PNG
#   dart run flutter_launcher_icons      # PNG -> ios/ android/ macos/ windows/ web/
#
# Only needed after editing an SVG: the rendered PNGs are committed, so
# regenerating the platform icons doesn't require Node.
set -euo pipefail

cd "$(dirname "$0")/../assets/icon"

for svg in *.svg; do
  png="${svg%.svg}.png"
  npx --yes @resvg/resvg-js-cli@2.6.2-beta.1 --fit-width 1024 "$svg" "$png"
  echo "rendered $png"
done
