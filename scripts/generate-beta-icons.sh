#!/usr/bin/env bash
#
# Generates the beta flavor's launcher icons (blue slash) from
# assets/icon/*-beta.png, config in scripts/icons-beta.yaml. Outputs:
#   android/app/src/beta/res/         (overrides main/res for the beta flavor)
#   ios/Runner/Assets.xcassets/AppIcon-beta.appiconset
#   macos/Runner/Assets.xcassets/AppIcon-beta.appiconset
# The iOS and macOS flavors pick the set through ASSETCATALOG_COMPILER_APPICON_NAME
# in their Environment-beta.xcconfig.
#
# Why a scratch copy: flutter_launcher_icons treats any
# flutter_launcher_icons-<flavor>.yaml in the project root as "flavors mode" and
# then ignores the main config, so `dart run flutter_launcher_icons` for the
# local/production icon would stop working. It also rewrites project.pbxproj
# (including an unrelated setting) and, on macOS, ignores flavors and overwrites
# AppIcon. Running it on a copy and taking only the icon files avoids all three.
#
# Usage (after ./scripts/render-icons.sh if a *-beta.svg changed):
#   ./scripts/generate-beta-icons.sh
set -euo pipefail

cd "$(dirname "$0")/.."
root="$PWD"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git ls-files -z | rsync -a --from0 --files-from=- "$root/" "$work/"
cp assets/icon/*-beta.png "$work/assets/icon/"
cp scripts/icons-beta.yaml "$work/flutter_launcher_icons-beta.yaml"

(cd "$work" && flutter pub get >/dev/null && dart run flutter_launcher_icons)

rm -rf android/app/src/beta/res ios/Runner/Assets.xcassets/AppIcon-beta.appiconset \
  macos/Runner/Assets.xcassets/AppIcon-beta.appiconset
cp -R "$work/android/app/src/beta/res" android/app/src/beta/res
cp -R "$work/ios/Runner/Assets.xcassets/AppIcon-beta.appiconset" ios/Runner/Assets.xcassets/
mkdir macos/Runner/Assets.xcassets/AppIcon-beta.appiconset
cp "$work"/macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png macos/Runner/Assets.xcassets/AppIcon-beta.appiconset/
cp macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json macos/Runner/Assets.xcassets/AppIcon-beta.appiconset/
echo "beta icons generated"
