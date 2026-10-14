# ELV2-P4 — atomic canonical placement

Status: implementation contract v1.3 — **FULL GREEN / READY TO IMPLEMENT**  
Branch: `feat/flutter-elv2-profile-constraints`  
Parent: [ELV2 technical specification](elv2-profile-constraints-technical-specification.md)  
Pre-placement UI: [P3 palette contract](elv2-p3-palette-contract.md)  
Decision engine: [P2 placement compatibility contract](elv2-p2-placement-compatibility-contract.md)  
Project-alignment audit: [P4 contract audit](../audit/elv2-p4-contract-project-alignment-audit.md)  
Full-readiness audit: [P4 full-readiness audit](../audit/elv2-p4-full-readiness-audit.md)

> Revision note: v1.3 closes the remaining full-readiness decisions D1–D6. It freezes the canonical physical ELV definition, the membership-role vocabulary/source, the trust boundary for reviewed candidate evidence, fingerprint v1 canonical encoding and digest, undo/redo revision/timestamp semantics, and exact-SHA CI behavior for documentation-only final heads.

## 1. Purpose

P4 turns the read-only P3 preview into one durable engineering operation. A successful command creates exactly one placed physical `ComponentInstance`, establishes exactly one engineering-system membership, persists the exact frozen canonical catalog/profile binding, instantiates the profile's ELV1 ports, and commits a durable placement-operation result in the same database transaction.

The engineering aggregate and placement-operation ledger are durable. The current editor undo/redo stack is session-only and is deliberately not upgraded to durable history in P4.

P4 covers **new canonical placement only**. Catalog revision impact, adoption and migration remain P5/P6.

```text
P3 canonical profile + reviewed candidate
        ↓
PlaceEngineeringProfileCommand
        ↓
resolve exact durable state
        ↓
rebuild commit-time candidate evidence
        ↓
P2 revalidation
        ↓
BEGIN DATABASE TRANSACTION
        ↓
component
membership
ports
frozen binding
aggregate postconditions
operation ledger COMPLETED
        ↓
COMMIT
        ↓
one session history entry
```

Any durable failure before commit leaves no partial component, membership, binding, port set or completed operation row.

---

## 2. Engineering principles

1. One logical placement creates at most one physical `ComponentInstance`.
2. Component, membership, ports, frozen binding and placement-operation result share one commit boundary.
3. P3 preview is evidence, not authorization; P2 runs again at commit time.
4. Exact catalog id/version/profile code are used; there is no latest-edition fallback.
5. The frozen binding, not `ComponentInstance.definitionId`, is the canonical engineering identity.
6. P4 reuses the existing physical `ComponentInstance` model; no ELV-only physical entity is added.
7. Persisted profile ports are authoritative ELV1 graph objects.
8. Same operation + same semantic command is restart-safe and idempotent.
9. Concurrent duplicate submissions cannot create duplicate aggregates.
10. Membership role is a canonical P4 value and is not inferred from topology participation role.
11. Reviewed engineer evidence is distinguished from independently reloadable durable facts.
12. Undo/redo acts on the aggregate and never silently destroys later connections/topology work.
13. Session history is not presented as cross-restart durable history.
14. No hidden repair of conflicting active state is allowed.
15. P4 introduces no ELV3 cable/pathway/route behavior.

---

## 3. Scope

### 3.1 In scope

- immutable atomic placement command/result/failure contracts;
- exact project/floor/room/surface-patch/system/family/catalog/profile resolution;
- canonical membership role;
- shared canonical physical ELV `ComponentDefinition`;
- commit-time P2 revalidation;
- component + membership + frozen binding + persisted ports;
- mandatory durable placement-operation ledger;
- canonical SHA-256 command fingerprint v1;
- rollback/fault injection;
- restart-safe idempotency and concurrent duplicate safety;
- one session-only aggregate undo/redo action;
- CCTV/LAN/ACS/Fire acceptance;
- exact-SHA push + PR CI.

### 3.2 Out of scope

- catalog replacement/adoption/migration;
- revision impact preview;
- connection creation as part of placement;
- whole-graph loop/degree/branch proof requiring persisted connections;
- durable editor-history redesign;
- ELV3 cables, cable runs, routes and pathways;
- ELV4 power/PoE/UPS calculations;
- manufacturer BOM selection.

---

# P4.1 — Atomic command contract

## 4. Command

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

The command contains intent and reviewed candidate evidence. It does not carry trusted copies of database rows, catalog/profile objects or system discipline.

### 4.1 Operation identity

`operationId` is a client-generated stable UUID/string for one logical placement attempt.

- non-empty and immutable;
- generated before first mutation;
- reused only for retry of the same intended placement;
- materially changed placement uses a new operation id;
- normal redo is not a retry of an old `COMPLETED` operation.

### 4.2 Membership role — frozen P4 vocabulary

For canonical profile placement in P4 the only valid persisted membership role is:

```text
DEVICE
```

Contract:

```text
P3/P4 command adapter -> membershipRole = "DEVICE"
command.membershipRole -> ComponentSystemMembership.role
```

Rules:

- UI does not expose arbitrary free-text role entry;
- P4 normalizes by trim + uppercase and requires exact `DEVICE`;
- any other role -> `INVALID_COMMAND` in P4;
- the role is included in the canonical fingerprint;
- it is not copied from `PlacementCandidateContext.topologyRole`;
- future controller/source/passive membership semantics require a separately versioned domain-contract change, not an implicit extension of P4.

This intentionally keeps membership semantics generic and discipline-agnostic while topology participation remains a separate concept.

### 4.3 P3→P4 surface identity

Current P3 stores `SurfacePatch.id` in `PlacementCandidateContext.surfaceId`.

P4 MUST prove:

```text
context.projectId == command.projectId
context.roomId == command.roomId
context.surfaceId == command.hostSurfacePatchId
resolvedPatch.id == command.hostSurfacePatchId
resolvedPatch.roomId == command.roomId
resolvedRoom.floorId == resolvedFloor.id
resolvedFloor.projectId == command.projectId
resolvedSystem.projectId == command.projectId
```

`PlacementCandidateContext.surfaceId` MUST NOT be compared with `SurfacePatch.surfaceId` in the current model.

### 4.4 Result

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

For a `COMPLETED` operation the exact result is persisted. Retry returns the same ids without new aggregate writes.

### 4.5 Typed failure model

At minimum:

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

Failures may carry P2 findings and expected/actual provenance. Presentation strings are not failure identity.

---

# P4.2 — Repository transaction boundary

## 5. Dedicated transaction owner

P4 MUST use one dedicated atomic owner:

```text
EngineeringPlacementRepository
  place(command)
  undo(operationId)
  redo(historyEntry)
```

backed by one top-level `AppDatabase.transaction` / existing `LocalUnitOfWork`.

P4 MUST NOT orchestrate independently committing public methods:

```text
ComponentInstanceRepository.saveComponent()
EngineeringSystemRepository.assign()
EngineeringReferenceRepository.bind()
EngineeringTopologyRepository.savePort()
```

Reusable validation/write seams must be transaction-scoped and must not open nested independent commit boundaries.

Conceptually:

```text
validate component / insert component
validate membership / insert membership
validate port / insert port
validate binding / insert binding
```

Standalone repository behavior outside P4 remains unchanged.

## 6. Placement transaction sequence

```text
1  validate command shape + fingerprint inputs
2  read operation row by operationId
3  COMPLETED + same fingerprint -> return stored result
4  UNDONE + normal retry -> OPERATION_UNDONE
5  same id + changed fingerprint -> IDEMPOTENCY_CONFLICT
6  resolve project -> floor -> room ownership
7  resolve exact SurfacePatch -> room ownership
8  resolve EngineeringSystem + exact family edition + discipline
9  resolve exact catalog id + catalogVersion + profileCode
10 resolve canonical physical ComponentDefinition
11 validate membershipRole == DEVICE
12 rebuild commit-time PlacementCandidateContext
13 run P2 and enforce commit policy
14 generate component/port ids once
15 insert component
16 insert membership
17 insert all ports
18 insert frozen binding with exact portIds
19 assert aggregate postconditions
20 persist operation COMPLETED + exact result
21 commit
```

No aggregate mutation occurs before conflict detection and commit-time validation are complete.

## 7. Aggregate postconditions

Before commit:

```text
1 active component == result.componentId
component.roomId == command.roomId
component.hostSurfacePatchId == command.hostSurfacePatchId
component.definitionId == system-elv-canonical-device
component.definitionVersion == 1

1 active membership(componentId, systemId)
membership.role == DEVICE
system.projectId == command.projectId

1 active binding(componentId)
binding exact catalogId/catalogVersion/profileCode == command edition

N active ports == profile.portTemplates.length
set(binding.portIds) == set(active port ids)
all ports.componentId == componentId
all template/interface provenance resolves to frozen exact edition

COMPLETED operation result references exactly this aggregate
```

Failure causes rollback, never repair.

---

# P4.3 — Component creation

## 8. Physical component and hierarchy

P4 creates the existing `ComponentInstance` and MUST explicitly validate:

- active project;
- active floor belonging to project;
- active room belonging to floor;
- active host `SurfacePatch` belonging to room;
- geometry through existing `ComponentPlacementValidator`;
- finite rotation;
- no manufacturer/display label as engineering identity.

Hierarchy ownership is explicit even if a current lower-level validator would reject some mismatches indirectly.

## 9. Canonical physical ELV definition — frozen D1 decision

P4 uses one shared system definition for all canonical ELV profiles:

```text
id                = system-elv-canonical-device
code              = ELV_CANONICAL_DEVICE
displayName       = ELV device
category          = ELV_DEVICE
source            = system
version           = 1
primaryDiscipline = lowVoltage
```

The implementation MUST make this definition available through the same system component-definition mechanism used by other code-defined definitions. It is not derived from profile code, discipline-specific labels or manufacturer SKU.

Contract separation:

```text
ComponentDefinition
  -> physical/editor representation only

ComponentReferenceBinding
  -> exact engineering identity/provenance
```

CCTV, LAN, ACS and Fire all use this same `definitionId/version` strategy. Missing definition -> `COMPONENT_DEFINITION_NOT_FOUND`.

## 10. Persisted-once IDs

Component and port ids may use the existing `IdGenerator`.

- generated once inside the successful transaction;
- persisted in aggregate rows + result before the same commit;
- `COMPLETED` retry replays stored ids;
- rolled-back attempts leave no durable ids, so later retry may generate different transient ids;
- semantic port identity is template code, never list index.

---

# P4.4 — Engineering-system membership

## 11. Membership invariants

Create exactly one active membership using the existing table.

- system belongs to project;
- exact family id/version resolves;
- family discipline equals profile discipline;
- role is exact canonical `DEVICE`;
- duplicate active `(componentId, systemId)` is forbidden;
- no implicit extra memberships;
- conflicts are rejected, not repaired.

### 11.1 P3→P4 role source — frozen D2 decision

P3 does not ask the engineer for a membership role. The canonical-profile placement adapter injects `DEVICE` when constructing `PlaceEngineeringProfileCommand`.

This is testable and deterministic:

```text
CanonicalProfileChoice + placement candidate
        ↓
P4 command adapter
        ↓
membershipRole = DEVICE
```

Acceptance fixtures MUST not invent discipline-specific membership roles.

---

# P4.5 — Frozen binding

## 12. Binding snapshot

Create exactly one active `ComponentReferenceBinding` freezing:

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

- exact catalog id AND version;
- no latest lookup;
- profile publication-valid for new placement;
- no legacy-unresolved/deprecated profile;
- profile discipline matches exact resolved system family;
- one active binding per component;
- binding portIds equal exact persisted P4 ports.

The existing public `bind()` is not a P4 orchestration primitive because it owns its own transaction. Equivalent validation/write logic is reused through transaction-scoped seams.

---

# P4.6 — Persisted port instantiation

## 13. Port set

For each `profile.portTemplates` entry create exactly one persisted `EngineeringPort` preserving:

- template code;
- kind/direction/capacity;
- connector;
- protocol/version;
- electrical metadata;
- template provenance;
- exact interface code/version/provenance from the exact catalog vocabulary.

Rules:

- no manual port adoption/overwrite by matching code;
- public `savePort()` is not called as an independently transactional P4 step;
- duplicate normalized template codes -> `PORT_CONFLICT` before insertion;
- generated ids map by normalized template code, never by template list position;
- partial port sets never survive rollback.

---

# P4.7 — P2 revalidation at commit

## 14. Durable facts vs reviewed engineer evidence — frozen D3 decision

P4 MUST distinguish two evidence classes.

### A. Durable authoritative facts — always reload

```text
project/floor/room identity and active state
SurfacePatch identity, room ownership and geometry
EngineeringSystem and exact family edition
catalog id/version/profile snapshot
pinned topology reference/profile when persisted
component definition constant
existing membership/binding/port conflicts
```

The command cannot override these facts.

### B. Reviewed engineer evidence — not independently persisted in current model

Examples may include:

```text
installation/mounting method chosen for the candidate
environment exposure/moisture/contamination/climate
ambient temperature
required/actual IP evidence
enclosure presence
available clearance
topology participation intent when it is not otherwise durable
```

For this evidence P4 MUST:

1. use the exact values that were reviewed in P3 and carried in `placementContext`;
2. validate their structure/ranges again;
3. reject stale identity (`projectId`, `roomId`, `surfaceId`) mismatch;
4. replace any field for which an authoritative persisted source exists with the current durable value;
5. rerun P2 using the reconstructed context;
6. never claim these non-persisted facts were independently measured or verified by the database.

A future persisted room/environment model may move fields from class B to class A without weakening this rule.

## 15. Commit policy

```text
COMPATIBLE -> may proceed
WARNING    -> only under an explicitly defined future product policy
FORBIDDEN  -> zero mutation
UNRESOLVED -> zero mutation
```

P4 introduces no warning override.

---

# P4.8 — Rollback and failure injection

## 16. Test-only failure seam

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

For every injected durable failure assert:

```text
new active components    = 0
new active memberships   = 0
new active bindings      = 0
new active ports         = 0
new COMPLETED operations = 0
```

History append is post-commit session state and is not a DB rollback point. Actual table state, not SQLite `total_changes()`, proves rollback.

Natural failures include hierarchy mismatch, invalid role, missing physical definition, exact catalog/version mismatch, wrong discipline, deprecated/legacy profile, P2 forbidden/unresolved, conflicts, duplicate port template code, interface-provenance failure and postcondition failure.

---

# P4.9 — Durable idempotent retry and concurrency

## 17. Mandatory operation ledger

P4 adds `EngineeringPlacementOperations` in the next Drift schema migration.

Minimum logical schema:

```text
operationId PRIMARY KEY
projectId NOT NULL
fingerprintVersion NOT NULL
commandFingerprint NOT NULL
status NOT NULL              // COMPLETED | UNDONE
componentId NOT NULL
resultJson NOT NULL
createdAt NOT NULL
updatedAt NOT NULL
originDeviceId NOT NULL
```

`IN_PROGRESS` is transaction-local, not durable. There is no durable `FAILED` state in P4.

## 18. Lifecycle

```text
ABSENT
  ↓ successful place
COMPLETED
  ↓ successful undo
UNDONE
  ↓ explicit history-aware redo
COMPLETED
```

Normal retry:

```text
ABSENT + command                    -> execute
COMPLETED + same fingerprint        -> same stored result, zero mutation
COMPLETED + different fingerprint   -> IDEMPOTENCY_CONFLICT
UNDONE + same fingerprint           -> OPERATION_UNDONE
UNDONE + different fingerprint      -> IDEMPOTENCY_CONFLICT
```

Only explicit redo transitions `UNDONE -> COMPLETED`.

## 19. Fingerprint v1 — frozen D4 decision

```text
fingerprintVersion = 1
algorithm          = SHA-256
input              = UTF-8 bytes of canonical P4 command representation
stored value        = lowercase hexadecimal SHA-256 digest
```

Canonical representation is a fixed-order JSON-like object with these material fields:

```text
fingerprintVersion
projectId
roomId
systemId
membershipRole              // normalized DEVICE
catalogId
catalogVersion
profileCode
hostSurfacePatchId
localPosition.xMm            // integer
localPosition.yMm            // integer
rotationRadiansBits          // canonical binary64 hex
placementContext             // fixed field order, not map insertion order
displayNameOverride          // normalized or explicit null
```

Canonical scalar rules:

- strings are exact UTF-8 values after field-specific normalization only;
- enums use stable `.name` values;
- null is explicit `null`;
- integer millimetres remain decimal integers;
- all doubles must be finite;
- `-0.0` normalizes to `+0.0`;
- every double in fingerprint material is encoded by its IEEE-754 binary64 bit pattern as exactly 16 lowercase hexadecimal digits, big-endian semantic representation;
- lists keep semantic order unless the domain explicitly defines them as sets;
- set-like collections are sorted by their canonical element representation before hashing;
- nested objects use a specified fixed field order;
- arbitrary `jsonEncode(command)` or map insertion order is forbidden as the fingerprint contract.

`PlacementCandidateContext` receives an explicit `fingerprintV1Projection()`/equivalent with fixed field order. Fingerprint semantics may only change under a new `fingerprintVersion`.

## 20. Concurrency

`operationId` database PK is the final duplicate guard.

Acceptable outcomes:

```text
A commits; B reads same COMPLETED result
```

or a transient serialized-write/in-progress outcome followed by retry. Duplicate aggregate sets are never acceptable.

---

# P4.10 — Single session undo/redo command

## 21. History boundary

After successful DB commit, append one in-memory entry:

```text
EngineeringPlacementHistoryEntry
- operationId
- command snapshot/fingerprint
- EngineeringPlacementResult
- aggregate snapshot required for exact restore
```

If the process exits after DB commit but before append, durable engineering state remains correct and only the session undo opportunity is lost.

## 22. Undo safety

Before undo, block `HISTORY_CONFLICT` if created ports/component participate in:

- engineering connections;
- internal mappings;
- topology groups;
- any later ownership/reference that makes retirement unsafe.

If safe, one transaction retires:

```text
ports
binding
membership
component
operation COMPLETED -> UNDONE
```

Existing deletion/topology guard intent must be preserved; P4 does not bypass it with blind deletes.

## 23. Undo/redo audit metadata — frozen D5 decision

All reactivation/retirement follows the repository audit-column convention.

### Undo

For component, membership, binding and every P4 port being retired:

```text
primary id       = unchanged
createdAt        = unchanged
revision         = previous revision + 1
updatedAt        = now UTC
deletedAt        = now UTC
originDeviceId   = current device performing undo
```

Placement-operation row:

```text
status           = UNDONE
createdAt        = unchanged
updatedAt        = now UTC
originDeviceId   = current device performing undo
resultJson       = unchanged original EngineeringPlacementResult
```

### Redo

For the exact same component/membership/binding/port identities:

```text
primary id       = unchanged
createdAt        = original createdAt
revision         = previous revision + 1
updatedAt        = now UTC
deletedAt        = null
originDeviceId   = current device performing redo
```

Placement-operation row:

```text
status           = COMPLETED
createdAt        = unchanged
updatedAt        = now UTC
originDeviceId   = current device performing redo
resultJson       = unchanged
```

`EngineeringPlacementResult.committedAt` denotes the original successful placement commit and does not change during undo/redo. Transition time is represented by row `updatedAt` values.

Redo MUST re-resolve current project/room/patch/system/catalog/profile and rerun P2. Exact ids are restored only if uniqueness and current state allow it; otherwise `HISTORY_CONFLICT`. Redo never silently mints replacement ids.

Existing electrical `ComponentPlacementHistory` behavior must remain green.

---

# P4.11 — Four-discipline acceptance

## 24. Generic path

One discipline-agnostic P4 orchestration path handles all fixtures. There is no `switch/case` on CCTV/LAN/ACS/Fire in atomic placement logic.

Every acceptance command uses:

```text
membershipRole = DEVICE
physical definition = system-elv-canonical-device / v1
```

Fixtures:

```text
CCTV  CAMERA    wall+bracket or ceiling+surface   ETH
LAN   OUTLET    wall+flush or wall+surface         ETH
ACS   READER    wall+surface                       BUS
Fire  DETECTOR  ceiling+surface                    IN, OUT
```

Each asserts exact component definition, membership role, frozen profile binding, constraints snapshot, port set and template/interface provenance.

---

# P4.12 — Restart acceptance

## 25. Restart flow

For all four disciplines, table-driven where practical:

```text
seed project/room/patch/system/catalog
        ↓
P4 place
        ↓
assert aggregate + COMPLETED ledger
        ↓
close database
        ↓
reopen database
        ↓
assert exact aggregate/provenance/result
        ↓
retry same operationId + command
        ↓
assert same result + zero duplicates
```

Restart assertions include exact component id/geometry/definition, membership `DEVICE`, catalog/profile snapshot, port ids/provenance, fingerprint version/hash and result. Undo stack is explicitly not expected to survive restart.

---

# P4.13 — Exact-SHA CI gate

## 26. Required gate

P4 is complete only when push and pull-request workflows pass on the **same final branch head SHA**.

```text
Drift generation                  PASS
Mobile formatting                 PASS
Mobile analyze                    PASS
Mobile tests                      PASS
Engineering core dependencies     PASS
Engineering core formatting       PASS
Engineering core analyze          PASS
Engineering core tests            PASS
```

### 26.1 PR path-filter policy — frozen D6 decision

Before the final P4 exact-SHA gate, `.github/workflows/flutter-local.yml` MUST make documentation changes relevant to this vertical trigger the PR workflow too.

The PR `paths` list must include at minimum:

```yaml
- 'apps/mobile/**'
- 'packages/engineering_core/**'
- 'docs/product/**'
- 'docs/audit/**'
- '.github/workflows/flutter-local.yml'
```

This prevents a final docs-only evidence/contract commit from producing a new head with push CI but no PR-triggered CI.

Alternative policy of making the PR workflow unconditional is acceptable, but the final implementation must use one deterministic policy and prove both runs on the exact final SHA.

After the final exact-SHA gate there MUST NOT be another branch commit before recording P4 as complete. PR metadata/comments may record evidence without changing the branch SHA.

PR #7 remains draft for P5–P7.

---

# 27. Database and migration requirements

Reuse:

```text
ComponentInstances
ComponentEngineeringMemberships
ComponentReferenceBindings
EngineeringPortInstances
```

Add mandatory `EngineeringPlacementOperations` in the next schema version after current schema 16.

Database/transactional guarantees:

- `operationId` PK uniqueness;
- one active binding per component;
- one active `(componentId, systemId)` membership;
- unique active port id/code per component under current ELV1 contract;
- exact hierarchy ownership;
- catalog row project ownership + exact `catalogVersion` equality.

Soft-delete conflicts that cannot be expressed by a simple SQLite unique constraint are enforced inside the single transaction and covered by conflict/concurrency tests.

---

# 28. Test specification

## 28.1 Contract/application

- required command validation;
- only `membershipRole=DEVICE` accepted for P4;
- P3 context surface id equals `hostSurfacePatchId`;
- canonical physical definition exact id/code/version;
- fingerprint v1 fixed vectors and SHA-256 expected digests;
- map insertion order does not alter fingerprint;
- every material field change alters fingerprint;
- `-0.0` and `+0.0` normalize identically;
- non-finite doubles rejected;
- exact system/family/profile discipline and catalog id+version;
- durable-vs-reviewed evidence reconstruction;
- P2 COMPATIBLE/FORBIDDEN/UNRESOLVED policy.

## 28.2 SQLite/repository

- one-transaction happy path;
- exact hierarchy ownership;
- operation completion committed with aggregate;
- completed retry returns same result;
- changed fingerprint conflicts;
- UNDONE retry returns `OPERATION_UNDONE`;
- concurrent same-operation calls converge;
- fault after component/membership/each port/binding/before completion/before commit rolls back totally;
- manual port/binding/membership conflicts;
- interface provenance failure;
- aggregate postconditions;
- schema migration from 16;
- restart idempotency.

## 28.3 History

- one success -> one session history entry;
- failure/rejection -> no history entry;
- undo exact revision/timestamp/deletedAt/originDeviceId semantics;
- downstream reference blocks undo;
- redo exact-id reactivation + revision/timestamp semantics;
- original `committedAt` remains stable;
- redo conflict is explainable;
- existing electrical history remains green;
- restart does not claim history durability.

## 28.4 Four disciplines

CCTV CAMERA, LAN OUTLET, ACS READER and Fire DETECTOR all use the same service, `DEVICE` membership role and `system-elv-canonical-device/v1` physical definition.

---

# 29. Acceptance criteria

- **AC-P4-01** one immutable command represents one canonical engineering placement.
- **AC-P4-02** membership role is exactly canonical `DEVICE`, not free text or topology role.
- **AC-P4-03** every canonical ELV component uses `system-elv-canonical-device`, `ELV_CANONICAL_DEVICE`, version `1`.
- **AC-P4-04** P3 candidate identity is checked against `SurfacePatch.id` / `hostSurfacePatchId`.
- **AC-P4-05** component, membership, ports, binding and operation result share one commit boundary.
- **AC-P4-06** project/floor/room/patch/system/family/catalog/profile resolution is exact.
- **AC-P4-07** durable facts are reloaded; non-persisted reviewed evidence is explicitly classified and revalidated.
- **AC-P4-08** P2 reruns at commit and stale preview cannot bypass constraints.
- **AC-P4-09** rejected/invalid placement leaves zero new aggregate rows.
- **AC-P4-10** exactly one valid component exists after success.
- **AC-P4-11** exactly one membership with role `DEVICE` exists.
- **AC-P4-12** exactly one frozen binding stores exact profile/constraints provenance.
- **AC-P4-13** exact profile-template port set and interface provenance exist.
- **AC-P4-14** binding portIds, persisted ports and operation result reference the same aggregate.
- **AC-P4-15** every injected/natural durable failure proves total rollback.
- **AC-P4-16** restart-safe `EngineeringPlacementOperations` migration exists.
- **AC-P4-17** fingerprint v1 is SHA-256 over the specified canonical UTF-8 projection.
- **AC-P4-18** completed same-command retry returns same result with zero mutation.
- **AC-P4-19** same operation id + changed semantics is rejected.
- **AC-P4-20** successful undo transitions `COMPLETED -> UNDONE` atomically.
- **AC-P4-21** normal retry of UNDONE returns `OPERATION_UNDONE`.
- **AC-P4-22** explicit redo alone restores `UNDONE -> COMPLETED` with exact ids or conflict.
- **AC-P4-23** undo/redo obey the frozen revision/timestamp/audit-column semantics.
- **AC-P4-24** concurrent same-operation submissions converge to one aggregate.
- **AC-P4-25** session history is not represented as restart-durable.
- **AC-P4-26** later connections/internal mappings/topology groups block destructive undo.
- **AC-P4-27** aggregate and operation result reconstruct exactly after database reopen.
- **AC-P4-28** CCTV/LAN/ACS/Fire pass through one discipline-agnostic path.
- **AC-P4-29** no ELV3 cable/pathway/route coupling is introduced.
- **AC-P4-30** docs-aware PR workflow and push workflow are green on the exact same final P4 SHA.

---

# 30. Definition of Done

P4 is done only when:

- [ ] immutable command/result/failure contracts implemented;
- [ ] P3→P4 adapter injects `membershipRole=DEVICE`;
- [ ] canonical `system-elv-canonical-device / ELV_CANONICAL_DEVICE / v1` definition implemented;
- [ ] P3 `SurfacePatch.id` identity contract enforced;
- [ ] durable-vs-reviewed candidate evidence boundary implemented;
- [ ] fingerprint v1 projection + SHA-256 fixed-vector tests implemented;
- [ ] `EngineeringPlacementOperations` schema migration implemented;
- [ ] `COMPLETED ↔ UNDONE` lifecycle implemented;
- [ ] one top-level Drift transaction owns all durable P4 writes;
- [ ] independently transactional public repositories are not composed as P4 write steps;
- [ ] transaction-scoped component/membership/port/binding seams exist;
- [ ] exact hierarchy/system/family/catalog-version/profile validation implemented;
- [ ] P2 commit-time revalidation implemented;
- [ ] component + `DEVICE` membership + ports + frozen binding persist atomically;
- [ ] aggregate postconditions run before commit;
- [ ] deterministic fault injection proves rollback after every durable stage;
- [ ] completed retry/idempotency conflict/concurrency/restart tests green;
- [ ] one session history entry per successful placement;
- [ ] undo/redo exact audit-column semantics implemented;
- [ ] unsafe undo blocked by downstream ELV references;
- [ ] redo restores exact ids or returns `HISTORY_CONFLICT`;
- [ ] existing electrical history remains green;
- [ ] CCTV CAMERA acceptance green;
- [ ] LAN OUTLET acceptance green;
- [ ] ACS READER acceptance green;
- [ ] Fire DETECTOR acceptance green;
- [ ] all four survive restart with exact provenance;
- [ ] PR workflow paths include `docs/product/**` and `docs/audit/**` (or PR workflow is unconditional);
- [ ] no ELV3 types/dependencies introduced;
- [ ] mobile/core format, analyze and tests green;
- [ ] push and PR workflows green on the exact same final SHA;
- [ ] no branch commit occurs after the final P4 exact-SHA gate before P4 evidence is recorded in PR metadata.

---

# 31. Recommended implementation sequence

```text
P4.1  command/result/failure
      + DEVICE role
      + fingerprint v1
      + SurfacePatch identity
  ↓
P4.2  schema 17 EngineeringPlacementOperations
      + atomic transaction owner
      + transaction-scoped persistence seams
  ↓
P4.3  system-elv-canonical-device/v1
      + ComponentInstance
      + persisted-once ids
  ↓
P4.4  EngineeringSystem membership role DEVICE
  ↓
P4.5  frozen ComponentReferenceBinding
  ↓
P4.6  persisted ports + exact provenance
  ↓
P4.7  durable-state reconstruction
      + reviewed-evidence reconstruction
      + P2 revalidation
  ↓
P4.8  fault injection + rollback/postconditions
  ↓
P4.9  COMPLETED/UNDONE + retry/concurrency/restart
  ↓
P4.10 session history + guarded undo/redo audit semantics
  ↓
P4.11 CCTV/LAN/ACS/Fire acceptance
  ↓
P4.12 database restart acceptance
  ↓
P4.13 docs-aware exact-head push + PR CI
```

P5 starts only after every P4 acceptance criterion is green.