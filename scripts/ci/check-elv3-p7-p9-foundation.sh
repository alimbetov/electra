#!/usr/bin/env bash
set -euo pipefail

required_files=(
  apps/mobile/lib/application/elv_physical_routing_workspace_state.dart
  apps/mobile/lib/application/elv_physical_routing_workspace_service.dart
  apps/mobile/lib/application/default_elv_physical_routing_workspace_service.dart
  apps/mobile/lib/application/elv_physical_trace_service.dart
  apps/mobile/lib/application/elv_command_history_repository.dart
  apps/mobile/lib/application/elv_workspace_error_codes.dart
  apps/mobile/test/application/elv_physical_routing_workspace_service_test.dart
  apps/mobile/test/application/elv_command_history_repository_contract_test.dart
  apps/mobile/test/support/elv_test_catalog.dart
  apps/mobile/test/support/elv_test_project.dart
  apps/mobile/test/support/elv_test_topology.dart
  apps/mobile/test/support/elv_test_routing.dart
  apps/mobile/test/support/elv_vertical_fixture_plan.dart
  apps/mobile/test/support/elv_failure_injector.dart
  apps/mobile/test/support/elv_database_reopen.dart
  docs/product/elv3-code-contract-p7-p9.md
  docs/product/elv3-p7-p9-foundation-design.md
  docs/audit/elv3-implementation-inventory.md
  docs/audit/elv3-command-contract-matrix.md
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "ELV3 P7-P9 foundation missing required file: $file" >&2
    exit 1
  fi
done

workspace=apps/mobile/lib/application/default_elv_physical_routing_workspace_service.dart
for token in \
  PhysicalRoutingStage.logicalConnection \
  PhysicalRoutingStage.cable \
  PhysicalRoutingStage.allocation \
  PhysicalRoutingStage.termination \
  PhysicalRoutingStage.route \
  PhysicalRoutingStage.carrier \
  PhysicalRoutingStage.findings \
  ELV_WORKSPACE_COMMAND_FORBIDDEN; do
  if ! grep -R -F -q "$token" apps/mobile/lib/application; then
    echo "ELV3 P7-P9 foundation missing canonical token: $token" >&2
    exit 1
  fi
done

if ! grep -F -q 'commandMutationsAllowed' "$workspace"; then
  echo 'P7 canEdit must include command permission evidence.' >&2
  exit 1
fi

failure_points=apps/mobile/lib/application/elv_failure_probe.dart
for point in \
  P1_CREATE_CABLE_AFTER_INSERT \
  P2_RESERVE_AFTER_FIRST_CLAIM \
  P2_REPLACE_TERMINATION_AFTER_DELETE \
  P2_ACTIVATE_BEFORE_STATE_UPDATE \
  P3_FREEZE_AFTER_SNAPSHOT_INSERT \
  P3_CREATE_NEXT_AFTER_REVISION_INSERT \
  P3_REROUTE_AFTER_DELETE_OLD_CHAIN \
  P4_ATTACH_CARRIER_AFTER_TRAVERSAL_UPDATE \
  P3_ADOPT_AFTER_CABLE_CREATE; do
  if ! grep -F -q "$point" "$failure_points"; then
    echo "P8 stable failure point missing: $point" >&2
    exit 1
  fi
done

inventory=docs/audit/elv3-implementation-inventory.md
python3 - "$inventory" <<'PY'
import pathlib
import re
import sys

source = pathlib.Path('apps/mobile/lib/data/database/app_database.dart').read_text()
inventory = pathlib.Path(sys.argv[1]).read_text()
actual = re.search(r'int get schemaVersion => (\d+);', source)
recorded = re.search(r'Current implemented schema baseline is .* / schema version (\d+)\.', inventory)
if not actual or not recorded:
    sys.exit('P9 inventory schema baseline or AppDatabase.schemaVersion is missing.')

actual_version = int(actual[1])
elv3_baseline = int(recorded[1])
if actual_version < elv3_baseline:
    sys.exit(
        'P9 inventory schema baseline cannot exceed AppDatabase.schemaVersion: '
        f'ELV3={elv3_baseline}, AppDatabase={actual_version}.'
    )
PY

if ! grep -F -q 'P3-P6 persistence prerequisite: OPEN' docs/product/elv3-p7-p9-foundation-design.md; then
  echo 'P7-P9 foundation must not masquerade as runtime closure.' >&2
  exit 1
fi

echo 'ELV3 P7-P9 foundation contract: PASS'
