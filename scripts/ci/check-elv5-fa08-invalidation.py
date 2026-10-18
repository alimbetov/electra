#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INVALIDATOR = ROOT / 'apps/mobile/lib/data/repositories/elv5/drift_elv5_dependency_invalidator.dart'
LIFECYCLE = ROOT / 'apps/mobile/lib/data/repositories/elv5/drift_elv5_lifecycle_invalidation.dart'
COORDINATOR = ROOT / 'apps/mobile/lib/data/repositories/elv5/drift_fa08_invalidation_coordinator.dart'
P1 = ROOT / 'apps/mobile/test/data/elv5_environment_ampacity_fa08_persistence_test.dart'
P2 = ROOT / 'apps/mobile/test/data/elv5_fa08_invalidation_test.dart'
REPUBLISH = ROOT / 'apps/mobile/test/data/elv5_fa08_republication_after_invalidation_test.dart'


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f'ELV5 FA08 invalidation guard failed: {message}')


def main() -> None:
    invalidator = INVALIDATOR.read_text(encoding='utf-8')
    lifecycle = LIFECYCLE.read_text(encoding='utf-8')
    coordinator = COORDINATOR.read_text(encoding='utf-8')
    p1 = P1.read_text(encoding='utf-8')
    p2 = P2.read_text(encoding='utf-8')
    republish = REPUBLISH.read_text(encoding='utf-8')

    require('lifecycle.invalidateNodes(' in invalidator, 'must use shared lifecycle invalidation closure')
    require('database.transaction' in lifecycle and 'requireWorking' in lifecycle, 'closure must be atomic and lifecycle guarded')
    require("freshness = 'STALE'" in lifecycle, 'must stale pointers')
    require('generation = generation + 1' in lifecycle, 'must advance generation once')
    require("freshness <> 'STALE'" in lifecycle, 'repeated invalidation must be idempotent')

    for token in (
        'environmentEditionChanged',
        'groupingEvidenceChanged',
        'routeChanged',
        'cableDefinitionChanged',
        'CABLE_RUN_ROUTE',
        'AMPACITY_GROUPING_CORRECTION',
        'ELV5_ENVIRONMENT_PROFILE',
    ):
        require(token in coordinator, f'coordinator missing {token}')

    for token in (
        'ROOM environment replacement is immutable and CAS guarded',
        'ROUTE_SECTION environment overrides ROOM profile',
        'ampacity section editions are immutable and binding CAS guarded',
        'FA-08 policy editions are immutable and CAS guarded',
    ):
        require(token in p1, f'P1 qualification missing {token}')

    for token in (
        'environment edition change',
        'grouping 1 to N',
        'route section add or remove',
        'cable definition change',
    ):
        require(token in p2, f'P2 invalidation qualification missing {token}')

    require('expectedGeneration: 1' in republish, 'must qualify stale generation rejection')
    require('expectedGeneration: 2' in republish, 'must qualify next generation publication')
    require("expect(row.read<int>('generation'), 3)" in republish, 'must reach generation 3')
    require("expect(row.read<String>('freshness'), 'CURRENT')" in republish, 'must republish CURRENT')

    print('ELV5 FA08 invalidation contract: PASS')


if __name__ == '__main__':
    main()
