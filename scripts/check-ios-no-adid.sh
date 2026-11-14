#!/usr/bin/env bash
# Fails if a built iOS app bundles Google's advertising-ID SDKs.
#
#   ./scripts/check-ios-no-adid.sh [path/to/Runner.app]   (default: build/ios/iphoneos/Runner.app)
#
# NoMoreX has no ads, and the privacy policy and store answers say no
# advertising identifier is collected. firebase_analytics leaves these SDKs out
# only when FIREBASE_ANALYTICS_WITHOUT_ADID is set while Swift Package Manager
# resolves packages. SwiftPM caches resolved manifests, though: with a warm
# cache the variable is silently ignored and the full SDK comes back. CI
# runners start cold, and this check makes sure it stays that way.
# docs/build.md ("Firebase") covers local builds.
set -euo pipefail

app="${1:-build/ios/iphoneos/Runner.app}"
if [ ! -d "$app/Frameworks" ]; then
  echo "::error::No Frameworks folder in $app. Build iOS first." >&2
  exit 1
fi

found=0
for framework in GoogleAppMeasurementIdentitySupport GoogleAdsOnDeviceConversion; do
  if [ -e "$app/Frameworks/$framework.framework" ]; then
    echo "::error::$framework.framework is in $app. Build with FIREBASE_ANALYTICS_WITHOUT_ADID=true and cold SwiftPM caches (docs/build.md, \"Firebase\")." >&2
    found=1
  fi
done
[ "$found" -eq 0 ] && echo "OK: no advertising-ID SDKs in $app"
exit "$found"
