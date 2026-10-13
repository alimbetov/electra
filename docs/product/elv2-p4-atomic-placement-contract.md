# ELV2-P4 — atomic canonical placement

Status: implementation contract v1.1 — approved baseline for implementation  
Branch: `feat/flutter-elv2-profile-constraints`  
Parent: [ELV2 technical specification](elv2-profile-constraints-technical-specification.md)  
Pre-placement UI: [P3 palette contract](elv2-p3-palette-contract.md)  
Decision engine: [P2 placement compatibility contract](elv2-p2-placement-compatibility-contract.md)

> Revision note: v1.1 hardens canonical command fingerprinting, durable operation state, concurrent duplicate handling, transaction postconditions, and undo/redo durability semantics before P4 implementation starts.

## 1. Purpose

P4 turns the read-only P3 preview into one durable engineering operation. A successful command creates exactly one placed physical component, establishes its engineering-system membership, freezes the exact canonical catalog/profile binding, instantiates persisted ELV1 ports, persists the durable operation identity/result, and records one aggregate editor-history action. A failed command leaves no partial engineering state.

P4 covers **new canonical placement only**. Catalog revision impact, replacement and adoption remain P5/P6.

Target flow:

```text
PlaceEngineeringProfileCommand
        │
        ├── validate command shape
        ├── resolve durable operationId state
        ├── resolve exact project / room / surface
        ├── resolve exact EngineeringSystem
        ├── resolve exact catalog edition + profile
        ├── reconstruct commit-time candidate evidence
        └── P2 revalidation
                ↓
        BEGIN DATABASE TRANSACTION
                ↓
        claim operationId / verify fingerprint
                ↓
        create physical ComponentInstance
                ↓
        create EngineeringSystem membership
                ↓
        create frozen ComponentReferenceBinding
                ↓
        instantiate persisted EngineeringPorts
                ↓
        validate aggregate postconditions
                ↓
        persist completed operation result
                ↓
        persist one history payload if history is durable
                ↓
        COMMIT
                ↓
        expose one successful editor action
```

If any durable step fails, the transaction rolls back every row created by the operation. No component, membership, binding, subset of ports, completed operation record or durable history record may survive a failed placement.

---

## 2. Engineering principles

The implementation MUST preserve the following rules.

1. **One physical component.** One logical placement operation creates at most one `ComponentInstance`.
2. **One atomic engineering aggregate.** Component, membership, frozen binding, ports and durable idempotency result share one commit boundary.
3. **Revalidate at commit.** A P3 preview is evidence shown to the user, not authorization to persist. P2 runs again against commit-time state.
4. **Exact provenance.** P4 uses the exact catalog id/version/profile code selected in P3 and freezes that profile snapshot.
5. **No silent latest lookup.** P4 never substitutes a newer catalog/profile/system/topology edition.
6. **ELV1 graph remains authoritative.** Ports created by P4 are persisted ELV1 graph objects.
7. **Rollback is total.** Any failure before commit produces zero new durable aggregate rows.
8. **Retry is durable and idempotent.** The same operation identity with the same semantic command converges to one result, including after restart.
9. **Command identity is semantic.** Idempotency compares a canonical command fingerprint, not arbitrary JSON serialization order.
10. **Concurrency is explicit.** Two simultaneous submissions of the same `operationId` cannot create two aggregates.
11. **Undo/redo is aggregate-level.** The user sees one placement action, not separate component/membership/binding/port mutations.
12. **History cannot weaken atomicity.** A successful durable placement must not depend on a best-effort post-commit history append that can be silently lost.
13. **No hidden repair.** Corrupt or conflicting existing state is rejected; P4 does not silently normalize existing memberships, bindings or ports.
14. **No ELV3 leakage.** P4 does not create cables, cable runs, pathways, route objects or cable compatibility rules.

---

## 3. Scope

### 3.1 In scope

- one atomic placement application command;
- exact project/room/surface/system/catalog/profile resolution;
- commit-time P2 compatibility revalidation;
- physical `ComponentInstance` creation;
- engineering-system membership creation;
- immutable `ComponentReferenceBinding` creation;
- persisted ELV1 port instantiation from profile templates;
- exact template/interface/catalog/profile provenance;
- durable `operationId` claim/result persistence;
- canonical command fingerprinting;
- concurrency-safe idempotency;
- deterministic rollback/failure injection;
- one aggregate undo/redo action;
- CCTV/LAN/ACS/Fire acceptance scenarios;
- database restart verification;
- exact-SHA push + PR CI gates.

### 3.2 Out of scope

- catalog v2 adoption/migration;
- profile replacement for existing components;
- migration of connected ports;
- revision impact preview;
- connection creation as part of placement;
- topology-group mutation beyond current membership facts;
- whole-graph loop/degree/branch validation that requires existing connections;
- cables, `CableRun`, routes and pathways;
- PoE, PSU, UPS or battery calculations;
- normative override workflow for forbidden/unresolved placement;
- manufacturer-equipment BOM selection.

---

# P4.1 — Atomic command contract

## 4. Command

Introduce an application-level immutable command equivalent to:

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

The command contains user intent and candidate evidence. It does not contain trusted copies of system discipline, catalog/profile objects, interface definitions or database rows. Those are resolved from persistence.

### 4.1 Operation identity

`operationId` is a stable client-generated UUID/string for one logical placement attempt.

Rules:

- non-empty and immutable;
- generated before the first mutation request;
- reused when retrying the same logical placement after UI/process uncertainty;
- a materially different intended placement uses a new value;
- never derived solely from component id, coordinates, display name or profile code;
- never reused by normal redo as if redo were a network retry; redo has explicit history semantics defined in P4.10.

### 4.2 Placement context identity

The command carries the `PlacementCandidateContext` reviewed in P3, but P4 verifies identity against durable state:

```text
context.projectId == command.projectId
context.roomId == command.roomId
context.surfaceId == resolved hostSurfacePatch.surfaceId
resolved hostSurfacePatch.roomId == command.roomId
resolved system.projectId == command.projectId
```

The context is evidence, not authority. Geometry, project, system, catalog/profile and pinned topology facts are resolved again.

### 4.3 Result

Return an immutable result equivalent to:

```text
EngineeringPlacementResult
- operationId
- componentId
- systemId
- catalogId
- catalogVersion
- profileCode
- binding identity
- portIds[]
- placementStatus
- committedAt
```

For a completed operation, the result is persisted or reconstructable from exact aggregate ids without ambiguity.

A retry of the same semantic command MUST return the same logical result and exact ids.

### 4.4 Typed failure model

Minimum semantic categories:

```text
INVALID_COMMAND
PROJECT_NOT_FOUND
ROOM_NOT_FOUND
SURFACE_PATCH_NOT_FOUND
SYSTEM_NOT_FOUND
SYSTEM_PROJECT_MISMATCH
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
OPERATION_IN_PROGRESS
HISTORY_CONFLICT
TRANSACTION_FAILED
```

A failure may carry structured detail such as P2 findings, conflicting ids or expected/actual provenance. UI text is presentation only and must not be the source of classification.

---

# P4.2 — Repository transaction boundary

## 5. Single transaction owner

P4 requires one dedicated transaction owner, for example:

```text
EngineeringPlacementRepository.place(command)
```

or an application service backed by one Drift transaction-scoped repository.

It MUST open exactly one top-level `AppDatabase.transaction` covering all durable P4 writes.

Existing public repositories such as component/reference/system repositories may continue to own transactions for their standalone use cases, but P4 MUST NOT compose independently committing public methods. Instead use one of:

```text
A. dedicated atomic repository writes tables directly
B. transaction-scoped internal DAO primitives with no nested independent commit boundary
C. explicit unit-of-work passed to internal repository methods
```

The implementation must document which option is chosen.

## 6. Transaction sequence

Inside one transaction:

```text
1. validate/claim operationId
2. compare canonical command fingerprint
3. if COMPLETED -> return stored/reconstructed result
4. if conflicting fingerprint -> IDEMPOTENCY_CONFLICT
5. resolve current project/room/surface/system/catalog/profile
6. verify geometry + discipline + persistence preconditions
7. reconstruct commit-time PlacementCandidateContext
8. run P2 and enforce commit policy
9. create component
10. create membership
11. create frozen binding skeleton / planned port ids
12. create all ports
13. finalize binding exact portIds
14. assert aggregate postconditions
15. persist COMPLETED operation result
16. persist durable history payload when history storage is database-backed
17. commit
```

No mutation happens before idempotency conflict detection and commit-time compatibility checks are complete.

## 7. Transaction observation

- Drift/watch observers must not observe a successful active component without required P4 membership/binding/ports.
- The application must not publish success or add an in-memory history entry until the database transaction commits.
- A post-commit event may refresh UI, but must not perform required durable aggregate writes.

## 8. Transaction postconditions

Before commit, assert at minimum:

```text
1 active component with result.componentId
1 active membership (componentId, systemId)
1 active binding for componentId
N active ports where N == profile.portTemplates.length
set(binding.portIds) == set(persisted port ids)
all ports.componentId == componentId
all port provenance resolves to the frozen profile/catalog edition
completed operation result references exactly these ids
```

A postcondition failure causes rollback, not repair.

---

# P4.3 — Component creation

## 9. Physical component

P4 creates a normal `ComponentInstance` compatible with the existing geometry model. It MUST NOT introduce an ELV-only parallel physical entity.

Required checks:

- project exists and is active;
- room exists, is active and belongs to the project;
- host surface patch exists, is active and belongs to the room;
- local point satisfies existing `ComponentPlacementValidator`/geometry invariants;
- rotation is finite and accepted by current component contract;
- generated component id is stable for the operation;
- manufacturer SKU/display label is not canonical engineering identity.

## 10. Component identity

Preferred rule:

```text
componentId = deterministic namespace-derived id from operationId
```

or another durable one-time identity stored in the claimed operation row before ambiguity can occur.

The same semantic retry must resolve the same component id.

If a generated id already exists but is not owned by the same successful operation/fingerprint, fail `COMPONENT_CONFLICT`.

## 11. Component definition/version

P4 must reuse the existing component-instance definition/version contract. If ELV placement requires a canonical/synthetic physical definition, it must have a documented deterministic identity and version; it must not be synthesized from translated labels or manufacturer names.

---

# P4.4 — Engineering-system membership

## 12. Membership invariants

Create exactly one persisted active membership associating the placed component with the selected `EngineeringSystem`.

Required invariants:

- system belongs to the same project;
- exact system family/version resolves successfully;
- resolved system discipline equals `profile.discipline`;
- duplicate active `(componentId, systemId)` membership is forbidden;
- rollback leaves no membership without its component;
- P4 does not create extra cross-discipline memberships implicitly;
- existing conflicting membership state is rejected rather than repaired.

P4 reuses the current engineering-system membership schema/table.

---

# P4.5 — Frozen binding

## 13. Binding snapshot

Create exactly one active `ComponentReferenceBinding` for the new component.

The binding freezes:

```text
componentId
catalogId
catalogVersion
profileCode
full ComponentEngineeringProfile snapshot
constraintsState
constraints snapshot
portIds[]
```

Required rules:

- use exact command edition; no latest lookup;
- profile must be publication-valid for new placement;
- `legacyUnspecified` cannot succeed;
- deprecated profile cannot succeed;
- profile discipline must match the resolved system discipline;
- one active binding per component;
- final `portIds` exactly equal persisted P4 port ids;
- rollback removes all binding effects.

The binding is the future P5/P6 provenance anchor. P4 therefore must not store only a profile code and rely on current catalog contents later.

---

# P4.6 — Persisted port instantiation

## 14. Port instantiation

For every `ComponentEngineeringProfile.portTemplates` entry create exactly one persisted `EngineeringPort` with the placed component id.

Preserve at minimum:

- template code;
- kind;
- direction;
- capacity;
- connector;
- protocol/version;
- electrical metadata already carried by the template;
- template provenance;
- exact interface code/version/provenance resolved from `portInterfaceCodes` and the selected catalog vocabulary.

No manually authored active port may be silently overwritten or adopted merely because its code matches a template.

## 15. Stable port identity

Persisted port identity MUST be deterministic for the operation and template semantic identity.

Recommended basis:

```text
operationId + normalized template code
```

Requirements:

- template list order does not affect identity;
- duplicate normalized template codes fail before mutation;
- same operation retry returns same port ids;
- different operation ids cannot accidentally converge to the same port ids;
- identity generation algorithm is covered by tests and treated as persisted contract once P4 ships.

## 16. Interface provenance

If `portInterfaceCodes` references an interface code, P4 must resolve that interface in the exact selected catalog vocabulary before insertion.

Failure to resolve exact interface provenance is `PORT_CONFLICT`/invalid catalog state and rolls back the whole operation.

## 17. All-or-nothing port set

If profile has N templates, success requires exactly N active ports.

Example:

```text
Fire DETECTOR
  IN
  OUT
```

If `IN` is inserted and `OUT` fails, transaction rollback removes both plus binding, membership, component and operation completion record.

---

# P4.7 — P2 revalidation at commit

## 18. Revalidation rule

P4 MUST invoke the existing `PlacementCompatibilityEngine` again using:

- exact resolved profile edition;
- current durable project/room/surface identity;
- current pinned topology evidence where applicable;
- candidate environmental/mounting facts explicitly supplied by the command and still applicable to that surface.

P3 result is never reused as a trusted boolean.

## 19. Commit policy

```text
COMPATIBLE  -> commit may proceed
WARNING     -> commit only if a separately defined product policy explicitly permits that warning class
FORBIDDEN   -> zero mutation
UNRESOLVED  -> zero mutation
```

At current P2 state, no warning exception is invented by P4.

Required stale-state checks include:

- profile became deprecated/unavailable;
- exact catalog edition missing;
- system/family edition no longer resolves;
- system/profile discipline mismatch;
- surface/room/project mismatch;
- mounting/environment evidence mismatch;
- required evidence missing;
- pinned topology evidence missing or mismatched;
- topology shape/role incompatible.

Whole-graph connection-dependent validation remains outside pre-placement P4.

---

# P4.8 — Rollback and failure injection

## 20. Deterministic failure seam

Provide a test-only injected fault interface equivalent to:

```text
EngineeringPlacementFailurePoint
- afterOperationClaim
- afterComponent
- afterMembership
- afterBinding
- beforePort(code)
- afterPort(code)
- beforeOperationComplete
- beforeHistoryPersist
- beforeCommit
```

Injection is a constructor/test dependency only. No debug flag is stored in project data or enabled in production flow.

## 21. Rollback proof

For every injected point, after the failed transaction assert final durable state:

```text
new active components        = 0
new active memberships       = 0
new active bindings          = 0
new active ports             = 0
new COMPLETED operations     = 0
new durable history records  = 0
```

An operation claim/state written in the same rolled-back transaction must also disappear. If implementation deliberately persists a non-transactional failure audit, that audit must be explicitly outside aggregate/idempotency semantics and cannot block safe retry.

SQLite `total_changes()` is not rollback evidence because it is cumulative. Assert actual table state.

## 22. Natural failure matrix

Also prove rollback for:

- invalid geometry/surface point;
- wrong project/room/surface relation;
- wrong discipline;
- missing system/catalog/profile/interface;
- deprecated/legacy profile;
- P2 forbidden/unresolved;
- existing active binding conflict;
- existing membership conflict;
- existing/manual port conflict;
- malformed profile/template duplicate;
- postcondition failure.

---

# P4.9 — Durable idempotent retry and concurrency

## 23. Operation state machine

Durable placement operation state MUST be explicit. Recommended state model:

```text
ABSENT
  ↓ claim
IN_PROGRESS
  ↓ same transaction success
COMPLETED
```

Because SQLite writes are serialized and the claim lives inside the placement transaction, a rolled-back operation returns effectively to `ABSENT`.

Do not persist a durable `FAILED` state that permanently poisons `operationId` unless retry semantics for that state are explicitly defined. For P4, rollback + retry is preferred.

## 24. Operation table

Preferred minimal additive persistence:

```text
EngineeringPlacementOperations
- operationId PRIMARY KEY
- commandFingerprint NOT NULL
- status NOT NULL
- componentId?
- systemId?
- binding identity?
- resultJson?
- createdAt
- completedAt?
```

The exact schema can be normalized, but it must support deterministic same-command replay after restart.

## 25. Canonical command fingerprint

Fingerprinting MUST NOT hash arbitrary `jsonEncode(command)` output unless canonical ordering/number encoding is guaranteed.

Define one canonical projection of material command fields:

```text
fingerprintVersion
projectId
roomId
systemId
catalogId
catalogVersion
profileCode
hostSurfacePatchId
localPosition.xMm
localPosition.yMm
normalized rotationRadians
canonical PlacementCandidateContext material evidence
normalized displayNameOverride if it is considered semantic
```

Rules:

- stable field order;
- stable enum names;
- explicit null representation;
- finite numeric values only;
- one documented numeric normalization strategy;
- fingerprint algorithm/version persisted or implied by an immutable schema version;
- changes to fingerprint semantics require migration/version handling, not silent reinterpretation.

## 26. Retry behavior

For same `operationId` + same fingerprint:

```text
COMPLETED -> return same EngineeringPlacementResult, zero mutation
ABSENT    -> execute normally
```

For same `operationId` + different fingerprint:

```text
IDEMPOTENCY_CONFLICT
```

## 27. Concurrent same-operation behavior

Two concurrent calls with same `operationId` MUST converge safely.

Acceptable outcomes:

```text
A succeeds; B subsequently observes COMPLETED and returns same result
```

or, if the implementation can observe an active claim:

```text
A owns claim; B returns OPERATION_IN_PROGRESS/retries; final durable aggregate count remains one
```

Unacceptable:

```text
2 components
2 memberships
2 bindings
2 port sets
```

Database PK/unique constraints should enforce the operation claim even if application-level locking fails.

## 28. Retry after crash/restart

Because successful operation result commits with the aggregate, after process/database restart the same operation must still return the same ids without additional writes.

There must be no committed state where aggregate rows exist but completed operation identity does not, or vice versa.

---

# P4.10 — Single undo/redo command

## 29. History boundary

The editor exposes one history action for one successful P4 aggregate:

```text
PlaceEngineeringProfileHistoryCommand
```

It contains enough durable identifiers/snapshot information to undo and redo exactly the P4-created aggregate.

A failed/forbidden/unresolved placement creates no history action.

## 30. Atomicity of history registration

Two supported designs are acceptable:

### Design A — durable database history

Persist the P4 history payload in the same database transaction as the aggregate and completed operation result. After commit, the editor loads/exposes that durable history entry.

### Design B — existing in-memory editor history

If project history is intentionally in-memory/session-only, the database transaction commits first and the in-memory history entry is appended synchronously before the UI reports the operation as fully handled. The contract must document recovery behavior if the process terminates after DB commit but before the in-memory append. Restart acceptance must not depend on in-memory history being durable.

P4 MUST NOT claim cross-restart undo durability unless the current history subsystem actually persists it.

This distinction avoids a false atomicity guarantee across two different storage systems.

## 31. Undo semantics

Undo operates on the complete aggregate in one transaction and dependency-safe order:

```text
ports
binding
membership
component
```

Soft-delete/retire vs physical delete follows existing repository conventions.

Before undo:

- enforce existing ELV deletion guards;
- if any P4-created port is now connected or otherwise referenced, unsafe undo is blocked with a structured history conflict;
- never cascade-delete later engineering work silently.

The completed placement operation record remains historical evidence; undo must not erase the fact that the original operation existed.

## 32. Redo semantics

Redo is **not** a normal retry of the original already-COMPLETED `operationId`.

Recommended contract:

```text
originalOperationId remains historical identity
redoExecutionId = new execution identity owned by history
restored aggregate preserves original profile/catalog provenance
```

Redo may restore the same component/port ids only if current persistence/soft-delete rules safely support reactivation and uniqueness. Otherwise it creates deterministic replacement runtime ids while the history payload preserves logical provenance. The chosen policy MUST be documented and tested before P4 is marked complete.

Redo must:

- re-check deletion/uniqueness preconditions;
- revalidate placement if current project geometry/system state can invalidate restoration;
- restore exactly one aggregate;
- never no-op merely because original `operationId` is completed;
- never create duplicates.

## 33. History invalidation

If subsequent work creates connections/references to the placed ports or otherwise makes destructive undo unsafe, history must either:

- mark that undo action unavailable with an explainable reason, or
- let repository guards reject undo and surface the structured conflict.

P4 must not bypass guards to preserve a simplistic undo stack.

---

# P4.11 — Four-discipline acceptance

## 34. Generic path

Use one generic P4 service for all fixtures. Discipline may determine profile data, but orchestration must not branch on CCTV/LAN/ACS/Fire.

### CCTV

```text
CAMERA
wall + bracket OR ceiling + surface
expected ports: ETH
```

Assert component, CCTV membership, frozen CAMERA binding, exact ETH template/interface provenance.

### LAN

```text
OUTLET
wall + flush OR wall + surface
expected ports: ETH
```

Assert LAN membership and exact Cat6/profile provenance.

### ACS

```text
READER
wall + surface
expected ports: BUS
```

Assert ACS membership and exact BUS/interface provenance.

### Fire

```text
DETECTOR
ceiling + surface
expected ports: IN, OUT
```

Assert both ports are persisted atomically and topology intent is compatible with the selected system profile.

Required architectural assertion:

```text
no switch/case on discipline inside atomic placement orchestration
```

---

# P4.12 — Restart acceptance

## 35. Restart flow

For every discipline fixture, or one table-driven suite covering all four:

```text
create project/room/surface/system/catalog
        ↓
P4 place
        ↓
assert aggregate + operation result
        ↓
close database
        ↓
reopen database
        ↓
load state
        ↓
assert exact aggregate/provenance
        ↓
retry same operationId + same command
        ↓
assert same result + zero duplicates
```

Restart assertions:

- same component id and geometry;
- same membership;
- same catalog id/version/profile code;
- same frozen profile/constraints snapshot;
- same port ids;
- same template/interface provenance;
- same completed operation result/fingerprint;
- no extra active rows;
- no dependency on in-memory idempotency state.

If history is session-only, restart tests do not require undo stack survival; they only require durable engineering aggregate/idempotency reconstruction.

---

# P4.13 — Exact-SHA CI gate

## 36. Required gate

P4 is complete only when push and PR-triggered workflows pass on the exact same branch head SHA.

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

PR #7 records:

- exact P4 SHA;
- push run;
- PR-triggered run;
- mobile/core test counts;
- P4 acceptance evidence.

PR #7 remains draft after P4 because P5–P7 remain required. ELV3 does not start after P4.

---

# Data model and database constraints

## 37. Minimal additive schema

Reuse existing component, engineering-system/membership, reference-binding and engineering-port tables.

A schema migration is expected only where necessary for durable placement operation/idempotency metadata and, if chosen, durable history metadata.

## 38. Database-enforced invariants

Prefer DB constraints/indexes for invariants that must survive concurrency/programming errors:

- `EngineeringPlacementOperations.operationId` unique/PK;
- one active binding per component;
- one active `(componentId, systemId)` membership;
- unique active port identity;
- unique active normalized port code per component where ELV1 contract requires it.

If current soft-delete design prevents a simple unique constraint, document the transactional enforcement and add explicit concurrent/conflict tests.

## 39. Foreign-key / ownership expectations

Where existing schema supports it, enforce or transactionally prove:

```text
component.roomId -> active room
membership.componentId -> component
binding.componentId -> component
ports.componentId -> component
operation result ids -> created aggregate
```

P4 must not depend on eventual cleanup jobs to restore referential correctness.

---

# Test specification

## 40. Contract/application tests

- required command-field validation;
- canonical fingerprint stability;
- fingerprint insensitive to map insertion order;
- fingerprint sensitive to material field changes;
- finite numeric normalization;
- exact profile/system discipline match;
- P2 COMPATIBLE/FORBIDDEN/UNRESOLVED policy;
- malformed/deprecated/legacy profile rejection;
- deterministic component/port identities;
- port identity independent of template list ordering when semantic template codes are unchanged.

## 41. SQLite/repository tests

- happy-path aggregate transaction;
- operation claim + completion in same commit;
- same-operation retry returns same result;
- same id + changed fingerprint conflicts;
- simulated concurrent same-operation calls converge to one aggregate;
- failure after operation claim rollback;
- failure after component rollback;
- failure after membership rollback;
- failure after binding rollback;
- failure before/after first/middle/last port rollback;
- failure before operation completion rollback;
- failure before durable history persist rollback if applicable;
- failure before commit rollback;
- manual port conflict rollback;
- binding/membership conflict rollback;
- exact interface provenance failure rollback;
- restart idempotency.

## 42. Editor/history tests

- COMPATIBLE preview can submit P4 command;
- P4 still revalidates independently;
- FORBIDDEN/UNRESOLVED produces no mutation/history;
- one success produces one visible undo action;
- undo removes/retires whole aggregate;
- undo is blocked after unsafe downstream connection/reference appears;
- redo restores exactly one aggregate according to documented redo identity policy;
- redo does not use completed `operationId` as a normal idempotent retry;
- failed P4 creates no history entry;
- existing electrical history behavior remains unaffected.

## 43. Four-discipline acceptance

Table-driven acceptance covers:

```text
CCTV CAMERA
LAN OUTLET
ACS READER
Fire DETECTOR
```

through the same P4 application/repository path.

---

# Acceptance criteria

### AC-P4-01 Atomic command
One immutable application command represents one canonical engineering placement.

### AC-P4-02 Single transaction
Component, membership, binding, ports and completed idempotency result share one database commit boundary.

### AC-P4-03 Exact resolution
Project/room/surface/system/catalog/profile are resolved by exact persisted identity; no latest/label fallback exists.

### AC-P4-04 Commit-time revalidation
P2 is rerun using current durable state; stale P3 preview cannot bypass constraints.

### AC-P4-05 Zero mutation on rejection
FORBIDDEN, UNRESOLVED, deprecated, legacy, missing edition and discipline mismatch leave zero new aggregate rows.

### AC-P4-06 Physical component
Exactly one valid `ComponentInstance` exists after success.

### AC-P4-07 Membership
Exactly one correct active system membership exists after success.

### AC-P4-08 Frozen binding
Exactly one binding freezes the exact catalog/profile/constraints snapshot.

### AC-P4-09 Ports
Exactly the profile-template port set exists with exact template/interface provenance.

### AC-P4-10 Aggregate postconditions
Binding `portIds`, persisted ports and completed operation result reference the same exact aggregate ids.

### AC-P4-11 Rollback
Every injected/natural failure leaves zero partial aggregate/completed-operation rows.

### AC-P4-12 Canonical fingerprint
Idempotency uses a versioned canonical semantic fingerprint, not incidental JSON/map ordering.

### AC-P4-13 Idempotent retry
Same operation id + same fingerprint returns the same result without new rows, including after restart.

### AC-P4-14 Idempotency conflict
Same operation id + changed material command is rejected.

### AC-P4-15 Concurrent duplicate safety
Concurrent same-operation submissions converge to one durable aggregate.

### AC-P4-16 Single history action
Successful placement appears as one reversible editor action.

### AC-P4-17 Safe undo
Undo is one transaction, preserves referential integrity and respects downstream ELV guards.

### AC-P4-18 Safe redo
Redo has explicit history-aware identity semantics and restores exactly one aggregate without relying on normal completed-operation retry.

### AC-P4-19 Restart reconstruction
Component/membership/binding/ports/idempotency/provenance reconstruct exactly after DB reopen.

### AC-P4-20 Four disciplines
CCTV/LAN/ACS/Fire pass through one discipline-agnostic orchestration path.

### AC-P4-21 No ELV3 coupling
No cable/pathway/route type or rule is introduced.

### AC-P4-22 Exact-SHA evidence
Push and PR workflows are green on the exact same P4 head SHA.

---

# Definition of Done

P4 is done only when all items below are true:

- [ ] `PlaceEngineeringProfileCommand` implemented and immutable;
- [ ] typed result/failure contracts implemented;
- [ ] durable `operationId` implemented;
- [ ] versioned canonical command fingerprint implemented;
- [ ] one top-level Drift transaction owns all durable P4 aggregate writes;
- [ ] operation claim/conflict/completion occurs inside the transaction;
- [ ] exact project/room/surface/system/catalog/profile resolution implemented;
- [ ] P2 commit-time revalidation implemented;
- [ ] physical component uses existing geometry invariants;
- [ ] engineering-system membership persisted;
- [ ] frozen `ComponentReferenceBinding` persisted;
- [ ] deterministic exact profile ports persisted;
- [ ] exact template/interface provenance persisted;
- [ ] binding portIds equal persisted port ids;
- [ ] aggregate postconditions asserted before commit;
- [ ] zero durable mutation for rejected placement;
- [ ] deterministic test fault injection implemented;
- [ ] rollback proven after every durable stage;
- [ ] same-operation retry proven idempotent;
- [ ] changed-command same-id conflict proven;
- [ ] concurrent same-operation convergence proven;
- [ ] idempotency survives restart;
- [ ] one editor history action per successful placement;
- [ ] history storage durability semantics documented honestly;
- [ ] undo removes/retires whole aggregate safely;
- [ ] downstream references block unsafe undo;
- [ ] redo identity/reactivation strategy documented and tested;
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

# Recommended implementation sequence

```text
P4.1  Command/result/failure contracts
      + operationId + canonical fingerprint contract
  ↓
P4.2  Operation table/schema + dedicated transaction owner
      + database uniqueness/concurrency guards
  ↓
P4.3  Component identity + ComponentInstance creation
  ↓
P4.4  EngineeringSystem membership persistence
  ↓
P4.5  Frozen ComponentReferenceBinding snapshot
  ↓
P4.6  Deterministic persisted ports + exact provenance
  ↓
P4.7  Commit-time state reconstruction + P2 revalidation
  ↓
P4.8  Fault injection + rollback/postcondition matrix
  ↓
P4.9  Retry + concurrent duplicate + restart idempotency
  ↓
P4.10 History durability decision + single undo/redo aggregate action
  ↓
P4.11 CCTV/LAN/ACS/Fire acceptance
  ↓
P4.12 Full DB restart acceptance
  ↓
P4.13 Exact-head push + PR CI and PR evidence
```

P5 starts only after all P4 acceptance criteria above are green.