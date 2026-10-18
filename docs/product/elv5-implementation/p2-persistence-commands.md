# P2 — Persistence, command boundaries and revision evidence

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P1 contracts plus evidenced shared platform.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [code-level runtime contract](code-level-runtime-contract.md); [schema 24 contract](persistence-schema-contract.md); [hardening amendments](code-level-hardening-amendments.md).

Inherited implementation and mandatory new extensions: [baseline contract P2](implemented-baseline.md#p2); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P2-001 | Add schema-24 revision-scoped calculation roots and normalized FK-bearing assignment children | P2-T01 |
| ELV5-P2-002 | Add isolated discipline records/pointers and schema dispatch preserving legacy and dedicated ELV4 stores | P2-T02 |
| ELV5-P2-003 | Implement 16 typed mutation/publication commands with canonical request hash, replay-first ledger, aggregate CAS and reviewed shared impact | P2-T03 |
| ELV5-P2-004 | Commit aspect/assignment edits, old+new invalidation, shared history and ledger atomically | P2-T04 |
| ELV5-P2-005 | Persist immutable discipline evaluations and guarded coherent DESIGN/SEGMENT/SEQUENCE current pointers | P2-T05 |
| ELV5-P2-006 | Extend coordinated snapshot manifest with versioned discipline section and legacy NOT_CAPTURED outcome | P2-T06 |
| ELV5-P2-007 | Materialize create-next with typed physical/assignment remapping and shared revision allocator | P2-T07 |
| ELV5-P2-008 | Persist complete forward/inverse history with revision-local cursor, restart-safe redo and file-SQLite migration evidence | P2-T08 |

## Concrete contract

P2 implements the concrete [Drift schema 24 persistence contract](persistence-schema-contract.md), not an implementation-defined equivalent. The exact generated Drift class names may vary only where semantic ownership/keys/indexes/FKs remain equivalent and P2 acceptance proves the equivalence.

The initial public discipline wire family is exactly `electra.elv5-discipline-command.v1`, payload version 1, with **16 registered operations**. ELV4 revision `FREEZE_DESIGN_REVISION` and `CREATE_NEXT_WORKING_DESIGN_REVISION` remain the only public revision commands. ELV5 integrates into those transactions and does not add duplicate revision endpoints.

The machine authority for exact key sets is [command-registry.json](command-registry.json). Three hardened operations are additionally explained by [code-level-hardening-amendments.md](code-level-hardening-amendments.md):

```text
REPLACE_CAMERA_STREAMS
REPLACE_RECORDING_ASSIGNMENTS
REPLACE_DOOR_ROLE_ASSIGNMENTS
```

## Schema 24 roots and children

P2 adds revision-scoped ELV5 ownership equivalent to:

```text
DisciplinePolicyBindings
CameraStreamBindings
CameraStreamSubscriptions
RecordingPoolBindings
RecordingAssignments
RecordingScheduleSegments
RecorderCapacityBindings / recorder accounting binding
RecorderAssignments
LinkCompositionBindings
LinkSectionAssignments
PortCapacityBindings
PortCapacityAssignments
OpticalLinkBindings
OpticalLossEvents
RackCapacityBindings
RackEquipmentMemberships
PatchPanelBindings
PatchPanelAssignments
DoorCalculationBindings
DoorRoleAssignments
DoorReleaseTruthRows
ControllerResourceBindings
ControllerResourceAssignments
FireLoopBindings
FireLoopDeviceAssignments
FireAddressClaims
NotificationCircuitBindings
NotificationCircuitAssignments
DisciplineEvaluationRecords
DisciplineEvaluationPointers
DisciplineDependencyIndex
DesignRevisionDisciplineSnapshots
```

Canonical nested identities remain mandatory: `(cameraId,encodedStreamId)`, `(cameraId,subscriptionId)`, `(encodedStreamId,poolId,copyRole)`, ordered realized link sections, unique canonical port/resource claims, connector-pair/splice event identity, door role slot identity, door release cause identity and full expanded fire `(addressDomain,address)` claims.

### Ownership constraints

ELV5 must not become canonical owner of cable, port, component, source, battery or revision identities. Specifically forbidden duplicate ownership concepts include:

```text
DisciplineCables
DisciplinePorts
DisciplineComponents
DisciplinePowerSources
DisciplineBatteryBanks
DisciplineProjectRevisions
DisciplineCommandHistoryCursor
DisciplineCommandLedger
```

Recorder/VMS device capability remains owned by the exact immutable catalog/component definition edition. The ELV5 recorder aspect owns accounting basis and non-owning assignments and captures the exact definition ref/hash needed by the kernel. If resolved limits are persisted for read performance, they are an immutable non-authoritative captured projection and cannot be independently edited.

## Strict command semantics

Every ELV5 envelope has the exact fields:

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

Unknown/missing top-level or operation payload fields fail closed. Nested objects have typed strict codecs. `normalizedPayloadSha256` is the semantic request hash from `electra.canonical-json.v1`, not raw JSON text hashing.

The semantic adapter resolves changed dependencies and reviewed impact from server-side state. Dependency refs supplied by a client are not authoritative input. `reviewedImpactFingerprint` and expected rows are compared against reloaded state immediately before mutation.

Replay order is normative:

1. strict decode and canonical semantic request hash;
2. open transaction;
3. command-ledger lookup by `(projectId,commandId)`;
4. same request hash returns stored logical response;
5. different request hash returns payload conflict;
6. only then load mutable revision/aggregate state and CAS expectations;
7. resolve server-side old/new impact and reviewed fingerprint;
8. validate canonical foreign ownership/policies/nested semantics;
9. mutate root/members atomically;
10. invalidate union(old,new) closure;
11. append complete forward/inverse shared revision history and cursor;
12. save ledger response/hash;
13. commit.

This ordering is required so response-loss replay remains successful after the first committed execution changed row revisions or pointer generations.

## Hardened aggregate details

### Camera streams

One `REPLACE_CAMERA_STREAMS` replaces stream profiles **and explicit directed subscriptions** for its aggregate. Subscription path identities participate in dependency old/new closure. Payload bitrate never becomes physical wire-rate capacity by silent default; exact transport overhead model reference is captured when such comparison is claimed.

### Recording

One `REPLACE_RECORDING_ASSIGNMENTS` atomically replaces:

```text
UTC horizon
temporal policy: IANA zone + tzdb + DST gap/overlap rule
sizing basis
reserve multiplier
redundancy model/ref
policy ref
recording assignments
schedule segment set
```

No host timezone default or hidden reserve/redundancy model may enter calculation.

### ACS door aggregate

One `REPLACE_DOOR_ROLE_ASSIGNMENTS` atomically replaces topology profile, lock safety mode, role assignments and technical release truth table. The release table is dependency-relevant engineering input but is not an ELV7 compliance certificate.

## Immutable evaluations and pointers

`DisciplineEvaluationRecords` are append-only and store exact node key, process/algorithm/input/output/numeric/canonical-encoder versions, input/policy fingerprints, independent execution/completion/assessment state, required dimensions, typed output projection, structured steps/findings, consumed evidence refs and deterministic output hash.

`DisciplineEvaluationPointers` are keyed by complete `engineering-node-v3` identity and contain `evaluationId?`, CURRENT/STALE freshness, pointer generation, current input fingerprint/output hash and update metadata. CURRENT never implies PASS.

Calculation uses capture → pure run → guarded publication. Publication revalidates lifecycle/token, every consumed row/set marker, every consumed upstream pointer generation and the canonical input fingerprint.

For one `CALCULATE_DISCIPLINE_PROCESS` request targeting several nodes, publication is **all-or-nothing for the requested coherent batch**. If any requested target or consumed dependency fails revalidation/CAS, no requested node from that command becomes CURRENT.

## Dependency reverse index

The reverse index uses code-owned dependency kinds and canonical key bytes/hash:

```text
FACT
SET
POLICY
EVAL
POINTER
MISSING
```

Set insertion/removal and creation of previously missing input must invalidate dependants even if no old concrete row existed. Replacement invalidates `union(oldClosure,newClosure)`.

## Freeze and create-next

Freeze serializes the complete active ELV5 roots/children needed for historical interpretation, exact policy refs/hashes, dependency-relevant canonical references and selected immutable result refs/hashes/generations. The new manifest contains `disciplineHash` without changing old physical/power hash meaning.

Old snapshots without discipline section return `ELV5_NOT_CAPTURED`; a schema-24/new-format empty discipline section is `CAPTURED_EMPTY`.

Create-next remaps every revision-owned ELV5 root/child and typed physical/assignment reference through the shared allocator/identity map. New-revision pointers are regenerated/stale as defined; old immutable evaluations remain attached to old provenance and are never retagged.

## Migration

The inherited accepted DB schema is **23**. ELV5 implementation target is frozen as additive **schema 24**.

P2 migration tests use real file SQLite and prove at least:

- fresh 24 database;
- accepted 23 → 24 preserving ELV3/ELV4 identities/hashes;
- supported historical origin → existing chain → 23 → 24;
- failed migration rollback/reopen;
- exact table/index/constraint inventory;
- root/member/evaluation/pointer/dependency/snapshot close/reopen;
- legacy snapshot versus CAPTURED_EMPTY distinction.

Migration success is not established solely by `PRAGMA user_version = 24`.

## Shared ledger/history reuse

P2 MUST reuse existing `ElvCommandLedgerStore` replay semantics and the existing ELV revision aggregate/history/cursor platform. No second ELV5 undo/redo platform exists.

Replacement commands store enough before/after member state to undo/redo after restart. Hash-only redo is not accepted.

## Exit

P2 runtime acceptance requires P2-T01…T08 at one accepted source SHA plus schema-24 file-SQLite migration/restart evidence.

P2 implementation entry now requires no further choice of migration number: schema **24** and its semantic persistence plan are frozen. Remaining entry work is executable source implementation and migration fixtures, not design selection.
