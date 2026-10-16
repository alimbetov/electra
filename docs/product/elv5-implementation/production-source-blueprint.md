# ELV5 — Production source blueprint

Status: DESIGN HARDENED / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`

Authority: governing ELV5 design, engineering primitives, typed 27-process API, schema 24, hardening amendments and qualification contract. This blueprint fixes the recommended production decomposition and class responsibilities. Exact filenames may differ only if ownership, dependency direction and public contracts remain equivalent.

## 1. Dependency direction

Production dependency direction is one-way:

```text
Flutter UI / projections
        ↓
application commands + queries
        ↓
ELV5 orchestration / capture / publish / dependency services
        ↓
repository interfaces + shared ELV UoW
        ↓
Drift adapters / schema 24

application orchestration
        ↓
engineering_core typed ELV5 process registry
        ↓
engineering primitives / pure kernels
```

Forbidden directions:

```text
engineering_core -> Flutter/UI
engineering_core -> Drift/SQLite
pure process kernel -> repository
repository -> UI widget/state
ELV4 physical kernel -> ELV5 result pointer
ELV5 process -> ad-hoc SQL
```

## 2. Recommended source tree

```text
packages/engineering_core/lib/src/elv5/
  numeric/
    decimal.dart
    rational.dart
    quantity.dart
    interval.dart
    units.dart
  evidence/
    source_ref.dart
    evidence_basis.dart
    engineering_value.dart
    applicability.dart
    operating_case.dart
  canonical/
    canonical_json_v1.dart
    canonical_value.dart
    fingerprints.dart
  time/
    temporal_policy.dart
    recurrence_expander.dart
  geometry/
    frame_ref.dart
    point3.dart
    rotation3.dart
    bounded_geometry.dart
  findings/
    finding.dart
    comparison.dart
  processes/
    process_code.dart
    process_versions.dart
    process_definition.dart
    process_registry.dart
    cctv/
      cctv_01.dart
      cctv_02.dart
      cctv_03.dart
      cctv_04.dart
      cctv_05.dart
      cctv_06.dart
    lan/
      lan_01.dart
      lan_02.dart
      lan_03.dart
      lan_04.dart
      lan_05.dart
      lan_06.dart
      lan_07.dart
    acs/
      acs_01.dart
      acs_02.dart
      acs_03.dart
      acs_04.dart
      acs_05.dart
      acs_06.dart
    fire_alarm/
      fa_01.dart
      fa_02.dart
      fa_03.dart
      fa_04.dart
      fa_05.dart
      fa_06.dart
      fa_07.dart
      fa_08.dart

apps/mobile/lib/application/elv5/
  wire/
    elv5_wire_command.dart
    elv5_wire_command_codec.dart
    elv5_wire_command_registry.dart
    elv5_wire_command_dispatcher.dart
    elv5_wire_failure_mapper.dart
  commands/
    elv5_command_handler.dart
    bind_discipline_policy_handler.dart
    adopt_discipline_policy_handler.dart
    release_discipline_policy_handler.dart
    replace_camera_streams_handler.dart
    replace_recording_assignments_handler.dart
    replace_recorder_assignments_handler.dart
    replace_link_composition_handler.dart
    replace_port_capacity_assignments_handler.dart
    replace_optical_link_assignments_handler.dart
    replace_rack_capacity_basis_handler.dart
    replace_patch_panel_assignments_handler.dart
    replace_door_role_assignments_handler.dart
    replace_controller_resource_assignments_handler.dart
    replace_fire_loop_assignments_handler.dart
    replace_notification_circuit_assignments_handler.dart
  calculation/
    elv5_calculation_service.dart
    elv5_capture_service.dart
    elv5_input_resolver.dart
    elv5_batch_plan.dart
    elv5_publication_service.dart
    elv5_result_aggregator.dart
  dependencies/
    elv5_dependency_key.dart
    elv5_dependency_resolver.dart
    elv5_invalidation_service.dart
    elv5_reverse_index_service.dart
  revision/
    elv5_freeze_extension.dart
    elv5_create_next_extension.dart
    elv5_history_projection.dart
  query/
    elv5_workspace_query_service.dart
    elv5_historical_query_service.dart
    elv5_explanation_projector.dart

apps/mobile/lib/data/database/
  discipline_database_tables.dart
  app_database.dart

apps/mobile/lib/data/elv5/
  discipline_policy_repository.dart
  cctv_aspect_repository.dart
  lan_aspect_repository.dart
  acs_aspect_repository.dart
  fire_aspect_repository.dart
  discipline_evaluation_repository.dart
  discipline_pointer_repository.dart
  discipline_dependency_repository.dart
  discipline_snapshot_repository.dart
  elv5_drift_write_session.dart
  elv5_drift_write_unit_of_work.dart

apps/mobile/lib/ui/elv5/
  models/
    elv5_workspace_vm.dart
    elv5_process_card_vm.dart
    elv5_dimension_vm.dart
    elv5_finding_vm.dart
  controllers/
    elv5_workspace_controller.dart
  widgets/
    elv5_calculation_panel.dart
    elv5_process_card.dart
    elv5_dimension_table.dart
    elv5_provenance_panel.dart
    elv5_finding_list.dart
```

## 3. engineering_core public boundary

Application/UI must depend on a narrow exported ELV5 surface rather than internal process files.

Recommended export facade:

```dart
library engineering_core_elv5;

export 'src/elv5/numeric/quantity.dart';
export 'src/elv5/numeric/interval.dart';
export 'src/elv5/evidence/engineering_value.dart';
export 'src/elv5/evidence/source_ref.dart';
export 'src/elv5/evidence/operating_case.dart';
export 'src/elv5/processes/process_code.dart';
export 'src/elv5/processes/process_definition.dart';
export 'src/elv5/processes/process_registry.dart';
export 'src/elv5/findings/finding.dart';
```

Do not export mutable registry internals or process-local helper functions merely for tests.

## 4. Process registry

```dart
abstract interface class Elv5ProcessDefinition<I, O> {
  Elv5ProcessCode get code;
  Elv5Discipline get discipline;
  Elv5ProcessVersions get versions;
  Set<Elv5ScopeKind> get legalScopes;
  Set<String> get requiredDimensions;

  O calculate(I input);
  Elv5EvaluationDraft evaluate(I input, O output);
}

final class Elv5ProcessRegistry {
  Elv5ProcessRegistry(List<Elv5ProcessDefinition<Object, Object>> definitions);

  Elv5ProcessDefinition<Object, Object> require(Elv5ProcessCode code);
  Iterable<Elv5ProcessDefinition<Object, Object>> get all;
}
```

Constructor validation fails immediately on:

```text
duplicate/missing process code
not exactly 27 process definitions
unknown dependency process
illegal scope binding
unknown binder
cycle
missing required dimension metadata
unsupported version format
```

Runtime never constructs process definitions from imported formula text.

## 5. Canonical encoder

```dart
abstract interface class Elv5CanonicalEncoder {
  String get version;
  Uint8List encode(Object value);
  String sha256(Object value);
}

final class Elv5CanonicalJsonV1 implements Elv5CanonicalEncoder {
  @override
  String get version => 'electra.canonical-json.v1';
}
```

Exactly one production instance/version is injected into command hashing, input fingerprinting, output hashing, dependency-key hashing and discipline snapshot hashing. Process packages do not call `jsonEncode()` directly to create engineering hashes.

## 6. Wire command model

```dart
final class Elv5WireCommand {
  final String schema;
  final String operation;
  final int payloadSchemaVersion;
  final String projectId;
  final String designRevisionId;
  final String commandId;
  final int expectedDesignRowRevision;
  final Map<String, int> expectedRows;
  final String reviewedImpactFingerprint;
  final Object payload;
}
```

The JSON codec never returns an unvalidated arbitrary payload map to a handler. Each operation has a typed payload class.

Examples:

```dart
sealed class Elv5CommandPayload {}

final class ReplaceCameraStreamsPayload extends Elv5CommandPayload {
  final String cameraId;
  final List<CameraStreamPayload> streams;
  final List<CameraSubscriptionPayload> subscriptions;
  final Elv5DefinitionRef? transportOverheadModelRef;
}

final class ReplaceRecordingAssignmentsPayload extends Elv5CommandPayload {
  final String poolId;
  final Elv5UtcWindow horizon;
  final Elv5TemporalPolicy temporalPolicy;
  final List<RecordingAssignmentPayload> assignments;
  final List<RecordingSchedulePayload> scheduleSegments;
  final CctvStorageSizingBasis sizingBasis;
  final Elv5Rational reserveMultiplier;
  final RedundancyModelPayload? redundancyModel;
  final Elv5PolicyEditionRef policyRef;
}

final class ReplaceDoorRoleAssignmentsPayload extends Elv5CommandPayload {
  final String doorAssemblyId;
  final Elv5DefinitionRef topologyProfileRef;
  final AcsLockSafetyMode safetyMode;
  final List<AcsRoleAssignmentPayload> roleAssignments;
  final List<AcsReleaseTruthPayload> releaseTruthTable;
}
```

## 7. Wire dispatcher and backend

```dart
abstract interface class Elv5WireCommandBackend {
  Future<Elv5CommandResult<Object?>> execute(Elv5DecodedCommand command);
}

final class Elv5WireCommandDispatcher {
  final Elv5WireCommandCodec codec;
  final Elv5WireCommandBackend backend;

  Future<Elv5WireResponse> dispatch(String json);
}
```

Dispatcher responsibilities:

```text
strict decode
schema/operation/version selection
exact field-set validation
nested type validation
canonical semantic request hash
failure-to-wire mapping
```

Dispatcher does **not**:

```text
query project state
resolve reviewed impact
modify DB
calculate process formula
infer identities from labels
```

## 8. Command backend mapping

The backend contains exactly these command-handler mappings:

| Operation | Handler |
|---|---|
| BIND_DISCIPLINE_POLICY | `BindDisciplinePolicyHandler` |
| ADOPT_DISCIPLINE_POLICY | `AdoptDisciplinePolicyHandler` |
| RELEASE_DISCIPLINE_POLICY | `ReleaseDisciplinePolicyHandler` |
| REPLACE_CAMERA_STREAMS | `ReplaceCameraStreamsHandler` |
| REPLACE_RECORDING_ASSIGNMENTS | `ReplaceRecordingAssignmentsHandler` |
| REPLACE_RECORDER_ASSIGNMENTS | `ReplaceRecorderAssignmentsHandler` |
| REPLACE_LINK_COMPOSITION | `ReplaceLinkCompositionHandler` |
| REPLACE_PORT_CAPACITY_ASSIGNMENTS | `ReplacePortCapacityAssignmentsHandler` |
| REPLACE_OPTICAL_LINK_ASSIGNMENTS | `ReplaceOpticalLinkAssignmentsHandler` |
| REPLACE_RACK_CAPACITY_BASIS | `ReplaceRackCapacityBasisHandler` |
| REPLACE_PATCH_PANEL_ASSIGNMENTS | `ReplacePatchPanelAssignmentsHandler` |
| REPLACE_DOOR_ROLE_ASSIGNMENTS | `ReplaceDoorRoleAssignmentsHandler` |
| REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS | `ReplaceControllerResourceAssignmentsHandler` |
| REPLACE_FIRE_LOOP_ASSIGNMENTS | `ReplaceFireLoopAssignmentsHandler` |
| REPLACE_NOTIFICATION_CIRCUIT_ASSIGNMENTS | `ReplaceNotificationCircuitAssignmentsHandler` |
| CALCULATE_DISCIPLINE_PROCESS | `Elv5CalculationService` |

A registry test proves exactly 16 mappings and exact parity with `command-registry.json`.

## 9. Shared mutation handler protocol

All 15 non-calculation mutations use one generic protocol implementation rather than hand-copying replay/CAS/history ordering.

```dart
abstract interface class Elv5ReplacementHandler<P, S> {
  Future<Elv5CommandResult<S>> execute(Elv5CommandContext<P> command);
}
```

Recommended reusable template:

```dart
Future<Elv5CommandResult<T>> runReplacement<T>({
  required Elv5DecodedCommand command,
  required Future<Elv5AggregateSnapshot> Function(Elv5WriteSession) loadBefore,
  required Future<Elv5ValidatedReplacement<T>> Function(
    Elv5WriteSession,
    Elv5AggregateSnapshot,
  ) validateReplacement,
  required Future<void> Function(
    Elv5WriteSession,
    Elv5ValidatedReplacement<T>,
  ) writeReplacement,
});
```

The shared template owns:

```text
ledger replay lookup
revision lifecycle/token validation
expected rows/CAS
server-side impact resolution
reviewed impact verification
before aggregate evidence
mutation
union(old,new) invalidation
new dependency set
complete inverse/forward history
ledger logical response
transaction commit
```

Individual handlers own only aggregate-specific semantic validation/mapping.

## 10. Result/failure model

Recommended internal failures are typed, not string parsing:

```dart
sealed class Elv5Failure {}

final class Elv5WireValidationFailure extends Elv5Failure {}
final class Elv5PayloadSemanticFailure extends Elv5Failure {}
final class Elv5OwnershipFailure extends Elv5Failure {}
final class Elv5RevisionConflict extends Elv5Failure {}
final class Elv5ExpectedRowConflict extends Elv5Failure {}
final class Elv5ReviewedImpactConflict extends Elv5Failure {}
final class Elv5CommandPayloadConflict extends Elv5Failure {}
final class Elv5CaptureStale extends Elv5Failure {}
final class Elv5PointerGenerationConflict extends Elv5Failure {}
final class Elv5FrozenRevisionConflict extends Elv5Failure {}
final class Elv5UnsupportedModelFailure extends Elv5Failure {}
final class Elv5StorageFailure extends Elv5Failure {}
```

Stable wire `code` values are mapped centrally. Localized UI prose is produced later from stable code + structured parameters.

## 11. Repository interfaces

Repositories expose domain operations, not raw Drift tables.

Example:

```dart
abstract interface class Elv5CctvAspectStore {
  Future<CctvCameraStreamAggregate> loadCameraStreams(
    String projectId,
    String designRevisionId,
    String cameraId,
  );

  Future<void> replaceCameraStreams(
    CctvCameraStreamReplacement replacement,
  );

  Future<CctvRecordingPoolAggregate> loadRecordingPool(...);
  Future<void> replaceRecordingPool(...);
  Future<CctvRecorderAggregate> loadRecorder(...);
  Future<void> replaceRecorder(...);
}
```

No application service should depend directly on generated Drift row classes outside data-adapter code.

## 12. ELV5 write unit of work

```dart
abstract interface class Elv5WriteSession extends ElvWriteSession {
  Elv5PolicyBindingStore get policyBindings;
  Elv5CctvAspectStore get cctv;
  Elv5LanAspectStore get lan;
  Elv5AcsAspectStore get acs;
  Elv5FireAspectStore get fire;
  Elv5EvaluationStore get evaluations;
  Elv5PointerStore get pointers;
  Elv5DependencyStore get dependencies;
  ElvRevisionHistoryStore get history;
}

abstract interface class Elv5WriteUnitOfWork
    implements ElvWriteUnitOfWork<Elv5WriteSession> {}
```

The shared `commandLedger` remains inherited from `ElvWriteSession`; no `Elv5CommandLedger` interface is introduced.

## 13. Capture service

```dart
final class Elv5CaptureService {
  Future<Elv5CapturedBatch> capture(Elv5CalculationRequest request);
}
```

Capture is a short consistent read. It resolves:

```text
revision lifecycle/token
requested node keys
exact mutable ELV5 roots/member-set fingerprints
canonical ELV3 facts/path evidence
exact ELV4 immutable evaluation refs/output hashes/pointer generations
policy refs/hashes/applicability
operating cases
environment/time/frame evidence
missing-identity dependency markers
target pointer generations
canonical input fingerprint per node
```

Capture returns immutable application/domain objects and closes DB read scope before pure calculation.

## 14. Input resolver

Each process has a resolver adapter outside the pure kernel:

```dart
abstract interface class Elv5InputResolver<I> {
  Elv5InputResolution<I> resolve(Elv5CapturedContext context);
}
```

Resolver returns one of:

```dart
sealed class Elv5InputResolution<I> {}
final class Elv5Resolved<I> extends Elv5InputResolution<I> { final I input; }
final class Elv5Blocked<I> extends Elv5InputResolution<I> { final List<Elv5Finding> findings; }
final class Elv5Unsupported<I> extends Elv5InputResolution<I> { final List<Elv5Finding> findings; }
```

Missing/unsupported results still have exact dependencies and deterministic output where process contract permits a BLOCKED/UNRESOLVED evaluation.

## 15. Calculation service

```dart
final class Elv5CalculationService implements Elv5CommandHandler {
  final Elv5CaptureService captureService;
  final Elv5ProcessRegistry registry;
  final Elv5PublicationService publicationService;

  Future<Elv5CalculateResult> execute(CalculateDisciplineProcessCommand command);
}
```

Algorithm:

```text
validate requested process/scope/subject inventory
capture coherent batch
for each node:
  resolve typed input
  if RESOLVED -> pure calculate -> evaluate
  if BLOCKED/UNSUPPORTED -> deterministic blocked evaluation draft
aggregate batch draft
publish entire requested batch atomically
return stable logical response
```

Pure execution may use isolates/parallelism later, but determinism and atomic publication semantics do not change.

## 16. Publication service

```dart
final class Elv5PublicationService {
  Future<Elv5PublicationResult> publish(
    Elv5CapturedBatch capture,
    Elv5EvaluationBatchDraft draft,
  );
}
```

Inside one write transaction:

```text
recheck revision WORKING + token
recheck every consumed row revision
recheck SET membership fingerprints
recheck exact policy refs/hashes
recheck upstream pointer generations/evidence refs
recompute/verify input fingerprints
verify every target pointer expected generation
insert every immutable evaluation record
replace every affected reverse-index edge set
update every target pointer CURRENT with generation+1
commit
```

If any check fails, zero requested target pointers/evaluations are published as current engineering results.

## 17. Dependency key types

Do not pass dependency keys around as arbitrary strings internally.

```dart
sealed class Elv5DependencyKey {}
final class Elv5FactDependency extends Elv5DependencyKey {}
final class Elv5SetDependency extends Elv5DependencyKey {}
final class Elv5PolicyDependency extends Elv5DependencyKey {}
final class Elv5EvaluationDependency extends Elv5DependencyKey {}
final class Elv5PointerDependency extends Elv5DependencyKey {}
final class Elv5MissingDependency extends Elv5DependencyKey {}
```

Each exposes canonical serialization. Debug string form may remain compatible with:

```text
FACT/...
SET/...
POLICY/...
EVAL/...
POINTER/...
MISSING/...
```

## 18. Invalidation service

```dart
final class Elv5InvalidationService {
  Future<Elv5InvalidationResult> invalidateForReplacement(
    Set<Elv5DependencyKey> oldClosure,
    Set<Elv5DependencyKey> newClosure,
  );
}
```

Algorithm:

```text
changedKeys = union(oldClosure,newClosure)
dependants = reverseIndex.lookup(changedKeys)
for each dependant:
  pointer.freshness = STALE
  pointer.generation += 1
persist pointer changes + index changes in same mutation UoW
```

Missing-identity keys ensure creation of previously absent evidence invalidates blocked results.

## 19. Freeze extension

```dart
abstract interface class Elv5FreezeExtension {
  Future<Elv5DisciplineSnapshotDraft> captureForFreeze(
    ElvFreezeContext context,
  );
}
```

Freeze extension is invoked by the existing revision freeze service; it is not another public command.

It captures:

```text
all active revision-owned ELV5 roots/members
exact policy refs/hashes
selected immutable current result refs/output hashes/generations
discipline canonical payload
physical/power hash cross references
disciplineHash
```

Legacy snapshot dispatch remains explicit.

## 20. Create-next extension

```dart
abstract interface class Elv5CreateNextRevisionExtension {
  Future<void> materialize(
    ElvCreateNextContext context,
    ElvIdentityRemap remap,
  );
}
```

The extension remaps revision-owned references but never edits old immutable evaluation records.

## 21. Workspace query projection

```dart
final class Elv5WorkspaceQueryService {
  Future<Elv5WorkspaceVm> load(Elv5WorkspaceQuery query);
}
```

Projection includes for each process:

```text
node identity
revision/scope/scenario/operating case
freshness/completion/assessment/execution
required dimensions
actual/required/margin values + canonical display unit
calculation steps
stable findings + remediation targets
policy edition/hash/status
source/evidence provenance
upstream immutable evidence refs
claim-scope limitations
last/current pointer generation
```

UI must never recompute a source budget or parse calculation prose to decide status.

## 22. Engineer-facing UI behavior

Recommended process-card visual hierarchy:

```text
1. Process + subject + scope
2. Current/Stale badge
3. Engineering verdict axes
4. Required dimension table
5. Worst/limiting dimension
6. Inputs and operating case
7. How calculated
8. Source/policy provenance
9. Findings and exact remediation
10. Claim-scope / not-assessed note
```

For shared source/bank/PSE:

```text
GLOBAL physical total
selected discipline contribution
other-system contribution
required capability
available capability
margin
same immutable evidence ID
```

A filter can hide rows but cannot change the calculation request into a reduced physical budget.

## 23. UI state controller

```dart
sealed class Elv5WorkspaceState {}
final class Elv5WorkspaceLoading extends Elv5WorkspaceState {}
final class Elv5WorkspaceReady extends Elv5WorkspaceState {}
final class Elv5WorkspaceCalculating extends Elv5WorkspaceState {}
final class Elv5WorkspaceConflict extends Elv5WorkspaceState {}
final class Elv5WorkspaceReadFailure extends Elv5WorkspaceState {}
```

A prior engineering FAIL is not a UI error state. An execution/storage failure is not displayed as engineering FAIL.

Controller preserves originating revision/scope generation so late async completion cannot attach to another selected revision/subject.

## 24. Command failure codes

Recommended stable codes include:

```text
ELV5_SCHEMA_UNSUPPORTED
ELV5_OPERATION_UNSUPPORTED
ELV5_PAYLOAD_SCHEMA_UNSUPPORTED
ELV5_TOP_LEVEL_FIELDS_MISMATCH
ELV5_PAYLOAD_FIELDS_MISMATCH
ELV5_PAYLOAD_SEMANTIC_INVALID
ELV5_FOREIGN_PROJECT_REFERENCE
ELV5_REVISION_NOT_WORKING
ELV5_DESIGN_ROW_REVISION_CONFLICT
ELV5_EXPECTED_ROW_CONFLICT
ELV5_REVIEWED_IMPACT_CONFLICT
ELV5_COMMAND_PAYLOAD_CONFLICT
ELV5_CAPTURE_STALE
ELV5_POINTER_GENERATION_CONFLICT
ELV5_PUBLISH_AFTER_FREEZE
ELV5_UNKNOWN_PROCESS
ELV5_ILLEGAL_SCOPE
ELV5_STORAGE_FAILURE
```

Blocked/unsupported engineering model outcomes normally belong inside an immutable evaluation result, not command failure, unless the public request itself selects an illegal scope/process/subject combination.

## 25. Migration 24 source boundary

`app_database.dart` owns schema version and migration orchestration. ELV5 table definitions live in `discipline_database_tables.dart`; repository adapters live outside that part file.

Migration implementation MUST be independently reviewable:

```dart
Future<void> migrate23To24(Migrator m) async {
  // create ELV5 additive tables/indexes
  // extend/rebuild manifest table only if required
  // preserve existing ELV3/ELV4 rows byte/semantic identity
}
```

Do not hide ELV5 migration inside a generic catch-all migration helper that prevents exact P2 evidence.

## 26. Transaction policy

Use short SQLite transactions:

```text
public replacement command -> one write transaction
capture -> short consistent read transaction/snapshot
pure calculation -> no DB transaction
publish -> one short write transaction
freeze -> existing coordinated revision transaction
create-next -> existing coordinated revision transaction
```

Never keep a write transaction open while running geometry, recurrence expansion, 27-process DAG execution or Flutter async UI work.

## 27. Logging and diagnostics

Structured diagnostic context should include:

```text
projectId
designRevisionId
commandId
operation
processCode
nodeKey hash
capture/input fingerprint
pointer generation
failure code
```

Do not log complete sensitive project payloads by default. Engineering evidence is persisted through the domain model; logs are diagnostics, not authoritative history.

## 28. Implementation slices

Recommended implementation order minimizes rework:

### Slice A — P1 primitives

Implement exact numeric/dimension/evidence/canonical/time/frame/finding types and tests.

### Slice B — registry skeleton

Implement 27 code enum/registry/definition interfaces and placeholder NOT_IMPLEMENTED definitions only in test scaffolding; production registration must fail if a process is not actually available when runtime feature is enabled.

### Slice C — schema 24

Implement tables/migration/repositories/UoW and close/reopen/migration tests before process writes depend on them.

### Slice D — strict wire infrastructure

Implement 16 exact codecs + examples + replay/handler routing and common replacement protocol.

### Slice E — simplest scalar verticals

Recommended early production verticals:

```text
LAN-02
LAN-07
ACS-01
ACS-02
FA-01
```

These validate typed inputs, persistence, dependency SET markers and publication without complex physical math.

### Slice F — CCTV storage/network and LAN physical compatibility

Implement CCTV-02/03/05, LAN-01/04/05/06 and associated cross-process dependencies.

### Slice G — shared ELV4 wrappers

Implement CCTV-04/06, LAN-03, ACS-03/04/05, FA-03/04/05/06 with exact immutable power evidence adapters.

### Slice H — geometry and topologies

Implement CCTV-01, ACS-06, FA-07/08 and remaining topology/model-limited processes.

### Slice I — P7 workspace/dependencies

Complete invalidation fan-out, missing markers, historical projection and engineer UI.

### Slice J — P8/P9

Execute full qualification/race/migration/freeze/scale matrix and exact-head evidence ledger.

## 29. Definition of Done for one process

A process is not Done until all are true:

```text
typed input/output class exists
registry definition exists with exact versions/scopes/dimensions
typed resolver exists
pure kernel exists
finding/step output is explanatory
all verdict inputs have provenance/evidence basis
input/output hash projection covered
old/new dependency closure covered
persistence/restart path covered if process owns aspects
public calculate path covered
POS primary vertical passes
NEG/unsupported primary vertical passes
boundary/metamorphic tests pass
workspace projection shows exact result/provenance/limitations
no later-stage false claim
P9 ledger contains source/test mapping
```

## 30. Definition of Done for one replacement command

A command is not Done until:

```text
strict typed codec
canonical request hash
exact payload-key guard
nested semantic validator
foreign ownership validation
replay-first behavior
expected row/CAS validation
server-side reviewed impact
atomic root+child replacement
union(old,new) invalidation
complete before/after history
ledger logical response
failure-injection rollback after reopen
undo/redo after restart
wire failure mapping
P9 source/test evidence
```

## 31. Architecture prohibition checklist

Code review rejects:

```text
new ELV5 cable/port/source/battery canonical tables
generic formula evaluator
process semantic Map<String,dynamic>
jsonEncode-based engineering hash
DateTime.now() inside pure kernel
host timezone recurrence
UI-created physical source subtotal presented as global
mutable latest policy lookup during calculation
ELV5-specific second command ledger/history cursor
long SQLite write transaction around pure calculation
partial multi-node publication
dBm treated as dB
nominal-only value satisfying guaranteed-bound check
localized message text parsed as business logic
```

## 32. Runtime closure

This blueprint becomes runtime evidence only when corresponding production files/classes exist and P8/P9 execute against them at one exact source SHA. The current branch remains specification-only until then.
