#!/usr/bin/env bash
#
# Regenerates every generated file: the *.g.dart files from a clean build
# cache, and the Pigeon bridge of each plugin package (scripts/lib/pigeon.sh).
#
# A plain `dart run build_runner build` trusts its cache in .dart_tool/build.
# A stale cache can make it skip a file without writing anything, or stall
# with no output and no CPU use after a few seconds. Cleaning first avoids both
# and costs only the ~15s builder compile.
#
#   ./scripts/gen.sh
#
# To check that committed files are current, use scripts/check-generated.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

dart run build_runner clean >/dev/null
dart run build_runner build
source scripts/lib/pigeon.sh
regenerate_pigeon
