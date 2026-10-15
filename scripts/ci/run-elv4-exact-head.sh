#!/usr/bin/env bash
# Read-only source validation. Generated Drift output must already match HEAD.
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
cd "$root"
git diff --exit-code HEAD -- .
test -z "$(git ls-files --others --exclude-standard)"
report_dir="${ELV4_REPORT_DIR:-$(mktemp -d)}"
mkdir -p "$report_dir"
report_dir="$(cd "$report_dir" && pwd)"
source_sha="$(git rev-parse HEAD)"
printf '%s\n' "$source_sha" > "$report_dir/source-sha.txt"
flutter --version --machine > "$report_dir/flutter-version.json"
: > "$report_dir/phases.tsv"
failed=0
phase() {
  local name="$1"; shift
  printf 'ELV4 %s @ %s\n' "$name" "$source_sha"
  if "$@" > "$report_dir/$name.log" 2>&1; then
    printf '%s\tPASS\n' "$name" >> "$report_dir/phases.tsv"
  else
    printf '%s\tFAIL\n' "$name" >> "$report_dir/phases.tsv"
    tail -60 "$report_dir/$name.log"
    failed=1
  fi
}
phase baseline-guards bash -c 'bash scripts/ci/check-no-generated-artifacts.sh && bash scripts/ci/check-elv3-p7-p9-foundation.sh'
phase specification python3 scripts/ci/check-elv4-specification.py
phase reconciliation bash -c 'python3 scripts/ci/check-elv4-closure.py && python3 -m unittest discover -s scripts/ci -p test_elv4_closure.py'
cd "$root/apps/mobile"
phase mobile-deps flutter pub get --enforce-lockfile
phase drift dart run build_runner build
phase mobile-format dart format --output=none --set-exit-if-changed lib test
phase mobile-analyze flutter analyze
phase mobile-tests flutter test --reporter expanded
cd "$root/packages/engineering_core"
phase core-deps dart pub get --enforce-lockfile
phase core-format dart format --output=none --set-exit-if-changed lib test
phase core-analyze dart analyze
phase core-tests dart test --reporter expanded
cd "$root/apps/mobile"
phase p7-p8-acceptance flutter test --reporter expanded \
  test/application/power_workspace_state_test.dart \
  test/application/power_workspace_controller_test.dart \
  test/features/editor/power_workspace_panel_test.dart \
  test/data/elv4_p2_persistence_test.dart \
  test/data/elv4_p2_power_command_service_test.dart \
  test/data/elv4_p7_runtime_test.dart \
  test/data/elv4_p7_batch_runtime_test.dart \
  test/data/elv4_p7_freeze_integration_test.dart \
  test/data/elv4_p7_t06_history_test.dart \
  test/data/elv4_p8_public_vertical_acceptance_test.dart \
  test/data/elv4_p8_command_outcome_durability_test.dart \
  test/data/elv4_p8_failure_race_acceptance_test.dart \
  test/data/elv4_p8_idempotency_race_acceptance_test.dart \
  test/data/elv4_p8_rejection_concurrency_acceptance_test.dart \
  test/data/elv4_p8_freeze_historical_invariance_test.dart \
  test/data/elv4_p9_canonical_port_guard_test.dart \
  test/data/elv_p3_runtime_closure_test.dart
cd "$root"
phase clean-tree bash -c 'git diff --exit-code HEAD -- . && test -z "$(git ls-files --others --exclude-standard)"'
python3 - "$report_dir" "$source_sha" <<'PY'
import datetime,json,os,pathlib,sys
out=pathlib.Path(sys.argv[1])
phases=dict(line.strip().split('\t') for line in (out/'phases.tsv').read_text().splitlines())
report={'schema':'electra.elv4-exact-head-technical.v1','sourceSha':sys.argv[2],
        'timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'runId':os.getenv('GITHUB_RUN_ID'),'runAttempt':os.getenv('GITHUB_RUN_ATTEMPT'),
        'technicalResult':'PASS' if all(v=='PASS' for v in phases.values()) else 'FAIL',
        'phases':phases,'toolchain':json.loads((out/'flutter-version.json').read_text()),
        'runtimeAcceptanceVerified':False,
        'scope':'Full regression plus existing P7/P8 integration tests; not the missing seven-case qualification matrix.'}
(out/'technical-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
PY
exit "$failed"
