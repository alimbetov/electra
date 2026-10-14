# Electra — ELV3 Code Implementation Index

Status: CODE IMPLEMENTATION AUTHORITY / CR REMEDIATED / TECHNICAL RE-REVIEW PASS / P1 AUTHORIZED  
Branch: `feat/flutter-elv3-physical-routing-design`

## 1. Purpose

This is the implementation entry point once a developer starts coding ELV3. Architecture/process meaning remains governed by the ELV3 architecture authority chain. This index governs code structure, public types, command ownership, Drift schema, transaction/concurrency contracts and test placement.

The previous code technical review reopened readiness. CR-01 through CR-16 are now closed and a fresh re-review passes.

Latest readiness evidence:

- `docs/audit/elv3-code-implementation-technical-rereview.md` — PASS.

The earlier `docs/audit/elv3-code-implementation-technical-review.md` remains historical finding evidence, not the current authorization source.

## 2. Code-level authority order

1. `docs/product/elv3-code-remediation-final-clarifications.md`
2. `docs/product/elv3-code-implementation-remediation-cr01-cr16.md`
3. `docs/product/elv3-code-contract-p1-p3.md`
4. `docs/product/elv3-code-contract-p4-p6.md`
5. `docs/product/elv3-code-contract-p7-p9.md`
6. `docs/product/elv3-dual-review-process-hardening.md`
7. `docs/product/elv3-r2-execution-clarifications.md`
8. `docs/product/elv3-r2-final-readiness-remediation.md`
9. `docs/product/elv3-implementation-specification-v2.md`
10. accepted ADR/P0 authority chain

Earlier wording contradicted by items 1-2 is superseded.

## 3. Layer map

```text
engineering_core
  pure domain/value objects/validators/calculations/codecs

application
  commands/command services/query ports/workspace state/impact coordination

data/repositories
  Drift adapters/phase-specific UoW/transaction-bound stores/error translation

app_database.dart
  tables/indexes/migrations/FKs

presentation
  render + command dispatch only
```

Hard rules:

```text
engineering_core MUST NOT import Drift/Flutter
application MUST NOT depend on Drift row types
widgets MUST NOT own compound DB mutations
calculation engines MUST NOT query repositories
command services are the sole use-case orchestration owner
```

## 4. P1 exact compile target

Core:

```text
elv_cable_reference.dart
elv_cable_resource_definition.dart
elv_cable.dart
```

Application:

```text
elv_command_result.dart
elv_cable_command.dart
elv_cable_repository.dart
elv_cable_command_service.dart
elv_cable_dependency_inspector.dart
elv_write_unit_of_work.dart
```

Data:

```text
drift_elv_cable_repository.dart
drift_elv_cable_write_unit_of_work.dart
```

P1 MUST NOT require P2/P3 store interfaces or tables to compile.

## 5. Phase resource ownership

```text
P1
  CableResourceKind
  TerminationPolicyMode
  TerminationPolicy
  CableResourceDefinition

P2
  CableResourceSelection
  WholeCableSelection
  ResourceSetSelection
  DefinitionGroupSelection
  ResolvedCableResourceSelection
  CableResourceResolver
```

No duplicate/transitional definitions.

## 6. Common ELV command result

All P1-P9 ELV commands use:

```text
ElvCommandResult<T>
  ElvCommandSuccess<T>
  ElvCommandFailureResult<T>

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

Raw Drift/SQLite exceptions never cross the application boundary.

## 7. Durable idempotency

P1 creates:

```text
CommandExecutionRecords
PK(project_id, command_id)
```

Columns/codec are frozen in CR remediation. Domain writes and committed command outcome share one transaction.

Same key + same canonical payload hash returns persisted logical SUCCESS/REJECTED outcome. Same key + different hash returns `ELV_IDEMPOTENCY_CONFLICT`.

## 8. Transaction model

Use phase-specific write sessions over a common ledger scope:

```text
ElvWriteSession
  commandLedger

ElvCableWriteSession       P1
ElvAllocationWriteSession  P2
ElvRoutingWriteSession     P3
...
```

Concrete Drift UoW opens one `AppDatabase.transaction(...)` and supplies stores bound to the same transaction.

Correctness relies on:

```text
FKs
partial unique indexes
expectedRevision conditional updates
atomic transaction
```

not on assumed application-level serialization.

## 9. DB-level concurrency invariants

Mandatory partial unique DB backstops:

```text
one ACTIVE normalized Cable label/project
one RESERVED|ACTIVE allocation/EngineeringConnection
one ACTIVE CanonicalCableRun/(Cable,DesignRevision)
one WORKING ProjectDesignRevision/project
one ACTIVE P5 profile set/project
one active RouteSeparationEvidence subject pair/revision
```

Resource claims also have DB uniqueness.

Constraint failures translate to stable ELV failure codes.

## 10. Real concurrency tests

Race tests use:

```text
one on-disk temp SQLite file
AppDatabase A
AppDatabase B
competing commands
close both
AppDatabase C reopen verification
```

A same-connection `Future.wait` is not concurrency acceptance evidence.

## 11. Shared route coexistence

`EditReusableRouteGeometryCommand` impact MUST include:

```text
CanonicalElvRunImpact
LegacyElectricalRunImpact
```

The impact fingerprint contains both. Commit revalidates canonical traversal chains and legacy electrical route/run/junction behavior through the existing legacy validators. Any invalid dependent rejects the whole edit.

## 12. Frozen snapshot boundary

Freeze uses:

```text
pure ElvPhysicalSnapshotAssembler
+
transaction-bound Drift design-revision command store
```

Every snapshot input read, snapshot insert, revision transition and command-ledger write occurs inside one transaction.

## 13. P4/P5/P6 typing

P4 canonical carrier state uses typed:

```text
CarrierEnvironmentFacts
CarrierInstallationFacts
```

not arbitrary maps.

P5 uses a sealed v1 `PhysicalCompatibilityRule` hierarchy. Unknown rule kinds are rejected.

P6 v1 does not infer general geometric route separation. Numeric distance requires canonical `RouteSeparationEvidenceRecords` owned by the design revision.

## 14. Allocation/workflow clarifications

```text
DRAFT
  termination candidate memory-only

RESERVED
  immutable resource selection exists
  termination may persist

ACTIVE
  complete required termination set

CreateCableRun
  requires ACTIVE Cable
  + WORKING revision
  + >=1 RESERVED|ACTIVE allocation
```

## 15. Canonical tables by phase

```text
P1 / schema 18
  ElvCables
  CommandExecutionRecords

P2 / schema 19
  CableAllocations
  CableAllocationResourceSelections
  CableResourceClaims
  CableTerminationMappings

P3 / schema 20
  ProjectDesignRevisions
  DesignRevisionPhysicalSnapshots
  CanonicalCableRuns
  CableRunTraversals
  RouteHandoffs
  RouteBendEvidence
  LegacyRouteAdoptions

P4 / schema 21
  PathwayContexts
  PhysicalCarriers
  PhysicalCarrierCompartments

P5 / schema 22
  ProjectPhysicalCompatibilityProfileSets
  ProjectPhysicalCompatibilityProfileRefs

P6 / schema 23
  RouteSeparationEvidenceRecords
```

If the branch schema advances before a phase starts, only monotonic number rebasing is allowed; table ownership/order remains fixed.

## 16. Cable dependency inspector

P1 service depends on exact stable port:

```text
ElvCableDependencyInspector
  hasResourceSelectionHistory
  hasConsumingAllocation
  hasCanonicalRunHistory
  blockingDependencyIds
```

Adapters gain real P2/P3 checks as schemas appear without changing the P1 command-service API.

## 17. Required phase gates

Every implementation phase must include:

```text
format/analyze
engineering_core tests
mobile tests
Drift generation
migration tests
restart tests
failure/rollback tests where compound
multi-connection concurrency tests where invariant races exist
legacy electrical regression from P3 onward
command-contract matrix update
exact branch SHA evidence
```

## 18. Current authorization

Authoritative result from `docs/audit/elv3-code-implementation-technical-rereview.md`:

```text
CR-01..CR-16                      CLOSED
open BLOCKER code-design findings 0
open HIGH code-design findings    0
P1 code implementation            AUTHORIZED
ELV3 code-level specification     READY FOR EXECUTION
```

Only P1 is authorized. P2 starts only after P1 exact-SHA gate passes; the same sequential rule applies through P9.
