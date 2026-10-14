# ELV2-P4 contract ↔ project alignment audit

Branch: `feat/flutter-elv2-profile-constraints`

Audited contract: `docs/product/elv2-p4-atomic-placement-contract.md` (v1.1)

## Resolution

**RED for implementation start until the BLOCKER findings below are incorporated into the P4 contract.**

The overall P4 architecture is correct: one physical `ComponentInstance`, one engineering-system membership, one frozen reference binding, persisted ELV1 ports, commit-time P2 revalidation, one aggregate transaction, rollback, idempotency and aggregate-level undo/redo. The gaps are not a reason to redesign P4; they are contract seams where the current project already has concrete semantics that P4 must reuse.

## Evidence from the current project

- `ComponentInstance` persistence requires `definitionId` and `definitionVersion` in addition to room/surface/geometry.
- Current generic component placement receives an exact `ComponentDefinition` and copies `definition.id/version` into the instance.
- Engineering-system membership persists `(systemId, componentId, role)` and validates a non-empty membership object before insert/update.
- P3 builds `PlacementCandidateContext.surfaceId` from `SurfacePatch.id`.
- Existing reference binding already enforces membership before binding, rejects active manual ports, instantiates profile ports, and freezes a full `ComponentReferenceBinding` payload.
- Existing `savePort` revalidates graph invariants and port-code uniqueness and owns its own transaction.
- Existing editor placement history is explicitly **session-only**, stores placed `ComponentInstance` values in memory, and calls `removeComponent/saveComponent` for undo/redo.
- Existing ELV deletion guards intentionally prevent removing a component while active bindings/ports exist and prevent changing system participation while bindings/topology dependencies exist.
- `DriftUnitOfWork` already exposes a project-level `LocalUnitOfWork` backed by one `AppDatabase.transaction`.

## BLOCKER findings

### A1 — P4 does not define the source of membership `role`

Current membership persistence requires:

```text
ComponentSystemMembership
- systemId
- componentId
- role
```

The P4 command/result contract currently has no membership role and no canonical derivation rule.

Do **not** silently reuse `PlacementCandidateContext.topologyRole`: topology participation and system membership role are different concepts unless the domain explicitly declares them equivalent.

Required remediation before code:

- add `membershipRole` to `PlaceEngineeringProfileCommand`, **or**
- define a typed canonical role derivation from `ComponentEngineeringProfile` / `EngineeringSystemFamily`;
- normalize and fingerprint the role;
- include it in idempotency conflict detection and restart assertions.

### A2 — P4.3 cannot construct a valid `ComponentInstance` from the current command

Current `ComponentInstance` requires:

```text
id
definitionId
definitionVersion
roomId
hostSurfacePatchId
position
rotation
```

P3 selects an engineering profile, not a `ComponentDefinition`. The existing component placement service receives a concrete `ComponentDefinition` and uses its exact id/version.

The P4 contract currently says a synthetic/canonical definition may be used but leaves the strategy unresolved. That is not implementable deterministically.

Required remediation before code: choose exactly one strategy.

Preferred project-aligned options:

1. **Canonical ELV placement definition**: introduce/reference a real generic component definition edition used for engineering-profile-backed devices; store its exact `definitionId/version` in the command/result; profile identity remains engineering truth in the frozen binding.
2. If the existing component catalog is extended with engineering classes, require the chosen canonical definition id/version explicitly in P4.

Do not derive `definitionId` from display text and do not make manufacturer SKU the definition source.

P4 acceptance must prove that the persisted component can still be rendered/reloaded by the existing editor after restart.

### A3 — P3→P4 `surfaceId` invariant is currently wrong

P3 creates the candidate context using:

```text
surfaceId = SurfacePatch.id
```

The P4 v1.1 contract currently describes a check against the patch's domain `surfaceId` value. Those are different identities.

Required project-aligned invariant for P4 as currently implemented:

```text
context.surfaceId == command.hostSurfacePatchId
```

and the resolved patch must then independently satisfy:

```text
patch.id == command.hostSurfacePatchId
patch.roomId == command.roomId
room -> floor -> project == command.projectId
```

A later rename to `surfacePatchId` would improve clarity but is not required for P4.

### A4 — idempotency state machine is incomplete once undo exists

The v1.1 state model ends at `COMPLETED`. P4.10 then allows undo of the aggregate while the durable operation result still says completed.

That creates an invalid retry case:

```text
operation = COMPLETED
aggregate = inactive after undo
retry same operationId
```

Returning the old result is stale; silently resurrecting is also wrong.

Required state semantics:

```text
ABSENT
  ↓ normal place
IN_PROGRESS (transaction-local claim)
  ↓ commit
COMPLETED
  ↓ history undo
UNDONE
  ↓ history redo only
COMPLETED
```

Normal retry rules:

```text
COMPLETED + same fingerprint -> return same active result
COMPLETED + different fingerprint -> IDEMPOTENCY_CONFLICT
UNDONE + normal retry -> OPERATION_UNDONE (no resurrection)
UNDONE + history redo -> restore exact aggregate, then COMPLETED
```

If `IN_PROGRESS` is never durably visible because the claim lives in the same SQLite transaction, document it as a transaction-local state rather than pretending it survives crashes.

## HIGH findings

### H1 — P4 must not compose the current public write repositories

The current component, engineering-system, reference and topology repositories each open their own transactions and often call `load()` methods that themselves open transactions.

The existing `bind()` path also creates ports internally, while `savePort()` performs graph checks and owns its own transaction.

Therefore P4 should not implement atomic placement by calling:

```text
components.saveComponent()
systems.assign()
references.bind()
topology.savePort()
```

in sequence.

Required architecture:

- one dedicated `EngineeringPlacementRepository` / transaction coordinator;
- one outer `LocalUnitOfWork` / `AppDatabase.transaction`;
- transaction-scoped internal read/write helpers that reuse existing validation logic without opening independent commit boundaries;
- extract reusable validation functions where required instead of bypassing current invariants.

### H2 — existing `bind()` cannot be reused as the P4 binding primitive

Current `bind()`:

- requires the component and membership to already exist;
- rejects active manually authored ports;
- instantiates/persists profile ports itself;
- uses repository `idGenerator` sequencing;
- finally writes the binding snapshot.

P4 needs to own the complete aggregate and idempotency result in one transaction, so the reusable parts should be factored into an internal builder/validator rather than calling `bind()` as an independently meaningful command.

### H3 — existing `savePort()` cannot be the per-port P4 persistence loop without refactoring

`savePort()` reloads project topology, checks binding freeze semantics, graph dependencies and code uniqueness, then commits its own transaction.

P4 should preserve those invariants but avoid N nested repository workflows. Recommended split:

```text
validatePortForInsert(snapshot, candidate)
insertPortInCurrentTransaction(candidate)
```

or equivalent internal transaction-scoped primitives.

### H4 — durable idempotency storage is mandatory, not optional guidance

P4 requires retry after restart and concurrency-safe same-operation behavior. The project currently has no placement-operation ledger in the audited persistence paths.

Therefore the contract should require an additive Drift migration for an operation table unless an existing table is proven equivalent.

Minimum project-aligned columns:

```text
operation_id PK
project_id
fingerprint_version
command_fingerprint
status (COMPLETED | UNDONE)
component_id
result_json
created_at
updated_at
origin_device_id
```

`IN_PROGRESS` may stay transaction-local. The row for `COMPLETED` must commit with the aggregate.

Clarify that this guarantees **local database idempotency**. Cross-device/distributed deduplication is outside P4 unless the sync architecture explicitly adds it later.

### H5 — deterministic ids are over-specified where atomic result persistence is sufficient

P4 currently leans toward deriving component/port ids from `operationId`. The existing project already has an `IdGenerator`, and atomic persistence of the generated ids in the operation result is enough for retry-after-commit.

Recommended rule:

- generate ids once inside the successful transaction using the existing id strategy;
- persist those ids in the binding and operation result;
- retry returns them from the operation row;
- redo restores the same stored ids;
- deterministic derivation from `operationId` is optional, not required.

For ports, semantic mapping remains by stable template `code`, not list index.

### H6 — P4.10 must align with the project's session-only history model

Current placement history is explicitly session-only and memory-backed. It records only `ComponentInstance` and calls component repository save/remove on undo/redo.

P4 should **not** introduce a durable history subsystem as a side effect of atomic ELV placement.

Project-aligned P4 rule:

- durable atomicity covers database aggregate + operation ledger;
- after successful commit, push one in-memory `EngineeringPlacementHistoryEntry`;
- that history entry stores enough aggregate snapshot/command/result information to invoke dedicated aggregate `undoPlacement` / `redoPlacement` methods;
- app restart legitimately clears undo/redo history, consistent with existing behavior;
- restart acceptance tests durable placement/idempotency, not restoration of editor undo stacks.

### H7 — P4 undo cannot reuse `ComponentInstanceRepository.removeComponent()` directly

Current deletion guard intentionally blocks component deletion when active binding or ports exist.

Therefore aggregate undo needs a dedicated transactional path:

```text
check downstream connections/internal links/groups
retire ports
retire binding
retire membership
retire component
mark operation UNDONE
```

It must reuse deletion/dependency guard semantics, not bypass them.

If later work has attached topology/connections to the placed ports, undo must fail safely and leave the history entry actionable/blocked; it must not cascade-delete later work.

## MEDIUM findings

### M1 — hierarchy ownership check should be explicit

P4 must prove:

```text
patch.roomId == room.id
room.floorId -> floor.projectId == command.projectId
system.projectId == command.projectId
catalog.projectId == command.projectId
```

Checking only that each row exists is insufficient.

### M2 — exact catalog version must be checked even though catalog id is immutable

The command carries both `catalogId` and `catalogVersion`; P4 should assert the row payload/column version equals the command version. Do not drop the version from the command merely because ids are immutable.

### M3 — reuse the existing palette discipline resolver semantics

P3 resolves discipline from the exact `(familyId, familyVersion)` and canonical family code. P4 must apply the same mapping rule at commit rather than copy a subtly different family/discipline heuristic.

Prefer extracting a shared application/domain resolver over duplicating switch logic across palette, binding and placement paths.

### M4 — fingerprint normalization needs numeric rules

For stable idempotency fingerprints:

- reject NaN/infinity before fingerprinting;
- normalize `-0.0` to `0.0`;
- use enum names/canonical string values;
- canonicalize map key ordering;
- define whether optional null vs omitted fields are equivalent;
- preserve engineering-significant list order only where order is semantic.

### M5 — successful postconditions should include persisted payload equality

Before commit assert not only row counts but also:

- binding `profile` canonical JSON equals the exact selected profile snapshot;
- binding `portIds` set equals active persisted port ids for the component;
- each port's `componentId` and provenance match the binding/catalog;
- membership role and system id match the command;
- operation result ids match actual rows.

## Confirmed alignment / no change required

### OK1 — one physical component model

P4 correctly reuses `ComponentInstance`; no parallel ELV physical device entity is needed.

### OK2 — one top-level Drift transaction is compatible with the project

The project already exposes `LocalUnitOfWork` and `DriftUnitOfWork` backed by `AppDatabase.transaction`, so P4 can introduce a dedicated atomic coordinator without inventing a second transaction abstraction.

### OK3 — frozen binding model is already compatible

`ComponentReferenceBinding` is persisted as canonical JSON and already carries exact catalog/profile/version/profile snapshot/port ids. P4 can reuse this model directly.

### OK4 — port conflict and graph safety semantics already exist

The topology repository already checks port code uniqueness, graph findings and freeze/dependency constraints. P4 should extract/reuse those rules, not replace them.

### OK5 — deletion guards support the desired safe-undo policy

Existing ELV guards already encode the principle that bindings/ports/connections/topology must be resolved before destructive ownership changes.

### OK6 — P2 commit-time revalidation remains correct

No conflict found with P2/P3 architecture. P3 remains read-only, and P4 must rebuild/verify persistence-backed context before mutation.

## Required contract remediation order

Before P4.1 implementation:

```text
R1  define canonical membership role source
R2  define exact ComponentDefinition / definitionId+version strategy
R3  fix P3 surface-patch identity invariant
R4  extend operation state semantics with UNDONE
R5  declare operation ledger migration mandatory
R6  explicitly select session-only history for P4
R7  define dedicated aggregate undo/redo repository methods
R8  require transaction-scoped internal primitives instead of public repository composition
R9  relax deterministic-id requirement to persisted-once ids
R10 add hierarchy/fingerprint/postcondition details
```

Then P4 can proceed in the originally planned order P4.1 → P4.13.

## Final verdict

The P4 contract is **architecturally sound but not yet implementation-safe against the current Electra codebase**. The blockers are concrete integration mismatches, not conceptual weaknesses in the ELV model. Once R1–R10 are folded into `elv2-p4-atomic-placement-contract.md`, the contract can move from **SPECIFIED** to **AUDITED / READY TO IMPLEMENT**.