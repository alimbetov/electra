# ELV3 implementation inventory

Status: LIVE IMPLEMENTATION INVENTORY / NOT FINAL CLOSURE  
Branch: `feat/flutter-elv3-physical-routing-design`

This file is the P9 inventory required by `docs/product/elv3-code-contract-p7-p9.md`. It is updated during implementation and becomes final evidence only after the P9 exact-SHA gate.

## engineering_core

### P1-P2

- `lib/src/elv_cable_resource_definition.dart`
- `lib/src/elv_cable_reference.dart`
- `lib/src/elv_cable.dart`
- `lib/src/elv_cable_resource.dart`
- `lib/src/elv_cable_allocation.dart`
- `lib/src/elv_cable_termination.dart`

### P3

- `lib/src/elv_design_revision.dart`
- `lib/src/elv_cable_run.dart`
- `lib/src/elv_route_handoff.dart`
- `lib/src/elv_route_bend_evidence.dart`
- `lib/src/elv_physical_snapshot.dart`

### P4

- `lib/src/elv_pathway_context.dart`
- `lib/src/elv_physical_carrier.dart`

### P5

- `lib/src/elv_physical_compatibility_profile.dart`
- `lib/src/elv_physical_profile_set.dart`
- `lib/src/elv_physical_compatibility.dart`

### P6

- `lib/src/elv_physical_calculations.dart`
- `lib/src/elv_physical_evidence.dart`

## mobile application layer

### P1-P2

- cable command/service/repository ports
- allocation command/service/repository ports
- shared `ElvCommandResult`
- phase-specific write-unit-of-work contracts

### P3

- `elv_design_revision_command.dart`
- `elv_design_revision_repository.dart`
- `elv_cable_run_command.dart`
- `elv_cable_run_repository.dart`

### P4

- `elv_pathway_command.dart`
- `elv_pathway_repository.dart`
- `elv_physical_carrier_command.dart`
- `elv_physical_carrier_repository.dart`

### P5

- `elv_physical_profile_set_command.dart`
- `elv_physical_compatibility_repository.dart`
- `elv_physical_compatibility_service.dart`

### P6

- `elv_physical_calculation_nodes.dart`
- `elv_physical_calculation_service.dart`

### P7

- `elv_physical_routing_workspace_state.dart`
- `elv_physical_routing_workspace_service.dart`
- `elv_physical_trace_service.dart`

### P8

- `elv_failure_probe.dart`

## current Drift schema

Current implemented schema baseline is P2 / schema version 19.

Canonical ELV tables currently implemented:

- `ElvCables`
- `CableAllocations`
- `CableAllocationResourceSelections`
- `CableResourceClaims`
- `CableTerminationMappings`
- `CommandExecutionRecords`

Planned but not yet persisted at this inventory revision:

- P3 schema 20 tables
- P4 schema 21 tables
- P5 schema 22 tables
- P6 `RouteSeparationEvidenceRecords` schema 23 table

This absence is an implementation gap, not an approved schema equivalent.

## reusable infrastructure

- existing `CableRoutes`, `CableRouteNodes`, `CableRouteSegments` remain the canonical reusable route geometry graph;
- existing `ProjectDerivedResults` is the intended P5/P6 derived-result store;
- legacy electrical `CableRuns` remain untouched and distinct from canonical ELV3 runs.

## P6 process codes

- `ELV-ROUTE-01` installed length
- `ELV-ROUTE-02` carrier fill basis
- `ELV-ROUTE-03` segregation evidence
- `ELV-ROUTE-04` bend-radius basis
- `ELV-ROUTE-05` congestion basis
- `ELV-ROUTE-06` reserve allowance

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

Implemented test categories include:

- P1 persistence/restart/migration;
- P2 domain, migration, SQLite concurrency and five-scenario acceptance foundations;
- P3-P5 domain invariant tests;
- P6 installed-length/occupancy/bend-evidence tests;
- P7 read-only workspace-state test;
- P8 failure-probe test support.

## P9 closure blockers

P9 MUST remain open until all of the following are true:

1. P3-P5 persistence verticals are implemented and green;
2. P6 persistence/restart/invalidation vertical is implemented and green;
3. P7 concrete workspace controller/presentation flow is green;
4. P8 mandatory failure probes are wired into concrete repositories and all rollback/reopen fixtures pass;
5. all five end-to-end discipline fixtures pass restart;
6. legacy electrical routing regression is green;
7. command-contract matrix contains every public P1-P8 mutation;
8. one final exact branch SHA passes all mobile/core/Drift gates.
