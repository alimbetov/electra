# Electra — ELV3 P7-P9 Foundation Design

Status: IMPLEMENTATION-READY FOUNDATION / NOT RUNTIME CLOSURE  
Branch: `feat/flutter-elv3-physical-routing-design`  
Authority: `docs/product/elv3-code-contract-p7-p9.md`

P3-P6 persistence prerequisite: OPEN

## 1. Purpose

This document freezes the implementation foundation that connects the ELV3 physical domain to the engineer workspace (P7), deterministic vertical acceptance (P8), and final architecture-vs-code closure (P9).

It deliberately separates **foundation readiness** from **runtime closure**. The current Drift schema is still P2/schema 19; therefore P7-P9 may define and test orchestration contracts, deterministic fixture contracts, stable failure/error codes and CI guards, but must not claim restart/frozen-trace closure until P3-P6 persistence exists.

## 2. Non-negotiable architecture

```text
Presentation
    |
    v
PhysicalRoutingWorkspaceService
    |---- command authorizer
    |---- command executor --------------------+
    |                                         |
    |---- trace service                       v
    |                                  phase command services
    |                                         |
    v                                         v
workspace query data source             phase-specific UoW
    |                                         |
    +---------------- repositories -----------+
                                              |
                                              v
                                            Drift
```

Rules:

1. widgets never perform compound database writes;
2. `canEdit` is derived from `PhysicalDesignContext` plus command permission evidence;
3. every mutation still executes through its owning P1-P6 command service;
4. P7 is orchestration, not a second domain layer;
5. frozen trace reconstruction will read immutable snapshot evidence, never patch gaps from current mutable rows;
6. P8 IDs are deterministic and never depend on UUID ordering;
7. P9 reports actual implementation state and fails rather than promoting a contract-only path as implemented.

## 3. P7 workspace state machine

Canonical progression is exactly:

```text
logicalConnection
  -> cable
  -> allocation
  -> termination
  -> route
  -> carrier
  -> findings
```

`PhysicalRoutingSelectionSnapshot` carries the minimum query evidence needed to place the workspace in that flow:

```text
connectionId
cableId
allocationId
terminationSetComplete
cableRunId
carrierAssignmentComplete
commandMutationsAllowed
blockingIssues
```

The stage is derived; presentation code must not maintain an independent stage machine.

### 3.1 Mutation gate

A workspace command may execute only when both are true:

```text
PhysicalDesignContext.editingAllowed
AND workingDesignRevisionId != null
AND ElvWorkspaceCommandAuthorizer.canExecute(command)
```

Stable workspace failures:

```text
ELV_WORKSPACE_READ_ONLY
ELV_WORKSPACE_COMMAND_FORBIDDEN
```

The selection-level `commandMutationsAllowed` controls rendered editability; command execution performs an independent authorization check to prevent UI state from becoming a security/correctness boundary.

## 4. P7 undo/redo foundation

Ordinary editor in-memory history is not authoritative for ELV3. ELV3 command history is persisted evidence.

`ElvCommandHistoryRecord` freezes:

```text
projectId
monotonic sequence
commandId
forward command type
forward payload SHA-256
undo class
precondition fingerprint
inverse command type/payload for reversible entries
state = APPLIED | UNDONE | REDO_ABANDONED
```

Required semantics:

- reversible entries require an explicit inverse command payload;
- irreversible-history entries are never exposed as normal Undo;
- undo succeeds only when the persisted precondition fingerprint still matches;
- redo is eligible only for an UNDONE reversible entry;
- a new forward command after undo abandons the remaining redo branch without deleting audit history;
- history state change and the underlying inverse/forward domain command must commit in one transaction.

Stable future history failures are reserved now:

```text
ELV_UNDO_NOT_AVAILABLE
ELV_REDO_NOT_AVAILABLE
ELV_UNDO_IRREVERSIBLE
ELV_UNDO_PRECONDITION_CHANGED
```

Concrete Drift history tables/UoW wiring are intentionally deferred to the persistence implementation wave; an in-memory substitute is forbidden as runtime evidence.

## 5. P8 deterministic vertical foundation

Test builders are split by responsibility:

```text
elv_test_catalog.dart   exact physical resource fixture definitions
elv_test_project.dart   deterministic project/revision identities
elv_test_topology.dart  deterministic connection/port identities
elv_test_routing.dart   deterministic run/route/traversal/carrier identities
elv_test_ids.dart       FixedSequenceIdGenerator + canonical prefixes
```

Five frozen fixture plans exist:

| Vertical | Connections | Cables | Allocations | Key invariant |
|---|---:|---:|---:|---|
| CCTV | 1 | 1 | 1 | Cat6 whole cable, >=3 traversals, carrier assignment |
| LAN | 1 | 1 | 1 | permanent-link physical cable; internal connectivity remains separate |
| ACS | 4 | 1 | 4 | one 8-core cable; four non-overlapping 2-core allocations |
| Fire | 2 | 2 | 2 | logical loop identity remains separate from explicit physical sections |
| Fiber | 2 | 1 | 2 | two duplex allocations; overlapping fiber atom rejected |

No fixture expects an ELV3 jurisdictional compliance result. PoE budget, battery sizing and other ELV4 responsibilities remain outside these verticals.

### 5.1 Runtime vertical promotion rule

The files required by the authoritative P8 runtime contract under `test/vertical/` become valid closure evidence only when they execute through the real P3-P6 Drift repositories. Fixture-contract tests are not counted as restart proof.

Promotion order:

```text
P3 revision/run persistence
 -> P4 pathway/carrier persistence
 -> P5 profile-set persistence
 -> P6 evidence/result persistence
 -> P7 concrete query/trace/history adapters
 -> five P8 DB verticals
 -> failure/reopen/idempotency/frozen reconstruction
```

## 6. P8 failure and restart protocol

Stable failure points remain the only legal probe keys. Tests must never depend on source line numbers or private helper names.

Every failure test follows:

```text
known canonical DB
 -> arm stable probe
 -> execute command
 -> deterministic failure
 -> same-connection state equals baseline
 -> close
 -> reopen
 -> state still equals baseline
 -> command ledger contains no success claim
```

Every replayable command follows:

```text
commit(commandId,payload)
 -> lose response
 -> reopen
 -> replay same commandId + same payload
 -> same logical result, no duplicate canonical rows
 -> same commandId + changed payload
 -> ELV_IDEMPOTENCY_CONFLICT
```

Frozen reconstruction follows:

```text
WORKING -> freeze snapshot/hash -> next WORKING -> mutate current
                                   |
                                   +-> old FROZEN trace == baseline exactly
```

## 7. P9 architecture guard

P9 is both documentation and executable guardrail.

The CI foundation script verifies:

- P7 source/test contracts exist;
- all seven canonical workspace stages remain represented;
- command permission evidence remains part of P7;
- command-history persistence ports remain present;
- deterministic P8 fixture builders remain present;
- all stable failure-point codes remain present;
- implementation inventory continues to state the actual P2 persistence baseline;
- this document continues to declare the P3-P6 persistence prerequisite OPEN until runtime implementation closes it.

This guard runs before Flutter setup so structural contract drift fails fast.

## 8. Foundation Definition of Done

P7-P9 **foundation design** is complete when:

1. one shared workspace state machine exposes all seven canonical stages;
2. writeability and execution authorization are distinct and tested;
3. persisted command-history record/store contracts exist with reversible/irreversible semantics;
4. stable workspace and undo/redo error codes are reserved;
5. deterministic builders and all five vertical fixture plans exist;
6. stable P8 failure points are frozen;
7. P9 inventory and command matrix identify contract-only versus implemented paths honestly;
8. CI enforces the foundation shape;
9. no document or test labels fixture-contract coverage as restart/runtime closure.

## 9. Runtime closure gates that remain open

These are not foundation defects; they are the next implementation wave:

```text
R1  P3 Drift revision/snapshot/run/traversal/adoption persistence
R2  P4 Drift pathway/carrier/compartment persistence
R3  P5 exact profile-set persistence
R4  P6 separation evidence + revision-scoped result persistence
R5  P7 Drift workspace query + frozen/current trace adapters
R6  P7 transactional command-history implementation
R7  five P8 real DB verticals
R8  all failure probes + rollback/reopen
R9  idempotency across reopen + conflict replay
R10 frozen reconstruction after later WORKING mutation
R11 P9 runtime forbidden-shortcut assertions
R12 final exact-SHA evidence
```

Only after R1-R12 are green may the branch change this document from `IMPLEMENTATION-READY FOUNDATION` to runtime closure evidence.
