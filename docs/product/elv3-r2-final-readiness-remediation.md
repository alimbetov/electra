# Electra — ELV3 R2 Final Readiness Remediation

Status: AUTHORITATIVE R2 REMEDIATION / CLOSED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Triggered by: `docs/audit/elv3-p1-p9-second-technical-audit.md`

## 1. Purpose

This contract closes R2-01 through R2-12 found by the second P1-P9 technical audit. It is authoritative over conflicting wording in `elv3-implementation-specification-v2.md`, PRE-P1 hardening and older P0 documents.

No R2 item is left for implementation-time architecture choice.

## 2. R2-01 — frozen ProjectDesignRevision reproducibility

A FROZEN design revision is reproduced from an immutable physical snapshot, not from mutable current project rows.

Canonical persisted artifact:

```text
DesignRevisionPhysicalSnapshot {
  id
  projectId
  designRevisionId
  schemaVersion
  payloadJson
  payloadSha256
  createdAt
  originDeviceId
}
```

Constraints:

```text
UNIQUE(design_revision_id)
```

`payloadJson` is canonical JSON containing the complete ELV3 physical design basis required to reconstruct that revision:

- Cable identity + exact CableDefinitionRef + Cable revision;
- ACTIVE/RESERVED allocation identity/state and resolved atomic resource claims;
- termination mappings;
- canonical CableRun identity and run allowances;
- ordered traversal chain with route-segment ids, direction and route geometry revision/hash evidence;
- RouteHandoff references used by continuity;
- PathwayContext, PhysicalCarrier and compartment references/revisions used by traversals;
- relevant exact ELV2 physical-profile references;
- source entity revisions and snapshot schema version.

Freeze transaction:

```text
BEGIN
  load WORKING ProjectDesignRevision at expected revision
  validate complete canonical physical graph for that revision
  build deterministic snapshot payload
  canonicalize payload
  compute SHA-256
  insert immutable DesignRevisionPhysicalSnapshot
  WORKING -> FROZEN
  revision++
COMMIT
```

After FROZEN, current Cable/Allocation/Termination/Route/Carrier records may evolve for a later WORKING revision without mutating the frozen snapshot. Any report/calculation requesting a FROZEN revision MUST resolve physical source-of-truth from its snapshot, never by silently reading current mutable rows.

Snapshot rows are append-only/immutable. A hash mismatch on restart is a blocking integrity failure.

## 3. R2-02 — bend-radius evidence

Point/polyline geometry does not prove bend radius. ELV3 MUST NOT infer an actual bend radius from adjacent straight segments alone.

Canonical type:

```text
RouteBendEvidence {
  id
  projectId
  routeNodeId
  radiusMm
  evidenceKind: DESIGNED_RADIUS | FITTING_RADIUS | MEASURED_RADIUS
  sourceRef?
  revision
}
```

Rules:

- radiusMm finite and > 0;
- routeNodeId references a bend-capable route node in the same project;
- one active bend evidence record per route node;
- if CableDefinition requires minimum bend radius and a traversed bend has no accepted evidence, P5 result is `UNRESOLVED` and P6 bend process is `BLOCKED`;
- if evidence exists, intrinsic check is `radiusMm >= minimumBendRadiusMm`;
- coordinate equality/angle is never substituted for radius evidence.

P3 introduces bend evidence persistence together with traversal-capable route evolution; P5 consumes it.

## 4. R2-03 — exact CableDefinition hash and ELV2 wire compatibility

Hash algorithm is frozen:

```text
schema marker = "electra.cable-definition.v1"
canonical value = {
  "schema": marker,
  "definition": CableDefinition.toMap()
}
canonical bytes = UTF-8(canonicalEngineeringJson(canonical value))
hash = SHA-256(canonical bytes)
stored form = lowercase 64-character hexadecimal
```

`canonicalEngineeringJson` sorts map keys recursively. List order is semantically significant unless the CableDefinition contract explicitly declares a collection unordered; unordered definition collections MUST be normalized/sorted by canonical identity before `toMap()`.

ELV2 persisted wire compatibility:

- existing JSON field `profiles` remains the component-profile field and is not renamed in P1;
- P1 adds optional `cableDefinitions`, default `[]` on read;
- P5 later adds optional `physicalCompatibilityProfiles`, default `[]` on read;
- P1 MUST NOT persist `physicalCompatibilityProfiles` early;
- catalog publication requires at least one publishable payload family (`profiles` or `cableDefinitions` in P1; P5 extends this set later);
- old component-only catalogs round-trip byte-semantically without requiring cable definitions.

## 5. R2-04 — resource atom/composite expansion

CableDefinition owns a deterministic resource graph:

```text
CableResourceDefinition {
  identity
  kind
  allocatable
  atomic
  parentResourceId?
  childResourceIds[]
  groupMembership[]
  terminationPolicy
}
```

Invariants:

- identity unique in exact definition edition;
- resource graph is finite and acyclic;
- every allocatable non-atomic resource resolves to at least one atomic descendant;
- atomic resources have no childResourceIds;
- group definitions resolve only to declared resources;
- `WHOLE_CABLE` resolves to reserved atom `__WHOLE_CABLE__` for exclusivity and semantically covers all allocatable physical atoms.

Canonical resolver:

```text
resolve(selection, exactDefinition) -> sorted Set<atomicResourceIdentity>
```

Examples:

- an atomic PAIR definition resolves to `PAIR:1`;
- a composite PAIR exposing independently allocatable conductors resolves to `COND:1, COND:2`;
- CORE_GROUP resolves recursively to its atomic descendants.

Overlap is defined only over resolved atom sets. This guarantees PAIR-vs-CONDUCTOR conflict where the exact definition exposes the pair as a composite of those conductors.

## 6. R2-05 — termination completeness policy

Termination completeness is definition-driven, not guessed by resource kind.

```text
TerminationPolicy {
  mode: BOTH_ENDS | A_END_ONLY | B_END_ONLY | OPTIONAL | GROUP_LEVEL
  terminalRequired: bool
  allowedRoles[]
}
```

Every allocatable resource definition carries one policy. `WHOLE_CABLE` selection expands termination obligations to the definition-declared termination resources; `__WHOLE_CABLE__` itself is never a fake physical terminal.

`ActivateCableAllocation` resolves selected atomic resources, derives obligations from exact CableDefinition, and requires exactly the mappings mandated by those policies.

Examples:

- fiber/conductor with BOTH_ENDS -> A and B mappings required;
- shield with A_END_ONLY -> only A required;
- OPTIONAL -> no mapping required for activation;
- GROUP_LEVEL -> mapping references the declared group termination resource.

No P2 command may hard-code `all selected resources need A+B`.

## 7. R2-06 — canonical RouteHandoff

Legacy `FloorRoutingHandoff` is not the canonical ELV3 handoff because it is run-owned. Reusable route continuity uses:

```text
RouteHandoff {
  id
  projectId
  fromRouteNodeId
  toRouteNodeId
  kind: SURFACE | FLOOR | VERTICAL | EXPLICIT
  adjacencyRef?
  evidenceJson
  revision
}
```

Rules:

- endpoints are canonical route nodes in the same project;
- no self handoff;
- direction is explicit; bidirectional behavior requires two-way flag/equivalent typed semantics;
- handoff does not reference CableRun;
- handoff must carry accepted spatial/adjacency evidence appropriate to kind;
- continuity is valid only by same canonical node or accepted RouteHandoff.

Legacy floor handoffs may be adapted to read-only RouteHandoff projections where evidence is sufficient; they are not reused as canonical persistence.

## 8. R2-07 — ProjectDesignRevision command contract

Commands are frozen:

```text
BootstrapProjectDesignRevision
FreezeProjectDesignRevision
CreateNextWorkingDesignRevision
SupersedeProjectDesignRevision
ArchiveProjectDesignRevision
```

Rules:

- exactly one WORKING revision per project;
- Bootstrap is idempotent and only valid when none exists;
- Freeze writes DesignRevisionPhysicalSnapshot and WORKING -> FROZEN atomically;
- CreateNextWorking requires no existing WORKING revision and `basedOnRevisionId` referencing FROZEN or SUPERSEDED revision;
- creating next working revision does not clone Cable identity; revision-sensitive realizations are edited against the new revision context;
- Supersede applies only to FROZEN when a successor baseline is accepted;
- Archive rejects current WORKING and revisions required by retained project evidence.

Repository transaction + unique/partial-index support MUST prevent two concurrent WORKING revisions.

## 9. R2-08 — remove P1/P5 phase leakage

P1 extends `EngineeringReferenceCatalog` with `cableDefinitions` only.

P5 introduces `physicalCompatibilityProfiles` and its backward-compatible reader/writer extension. P1 tests MUST prove no P5 payload or persistence is introduced.

## 10. R2-09 — exact P3 table names

The exact P3 canonical names are:

```text
ProjectDesignRevisions
DesignRevisionPhysicalSnapshots
CanonicalCableRuns
CableRunTraversals
RouteHandoffs
RouteBendEvidence
LegacyRouteAdoptions
```

Existing legacy `CableRuns`, `CableRoutes`, `CableRouteNodes`, `CableRouteSegments`, `FloorRoutingHandoffs` remain coexistence inputs. Implementers may not choose alternate canonical table names in P3.

## 11. R2-10 — exact P6 formulas and occupancy granularity

### Installed length

```text
installedLengthMm =
  geometricTraversalLengthMm * (1 + reservePercent / 100)
  + terminationAllowanceMm
```

`terminationAllowanceMm` is the total run-level allowance across both ends; it is applied exactly once. `reservePercent` must be finite and >= 0. Missing/invalid traversal geometry -> BLOCKED.

### Cable occupied area

For a circular cable with `outerDiameterMm`:

```text
occupiedAreaMm2 = PI * outerDiameterMm^2 / 4
```

Missing/non-positive outer diameter -> BLOCKED for fill calculations. Non-circular/hybrid constructions require an explicit exact-definition occupied-area fact; no guessed equivalent diameter.

### Carrier factual fill basis

Occupancy is computed per physical route usage key:

```text
(routeSegmentId, physicalCarrierId, carrierCompartmentId?)
```

For each key, count each distinct Cable identity once and sum its occupied area once. Allocations never multiply occupancy.

Carrier-level summaries are derived from segment/compartment facts (for example maximum occupied area/fill basis across traversed segments); they are not the source of truth.

P6 reports factual occupied area and usable area. Jurisdictional permitted percentage remains ELV7.

### Segregation evidence

P6 reports measured/derived geometry facts only: actual separation where geometrically defined, shared carrier/compartment, barrier evidence. No jurisdictional required distance is applied.

## 12. R2-11 — PathwayContext containment

`parentContextId` forms a project-local acyclic containment tree/forest.

Rules:

- parent != self;
- parent same project;
- transitive cycles forbidden;
- archive blocked while active child contexts or carriers depend on context;
- a child spatial host must be geometrically/logically contained by or compatible with parent scope.

Allowed parent kinds:

```text
ROOM_LOCAL     -> FLOOR_COMMON | PROJECT_SHARED
CEILING_VOID   -> ROOM_LOCAL | FLOOR_COMMON | PROJECT_SHARED
UNDERFLOOR     -> ROOM_LOCAL | FLOOR_COMMON | PROJECT_SHARED
FLOOR_COMMON   -> PROJECT_SHARED
RISER          -> PROJECT_SHARED
SHAFT          -> PROJECT_SHARED
PROJECT_SHARED -> none
```

A VerticalHost may not be parented under a single ROOM_LOCAL context.

## 13. R2-12 — deterministic P8 failure matrix

P8 MUST include at least:

| Command | Injected failure | Required post-rollback state |
|---|---|---|
| CreateCable | after Cable INSERT before idempotency outcome commit | no Cable, no command effect |
| ReserveCableResources | after first resource atom INSERT | allocation remains DRAFT, zero consuming claims |
| Bind/Replace termination | after first mapping mutation | prior complete mapping set restored |
| ActivateCableAllocation | before allocation state UPDATE | allocation remains RESERVED |
| FreezeProjectDesignRevision | after snapshot INSERT before state update | no snapshot committed, revision remains WORKING |
| CreateNextWorkingDesignRevision | after new revision INSERT | no second WORKING revision committed |
| RerouteCableRun | after old traversal removal / before replacement complete | old traversal chain fully restored |
| AttachTraversalToCarrier | after reference mutation | prior carrier/compartment reference restored |
| AdoptLegacyElectricalRoute | after Cable creation before adoption completion | no Cable/CanonicalCableRun/adoption residue |
| any compound command | optimistic revision conflict before commit | zero partial effects |

Each failure point is exercised with database reopen verification.

## 14. Closure matrix

```text
R2-01 frozen design revision source-of-truth     CLOSED
R2-02 bend-radius evidence                       CLOSED
R2-03 CableDefinition hash/wire compatibility    CLOSED
R2-04 resource atom/composite expansion          CLOSED
R2-05 termination policy                         CLOSED
R2-06 canonical RouteHandoff                     CLOSED
R2-07 ProjectDesignRevision commands             CLOSED
R2-08 P1/P5 phase leakage                        CLOSED
R2-09 P3 table-name contradiction                CLOSED
R2-10 P6 formulas/occupancy granularity          CLOSED
R2-11 PathwayContext containment                 CLOSED
R2-12 P8 failure matrix                          CLOSED
```

No item is deferred to implementation-time architecture selection.
