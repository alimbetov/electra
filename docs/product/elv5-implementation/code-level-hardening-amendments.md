# ELV5 — Code-level hardening amendments

Status: DESIGN DRAFT / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`

Authority: this document is a **normative amendment** to `code-level-runtime-contract.md` and `persistence-schema-contract.md`. Where the older contract text conflicts with the exact hardened rules below, this amendment governs. No public operation count or wire schema identity changes: the initial ELV5 family remains exactly 16 operations under `electra.elv5-discipline-command.v1`, payload schema version 1, because no ELV5 runtime has shipped.

## 1. Why an amendment is required

The second-pass engineering audit introduced three pieces of state that must be writable/reproducible but were absent from the initial exact payload-key table:

1. CCTV-02 explicit directed stream subscriptions and optional transport-overhead model reference;
2. CCTV-03 deterministic temporal policy plus reserve/redundancy/policy provenance;
3. ACS-06 lock safety mode and technical release truth table.

Leaving those only in typed inputs would create an impossible implementation contract: runtime could resolve fields that no public command can persist. This amendment closes that mismatch.

## 2. Superseding exact payload-key rows

The following three rows **replace** their corresponding rows in section 9.2 of `code-level-runtime-contract.md`. All other 13 operation key sets remain unchanged.

| Operation | Exact payload keys |
|---|---|
| `REPLACE_CAMERA_STREAMS` | `cameraId`, `streams`, `subscriptions`, `transportOverheadModelRef` |
| `REPLACE_RECORDING_ASSIGNMENTS` | `poolId`, `horizon`, `temporalPolicy`, `assignments`, `scheduleSegments`, `sizingBasis`, `reserveMultiplier`, `redundancyModel`, `policyRef` |
| `REPLACE_DOOR_ROLE_ASSIGNMENTS` | `doorAssemblyId`, `topologyProfileRef`, `safetyMode`, `roleAssignments`, `releaseTruthTable` |

The machine authority is `command-registry.json`; `command-examples.json` contains the canonical design-time examples and must match it exactly.

## 3. CCTV stream/subscription nested contract

`streams` remains a complete replacement set for one camera.

Minimum stream object:

```text
encodedStreamId
codecProfileRef
expectedBitrateBps
generic/guaranteed peak bitrate evidence as selected by the strict nested codec
```

`subscriptions` is a complete replacement set whose identity is:

```text
(cameraId, subscriptionId)
```

Each subscription must contain at least:

```text
subscriptionId
encodedStreamId
receiverId
deliveryMode
orderedNetworkEdgeIds
```

Rules:

- `encodedStreamId` must belong to the replacement camera stream set or to a legal exact existing stream identity according to the command codec;
- network-edge identity is non-owning canonical/project graph evidence;
- `UNICAST` copies are independent subscriptions;
- multicast de-duplication is legal only for a registered multicast model/tree, never from matching receiver labels;
- repeated system membership does not create a subscription;
- empty `orderedNetworkEdgeIds` is allowed only for a registered local/non-network receiver mode; otherwise semantic rejection.

`transportOverheadModelRef` is an exact immutable model ref/hash or explicit `null` if the selected process claim does not compare payload bitrate to physical wire capacity. `null` must not cause a hidden default percentage.

## 4. Additional schema-24 CCTV persistence rows

Add to `persistence-schema-contract.md` section 4 semantics:

```dart
@DataClassName('CameraStreamSubscriptionRow')
class CameraStreamSubscriptions extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get cameraId => text().references(ComponentInstances, #id)();
  TextColumn get subscriptionId => text()();
  TextColumn get encodedStreamId => text()();
  TextColumn get receiverId => text()();
  TextColumn get deliveryMode => text()();
  TextColumn get orderedNetworkEdgeIdsJson => text()();
  TextColumn get transportOverheadModelRefJson => text().nullable()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    cameraId,
    subscriptionId,
  };
}
```

If the overhead model is camera-set-wide rather than per subscription, production schema may normalize it into a `CameraStreamSetBindings` root. The semantic requirement is one exact captured model ref for the complete replacement set, not duplicated canonical network ownership.

## 5. CCTV recording nested contract

`horizon` is strict UTC start/end and contains no implicit timezone default.

`temporalPolicy` contains:

```text
timeZoneId
tzdbVersion
gapRule
overlapRule
```

`scheduleSegments` are interpreted through that exact policy when recurrence/local time is used. Absolute UTC schedule entries still retain the policy in the root because mixed/extended schedules and audit reproduction must not depend on host defaults.

`reserveMultiplier` is an exact nonnegative ratio. It is separate from uncertainty/evidence basis.

`redundancyModel` is either an exact typed model object/ref or `null`. `null` means raw-disk requirement is not assessed; it does not mean usable fraction `1` unless the selected policy explicitly defines that model.

`policyRef` is the exact immutable storage policy provenance used by this pool configuration.

These values belong to the `RecordingPoolBindings` root already defined by schema 24 and are replaced atomically with assignment/schedule members.

## 6. Recorder capability ownership clarification

The `RecorderCapacityBindings.limitsJson/limitsSha256` shown in the schema-24 design MUST NOT become a second authoritative equipment-capability store.

Normative rule:

```text
canonical recorder capability owner = exact immutable catalog/component definition edition
ELV5 recorder binding owner = accounting basis + non-owning assignments + captured definition ref/hash
```

Therefore implementation SHOULD replace the illustrative `limitsJson/limitsSha256` columns with:

```text
recorderDefinitionRefJson
recorderDefinitionSha256
```

or prove that any stored resolved limits are a non-authoritative immutable captured projection derived from that exact definition and cannot be edited independently.

CCTV-05 typed `CctvRecorderLimits` is the **resolved kernel input**, not proof that ELV5 owns those capability facts.

## 7. ACS door-release nested contract

`safetyMode` is a closed code-owned value:

```text
FAIL_SAFE
FAIL_SECURE
PROJECT_DEFINED
```

`releaseTruthTable` is a complete replacement set keyed by `(doorAssemblyId,causeCode)`.

Initial supported cause codes include at least:

```text
NORMAL_ACCESS
REQUEST_TO_EXIT
FIRE_RELEASE
EMERGENCY_BREAK_GLASS
POWER_FAILURE
```

Each row contains:

```text
causeCode
expectedOutcomeCode
requiredEvidenceRoles
```

The truth table records the project/topology profile's expected technical behavior. It must not infer behavior from device labels and must not claim ELV7 verified life-safety/egress compliance.

`DoorCalculationBindings`, `DoorRoleAssignments` and `DoorReleaseTruthRows` from schema 24 are mutated in one atomic aggregate replacement.

## 8. Canonical hashing amendment

All occurrences of `requestHash`, `inputFingerprint`, `policyFingerprint`, `outputHash`, command `normalizedPayloadSha256`, dependency-key SHA and `disciplineHash` in the initial runtime contract now refer to the canonical rules in `engineering-primitives-contract.md`.

In particular:

- raw JSON textual byte equality is not semantic equality;
- object/set order does not perturb hashes when order is not semantic;
- path/sequence order remains hash-significant;
- evaluation ID and completion timestamp do not enter deterministic output hash;
- source ref/hash, evidence basis/applicability, temporal policy and operating case enter the input fingerprint where consumed.

## 9. Batch calculation publication amendment

For one `CALCULATE_DISCIPLINE_PROCESS` request targeting multiple nodes, capture and pure execution may be parallelized, but guarded publication is one coherent atomic batch:

```text
revalidate all requested nodes
revalidate all shared consumed versions/generations
verify all expected target pointer generations
insert all immutable records
CAS/update all target pointers
replace all target reverse-index edges
commit once
```

If any requested node fails publication preconditions, **none** of the nodes from that command become CURRENT. Immutable drafts created only in memory are discarded. A design may optionally persist failed execution telemetry outside engineering evaluation/current-pointer state, but that telemetry cannot appear as a partially successful engineering publication.

## 10. Code ownership amendment

The process-specific typed API is now normative. `Map<String,Object?>` is permitted at:

```text
strict JSON codec boundary
canonical storage payload boundary
localized projection parameter boundary
```

It is not permitted as the semantic input/output type of any of the 27 production kernels.

## 11. Acceptance amendment

P8/P9 must additionally prove:

1. the three hardened payload key sets match registry, examples and runtime codecs;
2. CCTV-02 stream subscriptions survive file-SQLite restart and invalidate edge bandwidth consumers on old/new path union;
3. recording temporal policy/tzdb/reserve/redundancy provenance survives restart/freeze;
4. no host timezone default changes CCTV-03 result;
5. recorder capability is resolved from one exact immutable canonical definition, not ELV5-authored duplicate limits;
6. ACS release truth table survives restart/undo/redo and participates in dependency invalidation;
7. all-or-nothing multi-node publication is race-tested;
8. canonical hash projection tests from the primitives contract pass.

## 12. Closure rule

This amendment resolves specification contradictions only. Runtime remains NOT STARTED until source, migration 24 and executable P8 evidence implement these rules.
