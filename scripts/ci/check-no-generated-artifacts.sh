#!/usr/bin/env bash
set -euo pipefail

tracked="$(git ls-files | grep -E '(^|/)(\.dart_tool|build)/' || true)"
if [[ -n "$tracked" ]]; then
  echo "Tracked generated/runtime artifacts are forbidden:" >&2
  echo "$tracked" >&2
  exit 1
fi

echo "No tracked .dart_tool/ or build/ artifacts."
