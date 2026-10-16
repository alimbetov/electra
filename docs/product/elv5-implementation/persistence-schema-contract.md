# ELV5 — Drift schema 24 persistence and migration contract

Status: DESIGN DRAFT / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`  
Parent database schema: **23** at merged ELV4 baseline.  
Required ELV5 additive target: **24**.

Authority: [implemented baseline](implemented-baseline.md), [code-level runtime contract](code-level-runtime-contract.md), [engineering primitives](engineering-primitives-contract.md), [typed process API](typed-process-api.md).

This document freezes the database shape expected from P2. It deliberately reuses the existing project/revision tables, shared ELV command ledger/write-unit-of-work behavior and ELV revision history. It does not create a second project, cable, port, component, source, battery, revision, command-history or undo/redo ownership model.

## 1. Migration boundary

At implementation start:

```dart
@override
int get schemaVersion => 24;
```

Schema 24 MUST be an additive migration from the accepted schema 23. Upgrade from supported historical origins still runs the existing chain to 23 first, then the ELV5 migration to 24. No ELV5 migration may reinterpret existing ELV3/ELV4 rows.

Recommended source split:

```text
apps/mobile/lib/data/database/
  app_database.dart
  power_database_tables.dart           // unchanged ownership
  elv_history_database_tables.dart     // shared history ownership
  discipline_database_tables.dart      // new ELV5 tables
```

`app_database.dart` adds:

```dart
part 'discipline_database_tables.dart';
```

The exact generated SQL names may follow existing Drift naming conventions; semantic keys and constraints below are normative.

## 2. Shared audit mixin

All mutable ELV5 revision-owned roots use one shape:

```dart
mixin DisciplineRevisionAuditColumns on Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get id => text()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get originDeviceId => text()();
}
```

Every mutable root primary key is `{designRevisionId, id}`. Every command mutation also verifies project ownership even when the database FK target is globally keyed by ID.

Soft-deleted rows are not active members. Active uniqueness that cannot be expressed as a Drift table-level PK must be enforced by an explicit SQLite partial unique index in migration 24 and by a transaction-level acceptance test.

## 3. Policy bindings

```dart
@DataClassName('DisciplinePolicyBindingRow')
class DisciplinePolicyBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get subjectKind => text()();
  TextColumn get subjectId => text()();
  TextColumn get processCodesJson => text()(); // canonical sorted set
  TextColumn get definitionRefJson => text()();
  TextColumn get definitionSha256 => text()();
  TextColumn get applicabilityJson => text()();
  TextColumn get applicabilitySha256 => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

Required indexes:

```text
UNIQUE active(designRevisionId, id)
INDEX(projectId, designRevisionId, subjectKind, subjectId)
INDEX(projectId, designRevisionId, definitionSha256)
```

A binding references an immutable definition edition by exact ref/hash; it never stores a mutable `latest` pointer.

## 4. CCTV camera stream aspect

```dart
@DataClassName('CameraStreamBindingRow')
class CameraStreamBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get cameraId => text().references(ComponentInstances, #id)();
  TextColumn get encodedStreamId => text()();
  TextColumn get streamProfileJson => text()();
  TextColumn get streamProfileSha256 => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

Active uniqueness:

```text
(designRevisionId, cameraId, encodedStreamId)
```

`id` is the ELV5 aspect row identity; `(cameraId, encodedStreamId)` is the engineering stream identity. Camera remains canonical ELV3/component ownership.

## 5. Recording pool root, assignments and schedule

The wire command is pool-scoped, therefore storage horizon/sizing basis belongs to a root and is not copied into every assignment.

```dart
@DataClassName('RecordingPoolBindingRow')
class RecordingPoolBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get poolId => text()(); // non-owning external/logical pool identity
  TextColumn get horizonJson => text()();
  TextColumn get temporalPolicyJson => text()();
  TextColumn get sizingBasis => text()();
  TextColumn get reserveMultiplierJson => text()();
  TextColumn get redundancyModelJson => text().nullable()();
  TextColumn get policyRefJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

```dart
@DataClassName('RecordingAssignmentRow')
class RecordingAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get encodedStreamId => text()();
  TextColumn get copyRole => text()();
  TextColumn get bitrateValueJson => text()();
  TextColumn get bitrateEvidenceJson => text()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    encodedStreamId,
    copyRole,
  };
}
```

```dart
@DataClassName('RecordingScheduleSegmentRow')
class RecordingScheduleSegments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get segmentId => text()();
  IntColumn get ordinal => integer()();
  TextColumn get scheduleJson => text()();
  TextColumn get scheduleSha256 => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    segmentId,
  };
}
```

`RecordingAssignments` must reject duplicate semantic identity even if a caller supplies different row IDs. Schedule replacement is whole-set replacement inside one transaction.

## 6. Recorder capacity root and assignments

```dart
@DataClassName('RecorderCapacityBindingRow')
class RecorderCapacityBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get recorderId => text().references(ComponentInstances, #id)();
  TextColumn get accountingBasis => text()();
  TextColumn get limitsJson => text()();
  TextColumn get limitsSha256 => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

```dart
@DataClassName('RecorderAssignmentRow')
class RecorderAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get cameraId => text().references(ComponentInstances, #id)();
  TextColumn get encodedStreamId => text()();
  TextColumn get licenseChannelId => text()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    cameraId,
    encodedStreamId,
    licenseChannelId,
  };
}
```

Accounting basis is root state because changing DEVICE ↔ ENCODED_STREAM ↔ LICENSE_CHANNEL changes all capacity semantics and invalidates the recorder closure.

## 7. Link composition root and ordered sections

```dart
@DataClassName('LinkCompositionBindingRow')
class LinkCompositionBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get linkId => text()();
  TextColumn get policyBindingId => text()();
  TextColumn get compositionKind => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

```dart
@DataClassName('LinkSectionAssignmentRow')
class LinkSectionAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  IntColumn get ordinal => integer()();
  TextColumn get realizedSectionId => text()();
  TextColumn get sectionRole => text()();
  TextColumn get evidenceJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, bindingId, ordinal};
}
```

A unique index on `(designRevisionId,bindingId,realizedSectionId)` is required unless the selected process model explicitly marks repeated traversal and carries a distinct traversal identity.

## 8. Switch/port capacity root and claims

```dart
@DataClassName('PortCapacityBindingRow')
class PortCapacityBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get switchId => text().references(ComponentInstances, #id)();
  TextColumn get sparePolicyRefJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

```dart
@DataClassName('PortCapacityAssignmentRow')
class PortCapacityAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get endpointId => text()();
  TextColumn get portId => text().references(EngineeringPortInstances, #id)();
  TextColumn get selectedMode => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    portId,
  };
}
```

A canonical physical port cannot be assigned twice in one active switch-capacity binding.

## 9. Optical link root, directions and loss events

```dart
@DataClassName('OpticalLinkBindingRow')
class OpticalLinkBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get linkId => text()();
  TextColumn get forwardOpticsJson => text()();
  TextColumn get reverseOpticsJson => text()();
  TextColumn get policyRefJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

```dart
@DataClassName('OpticalLossEventRow')
class OpticalLossEvents extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get directionCode => text()();
  TextColumn get eventId => text()();
  TextColumn get eventKind => text()();
  IntColumn get ordinal => integer()();
  TextColumn get lossIntervalJson => text()();
  TextColumn get evidenceJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    directionCode,
    eventId,
  };
}
```

Connector-pair event is one event identity. Two connector ends must not become two mated-pair losses unless the selected optical model explicitly says so.

## 10. Rack capacity basis and non-owning equipment membership

```dart
@DataClassName('RackCapacityBindingRow')
class RackCapacityBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get rackId => text().references(ComponentInstances, #id)();
  TextColumn get capacityBasis => text()();
  TextColumn get capacityJson => text()();
  TextColumn get excludedCapacityJson => text()();
  TextColumn get exclusionProvenanceJson => text()();
  TextColumn get policyRefJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

```dart
@DataClassName('RackEquipmentMembershipRow')
class RackEquipmentMemberships extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get equipmentId => text().references(ComponentInstances, #id)();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    equipmentId,
  };
}
```

This is demand membership only. No U-position/slot placement is stored here; actual enclosure layout belongs to ELV6.

## 11. Patch-panel basis

```dart
@DataClassName('PatchPanelBindingRow')
class PatchPanelBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get panelId => text().references(ComponentInstances, #id)();
  TextColumn get sparePolicyRefJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

```dart
@DataClassName('PatchPanelAssignmentRow')
class PatchPanelAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get panelPortId => text().references(EngineeringPortInstances, #id)();
  TextColumn get endpointId => text()();
  TextColumn get destinationRefJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    panelPortId,
  };
}
```

## 12. Door calculation root, role assignments and release truth table

```dart
@DataClassName('DoorCalculationBindingRow')
class DoorCalculationBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get doorAssemblyId => text()();
  TextColumn get topologyProfileRefJson => text()();
  TextColumn get safetyMode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

```dart
@DataClassName('DoorRoleAssignmentRow')
class DoorRoleAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get componentId => text().references(ComponentInstances, #id)();
  TextColumn get roleCode => text()();
  TextColumn get slot => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    roleCode,
    slot,
  };
}
```

```dart
@DataClassName('DoorReleaseTruthRow')
class DoorReleaseTruthRows extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get causeCode => text()();
  TextColumn get expectedOutcomeCode => text()();
  TextColumn get requiredEvidenceRolesJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    causeCode,
  };
}
```

The truth table is technical behavior evidence, not a compliance certificate.

## 13. Controller resource basis

```dart
@DataClassName('ControllerResourceBindingRow')
class ControllerResourceBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get controllerId => text().references(ComponentInstances, #id)();
  TextColumn get reservePolicyRefJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

```dart
@DataClassName('ControllerResourceAssignmentRow')
class ControllerResourceAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get resourceId => text()();
  TextColumn get doorAssemblyId => text()();
  TextColumn get roleCode => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    resourceId,
    roleCode,
  };
}
```

## 14. Fire-loop root, device membership and expanded address claims

```dart
@DataClassName('FireLoopBindingRow')
class FireLoopBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get loopId => text()();
  TextColumn get addressDomainJson => text()();
  TextColumn get topologyProfileRefJson => text()();
  TextColumn get policyRefJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

```dart
@DataClassName('FireLoopDeviceAssignmentRow')
class FireLoopDeviceAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get deviceId => text().references(ComponentInstances, #id)();
  TextColumn get expansionProfileRefJson => text()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    deviceId,
  };
}
```

```dart
@DataClassName('FireAddressClaimRow')
class FireAddressClaims extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get deviceId => text().references(ComponentInstances, #id)();
  TextColumn get addressDomain => text()();
  IntColumn get address => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    addressDomain,
    address,
  };
}
```

The address claim table makes collision impossible to hide inside JSON. Migration/runtime validates expanded claim cardinality against the selected expansion profile.

## 15. Notification circuit root and assignments

```dart
@DataClassName('NotificationCircuitBindingRow')
class NotificationCircuitBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get circuitId => text()();
  TextColumn get outputRefJson => text()();
  TextColumn get policyRefJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}
```

```dart
@DataClassName('NotificationCircuitAssignmentRow')
class NotificationCircuitAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get deviceId => text().references(ComponentInstances, #id)();
  TextColumn get outputId => text()();
  TextColumn get stateLoadJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    deviceId,
    outputId,
  };
}
```

## 16. Immutable discipline evaluations

```dart
@DataClassName('DisciplineEvaluationRecordRow')
class DisciplineEvaluationRecords extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get logicalNodeKeyJson => text()();
  TextColumn get logicalNodeKeySha256 => text()();
  TextColumn get evaluationId => text()();
  TextColumn get scopeKind => text()();
  TextColumn get scopeId => text()();
  TextColumn get scenarioKey => text()();
  TextColumn get processCode => text()();
  TextColumn get subjectKind => text()();
  TextColumn get subjectId => text()();
  TextColumn get algorithmVersion => text()();
  TextColumn get inputSchemaVersion => text()();
  TextColumn get outputSchemaVersion => text()();
  TextColumn get numericBackendVersion => text()();
  TextColumn get canonicalEncoderVersion => text()();
  TextColumn get inputFingerprint => text()();
  TextColumn get policyFingerprint => text()();
  TextColumn get execution => text()();
  TextColumn get completion => text()();
  TextColumn get assessment => text()();
  TextColumn get outputJson => text()();
  TextColumn get outputSha256 => text()();
  TextColumn get evidenceJson => text()();
  TextColumn get evidenceSha256 => text()();
  DateTimeColumn get completedAtUtc => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    logicalNodeKeySha256,
    evaluationId,
  };
}
```

`outputSha256` follows the deterministic output projection and therefore excludes `evaluationId` and `completedAtUtc`.

Indexes:

```text
INDEX(projectId, designRevisionId, processCode)
INDEX(projectId, designRevisionId, subjectKind, subjectId)
INDEX(inputFingerprint)
INDEX(outputSha256)
```

Records are append-only. Production repository exposes no update/delete method for immutable evaluation content.

## 17. Current/stale discipline pointers

```dart
@DataClassName('DisciplineEvaluationPointerRow')
class DisciplineEvaluationPointers extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get logicalNodeKeyJson => text()();
  TextColumn get logicalNodeKeySha256 => text()();
  TextColumn get freshness => text()();
  IntColumn get generation => integer()();
  TextColumn get evaluationId => text().nullable()();
  TextColumn get inputFingerprint => text().nullable()();
  TextColumn get outputSha256 => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    logicalNodeKeySha256,
  };
}
```

Pointer generation is monotonically increasing per node. Publication is compare-and-swap against captured generation. `CURRENT` means current for captured inputs, not engineering PASS.

## 18. Dependency reverse index

```dart
@DataClassName('DisciplineDependencyIndexRow')
class DisciplineDependencyIndex extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get dependencyKey => text()();
  TextColumn get dependencyKeySha256 => text()();
  TextColumn get logicalNodeKeySha256 => text()();
  TextColumn get relationKind => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    dependencyKeySha256,
    logicalNodeKeySha256,
  };
}
```

`relationKind` is a closed code-owned token: `FACT`, `SET`, `POLICY`, `EVAL`, `POINTER`, `MISSING`. The full canonical dependency string remains available for audit; SHA is an index key, never the only evidence.

## 19. Discipline snapshot section

```dart
@DataClassName('DesignRevisionDisciplineSnapshotRow')
class DesignRevisionDisciplineSnapshots extends Table {
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get sectionSchema => text()();
  TextColumn get captureKind => text()();
  TextColumn get payloadJson => text()();
  TextColumn get disciplineSha256 => text()();
  TextColumn get physicalSha256 => text()();
  TextColumn get powerSha256 => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId};
}
```

The existing `DesignRevisionSnapshotManifests` must be extended additively to include discipline section identity/hash. If altering the existing table requires a SQLite rebuild, migration 24 must prove row preservation from schema 23 and exact old-manifest compatibility.

Old snapshots without this section return `ELV5_NOT_CAPTURED`. A new-format section with zero active ELV5 roots is `CAPTURED_EMPTY`.

## 20. Command ledger and history reuse

ELV5 MUST reuse the existing command-ledger semantics exposed through:

```dart
abstract interface class ElvCommandLedgerStore {
  Future<ElvCommandLedgerEntry?> find(String projectId, String commandId);
  Future<void> save(ElvCommandLedgerEntry entry);
}
```

Do not create `DisciplineCommandLedger`.

The stored `normalizedPayloadSha256` for ELV5 is the `electra.canonical-json.v1` request hash. The ledger stores the logical semantic result needed to replay response-loss retries.

ELV5 reversible mutations also reuse the revision history/evidence platform (`ElvRevisionAggregateEvidenceRecords`, `ElvRevisionCommandHistoryOperations`, cursor/execution tables). Aggregate evidence gains ELV5 roots through its canonical payload; no second undo/redo cursor is permitted.

## 21. Write unit of work

Recommended boundary:

```dart
abstract interface class Elv5DisciplineWriteSession extends ElvWriteSession {
  Elv5PolicyBindingStore get policies;
  Elv5CctvAspectStore get cctv;
  Elv5LanAspectStore get lan;
  Elv5AcsAspectStore get acs;
  Elv5FireAspectStore get fire;
  Elv5EvaluationStore get evaluations;
  Elv5PointerStore get pointers;
  Elv5DependencyIndexStore get dependencies;
  Elv5RevisionStore get revisions;
  ElvRevisionHistoryStore get history; // shared platform
}

abstract interface class Elv5DisciplineWriteUnitOfWork
    implements ElvWriteUnitOfWork<Elv5DisciplineWriteSession> {}
```

One public mutation uses exactly one SQLite transaction for replay lookup, expected-row checks, server-side impact verification, root/member mutation, dependency invalidation, shared history append and ledger save.

Long calculations use capture/pure-run/publish and do not hold this write transaction during the pure kernel.

## 22. Replacement-command transaction pattern

Every `REPLACE_*` command follows the same storage protocol:

```text
BEGIN IMMEDIATE
  replay ledger lookup
  verify working revision/token/expected rows
  load old root + all old members
  resolve server-side old dependency closure
  decode/validate complete replacement payload
  validate all canonical foreign references belong to project/revision
  derive new dependency closure
  verify reviewedImpactFingerprint
  upsert/increment root revision or create root
  delete/replace child member set atomically
  mark union(old,new) dependent pointers STALE + generation++
  replace reverse-index edges for directly changed root
  append before/after aggregate evidence + complete forward/inverse history
  save ledger logical response
COMMIT
```

Any validation/storage failure rolls back root, children, pointer invalidation, history and ledger together.

## 23. Publish transaction pattern

```text
CAPTURE (read transaction)
  exact roots/children/set markers
  exact policy refs/hashes
  exact ELV3/ELV4 evidence refs/hashes/pointer generations
  target discipline pointer generations
  input fingerprint

PURE RUN
  no DB writes

PUBLISH (write transaction)
  verify revision still WORKING and token unchanged
  re-read every consumed row revision/set marker
  re-read upstream pointer generations
  recompute/compare input fingerprint
  CAS every target discipline pointer generation
  insert immutable evaluation records
  replace reverse dependency edges for published nodes
  update pointers CURRENT to inserted evaluations
COMMIT
```

Publication of a multi-node calculate command is all-or-nothing for the requested coherent batch. If any captured node conflicts, none of the batch becomes CURRENT. The caller may recapture and retry with a new command ID or the defined retry workflow.

## 24. Required SQL integrity checks

Migration/runtime must enforce or test equivalent invariants:

1. every mutable root references existing project and design revision;
2. every canonical component/port reference belongs to the same project context;
3. no child exists without its active root;
4. no duplicate camera stream engineering identity;
5. no duplicate recording `(stream,pool,copyRole)` identity;
6. no duplicate port claim within one capacity binding;
7. no duplicate fire `(addressDomain,address)` claim within one loop binding;
8. ordered child ordinals are unique per root;
9. pointer generation is nonnegative and monotonic under repository methods;
10. immutable evaluation rows are never updated;
11. evaluation/pointer owner is intrinsically ELV5 through table identity and node-key owner validation;
12. ELV4 power records/pointers remain untouched by migration 24;
13. schema-23 database opens/migrates/reopens without data loss;
14. schema-24 reopen preserves every ELV5 root/member/hash/index;
15. foreign-project references are rejected before commit even if raw SQLite FK shape alone cannot express project ownership.

## 25. Migration-24 acceptance matrix

P2 must execute file-SQLite tests for:

| Case | Required proof |
|---|---|
| fresh 24 | all ELV5 tables/indexes exist, empty state valid |
| 23 → 24 | ELV3/ELV4 row counts/hashes unchanged; ELV5 tables empty |
| supported historical origin → 24 | historical chain reaches 23 then 24 and preserves acceptance fixtures |
| failed migration | transaction rollback leaves source DB reopenable |
| foreign FK | rejected |
| duplicate stream/address/port claim | rejected deterministically |
| replace root+children | atomic old→new set, no hybrid set |
| process publish | immutable record + pointer + reverse index atomic |
| stale publish | zero inserted CURRENT publication state |
| freeze race | freeze winner prevents late CURRENT pointer |
| reopen | hashes, revisions and child order unchanged |
| legacy snapshot | `ELV5_NOT_CAPTURED` |
| empty ELV5 frozen snapshot | `CAPTURED_EMPTY` distinct from legacy |

## 26. Schema ownership prohibition

The following tables are explicitly forbidden in ELV5:

```text
DisciplineCables
DisciplinePorts
DisciplineComponents
DisciplinePowerSources
DisciplineBatteryBanks
DisciplineProjectRevisions
DisciplineCommandHistoryCursor
```

If implementation appears to need one of them, that is an ownership defect. Add a non-owning binding/member/reference to the canonical entity instead.

## 27. Closure rule

Schema 24 is now the frozen ELV5 design target. Runtime acceptance still requires the actual migration, generated Drift code, file-SQLite upgrade matrix, exact table/index inspection and source-level ownership audit at the same accepted SHA.
