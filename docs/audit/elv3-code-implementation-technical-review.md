# Electra — ELV3 Code Implementation Technical Review

Status: CODE-IMPLEMENTATION TECHNICAL REVIEW / READINESS REOPENED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Reviewed entry point: `docs/product/elv3-code-implementation-index.md`

## 1. Objective

Review the ELV3 code-level specification against the current Flutter/Dart/Drift implementation conventions and attempt to find defects that would force developers to invent code architecture, transaction semantics, persistence constraints or test strategy during P1-P9 implementation.

This review is stricter than the prior code-level readiness audit. A finding is BLOCKER/HIGH when two conforming developers could produce behaviorally incompatible implementations or when the proposed implementation could violate an accepted project invariant under concurrency/migration/coexistence.

## 2. Existing code checked

The review checked the code-level contracts against current branch code including:

- `engineering_core` export/layout conventions;
- `EngineeringReferenceCatalog` current constructor/wire format/validation;
- `EngineeringReferenceRepository` and Drift reference adapter;
- existing `IdGenerator` UUID-v7/test sequence pattern;
- existing engineering placement command/fingerprint/operation persistence;
- `app_database.dart` schema version 17 and migration/index conventions;
- legacy `CableRoutes`, `CableRouteNodes`, `CableRouteSegments`, electrical `CableRuns`, floor handoffs and `ProjectDerivedResults`;
- current `CableRoutingRepository`/`CableRouteValidator` behavior.

## 3. Findings summary

| ID | Finding | Severity | State |
|---|---|---:|---|
| CR-01 | P1 `CableDefinition` requires P2-owned `CableResourceDefinition` source/type | HIGH | OPEN |
| CR-02 | repository and service both appear to own command orchestration | HIGH | OPEN |
| CR-03 | `CommandExecutionRecords` exact schema/payload/result codec is not frozen | HIGH | OPEN |
| CR-04 | critical lifecycle/cardinality invariants lack frozen DB-level unique indexes | HIGH | OPEN |
| CR-05 | `BEGIN IMMEDIATE` is prescribed without a concrete Drift transaction primitive/strategy | HIGH | OPEN |
| CR-06 | concurrent-write tests can give false confidence if they use one Drift connection | HIGH | OPEN |
| CR-07 | reusable route geometry fan-out excludes legacy electrical `CableRuns` | BLOCKER | OPEN |
| CR-08 | snapshot builder ownership/transaction boundary remains split/ambiguous | HIGH | OPEN |
| CR-09 | P4 carrier environment/installation facts use open `Map<String,Object?>` domain state | HIGH | OPEN |
| CR-10 | P5 `PhysicalCompatibilityProfile` exact sealed rule hierarchy is not defined | HIGH | OPEN |
| CR-11 | P6 measurable separation algorithm/evidence contract is not executable | HIGH | OPEN |
| CR-12 | P7 permits DRAFT termination preparation while persisted selection evidence does not exist until RESERVED | HIGH | OPEN |
| CR-13 | `CreateCableRun` prerequisite relative to allocation state is not frozen | MEDIUM/HIGH | OPEN |
| CR-14 | ELV command result/failure model is fragmented instead of one stable application contract | MEDIUM/HIGH | OPEN |
| CR-15 | phase migration versions are left implementation-selected despite current schemaVersion=17 | MEDIUM | OPEN |
| CR-16 | future downstream Cable dependency checks are described as generic probes but exact port is absent | MEDIUM/HIGH | OPEN |

Open BLOCKER = 1. Open HIGH = 11. P1 code implementation authorization is therefore suspended until remediation closes CR-01 through CR-16.

## 4. CR-01 — CableResourceDefinition ownership/compile order

Current P1 code contract defines `CableDefinition(resourceDefinitions: Iterable<CableResourceDefinition>)`, but the exact P1 source-file plan does not create `elv_cable_resource.dart`; that file is declared in P2. The document says P1 "may introduce" the immutable type, which leaves incompatible file/type ownership.

### Required resolution

P1 owns reference-data resource structure because it is part of the immutable CableDefinition payload:

```text
P1 elv_cable_resource_definition.dart
  CableResourceKind
  TerminationPolicyMode
  TerminationPolicy
  CableResourceDefinition
```

P2 owns runtime selection/allocation behavior:

```text
P2 elv_cable_resource_selection.dart
  CableResourceSelection
  WholeCableSelection
  ResourceSetSelection
  DefinitionGroupSelection
  CableResourceResolver
  ResolvedCableResourceSelection
```

No duplicate transitional type is allowed.

## 5. CR-02 — one command orchestration owner

The P1 repository port currently exposes both reads and `create/changeDefinition/archive`, while the UI is instructed to use `ElvCableService`. This permits either repository-owned or service-owned orchestration.

### Required resolution

Freeze one pattern:

```text
ElvCableRepository
  = persistence/query primitives only

ElvCableCommandService
  = command validation/order/idempotency/unit-of-work owner
```

The service invokes one transactional data-layer unit-of-work; repositories do not recursively orchestrate other repositories. Apply the same rule P2-P5.

## 6. CR-03 — exact durable command ledger

The specification requires `CommandExecutionRecords` but does not freeze exact columns or result encoding.

### Required schema

```text
CommandExecutionRecords
- project_id FK -> Projects.id
- command_id
- command_type
- payload_schema_version
- normalized_payload_sha256
- outcome_kind
- logical_result_json
- created_at
- committed_at
- origin_device_id
PRIMARY KEY(project_id, command_id)
```

`logical_result_json` stores stable logical identities/result data only, never raw Drift rows or exception text. Payload hashing uses versioned canonical JSON. Every replayable ELV command must declare its payload schema marker.

## 7. CR-04 — DB-enforced critical invariants

Application pre-checks are insufficient under competing writers. Freeze explicit partial unique indexes (or a proven SQLite equivalent with identical concurrency behavior):

```sql
CREATE UNIQUE INDEX ux_elv_cable_active_label
ON elv_cables(project_id, normalized_label)
WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL;

CREATE UNIQUE INDEX ux_elv_alloc_consuming_connection
ON cable_allocations(engineering_connection_id)
WHERE lifecycle_state IN ('RESERVED','ACTIVE') AND deleted_at IS NULL;

CREATE UNIQUE INDEX ux_elv_run_active_cable_revision
ON canonical_cable_runs(cable_id, design_revision_id)
WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL;

CREATE UNIQUE INDEX ux_elv_design_revision_working
ON project_design_revisions(project_id)
WHERE state = 'WORKING' AND deleted_at IS NULL;

CREATE UNIQUE INDEX ux_elv_profile_set_active
ON project_physical_compatibility_profile_sets(project_id)
WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL;
```

Constraint failures must map to stable domain failures.

## 8. CR-05 — Drift transaction primitive

`BEGIN IMMEDIATE` is repeatedly shown, but the implementation contract does not state how this is achieved safely through Drift. Ad-hoc `customStatement('BEGIN IMMEDIATE')` nested inside `database.transaction()` is not an acceptable unspecified implementation.

### Required resolution

Introduce one data-layer abstraction, for example:

```dart
abstract interface class ElvWriteUnitOfWork {
  Future<T> run<T>(Future<T> Function() action);
}
```

The concrete Drift implementation owns the chosen supported transaction mode. Semantic correctness MUST rely on DB uniqueness/FKs + optimistic revision checks, not on assuming application pre-check serialization. The implementation must document the exact Drift/SQLite transaction mechanism used and prove it in concurrency tests.

## 9. CR-06 — real concurrency test topology

A concurrency test using one `AppDatabase`/single SQLite connection may serialize both futures and never exercise competing writers.

### Required resolution

For allocation/revision/profile-set race tests:

```text
one temporary on-disk SQLite database
connection A -> AppDatabase A
connection B -> AppDatabase B
foreign_keys ON both
(optional WAL only if production config uses/proves it)
launch competing commands
assert exactly one commits where uniqueness applies
close/reopen third connection and verify canonical state
```

## 10. CR-07 — reusable route edit must include legacy electrical dependents

BLOCKER.

The code contract reuses existing `CableRoute/Node/Segment` infrastructure. Legacy electrical `CableRuns` still reference `CableRoutes.routeId`. `EditReusableRouteGeometryCommand` currently resolves only canonical CableRuns whose traversals reference affected segments.

A shared route edit can therefore invalidate a legacy electrical run without appearing in the impact preview.

### Required resolution

Impact set must be a tagged union:

```text
RouteImpactDependent
  CanonicalElvRun(runId, revision)
  LegacyElectricalRun(runId, circuitId, routeId, revision)
```

Preview fingerprint includes both sets. Commit must revalidate:

- every canonical traversal chain;
- every affected legacy electrical route/run using current `CableRouteValidator`/legacy invariants.

If any dependent becomes invalid, the shared geometry edit is rejected atomically. P3 regression tests must include one route used by both canonical ELV traversal and a legacy electrical run.

## 11. CR-08 — snapshot transaction ownership

`ElvPhysicalSnapshotBuilder` is described as application/pure boundary but returns `Future` and may read across repositories, while freeze requires all reads and snapshot insert/state transition in one DB transaction.

### Required resolution

Split responsibilities:

```text
ElvPhysicalSnapshotAssembler (pure engineering/application logic)
  build(materialized PhysicalSnapshotInput) -> snapshot

DriftElvDesignRevisionUnitOfWork
  opens one transaction
  loads all canonical rows using transaction-bound queries
  materializes PhysicalSnapshotInput
  invokes assembler
  inserts snapshot
  updates revision state
  inserts command record
```

No snapshot repository reads may escape the freeze transaction.

## 12. CR-09 — typed carrier facts

`PhysicalCarrier.environmentFacts` and `installationFacts` are open maps. This reintroduces arbitrary key/value schema into canonical domain state and makes P5 rules non-type-safe.

### Required resolution

Define immutable typed values, for example:

```text
CarrierEnvironmentFacts
  exposureClassCode?
  moistureClassCode?
  contaminationClassCode?
  climateClassCode?
  temperatureRange?
  fireZoneRef?

CarrierInstallationFacts
  installationClassCode?
  openOrClosed?
  embeddedOrExposed?
  supportMethodCode?
  maintenanceAccessibility?
  penetrationRef?
```

Reference-code fields resolve through accepted ELV2 dictionaries. Persistence may remain canonical JSON, but domain state must be typed/versioned.

## 13. CR-10 — PhysicalCompatibilityProfile rule hierarchy

P5 specifies combination behavior but not the concrete rule types a developer must implement.

### Required resolution

Freeze a sealed v1 rule model, for example:

```text
sealed PhysicalCompatibilityRule
  AllowedCableClassRule
  AllowedCarrierKindRule
  AllowedInstallationClassRule
  AllowedEnvironmentClassRule
  MinimumBendRadiusRule/reference basis
  MaximumCableDiameterRule
  MinimumCarrierUsableAreaRule (intrinsic only)
  DirectIntrinsicProhibitionRule
```

Each rule has canonical `ruleCode`, typed payload, validate/toMap/fromMap and explicit combination category. No generic `Map<String,Object?> rule` is allowed as canonical P5 profile state.

## 14. CR-11 — measurable separation is not executable

P6 permits "actual measurable separation when geometry supports it" but defines no algorithm/evidence object, so implementations can produce different distances.

### Required v1 resolution

Either:

A. freeze an exact world-geometry minimum-segment-distance algorithm and its applicability domain; or

B. for P6 v1, do not infer general route separation. Report shared carrier/compartment/barrier facts and consume an explicit typed `RouteSeparationEvidence` for numeric separation.

This review recommends B for initial correctness. Missing explicit measurement -> separation distance UNRESOLVED, not guessed.

## 15. CR-12 — DRAFT termination contradiction

P7 states DRAFT allocation termination may be prepared, while P2 persists immutable resource selection only during Reserve. A persisted termination cannot be validated against selected resources before that evidence exists.

### Required resolution

```text
DRAFT
  UI may stage termination candidate in memory only
  no CableTerminationMappings persisted

RESERVED
  immutable resource selection exists
  ReplaceCableTerminationSet may persist mappings

ACTIVE
  replacement remains complete-set atomic and must remain valid
```

## 16. CR-13 — CreateCableRun allocation prerequisite

The code contract does not freeze whether a Cable with no consuming allocation may receive a canonical run.

### Required resolution

For ELV3 P1-P9, `CreateCableRun` requires:

```text
Cable ACTIVE
current ProjectDesignRevision WORKING
at least one RESERVED or ACTIVE CableAllocation for this Cable
```

This permits route design before final activation/termination while preserving the accepted logical-to-physical realization path. A Cable with no reserved/active allocation cannot create a canonical run.

## 17. CR-14 — one ELV command result/failure contract

P1 introduces `ElvCableCommandResult`, later documents use generic `CommandResult<T>`, and existing placement has its own failure type. ELV3 itself should not fragment public command handling per phase.

### Required resolution

Freeze ELV3-wide application contract:

```text
sealed ElvCommandResult<T>
  ElvCommandSuccess<T>
  ElvCommandFailureResult(ElvFailure)

ElvFailure
  code
  category
  entityType?
  entityId?
  field?
  expectedRevision?
  actualRevision?
  details
```

Stable code strings remain phase-specific, but envelope/result semantics are shared P1-P9.

## 18. CR-15 — migration versions

Current branch schemaVersion is 17. Because delivery is sequential and phase-gated, leaving phase numbers entirely to implementation is unnecessary ambiguity.

### Required baseline

Unless schemaVersion changes before P1 coding starts:

```text
P1 -> 18
P2 -> 19
P3 -> 20
P4 -> 21
P5 -> 22
P6 -> no schema bump unless an approved new canonical table is added
P7/P8/P9 -> no schema bump by default
```

If branch schemaVersion changes before a phase starts, the implementation must rebase these numbers monotonically and record the mapping in the phase gate; table ownership/order may not change.

## 19. CR-16 — exact Cable downstream dependency port

P1 currently says future P2/P3 dependency probes initially return false without freezing the interface.

### Required port

```text
abstract interface class ElvCableDependencyInspector {
  Future<bool> hasResourceSelectionHistory(projectId, cableId);
  Future<bool> hasConsumingAllocation(projectId, cableId);
  Future<bool> hasCanonicalRunHistory(projectId, cableId);
  Future<List<String>> blockingDependencyIds(projectId, cableId);
}
```

P1 uses an implementation backed by only available P1 schema and returns false for not-yet-existing categories. P2/P3 replace/extend the adapter after their migrations without changing `ElvCableCommandService` API.

## 20. Final verdict

```text
architecture alignment                        PASS
code layer direction                         PASS
current code-level specification completeness FAIL / REOPENED

BLOCKER findings                              1
HIGH findings                                11
MEDIUM/HIGH findings                         3
MEDIUM findings                              1

P1 code implementation                       HOLD
```

The code-level design is close, but the prior `READY FOR EXECUTION` status was premature at implementation-detail level. Most findings are local hardening work; the canonical ELV3 domain architecture does not need redesign. After CR-01..CR-16 are remediated, rerun this review before restoring P1 authorization.
