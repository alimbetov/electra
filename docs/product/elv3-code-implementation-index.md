# Electra — ELV3 Code Implementation Index

Status: CODE IMPLEMENTATION AUTHORITY / READINESS REOPENED / P1 HOLD  
Branch: `feat/flutter-elv3-physical-routing-design`

## 1. Purpose

This is the implementation entry point once a developer starts coding ELV3. Architectural meaning remains governed by the higher-level ELV3 authority chain, but code structure, type names, repository boundaries, persistence ownership and test placement are defined here.

A stricter implementation review found code-design gaps that must be remediated before P1 starts. The current blocking review is:

`docs/audit/elv3-code-implementation-technical-review.md`

Until CR-01 through CR-16 are closed, the earlier code-level READY status is suspended.

## 2. Code-level authority order

1. `docs/audit/elv3-code-implementation-technical-review.md` — temporary readiness blocker and required CR-01..CR-16 remediation contract.
2. `docs/product/elv3-code-contract-p1-p3.md`
3. `docs/product/elv3-code-contract-p4-p6.md`
4. `docs/product/elv3-code-contract-p7-p9.md`
5. `docs/product/elv3-dual-review-process-hardening.md`
6. `docs/product/elv3-r2-execution-clarifications.md`
7. `docs/product/elv3-r2-final-readiness-remediation.md`
8. `docs/product/elv3-implementation-specification-v2.md`
9. accepted ADR/P0 authority chain

The technical review currently wins wherever it identifies a code-design ambiguity. After remediation, this index must be updated to reference the closed remediation and rerun audit.

## 3. Layer map

```text
packages/engineering_core/lib/src
  pure domain entities
  immutable value objects
  validators/resolvers
  calculation engines
  canonical serializers/hash inputs

apps/mobile/lib/application
  commands
  services/use-cases
  repository/query interfaces
  workspace state
  dependency/impact coordination

apps/mobile/lib/data/repositories
  Drift persistence adapters
  transaction-bound query/write primitives
  row/domain mapping
  SQLite error translation
  restart/idempotency persistence

apps/mobile/lib/data/database/app_database.dart
  tables
  indexes
  migrations
  foreign keys

apps/mobile/lib/...presentation...
  widgets/rendering only
  dispatch commands
  never own multi-table domain transactions
```

## 4. Frozen source-file groups

The source-file groups remain the intended target but CR-01 requires P1/P2 resource-definition ownership to be corrected before coding starts.

### P1–P3 core target

```text
elv_cable_reference.dart
elv_cable.dart
elv_cable_resource_definition.dart   # P1 reference-data type after CR-01
elv_cable_resource_selection.dart    # P2 runtime selection/resolver after CR-01
elv_cable_allocation.dart
elv_cable_termination.dart
elv_design_revision.dart
elv_cable_run.dart
elv_route_handoff.dart
elv_route_bend_evidence.dart
elv_physical_snapshot.dart
```

### P4–P6 core

```text
elv_pathway_context.dart
elv_physical_carrier.dart
elv_physical_compatibility.dart
elv_physical_compatibility_profile.dart
elv_physical_calculations.dart
elv_physical_evidence.dart
```

Equivalent private splitting is allowed only if exported public contracts remain compatible and P9 records the mapping.

## 5. Frozen canonical table ownership

P1:

```text
ElvCables
CommandExecutionRecords
```

P2:

```text
CableAllocations
CableAllocationResourceSelections
CableResourceClaims
CableTerminationMappings
```

P3:

```text
ProjectDesignRevisions
DesignRevisionPhysicalSnapshots
CanonicalCableRuns
CableRunTraversals
RouteHandoffs
RouteBendEvidence
LegacyRouteAdoptions
```

P4:

```text
PathwayContexts
PhysicalCarriers
PhysicalCarrierCompartments
```

P5:

```text
ProjectPhysicalCompatibilityProfileSets
ProjectPhysicalCompatibilityProfileRefs
```

P6 uses existing derived-result persistence with design-revision-scoped keys unless a later audited implementation finding proves this is technically impossible.

## 6. No-cross-layer rules

```text
engineering_core MUST NOT import Drift/Flutter
application MUST NOT depend on Drift row types
widgets MUST NOT use database tables directly for domain mutations
persistence repositories MUST NOT invent domain validation semantics
calculation engines MUST NOT query repositories
```

CR-02 further requires exactly one application command-orchestration owner; persistence repositories become query/write ports rather than alternate command services.

## 7. Public command naming

Existing command names remain reserved, subject to CR-14 common result/failure envelope and CR-02 orchestration hardening.

P1:

```text
CreateCableCommand
ChangeCableDefinitionRefCommand
ArchiveCableCommand
```

P2:

```text
CreateCableAllocationDraftCommand
ReserveCableResourcesCommand
ReplaceCableTerminationSetCommand
ActivateCableAllocationCommand
ReleaseCableResourcesCommand
ArchiveCableAllocationCommand
```

P3:

```text
BootstrapProjectDesignRevisionCommand
FreezeProjectDesignRevisionCommand
CreateNextWorkingDesignRevisionCommand
SupersedeProjectDesignRevisionCommand
ArchiveProjectDesignRevisionCommand
CreateCableRunCommand
RerouteCableRunCommand
SupersedeCableRunCommand
ArchiveCableRunCommand
EditReusableRouteGeometryCommand
AdoptLegacyElectricalRouteCommand
```

P4+ command names are defined in their phase code contracts.

## 8. Common command envelope

All replayable commands expose:

```text
commandId
projectId
```

All updates to mutable roots additionally expose relevant:

```text
expectedRevision
expectedImpactFingerprint (when shared fan-out applies)
```

No repository/service may substitute implicit latest revision for a required expected revision.

## 9. Error contract

Errors cross application boundary as typed deterministic failures, never raw Drift/SQLite exceptions.

Primary evaluation order remains:

```text
1 command envelope / idempotency
2 entity existence
3 project isolation
4 lifecycle / WORKING revision guard
5 optimistic revision
6 reference/snapshot integrity
7 structural/domain validation
8 dependency impact
9 storage translation
```

CR-14 requires one shared ELV3 `ElvCommandResult<T>` / `ElvFailure` envelope across P1-P9.

## 10. Migration discipline

Current branch database schema is version 17. CR-15 requires the initial phase mapping to be treated as:

```text
P1 -> 18
P2 -> 19
P3 -> 20
P4 -> 21
P5 -> 22
```

unless the branch schema changes before the relevant phase starts; any rebase must remain monotonic and be documented in the phase gate.

Migration tests must cover fresh DB, exact previous-version upgrade, reopen, foreign keys, partial unique indexes and preservation of legacy electrical data.

## 11. Current mandatory remediation before P1

```text
CR-01 P1/P2 cable-resource type ownership
CR-02 one command orchestration owner
CR-03 exact durable command ledger schema/codec
CR-04 DB-level critical partial unique indexes
CR-05 concrete Drift write-unit-of-work transaction contract
CR-06 two-connection SQLite concurrency tests
CR-07 route edit impact includes legacy electrical CableRuns
CR-08 snapshot assembler vs transaction coordinator split
CR-09 typed carrier environment/installation facts
CR-10 exact P5 sealed rule hierarchy
CR-11 executable P6 separation evidence/algorithm
CR-12 DRAFT termination persistence contradiction
CR-13 CreateCableRun allocation prerequisite
CR-14 one ELV command result/failure envelope
CR-15 migration-version baseline
CR-16 exact Cable dependency inspector port
```

## 12. Code-review checklist per PR

Every phase PR reviewer checks:

```text
[ ] files follow layer ownership
[ ] public types match remediated code contract
[ ] no future-phase persistence leaked
[ ] DB-level invariants/indexes exist
[ ] transactions match command matrix/UoW
[ ] errors translated deterministically
[ ] idempotency evidence persists atomically
[ ] two-connection race tests exist where required
[ ] restart test exists
[ ] failure/rollback test exists where compound
[ ] dependency keys emitted where required
[ ] shared route edits validate canonical + legacy dependents
[ ] no widget direct multi-table writes
[ ] no legacy electrical regression
[ ] exact-SHA workflow green
```

## 13. Implementation start rule

P1 MUST NOT start from the previous READY state. First close CR-01 through CR-16 in the code-level contracts and rerun `elv3-code-implementation-technical-review.md`. Only a new PASS may restore `P1 AUTHORIZED`.
