# Electra — ELV3 P0.5 Lifecycle, Revision, Audit and Command Contract

Status: REMEDIATED DESIGN CONTRACT / P0-R9  
Branch: `feat/flutter-elv3-physical-routing-design`  
Authoritative parent: `docs/product/elv3-p0-system-architecture-remediation.md`  
Implementation status: HOLD UNTIL P0-R10

## 1. Purpose

This document defines lifecycle, design-revision identity, audit/provenance and application command boundaries for ELV3.

It supersedes the first P0.5 where lifecycle was described without sufficient design-revision semantics and where `CableRun`/`CableRoute` atomicity assumed the old one-run-per-room / one-route-per-run model.

## 2. Canonical mutable roots

Project-owned mutable roots relevant to ELV3:

```text
Cable
CableAllocation
CableRun
Route / route infrastructure
PhysicalCarrier
PathwayContext
```

ELV2 reference definitions are immutable/versioned reference data and are not mutable ELV3 project roots.

## 3. Design revision semantics

A Cable may have historical routing realizations, but at most one active CableRun in one design revision.

Conceptually:

```text
Cable C-001
  revision/design context R1 -> CableRun CR-001 ACTIVE
  revision/design context R2 -> CableRun CR-002 ACTIVE
  prior run -> SUPERSEDED/HISTORICAL
```

Minimum invariant:

```text
UNIQUE(cableId, designRevisionId) for active CableRun realization
```

The exact project revision mechanism may reuse existing project revision infrastructure, but ELV3 must not flatten all historical run states into one mutable row if reproducibility requires history.

## 4. Lifecycle states

Canonical project lifecycle states:

```text
ACTIVE
ARCHIVED
```

Routing realization may additionally expose:

```text
ACTIVE
SUPERSEDED
ARCHIVED
```

Allocation reservation may use implementation states such as DRAFT/RESERVED/ACTIVE/RELEASED only if their capacity-consumption semantics are explicit and deterministic.

## 5. Deletion/restriction matrix

| Entity | Rule |
|---|---|
| EngineeringConnection | delete blocked while active CableAllocation exists |
| CableAllocation | release/archive explicitly; removal must free resources atomically |
| Cable | delete/archive blocked while active allocations or active CableRun exists |
| CableRun | replace/supersede through command; historical evidence retained where required |
| CableTraversal | owned by CableRun realization; mutated only through reroute command |
| Route/RouteSegment | deletion blocked while active traversals reference it |
| PhysicalCarrier | deletion blocked while active traversals reference it |
| PathwayContext | deletion blocked while carriers/routes depend on it |
| CableDefinition/Profile edition | governed by ELV2; immutable and retained while referenced |

No cross-aggregate cascade may silently erase topology or engineering evidence.

## 6. Audit metadata

Mutable ELV3 roots SHOULD expose shared audit metadata:

```text
revision/version token
createdAt
createdBy
updatedAt
updatedBy
archivedAt?
archivedBy?
originDeviceId?   // where existing offline architecture requires it
```

Use existing project conventions where available rather than creating a parallel audit framework.

## 7. Provenance

### Cable

Persist exact ELV2 project/reference binding sufficient to reconstruct the exact `CableDefinition/Profile` edition used by the Cable.

Do not duplicate catalog governance fields when the canonical reference binding already provides them.

### PhysicalCarrier / PathwayContext

Factual dimensions/geometry may retain:

```text
sourceType
sourceReference?
sourceRevision?
capturedAt?
capturedBy?
```

### Derived results

Length, occupied area, fill basis and compatibility results are derived evidence. If persisted/cached, they require input fingerprint/revisions and are never independently editable truth.

## 8. Mandatory application commands

ELV3 must not be implemented as arbitrary UI sequences of repository writes.

Required command families:

```text
CreateCable
ArchiveCable
ChangeCableDefinitionBinding
AllocateCableResources
ReleaseCableResources
BindCableTermination
CreateCableRun
RerouteCableRun
SupersedeCableRun
AttachTraversalToRoute
AttachTraversalToCarrier
DetachTraversalFromCarrier
CreateOrUpdatePhysicalCarrier
CreateOrUpdatePathwayContext
AdoptLegacyElectricalRoute
```

Each command must define:

- transaction boundary;
- structural validation;
- expected revision / optimistic concurrency guard;
- project-isolation checks;
- affected dependency keys;
- idempotency identity where retry is possible;
- undo/redo semantics where editor UX exposes the operation.

## 9. Atomicity examples

### AllocateCableResources

```text
BEGIN
  load Cable + exact ELV2 definition binding
  resolve resource selection
  load active resource claims
  validate overlap / WHOLE_CABLE exclusivity
  validate explicit transition if multi-cable realization
  persist allocation + resource atoms + termination mappings
  increment revisions
COMMIT
```

### RerouteCableRun

```text
BEGIN
  load active CableRun + expected revision
  validate target route/traversal chain
  validate route/carrier references
  replace/supersede traversal set atomically
  invalidate affected physical calculations only
  increment revision
COMMIT
```

### AdoptLegacyElectricalRoute

```text
BEGIN
  load legacy electrical routing evidence
  require explicit adoption decision
  require sufficient physical-cable facts
  create Cable only when evidence exists
  create canonical CableRun/traversals
  persist adoption mapping/provenance
COMMIT
```

No partial canonical Cable is created from ambiguous electrical data.

## 10. Dependency invalidation

Expected direction:

```text
ELV2 CableDefinition/Profile binding
  -> Cable
  -> CableAllocation / termination
  -> CableRun / traversal
  -> Route occupancy + length
  -> ELV3 technical compatibility
  -> ELV4/ELV5 calculations using physical path facts
  -> ELV7 normative evaluation
  -> ELV8 schedules/BOM/deliverables
```

Commands invalidate only affected IDs/subgraphs. Whole-project recalculation is not the default.

## 11. Restart contract

After close/reopen, reconstruct exactly:

- Cable identity;
- exact ELV2 reference binding;
- allocation resource selection and resource atoms;
- termination mappings;
- active/historical CableRun revision identity;
- ordered CableTraversal chain;
- referenced route geometry;
- carrier/pathway references;
- audit/provenance metadata;
- explicit legacy adoption mapping when present.

Restart must not regenerate identity from display labels or latest catalog values.

## 12. Failure behavior

Failure leaves:

```text
no partial allocation
no duplicate resource claim
no orphan CableRun traversal
no half-rerouted route state
no invented Cable from ambiguous legacy circuit
no dangling carrier/pathway reference
```

Retry with the same idempotency identity must not duplicate successfully committed domain objects.

## 13. Undo/redo

Editor-facing compound operations must be represented as single logical commands where the engineer perceives one action.

Examples:

```text
create cable + allocation
reroute cable
release allocation
adopt legacy route
```

Undo must restore a valid prior aggregate state, not replay low-level row deletes independently.

## 14. P0-R9 lifecycle/command acceptance

- [x] design-revision identity is explicit.
- [x] at most one active CableRun per Cable/revision.
- [x] route infrastructure deletion is restrictive while used.
- [x] ELV2 reference governance is reused.
- [x] command boundaries are explicit.
- [x] transaction/revision/idempotency/undo requirements are explicit.
- [x] dependency invalidation direction is defined through ELV4–ELV8.
- [x] restart and failure semantics are deterministic.

This remediation point is CLOSED subject to P0-R10.