# Electra — ELV3 Code Implementation Remediation CR-01…CR-16

Status: AUTHORITATIVE CODE REMEDIATION / CLOSED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Parent review: `docs/audit/elv3-code-implementation-technical-review.md`

## 1. Purpose

Close every implementation-design finding CR-01 through CR-16 before P1 coding starts. This document overrides conflicting wording in earlier code-level contracts. It refines code structure only; accepted ELV3 domain architecture remains unchanged.

Pass condition:

```text
CR-01..CR-16 CLOSED
open BLOCKER code-design findings = 0
open HIGH code-design findings = 0
```

---

## 2. CR-01 CLOSED — cable resource definition belongs to P1

P1 owns immutable CableDefinition resource semantics.

Create in P1:

```text
packages/engineering_core/lib/src/elv_cable_resource_definition.dart
```

Public types:

```dart
enum CableResourceKind {
  wholeCable,
  pair,
  conductor,
  fiber,
  coreGroup,
  shield,
  drain,
  protectiveEarth,
  functionalEarth,
}

enum TerminationPolicyMode {
  bothEnds,
  aEndOnly,
  bEndOnly,
  optional,
  groupLevel,
}

final class TerminationPolicy {
  const TerminationPolicy({
    required this.mode,
    required this.terminalRequired,
    this.allowedRoles = const [],
  });

  final TerminationPolicyMode mode;
  final bool terminalRequired;
  final List<String> allowedRoles;
}

final class CableResourceDefinition {
  const CableResourceDefinition({
    required this.identity,
    required this.kind,
    required this.allocatable,
    required this.atomic,
    required this.terminationPolicy,
    this.parentResourceId,
    this.childResourceIds = const [],
    this.groupMembership = const [],
  });

  final String identity;
  final CableResourceKind kind;
  final bool allocatable;
  final bool atomic;
  final String? parentResourceId;
  final List<String> childResourceIds;
  final List<String> groupMembership;
  final TerminationPolicy terminationPolicy;
}
```

P1 validates uniqueness, graph references and acyclicity of `CableResourceDefinition` as part of `CableDefinition.validate()`.

P2 creates:

```text
packages/engineering_core/lib/src/elv_cable_resource_selection.dart
```

and owns only runtime selection/resolution:

```text
CableResourceSelection
WholeCableSelection
ResourceSetSelection
DefinitionGroupSelection
ResolvedCableResourceSelection
CableResourceResolver
```

No duplicate transitional resource-definition type is permitted.

---

## 3. CR-02 CLOSED — one command orchestration owner

ELV3 uses command services as the only application orchestration boundary.

Pattern:

```text
Widget/controller
  -> Elv*CommandService
      -> read/query ports
      -> ElvWriteUnitOfWork
          -> transaction-bound data primitives
```

Repositories do not expose high-level mutation use cases.

P1 port becomes:

```dart
abstract interface class ElvCableRepository {
  Future<List<Cable>> loadProjectCables(String projectId);
  Future<Cable?> findCable(String projectId, String cableId);
  Stream<List<Cable>> watchProjectCables(String projectId);
  Future<CableDefinition> resolveDefinition(
    String projectId,
    CableDefinitionRef ref,
  );
}
```

Command API:

```dart
abstract interface class ElvCableCommandService {
  Future<ElvCommandResult<Cable>> create(CreateCableCommand command);
  Future<ElvCommandResult<Cable>> changeDefinition(
    ChangeCableDefinitionRefCommand command,
  );
  Future<ElvCommandResult<Cable>> archive(ArchiveCableCommand command);
}
```

The same split is mandatory P2-P5: repository/query ports expose reads; command services own ordering and invoke one transaction-bound unit of work.

---

## 4. CR-03 CLOSED — exact durable command ledger

P1 creates `CommandExecutionRecords`.

Canonical Drift shape:

```dart
@DataClassName('CommandExecutionRecordRow')
class CommandExecutionRecords extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get commandId => text()();
  TextColumn get commandType => text()();
  IntColumn get payloadSchemaVersion => integer()();
  TextColumn get normalizedPayloadSha256 => text()();
  TextColumn get outcomeKind => text()();
  TextColumn get logicalResultJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get committedAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {projectId, commandId};
}
```

Stable outcome strings:

```text
SUCCESS
REJECTED
```

Only a committed logical outcome is persisted. Transaction/SQLite failures are never recorded as successful command outcomes.

Every replayable command declares:

```text
commandType
payloadSchemaVersion
payload schema marker
```

Normalized payload hash contract:

```text
canonical = {
  schema: <command payload schema marker>,
  commandType: <stable command type>,
  payload: <normalized semantic payload excluding commandId>
}
sha256 = SHA-256(UTF8(canonicalEngineeringJson(canonical)))
```

`logicalResultJson` uses a versioned logical-result codec and contains domain ids/revisions/state required for replay, never Drift row JSON or exception text.

Ledger insert and domain writes commit atomically in the same SQLite transaction.

---

## 5. CR-04 CLOSED — DB-enforced critical invariants

`_createIndexes()` MUST create these partial unique indexes using actual generated SQL table names:

```sql
CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_cable_active_label
ON elv_cables(project_id, normalized_label)
WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_alloc_consuming_connection
ON cable_allocations(engineering_connection_id)
WHERE lifecycle_state IN ('RESERVED', 'ACTIVE') AND deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_run_active_cable_revision
ON canonical_cable_runs(cable_id, design_revision_id)
WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_design_revision_working
ON project_design_revisions(project_id)
WHERE state = 'WORKING' AND deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_profile_set_active
ON project_physical_compatibility_profile_sets(project_id)
WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL;
```

Additionally:

```text
CableRunTraversals UNIQUE(cable_run_id, sequence)
PhysicalCarrierCompartments UNIQUE active(carrier_id, normalized_code)
PhysicalCarrierCompartments UNIQUE active(carrier_id, sequence)
CableTerminationMappings UNIQUE(allocation_id, resource_identity, end_role)
CableResourceClaims UNIQUE(claim_key)
```

Stable translation:

```text
ux_elv_cable_active_label          -> ELV_CABLE_LABEL_CONFLICT
ux_elv_alloc_consuming_connection  -> ELV_ALLOC_CONNECTION_CONFLICT
ux_elv_run_active_cable_revision   -> ELV_RUN_ACTIVE_CONFLICT
ux_elv_design_revision_working     -> ELV_REVISION_WORKING_CONFLICT
ux_elv_profile_set_active          -> ELV_PROFILE_SET_ACTIVE_CONFLICT
CableResourceClaims.claim_key      -> ELV_ALLOC_RESOURCE_CONFLICT
```

Application pre-checks remain UX/early validation only; DB constraints are the concurrency backstop.

---

## 6. CR-05 CLOSED — concrete Drift write-unit-of-work boundary

Application contract:

```dart
abstract interface class ElvWriteUnitOfWork {
  Future<T> run<T>(Future<T> Function(ElvWriteSession session) action);
}

abstract interface class ElvWriteSession {
  ElvCommandLedgerStore get commandLedger;
  ElvCableWriteStore get cables;
  ElvAllocationWriteStore get allocations;
  ElvDesignRevisionWriteStore get designRevisions;
  ElvRoutingWriteStore get routing;
  ElvCarrierWriteStore get carriers;
  ElvProfileSetWriteStore get profileSets;
}
```

Concrete data implementation:

```text
DriftElvWriteUnitOfWork
```

owns one Drift `AppDatabase.transaction(...)` boundary and supplies transaction-bound stores backed by the same transaction/executor.

No service may open nested independent transactions for one logical command.

`BEGIN IMMEDIATE` in older pseudocode is semantic shorthand only. Implementation correctness must not depend on undocumented Drift locking mode; it relies on:

```text
partial unique indexes
foreign keys
expectedRevision conditional UPDATE
atomic transaction
```

If the concrete Drift version exposes a supported immediate transaction mode, it may be used and documented, but it is not part of domain correctness.

Expected revision updates use affected-row checks, conceptually:

```sql
UPDATE ...
SET revision = revision + 1, ...
WHERE id = ? AND project_id = ? AND revision = ?;
```

zero affected rows -> `ELV_REVISION_CONFLICT`.

---

## 7. CR-06 CLOSED — real two-connection SQLite concurrency tests

Required helper:

```text
apps/mobile/test/support/elv_concurrent_database.dart
```

Test topology:

```text
temporary on-disk SQLite file
  -> AppDatabase connection A
  -> AppDatabase connection B
```

Both enable foreign keys and use production journal/transaction configuration.

Required races:

```text
P1 same active normalized cable label
P2 two consuming allocations for same EngineeringConnection
P2 overlapping CableResourceClaims
P3 two WORKING revisions for same project
P3 two ACTIVE runs for same (cable, designRevision)
P5 two ACTIVE profile sets for same project
```

Test algorithm:

```text
seed baseline
synchronize two command starts with barrier/latches
execute through two independent AppDatabase instances
assert exactly one succeeds where uniqueness applies
assert loser receives stable domain conflict code
close both
open connection C
verify exactly one canonical winner and no partial loser state
```

A same-connection `Future.wait` test is insufficient as concurrency evidence.

---

## 8. CR-07 CLOSED — shared route impact covers ELV + legacy electrical

Create code-level tagged dependent model:

```dart
sealed class RouteImpactDependent {
  const RouteImpactDependent();
}

final class CanonicalElvRunImpact extends RouteImpactDependent {
  final String runId;
  final int revision;
}

final class LegacyElectricalRunImpact extends RouteImpactDependent {
  final String runId;
  final String circuitId;
  final String routeId;
  final int revision;
}
```

Preview for `EditReusableRouteGeometryCommand` includes:

1. canonical ELV runs referencing any affected route segment through `CableRunTraversals`;
2. every legacy electrical `CableRuns` row whose `routeId` is the edited route.

Fingerprint canonical payload contains tagged sorted identities/revisions for both sets.

Commit transaction:

```text
load current route expected revision
recompute complete canonical + legacy impact set
compare expectedImpactFingerprint
validate candidate route geometry
validate every canonical traversal chain
validate every legacy CableRun/route using current CableRouteValidator and legacy active-circuit/junction invariants where applicable
if any failure -> reject all
persist route/node/segment geometry atomically
invalidate canonical ELV dependency keys
preserve/recalculate legacy electrical dependent state according to existing routing flow
command ledger record
commit
```

Mandatory test fixture uses one `CableRoute` referenced by both:

```text
CanonicalCableRun traversal
Legacy electrical CableRun.routeId
```

A candidate breaking either side must not commit.

---

## 9. CR-08 CLOSED — pure snapshot assembler + transaction coordinator

Core/application pure assembler:

```dart
abstract interface class ElvPhysicalSnapshotAssembler {
  DesignRevisionPhysicalSnapshot assemble(PhysicalSnapshotInput input);
}
```

It has no repository access and no `Future`.

Data-layer transaction coordinator:

```text
DriftElvDesignRevisionCommandStore
```

Freeze command transaction performs:

```text
idempotency check
load WORKING revision expected revision
load every P1-P3 snapshot input row through same transaction-bound session
materialize immutable PhysicalSnapshotInput
assemble snapshot
validate snapshot
compute canonical hash
insert DesignRevisionPhysicalSnapshot
update revision WORKING -> FROZEN using expected revision
insert CommandExecutionRecord
commit
```

No snapshot input read may occur through a repository using another database connection.

Later phase snapshot readers/builders extend the materialized input by schema version; they never backfill old frozen snapshots.

---

## 10. CR-09 CLOSED — typed carrier facts

Replace canonical open maps with typed objects.

```dart
final class CarrierTemperatureRange {
  const CarrierTemperatureRange({required this.minC, required this.maxC});
  final double minC;
  final double maxC;
}

enum CarrierEnclosureExposure { open, enclosed, embedded }
enum MaintenanceAccessibility { unrestricted, restricted, inaccessible }

final class CarrierEnvironmentFacts {
  const CarrierEnvironmentFacts({
    this.exposureClassCode,
    this.moistureClassCode,
    this.contaminationClassCode,
    this.climateClassCode,
    this.temperatureRange,
    this.fireZoneRef,
  });

  final String? exposureClassCode;
  final String? moistureClassCode;
  final String? contaminationClassCode;
  final String? climateClassCode;
  final CarrierTemperatureRange? temperatureRange;
  final String? fireZoneRef;
}

final class CarrierInstallationFacts {
  const CarrierInstallationFacts({
    this.installationClassCode,
    this.enclosureExposure,
    this.supportMethodCode,
    this.maintenanceAccessibility,
    this.penetrationRef,
  });

  final String? installationClassCode;
  final CarrierEnclosureExposure? enclosureExposure;
  final String? supportMethodCode;
  final MaintenanceAccessibility? maintenanceAccessibility;
  final String? penetrationRef;
}
```

All numeric values validate finite/range ordering. Reference codes normalize through ELV2 accepted vocabulary. Persistence remains versioned canonical JSON:

```text
environment_facts_json schema = electra.carrier-environment-facts.v1
installation_facts_json schema = electra.carrier-installation-facts.v1
```

No arbitrary user key may become canonical P4 fact.

---

## 11. CR-10 CLOSED — exact P5 sealed rule hierarchy

P5 v1 rules:

```dart
sealed class PhysicalCompatibilityRule {
  String get ruleCode;
  PhysicalCompatibilityRuleKind get kind;
  List<String> validate();
  Map<String, Object?> toMap();
}

enum PhysicalCompatibilityRuleKind {
  allowedCableClass,
  allowedCarrierKind,
  allowedInstallationClass,
  allowedEnvironmentClass,
  maximumCableDiameter,
  minimumCarrierUsableArea,
  directIntrinsicProhibition,
}
```

Concrete rules:

```text
AllowedCableClassRule
  allowedClassCodes: Set<String>

AllowedCarrierKindRule
  allowedKinds: Set<PhysicalCarrierKind>

AllowedInstallationClassRule
  allowedClassCodes: Set<String>

AllowedEnvironmentClassRule
  allowedClassCodes: Set<String>

MaximumCableDiameterRule
  maxDiameterMm: double

MinimumCarrierUsableAreaRule
  minimumUsableAreaMm2: double

DirectIntrinsicProhibitionRule
  subjectTypeCode
  subjectValueCode
  reasonCode
```

`PhysicalCompatibilityProfile` contains `List<PhysicalCompatibilityRule>` only; no generic rule map.

Canonical codec uses discriminator `kind` and rejects unknown v1 rule kinds as unsupported profile schema rather than silently ignoring them.

Combination categories:

```text
allowed sets           -> intersection
maximum numeric limit  -> minimum of maxima
minimum numeric limit  -> maximum of minima
direct prohibition     -> union; any applicable prohibition blocks
```

`minimumBendRadiusMm` remains CableDefinition intrinsic data checked against RouteBendEvidence; it is not duplicated as a P5 profile rule in v1.

---

## 12. CR-11 CLOSED — P6 v1 separation uses explicit evidence

P6 v1 does not infer arbitrary 3D route-to-route distance.

Create:

```dart
enum RouteSeparationEvidenceKind {
  measured,
  designedDimension,
  surveyed,
}

final class RouteSeparationEvidence {
  const RouteSeparationEvidence({
    required this.id,
    required this.projectId,
    required this.designRevisionId,
    required this.subjectA,
    required this.subjectB,
    required this.distanceMm,
    required this.evidenceKind,
    this.sourceRef,
  });

  final String id;
  final String projectId;
  final String designRevisionId;
  final String subjectA;
  final String subjectB;
  final double distanceMm;
  final RouteSeparationEvidenceKind evidenceKind;
  final String? sourceRef;
}
```

`distanceMm` must be finite and >= 0.

P6 segregation evidence returns:

```text
sameCarrier
sameCompartment
barrierPresent
explicitSeparationDistanceMm?
separationEvidenceId?
```

If numeric distance is required by a caller and no explicit evidence exists:

```text
state = BLOCKED
blockingCode = ELV_SEPARATION_EVIDENCE_MISSING
```

No general minimum-segment-distance algorithm exists in P6 v1.

Initial persistence: RouteSeparationEvidence is revision-owned canonical evidence and is introduced in P6 only if persisted UI capture is implemented in P6. If P6 remains calculation-only, evidence may be supplied through the revision snapshot/input boundary. A future persisted table requires explicit P6 schema bump and P9 inventory; no hidden table is allowed.

---

## 13. CR-12 CLOSED — DRAFT termination is memory-only candidate

State rule:

```text
DRAFT
  no persisted CableAllocationResourceSelections
  no persisted CableTerminationMappings
  UI may hold temporary candidate objects only

RESERVED
  immutable selection evidence exists
  termination mappings may persist

ACTIVE
  required mappings complete
  replacement uses full-set atomic mutation

RELEASED/ARCHIVED
  mappings retained as historical evidence; no ordinary editing
```

`ReplaceCableTerminationSetCommand` requires allocation state `RESERVED` or `ACTIVE`.

Attempt in DRAFT returns:

```text
ELV_TERMINATION_SELECTION_NOT_RESERVED
```

---

## 14. CR-13 CLOSED — CreateCableRun prerequisite

`CreateCableRunCommand` preconditions:

```text
Cable.lifecycleState == ACTIVE
ProjectDesignRevision.state == WORKING
PhysicalDesignContext.editingAllowed == true
exists CableAllocation for cable with state in {RESERVED, ACTIVE}
no other ACTIVE CanonicalCableRun for (cableId, designRevisionId)
```

No allocation -> `ELV_RUN_ALLOCATION_REQUIRED`.

A RESERVED allocation permits route design before activation; RELEASED/ARCHIVED allocations do not satisfy the prerequisite.

---

## 15. CR-14 CLOSED — one ELV command result/failure model

Create in application common file:

```text
apps/mobile/lib/application/elv_command_result.dart
```

Contract:

```dart
sealed class ElvCommandResult<T> {
  const ElvCommandResult();
}

final class ElvCommandSuccess<T> extends ElvCommandResult<T> {
  const ElvCommandSuccess(this.value);
  final T value;
}

final class ElvCommandFailureResult<T> extends ElvCommandResult<T> {
  const ElvCommandFailureResult(this.failure);
  final ElvFailure failure;
}

enum ElvFailureCategory {
  command,
  notFound,
  projectIsolation,
  lifecycle,
  revisionConflict,
  referenceIntegrity,
  validation,
  dependencyImpact,
  storage,
}

final class ElvFailure {
  const ElvFailure({
    required this.code,
    required this.category,
    this.entityType,
    this.entityId,
    this.field,
    this.expectedRevision,
    this.actualRevision,
    this.details = const {},
  });

  final String code;
  final ElvFailureCategory category;
  final String? entityType;
  final String? entityId;
  final String? field;
  final int? expectedRevision;
  final int? actualRevision;
  final Map<String, Object?> details;
}
```

P1-P9 ELV3 commands use this envelope. Existing unrelated placement failure classes are not required to migrate in ELV3.

Failure primary ordering remains the authoritative ordering from dual-review hardening.

---

## 16. CR-15 CLOSED — migration baseline fixed

Current pre-P1 branch schemaVersion = 17.

Initial mapping:

```text
P1 schemaVersion 18
  ElvCables
  CommandExecutionRecords
  P1 indexes

P2 schemaVersion 19
  CableAllocations
  CableAllocationResourceSelections
  CableResourceClaims
  CableTerminationMappings
  P2 indexes

P3 schemaVersion 20
  ProjectDesignRevisions
  DesignRevisionPhysicalSnapshots
  CanonicalCableRuns
  CableRunTraversals
  RouteHandoffs
  RouteBendEvidence
  LegacyRouteAdoptions
  P3 indexes

P4 schemaVersion 21
  PathwayContexts
  PhysicalCarriers
  PhysicalCarrierCompartments
  P4 indexes

P5 schemaVersion 22
  ProjectPhysicalCompatibilityProfileSets
  ProjectPhysicalCompatibilityProfileRefs
  P5 indexes

P6+
  no bump by default
```

If `app_database.dart` advances before a phase begins, that phase rebases to the next available monotonic version. The phase gate records:

```text
plannedVersion
actualVersion
reasonForRebase
```

Table ownership/order cannot change during version rebase.

---

## 17. CR-16 CLOSED — exact Cable dependency inspector

Application port:

```dart
abstract interface class ElvCableDependencyInspector {
  Future<bool> hasResourceSelectionHistory(
    String projectId,
    String cableId,
  );

  Future<bool> hasConsumingAllocation(
    String projectId,
    String cableId,
  );

  Future<bool> hasCanonicalRunHistory(
    String projectId,
    String cableId,
  );

  Future<List<String>> blockingDependencyIds(
    String projectId,
    String cableId,
  );
}
```

P1 adapter:

```text
hasResourceSelectionHistory = false
hasConsumingAllocation = false
hasCanonicalRunHistory = false
blockingDependencyIds = []
```

because tables do not yet exist.

P2 adapter implements selection/allocation checks. P3 adapter additionally implements run-history checks. `ElvCableCommandService` constructor/API does not change.

Definition change rule:

```text
if hasResourceSelectionHistory == true -> permanently blocked
if hasCanonicalRunHistory == true -> permanently blocked
```

Archive rule uses `hasConsumingAllocation` and other active dependency ids according to lifecycle policy.

---

## 18. Required code-contract corrections after this remediation

Earlier code contracts are interpreted as follows:

```text
P1 resource file
  elv_cable_resource_definition.dart

P2 resource file
  elv_cable_resource_selection.dart

all mutation orchestration
  command service, never repository port

all ELV3 command results
  ElvCommandResult<T>

shared route geometry impact
  canonical ELV + legacy electrical dependents

carrier facts
  typed value objects, JSON only as codec

P5 profile rules
  sealed v1 hierarchy

P6 separation
  explicit evidence only in v1

DRAFT termination
  non-persistent candidate only
```

## 19. Remediation verification matrix

| Finding | Closure evidence | Status |
|---|---|---|
| CR-01 | P1/P2 resource type/file split frozen | CLOSED |
| CR-02 | command service is sole orchestrator | CLOSED |
| CR-03 | ledger columns/hash/result codec frozen | CLOSED |
| CR-04 | critical partial unique indexes frozen | CLOSED |
| CR-05 | `ElvWriteUnitOfWork` + transaction stores frozen | CLOSED |
| CR-06 | two-connection file-DB races mandatory | CLOSED |
| CR-07 | route impact includes legacy electrical runs | CLOSED |
| CR-08 | pure assembler + transaction-bound snapshot reads | CLOSED |
| CR-09 | typed carrier facts frozen | CLOSED |
| CR-10 | sealed P5 v1 rule hierarchy frozen | CLOSED |
| CR-11 | explicit separation evidence frozen | CLOSED |
| CR-12 | DRAFT termination memory-only | CLOSED |
| CR-13 | CreateCableRun allocation prerequisite frozen | CLOSED |
| CR-14 | common ELV result/failure envelope frozen | CLOSED |
| CR-15 | schema 18→22 baseline frozen | CLOSED |
| CR-16 | dependency inspector port frozen | CLOSED |

## 20. Exit condition

This document closes design remediation only. A fresh code-implementation technical review must independently verify the corrected authority set before P1 authorization is restored.
