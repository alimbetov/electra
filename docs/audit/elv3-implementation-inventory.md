# ELV3 implementation inventory

Status: LIVE IMPLEMENTATION INVENTORY / P7-P9 FOUNDATION INDEXED / NOT FINAL CLOSURE  
Branch: `feat/flutter-elv3-physical-routing-design`

This file is the P9 inventory required by `docs/product/elv3-code-contract-p7-p9.md`. It reports source reality; planned contracts are never counted as persisted runtime implementation.

## engineering_core

### P1-P2

- `lib/src/elv_cable_resource_definition.dart`
- `lib/src/elv_cable_reference.dart`
- `lib/src/elv_cable.dart`
- `lib/src/elv_cable_resource.dart`
- `lib/src/elv_cable_allocation.dart`
- `lib/src/elv_cable_termination.dart`

### P3-P6

- `elv_design_revision.dart`
- `elv_cable_run.dart`
- `elv_route_handoff.dart`
- `elv_route_bend_evidence.dart`
- `elv_physical_snapshot.dart`
- `elv_pathway_context.dart`
- `elv_physical_carrier.dart`
- `elv_physical_compatibility_profile.dart`
- `elv_physical_profile_set.dart`
- `elv_physical_compatibility.dart`
- `elv_physical_calculations.dart`
- `elv_physical_evidence.dart`

## mobile application layer

### P1-P2

- cable command/service/repository ports and Drift adapters
- allocation command/service/repository ports and Drift adapters
- shared `ElvCommandResult`
- phase-specific write-unit-of-work contracts
- persisted `CommandExecutionRecords`

### P3-P6 contract layer

- design-revision command/repository ports
- cable-run command/repository ports
- pathway/carrier command/repository ports
- exact profile-set command/repository/service ports
- physical calculation nodes/service/store

P3/P4 have concrete Drift adapters/tables in merged `7f1c70` (schema 21).
P5 compatibility persistence, complete P6 dependency evidence and P7 persisted
trace/history integration remain open; see the ELV4 P0 reconciliation below.

### P7 foundation

- `elv_physical_routing_workspace_state.dart`
- `elv_physical_routing_workspace_service.dart`
- `default_elv_physical_routing_workspace_service.dart`
- `elv_physical_trace_service.dart`
- `elv_command_history_repository.dart`
- `elv_workspace_error_codes.dart`

Implemented foundation behavior:

- all seven canonical stages;
- read-only WORKING-revision guard;
- independent command authorization boundary;
- `canEdit` includes command permission evidence;
- persisted-history record/store contract with reversible/irreversible classification.

Concrete Drift workspace query, trace reconstruction and history store remain open.

### P8 foundation

- `elv_failure_probe.dart`
- deterministic `FixedSequenceIdGenerator` and canonical prefixes
- `elv_test_catalog.dart`
- `elv_test_project.dart`
- `elv_test_topology.dart`
- `elv_test_routing.dart`
- `elv_vertical_fixture_plan.dart`
- existing database reopen/failure-injector support

Five fixture plans are frozen: CCTV, LAN, ACS, Fire, Fiber. They are fixture-contract evidence, not DB restart proof.

### P9 foundation

- this inventory;
- `docs/audit/elv3-command-contract-matrix.md`;
- `docs/product/elv3-p7-p9-foundation-design.md`;
- `scripts/ci/check-elv3-p7-p9-foundation.sh`;
- workflow execution of the structural guard.

## current Drift schema

Current implemented schema baseline is P4 / schema version 21.

Reconciled 2026-10-15 against `7f1c701cb4ba492589321f8f9827d20464ddaefb`.
The previous P2/schema 19 statement described the earlier foundation checkpoint,
not the merged runtime baseline. This correction does not establish RC9 closure.

Canonical ELV tables currently implemented:

- `ElvCables`
- `CableAllocations`
- `CableAllocationResourceSelections`
- `CableResourceClaims`
- `CableTerminationMappings`
- `CommandExecutionRecords`
- `ProjectDesignRevisions`, `DesignRevisionPhysicalSnapshots`
- `CanonicalCableRuns`, `CableRunTraversals`, `RouteHandoffs`, `RouteBendEvidence`
- `LegacyRouteAdoptions`
- `PathwayContexts`, `PhysicalCarriers`, `PhysicalCarrierCompartments`
- `TraversalCarrierAssignments`

Planned but not yet persisted:

- P5 compatibility profile-set/finding tables (next schema number must be allocated from actual baseline);
- P6 separation-evidence/revision-scoped result persistence;
- P7 command-history persistence.

This absence is an implementation gap, not an approved schema equivalent.

## reusable infrastructure

- existing `CableRoutes`, `CableRouteNodes`, `CableRouteSegments` remain the canonical reusable route geometry graph;
- `ProjectDerivedResults` remains the intended shared derived-result infrastructure subject to revision-scoped identity;
- legacy electrical `CableRuns` remain untouched and distinct from canonical ELV3 runs.

## process codes

- `ELV-ROUTE-01` installed length
- `ELV-ROUTE-02` carrier fill basis
- `ELV-ROUTE-03` segregation evidence
- `ELV-ROUTE-04` bend-radius basis
- `ELV-ROUTE-05` congestion basis
- `ELV-ROUTE-06` reserve allowance

## stable workspace/history error codes

- `ELV_WORKSPACE_READ_ONLY`
- `ELV_WORKSPACE_COMMAND_FORBIDDEN`
- `ELV_UNDO_NOT_AVAILABLE`
- `ELV_REDO_NOT_AVAILABLE`
- `ELV_UNDO_IRREVERSIBLE`
- `ELV_UNDO_PRECONDITION_CHANGED`

## P8 stable failure points

- `P1_CREATE_CABLE_AFTER_INSERT`
- `P2_RESERVE_AFTER_FIRST_CLAIM`
- `P2_REPLACE_TERMINATION_AFTER_DELETE`
- `P2_ACTIVATE_BEFORE_STATE_UPDATE`
- `P3_FREEZE_AFTER_SNAPSHOT_INSERT`
- `P3_CREATE_NEXT_AFTER_REVISION_INSERT`
- `P3_REROUTE_AFTER_DELETE_OLD_CHAIN`
- `P4_ATTACH_CARRIER_AFTER_TRAVERSAL_UPDATE`
- `P3_ADOPT_AFTER_CABLE_CREATE`

## current test evidence

Implemented evidence includes:

- P1 persistence/restart/migration;
- P2 domain, migration, SQLite concurrency and acceptance foundations;
- P3-P5 domain invariant tests;
- P6 calculation/evidence tests;
- P7 seven-stage workspace/permission tests;
- P7 command-history record contract tests;
- P8 deterministic five-discipline fixture-contract tests;
- P8 failure-probe/reopen support.

Not yet counted as implemented evidence:

- P3-P6 DB verticals;
- P7 presentation + frozen/current concrete trace reconstruction;
- P7 transactional undo/redo;
- five P8 real DB restart verticals;
- P3/P4 failure-probe rollback verticals;
- full idempotency-after-reopen matrix;
- frozen revision reconstruction after later mutation.

## P9 closure blockers

P9 MUST remain open until:

1. P3-P6 canonical persistence verticals are implemented and green;
2. P7 concrete workspace query/trace/history adapters are green;
3. mandatory failure probes roll back exactly before and after reopen;
4. all five real discipline fixtures pass restart;
5. idempotent replay and conflict replay pass after reopen;
6. frozen revision reconstruction is exact after later WORKING mutation;
7. legacy electrical routing regression is green;
8. command matrix maps every public mutation to implementation + test + errors;
9. runtime forbidden-shortcut assertions are green;
10. one final exact branch SHA passes all mobile/core/Drift/foundation gates.
