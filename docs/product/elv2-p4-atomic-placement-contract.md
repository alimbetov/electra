# ELV2-P4 — atomic canonical placement

Status: implementation contract v1.2 — **AUDITED / READY TO IMPLEMENT**  
Branch: `feat/flutter-elv2-profile-constraints`  
Parent: [ELV2 technical specification](elv2-profile-constraints-technical-specification.md)  
Pre-placement UI: [P3 palette contract](elv2-p3-palette-contract.md)  
Decision engine: [P2 placement compatibility contract](elv2-p2-placement-compatibility-contract.md)  
Project-alignment audit: [P4 contract audit](../audit/elv2-p4-contract-project-alignment-audit.md)

> Revision note: v1.2 incorporates the P4 project-alignment audit. It resolves membership-role ownership, `ComponentInstance.definitionId/definitionVersion`, P3→P4 surface identity, `COMPLETED ↔ UNDONE` idempotency/history semantics, the mandatory placement-operation ledger, session-only editor history, transaction-scoped persistence seams, persisted-once aggregate ids, hierarchy ownership checks, canonical numeric fingerprinting and aggregate postconditions.

## 1. Purpose

P4 turns the read-only P3 preview into one durable engineering operation. A successful command creates exactly one placed physical component, establishes its engineering-system membership, freezes the exact canonical catalog/profile binding, instantiates persisted ELV1 ports, and commits a durable placement-operation result in the same database transaction.

The current editor undo/redo subsystem is session-only. Therefore the durable P4 transaction and the in-memory history stack have explicitly different durability guarantees: the engineering aggregate and placement-operation ledger survive restart; the editor undo stack does not.

P4 covers **new canonical placement only**. Catalog revision impact, replacement and adoption remain P5/P6.

Target flow:

```text
P3 canonical profile + candidate preview
        ↓
PlaceEngineeringProfileCommand
        │
        ├── validate command shape
        ├── resolve operationId / fingerprint state
        ├── resolve exact project / room / SurfacePatch
        ├── resolve exact EngineeringSystem + family edition
        ├── resolve exact catalog edition + profile
        ├── resolve canonical physical ComponentDefinition
        ├── reconstruct commit-time candidate evidence
        └── P2 revalidation
                ↓
        BEGIN DATABASE TRANSACTION
                ↓
        claim/check operationId
                ↓
        create ComponentInstance
                ↓
        create EngineeringSystem membership + role
                ↓
        instantiate exact persisted EngineeringPorts
                ↓
        create frozen ComponentReferenceBinding with exact portIds
                ↓
        assert aggregate postconditions
                ↓
        persist placement operation as COMPLETED
                ↓
        COMMIT
                ↓
        append one session history entry
```

If any durable step fails, the transaction rolls back every row created by the operation. No component, membership, binding, subset of ports or completed operation record may survive a failed placement.

---

## 2. Engineering principles

1. **One physical component.** One logical placement operation creates at most one `ComponentInstance`.
2. **One atomic engineering aggregate.** Component, membership, frozen binding, ports and placement-operation result share one commit boundary.
3. **Revalidate at commit.** A P3 preview is evidence shown to the user, not authorization to persist.
4. **Exact provenance.** P4 uses exact catalog id/version/profile code and freezes the corresponding profile snapshot.
5. **No silent latest lookup.** P4 never substitutes a newer catalog/profile/system/topology edition.
6. **One existing physical model.** P4 reuses `ComponentInstance`; no parallel ELV device entity is introduced.
7. **ELV1 graph remains authoritative.** Profile ports become real persisted ELV1 `EngineeringPort` objects.
8. **Rollback is total.** Any failure before commit produces zero new durable aggregate rows.
9. **Retry is durable and idempotent.** Same operation + same semantic command converges to one result, including after restart.
10. **Command identity is semantic.** Idempotency uses a versioned canonical fingerprint, not arbitrary JSON ordering.
11. **Concurrency is explicit.** Concurrent same-operation submissions cannot create duplicate aggregates.
12. **Membership role is explicit.** System membership role is not inferred from topology participation role unless the domain explicitly defines such mapping.
13. **History is session-only in current architecture.** Restart persistence must never depend on the undo stack.
14. **Undo/redo is aggregate-level.** One placement becomes one reversible session history entry.
15. **Undo respects later work.** Existing ELV deletion/topology guards may block undo after connections/groups/internal mappings are added.
16. **No hidden repair.** Corrupt/conflicting active state is rejected, not silently adopted or normalized.
17. **No ELV3 leakage.** P4 creates no cables, cable runs, pathways, routes or cable-compatibility rules.

---

## 3. Scope

### 3.1 In scope

- atomic placement application command;
- exact project/room/surface-patch/system/catalog/profile resolution;
- explicit membership role;
- canonical physical `ComponentDefinition` strategy;
- commit-time P2 compatibility revalidation;
- physical `ComponentInstance` creation;
- engineering-system membership creation;
- immutable `ComponentReferenceBinding` creation;
- persisted ELV1 port instantiation from profile templates;
- exact template/interface/catalog/profile provenance;
- mandatory durable placement-operation ledger;
- canonical command fingerprinting;
- concurrency-safe idempotency;
- deterministic rollback/failure injection;
- one session-only aggregate undo/redo action;
- CCTV/LAN/ACS/Fire acceptance scenarios;
- database restart verification;
- exact-SHA push + PR CI gates.

### 3.2 Out of scope

- catalog v2 adoption/migration;
- profile replacement for existing components;
- connected-port migration;
- revision impact preview;
- connection creation as part of placement;
- topology-group mutation beyond current membership facts;
- whole-graph loop/degree/branch validation requiring existing connections;
- durable/cross-restart editor-history redesign;
- cables, `CableRun`, routes and pathways;
- PoE, PSU, UPS or battery calculations;
- normative override workflow for forbidden/unresolved placement;
- manufacturer BOM selection.

---

# P4.1 — Atomic command contract

## 4. Command

Introduce an immutable application-level command equivalent to:

```text
PlaceEngineeringProfileCommand
- operationId
- projectId
- roomId
- systemId
- membershipRole
- catalogId
- catalogVersion
- profileCode
- hostSurfacePatchId
- localPosition
- rotationRadians
- placementContext
- displayNameOverride?
```

The command contains user intent and reviewed candidate evidence. It does not contain trusted copies of system discipline, catalog/profile objects, interface definitions or database rows; those are resolved from persistence.

### 4.1 `operationId`

`operationId` is a stable client-generated UUID/string for one logical placement attempt.

Rules:

- non-empty and immutable;
- generated before the first mutation request;
- reused only for retrying the same logical placement after uncertainty;
- materially different intended placement uses a new id;
- not derived solely from coordinates, display name, profile code or generated component id;
- normal redo is **not** a retry of an old `COMPLETED` operation.

### 4.2 Membership role

`ComponentSystemMembership` currently persists a non-null `role`; therefore P4 MUST have a canonical source for it.

For P4 v1.2 the role is an explicit command field:

```text
command.membershipRole -> ComponentSystemMembership.role
```

Rules:

- trim and validate using the existing membership domain contract;
- empty/invalid role -> `INVALID_COMMAND`;
- role is included in the canonical command fingerprint;
- role is not silently copied from `PlacementCandidateContext.topologyRole`;
- if a future domain model defines a canonical profile→membership-role mapping, that is a later explicit contract change.

### 4.3 P3→P4 surface identity

Current P3 populates `PlacementCandidateContext.surfaceId` with `SurfacePatch.id`. P4 therefore MUST validate:

```text
context.projectId == command.projectId
context.roomId == command.roomId
context.surfaceId == command.hostSurfacePatchId
resolvedPatch.id == command.hostSurfacePatchId
resolvedPatch.roomId == command.roomId
resolvedRoom.floorId -> floor.projectId == command.projectId
resolvedSystem.projectId == command.projectId
```

P4 MUST NOT compare `context.surfaceId` with `SurfacePatch.surfaceId`; those are different identifiers in the current model.

A future rename from `PlacementCandidateContext.surfaceId` to `surfacePatchId` is allowed, but P4 does not require that refactor.

### 4.4 Result

Return an immutable result equivalent to:

```text
EngineeringPlacementResult
- operationId
- componentId
- systemId
- membershipRole
- catalogId
- catalogVersion
- profileCode
- binding identity
- portIds[]
- placementStatus
- committedAt
```

For a `COMPLETED` operation the exact result is persisted in the operation ledger. A same-command retry returns the same ids without new aggregate rows.

### 4.5 Typed failure model

Minimum categories:

```text
INVALID_COMMAND
PROJECT_NOT_FOUND
ROOM_NOT_FOUND
SURFACE_PATCH_NOT_FOUND
SYSTEM_NOT_FOUND
SYSTEM_PROJECT_MISMATCH
SYSTEM_DISCIPLINE_MISMATCH
COMPONENT_DEFINITION_NOT_FOUND
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
OPERATION_UNDONE
HISTORY_CONFLICT
TRANSACTION_FAILED
```

Failures may carry structured P2 findings, conflicting ids and expected/actual provenance. UI strings are presentation only.

---

# P4.2 — Repository transaction boundary

## 5. Dedicated transaction owner

P4 MUST use one dedicated atomic owner, preferably:

```text
EngineeringPlacementRepository
  place(command)
  undo(operationId)
  redo(historyEntry)
```

backed by one top-level `AppDatabase.transaction` / existing `LocalUnitOfWork`.

P4 MUST NOT orchestrate these independently committing public operations:

```text
ComponentInstanceRepository.saveComponent()
EngineeringSystemRepository.assign()
EngineeringReferenceRepository.bind()
EngineeringTopologyRepository.savePort()
```

Instead extract/reuse their validation logic through transaction-scoped internal helpers/DAOs that do **not** open independent commit boundaries.

Required reusable seams should conceptually separate:

```text
validate component geometry      / insert component
validate membership              / insert membership
validate binding preconditions   / insert binding
validate port                     / insert port
```

Existing standalone repository behavior must remain unchanged.

## 6. Transaction sequence

Inside one transaction:

```text
1. validate command and canonical fingerprint input
2. read placement-operation row by operationId
3. COMPLETED + same fingerprint -> return stored active result
4. UNDONE + normal retry -> OPERATION_UNDONE
5. same operationId + different fingerprint -> IDEMPOTENCY_CONFLICT
6. resolve project -> room -> floor/project ownership
7. resolve exact SurfacePatch and room ownership
8. resolve system + exact family edition + discipline
9. resolve exact catalog id + exact catalogVersion + profile code
10. resolve canonical physical ComponentDefinition
11. validate membershipRole
12. reconstruct commit-time PlacementCandidateContext
13. run P2 and enforce commit policy
14. generate aggregate ids once
15. insert component
16. insert membership
17. instantiate and insert all ports
18. insert frozen binding with exact portIds
19. assert aggregate postconditions
20. insert/update placement-operation row as COMPLETED with exact result
21. commit
```

No aggregate mutation happens before idempotency conflict detection and commit-time validation are complete.

## 7. Transaction observation

- Drift watchers must not observe a successful active component without required P4 membership/binding/ports after commit.
- UI success and session history registration occur only after database commit.
- post-commit UI work may refresh state but must not perform required durable aggregate writes.

## 8. Aggregate postconditions

Before commit assert at minimum:

```text
1 active ComponentInstance == result.componentId
component.roomId == command.roomId
component.hostSurfacePatchId == command.hostSurfacePatchId
component.definitionId/version == canonical ELV physical definition

1 active membership (componentId, systemId)
membership.role == normalized command.membershipRole
system.projectId == command.projectId

1 active binding for componentId
binding catalogId/version/profileCode == exact command edition

N active ports where N == profile.portTemplates.length
set(binding.portIds) == set(persisted port ids)
all ports.componentId == componentId
all port template/interface provenance resolves to frozen exact edition

COMPLETED operation result references exactly this aggregate
```

Failure causes rollback, never hidden repair.

---

# P4.3 — Component creation

## 9. Physical component

P4 creates the existing `ComponentInstance`. It MUST NOT introduce `ElvDeviceInstance` or another parallel physical entity.

Required checks:

- project active;
- floor/project and room/floor ownership valid;
- host patch active and belongs to room;
- local point passes existing `ComponentPlacementValidator`/geometry invariants;
- rotation is finite;
- manufacturer SKU/display name is not engineering identity.

## 10. Canonical physical ComponentDefinition

Current `ComponentInstance` requires non-null `definitionId` and `definitionVersion`, while P3 selects a `ComponentEngineeringProfile` rather than a component-catalog definition.

P4 therefore MUST introduce/reuse one documented canonical physical definition for generic ELV profile placement, for example:

```text
ELV_CANONICAL_DEVICE / version 1
```

Exact constant/name may follow existing catalog naming conventions, but the contract is:

```text
ComponentDefinition
  -> physical/editor representation

ComponentReferenceBinding
  -> engineering identity and exact canonical profile provenance
```

Rules:

- definition identity/version are stable and code-defined/catalog-defined, not derived from translated display labels, manufacturer SKU, discipline or profile code;
- P4 resolves this definition before mutation;
- missing canonical physical definition -> `COMPONENT_DEFINITION_NOT_FOUND`;
- CCTV/LAN/ACS/Fire use the same physical-definition strategy;
- engineering semantics remain in the frozen binding, not in `definitionId`.

## 11. Component and port ids

Deterministic derivation from `operationId` is **not required**.

P4 may use the existing `IdGenerator` to generate component and port ids exactly once during the successful transaction. Those ids are persisted both in aggregate rows and `EngineeringPlacementResult` before the same commit.

Rules:

- retry of `COMPLETED` returns stored ids, never regenerates;
- rollback leaves no durable ids/aggregate, so a later retry may legitimately generate different transient ids;
- redo uses ids/snapshot stored in the session history payload where safe to reactivate; otherwise it follows the explicit redo policy below;
- duplicate template codes are rejected before port insertion;
- port identity never depends on template list index as semantic identity.

---

# P4.4 — Engineering-system membership

## 12. Membership invariants

Create exactly one active membership using the current membership table/schema.

Required:

- system belongs to project;
- exact system family/version resolves;
- family discipline equals `profile.discipline`;
- membership role equals normalized `command.membershipRole`;
- duplicate active `(componentId, systemId)` forbidden;
- no implicit cross-discipline extra memberships;
- existing conflicting active state rejected, not repaired;
- rollback leaves no membership without its component.

---

# P4.5 — Frozen binding

## 13. Binding snapshot

Create exactly one active `ComponentReferenceBinding` and freeze:

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

Rules:

- exact `catalogId` **and** exact `catalogVersion` from command must match the persisted catalog row/payload;
- no latest lookup;
- profile publication-valid for new placement;
- no `legacyUnspecified`;
- no deprecated profile;
- discipline matches resolved system family;
- one active binding per component;
- `portIds` equal exact persisted P4 ports;
- future P5/P6 use this frozen snapshot as provenance anchor.

P4 must not call the existing public `bind()` as an orchestration primitive because that method owns its own transaction and currently instantiates ports internally. Extract/reuse equivalent validation/write logic inside the P4 transaction instead.

---

# P4.6 — Persisted port instantiation

## 14. Port instantiation

For every `profile.portTemplates` entry create exactly one persisted `EngineeringPort` using existing ELV1 semantics.

Preserve:

- template code;
- kind;
- direction;
- capacity;
- connector;
- protocol/version;
- electrical metadata;
- exact template provenance;
- exact interface code/version/provenance resolved from the selected catalog vocabulary.

No active manually authored port may be overwritten/adopted because its code happens to match.

P4 must not call public per-port `savePort()` as the transaction orchestration primitive. Its graph validation, frozen-port checks and unique-code logic should be preserved through transaction-scoped reusable validation/write seams.

## 15. Port identity and ordering

- generate/persist port ids once in the successful placement transaction;
- map generated ids by normalized template code, not list index;
- duplicate normalized template codes -> `PORT_CONFLICT` before mutation;
- template reordering alone must not change semantic template identity;
- same `COMPLETED` retry returns stored port ids.

## 16. Interface provenance

Any `portInterfaceCodes` reference must resolve in the exact selected catalog vocabulary. Missing/ambiguous interface provenance is invalid catalog state / `PORT_CONFLICT` and rolls back the operation.

## 17. All-or-nothing

For N templates success requires exactly N active persisted ports. Partial port sets never survive rollback.

---

# P4.7 — P2 revalidation at commit

## 18. Revalidation

P4 invokes the existing `PlacementCompatibilityEngine` with:

- exact resolved profile edition;
- current project/room/**SurfacePatch.id** identity;
- current pinned topology evidence where applicable;
- candidate mounting/environment evidence from the command that is still applicable.

The P3 result is never reused as a trusted boolean.

## 19. Commit policy

```text
COMPATIBLE  -> may proceed
WARNING     -> only if a separately defined product policy permits the warning class
FORBIDDEN   -> zero mutation
UNRESOLVED  -> zero mutation
```

P4 invents no warning exceptions.

Stale-state checks include exact catalog/version/profile availability, system/family edition, discipline, patch/room/project hierarchy, mounting/environment evidence, required evidence and pinned topology shape/role.

---

# P4.8 — Rollback and failure injection

## 20. Test-only failure seam

```text
EngineeringPlacementFailurePoint
- afterOperationCheck
- afterComponent
- afterMembership
- beforePort(code)
- afterPort(code)
- afterBinding
- beforeOperationComplete
- beforeCommit
```

History append is session-only and occurs after DB commit, so it is not a database rollback point.

## 21. Rollback proof

For every injected durable failure assert final state:

```text
new active components    = 0
new active memberships   = 0
new active bindings      = 0
new active ports         = 0
new COMPLETED operations = 0
```

SQLite `total_changes()` is not rollback evidence; inspect actual durable state.

Natural failure cases include invalid geometry/hierarchy, invalid role, missing physical definition, wrong discipline, exact catalog-version mismatch, deprecated/legacy profile, P2 forbidden/unresolved, active binding/membership/manual-port conflict, duplicate template code, interface provenance failure and postcondition failure.

---

# P4.9 — Durable idempotent retry and concurrency

## 22. Mandatory operation ledger

A durable placement-operation table is **required**, not optional, because P4 guarantees restart-safe idempotency.

Minimum logical schema:

```text
EngineeringPlacementOperations
- operationId PRIMARY KEY
- projectId NOT NULL
- fingerprintVersion NOT NULL
- commandFingerprint NOT NULL
- status NOT NULL              // COMPLETED | UNDONE
- componentId NOT NULL
- resultJson NOT NULL
- createdAt NOT NULL
- updatedAt NOT NULL
- originDeviceId NOT NULL
```

Additional normalized result columns are allowed, but `resultJson`/equivalent must reconstruct the exact `EngineeringPlacementResult`.

Schema migration is therefore an expected P4 change.

`IN_PROGRESS` need not be durable: with SQLite serialization the claim/check and aggregate creation occur inside one transaction. Rollback returns effectively to `ABSENT`.

## 23. Operation lifecycle

```text
ABSENT
  ↓ successful place transaction
COMPLETED
  ↓ successful history undo transaction
UNDONE
  ↓ explicit history-aware redo transaction
COMPLETED
```

There is no durable `FAILED` state in P4.

### Normal retry rules

```text
ABSENT + command
  -> execute placement

COMPLETED + same fingerprint
  -> return stored result, zero mutation

COMPLETED + different fingerprint
  -> IDEMPOTENCY_CONFLICT

UNDONE + normal place retry
  -> OPERATION_UNDONE

UNDONE + different fingerprint
  -> IDEMPOTENCY_CONFLICT
```

Only explicit history-aware redo may transition `UNDONE -> COMPLETED`.

## 24. Canonical command fingerprint

Fingerprint projection includes at minimum:

```text
fingerprintVersion
projectId
roomId
systemId
normalized membershipRole
catalogId
catalogVersion
profileCode
hostSurfacePatchId
localPosition.xMm
localPosition.yMm
normalized rotationRadians
canonical PlacementCandidateContext material evidence
normalized displayNameOverride? if semantic
```

Rules:

- stable field order;
- stable enum names;
- explicit null encoding;
- only finite numeric inputs;
- integer millimetres remain integer canonical values;
- floating values such as rotation use one documented canonical representation (for example normalized finite IEEE-754 value encoded by a dedicated canonical formatter), never locale-dependent text;
- canonical nested maps/lists use deterministic key/order rules appropriate to their semantics;
- fingerprint algorithm/version is persisted;
- semantic changes require new fingerprint version/migration handling.

## 25. Concurrent same-operation behavior

Database PK uniqueness on `operationId` is the final guard.

Acceptable:

```text
A commits COMPLETED; B then reads same COMPLETED result
```

or B receives a transient database/operation-in-progress outcome and retries to the same result.

Never acceptable: duplicate component/membership/binding/port sets.

## 26. Restart

Because operation result commits with the aggregate, restart must preserve exact result/idempotency. There must be no committed split-brain where active aggregate exists without its `COMPLETED` operation row or vice versa.

---

# P4.10 — Single session undo/redo command

## 27. Current history durability boundary

Electra currently uses `ComponentPlacementHistory` as **session history**. P4 follows that architecture; it does not introduce durable editor-history persistence.

After successful DB commit, append one in-memory entry equivalent to:

```text
EngineeringPlacementHistoryEntry
- operationId
- command snapshot/fingerprint
- EngineeringPlacementResult
- aggregate snapshot needed for restore
```

If the process terminates after DB commit but before session-history append, the engineering aggregate and operation ledger remain correct; only that undo opportunity is lost. Restart acceptance therefore does not require history survival.

## 28. Undo

Undo is a dedicated repository transaction, not a sequence of current public repository calls.

Before mutation it must run existing ELV safety semantics against the aggregate:

- any connection touching created ports -> block `HISTORY_CONFLICT`;
- internal mappings/topology-group attachments -> block;
- any other downstream ownership/reference that would make removal unsafe -> block;
- never bypass `guardComponentElvPorts` / `guardSystemElvTopology` intent by blindly deleting rows.

If safe, retire in dependency-safe transaction order:

```text
ports
binding
membership
component
operation status: COMPLETED -> UNDONE
```

No orphan active row may remain.

## 29. Redo

Redo is explicit history-aware execution against an `UNDONE` operation, not a normal call to `place()` with the old operation id.

Required policy for P4:

- use the history entry + durable operation result as restore source;
- re-check current project/room/patch/system/catalog/profile and P2 compatibility;
- reactivate/reinsert the same logical aggregate with the same component/port ids when current soft-delete and uniqueness rules permit;
- if those exact ids are now occupied by conflicting active identities, fail `HISTORY_CONFLICT`; do not silently mint a semantically different replacement aggregate;
- restore binding/membership/provenance exactly once;
- operation status transitions `UNDONE -> COMPLETED` in the same restore transaction;
- no duplicate rows.

This exact-id restore policy keeps the persisted `EngineeringPlacementResult` truthful across undo/redo.

## 30. Existing electrical history

P4 must not regress the existing electrical `ComponentPlacementHistory`. ELV canonical placement may use a parallel aggregate-aware session history adapter or generalize the history abstraction, but existing electrical behavior remains green.

---

# P4.11 — Four-discipline acceptance

## 31. Generic orchestration

One P4 path handles all fixtures. No `switch/case` on CCTV/LAN/ACS/Fire is allowed inside atomic placement orchestration.

Every fixture supplies an explicit valid `membershipRole` appropriate to the test; the placement service treats it generically.

### CCTV

```text
CAMERA
wall + bracket OR ceiling + surface
ports: ETH
```

### LAN

```text
OUTLET
wall + flush OR wall + surface
ports: ETH
```

### ACS

```text
READER
wall + surface
ports: BUS
```

### Fire

```text
DETECTOR
ceiling + surface
ports: IN, OUT
```

Each acceptance asserts physical component, exact membership+role, frozen binding and exact template/interface provenance.

---

# P4.12 — Restart acceptance

## 32. Restart flow

For each discipline, or one table-driven suite covering all four:

```text
create project/room/patch/system/catalog
        ↓
P4 place
        ↓
assert aggregate + COMPLETED operation
        ↓
close DB
        ↓
reopen DB
        ↓
assert exact component/membership/binding/ports/result
        ↓
retry same operationId + same command
        ↓
assert same result + zero duplicates
```

Assert:

- same component id/geometry/definition id+version;
- same membership and role;
- same catalog id/version/profile code;
- same frozen profile/constraints;
- same port ids/template/interface provenance;
- same fingerprint version/hash and result;
- no extra active rows;
- undo stack is not expected to survive restart.

---

# P4.13 — Exact-SHA CI gate

## 33. Required gate

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

PR #7 records exact P4 SHA, both workflow runs, test counts and P4 acceptance evidence. PR remains draft for P5–P7. ELV3 does not start after P4.

---

# 34. Database and migration requirements

P4 reuses existing tables for:

```text
ComponentInstances
ComponentEngineeringMemberships
ComponentReferenceBindings
EngineeringPortInstances
```

and adds the mandatory `EngineeringPlacementOperations` migration.

Prefer DB/transactional enforcement for:

- operationId PK uniqueness;
- one active binding per component;
- one active `(componentId, systemId)` membership;
- unique active port identity/code per component according to ELV1 contract;
- FK/ownership relationships where existing schema permits them.

If soft-delete prevents a simple unique index, enforce within the single write transaction and cover conflicts/concurrency with tests.

Hierarchy ownership MUST be proven by the actual current model:

```text
SurfacePatch.roomId == Room.id
Room.floorId == Floor.id
Floor.projectId == Project.id
EngineeringSystem.projectId == Project.id
EngineeringReferenceCatalog.projectId == Project.id
```

Catalog id alone is insufficient: persisted `catalogVersion`/payload edition must equal the command version.

---

# 35. Test specification

## 35.1 Contract/application

- required command validation, including `membershipRole`;
- P3 `context.surfaceId == hostSurfacePatchId` contract;
- canonical fingerprint stable across map insertion order;
- fingerprint sensitive to membership role and other material fields;
- finite numeric normalization;
- exact system/family/profile discipline;
- exact catalog id + version;
- canonical physical ComponentDefinition resolution;
- P2 COMPATIBLE/FORBIDDEN/UNRESOLVED policy;
- malformed/deprecated/legacy rejection.

## 35.2 SQLite/repository

- happy-path one-transaction aggregate;
- exact hierarchy ownership checks;
- operation `COMPLETED` committed with aggregate;
- same-operation retry returns same result;
- same id + changed fingerprint conflicts;
- `UNDONE` normal retry -> `OPERATION_UNDONE`;
- simulated concurrent same-operation calls converge;
- failure after component/membership/each port/binding/before operation completion/before commit -> total rollback;
- manual port/binding/membership conflict rollback;
- interface provenance failure rollback;
- exact aggregate postconditions;
- restart idempotency.

## 35.3 History

- one success -> one session undo entry;
- no history entry for failed/rejected placement;
- undo retires whole aggregate + marks operation UNDONE;
- downstream connection/internal/group reference blocks undo;
- normal retry while UNDONE is rejected;
- explicit redo restores exact ids/provenance once and marks COMPLETED;
- redo conflict on occupied ids is explainable;
- existing electrical placement history remains green;
- restart does not claim undo-stack durability.

## 35.4 Four disciplines

Table-driven CCTV CAMERA, LAN OUTLET, ACS READER and Fire DETECTOR use the same P4 service, same canonical physical ComponentDefinition strategy and generic membership-role persistence.

---

# 36. Acceptance criteria

### AC-P4-01 Atomic command
One immutable command represents one canonical engineering placement.

### AC-P4-02 Explicit membership role
Successful placement persists the exact validated command role; no topology-role guessing occurs.

### AC-P4-03 Canonical physical definition
Every ELV canonical placement creates a normal `ComponentInstance` with the documented shared physical `definitionId/version` strategy.

### AC-P4-04 Correct surface identity
P3 candidate surface identity is validated against `SurfacePatch.id` / `hostSurfacePatchId`, not `SurfacePatch.surfaceId`.

### AC-P4-05 Single transaction
Component, membership, ports, binding and completed operation result share one commit boundary.

### AC-P4-06 Exact resolution
Project hierarchy, patch, system/family and catalog id/version/profile are exact; no latest/label fallback.

### AC-P4-07 Commit-time P2 revalidation
Stale P3 preview cannot bypass current constraints.

### AC-P4-08 Zero mutation on rejection
Rejected/invalid placements leave zero new aggregate rows.

### AC-P4-09 Physical component
Exactly one valid `ComponentInstance` exists after success.

### AC-P4-10 Membership
Exactly one correct active membership with exact role exists.

### AC-P4-11 Frozen binding
Exactly one binding freezes exact catalog/profile/constraints snapshot.

### AC-P4-12 Ports
Exactly the template port set exists with exact provenance.

### AC-P4-13 Aggregate postconditions
Binding portIds, persisted ports and operation result reference the same aggregate.

### AC-P4-14 Rollback
Every injected/natural durable failure leaves zero partial aggregate/completed-operation rows.

### AC-P4-15 Mandatory durable ledger
Restart-safe `EngineeringPlacementOperations` persistence exists.

### AC-P4-16 Canonical fingerprint
Idempotency uses a versioned deterministic semantic fingerprint.

### AC-P4-17 Completed retry
Same COMPLETED operation + same fingerprint returns same result with zero mutation.

### AC-P4-18 Idempotency conflict
Same operation id + changed semantic command is rejected.

### AC-P4-19 Undo lifecycle
Successful aggregate undo transitions `COMPLETED -> UNDONE` atomically.

### AC-P4-20 Retry-after-undo
Normal place retry of UNDONE returns `OPERATION_UNDONE` and does not resurrect state.

### AC-P4-21 History-aware redo
Only explicit redo restores UNDONE -> COMPLETED, with exact aggregate ids/provenance or an explainable conflict.

### AC-P4-22 Concurrent duplicate safety
Concurrent same-operation submissions converge to one aggregate.

### AC-P4-23 Session-only history honesty
P4 does not claim cross-restart undo durability.

### AC-P4-24 Guarded undo
Later connections/internal/group references block destructive undo.

### AC-P4-25 Restart reconstruction
Aggregate and operation result reconstruct exactly after DB reopen.

### AC-P4-26 Four disciplines
CCTV/LAN/ACS/Fire pass through one discipline-agnostic orchestration path.

### AC-P4-27 No ELV3 coupling
No cable/pathway/route type or rule is introduced.

### AC-P4-28 Exact-SHA evidence
Push and PR workflows are green on the exact same P4 head SHA.

---

# 37. Definition of Done

P4 is done only when:

- [ ] command/result/failure contracts implemented;
- [ ] explicit validated `membershipRole` implemented and fingerprinted;
- [ ] P3 surfacePatch identity contract implemented;
- [ ] canonical shared ELV physical `ComponentDefinition` strategy implemented;
- [ ] mandatory placement-operation migration implemented;
- [ ] operation lifecycle `COMPLETED ↔ UNDONE` implemented;
- [ ] one top-level Drift transaction owns every durable P4 write;
- [ ] current independently transactional public repository methods are not composed as P4 write steps;
- [ ] transaction-scoped component/membership/port/binding validation/write seams exist;
- [ ] exact project/floor/room/patch/system/family/catalog-version/profile checks implemented;
- [ ] P2 commit-time revalidation implemented;
- [ ] component uses current geometry invariants;
- [ ] membership + exact role persisted;
- [ ] frozen binding persisted;
- [ ] exact profile ports/provenance persisted;
- [ ] generated ids are persisted once and replayed from operation result;
- [ ] binding portIds equal persisted port ids;
- [ ] aggregate postconditions asserted before commit;
- [ ] zero durable mutation for rejected placement;
- [ ] deterministic fault injection and rollback matrix green;
- [ ] completed retry/idempotency conflict/concurrency green;
- [ ] idempotency survives restart;
- [ ] one session history entry per successful placement;
- [ ] undo retires whole aggregate safely and marks UNDONE;
- [ ] downstream references block unsafe undo;
- [ ] normal retry of UNDONE is rejected;
- [ ] redo restores exact aggregate once and marks COMPLETED;
- [ ] existing electrical history remains unaffected;
- [ ] CCTV CAMERA acceptance green;
- [ ] LAN OUTLET acceptance green;
- [ ] ACS READER acceptance green;
- [ ] Fire DETECTOR acceptance green;
- [ ] all four survive restart with exact provenance;
- [ ] no ELV3 types/dependencies introduced;
- [ ] mobile/core format/analyze/tests green;
- [ ] push and PR workflows green on exact same SHA;
- [ ] PR #7 records P4 exact-SHA evidence and remains draft for P5–P7.

---

# 38. Recommended implementation sequence

```text
P4.1  Command/result/failure contracts
      + membershipRole
      + canonical fingerprint v1
      + surfacePatch identity
  ↓
P4.2  EngineeringPlacementOperations schema/migration
      + dedicated atomic transaction owner
      + transaction-scoped persistence seams
  ↓
P4.3  canonical ELV physical ComponentDefinition
      + ComponentInstance creation + persisted-once ids
  ↓
P4.4  EngineeringSystem membership + exact role
  ↓
P4.5  Frozen ComponentReferenceBinding
  ↓
P4.6  Persisted ports + exact template/interface provenance
  ↓
P4.7  Commit-time state reconstruction + P2 revalidation
  ↓
P4.8  Fault injection + rollback/postcondition matrix
  ↓
P4.9  COMPLETED/UNDONE lifecycle
      + retry/concurrency/restart idempotency
  ↓
P4.10 Session aggregate history + guarded undo + explicit redo
  ↓
P4.11 CCTV/LAN/ACS/Fire acceptance
  ↓
P4.12 Full database restart acceptance
  ↓
P4.13 Exact-head push + PR CI and PR evidence
```

P5 starts only after all P4 acceptance criteria above are green.