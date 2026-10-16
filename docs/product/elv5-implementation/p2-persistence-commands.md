# P2 — Persistence, command boundaries and revision evidence

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: P1 contracts plus evidenced shared platform.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [code-level runtime contract](code-level-runtime-contract.md).

Inherited implementation and mandatory new extensions: [baseline contract P2](implemented-baseline.md#p2); [pinned evidence](baseline.json). This contract supersedes the original design-only parent assumptions.

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P2-001 | Add revision-scoped calculation aspects and normalized FK-bearing assignment children | P2-T01 |
| ELV5-P2-002 | Add isolated discipline records/pointers and schema dispatch preserving legacy and dedicated ELV4 stores | P2-T02 |
| ELV5-P2-003 | Implement typed mutation commands with replay-first ledger, aggregate CAS and reviewed shared impact | P2-T03 |
| ELV5-P2-004 | Commit aspect/assignment edits, old+new invalidation, history and ledger atomically | P2-T04 |
| ELV5-P2-005 | Persist immutable discipline evaluations and guarded DESIGN/SEGMENT/SEQUENCE current pointers | P2-T05 |
| ELV5-P2-006 | Extend coordinated snapshot manifest with versioned discipline section and legacy NOT_CAPTURED outcome | P2-T06 |
| ELV5-P2-007 | Materialize create-next with typed physical/assignment remapping and shared revision allocator | P2-T07 |
| ELV5-P2-008 | Persist complete forward/inverse history with revision-local cursor and restart-safe redo | P2-T08 |

## Concrete contract

Add isolated `DisciplineEvaluationRecords` / `DisciplineEvaluationPointers` and a discipline reverse dependency index; preserve existing power stores and `ProjectDerivedResults`. See baseline P2 for explicit dispatch, transactional extension and compatibility proof.

The initial public discipline wire family is exactly `electra.elv5-discipline-command.v1`, payload version 1, with the 16 registered operations fixed in the [code-level runtime contract](code-level-runtime-contract.md#9-exact-16-operation-public-elv5-command-surface). ELV4 revision `FREEZE_DESIGN_REVISION` and `CREATE_NEXT_WORKING_DESIGN_REVISION` stay the only public revision commands. ELV5 integrates into those transactions and does not add duplicate revision endpoints.

### Revision-scoped roots

P2 MUST persist equivalent roots/children for:

- DisciplinePolicyBindings;
- CameraStreamBindings;
- RecordingAssignments and RecordingScheduleSegments;
- RecorderAssignments;
- LinkSectionAssignments;
- PortCapacityAssignments;
- OpticalLinkAssignments;
- RackCapacityBindings;
- PatchPanelAssignments;
- DoorCalculationAssignments;
- ControllerResourceAssignments;
- FireLoopDeviceAssignments;
- NotificationCircuitAssignments.

Common revision-root identity is `(projectId, designRevisionId, logicalId)` with positive `rowRevision`. Project and canonical entity ownership are verified transactionally/compositely. Child rows must have effective parent/FK integrity and deterministic ordering where order is semantic. Raw schemas are implementation targets, not claims that these tables already exist.

Canonical nested identities are mandatory: `(cameraId, encodedStreamId)`, `(encodedStreamId,poolId,copyRole)`, ordered realized link sections, unique canonical port/resource claims, connector-pair/splice event identity, door role slot identity and full expanded fire `(addressDomain,address)` claims. Repeated system membership never creates a duplicate physical resource.

### Strict command semantics

Every ELV5 envelope has the exact ELV4-style top-level fields: schema, operation, payloadSchemaVersion, projectId, designRevisionId, commandId, expectedDesignRowRevision, expectedRows, reviewedImpactFingerprint and payload. Unknown/missing top-level or operation payload fields fail closed before durable mutation. Each operation has one exact payload key set and a typed nested decoder.

The semantic adapter MUST resolve changed dependencies and reviewed impact from server-side state. Dependency refs supplied by a client are not authoritative input. `reviewedImpactFingerprint` and `expectedRows` are compared against reloaded state immediately before mutation.

Replay order is normative:

1. strict decode;
2. transaction;
3. command-ledger lookup by `(projectId,commandId)` and request hash;
4. same-hash replay returns stored response;
5. different-hash replay returns payload conflict;
6. only then load mutable revision/aggregate state and CAS expectations;
7. resolve server-side old/new impact and reviewed fingerprint;
8. mutate root/members;
9. invalidate union(old,new) closure;
10. append forward/inverse history and cursor;
11. persist ledger response/hash;
12. commit.

This ordering is required so response-loss replay remains successful after the first committed execution changed row revisions or pointer generations.

### Immutable evaluations and pointers

`DisciplineEvaluationRecords` are append-only and store exact node key, process/algorithm/input/output/numeric versions, input/policy fingerprints, independent execution/completion/assessment state, required dimension outputs, structured steps/findings, consumed evidence refs and immutable output hash.

`DisciplineEvaluationPointers` are keyed by the complete `engineering-node-v3` identity and contain `evaluationId?`, CURRENT/STALE freshness, `pointerGeneration`, current input fingerprint and update timestamp. CURRENT does not imply PASS.

Calculation uses capture → pure run → guarded publication. Publication revalidates lifecycle/token, every consumed row/set marker, every consumed upstream pointer generation and input fingerprint. Immutable evaluation insert + pointer batch CAS + dependency-index update commit atomically. A mismatch returns a stale/conflict outcome; a late publisher after freeze cannot revive CURRENT.

Freeze serializes required canonical/reference/geometry/path/scenario/policy facts plus selected immutable results in the same revision transition. Physical/power hashes retain their meaning; new versioned manifest includes `disciplineHash`. Old snapshots return `ELV5_NOT_CAPTURED`, distinct from `CAPTURED_EMPTY`. Capture/calculation/publish uses pure stage and short guarded transactions; late publisher after freeze conflicts.

The inherited schema is 23; select an additive version above 23 from implementation HEAD and test real v21/v22 plus merged v23 origins. Preserve old manifest v1/power section v2 byte/hash semantics through explicit new manifest dispatch.

Create-next remaps every ELV5 revision-owned root/child and all typed physical/assignment references using the shared allocator/identity map. New revision pointers are regenerated or stale from the remapped facts; old immutable evaluations remain attached to old provenance and are never retagged.

Complete forward/inverse history is durable. Replacement commands store enough old and new member payload to undo/redo after restart; schema/hash-only redo is not accepted.

## Exit

P2 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

P2 implementation entry additionally requires: exact payload examples for all 16 operations; selected migration number above accepted schema 23; concrete Drift PK/FK/index proposal; explicit command-ledger request/response hash schema; pointer-generation CAS test design; and freeze/create-next migration fixtures.
