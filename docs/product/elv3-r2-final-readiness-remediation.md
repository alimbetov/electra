# Electra — ELV3 R2 Final Readiness Remediation

Status: AUTHORITATIVE R2 REMEDIATION / CLOSED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Triggered by: `docs/audit/elv3-p1-p9-second-technical-audit.md`

## 1. Purpose

This contract closes R2-01 through R2-12 from the second P1-P9 technical audit and two additional defects found while integrating those fixes (R2-13/R2-14). It overrides conflicting wording in `elv3-implementation-specification-v2.md`, PRE-P1 hardening and older P0 documents.

No item is left for implementation-time architecture choice.

## 2. R2-01 — frozen ProjectDesignRevision reproducibility

A FROZEN revision is reproduced from an immutable physical snapshot, not mutable current rows.

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

Constraint: `UNIQUE(design_revision_id)`.

The snapshot payload embeds the exact physical facts required to reconstruct the frozen revision, not merely mutable row references/revision numbers:

- Cable identity/label + exact CableDefinitionRef + Cable revision;
- all non-archived allocation identities/states, persistent selected resources and resolved atomic resource sets;
- termination mappings;
- canonical CableRun identity, lifecycle and run allowances;
- ordered traversal chain;
- exact route node/segment geometry facts used by those traversals, including coordinates/anchors/laying method and source revisions;
- RouteHandoff facts used by continuity;
- RouteBendEvidence facts;
- PathwayContext, PhysicalCarrier and compartment facts used by traversals;
- exact P5 profile refs used by frozen technical findings when present;
- snapshot schema version and source entity revision metadata.

References to immutable ELV2 catalog editions may remain references because the catalog import contract already forbids mutation. Mutable route/carrier/pathway facts MUST be embedded so later edits cannot change historical reconstruction.

Freeze transaction:

```text
BEGIN
  load WORKING ProjectDesignRevision at expected revision
  validate the physical graph for freeze
  build deterministic embedded snapshot payload
  canonicalize payload
  compute SHA-256
  insert immutable DesignRevisionPhysicalSnapshot
  WORKING -> FROZEN
  revision++
COMMIT
```

A FROZEN revision is read from its snapshot. Current mutable rows may evolve for the next WORKING revision. Snapshot rows are append-only/immutable; hash mismatch is a blocking integrity failure.

## 3. R2-02 — bend-radius evidence

Polyline vertices do not prove bend radius. ELV3 never infers radius from adjacent straight segments.

```text
RouteBendEvidence {
  id
  projectId
  routeNodeId
  radiusMm
  evidenceKind: DESIGNED_RADIUS | FITTING_RADIUS | MEASURED_RADIUS
  sourceRef?
  lifecycleState
  revision
}
```

Rules:

- radiusMm finite and > 0;
- same-project bend-capable route node;
- max one ACTIVE evidence row per route node;
- required bend radius + no evidence => P5 `UNRESOLVED`, P6 bend process `BLOCKED`;
- evidence present => intrinsic check `radiusMm >= minimumBendRadiusMm`;
- angle/coordinate heuristics never substitute for evidence.

P3 adds persistence; P5/P6 consume it.

## 4. R2-03 — exact CableDefinition hash and ELV2 wire compatibility

Hash algorithm:

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

`canonicalEngineeringJson` sorts map keys recursively. List order is significant unless the definition explicitly declares a collection unordered; such collections are sorted by canonical identity before `toMap()`.

Wire compatibility:

- existing JSON field `profiles` remains the component-profile field;
- P1 adds optional `cableDefinitions`, default `[]` on read;
- P5 later adds optional `physicalCompatibilityProfiles`, default `[]` on read;
- P1 MUST NOT persist P5 profiles;
- P1 publication requires at least one publishable `profiles` or `cableDefinitions` entry;
- old component-only catalog payloads remain readable and round-trip semantically unchanged.

## 5. R2-04 — resource atom/composite expansion

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
- finite acyclic resource graph;
- allocatable non-atomic resource resolves to >=1 atomic descendant;
- atomic resource has no children;
- declared groups resolve only to declared resources;
- WHOLE_CABLE uses reserved exclusivity atom `__WHOLE_CABLE__` and semantically covers every allocatable physical atom.

Canonical resolver:

```text
resolve(selection, exactDefinition) -> sorted Set<atomicResourceIdentity>
```

Examples:

- atomic PAIR -> `PAIR:1`;
- composite PAIR -> `COND:1, COND:2`;
- CORE_GROUP -> recursive atomic descendants.

Overlap is defined only over resolved atom sets.

## 6. R2-05 — termination completeness policy

```text
TerminationPolicy {
  mode: BOTH_ENDS | A_END_ONLY | B_END_ONLY | OPTIONAL | GROUP_LEVEL
  terminalRequired: bool
  allowedRoles[]
  groupTerminationResourceId?
}
```

Every allocatable resource has a policy. WHOLE_CABLE selection expands obligations to definition-declared termination resources; `__WHOLE_CABLE__` is never a fake terminal.

`ActivateCableAllocation` derives exact obligations from the CableDefinition and requires exactly the mandated mappings.

- BOTH_ENDS -> A and B required;
- A_END_ONLY/B_END_ONLY -> one end required;
- OPTIONAL -> no mapping required for activation;
- GROUP_LEVEL -> mapping references the declared group termination resource.

`CableTerminationMapping.cableResourceIdentity` refers to a declared termination-obligation resource identity, which may be an atomic resource or an explicit group termination resource. No command hard-codes A+B for every selected resource.

## 7. R2-06 — canonical RouteHandoff

```text
RouteHandoff {
  id
  projectId
  fromRouteNodeId
  toRouteNodeId
  kind: SURFACE | FLOOR | VERTICAL | EXPLICIT
  direction: FORWARD | BIDIRECTIONAL
  adjacencyRef?
  evidenceJson
  revision
}
```

Rules:

- same-project canonical route nodes;
- no self handoff;
- no CableRun ownership;
- typed spatial/adjacency evidence required;
- continuity only by same canonical node or accepted RouteHandoff;
- handoff is a zero-design-length topological continuity relation. Any non-zero physical span, including vertical rise/drop, MUST be represented by route segment geometry and contributes to length there.

Legacy `FloorRoutingHandoffs` may be adapted to read-only handoff projections where evidence is sufficient; they are not canonical persistence.

## 8. R2-07 — ProjectDesignRevision commands

```text
BootstrapProjectDesignRevision
FreezeProjectDesignRevision
CreateNextWorkingDesignRevision
SupersedeProjectDesignRevision
ArchiveProjectDesignRevision
```

Rules:

- exactly one WORKING revision per project;
- Bootstrap idempotent, only when none exists;
- Freeze writes immutable snapshot and WORKING -> FROZEN atomically;
- CreateNextWorking requires no current WORKING and basedOnRevisionId referencing FROZEN/SUPERSEDED;
- Cable identity is not cloned solely for a new revision;
- Supersede applies to FROZEN after successor acceptance;
- Archive rejects current WORKING and retained-evidence dependencies;
- transaction + enforceable uniqueness prevents concurrent second WORKING revision.

## 9. R2-08 — remove P1/P5 phase leakage

P1 extends `EngineeringReferenceCatalog` with `cableDefinitions` only. P5 later adds `physicalCompatibilityProfiles`. P1 tests prove no P5 payload/persistence is introduced.

## 10. R2-09 — exact P3 names

P3 canonical persistence names are exactly:

```text
ProjectDesignRevisions
DesignRevisionPhysicalSnapshots
CanonicalCableRuns
CableRunTraversals
RouteHandoffs
RouteBendEvidence
LegacyRouteAdoptions
```

Legacy `CableRuns`, `CableRoutes`, `CableRouteNodes`, `CableRouteSegments`, `FloorRoutingHandoffs` remain coexistence inputs.

## 11. R2-10 — exact P6 formulas and occupancy granularity

Installed length:

```text
installedLengthMm =
  geometricTraversalLengthMm * (1 + reservePercent / 100)
  + terminationAllowanceMm
```

`terminationAllowanceMm` is total run-level allowance across both ends and is applied once. Handoffs add zero length. Invalid/missing geometry -> BLOCKED.

Circular cable area:

```text
occupiedAreaMm2 = PI * outerDiameterMm^2 / 4
```

Missing/non-positive diameter -> BLOCKED. Non-circular/hybrid constructions require explicit `occupiedAreaMm2` in exact definition; no guessed equivalent diameter.

Occupancy source-of-truth key:

```text
(routeSegmentId, physicalCarrierId, carrierCompartmentId?)
```

Per key, each distinct Cable id contributes area once regardless of allocation count. Carrier summaries derive from these segment/compartment facts.

`ELV-ROUTE-05 congestion` is factual: distinct cable count, occupied area, usable area and derived factual occupancy ratio per usage key; it does not apply normative acceptance thresholds.

Segregation output is factual geometry/shared-containment/barrier evidence only. ELV7 owns jurisdictional thresholds.

## 12. R2-11 — PathwayContext containment

`parentContextId` forms a project-local acyclic forest.

Rules:

- parent != self;
- same project;
- transitive cycles forbidden;
- archive blocked by active child contexts/carriers;
- child host must be compatible with parent spatial scope.

Allowed parents:

```text
ROOM_LOCAL     -> FLOOR_COMMON | PROJECT_SHARED
CEILING_VOID   -> ROOM_LOCAL | FLOOR_COMMON | PROJECT_SHARED
UNDERFLOOR     -> ROOM_LOCAL | FLOOR_COMMON | PROJECT_SHARED
FLOOR_COMMON   -> PROJECT_SHARED
RISER          -> PROJECT_SHARED
SHAFT          -> PROJECT_SHARED
PROJECT_SHARED -> none
```

VerticalHost cannot be parented under one ROOM_LOCAL context.

## 13. R2-12 — deterministic P8 failure matrix

| Command | Injected failure | Required post-rollback state |
|---|---|---|
| CreateCable | after Cable INSERT before idempotency outcome commit | no Cable, no command effect |
| ReserveCableResources | after first claim INSERT | allocation DRAFT, zero consuming claims |
| Bind/Replace termination | after first mapping mutation | prior complete mapping set restored |
| ActivateCableAllocation | before state UPDATE | remains RESERVED |
| FreezeProjectDesignRevision | after snapshot INSERT before state update | no snapshot committed, remains WORKING |
| CreateNextWorkingDesignRevision | after new revision INSERT | no second WORKING committed |
| RerouteCableRun | after old traversal removal | old chain fully restored |
| AttachTraversalToCarrier | after reference mutation | prior reference restored |
| AdoptLegacyElectricalRoute | after Cable create | no Cable/CanonicalCableRun/adoption residue |
| any compound command | optimistic conflict | zero partial effects |

Every case includes database reopen verification.

## 14. R2-13 — separate resource-selection history from active claims

The selected resource evidence MUST survive RELEASED/ARCHIVED states. Therefore P2 uses separate persistence roles:

```text
CableAllocationResourceSelections
- allocation_id
- selected_resource_identity
- resolved_atoms_json/hash
- definition_ref/hash evidence
- immutable audit fields

CableResourceClaims
- allocation_id
- cable_id
- atomic_resource_identity
- claim_key UNIQUE while present
```

Rules:

- selection rows are historical evidence and are never deleted merely because resources are released;
- RESERVED/ACTIVE owns `CableResourceClaims` rows;
- Release removes claims atomically but preserves selection and termination history;
- reusing the same physical atom for a later allocation is allowed after prior claim removal;
- restart of RELEASED/ARCHIVED allocation still reconstructs its original selection exactly.

`claim_key = <cableId>|<atomicResourceIdentity>`. WHOLE_CABLE uses `__WHOLE_CABLE__` with the transaction checks defined in R2-04.

## 15. R2-14 — exact P5 PhysicalCompatibilityProfile binding

P5 must never search "latest" or all imported catalogs implicitly.

Canonical exact ref:

```text
PhysicalCompatibilityProfileRef {
  catalogId
  catalogVersion
  profileCode
  profileContentHash
}
```

P5 introduces project-owned active bindings:

```text
ProjectPhysicalCompatibilityProfileBindings
- id
- project_id
- profile_role
- catalog_id
- catalog_version
- profile_code
- profile_content_hash
- lifecycle_state
- revision/audit
```

Rules:

- exact same-project catalog edition resolution + SHA-256 content verification using a versioned canonical profile schema marker;
- active binding identity is deterministic by project + profile_role;
- no implicit latest-edition adoption;
- changing binding is an explicit command and invalidates affected P5/P6 results;
- evaluation applies only exact active refs selected by project policy plus intrinsic CableDefinition facts;
- incompatible/duplicate active profile roles are rejected or produce deterministic UNRESOLVED according to the profile-role contract, never silent precedence.

This remains inside ELV2 catalog governance; it does not create a second catalog lifecycle.

## 16. Closure matrix

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
R2-13 selection history vs consuming claims      CLOSED
R2-14 exact P5 profile binding                   CLOSED
```

No item is deferred to implementation-time architecture selection.
