#!/usr/bin/env bash
#
# Fails if any committed *.g.dart file is out of date with its source.
#
# Generated files are committed, so a provider or annotation edited without
# rerunning build_runner leaves its .g.dart stale. Nothing else notices: the
# app still compiles. The next person to regenerate then finds unrelated
# changes in their diff.
#
# Run by CI (pr-checks.yml) and scripts/verify.sh. To fix a failure:
#   dart run build_runner build --delete-conflicting-outputs
# then commit the changed *.g.dart files.
#
# `build_runner clean` comes first because a plain build trusts its cache in
# .dart_tool/build and can skip a stale file, writing nothing.

set -euo pipefail
cd "$(dirname "$0")/.."

dart run build_runner clean >/dev/null
dart run build_runner build --delete-conflicting-outputs

changed=$(git status --porcelain -- '*.g.dart')
if [ -n "$changed" ]; then
  echo "Generated files are out of date with their sources:"
  echo "$changed"
  git --no-pager diff --stat -- '*.g.dart'
  echo
  echo "Run: dart run build_runner build --delete-conflicting-outputs"
  echo "then commit the *.g.dart changes."
  exit 1
fi
echo "Generated files are up to date."
