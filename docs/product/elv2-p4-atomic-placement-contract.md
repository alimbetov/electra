# ELV2-P4 — atomic canonical placement

Branch: `feat/flutter-elv2-profile-constraints`  
Parent: [ELV2 technical specification](elv2-profile-constraints-technical-specification.md)  
Pre-placement UI: [P3 palette contract](elv2-p3-palette-contract.md)  
Decision engine: [P2 placement compatibility contract](elv2-p2-placement-compatibility-contract.md)

## 1. Purpose

P4 turns the read-only P3 preview into one durable engineering operation. A successful command creates exactly one placed physical component, establishes its engineering-system membership, freezes the exact canonical catalog/profile binding, instantiates persisted ELV1 ports, and records one editor-history action. A failed command leaves no partial engineering state.

Target transaction:

```text
PlaceEngineeringProfileCommand
        │
        ├── resolve exact project / room / surface
        ├── resolve exact EngineeringSystem
        ├── resolve exact catalog edition + profile
        ├── reconstruct candidate evidence
        └── P2 revalidation
                ↓
        BEGIN DATABASE TRANSACTION
                ↓
        create physical ComponentInstance
                ↓
        create EngineeringSystem membership
                ↓
        create frozen ComponentReferenceBinding
                ↓
        instantiate persisted EngineeringPorts
                ↓
        validate postconditions
                ↓
        persist idempotency result
                ↓
        COMMIT
                ↓
        append one editor history command
```

If any durable step fails, the database transaction rolls back every row created by the operation. No component, membership, binding or subset of ports may survive a failed placement.

P4 covers **new canonical placement only**. Catalog revision migration/adoption remains P5/P6.

---

## 2. Engineering principles

The implementation MUST preserve the following rules.

1. **One physical component.** One placement command creates at most one `ComponentInstance`.
2. **One atomic engineering operation.** Component, membership, frozen binding and ports are one commit boundary.
3. **Revalidate at commit.** A P3 preview result is not authorization to persist; P2 runs again immediately before mutation.
4. **Exact provenance.** The command identifies exact catalog id/version/profile code and the binding freezes the corresponding profile snapshot.
5. **No silent latest lookup.** P4 never substitutes a newer catalog/profile edition during commit.
6. **ELV1 persisted graph remains authoritative.** Ports instantiated by P4 are real persisted ELV1 ports, not transient profile metadata.
7. **Rollback is total.** Any exception before commit produces zero new durable rows from the operation.
8. **Retry is idempotent.** Re-submitting the same operation identity cannot create duplicates.
9. **Undo/redo is aggregate-level.** The user performs one placement operation, therefore history records one reversible engineering command, not four unrelated mutations.
10. **No ELV3 leakage.** P4 does not create cables, cable runs, pathways or route objects.

---

## 3. Scope

### 3.1 In scope

- atomic placement application command;
- exact project/room/surface/system/catalog/profile resolution;
- P2 compatibility revalidation at commit time;
- physical `ComponentInstance` creation;
- engineering-system membership creation;
- immutable `ComponentReferenceBinding` creation;
- persisted ELV1 port instantiation from profile templates;
- provenance preservation for template/interface/catalog/profile edition;
- rollback on any failure;
- deterministic failure injection for tests;
- idempotent retry by stable operation identity;
- single undo/redo history action;
- CCTV/LAN/ACS/Fire acceptance scenarios;
- persistence/restart verification;
- exact-SHA push + PR CI gates.

### 3.2 Out of scope

- catalog v2 adoption/migration;
- profile replacement for existing components;
- migration of connected ports;
- revision impact preview;
- connection creation as part of placement;
- topology-group mutation beyond membership facts required by current ELV1 model;
- cables, `CableRun`, routes and pathways;
- PoE, PSU, UPS or battery calculations;
- normative override workflow for forbidden/unresolved placement.

---

## 4. P4.1 — Atomic command contract

Introduce an application-level command equivalent to:

```text
PlaceEngineeringProfileCommand
- operationId
- projectId
- roomId
- systemId
- catalogId
- catalogVersion
- profileCode
- hostSurfacePatchId
- localPosition
- rotationRadians
- placementContext
- displayNameOverride?
```

### 4.1 Operation identity

`operationId` is a stable client-generated UUID/string for one logical placement attempt.

Rules:

- non-empty and immutable;
- unique per logical user operation;
- retrying after transport/UI uncertainty reuses the same value;
- a different intended placement uses a new value;
- `operationId` is not derived from component id, coordinates or profile code.

### 4.2 Placement context

The command carries the exact `PlacementCandidateContext` that was reviewed in P3, but P4 MUST verify that its identity fields agree with the command/project state:

```text
context.projectId == command.projectId
context.roomId == command.roomId
context.surfaceId corresponds to hostSurfacePatchId.surfaceId
```

The context is evidence, not authority. Project/system/catalog/geometry state is resolved again from persistence.

### 4.3 Result contract

Return an immutable result equivalent to:

```text
EngineeringPlacementResult
- operationId
- componentId
- systemId
- catalogId
- catalogVersion
- profileCode
- bindingId or binding identity
- portIds[]
- placementStatus
```

The same `operationId` retry MUST return the same durable result after the first successful commit.

### 4.4 Failure model

Use typed/application-level failures where practical. Minimum semantic categories:

```text
PROJECT_NOT_FOUND
ROOM_NOT_FOUND
SURFACE_PATCH_NOT_FOUND
SYSTEM_NOT_FOUND
SYSTEM_DISCIPLINE_MISMATCH
CATALOG_EDITION_NOT_FOUND
PROFILE_NOT_FOUND
PROFILE_DEPRECATED
PLACEMENT_FORBIDDEN
PLACEMENT_UNRESOLVED
COMPONENT_CONFLICT
MEMBERSHIP_CONFLICT
BINDING_CONFLICT
PORT_CONFLICT
IDEMPOTENCY_CONFLICT
TRANSACTION_FAILED
```

UI text must not be the source of failure classification.

---

## 5. P4.2 — Repository transaction boundary

### 5.1 Single owner

P4 requires one transaction owner in the data/application boundary, for example:

```text
EngineeringPlacementRepository.place(command)
```

or an application service backed by one Drift repository.

It MUST open exactly one top-level `AppDatabase.transaction` covering all durable P4 mutations.

The current component repository already uses independent transactions for `saveComponent`; P4 MUST NOT compose several public repository methods if that creates separate commit boundaries. P4 should instead use transaction-scoped internal operations or a dedicated atomic repository that writes through the same database transaction.

### 5.2 Transaction sequence

Inside one transaction:

```text
1. claim/check operationId
2. re-read project/room/surface/system/catalog/profile
3. run all persistence preconditions
4. create component
5. create membership
6. create frozen binding
7. instantiate all ports
8. assert postconditions
9. persist successful operation result
10. return
```

P2 domain revalidation may run immediately before the transaction if every referenced durable fact is then rechecked inside it. Preferred implementation is to resolve the commit snapshot and evaluate P2 within the same transaction before the first insert.

### 5.3 No externally visible partial state

Watch streams may emit only after commit. No caller may observe an active component without its required binding/ports as a successful P4 result.

---

## 6. P4.3 — Component creation

P4 creates a normal physical `ComponentInstance` compatible with the existing geometry model.

Required checks:

- project and room are active;
- surface patch exists, is active and belongs to the room;
- component local point belongs to the selected patch according to existing `ComponentPlacementValidator`/geometry invariants;
- component id is newly generated deterministically for the operation or persisted in the idempotency record before retry ambiguity;
- no manufacturer SKU becomes the canonical engineering source of truth;
- geometry remains one physical instance even if future systems share it.

The component definition/version strategy MUST use the existing component-instance contract without creating a parallel ELV-only physical entity. If a synthetic/canonical definition is required for ELV placement, it must be deterministic and documented rather than encoded from display text.

---

## 7. P4.4 — Engineering-system membership

After component creation, create the persisted membership that associates the physical component with the selected `EngineeringSystem`.

Invariants:

- system belongs to the same project;
- system is active/resolvable;
- system discipline/family resolves to the exact discipline of the selected canonical profile;
- duplicate active membership for the same component/system is forbidden;
- no membership may remain without its component after rollback;
- cross-discipline placement fails before binding/ports are committed.

If current membership persistence uses the engineering-system repository/table directly, P4 must reuse that schema rather than inventing a second relation.

---

## 8. P4.5 — Frozen binding

Create exactly one active `ComponentReferenceBinding` for the new component.

The binding MUST freeze:

```text
componentId
catalogId
catalogVersion
profileCode
full ComponentEngineeringProfile snapshot
constraints state + constraints snapshot
portIds[]
```

Rules:

- exact profile edition from the command is used;
- no latest-version lookup;
- `legacyUnspecified` cannot be used for successful new placement;
- deprecated profile cannot be used for successful new placement;
- profile discipline must match system discipline;
- one active binding per component;
- rollback removes the binding if any subsequent port operation fails.

The final stored `portIds` must exactly match the persisted ports created in P4.6.

---

## 9. P4.6 — Persisted port instantiation

Instantiate ports from `ComponentEngineeringProfile.portTemplates` using existing ELV1 semantics.

For every template:

- create one persisted `EngineeringPort` with the placed `componentId`;
- preserve template code/kind/direction/capacity/protocol/connector/electrical metadata;
- preserve exact template provenance;
- resolve and freeze exact interface provenance from `portInterfaceCodes` and the selected catalog vocabulary;
- generate stable unique persisted port ids;
- prohibit duplicate active port ids/codes for the component;
- prohibit silent replacement of manually authored conflicting active ports.

### 9.1 Port identity

For a first placement attempt, generated port ids MUST be deterministic for the durable operation or persisted once before ambiguity, so an idempotent retry returns the same ids.

Recommended identity basis:

```text
operationId + normalized port template code
```

or another collision-safe deterministic scheme owned by P4.

Do not use list index alone; template reordering is not semantic identity.

### 9.2 All-or-nothing

If a profile has N templates, success requires exactly N active persisted ports and the binding must list exactly those N ids.

Example Fire detector:

```text
DETECTOR
  IN
  OUT
```

If `IN` succeeds and `OUT` fails, neither port, the binding, membership nor component may remain after rollback.

---

## 10. P4.7 — P2 revalidation at commit

P3 preview is advisory/read-only. P4 MUST call `PlacementCompatibilityEngine` again with the exact profile edition and commit-time candidate evidence.

Commit policy:

```text
COMPATIBLE  -> may proceed
WARNING     -> may proceed only when P2 actually emits an explicit warning rule and product policy permits it
FORBIDDEN   -> zero mutation
UNRESOLVED  -> zero mutation
```

Current P2 emits no warning rules, so P4 should be implemented without inventing warning exceptions.

Revalidation MUST detect at least:

- stale/deprecated profile;
- catalog/profile mismatch;
- mounting mismatch;
- environment mismatch;
- incomplete required evidence;
- topology shape/role mismatch;
- missing pinned topology evidence where P3 already treats it as unresolved.

A previously compatible P3 preview does not bypass P4 validation.

---

## 11. P4.8 — Rollback and failure injection

Atomicity MUST be proven with deterministic failure injection in repository/integration tests.

Provide a test-only fault seam equivalent to:

```text
EngineeringPlacementFailurePoint
- afterComponent
- afterMembership
- afterBinding
- beforePort(index/code)
- afterPort(index/code)
- beforeCommit
```

The production path must not depend on a debug flag stored in project data. Injection is constructor/test dependency behavior only.

For every injected point assert:

```text
component count delta = 0
membership count delta = 0
binding count delta = 0
port count delta = 0
idempotency success record delta = 0
history delta = 0
```

Database `total_changes()` may increase internally during a rolled-back SQLite transaction; acceptance must verify final durable state, not assume SQLite's cumulative counter rolls back.

Also test natural failures:

- invalid surface geometry;
- wrong discipline;
- missing catalog/profile;
- pre-existing conflicting port;
- duplicate binding/membership conflict.

---

## 12. P4.9 — Idempotent retry

### 12.1 Required behavior

For the same `operationId` and semantically identical command:

```text
first call  -> creates aggregate and returns result
second call -> creates nothing and returns the same result
```

No duplicate component, membership, binding, ports or history action.

### 12.2 Conflict behavior

If an existing `operationId` is reused with materially different command data, fail with `IDEMPOTENCY_CONFLICT`.

Material fields include at least:

```text
projectId
roomId
systemId
catalogId/version/profileCode
hostSurfacePatchId
position/rotation
placement evidence relevant to P2
```

### 12.3 Persistence strategy

Idempotency must survive restart. An in-memory set is insufficient.

Preferred minimal additive persistence:

```text
EngineeringPlacementOperations
- operationId PK
- commandFingerprint
- status
- resultJson / aggregate ids
- createdAt
```

A successful operation row is committed in the same transaction as the placement aggregate. If an existing suitable durable operation/audit table can express the same contract without ambiguity, reuse it.

Do not persist a successful idempotency result outside the placement transaction.

---

## 13. P4.10 — Single undo/redo command

The editor must treat successful P4 placement as one history action.

Conceptual command:

```text
PlaceEngineeringProfileHistoryCommand
  do   -> invoke/restore the complete aggregate
  undo -> remove/retire complete aggregate consistently
  redo -> restore the same logical placement exactly once
```

### 13.1 History boundary

History entry is appended only after the atomic placement transaction succeeds.

A failed/forbidden/unresolved placement creates no undo entry.

### 13.2 Undo semantics

Undo must remove/retire the aggregate in a dependency-safe order under one transaction:

```text
ports
binding
membership
component
```

No orphan active row may remain.

Because P4 creates no connections, undo should not yet need connected-port migration logic. If a later user action connects a P4-created port, existing deletion guards must prevent unsafe undo or the editor must invalidate that historical undo path. P4 must not bypass ELV deletion guards.

### 13.3 Redo semantics

Redo restores one aggregate with the same logical provenance. It must not duplicate ports/bindings/memberships. Reusing the original operation identity requires an explicit history-aware restore policy; if idempotency records mark the operation already completed, redo must use the persisted aggregate/history contract rather than accidentally no-oping or duplicating it.

The implementation must define and test this interaction explicitly.

---

## 14. P4.11 — Four-discipline acceptance

Use the canonical fictional acceptance catalog and execute the same P4 command path for all disciplines.

### CCTV

```text
CAMERA
wall + bracket or ceiling + surface
expected persisted ports: ETH
```

Assert physical component, CCTV membership, frozen CAMERA binding and exact ETH interface/template provenance.

### LAN

```text
OUTLET
wall + flush/surface
expected persisted ports: ETH
```

Assert LAN membership and exact Cat6/profile provenance without discipline-specific P4 branches.

### ACS

```text
READER
wall + surface
expected persisted ports: BUS
```

Assert ACS membership and exact bus/interface provenance.

### Fire

```text
DETECTOR
ceiling + surface
expected persisted ports: IN, OUT
```

Assert both ports are persisted atomically and topology intent is compatible with the selected system profile.

The P4 implementation MUST remain discipline-agnostic. CCTV/LAN/ACS/Fire are fixtures proving the generic contract, not switch branches in the placement service.

---

## 15. P4.12 — Restart acceptance

A successful placement must survive database close/reopen with exact reconstruction.

Test flow:

```text
create project/room/surface/system/catalog
        ↓
P4 place component
        ↓
assert component + membership + binding + ports
        ↓
close database
        ↓
reopen database
        ↓
load project state
        ↓
assert exact same aggregate/provenance/port ids
        ↓
retry same operationId
        ↓
assert no duplicates and same result
```

Restart assertions include:

- same component id and geometry;
- same system membership;
- same catalog id/version/profile code;
- same frozen profile/constraints snapshot;
- same port ids and template/interface provenance;
- idempotency record reconstructs the same result;
- no extra active rows.

At least one full restart case is required for each discipline before P4 is complete, or one table-driven restart suite that covers all four canonical fixtures.

---

## 16. P4.13 — Exact-SHA CI gate

P4 is complete only when both push and PR-triggered workflows pass on the exact same branch head SHA.

Required gates:

```text
Drift generation                  PASS

Mobile:
  formatting                      PASS
  analyze                         PASS
  tests                           PASS

Engineering Core:
  dependencies                    PASS
  formatting                      PASS
  analyze                         PASS
  tests                           PASS
```

The PR description must record the exact P4 SHA and test counts/evidence.

Do not mark PR #7 ready and do not begin ELV3 after P4. P5–P7 remain required.

---

## 17. Data-model guidance

### 17.1 Prefer minimal additive schema

Existing persistence already contains component instances, engineering systems/memberships, reference bindings and ports. P4 should reuse these tables.

A schema migration is justified only for durable idempotency/history metadata that cannot be represented safely by current structures.

### 17.2 Constraints

Where Drift schema allows, add uniqueness/index protection for invariants that must survive programming mistakes/concurrency, for example:

- unique successful `operationId`;
- one active binding per component;
- one active component/system membership pair;
- unique active port identity per component;
- stable operation fingerprint.

If soft-delete prevents a simple SQL unique index, enforce the invariant transactionally and document why a partial index/table redesign is not used.

### 17.3 Concurrency

Two concurrent submissions with the same `operationId` must converge to one durable aggregate or one succeeds while the other reads that result. They must not create two aggregates.

Two different operations attempting the same generated component id/port ids must fail safely under database constraints/transaction logic.

---

## 18. Test specification

### 18.1 Application/domain tests

- command validation;
- command fingerprint stability;
- exact profile/system discipline match;
- P2 compatible/forbidden/unresolved commit policy;
- same operation retry returns same result;
- changed command with same operation id conflicts;
- deterministic port identities independent of template list ordering where template code identity is unchanged.

### 18.2 Repository/SQLite tests

- successful aggregate transaction;
- failure after component -> rollback;
- failure after membership -> rollback;
- failure after binding -> rollback;
- failure on first/middle/last port -> rollback;
- failure before commit -> rollback;
- conflicting manual port -> rollback;
- duplicate membership/binding protection;
- concurrent/simulated duplicate operation id behavior;
- restart idempotency.

### 18.3 Editor/history tests

- COMPATIBLE preview can invoke P4;
- FORBIDDEN/UNRESOLVED cannot invoke mutation;
- one success produces one undo entry;
- undo removes entire aggregate;
- redo restores one aggregate once;
- failed P4 creates no history entry;
- existing electrical placement history remains unaffected.

### 18.4 Four-discipline acceptance

Table-driven tests cover CCTV CAMERA, LAN OUTLET, ACS READER and Fire DETECTOR through the same P4 service.

---

## 19. Acceptance criteria

### AC-P4-01 Atomic command
One application command represents one canonical engineering placement.

### AC-P4-02 Single transaction
Component, membership, binding, ports and successful idempotency result share one database commit boundary.

### AC-P4-03 Revalidation
P2 is rerun at commit; stale P3 preview cannot bypass current constraints.

### AC-P4-04 Zero mutation on rejection
FORBIDDEN, UNRESOLVED, deprecated, missing edition and discipline mismatch create no durable placement state.

### AC-P4-05 Physical component
Exactly one valid `ComponentInstance` is created for success.

### AC-P4-06 Membership
Exactly one correct active system membership is created.

### AC-P4-07 Frozen binding
Exactly one binding freezes the exact catalog/profile/constraints snapshot.

### AC-P4-08 Ports
Exactly the profile-template port set is persisted with exact provenance.

### AC-P4-09 Rollback
Every injected failure point leaves zero partial aggregate rows.

### AC-P4-10 Idempotency
Same operation + same command returns the same result without new rows.

### AC-P4-11 Idempotency conflict
Same operation id + changed material command is rejected.

### AC-P4-12 Restart idempotency
Idempotent behavior survives database reopen.

### AC-P4-13 Single history action
Successful placement creates one reversible editor action.

### AC-P4-14 Safe undo/redo
Undo/redo never leaves or creates orphan/duplicate engineering rows.

### AC-P4-15 Four disciplines
CCTV/LAN/ACS/Fire pass through one discipline-agnostic service.

### AC-P4-16 No ELV3 coupling
No cable/pathway/route model is introduced.

### AC-P4-17 Exact-SHA evidence
Push and PR workflows are green on the exact P4 head SHA.

---

## 20. Definition of Done

P4 is done only when all items below are true:

- [ ] `PlaceEngineeringProfileCommand` contract implemented;
- [ ] stable `operationId` and durable command fingerprint implemented;
- [ ] one top-level Drift transaction owns all P4 writes;
- [ ] exact commit-time project/room/surface/system/catalog/profile checks implemented;
- [ ] P2 commit-time revalidation implemented;
- [ ] physical component created through existing geometry invariants;
- [ ] engineering-system membership persisted;
- [ ] frozen `ComponentReferenceBinding` persisted;
- [ ] exact profile ports persisted with template/interface provenance;
- [ ] binding portIds equal persisted port ids;
- [ ] zero durable mutation for FORBIDDEN/UNRESOLVED/deprecated/wrong-discipline cases;
- [ ] deterministic test failure injection implemented;
- [ ] rollback proven after every durable stage;
- [ ] same-operation retry proven idempotent;
- [ ] changed-command reuse of operation id proven conflicting;
- [ ] idempotency survives restart;
- [ ] one editor history action per successful placement;
- [ ] undo removes/retires whole aggregate safely;
- [ ] redo restores whole aggregate once;
- [ ] CCTV CAMERA acceptance green;
- [ ] LAN OUTLET acceptance green;
- [ ] ACS READER acceptance green;
- [ ] Fire DETECTOR acceptance green;
- [ ] all four survive restart with exact provenance;
- [ ] no ELV3 types/dependencies introduced;
- [ ] mobile/core format and analyze green;
- [ ] mobile/core tests green;
- [ ] push and PR workflows green on exact same SHA;
- [ ] PR #7 records P4 exact-SHA evidence and remains draft for P5–P7.

---

## 21. Recommended implementation sequence

```text
P4.1  Atomic command/result/failure contracts
  ↓
P4.2  Dedicated transaction owner + durable idempotency strategy
  ↓
P4.3  Physical ComponentInstance creation using existing geometry validation
  ↓
P4.4  EngineeringSystem membership persistence
  ↓
P4.5  Frozen ComponentReferenceBinding snapshot
  ↓
P4.6  Deterministic persisted port instantiation + provenance
  ↓
P4.7  P2 commit-time revalidation and rejection policy
  ↓
P4.8  Fault injection + rollback matrix
  ↓
P4.9  Retry/concurrency/restart idempotency
  ↓
P4.10 Single aggregate undo/redo history action
  ↓
P4.11 CCTV/LAN/ACS/Fire acceptance
  ↓
P4.12 Database restart acceptance
  ↓
P4.13 Exact-head push + PR CI and PR evidence
```

P5 starts only after all P4 acceptance criteria above are green.