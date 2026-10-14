# Electra — ELV3 Code-Level Implementation Contract P1–P3

Status: AUTHORITATIVE CODE DESIGN / P1–P3  
Branch: `feat/flutter-elv3-physical-routing-design`  
Parent authority: `docs/product/elv3-dual-review-process-hardening.md`

## 1. Purpose

This document translates the accepted ELV3 specification into code-level contracts for P1–P3. It does not implement code. It freezes public type names, layer boundaries, repository ports, command inputs/results, persistence ownership, transaction shape, migration order and mandatory test locations so implementation is mechanical rather than architectural.

Current project conventions that MUST be reused:

- pure domain in `packages/engineering_core/lib/src`;
- public domain exports through `packages/engineering_core/lib/engineering_core.dart`;
- application ports/commands in `apps/mobile/lib/application`;
- Drift adapters in `apps/mobile/lib/data/repositories`;
- tables and migration ordering in `apps/mobile/lib/data/database/app_database.dart`;
- UUID v7 through existing `IdGenerator`;
- canonical serialization through `canonicalEngineeringJson`;
- project-isolated repositories and explicit transactions;
- generated Drift code remains generated only.

---

# P1 — Cable identity + exact CableDefinitionRef

## 2. P1 exact source-file plan

Create:

```text
packages/engineering_core/lib/src/elv_cable_reference.dart
packages/engineering_core/lib/src/elv_cable.dart

apps/mobile/lib/application/elv_cable_command.dart
apps/mobile/lib/application/elv_cable_repository.dart
apps/mobile/lib/application/elv_cable_service.dart

apps/mobile/lib/data/repositories/drift_elv_cable_repository.dart
```

Modify:

```text
packages/engineering_core/lib/engineering_core.dart
packages/engineering_core/lib/src/engineering_reference_catalog.dart
apps/mobile/lib/data/database/app_database.dart
apps/mobile/lib/data/repositories/drift_engineering_reference_repository.dart
```

Tests:

```text
packages/engineering_core/test/elv_cable_reference_test.dart
packages/engineering_core/test/elv_cable_test.dart
apps/mobile/test/application/elv_cable_service_test.dart
apps/mobile/test/data/drift_elv_cable_repository_test.dart
apps/mobile/test/data/elv_p1_restart_test.dart
```

## 3. P1 domain API

### 3.1 `CableDefinitionRef`

```dart
final class CableDefinitionRef {
  const CableDefinitionRef({
    required this.catalogId,
    required this.catalogVersion,
    required this.definitionCode,
    required this.definitionContentHash,
  });

  final String catalogId;
  final String catalogVersion;
  final String definitionCode;
  final String definitionContentHash;

  CableDefinitionRef normalized();
  List<ElvCableFailure> validate();
  Map<String, Object?> toMap();
  factory CableDefinitionRef.fromMap(Map<String, dynamic> map);
}
```

Normalization:

```text
catalogId                 trim only
catalogVersion            trim only; exact edition identity
 definitionCode            trim + uppercase
definitionContentHash     trim + lowercase
```

Hash validation: exactly 64 lowercase hex characters.

### 3.2 `CableDefinition`

The implementation MUST use the C7 exact semantic shape from R2. Public constructor shape:

```dart
final class CableDefinition {
  CableDefinition({
    required this.code,
    required this.label,
    required this.mediaCode,
    required Iterable<CableResourceDefinition> resourceDefinitions,
    this.deprecated = false,
    this.categoryCode,
    this.conductorMaterialCode,
    this.shieldingCode,
    this.firePerformanceCode,
    Iterable<String> environmentClassCodes = const [],
    Iterable<String> installationClassCodes = const [],
    Iterable<String> technicalClassCodes = const [],
    this.conductorCount,
    this.pairCount,
    this.fiberCount,
    this.conductorCrossSectionMm2,
    this.characteristicImpedanceOhm,
    this.dcResistanceOhmPerKm,
    this.capacitanceNfPerKm,
    this.inductanceMhPerKm,
    this.voltageRatingV,
    this.outerDiameterMm,
    this.occupiedAreaMm2,
    this.minimumBendRadiusMm,
    this.maximumPullingForceN,
  });
}
```

`CableResourceDefinition` is declared in P2 but P1 may introduce its immutable reference-data type because it is part of `CableDefinition` payload. P1 MUST NOT introduce CableAllocation persistence.

### 3.3 Canonical hash helper

Public helper:

```dart
String cableDefinitionContentHashV1(CableDefinition definition);
```

Implementation contract:

```text
canonical = {
  schema: "electra.cable-definition.v1",
  definition: definition.toMap()
}
bytes = UTF8(canonicalEngineeringJson(canonical))
SHA-256 -> lowercase hex
```

One shared SHA-256 helper SHOULD be extracted from existing placement fingerprint code into a reusable internal engineering utility; duplication of independent SHA-256 implementations is prohibited.

### 3.4 `Cable`

```dart
enum CableLifecycleState { active, archived }

final class Cable {
  const Cable({
    required this.id,
    required this.projectId,
    required this.label,
    required this.name,
    required this.definitionRef,
    required this.lifecycleState,
    required this.revision,
  });

  final String id;
  final String projectId;
  final String label;
  final String name;
  final CableDefinitionRef definitionRef;
  final CableLifecycleState lifecycleState;
  final int revision;

  String get normalizedLabel => label.trim().toUpperCase();
  List<ElvCableFailure> validate();
}
```

No `roomId`, `floorId`, `circuitId`, `routeId`, `totalLength` fields.

## 4. ELV2 catalog code changes in P1

`EngineeringReferenceCatalog` retains the existing persisted JSON key `profiles` exactly.

Add:

```dart
final List<CableDefinition> cableDefinitions;
```

Reader:

```dart
cableDefinitions =
  (map['cableDefinitions'] as List? ?? const [])
    .map((e) => CableDefinition.fromMap(e as Map<String, dynamic>))
    .toList();
```

Writer emits `cableDefinitions` only when non-empty or consistently emits `[]`; whichever convention is chosen MUST be covered by byte-semantic compatibility tests for pre-P1 component-only catalogs.

P1 MUST NOT add `physicalCompatibilityProfiles`.

Required catalog API:

```dart
CableDefinition cableDefinition(String rawCode);
CableDefinitionRef cableDefinitionRef(String rawCode);
```

`cableDefinitionRef` computes the content hash from this exact catalog edition.

Publication validation after P1:

```text
valid publication payload if:
profiles.isNotEmpty || cableDefinitions.isNotEmpty
```

Existing profile validation remains unchanged.

## 5. P1 application command API

```dart
final class CreateCableCommand {
  const CreateCableCommand({
    required this.commandId,
    required this.projectId,
    required this.cableId,
    required this.label,
    required this.name,
    required this.definitionRef,
  });
}

final class ChangeCableDefinitionRefCommand {
  const ChangeCableDefinitionRefCommand({
    required this.commandId,
    required this.projectId,
    required this.cableId,
    required this.expectedRevision,
    required this.definitionRef,
  });
}

final class ArchiveCableCommand {
  const ArchiveCableCommand({
    required this.commandId,
    required this.projectId,
    required this.cableId,
    required this.expectedRevision,
  });
}
```

Result:

```dart
sealed class ElvCableCommandResult {}
final class ElvCableSuccess<T> extends ElvCableCommandResult { ... }
final class ElvCableRejected extends ElvCableCommandResult {
  final ElvCableFailure failure;
}
```

Failure codes MUST be a typed enum/string mapping stable for UI/tests.

## 6. P1 repository port

```dart
abstract interface class ElvCableRepository {
  Future<List<Cable>> loadProjectCables(String projectId);
  Future<Cable?> findCable(String projectId, String cableId);
  Stream<List<Cable>> watchProjectCables(String projectId);

  Future<CableDefinition> resolveDefinition(
    String projectId,
    CableDefinitionRef ref,
  );

  Future<ElvCableCommandResult> create(CreateCableCommand command);
  Future<ElvCableCommandResult> changeDefinition(
    ChangeCableDefinitionRefCommand command,
  );
  Future<ElvCableCommandResult> archive(ArchiveCableCommand command);
}
```

UI MUST use `ElvCableService`, not call Drift repository directly.

## 7. P1 Drift table

```dart
@DataClassName('ElvCableRow')
class ElvCables extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get label => text()();
  TextColumn get normalizedLabel => text()();
  TextColumn get name => text()();
  TextColumn get definitionCatalogId =>
      text().references(EngineeringReferenceCatalogs, #id)();
  TextColumn get definitionCatalogVersion => text()();
  TextColumn get definitionCode => text()();
  TextColumn get definitionContentHash => text()();
  TextColumn get lifecycleState => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

Use table name `ElvCables` in Dart to avoid ambiguity with future electrical/general names. Domain type remains `Cable`.

Required indexes/constraints:

```text
index(project_id)
index(definition_catalog_id)
partial uniqueness or transactionally equivalent:
  project_id + normalized_label where deleted/archived is not active
```

Because Drift declarative partial indexes may be awkward, `_createIndexes()` may use explicit SQL. Observable uniqueness is mandatory.

`lifecycle_state=ARCHIVED` and `deleted_at` MUST NOT be two competing lifecycle sources. For ELV3 use `lifecycle_state` as business lifecycle; `deleted_at` is reserved for technical soft-deletion only and normally remains null.

## 8. P1 transaction pseudocode

### Create

```text
BEGIN IMMEDIATE
  validate command envelope
  find CommandExecutionRecord(projectId, commandId)
    same fingerprint -> return stored logical result
    different fingerprint -> reject
  assert Project exists
  resolve exact EngineeringReferenceCatalog same project
  assert edition/version/hash
  assert normalized label unique among ACTIVE cables
  INSERT ElvCables revision=1 ACTIVE
  INSERT CommandExecutionRecord
COMMIT
```

### Change definition

P1 allows only while no P2 selection evidence and no P3 run exist. Repository must call dependency probes even before those phases exist through interfaces that initially return false.

After P2, existence of any `CableAllocationResourceSelections` for this Cable permanently blocks in-place definition change.

### Archive

P1 archive checks no active downstream dependency. P2/P3 extend the dependency probe without changing P1 command signature.

---

# P2 — CableAllocation / resource claims / termination

## 9. P2 exact source-file plan

Create core:

```text
packages/engineering_core/lib/src/elv_cable_resource.dart
packages/engineering_core/lib/src/elv_cable_allocation.dart
packages/engineering_core/lib/src/elv_cable_termination.dart
```

Create application:

```text
apps/mobile/lib/application/elv_cable_allocation_command.dart
apps/mobile/lib/application/elv_cable_allocation_repository.dart
apps/mobile/lib/application/elv_cable_allocation_service.dart
```

Create data:

```text
apps/mobile/lib/data/repositories/drift_elv_cable_allocation_repository.dart
```

Tests:

```text
packages/engineering_core/test/elv_cable_resource_test.dart
packages/engineering_core/test/elv_cable_termination_test.dart
apps/mobile/test/application/elv_cable_allocation_service_test.dart
apps/mobile/test/data/elv_cable_allocation_concurrency_test.dart
apps/mobile/test/data/elv_p2_restart_test.dart
```

## 10. P2 core types

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
  final TerminationPolicyMode mode;
  final bool terminalRequired;
  final List<String> allowedRoles;
}

final class CableResourceDefinition {
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

Resolver:

```dart
abstract final class CableResourceResolver {
  static ResolvedCableResourceSelection resolve({
    required CableDefinition definition,
    required CableResourceSelection selection,
  });
}
```

Must validate finite/acyclic graph once per definition and return sorted immutable atom ids.

Selections:

```dart
sealed class CableResourceSelection {}
final class WholeCableSelection extends CableResourceSelection {}
final class ResourceSetSelection extends CableResourceSelection {
  final List<String> resourceIdentities;
}
final class DefinitionGroupSelection extends CableResourceSelection {
  final String groupIdentity;
}
```

## 11. P2 allocation types

```dart
enum CableAllocationState { draft, reserved, active, released, archived }

enum CableTerminationEnd { a, b }

final class CableAllocation {
  final String id;
  final String projectId;
  final String engineeringConnectionId;
  final String cableId;
  final CableAllocationState state;
  final int revision;
}

final class CableAllocationResourceSelectionEvidence {
  final String allocationId;
  final CableDefinitionRef cableDefinitionRef;
  final CableResourceSelection selection;
  final List<String> resolvedAtoms;
  final String selectionSha256;
}

final class CableTerminationMapping {
  final String id;
  final String allocationId;
  final String resourceIdentity;
  final CableTerminationEnd end;
  final String endpointPortId;
  final String? endpointTerminalRef;
  final String? terminationRole;
}
```

## 12. P2 command API

Exact commands:

```text
CreateCableAllocationDraftCommand
ReserveCableResourcesCommand
ActivateCableAllocationCommand
ReleaseCableResourcesCommand
ArchiveCableAllocationCommand
ReplaceCableTerminationSetCommand
```

Do NOT expose `BindCableTermination` as the primary service API for ACTIVE allocation. A draft/reserved UI editor may build an in-memory candidate set; repository persistence uses full-set replacement.

`ReplaceCableTerminationSetCommand` contains:

```dart
commandId
projectId
allocationId
expectedRevision
List<CableTerminationMappingInput> completeMappings
```

The complete set is validated before any row mutation.

## 13. P2 persistence tables

```text
CableAllocations
CableAllocationResourceSelections
CableResourceClaims
CableTerminationMappings
```

Recommended Drift shapes:

```dart
class CableAllocations extends Table with GeometryAuditColumns {
  id PK
  projectId FK
  engineeringConnectionId FK -> EngineeringPortConnections.id
  cableId FK -> ElvCables.id
  lifecycleState
}
```

`CableAllocationResourceSelections`:

```text
allocation_id PK/FK
selection_json
resolved_atoms_json
selection_sha256
created_at
origin_device_id
```

Immutable after insert.

`CableResourceClaims`:

```text
allocation_id FK
cable_id FK
resource_atom
claim_key
PRIMARY KEY(allocation_id, resource_atom)
UNIQUE(claim_key)
```

Only RESERVED/ACTIVE have rows.

`CableTerminationMappings`:

```text
id PK
allocation_id FK
resource_identity
end_role
endpoint_port_id FK -> EngineeringPortInstances.id
endpoint_terminal_ref nullable
termination_role nullable
revision/audit
UNIQUE(allocation_id, resource_identity, end_role)
```

## 14. P2 reserve transaction

```text
BEGIN IMMEDIATE
  idempotency check
  load DRAFT allocation expected revision
  load EngineeringPortConnection + endpoints
  load Cable + exact CableDefinitionRef
  enforce same project
  reject another RESERVED/ACTIVE allocation for same connection
  resolve selection -> atoms
  build selection evidence hash
  check WHOLE_CABLE mutual exclusion
  INSERT immutable selection evidence
  INSERT claim rows one by one under UNIQUE(claim_key)
  UPDATE allocation DRAFT -> RESERVED, revision++
  INSERT command execution record
COMMIT
```

Any UNIQUE violation maps to deterministic resource-overlap code, not raw SQLite exception.

## 15. P2 activation transaction

```text
BEGIN IMMEDIATE
  load RESERVED allocation expected revision
  load immutable selection evidence
  load exact definition from evidence definitionRef
  derive termination obligations
  load complete mappings
  validate exact A/B endpoints against EngineeringPortConnection
  validate terminal-required semantics
  UPDATE RESERVED -> ACTIVE
  command record
COMMIT
```

No claim rewrite on activation.

## 16. P2 release transaction

```text
BEGIN IMMEDIATE
  load RESERVED|ACTIVE allocation expected revision
  DELETE CableResourceClaims for allocation
  UPDATE allocation -> RELEASED
  retain selection evidence
  retain termination mappings
  command record
COMMIT
```

Release is forward-history operation, not UI undo.

---

# P3 — ProjectDesignRevision / canonical runs / traversal

## 17. P3 exact source-file plan

Core:

```text
packages/engineering_core/lib/src/elv_design_revision.dart
packages/engineering_core/lib/src/elv_cable_run.dart
packages/engineering_core/lib/src/elv_route_handoff.dart
packages/engineering_core/lib/src/elv_route_bend_evidence.dart
packages/engineering_core/lib/src/elv_physical_snapshot.dart
```

Application:

```text
apps/mobile/lib/application/elv_design_revision_command.dart
apps/mobile/lib/application/elv_design_revision_repository.dart
apps/mobile/lib/application/elv_physical_design_context.dart
apps/mobile/lib/application/elv_cable_run_command.dart
apps/mobile/lib/application/elv_cable_run_repository.dart
apps/mobile/lib/application/elv_route_geometry_command.dart
apps/mobile/lib/application/elv_legacy_route_adoption.dart
```

Data:

```text
apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart
apps/mobile/lib/data/repositories/drift_elv_cable_run_repository.dart
apps/mobile/lib/data/repositories/drift_elv_route_geometry_repository.dart
apps/mobile/lib/data/repositories/drift_elv_legacy_route_adapter.dart
```

Tests:

```text
packages/engineering_core/test/elv_cable_run_test.dart
packages/engineering_core/test/elv_route_handoff_test.dart
packages/engineering_core/test/elv_physical_snapshot_test.dart
apps/mobile/test/data/elv_design_revision_concurrency_test.dart
apps/mobile/test/data/elv_route_fanout_test.dart
apps/mobile/test/data/elv_p3_restart_test.dart
apps/mobile/test/data/elv_legacy_routing_regression_test.dart
```

## 18. P3 design revision types

```dart
enum ProjectDesignRevisionState { working, frozen, superseded, archived }

final class ProjectDesignRevision {
  final String id;
  final String projectId;
  final String code;
  final int sequence;
  final ProjectDesignRevisionState state;
  final String? basedOnRevisionId;
  final int revision;
}

final class PhysicalDesignContext {
  final String projectId;
  final String? workingDesignRevisionId;
  final String? latestFrozenRevisionId;
  final bool editingAllowed;
}
```

Repository:

```dart
abstract interface class ElvDesignRevisionRepository {
  Future<PhysicalDesignContext> context(String projectId);
  Future<ProjectDesignRevision> bootstrap(BootstrapProjectDesignRevisionCommand c);
  Future<ProjectDesignRevision> freeze(FreezeProjectDesignRevisionCommand c);
  Future<ProjectDesignRevision> createNext(CreateNextWorkingDesignRevisionCommand c);
  Future<ProjectDesignRevision> supersede(SupersedeProjectDesignRevisionCommand c);
  Future<ProjectDesignRevision> archive(ArchiveProjectDesignRevisionCommand c);
}
```

## 19. P3 canonical run types

```dart
enum CanonicalCableRunState { active, superseded, archived }
enum CableTraversalDirection { forward, reverse }

final class CanonicalCableRun {
  final String id;
  final String projectId;
  final String cableId;
  final String designRevisionId;
  final String? basedOnCableRunId;
  final CanonicalCableRunState state;
  final double reservePercent;
  final int terminationAllowanceMm;
  final int revision;
}

final class CableRunTraversal {
  final String id;
  final String cableRunId;
  final int sequence;
  final String routeSegmentId;
  final CableTraversalDirection direction;
  final String? physicalCarrierId;
  final String? carrierCompartmentId;
}
```

Traversal sequence MUST be 1-based, unique per run and gap-free at aggregate validation.

## 20. P3 persistence exact names

```text
ProjectDesignRevisions
DesignRevisionPhysicalSnapshots
CanonicalCableRuns
CableRunTraversals
RouteHandoffs
RouteBendEvidence
LegacyRouteAdoptions
CommandExecutionRecords
```

`CommandExecutionRecords` is introduced at the earliest phase requiring durable idempotency if P1 does not introduce it already. Preferred: introduce in P1 because all ELV compound commands depend on it.

Required uniqueness:

```text
ProjectDesignRevisions(project_id, code)
ProjectDesignRevisions(project_id, sequence)
exactly one WORKING/project (partial unique index or equivalent transactional guarantee)
CanonicalCableRuns(cable_id, design_revision_id) where state=ACTIVE
CableRunTraversals(cable_run_id, sequence)
DesignRevisionPhysicalSnapshots(design_revision_id)
LegacyRouteAdoptions(legacy_source_identity)
CommandExecutionRecords(project_id, command_id)
```

## 21. CreateNextWorking materialization

Transaction shape:

```text
BEGIN IMMEDIATE
  verify no WORKING revision
  load base FROZEN revision + verify snapshot SHA
  create new WORKING revision identity
  materialize one ACTIVE CanonicalCableRun per active run snapshot item
      new run id
      basedOnCableRunId = snapshot run id
      same Cable id
      new designRevisionId
  materialize traversal chains with new traversal ids
  DO NOT clone Cable/Allocation ids
  INSERT command record
COMMIT
```

If base snapshot schema predates a later phase, only state that existed in that snapshot is materialized. Never fill missing historical phase data from current rows.

## 22. Reroute code contract

`RerouteCableRunCommand` contains:

```dart
commandId
projectId
designRevisionId
cableRunId
expectedRunRevision
List<CableRunTraversalInput> completeTraversalChain
```

Process:

```text
require design revision WORKING
load run expected revision
validate all routeSegmentIds same project
validate direction-aware continuity
same-node OR accepted RouteHandoff
validate no branching
replace entire traversal chain in one transaction
increment run revision
emit affected dependency keys
```

It MUST NOT change `CableRouteNode` or `CableRouteSegment` geometry.

## 23. Shared route geometry edit contract

Separate command:

```dart
final class EditReusableRouteGeometryCommand {
  commandId
  projectId
  routeId
  expectedRouteRevision
  expectedImpactFingerprint
  candidateGeometry
}
```

Before commit:

```text
resolve all CanonicalCableRuns whose traversal references affected segments
compute stable impacted run id/revision set
compare fingerprint
validate candidate geometry
revalidate every impacted traversal chain
commit geometry atomically
invalidate all impacted dependency keys
```

A route edit that breaks one impacted run is rejected for all; no partial fan-out commit.

## 24. RouteHandoff code contract

```dart
enum RouteHandoffKind { surface, floor, vertical, explicit }

final class RouteHandoff {
  final String id;
  final String projectId;
  final String fromRouteNodeId;
  final String toRouteNodeId;
  final RouteHandoffKind kind;
  final bool bidirectional;
  final String? adjacencyRef;
  final Map<String, Object?> evidence;
  final int revision;
}
```

Handoff endpoints MUST represent the same physical interface. Handoff contributes zero cable length.

## 25. Bend evidence code contract

```dart
enum RouteBendEvidenceKind { designedRadius, fittingRadius, measuredRadius }

final class RouteBendEvidence {
  final String id;
  final String projectId;
  final String routeNodeId;
  final double radiusMm;
  final RouteBendEvidenceKind evidenceKind;
  final String? sourceRef;
  final int revision;
}
```

No geometry helper may infer radius from a polyline bend.

## 26. Frozen snapshot builder

Create one service/pure builder boundary:

```dart
abstract interface class ElvPhysicalSnapshotBuilder {
  Future<DesignRevisionPhysicalSnapshot> buildForFreeze(
    String projectId,
    String designRevisionId,
  );
}
```

Snapshot payload type is versioned. P3 initial schema embeds only data introduced through P3. P4/P5/P6 add later schema versions/readers, never mutate an existing snapshot.

Freeze transaction MUST build/validate all mutable inputs and persist snapshot + revision state atomically. If snapshot construction requires reads across repositories, the concrete Drift implementation must execute them against the same database transaction.

## 27. P1–P3 migration order

At implementation time current schema version is read from branch. Migrations are strictly incremental. Logical order is frozen:

```text
P1 migration
  ElvCables
  CommandExecutionRecords (preferred here)

P2 migration
  CableAllocations
  CableAllocationResourceSelections
  CableResourceClaims
  CableTerminationMappings

P3 migration
  ProjectDesignRevisions
  DesignRevisionPhysicalSnapshots
  CanonicalCableRuns
  CableRunTraversals
  RouteHandoffs
  RouteBendEvidence
  LegacyRouteAdoptions
```

Never create P2/P3 tables in P1 migration.

## 28. P1–P3 exact-SHA gate checklist

Every phase gate MUST run:

```text
dart format --set-exit-if-changed
flutter analyze / dart analyze as project workflows define
engineering_core tests
mobile tests
Drift build_runner generation
generated artifact guard
phase restart tests
phase failure/idempotency tests
legacy electrical routing regression from P3 onward
```

Gate evidence records exact branch SHA. Any later commit invalidates the gate.