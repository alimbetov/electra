# Electra — ELV3 Code Implementation Index

Status: CODE IMPLEMENTATION AUTHORITY / READY FOR P1  
Branch: `feat/flutter-elv3-physical-routing-design`

## 1. Purpose

This is the implementation entry point once a developer starts coding ELV3. Architectural meaning remains governed by the higher-level ELV3 authority chain, but code structure, type names, repository boundaries, persistence ownership and test placement are defined here.

## 2. Code-level authority order

1. `docs/product/elv3-code-contract-p1-p3.md`
2. `docs/product/elv3-code-contract-p4-p6.md`
3. `docs/product/elv3-code-contract-p7-p9.md`
4. `docs/product/elv3-dual-review-process-hardening.md`
5. `docs/product/elv3-r2-execution-clarifications.md`
6. `docs/product/elv3-r2-final-readiness-remediation.md`
7. `docs/product/elv3-implementation-specification-v2.md`
8. accepted ADR/P0 authority chain

Code-level contracts refine but may not contradict domain architecture. If a lower-level code document conflicts with a higher-ranked code document, earlier item wins. If code-level wording would violate domain architecture, domain architecture wins and P9 must record the correction.

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
  repository interfaces
  workspace state
  dependency/impact coordination

apps/mobile/lib/data/repositories
  Drift repository implementations
  database transactions
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

### P1–P3 core

```text
elv_cable_reference.dart
elv_cable.dart
elv_cable_resource.dart
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

P6 uses existing derived-result persistence with design-revision-scoped keys unless P9-approved evidence proves this is technically impossible.

## 6. No-cross-layer rules

```text
engineering_core MUST NOT import Drift/Flutter
application MUST NOT depend on Drift row types
widgets MUST NOT use database tables directly for domain mutations
repositories MUST NOT invent domain validation semantics
calculation engines MUST NOT query repositories
```

## 7. Public command naming

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

No repository may substitute implicit latest revision for a required expected revision.

## 9. Error contract

Errors cross application boundary as typed deterministic failures, never raw Drift/SQLite exceptions.

Primary evaluation order:

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

Multiple findings in one category sort by `(code, entityId, field)`.

## 10. Migration discipline

Each phase owns only its new schema. P1 cannot pre-create P2/P3 tables. Before coding a phase, implementer reads current `schemaVersion` and assigns the next incremental version(s) needed by that phase.

Migration tests must cover:

```text
fresh database
upgrade from previous exact phase schema
reopen after migration
foreign_keys ON
index/uniqueness behavior
legacy electrical data preservation
```

## 11. Code-review checklist per PR

Every phase PR reviewer checks:

```text
[ ] files follow layer ownership
[ ] public types match code contract
[ ] no future-phase persistence leaked
[ ] transactions match command contract matrix
[ ] errors translated deterministically
[ ] idempotency evidence persists atomically
[ ] restart test exists
[ ] failure/rollback test exists where compound
[ ] dependency keys emitted where required
[ ] no widget direct multi-table writes
[ ] no legacy electrical regression
[ ] exact-SHA workflow green
```

## 12. Implementation start rule

P1 may start from this index. After P1 exact-SHA gate closes, update this index only if code-level audit discovers a necessary non-semantic mapping change. Any semantic change reopens architecture review rather than being hidden in implementation.