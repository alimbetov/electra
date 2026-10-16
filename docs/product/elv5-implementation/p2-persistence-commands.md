# P2 — Persistence, command boundaries and revision evidence

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: P1 contracts plus evidenced shared platform.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md).

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

Add isolated DisciplineEvaluationRecords/DisciplineEvaluationPointers and a discipline reverse index; preserve existing power stores and ProjectDerivedResults. See baseline P2 for explicit dispatch, transactional extension and compatibility proof.

Proposed roots: DisciplinePolicyBindings, CameraStreamBindings, RecordingAssignments, RecordingScheduleSegments, LinkSectionAssignments, PortCapacityAssignments, DoorCalculationAssignments and FireLoopDeviceAssignments. Common scope PK is (designRevisionId,logicalId); project and canonical entity ownership are verified transactionally/compositely. Unique scoped stream IDs, assignments, loop address ranges and resource memberships are enforced. Raw schemas are implementation targets, not existing tables.

Bind/adopt/release policy, replace stream/recording/link/port/door/fire assignments and calculate commands use explicit project/revision/command IDs, typed payload/schema/hash, expected design/row revisions and reviewed impact. Existing topology/assembly/catalog mutations remain canonical owners. No widget multi-table writes or nested independent commit.

Freeze serializes required canonical/reference/geometry/path/scenario/policy facts plus selected immutable results in the same revision transition. Physical/power hashes retain their meaning; new versioned manifest includes disciplineHash. Old snapshots return ELV5_NOT_CAPTURED, distinct from CAPTURED_EMPTY. Capture/calculation/publish uses pure stage and short guarded transactions; late publisher after freeze conflicts. The inherited schema is 23; select an additive version above 23 from implementation HEAD and test real v21/v22 plus merged v23 origins. Preserve old manifest v1/power section v2 byte/hash semantics through explicit new manifest dispatch.

## Exit

P2 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.
