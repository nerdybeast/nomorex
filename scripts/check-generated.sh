#!/usr/bin/env bash
#
# Fails if any committed generated file is out of date with its source: the
# build_runner *.g.dart files, and the Pigeon bridge of
# packages/genkit_apple_intelligence (Dart and Swift).
#
# Generated files are committed, so a provider or annotation edited without
# rerunning build_runner leaves its .g.dart stale. Nothing else notices: the
# app still compiles. The next person to regenerate then finds unrelated
# changes in their diff.
#
# Run by CI (pr-checks.yml) and scripts/verify.sh. To fix a failure:
#   ./scripts/gen.sh
# then commit the changed generated files.
#
# `build_runner clean` comes first because a plain build trusts its cache in
# .dart_tool/build and can skip a stale file, writing nothing.

set -euo pipefail
cd "$(dirname "$0")/.."

dart run build_runner clean >/dev/null
dart run build_runner build --delete-conflicting-outputs

# Pigeon: regenerated from pigeon/messages.dart in the plugin package.
(cd packages/genkit_apple_intelligence && flutter pub get >/dev/null && dart run pigeon --input pigeon/messages.dart)

changed=$(git status --porcelain -- '*.g.dart' '*.g.swift')
if [ -n "$changed" ]; then
  echo "Generated files are out of date with their sources:"
  echo "$changed"
  git --no-pager diff --stat -- '*.g.dart' '*.g.swift'
  echo
  echo "Run: ./scripts/gen.sh"
  echo "then commit the generated changes."
  exit 1
fi
echo "Generated files are up to date."
