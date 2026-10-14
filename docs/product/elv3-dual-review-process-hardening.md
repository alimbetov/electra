# Electra — ELV3 Dual-Review Architecture and Process Hardening

Status: AUTHORITATIVE DUAL-REVIEW HARDENING / CLOSED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Triggered after: third adversarial P1-P9 audit

## 1. Purpose

This contract simulates independent implementation review by two specialists:

- **Architect A — macro consistency:** validates ELV1-ELV8 boundaries, ownership, persistence evolution, revision/history semantics, shared infrastructure and compatibility with the existing routing/recalculation kernel.
- **Architect B — process flow:** validates every engineer-visible command from input through validation, transaction, effects, invalidation, rollback, restart and undo/redo.

The acceptance criterion is stronger than document consistency:

> Two independent developers following the authority set must produce interoperable domain/persistence behavior, while two independent architects must agree on both system ownership and command-state flow without introducing architecture during implementation.

This document wins over conflicting wording in earlier ELV3 specifications.

---

## 2. D1 — new WORKING revision materialization is explicit

`CreateNextWorkingDesignRevision` is not allowed to choose between empty revision, lazy inheritance or ad-hoc cloning.

Canonical behavior:

```text
FROZEN revision Rn
  + immutable DesignRevisionPhysicalSnapshot Sn
       |
       | CreateNextWorkingDesignRevision
       v
WORKING revision Rn+1
  + materialized revision-scoped editable realization
```

### Transaction

```text
BEGIN
  require no current WORKING revision
  load base revision in FROZEN or SUPERSEDED state
  verify base DesignRevisionPhysicalSnapshot hash
  create new ProjectDesignRevision WORKING
  for each ACTIVE canonical CableRun in base snapshot:
    create new CanonicalCableRun with new id
      designRevisionId = new revision id
      basedOnCableRunId = base run id
      same Cable identity
      same run allowances
    create new CableRunTraversal rows with new ids
      preserving ordered routeSegmentId + direction + carrier/compartment refs
  persist materialization provenance
COMMIT
```

No project-global Cable identity or CableAllocation identity is cloned merely because a revision changes.

`CanonicalCableRuns` therefore includes:

```text
based_on_cable_run_id? -> CanonicalCableRuns.id
```

A new WORKING revision begins as an explicit editable materialization of the base physical design, not an empty or lazy virtual overlay.

If base snapshot cannot be verified or required referenced current reusable route infrastructure no longer matches the frozen interface identity, creation is blocked with structured reconstruction conflict; implementation must not silently invent a replacement path.

---

## 3. D2 — global physical mutations require a WORKING context after P3

Before P3 exists, P1/P2 commands operate under their own phase gates.

Once ProjectDesignRevision capability is installed for a project, every command that mutates current physical design intent MUST require exactly one WORKING revision, including:

```text
CreateCable
ChangeCableDefinitionRef
ArchiveCable
CreateCableAllocationDraft
ReserveCableResources
ActivateCableAllocation
ReleaseCableResources
ArchiveCableAllocation
Bind/Replace terminations
route geometry mutation
RouteHandoff mutation
RouteBendEvidence mutation
PathwayContext mutation
PhysicalCarrier/compartment mutation
P5 profile-set mutation
```

No physical mutation is permitted in the gap after `FreezeProjectDesignRevision` and before `CreateNextWorkingDesignRevision`.

Historical reads of FROZEN revisions remain snapshot-backed and are never affected by this guard.

Error:

```text
ELV_WORKING_REVISION_REQUIRED
```

---

## 4. D3 — shared route geometry mutation is separate from CableRun reroute

`RerouteCableRun` changes only a CableRun traversal chain. It MUST NOT edit reusable `CableRoute`, `CableRouteNode` or `CableRouteSegment` geometry as a hidden side effect.

Two explicit operation families exist:

```text
RerouteCableRun
  -> replace which existing route segments this CableRun traverses

EditReusableRouteGeometry
  -> mutate shared route infrastructure itself
```

### EditReusableRouteGeometry

Input includes:

```text
commandId
projectId
workingDesignRevisionId
routeId / affected route entities
expected route/node/segment revisions
expectedImpactFingerprint
complete geometry mutation payload
```

Before commit the application resolves every current WORKING `CanonicalCableRun` traversal referencing affected segments/nodes and builds a stable sorted impacted-run set.

```text
impactFingerprint = SHA-256(canonical impacted run ids + affected route ids/revisions)
```

If it differs from `expectedImpactFingerprint`, command fails with:

```text
ELV_ROUTE_IMPACT_CHANGED
```

Successful geometry mutation atomically:

- updates reusable geometry;
- revalidates all impacted current traversal chains;
- rejects mutation if any chain becomes structurally invalid;
- invalidates P5/P6 affected-subgraph keys for every impacted run;
- records command/audit evidence.

A route geometry change is therefore an explicit shared-infrastructure operation, never an accidental single-cable edit.

---

## 5. D4 — shared carrier/pathway mutations use the same impact discipline

`UpdatePhysicalCarrier`, `UpdateCarrierCompartment` and `UpdatePathwayContext` must resolve all current WORKING traversals that depend on the changed object.

The command must carry an `expectedImpactFingerprint` over sorted dependent traversal/run identities and relevant object revisions. Changed impact between preview and commit yields:

```text
ELV_INFRASTRUCTURE_IMPACT_CHANGED
```

Mutation is rejected if it would leave an active traversal referencing an invalid carrier/compartment/context combination.

Archive remains restrictive while current dependencies exist.

---

## 6. D5 — snapshot schema evolves by phase, never predicts future phases

P3 cannot persist P4/P5 fields that do not yet exist.

`DesignRevisionPhysicalSnapshot.schemaVersion` is phase-evolution aware:

```text
v1 (P3)  = P1-P3 physical basis
v2 (P4)  = v1 + PathwayContext/Carrier/compartment facts
v3 (P5)  = v2 + exact active PhysicalCompatibilityProfileSet refs
v4+      = explicit future schema migrations only
```

Rules:

- a snapshot embeds only capabilities actually installed at freeze time;
- old snapshots are immutable and are never silently backfilled from current rows;
- readers are versioned;
- requesting evidence introduced after an old snapshot returns typed `NOT_CAPTURED_IN_REVISION`, not current data and not guessed defaults;
- freezing after a new phase is installed uses the newest required snapshot schema.

This preserves phase isolation and historical truth simultaneously.

---

## 7. D6 — derived results are design-revision scoped

The existing project-wide derived-result infrastructure may be reused, but ELV3 node identity MUST include design-revision scope.

Canonical ELV3 derived key prefix:

```text
elv3:<designRevisionId>:<processCode>:<subjectIdentity>
```

Examples:

```text
elv3:REV-02:ELV-ROUTE-01:cable-run:CR-17
elv3:REV-02:ELV-ROUTE-02:segment-carrier:S12|C3|COMP-A
```

No P5/P6 result for one revision may overwrite/cache-hit another revision merely because projectId/subjectId match.

For FROZEN revisions, calculation inputs resolve from snapshot content. For WORKING, they resolve from current canonical rows plus exact refs.

---

## 8. D7 — CableDefinitionRef becomes immutable after resource evidence exists

`ChangeCableDefinitionRef` is permitted only while the Cable has never produced immutable `CableAllocationResourceSelections` evidence and has no CanonicalCableRun.

Once any resource-selection evidence exists, even if the allocation is later RELEASED/ARCHIVED:

```text
ChangeCableDefinitionRef -> ELV_CABLE_DEFINITION_CHANGE_BLOCKED
```

Reason: historical resource identities and selection hashes are defined by the exact CableDefinition edition and cannot be reinterpreted under another definition.

To use a different definition after physical-resource history exists, create a new Cable identity and explicitly migrate/reallocate engineering intent.

This replaces any earlier wording suggesting downstream revalidation could make an in-place definition identity change safe.

---

## 9. D8 — termination replacement is set-atomic

Single-row replacement is not the engineer-visible consistency boundary for RESERVED/ACTIVE allocation.

Canonical command:

```text
ReplaceCableTerminationSet
```

Input contains the complete desired termination mapping set for the allocation plus expected allocation revision.

Transaction:

```text
BEGIN
  load allocation + exact immutable selection evidence + definition
  require RESERVED or ACTIVE
  validate complete candidate mapping set against TerminationPolicy
  validate endpoint/project/resource uniqueness
  replace mapping set atomically
  if ACTIVE, require candidate remains activation-complete
  revision++
  invalidate dependent physical findings
COMMIT
```

`BindCableTermination` may be used only while building an incomplete RESERVED mapping interactively; it may not leave an ACTIVE allocation structurally incomplete.

---

## 10. D9 — command idempotency ledger semantics are frozen

Observable idempotency was already required; persistence identity is now fixed enough for independent implementations.

Canonical key:

```text
(projectId, commandId)
```

Persisted evidence equivalent to:

```text
CommandExecutionRecord {
  projectId
  commandId
  commandType
  normalizedPayloadSha256
  outcomeKind
  logicalResultIdentityJson
  committedAt
}
```

Payload hash:

```text
schema marker = "electra.command-payload.v1"
SHA-256(UTF-8(canonicalEngineeringJson({schema, commandType, normalizedPayload})))
```

Rules:

- same `(projectId, commandId)` + same command type/payload hash -> return prior logical outcome without reapplying effects;
- same key with different command type or payload hash -> `ELV_IDEMPOTENCY_CONFLICT`;
- execution record and domain effects commit atomically;
- failed/rolled-back attempts do not create a successful execution record;
- restart preserves replay semantics.

Exact table/class name may differ only if these persisted semantics remain identical; no in-memory-only idempotency is acceptable.

---

## 11. D10 — reversible versus irreversible command matrix

Undo/redo is not automatically available for every command.

### Reversible engineer-edit commands

Must provide deterministic inverse/snapshot semantics while the same WORKING revision remains editable:

```text
CreateCable                    -> undo archives/removes only if no dependents were created after it
CreateCableAllocationDraft     -> undo removes/archives empty DRAFT
ReserveCableResources          -> undo releases reservation only if no later dependent command exists
BindCableTermination           -> undo restores prior RESERVED mapping set
ReplaceCableTerminationSet     -> undo restores prior mapping set
CreateCableRun                 -> undo removes/supersedes newly created WORKING run if dependency-safe
RerouteCableRun                -> undo restores complete prior traversal chain
EditReusableRouteGeometry      -> undo restores complete prior shared geometry if impact/dependency revisions still match
Attach/DetachTraversalCarrier  -> undo restores prior attachment
editable P4 infrastructure changes -> inverse only while dependency guard passes
```

### Irreversible/history commands

Not exposed as ordinary UI undo:

```text
FreezeProjectDesignRevision
CreateNextWorkingDesignRevision
SupersedeProjectDesignRevision
ArchiveProjectDesignRevision
ArchiveCable with historical evidence
ArchiveCableAllocation
AdoptLegacyElectricalRoute once committed as migration evidence
```

Corrections occur through a new explicit forward command/revision, not by erasing history.

Redo is valid only for a previously undone reversible command whose precondition fingerprint still matches current state; otherwise `ELV_REDO_STALE`.

---

## 12. D11 — phase process gates include exact inputs, effects and postconditions

Each implementation PR/work package MUST include a command-contract table for every new/changed command with these columns:

```text
Command
Input identity / expected revisions
Required state
Read set
Validation set
Write set
State transition
Affected dependency keys
Idempotency behavior
Rollback postcondition
Undo class
Restart assertion
Error codes
```

A phase cannot close if a command appears in code without a corresponding contract row and tests for its state/error/rollback path.

This requirement applies to P1-P8; P9 audits the complete matrix against code.

---

## 13. D12 — process error ordering is deterministic

For a compound command, externally observable validation precedence is:

```text
1 command envelope / idempotency conflict
2 project + entity existence
3 project isolation
4 lifecycle / WORKING-revision guard
5 optimistic expectedRevision conflict
6 reference/snapshot integrity
7 structural/domain validation
8 dependency/impact validation
9 transaction write / storage failure
```

If several errors exist, the earliest applicable category is returned. Within one category validators emit stable sorted findings by `(code, entityId, field)`.

This avoids two implementations returning incompatible primary failures for the same command input.

---

## 14. D13 — phase-aware project state after P3

From P3 onward the application exposes one physical-design edit context:

```text
PhysicalDesignContext {
  projectId
  workingDesignRevisionId?
  latestFrozenRevisionId?
  editingAllowed
}
```

Rules:

- before first P3 bootstrap, migration creates the single WORKING revision idempotently;
- after freeze and before next-working creation: `editingAllowed=false`;
- P7 workspace renders frozen state read-only in that gap;
- every write command resolves/validates the same context instead of independently guessing current revision.

---

## 15. D14 — macro ownership reconciliation

The dual review confirms these ownership lines and prohibits cross-layer shortcuts:

```text
ELV1  logical ports/connections/topology
ELV2  canonical reference identities/dictionaries/immutable editions
ELV3  current + revisioned physical realization and intrinsic physical evidence
ELV4  power-conversion/PoE/PSU/UPS graph
ELV5  discipline-specific calculations
ELV6  enclosure/rack/patching physical layout
ELV7  jurisdiction/normative thresholds and compliance
ELV8  manufacturer selection/BOM/deliverables
```

Specific guardrails:

- P3 snapshot is historical evidence, not a new reference catalog.
- P5 `PhysicalCompatibilityProfile` contains intrinsic rules only; normative rules remain ELV7.
- P6 result cache is derived evidence, never source-of-truth geometry.
- ELV8 manufacturer product may reference CableDefinition but never replaces Cable/CableDefinition identity.
- existing legacy electrical CableRun remains a coexistence adapter input, not canonical ELV3 ownership.

---

## 16. Closure matrix

```text
D1 new revision materialization                 CLOSED
D2 WORKING context for physical writes          CLOSED
D3 shared route mutation boundary               CLOSED
D4 shared carrier/pathway impact boundary       CLOSED
D5 phase-evolving snapshot schema               CLOSED
D6 revision-scoped derived results              CLOSED
D7 CableDefinitionRef history immutability      CLOSED
D8 set-atomic termination replacement           CLOSED
D9 persisted idempotency ledger semantics       CLOSED
D10 undo/redo reversibility matrix              CLOSED
D11 mandatory command contract matrix           CLOSED
D12 deterministic error precedence              CLOSED
D13 physical-design edit context                CLOSED
D14 macro ownership reconciliation              CLOSED
```

No item is deferred to implementation-time architectural choice.
