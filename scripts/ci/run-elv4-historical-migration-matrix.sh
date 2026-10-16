#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
current_sha="$(git -C "$root" rev-parse HEAD)"
tmp="$(mktemp -d)"
exporter="$root/scripts/ci/elv4_historical_fixture_export.dart"

cleanup() {
  for worktree in "$tmp"/worktree-*; do
    if [[ -d "$worktree" ]]; then
      git -C "$root" worktree remove --force "$worktree" >/dev/null 2>&1 || true
    fi
  done
  rm -rf "$tmp"
}
trap cleanup EXIT

run_origin() {
  local version="$1"
  local sha="$2"
  local worktree="$tmp/worktree-v$version"
  local fixture="$tmp/elv4-v$version.sqlite"
  local exporter_test="test/elv4_historical_fixture_export_test.dart"

  printf 'ELV4 historical migration v%s origin %s -> %s\n' \
    "$version" "$sha" "$current_sha"
  git -C "$root" fetch --no-tags --depth=1 origin "$sha"
  git -C "$root" worktree add --detach "$worktree" "$sha" >/dev/null
  test "$(git -C "$worktree" rev-parse HEAD)" = "$sha"

  mkdir -p "$worktree/apps/mobile/test"
  cp "$exporter" "$worktree/apps/mobile/$exporter_test"
  (
    cd "$worktree/apps/mobile"
    flutter pub get
    ELV4_HISTORICAL_FIXTURE_OUT="$fixture" \
    ELV4_HISTORICAL_VERSION="$version" \
      flutter test --reporter expanded "$exporter_test"
  )
  test -s "$fixture"

  (
    cd "$root/apps/mobile"
    ELV4_HISTORICAL_FIXTURE="$fixture" \
    ELV4_HISTORICAL_VERSION="$version" \
      flutter test --reporter expanded \
        test/data/elv4_p9_historical_migration_matrix_test.dart
  )

  git -C "$root" worktree remove --force "$worktree" >/dev/null
}

run_origin 21 74c61f6443c3beaf98e69f0d5f21af3f09474c5c
run_origin 22 b5e3dc94ba026ecb76e3b6e1b17853bf0f63ccb4

printf 'ELV4 historical migration matrix PASS @ %s\n' "$current_sha"
