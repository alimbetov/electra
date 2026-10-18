# ELV5 — Code-level runtime contract

Status: DESIGN DRAFT / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`  
Authority: [ELV5 design](../elv5-discipline-calculations-design-specification.md), [27 process contracts](process-contracts.md), [process registry](process-registry.json), [implemented baseline](implemented-baseline.md).

This document closes the gap between engineering prose and executable Dart/Drift boundaries. It does **not** replace process formulas or P0–P9 package contracts. It fixes the minimum runtime types, wire envelopes, command surface, persistence identities, dependency/publication protocol and acceptance obligations that any ELV5 implementation must satisfy.

The implementation may split files differently, but semantic names, stable external string codes, identity composition, status axes, replay/CAS order and fail-closed behavior are normative.

## 1. Architectural rule

ELV5 is an owner-isolated discipline calculation layer on top of accepted ELV3/ELV4 facts.

```text
ELV2 exact reference editions
        │
ELV3 canonical physical facts
        │
ELV4 physical power evidence ─────────────┐
        │                                  │
        └──────────────┬───────────────────┘
                       ▼
              ELV5 input resolver
                       ▼
           typed process definition
                       ▼
              pure process kernel
                       ▼
         immutable evaluation record
                       ▼
        generation-guarded current pointer
                       ▼
        dependency index / workspace / report
```

ELV5 MUST NOT:

- rewrite `PowerNodeKeyV2`, ELV4 power records/pointers or ELV4 command schemas;
- synthesize missing canonical cable lengths, topology, source memberships or product facts from labels;
- persist `RUNNING` as an engineering result;
- collapse `STALE`, `BLOCKED`, `FAIL` and execution failure into one status;
- accept executable formulas/scripts from project data;
- infer national compliance, cabinet fit or commercial selection from ELV5 technical PASS.

## 2. Stable process and scope types

Runtime code MUST use code-owned values for the 27 process codes. The external string value is stable and is the serialization value.

```dart
enum Elv5Discipline { cctv, lan, acs, fireAlarm }

enum Elv5ScopeKind { design, segment, sequence }

enum Elv5Freshness { current, stale }

enum Elv5Completion { complete, partial, blocked }

enum Elv5Assessment { pass, fail, unresolved, notAssessed }

enum Elv5Execution { succeeded, failed }

enum Elv5PolicySourceStatus {
  fictional,
  projectAuthored,
  verifiedExternal,
}
```

`Elv5ProcessCode` MUST be represented by a closed code-owned registry containing exactly:

- CCTV-01…CCTV-06;
- LAN-01…LAN-07;
- ACS-01…ACS-06;
- FA-01…FA-08.

Unknown process code is a codec/registry error, never a generic custom process.

### 2.1 Engineering node key v3

```dart
final class Elv5EngineeringNodeKeyV3 {
  final String owner;              // constant "ELV5"
  final String designRevisionId;
  final String scenarioKey;        // "NONE" for DESIGN
  final Elv5ScopeKind scopeKind;
  final String scopeId;
  final String processCode;
  final String subjectKind;
  final String subjectId;
}
```

Canonical serialized tuple:

```text
[
  "engineering-node-v3",
  "ELV5",
  designRevisionId,
  scenarioKey,
  scopeKind,
  scopeId,
  processCode,
  subjectKind,
  subjectId
]
```

Rules:

1. `DESIGN` requires `scenarioKey == "NONE"`.
2. `SEGMENT` requires a real scenario and actual segment scope ID.
3. `SEQUENCE` requires a real scenario and a deterministic ordered-segment sequence identity.
4. `processCode/subjectKind/subjectId` must match the code-owned process binder.
5. UI selection never changes the key implicitly.

## 3. Exact numeric types

Engineering kernels MUST use exact decimal/rational representations for persisted scalar inputs and deterministic conservative intervals for bounded functions.

```dart
final class Elv5Decimal {
  final BigInt unscaled;
  final int scale;
}

final class Elv5Rational {
  final BigInt numerator;
  final BigInt denominator; // > 0, normalized
}

final class Elv5Interval<T> {
  final T min;
  final T max;
}
```

String-to-number parsing is strict and locale-independent. IEEE double MAY be used internally only inside an explicitly versioned bounded backend whose returned interval encloses the true value. UI formatting/rounding MUST NOT be reused as engineering arithmetic.

Signed values are allowed only where the process contract permits them, including coordinates, dBm and signed margins. Duration, capacity, physical loss, current and count remain nonnegative.

Pool/device integer capacities use the process-defined one-time conservative ceiling after exact aggregation; per-member UI rounding is forbidden.

## 4. Evaluation result model

Every process output MUST preserve the four independent state axes.

```dart
final class Elv5DimensionResult {
  final String dimensionCode;
  final Elv5Completion completion;
  final Elv5Assessment assessment;
  final Map<String, Object?> values;
  final List<Elv5Finding> findings;
}

final class Elv5EvaluationRecord {
  final String evaluationId;
  final Elv5EngineeringNodeKeyV3 nodeKey;
  final String algorithmVersion;
  final String inputSchemaVersion;
  final String outputSchemaVersion;
  final String numericBackendVersion;
  final String inputFingerprint;
  final String policyFingerprint;
  final Elv5Execution execution;
  final Elv5Completion completion;
  final Elv5Assessment assessment;
  final List<Elv5DimensionResult> dimensions;
  final List<Elv5ConsumedEvidenceRef> consumedEvidence;
  final List<Elv5CalculationStep> steps;
  final List<Elv5Finding> findings;
  final String outputHash;
  final DateTime completedAtUtc;
}
```

`FAILED` execution means the kernel/runtime did not produce a valid engineering evaluation. A completed engineering violation is `execution=SUCCEEDED`, `completion=COMPLETE`, `assessment=FAIL`.

Required-dimension aggregation:

- COMPLETE only when every required dimension is COMPLETE;
- BLOCKED when no valid evaluation can be made because a mandatory fact/policy/model is absent or unsupported;
- PARTIAL when at least one useful dimension is valid but not all required dimensions are complete;
- PASS only when every required assessable positive dimension passes and no required dimension is unresolved/not-assessed;
- FAIL when at least one required evaluated dimension violates its threshold/model;
- UNRESOLVED when required evidence exists insufficiently to decide PASS/FAIL;
- NOT_ASSESSED is allowed only for dimensions explicitly outside the process claim scope.

Freshness is not stored inside the immutable record; it is pointer state.

## 5. Process definition interface

Each of the 27 definitions MUST implement one typed definition contract. Dynamic maps may exist only at the wire/storage boundary.

```dart
abstract interface class Elv5ProcessDefinition<TInput, TOutput> {
  String get processCode;
  Elv5Discipline get discipline;
  String get algorithmVersion;
  String get inputSchemaVersion;
  String get outputSchemaVersion;
  Set<String> get requiredDimensionCodes;

  Elv5InputResolution<TInput> resolveInput(
    Elv5CapturedProjectContext context,
    Elv5ProcessRequest request,
  );

  TOutput calculate(TInput input);

  Elv5EvaluationDraft evaluateOutput(
    TInput input,
    TOutput output,
  );
}
```

The runtime registry MUST be total and exact:

```dart
abstract interface class Elv5ProcessRegistry {
  Elv5ProcessDefinition<Object, Object> require(String processCode);
  Iterable<String> get processCodes; // exactly 27
  void validateGraph();
}
```

Startup/CI registry validation fails on:

- missing or duplicate process code;
- unknown upstream code;
- unknown scope/subject binder;
- invalid process-scope compatibility;
- dependency cycle;
- required dimension missing from process definition;
- algorithm/input/output version absent;
- machine dependency derived from free-text notes.

## 6. Input resolution contract

Input resolution is a first-class stage and MUST be deterministic over one captured revision context.

```dart
sealed class Elv5InputResolution<T> {}

final class Elv5ResolvedInput<T> extends Elv5InputResolution<T> {
  final T value;
  final Elv5ConsumedFacts consumedFacts;
}

final class Elv5BlockedInput<T> extends Elv5InputResolution<T> {
  final List<Elv5MissingDependency> missing;
  final String fingerprint;
}

final class Elv5UnsupportedInput<T> extends Elv5InputResolution<T> {
  final String modelCode;
  final String reasonCode;
  final String fingerprint;
}
```

A missing input is still represented in dependency keys. Therefore later creation/binding of that fact invalidates the previously blocked pointer.

`consumedFacts` MUST include all set memberships whose addition/removal can change the result. Fingerprinting only currently present rows is insufficient.

## 7. Discipline policy edition

```dart
final class Elv5PolicyEditionRef {
  final String policyCode;
  final String editionId;
  final String contentHash;
}

final class Elv5PolicyEdition {
  final Elv5PolicyEditionRef ref;
  final Elv5PolicySourceStatus sourceStatus;
  final Set<String> applicableProcessCodes;
  final Set<Elv5ScopeKind> applicableScopes;
  final Map<String, Object?> typedParameters;
  final String schemaVersion;
}
```

Policy adoption never mutates an existing edition. It changes a revision-scoped binding to another immutable exact edition. No `latest` lookup is allowed during calculation/replay/frozen reads.

## 8. Strict ELV5 wire envelope

ELV5 MUST copy the **behavioral discipline**, not the schema identity, of accepted ELV4 wire dispatch. ELV4 schemas stay untouched.

New schema:

```text
electra.elv5-discipline-command.v1
```

Payload schema version for the initial command family:

```text
1
```

Exact top-level fields:

```text
schema
operation
payloadSchemaVersion
projectId
designRevisionId
commandId
expectedDesignRowRevision
expectedRows
reviewedImpactFingerprint
payload
```

Unknown/missing top-level fields fail before any DB access. Unknown schema/operation/version tuple fails closed. `reviewedImpactFingerprint` is mandatory for every durable ELV5 mutation and calculation publication command.

ELV5 revision freeze/create-next continue to use the accepted ELV4 revision command family. ELV5 extends the underlying revision service transactionally; it MUST NOT create competing freeze/create-next public commands.

## 9. Exact 16-operation public ELV5 command surface

The initial discipline schema registers exactly these operations:

```text
BIND_DISCIPLINE_POLICY
ADOPT_DISCIPLINE_POLICY
RELEASE_DISCIPLINE_POLICY
REPLACE_CAMERA_STREAMS
REPLACE_RECORDING_ASSIGNMENTS
REPLACE_RECORDER_ASSIGNMENTS
REPLACE_LINK_COMPOSITION
REPLACE_PORT_CAPACITY_ASSIGNMENTS
REPLACE_OPTICAL_LINK_ASSIGNMENTS
REPLACE_RACK_CAPACITY_BASIS
REPLACE_PATCH_PANEL_ASSIGNMENTS
REPLACE_DOOR_ROLE_ASSIGNMENTS
REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS
REPLACE_FIRE_LOOP_ASSIGNMENTS
REPLACE_NOTIFICATION_CIRCUIT_ASSIGNMENTS
CALCULATE_DISCIPLINE_PROCESS
```

### 9.1 Ownership rule

These operations may write only revision-scoped ELV5 aspects, non-owning assignments, dependency rows, immutable evaluations/pointers, history and ledger rows. They do not modify canonical ELV3 cable/resource/run identities, canonical component ports, ELV4 power source graph or immutable reference editions.

### 9.2 Required payload keys

Payload codecs MUST require exact key sets.

| Operation | Exact payload keys |
|---|---|
| `BIND_DISCIPLINE_POLICY` | `bindingId`, `subject`, `processCodes`, `definitionRef`, `applicability` |
| `ADOPT_DISCIPLINE_POLICY` | `bindingId`, `newDefinitionRef`, `applicability` |
| `RELEASE_DISCIPLINE_POLICY` | `bindingId`, `releasePolicy` |
| `REPLACE_CAMERA_STREAMS` | `cameraId`, `streams` |
| `REPLACE_RECORDING_ASSIGNMENTS` | `poolId`, `horizon`, `assignments`, `scheduleSegments`, `sizingBasis` |
| `REPLACE_RECORDER_ASSIGNMENTS` | `recorderId`, `accountingBasis`, `assignments` |
| `REPLACE_LINK_COMPOSITION` | `linkId`, `orderedSections`, `policyBindingId` |
| `REPLACE_PORT_CAPACITY_ASSIGNMENTS` | `switchId`, `assignments`, `sparePolicyRef` |
| `REPLACE_OPTICAL_LINK_ASSIGNMENTS` | `linkId`, `forwardOptics`, `reverseOptics`, `connectorEvents`, `spliceEvents` |
| `REPLACE_RACK_CAPACITY_BASIS` | `rackId`, `capacityBasis`, `equipmentIds`, `excludedCapacity`, `policyRef` |
| `REPLACE_PATCH_PANEL_ASSIGNMENTS` | `panelId`, `assignments`, `sparePolicyRef` |
| `REPLACE_DOOR_ROLE_ASSIGNMENTS` | `doorAssemblyId`, `topologyProfileRef`, `roleAssignments` |
| `REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS` | `controllerId`, `resourceAssignments`, `reservePolicyRef` |
| `REPLACE_FIRE_LOOP_ASSIGNMENTS` | `loopId`, `deviceAssignments`, `addressDomain`, `topologyProfileRef` |
| `REPLACE_NOTIFICATION_CIRCUIT_ASSIGNMENTS` | `circuitId`, `deviceAssignments`, `outputRef`, `policyRef` |
| `CALCULATE_DISCIPLINE_PROCESS` | `scope`, `processCodes`, `subjects`, `expectedPointerGenerations` |

Nested objects have dedicated typed codecs. A top-level exact-key check is necessary but not sufficient.

### 9.3 Critical nested identities

Minimum identity rules:

- camera stream identity: `(cameraId, encodedStreamId)`;
- recording identity: `(encodedStreamId, poolId, copyRole)`;
- link section identity: `(linkId, ordinal, realizedSectionId)` with no duplicate realized section unless the process contract explicitly models a repeated traversal;
- physical switch/panel port assignment: canonical `portId` unique within active assignment set;
- optical event identity: canonical connector-pair/splice event ID, not connector-end count;
- door role assignment: `(doorAssemblyId, roleCode, slot)` under topology profile multiplicity;
- controller resource claim: canonical channel/input/output ID plus assignment role;
- fire address claim: explicit expanded `(addressDomain, address)` set or deterministic versioned expansion whose cardinality equals declared consumption;
- notification assignment: canonical device/output/circuit identity.

## 10. Semantic adapter and backend interface

Public JSON decoding and DB mutation MUST be separated.

```dart
abstract interface class Elv5WireSemanticCodec<TResult> {
  Elv5WireCommandKey get key;
  Future<TResult> execute(
    Elv5WireCommandEnvelope envelope,
    Elv5ResolvedWireImpact impact,
  );
}

abstract interface class Elv5WireRuntimeBackend<TResult> {
  Future<TResult> bindDisciplinePolicy(...);
  Future<TResult> adoptDisciplinePolicy(...);
  Future<TResult> releaseDisciplinePolicy(...);
  Future<TResult> replaceCameraStreams(...);
  Future<TResult> replaceRecordingAssignments(...);
  Future<TResult> replaceRecorderAssignments(...);
  Future<TResult> replaceLinkComposition(...);
  Future<TResult> replacePortCapacityAssignments(...);
  Future<TResult> replaceOpticalLinkAssignments(...);
  Future<TResult> replaceRackCapacityBasis(...);
  Future<TResult> replacePatchPanelAssignments(...);
  Future<TResult> replaceDoorRoleAssignments(...);
  Future<TResult> replaceControllerResourceAssignments(...);
  Future<TResult> replaceFireLoopAssignments(...);
  Future<TResult> replaceNotificationCircuitAssignments(...);
  Future<TResult> calculateDisciplineProcess(...);
}
```

Runtime startup MUST prove one codec for every registered operation and no extra codec.

The server-side impact resolver reloads mutable state and produces:

```dart
final class Elv5ResolvedWireImpact {
  final Map<String, int> verifiedRows;
  final List<String> oldDependencyRefs;
  final List<String> newDependencyRefs;
  final String reviewedImpactFingerprint;
}
```

Dependency/impact sets are never trusted from the wire payload.

## 11. Replay-first mutation protocol

Every public command uses this order:

```text
1. Decode exact envelope/schema/operation/version.
2. Validate commandId syntax and immutable request hash.
3. Open transaction.
4. Lookup command ledger by (projectId, commandId).
5. If existing successful command with same request hash: return stored response.
6. If existing commandId with different request hash: COMMAND_PAYLOAD_CONFLICT.
7. Only now load mutable revision/aggregate state.
8. Resolve and compare expectedDesignRowRevision / expectedRows.
9. Resolve server-side old/new impact closure and compare reviewedImpactFingerprint.
10. Validate ownership, FK scope, policy edition and semantic payload.
11. Apply root/member replacement atomically.
12. Invalidate union(oldClosure,newClosure).
13. Append complete forward/inverse history and cursor mutation.
14. Persist ledger response/result hash.
15. Commit.
```

Replay MUST precede mutable preconditions so a response-loss retry remains successful even after the first execution changed revisions/generations.

## 12. Persistence identities

The implementation MUST provide isolated discipline storage. Exact Drift class names may differ, but equivalent constraints are required.

### 12.1 Mutable revision-scoped roots

```text
DisciplinePolicyBindings
CameraStreamBindings
RecordingAssignments
RecordingScheduleSegments
RecorderAssignments
LinkSectionAssignments
PortCapacityAssignments
OpticalLinkAssignments
RackCapacityBindings
PatchPanelAssignments
DoorCalculationAssignments
ControllerResourceAssignments
FireLoopDeviceAssignments
NotificationCircuitAssignments
```

Every revision-owned root has:

```text
projectId
designRevisionId
logicalId
rowRevision
createdAtUtc
updatedAtUtc
```

Child rows carry composite FKs to the revision/root where SQLite supports the intended integrity; otherwise an equivalent transactionally verified parent constraint plus acceptance proof is mandatory. Canonical foreign IDs are validated against the same project/revision ownership rules.

### 12.2 Immutable evaluations

`DisciplineEvaluationRecords` are append-only. Unique identity is `evaluationId`; node key + generation/version fields are indexed, not used to mutate old evidence.

`DisciplineEvaluationPointers` are mutable current/stale locators keyed by the complete `Elv5EngineeringNodeKeyV3`.

Pointer minimum fields:

```text
nodeKey
evaluationId nullable
freshness
pointerGeneration
inputFingerprint nullable
updatedAtUtc
```

A blocked/unresolved process MAY have an immutable evaluation explaining why, but CURRENT still means current-for-those-inputs, not PASS.

## 13. Capture → pure run → guarded publish

Long calculations MUST NOT hold the write transaction.

```text
A. CAPTURE
   short read transaction
   - verify lifecycle/token/revision
   - resolve exact policies/facts/upstream evidence
   - capture pointer generations
   - compute canonical input fingerprint

B. PURE RUN
   no database writes
   - resolve typed input from captured context
   - execute deterministic kernel
   - build immutable evaluation draft

C. PUBLISH
   short write transaction
   - recheck revision lifecycle/token
   - recheck every consumed row/version/set marker
   - recheck every consumed pointer generation
   - recheck input fingerprint
   - insert immutable evaluation
   - CAS pointers as one coherent batch
   - update dependency reverse index
```

Any mismatch returns a stale/conflict outcome. A late publisher after freeze MUST NOT create CURRENT pointers for the frozen working revision.

## 14. Dependency keys

Dependency keys are code-owned canonical strings/typed values. They MUST distinguish at least:

```text
FACT/<owner>/<kind>/<id>/<field-or-membership>
SET/<owner>/<kind>/<scopeId>/<membershipKind>
POLICY/<policyCode>/<editionId>/<hash>
EVAL/<owner>/<nodeKey>/<evaluationId>/<outputHash>
POINTER/<owner>/<nodeKey>/<generation>
MISSING/<kind>/<expectedIdentity>
```

Invalidation uses union of old and new closures. Set keys ensure member insertion/removal invalidates dependent calculations even when the changed member did not exist in the previous result.

Cross-owner ELV4 evidence dependency records exact immutable evaluation ID, node key, input/output hash, algorithm/numeric version and pointer generation used during capture.

No dependency cycle may cross back from ELV5 numerical output into physical ELV4 source solving. ELV5 wrappers consume ELV4 evidence; they do not create a physical feedback loop.

## 15. Calculation request/result API

```dart
final class Elv5ProcessRequest {
  final String projectId;
  final String designRevisionId;
  final Elv5ScopeRef scope;
  final List<String> processCodes;
  final List<Elv5SubjectRef> subjects;
  final Map<String, int> expectedPointerGenerations;
}

sealed class Elv5CalculateResult {}

final class Elv5CalculatePublished extends Elv5CalculateResult {
  final List<String> evaluationIds;
  final Map<String, int> pointerGenerations;
}

final class Elv5CalculateConflict extends Elv5CalculateResult {
  final String conflictCode;
}

final class Elv5CalculateRejected extends Elv5CalculateResult {
  final String reasonCode;
}
```

`BLOCKED`, `PARTIAL`, `FAIL` and `UNRESOLVED` are valid published engineering evaluations when produced deterministically from current captured facts. They are not command-level rejection unless input cannot even be decoded/bound to a legal subject/scope.

## 16. Failure taxonomy

Stable machine-readable error/reason codes are required. Initial minimum set:

```text
ELV5_UNSUPPORTED_SCHEMA
ELV5_UNSUPPORTED_OPERATION
ELV5_PAYLOAD_FIELDS_MISMATCH
ELV5_PAYLOAD_SEMANTIC_INVALID
ELV5_COMMAND_PAYLOAD_CONFLICT
ELV5_EXPECTED_ROWS_CONFLICT
ELV5_STALE_REVIEWED_IMPACT
ELV5_REVISION_NOT_WORKING
ELV5_REVISION_TOKEN_CONFLICT
ELV5_FOREIGN_PROJECT_REFERENCE
ELV5_POLICY_NOT_BOUND
ELV5_POLICY_EDITION_MISMATCH
ELV5_UNSUPPORTED_MODEL
ELV5_MISSING_REQUIRED_INPUT
ELV5_POINTER_GENERATION_CONFLICT
ELV5_CAPTURE_STALE
ELV5_PUBLISH_AFTER_FREEZE
ELV5_NOT_CAPTURED
```

Do not expose raw SQLite exception text as a public semantic result.

## 17. Freeze and create-next integration

ELV5 extends the accepted revision lifecycle rather than replacing it.

Freeze adds a versioned discipline section containing:

- exact mutable ELV5 aspect roots/children;
- exact policy refs/hashes;
- exact dependency-relevant canonical refs;
- selected immutable discipline evaluation refs/hashes/pointer generations;
- `disciplineHash` in the extended manifest.

Old snapshots with no discipline section return `ELV5_NOT_CAPTURED`; `CAPTURED_EMPTY` is a distinct new-format state.

Create-next remaps all revision-owned ELV5 roots/children to the new revision while canonical external IDs remain governed by their existing remapping rules. Current pointers for the new revision are regenerated/invalidated from remapped inputs; old immutable evaluations stay attached to old provenance and are never retagged.

## 18. UI query contract

The workspace reads a projection, never raw tables.

```dart
final class Elv5ProcessCardVm {
  final String processCode;
  final Elv5SubjectRef subject;
  final Elv5ScopeRef scope;
  final Elv5Freshness freshness;
  final Elv5Completion completion;
  final Elv5Assessment assessment;
  final Elv5Execution execution;
  final List<Elv5DimensionResult> dimensions;
  final List<Elv5CalculationStep> steps;
  final List<Elv5Finding> findings;
  final List<Elv5EvidenceVm> provenance;
  final Elv5SharedSourceVm? sharedSource;
}
```

Shared-source cards MUST show both full physical-project total and selected discipline contribution from the same ELV4 evidence. The UI may filter presentation but MUST NOT request or publish a reduced physical source graph as if it were the global budget.

## 19. Process-to-store ownership map

The 27 algorithms consume the following ELV5-owned aspects in addition to canonical external facts:

| Process group | ELV5-owned mutable aspects |
|---|---|
| CCTV-01 | policy binding only; camera geometry remains canonical external fact |
| CCTV-02 | camera streams, recorder/network subscription assignments |
| CCTV-03 | recording assignments + schedule segments + sizing basis |
| CCTV-04 | policy/context binding only; ELV4 PoE evidence is external immutable evidence |
| CCTV-05 | recorder assignments/accounting basis + CCTV-02/03 evidence |
| CCTV-06 | link composition/policy binding + ELV4 PoE evidence when applicable |
| LAN-01/04 | link composition + policy binding |
| LAN-02 | switch port capacity assignments + spare policy |
| LAN-03 | policy/context binding only; ELV4 PoE evidence |
| LAN-05 | optical link assignment + exact optics/events |
| LAN-06 | rack capacity basis + non-owning equipment membership |
| LAN-07 | patch-panel assignments + spare policy |
| ACS-01/06 | door role assignments + topology profile |
| ACS-02 | controller resource assignments + reserve policy |
| ACS-03/04/05 | discipline policy/context + exact ELV4 power evidence/loads as registered |
| FA-01/02/03/07/08 | fire loop device/address assignments + topology/policy refs |
| FA-04/05 | discipline policy/context + complete ELV4 physical evidence |
| FA-06 | notification-circuit assignments + exact power evidence |

Any implementation that introduces a second canonical cable, port, component, source or battery identity to satisfy this table violates the contract.

## 20. Acceptance obligations at code level

P1/P2/P7/P8 MUST add tests that prove, at minimum:

1. exactly 27 process definitions and exactly 16 ELV5 command codecs;
2. missing/extra codec registration fails startup/test construction;
3. every command rejects missing/unknown top-level and payload fields;
4. response-loss replay succeeds after first execution changed row revisions;
5. same command ID with different payload is rejected;
6. reviewed impact is server-resolved and stale fingerprint fails before mutation;
7. replacement commands invalidate union(old,new) dependency closures;
8. file-SQLite reopen preserves every root/child/evaluation/pointer/history/ledger identity;
9. pointer generation CAS prevents stale publication;
10. freeze racing publication cannot revive CURRENT after freeze;
11. create-next remaps all ELV5 revision-owned roots without retagging old immutable evaluations;
12. legacy snapshot returns `ELV5_NOT_CAPTURED`, not empty/pass;
13. mixed legacy/ELV4/ELV5 result dispatch never decodes one owner as another;
14. blocked missing-input result is invalidated when the missing fact later appears;
15. shared PoE/battery/source wrappers show one physical evaluation plus discipline contribution, never duplicated demand;
16. every one of 27 POS/NEG process oracles executes through public setup + real persistence + registry dispatch;
17. audit counterexamples remain regression tests: sub-byte pool ceiling, estimate-vs-guarantee, optical overload, overlapping fire address sets, recorder accounting basis, gross/net rack basis and FOV required dimensions;
18. no PASS from unsupported model, missing required dimension, fictional policy compliance claim or ELV6/7/8-owned conclusion.

## 21. Definition of ready-to-implement

ELV5 may move from design-only to runtime P1/P2 implementation only when all of the following are frozen in specification:

- this code-level contract is linked from the authoritative index and package index;
- the 16-operation registry is reflected in P1/P2 acceptance assertions;
- process registry and process contracts agree on 27 codes, scopes, binders and required dimensions;
- exact payload examples exist for all 16 operations;
- Drift migration target is selected from implementation HEAD above accepted schema 23;
- qualification manifest names exact public commands/fixtures for all 27 POS/NEG oracles;
- no open contradiction remains between ELV5 assignment ownership and ELV3/ELV4 canonical ownership.

Until then the branch remains `DESIGN DRAFT / RUNTIME NOT STARTED`.
