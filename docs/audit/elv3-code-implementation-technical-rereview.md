# Electra — ELV3 Code Implementation Technical Re-review

Status: CODE-IMPLEMENTATION TECHNICAL RE-REVIEW / PASS  
Branch: `feat/flutter-elv3-physical-routing-design`  
Previous review: `docs/audit/elv3-code-implementation-technical-review.md`  
Remediation: `docs/product/elv3-code-implementation-remediation-cr01-cr16.md`  
Final clarifications: `docs/product/elv3-code-remediation-final-clarifications.md`

## 1. Objective

Repeat the same implementation-level review after CR-01 through CR-16 remediation. The review attempts to find remaining decisions that a developer would have to invent while coding P1-P9, especially around Dart compile order, command ownership, Drift constraints, SQLite concurrency, transaction scope, legacy routing coexistence, typed profile/fact models, migration order and executable tests.

Pass criterion:

```text
open BLOCKER code-design findings = 0
open HIGH code-design findings = 0
P1 code implementation = AUTHORIZED
```

Runtime correctness is not claimed here. Each implementation phase must still earn its own exact-SHA gate.

## 2. Authority set reviewed

The re-review checks:

1. `elv3-code-remediation-final-clarifications.md`;
2. `elv3-code-implementation-remediation-cr01-cr16.md`;
3. `elv3-code-contract-p1-p3.md`;
4. `elv3-code-contract-p4-p6.md`;
5. `elv3-code-contract-p7-p9.md`;
6. dual-review/R2/domain authority chain;
7. current repository code conventions and schema version 17.

Where old code-contract wording conflicts with remediation, remediation wins.

## 3. CR-01 — compile-order/resource ownership

**PASS / CLOSED.**

P1 now owns immutable reference-data resource types in:

```text
elv_cable_resource_definition.dart
```

P2 owns runtime selection/resolution only in:

```text
elv_cable_resource_selection.dart
```

`CableDefinition` can therefore compile and validate in P1 without depending on P2. Resource graph publication validation is exact: unique normalized identities, reserved WHOLE_CABLE identity, reciprocal parent/child relations, acyclicity and atomic/composite rules.

No transitional duplicate type remains allowed.

## 4. CR-02 — orchestration ownership

**PASS / CLOSED.**

One application pattern is frozen:

```text
UI/controller
 -> Elv*CommandService
 -> phase-specific ElvWriteUnitOfWork
 -> transaction-bound write/read stores
```

Repository ports are query/persistence abstractions and no longer alternate command use-case owners.

A developer cannot conform while choosing repository-owned orchestration in one phase and service-owned orchestration in another.

## 5. CR-03 — durable command ledger

**PASS / CLOSED.**

`CommandExecutionRecords` exact columns, primary key, payload hash and result codec responsibilities are frozen.

Idempotency identity is:

```text
(projectId, commandId)
```

Replay compares canonical payload SHA-256. SUCCESS and deterministic REJECTED semantic outcomes may be persisted; transaction/storage/failure-injection failures are not persisted as committed outcomes.

The same command id/payload after restart returns the committed logical outcome. Changed payload returns `ELV_IDEMPOTENCY_CONFLICT`.

## 6. CR-04 — DB backstops

**PASS / CLOSED.**

The specification now requires database-enforced uniqueness for all critical concurrency invariants:

```text
active Cable label/project
consuming allocation/EngineeringConnection
active CanonicalCableRun/(Cable,DesignRevision)
one WORKING design revision/project
one ACTIVE P5 profile set/project
resource claim key
```

Constraint names map to stable domain failure codes. Application pre-checks are explicitly non-authoritative under concurrency.

## 7. CR-05 — transaction primitive/UoW

**PASS / CLOSED.**

The earlier pseudo `BEGIN IMMEDIATE` is no longer an unspecified implementation requirement.

Correctness contract is:

```text
one Drift transaction
+ transaction-bound phase session/stores
+ FKs
+ partial unique indexes
+ conditional expectedRevision updates
```

Phase-specific sessions prevent P1 from importing/declaring P2-P5 write stores. No logical command may split writes across independent transactions.

## 8. CR-06 — concurrency test topology

**PASS / CLOSED.**

Concurrency acceptance requires two independent `AppDatabase` instances over one temporary on-disk SQLite file, followed by reopen verification from a third connection.

Required races cover P1 label uniqueness, P2 allocation/resource claims, P3 WORKING/ACTIVE-run uniqueness and P5 active profile set uniqueness.

A one-connection `Future.wait` test no longer qualifies as evidence.

## 9. CR-07 — reusable route + legacy electrical coexistence

**PASS / CLOSED.**

This was the previous BLOCKER.

`EditReusableRouteGeometry` impact is now a tagged union of:

```text
CanonicalElvRunImpact
LegacyElectricalRunImpact
```

Impact fingerprint includes both sets. Commit revalidates all canonical traversal chains and every affected legacy electrical run using the currently shipped legacy `CableRouteValidator`/`RoutingJunctionValidator` behavior through an adapter.

A route shared by ELV and electrical is mandatory regression coverage. If either side becomes invalid, the entire geometry mutation is rejected.

The reuse of one routing graph is therefore compatible with legacy coexistence at implementation level.

## 10. CR-08 — freeze snapshot transaction ownership

**PASS / CLOSED.**

Snapshot construction is split into:

```text
pure ElvPhysicalSnapshotAssembler
transaction-bound Drift design-revision command store
```

All source rows used for a freeze are read inside the same transaction that persists the snapshot, changes revision state and writes the command ledger outcome.

No async repository fetch on another connection is allowed during snapshot construction.

## 11. CR-09 — carrier fact typing

**PASS / CLOSED.**

Canonical P4 state uses typed:

```text
CarrierEnvironmentFacts
CarrierInstallationFacts
CarrierTemperatureRange
CarrierEnclosureExposure
MaintenanceAccessibility
```

Open `Map<String,Object?>` is no longer canonical domain state. JSON remains only a versioned persistence codec.

## 12. CR-10 — P5 rule model

**PASS / CLOSED.**

P5 v1 now has a sealed rule hierarchy with exact discriminators and typed payloads:

```text
AllowedCableClassRule
AllowedCarrierKindRule
AllowedInstallationClassRule
AllowedEnvironmentClassRule
MaximumCableDiameterRule
MinimumCarrierUsableAreaRule
DirectIntrinsicProhibitionRule
```

Unknown rule kinds are rejected as unsupported schema. Combination semantics are deterministic by rule category.

Bend minimum remains CableDefinition intrinsic data and is not duplicated into P5 rule state.

## 13. CR-11 — separation evidence

**PASS / CLOSED.**

P6 v1 no longer leaves the geometric separation algorithm to implementation.

Numeric separation exists only through typed `RouteSeparationEvidence` and canonical `RouteSeparationEvidenceRecords` persistence. Missing evidence yields `ELV_SEPARATION_EVIDENCE_MISSING`/BLOCKED when numeric distance is required.

One ACTIVE evidence row per canonical subject pair/design revision is DB-enforced. P6 schema version therefore advances to 23.

No developer may invent a general 3D distance algorithm in P6 v1.

## 14. CR-12 — DRAFT termination flow

**PASS / CLOSED.**

DRAFT has no persisted resource selection and no persisted termination mappings. UI may stage a candidate only in memory.

RESERVED/ACTIVE may persist mappings through full-set replacement. RELEASED/ARCHIVED retain evidence and are not ordinarily editable.

This now matches P2 selection lifecycle and P7 workspace progression.

## 15. CR-13 — CreateCableRun prerequisite

**PASS / CLOSED.**

Create run requires:

```text
ACTIVE Cable
WORKING ProjectDesignRevision
editingAllowed
>=1 RESERVED or ACTIVE allocation for Cable
no competing ACTIVE run for same Cable/revision
```

A bare project Cable cannot enter canonical routing without logical physical-realization evidence.

## 16. CR-14 — command result/failure envelope

**PASS / CLOSED.**

All ELV3 P1-P9 commands use:

```text
ElvCommandResult<T>
ElvCommandSuccess<T>
ElvCommandFailureResult<T>
ElvFailure
ElvFailureCategory
```

Stable error ordering remains defined by process hardening. Existing non-ELV3 placement error types do not need migration.

## 17. CR-15 — migrations

**PASS / CLOSED.**

Current pre-P1 baseline is schema 17. Frozen logical sequence:

```text
P1 -> 18
P2 -> 19
P3 -> 20
P4 -> 21
P5 -> 22
P6 -> 23
P7-P9 -> no schema bump by default
```

If another branch advance changes the current schema before a phase starts, only numeric rebasing is allowed; table ownership/order remains fixed and the gate records the rebase.

## 18. CR-16 — downstream Cable dependency inspection

**PASS / CLOSED.**

The exact `ElvCableDependencyInspector` application port is frozen and evolves through adapters as P2/P3 schema appears without changing `ElvCableCommandService` API.

Definition change is permanently blocked once resource-selection or canonical-run history exists.

## 19. New findings discovered during remediation self-review

Two possible ambiguities were found before this re-review and closed in `elv3-code-remediation-final-clarifications.md`:

### FC-01 phase-specific UoW sessions

A monolithic write session would have forced P1 to define future-phase stores. It is replaced by generic ledger scope + phase-specific sessions.

**State: CLOSED.**

### FC-03 P6 separation persistence

The first remediation wording allowed separation evidence to be either persisted or merely supplied. This was incompatible with deterministic implementation. P6 now always owns canonical `RouteSeparationEvidenceRecords` and schema version 23.

**State: CLOSED.**

Additional ledger/resource-validation/legacy-validator clarifications are also closed.

## 20. Compile-path review by phase

### P1

Can compile independently with:

```text
CableDefinition
CableResourceDefinition
TerminationPolicy
CableDefinitionRef
Cable
ElvCommandResult
ElvCableRepository
ElvCableCommandService
ElvCableDependencyInspector
ElvCableWriteUnitOfWork/session
ElvCables
CommandExecutionRecords
```

No P2/P3 table/type is required.

### P2

Adds runtime selection/allocation/termination types and allocation-specific write session. P1 immutable resource definitions are reused, not replaced.

### P3

Adds revision/routing/snapshot/coexistence. Shared route mutation explicitly validates current legacy routing.

### P4-P6

Typed carrier facts and sealed P5 rules remove open-map semantics. P6 has deterministic formula/evidence persistence and revision scope.

### P7-P9

Workspace and acceptance layers consume already-frozen command services/contracts; they do not invent persistence semantics.

## 21. Database/concurrency review

The required invariants now have all three levels:

```text
domain/application validation
DB constraint/conditional update
multi-connection SQLite acceptance test
```

This is sufficient specification for implementation to prove behavior rather than relying on a single-process pre-check.

## 22. Remaining implementation freedom

Only non-semantic choices remain:

```text
private helper/class split
exact supported Drift transaction API call
index creation helper organization
widget composition
performance indexes
fixture helper organization
migration number rebase if baseline advances
```

Such choices may not alter observable command/result/state/concurrency semantics.

## 23. Final re-review verdict

```text
architecture alignment                         PASS
process architecture                           PASS
code compile-order specification               PASS
command orchestration ownership                PASS
idempotency persistence                        PASS
DB invariant/concurrency contract               PASS
snapshot transaction contract                  PASS
legacy routing coexistence                     PASS
P4 typed fact contract                         PASS
P5 typed rule contract                         PASS
P6 evidence/calculation contract               PASS
migration/test contract                        PASS

CR-01..CR-16                                    CLOSED
new remediation ambiguities                     CLOSED
open BLOCKER code-design findings               0
open HIGH code-design findings                  0

P1 code implementation                          AUTHORIZED
ELV3 code-level specification                   READY FOR EXECUTION
```

P1 authorization is limited to P1. P2 remains gated on P1 exact-SHA CI and acceptance evidence, and the same sequential rule applies through P9.
