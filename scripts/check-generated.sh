#!/usr/bin/env bash
#
# Fails if any committed generated file is out of date with its source: the
# build_runner *.g.dart files, and the Pigeon bridges of the plugin packages
# (Dart, Swift and Kotlin).
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

# Pigeon: each plugin package's bridge, from its pigeon/messages.dart.
source scripts/lib/pigeon.sh
regenerate_pigeon

changed=$(git status --porcelain -- '*.g.dart' '*.g.swift' '*.g.kt')
if [ -n "$changed" ]; then
  echo "Generated files are out of date with their sources:"
  echo "$changed"
  git --no-pager diff --stat -- '*.g.dart' '*.g.swift' '*.g.kt'
  echo
  echo "Run: ./scripts/gen.sh"
  echo "then commit the generated changes."
  exit 1
fi
echo "Generated files are up to date."
