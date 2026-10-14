# Electra — ELV3 PRE-P1 Final Specification Hardening

Status: AUTHORITATIVE IMPLEMENTATION HARDENING / CLOSED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Parent architecture: `docs/product/elv3-p0-system-architecture-remediation.md`  
Master implementation spec: `docs/product/elv3-implementation-specification.md`

## 1. Purpose

This document closes the last implementation ambiguities found by the adversarial review of ELV3 before P1 execution. It is authoritative wherever earlier P0/P1-P9 wording allowed more than one incompatible implementation.

The hardening criterion is strict:

> Two independent teams following the specification must produce compatible domain identities, persistence relations, command semantics and phase boundaries without inventing architecture during coding.

The seven findings F1-F7 below are CLOSED by explicit decisions.

---

## 2. F1 — CableDefinition reference contract

### Decision

ELV3 does not create a new catalog table, catalog lifecycle or component-style binding row for Cable definitions.

The existing ELV2 `EngineeringReferenceCatalogs` table remains the single project-scoped, versioned reference container. Its catalog payload is extended in P1 to support typed cable definitions in addition to component profiles.

Canonical catalog shape evolves conceptually to:

```text
EngineeringReferenceCatalog
  id
  code
  version
  source
  jurisdiction?
  componentProfiles[]
  cableDefinitions[]
  physicalCompatibilityProfiles[]
  vocabulary
```

`componentProfiles[]` preserves current semantics. Existing component bindings remain component-only and MUST NOT be reused as Cable bindings.

### CableDefinition

```text
CableDefinition {
  code
  label
  medium
  construction
  resourceDefinitions[]
  outerDiameterMm?
  minimumBendRadiusMm?
  installationFacts
  environmentRatings
  technicalClasses
}
```

The definition is immutable inside one exact catalog edition. `code` is canonical and unique in `cableDefinitions[]` after normalization.

### CableDefinitionRef

A Cable stores an exact immutable value reference:

```text
CableDefinitionRef {
  catalogId
  catalogVersion
  definitionCode
  definitionContentHash
}
```

Rules:

1. `catalogId` resolves to `EngineeringReferenceCatalogs.id` in the same project.
2. `catalogVersion` MUST equal the persisted catalog row edition used at creation/adoption time.
3. `definitionCode` MUST resolve inside that exact catalog payload.
4. `definitionContentHash` is computed deterministically from the canonical serialized CableDefinition and MUST match on restart.
5. a later catalog import/version never changes an existing Cable reference.
6. no lookup by "latest" is allowed while reconstructing Cable.
7. manufacturer SKU is downstream ELV8 mapping and is never the CableDefinition identity.

There is no `CableDefinitionBindings` table in P1. The exact reference is persisted on `Cables` because the catalog itself is already project-scoped/versioned.

### P1 persistence fields

```text
Cables
- id PK
- project_id FK -> Projects.id
- label
- name
- definition_catalog_id FK -> EngineeringReferenceCatalogs.id
- definition_catalog_version
- definition_code
- definition_content_hash
- lifecycle_state
- revision
- created_at
- updated_at
- archived_at?
- origin_device_id
```

P1 repository resolution is exact tuple lookup + payload verification, never component binding lookup.

---

## 3. F2 — Route evolution strategy

### Decision

ELV3 uses one routing kernel. The existing `CableRoutes`, `CableRouteNodes` and `CableRouteSegments` are evolved into reusable route/geometry infrastructure. No second parallel route graph is introduced.

Authoritative ADR: `docs/adr/ADR-029-elv3-reusable-route-traversal.md`.

Canonical P3 direction:

```text
Reusable route geometry
CableRoute
  -> CableRouteNode[]
  -> CableRouteSegment[]

Canonical cable usage
CableRun
  -> CableRunTraversal[]
       -> CableRouteSegment
```

A canonical `CableRun` no longer owns one private `routeId` as its final-domain identity. Traversals reference existing/evolved route segments in order.

Legacy electrical `CableRuns.routeId` remains untouched for legacy rows during coexistence. The P3 adapter reads old private-route rows and exposes them through the canonical traversal view without destructive conversion.

New ELV3 writes MUST use `CableRunTraversals`; they MUST NOT create a second geometry subsystem.

---

## 4. F3 — DesignRevision identity

### Decision

`Projects.revision` is an optimistic-concurrency counter and MUST NOT be used as engineering design-revision identity.

ELV3 introduces/reuses a stable project design revision root:

```text
ProjectDesignRevision {
  id
  projectId
  code
  sequence
  state: WORKING | FROZEN | SUPERSEDED | ARCHIVED
  basedOnRevisionId?
  revision
  createdAt
  updatedAt
}
```

Authoritative ADR: `docs/adr/ADR-030-project-design-revision-identity.md`.

Rules:

1. every project has exactly one current WORKING design revision for editable design data;
2. `id` is stable and never derived from the mutable integer `Projects.revision`;
3. `code` is human-visible and unique inside project, but identity is `id`;
4. freezing a revision preserves reproducible design evidence;
5. a new working revision may be based on a frozen/superseded revision;
6. CableRun is unique-active per `(cableId, designRevisionId)`;
7. P1/P2 entities that are global project physical identities (`Cable`, `CableAllocation`) are not duplicated merely because a design revision changes; their revision-sensitive realizations/findings carry designRevisionId where needed.

P3 persistence MUST add `ProjectDesignRevisions` before canonical `CableRuns.design_revision_id` is introduced.

---

## 5. F4 — CableAllocation lifecycle

### Decision

The state machine is frozen and no arbitrary state skipping is permitted.

```text
DRAFT
  -> RESERVED
  -> ACTIVE
  -> RELEASED
  -> ARCHIVED
```

Permitted cancellation/history transitions:

```text
DRAFT    -> ARCHIVED
RESERVED -> RELEASED
```

No other direct transition is legal.

Semantics:

- `DRAFT`: no resource reservation; editable proposal only.
- `RESERVED`: resource atoms are claimed and participate in overlap/WHOLE_CABLE exclusion.
- `ACTIVE`: accepted physical realization; resources remain claimed.
- `RELEASED`: resource atoms are free; allocation remains evidence and cannot become ACTIVE again.
- `ARCHIVED`: terminal historical state; consumes no resources.

Commands map exactly:

```text
CreateCableAllocationDraft   -> DRAFT
ReserveCableResources        -> DRAFT -> RESERVED
ActivateCableAllocation      -> RESERVED -> ACTIVE
ReleaseCableResources        -> RESERVED|ACTIVE -> RELEASED
ArchiveCableAllocation       -> DRAFT|RELEASED -> ARCHIVED
```

`AllocateCableResources` may remain a convenience application command only as an atomic composition of `create draft + reserve`; its committed state is RESERVED, never an implementation-defined state.

Database resource claims exist only for RESERVED/ACTIVE allocations.

---

## 6. F5 — Multi-cable policy

### Decision

ELV3 P1-P9 does NOT implement generic cable splice/transition topology.

Canonical rule for this delivery:

```text
one continuous wired EngineeringConnection
  -> zero or one resource-consuming Cable
```

A second active/reserved CableAllocation for the same EngineeringConnection on a different Cable is rejected with:

```text
ELV_ALLOC_MULTI_CABLE_NOT_SUPPORTED
```

The previous `transitionRef` placeholder is removed from the P1-P9 canonical model.

Future splice/connector/patch/media-transition work MUST introduce an explicit typed `CableTransition`/termination topology contract before multi-cable realization is enabled. Ordering or sequence metadata will never prove continuity.

This restriction does not prevent:

- one physical Cable carrying multiple different EngineeringConnections by non-overlapping resources;
- multiple CableRuns across historical design revisions for the same Cable;
- InternalConnectivity inside patch panels/components;
- future explicit transition entities.

---

## 7. F6 — PathwayContext sealed spatial model

### Decision

`spatialHost/reference` is removed as an open placeholder. PathwayContext uses a closed typed host contract in ELV3 P4.

```text
sealed PathwayContextHost
  RoomHost(roomId)
  FloorHost(floorId)
  SurfaceVoidHost(floorId, spatialFeatureId)
  VerticalHost(fromFloorId, toFloorId, spatialFeatureId?)
  ProjectHost(projectId)
```

Kind-to-host mapping is mandatory:

| Pathway kind | Required host |
|---|---|
| ROOM_LOCAL | RoomHost |
| FLOOR_COMMON | FloorHost |
| CEILING_VOID | SurfaceVoidHost |
| UNDERFLOOR | SurfaceVoidHost |
| RISER | VerticalHost |
| SHAFT | VerticalHost |
| PROJECT_SHARED | ProjectHost |

Persistence is explicit, not generic JSON identity:

```text
PathwayContexts
- id
- project_id
- kind
- host_type
- room_id?
- floor_id?
- from_floor_id?
- to_floor_id?
- spatial_feature_id?
- parent_context_id?
- provenance_json
- lifecycle_state
- revision/audit columns
```

Validation rejects every field combination not matching the table above. All referenced spatial objects must belong to the same project.

`RISER`/`SHAFT` may span multiple floors through `fromFloorId`/`toFloorId`; they are never forced into room ownership.

---

## 8. F7 — Technical compatibility/profile ownership and segregation boundary

### Decision

ELV3 P5 technical compatibility profiles are typed records inside the same ELV2 `EngineeringReferenceCatalog` edition. They do not use a new catalog lifecycle and they do not repurpose component connection profiles by name alone.

Canonical type:

```text
PhysicalCompatibilityProfile {
  code
  applicableCableClasses[]
  applicableCarrierClasses[]
  intrinsicInstallationRules[]
  environmentCompatibilityRules[]
  source
}
```

Cable/Carrier/profile identities are resolved from exact ELV2 catalog editions and included in result fingerprints.

Existing `EngineeringCompatibilityProfiles` persistence remains the ELV1 logical connection-compatibility projection unless explicitly evolved by a later dedicated migration. P5 MUST NOT silently reinterpret existing rows as physical routing profiles.

### ELV3 / ELV7 segregation boundary

ELV3 P5/P6 may compute only factual or intrinsic technical evidence, for example:

```text
actual distance between routes = 37 mm
same carrier compartment = true
physical barrier present = false
cable minimum bend radius = 32 mm
actual bend radius = 45 mm
carrier usable area = 1200 mm2
occupied cable area = 510 mm2
```

ELV3 MUST NOT own jurisdictional acceptance thresholds such as:

```text
required segregation distance = 50 mm under standard X
permitted fill = 40% under jurisdiction Y
fire cable separation rule Z
```

Those thresholds and PASS/FAIL compliance findings belong to ELV7 versioned normative rule packs.

The only limits ELV3 may directly enforce are intrinsic physical/manufacturer/reference-definition limits whose meaning does not depend on jurisdiction, such as minimum bend radius, connector geometry, material/environment rating or factual dimensional impossibility.

`ELV-ROUTE-03` is therefore renamed semantically to **segregation evidence basis**: it reports measured/shared-containment facts and does not decide normative compliance.

---

## 9. Additional ambiguity closures

To make the master specification executable, the following are also frozen:

### 9.1 Cable label uniqueness

Active Cable labels are mandatory, normalized by trim + canonical uppercase comparison, and unique per project among non-archived Cables.

### 9.2 Cable restore

`RestoreCable` is out of scope for ELV3 P1-P9. Archived Cable is terminal for this delivery. A future restore policy requires a separate command because labels/resources may have been reused.

### 9.3 Idempotency identity

Every replayable compound command carries a non-empty `commandId`. Persisted command outcome/effect identity MUST make same-command replay return the same logical result; same `commandId` with a different normalized payload returns `ELV_IDEMPOTENCY_CONFLICT`.

### 9.4 Concurrency basis

Optimistic `revision` protects mutable roots. Allocation resource exclusivity additionally requires an atomic database transaction plus enforceable claim identity. Application pre-check alone is insufficient.

### 9.5 Resource uniqueness implementation

P2 MUST persist one claim row per normalized atomic resource with a stable `claim_key`:

```text
<cableId>|<definitionResourceIdentity>
```

WHOLE_CABLE uses the reserved atom identity `__WHOLE_CABLE__`. Reservation of WHOLE_CABLE requires checking that no other consuming claim exists; any partial reservation requires checking that WHOLE_CABLE claim does not exist. Both checks and writes occur in one transaction.

### 9.6 Route traversal continuity

Two adjacent traversals are continuous only when the previous traversal end node and next traversal start node are the same canonical route node or are connected by one explicit accepted surface/floor handoff. Coordinate equality alone never proves continuity.

---

## 10. Final hardening closure matrix

```text
F1 CableDefinition exact ELV2 reference          CLOSED
F2 one route evolution strategy                  CLOSED
F3 stable ProjectDesignRevision identity         CLOSED
F4 strict CableAllocation lifecycle              CLOSED
F5 multi-cable placeholder removed               CLOSED
F6 sealed PathwayContext host model              CLOSED
F7 profile ownership / ELV7 boundary             CLOSED
```

No item is deferred to implementation-time architecture choice.

## 11. Readiness rule

P1 may start only against:

1. `elv3-p0-system-architecture-remediation.md`;
2. this final hardening contract;
3. the synchronized `elv3-implementation-specification.md`;
4. ADR-029 and ADR-030;
5. the final readiness audit after synchronization.

Any implementation that conflicts with these decisions is non-conforming even if an older P0/P1-P9 paragraph allowed the superseded choice.
