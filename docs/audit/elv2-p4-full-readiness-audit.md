# ELV2-P4 full readiness audit — P4.1 through P4.13

Status: **AMBER — architecture approved, six pre-implementation decisions remain**  
Branch: `feat/flutter-elv2-profile-constraints`  
Audited contract: `docs/product/elv2-p4-atomic-placement-contract.md` v1.2  
Audit scope: project alignment, persistence feasibility, editor integration, idempotency, rollback, undo/redo, acceptance and exact-SHA CI.

## Executive verdict

P4 v1.2 is materially aligned with the current Electra architecture. The earlier project-alignment blockers are resolved in the normative contract: membership role is explicit, P3 surface identity is corrected, durable operation state includes `UNDONE`, history is explicitly session-only, and atomic placement is separated from the existing independently transactional repositories.

However, the contract still leaves six implementation-significant decisions open. None requires a redesign of P4, but they should be closed before P4.1/P4.2 code is treated as final. The correct status is therefore **AMBER / READY AFTER TARGETED CONTRACT CLARIFICATIONS**, not RED.

### Status matrix

| P4 item | Status | Audit verdict |
|---|---|---|
| P4.1 Atomic command contract | GREEN | Shape, identity and typed failures are implementable. |
| P4.2 Repository transaction boundary | GREEN | Dedicated atomic owner is compatible with existing Drift/LocalUnitOfWork architecture. |
| P4.3 Component creation | AMBER | Shared canonical ELV `ComponentDefinition` strategy exists conceptually but exact `definitionId/version` is not frozen. |
| P4.4 Membership | AMBER | Persistence role is explicit, but real P3→P4 source/vocabulary for `membershipRole` is not defined. |
| P4.5 Frozen binding | GREEN | Existing binding snapshot model supports exact frozen provenance. |
| P4.6 Persisted ports | GREEN | Existing instantiate/topology semantics can be extracted into transaction-scoped seams. |
| P4.7 P2 revalidation | AMBER | Durable-state revalidation is clear; trust boundary for user-supplied environment evidence needs one explicit rule. |
| P4.8 Rollback/failure injection | GREEN | Failure seam and zero-partial-state proof are sufficient. |
| P4.9 Idempotent retry/concurrency | AMBER | Ledger/lifecycle are sound; fingerprint hash/encoding algorithm remains underspecified. |
| P4.10 Single undo/redo | AMBER | Aggregate lifecycle is sound; exact reactivation revision/timestamp semantics need to be frozen. |
| P4.11 Four-discipline acceptance | AMBER | Generic path is correct, but acceptance roles depend on unresolved membership-role vocabulary. |
| P4.12 Restart | GREEN | Durable aggregate + operation ledger model is restart-safe. |
| P4.13 Exact-SHA CI | AMBER | PR workflow path filter can miss a docs-only final head, violating exact-head evidence. |

---

# Detailed audit

## P4.1 — Atomic command contract — GREEN

### Confirmed

The command now includes all durable user intent needed by the aggregate:

```text
operationId
projectId
roomId
systemId
membershipRole
catalogId
catalogVersion
profileCode
hostSurfacePatchId
localPosition
rotationRadians
placementContext
displayNameOverride?
```

The corrected P3→P4 identity rule is explicit:

```text
PlacementCandidateContext.surfaceId == hostSurfacePatchId == SurfacePatch.id
```

The result contains aggregate ids and exact catalog/profile identity, and the typed failure set includes operation/history states.

### Audit decision

No contract change required for command shape itself.

---

## P4.2 — Repository transaction boundary — GREEN

### Current project facts

Electra already has `LocalUnitOfWork`, implemented by `DriftUnitOfWork` as one `database.transaction(action)`.

Existing public repositories independently own transactions:

```text
ComponentInstanceRepository.saveComponent
EngineeringSystemRepository.assign
EngineeringReferenceRepository.bind
EngineeringTopologyRepository.savePort
```

Therefore the v1.2 prohibition on composing those public methods is correct.

### Required implementation form

Use one dedicated owner, e.g.:

```text
EngineeringPlacementRepository
  place(command)
  undo(operationId)
  redo(historyEntry)
```

with transaction-scoped internal validation/write helpers.

### Audit decision

GREEN. No additional architecture abstraction is needed.

---

## P4.3 — Component creation — AMBER

### Confirmed

`ComponentInstances` requires non-null:

```text
definitionId
definitionVersion
roomId
hostSurfacePatchId
```

and current component placement uses a concrete `ComponentDefinition`.

The contract correctly separates:

```text
ComponentDefinition       -> physical/editor representation
ComponentReferenceBinding -> engineering truth/provenance
```

### Remaining gap A-P4.3-01

The contract says the canonical definition may be, for example:

```text
ELV_CANONICAL_DEVICE / version 1
```

but does not freeze the actual project identifier/code/version.

That is too late to decide inside repository code because `definitionId/version` becomes persisted data.

### Required remediation

Before implementation freeze one exact code-defined definition, for example:

```text
id: system-elv-canonical-device
code: ELV_CANONICAL_DEVICE
version: 1
source: system
```

The exact chosen values may differ, but they must be normative before the first P4 database is written.

### Additional project-alignment requirement

The atomic repository must explicitly prove:

```text
patch.roomId == command.roomId
room.floorId -> floor.projectId == command.projectId
```

rather than relying only on indirect geometry validation.

---

## P4.4 — Engineering-system membership — AMBER

### Confirmed

Current membership persistence requires a non-null `role`, and v1.2 correctly makes it an explicit command field instead of conflating it with topology participation.

### Remaining gap A-P4.4-01

The persistence contract is defined, but the real editor source is not.

P3 currently selects:

```text
EngineeringSystem + catalog + profile + PlacementCandidateContext
```

It does not expose a system-membership role selector and no canonical role vocabulary is defined in the P4 contract.

Without an explicit source, the UI/application layer would have to invent strings such as `DEVICE`, `ENDPOINT`, `PRIMARY`, etc.

### Required remediation

Choose exactly one P4 rule before UI wiring:

1. a fixed generic canonical role for new ELV profile placement, or
2. a typed role vocabulary owned by `EngineeringSystemFamily`, or
3. an explicit role selector populated from a typed source.

Do not accept arbitrary free-text role from the editor as engineering truth.

P4.11 acceptance fixture roles must use the same normative rule.

---

## P4.5 — Frozen binding — GREEN

### Confirmed

The current `ComponentReferenceBinding` already stores a full profile snapshot and port ids in canonical JSON. Existing reference binding persistence therefore matches the future P5/P6 provenance requirement.

The v1.2 contract correctly requires exact:

```text
catalogId
catalogVersion
profileCode
profile snapshot
constraints snapshot
portIds
```

and explicitly forbids using public `bind()` as the P4 orchestration primitive.

### Audit decision

GREEN.

---

## P4.6 — Persisted port instantiation — GREEN

### Confirmed

Current binding logic already instantiates profile ports using the exact catalog vocabulary, and topology persistence already enforces port code/graph invariants.

The contract correctly requires reusable transaction-scoped seams rather than nested `savePort()` transactions.

Port semantic identity is based on normalized template code, not template list index, while runtime ids are generated once and stored in the completed operation result.

### Audit decision

GREEN.

---

## P4.7 — P2 revalidation at commit — AMBER

### Confirmed

Exact persisted identity can be reloaded at commit:

```text
project / floor / room / SurfacePatch
system / family edition
catalog id / version / profile
topology profile reference
```

P2 can therefore be rerun without trusting the old P3 boolean.

### Remaining gap A-P4.7-01 — evidence trust boundary

Some `PlacementCandidateContext` fields are engineer/user evidence rather than durable room-state records, for example environmental exposure/moisture/contamination/climate or enclosure/clearance facts where Electra has no persisted authoritative source yet.

The phrase “still applicable” must not imply that P4 can independently prove facts that the current project model does not persist.

### Required remediation

Add an explicit rule:

```text
P4 re-resolves every fact that has a durable authoritative source.
For non-persisted candidate evidence, P4 validates command consistency/shape and reruns P2 against that exact reviewed evidence; it does not claim independent physical-world verification.
```

If a future room/environment model becomes authoritative, P4/P5 may replace supplied evidence with durable facts.

---

## P4.8 — Rollback and failure injection — GREEN

The fault points cover every durable stage:

```text
afterOperationCheck
afterComponent
afterMembership
beforePort/afterPort
afterBinding
beforeOperationComplete
beforeCommit
```

The required proof correctly checks actual rows rather than SQLite `total_changes()`.

History append is correctly excluded from DB rollback because current history is session-only.

### Audit decision

GREEN.

---

## P4.9 — Durable idempotent retry and concurrency — AMBER

### Confirmed

Mandatory persisted ledger and lifecycle are now coherent:

```text
ABSENT -> COMPLETED -> UNDONE -> COMPLETED
```

Normal retry of `UNDONE` is explicitly rejected. SQLite PK uniqueness on `operationId` is an appropriate final duplicate guard.

Schema version is currently 16, so P4 is expected to introduce the next Drift migration/version for `EngineeringPlacementOperations`.

### Remaining gap A-P4.9-01 — canonical fingerprint algorithm

The contract defines the projection and normalization properties but does not freeze:

- digest algorithm;
- exact canonical byte/string encoding;
- exact rotation encoding rule.

Because the fingerprint survives restart and may outlive application versions, this must be deterministic across versions/platforms.

### Required remediation

Freeze a concrete version-1 algorithm, e.g. conceptually:

```text
fingerprintVersion = 1
canonical UTF-8 projection
SHA-256 digest
rotation represented by one documented canonical finite encoding
```

The exact algorithm may differ, but “for example” is insufficient for persisted idempotency identity.

---

## P4.10 — Single session undo/redo — AMBER

### Confirmed

The contract is correctly aligned with current `ComponentPlacementHistory`: undo/redo is session-only and restart does not promise undo-stack persistence.

The aggregate undo order and downstream guards are correct:

```text
ports -> binding -> membership -> component -> operation UNDONE
```

Redo correctly restores exact ids or fails rather than silently minting replacement identities.

### Remaining gap A-P4.10-01 — reactivation metadata semantics

Current rows use soft-delete plus revision/createdAt/updatedAt/originDeviceId. The contract does not state what exact redo does to those audit fields.

### Required remediation

Freeze one policy, preferably:

```text
same primary ids
same original createdAt
revision incremented on undo and redo
updatedAt changed each transition
deletedAt set on undo, cleared on redo
originDeviceId set to current mutation origin
binding/ports/member/component all follow their existing revision semantics
EngineeringPlacementResult ids/provenance remain unchanged
```

Also specify whether `committedAt` in stored result remains the original placement commit time; recommendation: preserve it and let operation-row `updatedAt` represent undo/redo transitions.

---

## P4.11 — CCTV/LAN/ACS/Fire acceptance — AMBER

### Confirmed

The generic orchestration requirement is correct and must remain free of discipline switches.

Required fixtures are appropriate:

```text
CCTV CAMERA -> ETH
LAN OUTLET -> ETH
ACS READER -> BUS
Fire DETECTOR -> IN, OUT
```

### Remaining dependency

Acceptance says each fixture supplies “an explicit valid membershipRole”, but those role values are not yet normative.

### Required remediation

Resolve A-P4.4-01 first, then freeze the table-driven fixture role values from the same source/vocabulary.

No separate discipline-specific P4 logic is required.

---

## P4.12 — Restart acceptance — GREEN

The durable state required for restart is fully defined:

```text
component
membership + role
binding snapshot
ports + provenance
operation fingerprint/result/status
```

The existing session-only history is correctly excluded.

### Audit decision

GREEN, subject only to implementing the mandatory operation migration from P4.9.

---

## P4.13 — Exact-SHA CI — AMBER

### Current workflow fact

`Flutter Local Foundation` triggers:

- on push to `main` and `feat/flutter-*`;
- on pull request only when changes touch:
  - `apps/mobile/**`
  - `packages/engineering_core/**`
  - `.github/workflows/flutter-local.yml`.

### Remaining gap A-P4.13-01

A docs-only final commit after the last P4 code commit would trigger the push workflow but **not** the PR workflow. The new branch head would therefore lack PR-triggered evidence at the exact SHA required by the contract.

### Required remediation

Choose one explicit policy:

**Preferred:** extend the PR workflow path filter to include the P4 product/audit docs that may be committed after implementation, or remove the restrictive path filter for this branch workflow.

**Alternative:** guarantee that no repository commit occurs after the final exact-head code/test commit; update only PR body for evidence because PR metadata does not change the Git SHA.

The gate must not be marked complete from runs attached to a previous SHA.

---

# Cross-cutting database audit

Current schema already provides useful hard constraints:

```text
ComponentEngineeringMemberships PK = (systemId, componentId)
ComponentReferenceBindings PK = componentId
EngineeringPortInstances PK = id
EngineeringPortInstances UNIQUE = (componentId, code)
EngineeringReferenceCatalogs UNIQUE = (projectId, code, catalogVersion)
```

These align well with P4. Existing tables use soft-delete audit columns, so redo should reactivate existing exact-key rows instead of expecting a new duplicate row with the same PK/unique key.

P4 migration should add `EngineeringPlacementOperations` and increment schema version from current 16.

---

# Required pre-implementation decisions

Close these six items before calling the contract fully GREEN:

```text
D1  Freeze exact canonical ELV ComponentDefinition id/code/version.
D2  Freeze membershipRole source/vocabulary and P3→P4 derivation/selection.
D3  State the trust boundary for non-persisted PlacementCandidateContext evidence.
D4  Freeze fingerprint v1 canonical encoding + digest + rotation representation.
D5  Freeze undo/redo revision/timestamp/reactivation semantics.
D6  Fix/define exact-SHA CI behavior for a possible docs-only final head.
```

Recommended order:

```text
D1 + D2
  ↓
D3 + D4
  ↓
D5
  ↓
D6
  ↓
contract v1.3 / FULL GREEN
  ↓
P4.1 implementation
```

# Final resolution

The full P4 architecture is approved. There is no reason to split P4, create a new specification, change the physical domain model, or move work to ELV3.

Current readiness:

```text
architecture correctness       GREEN
project model compatibility    GREEN
transaction model              GREEN
persistence model              GREEN
implementation determinism     AMBER (D1-D5)
exact-SHA gate determinism      AMBER (D6)
```

**Final status: AMBER — proceed only after the six targeted decisions above are written into the existing P4 contract.**
