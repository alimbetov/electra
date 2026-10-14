# Electra — ELV3 Implementation Specification P1–P9

Status: IMPLEMENTATION SPECIFICATION / READY FOR EXECUTION  
Branch: `feat/flutter-elv3-physical-routing-design`  
Architecture baseline: `docs/product/elv3-p0-system-architecture-remediation.md`  
Final P0 audit: `docs/audit/elv3-p0-hard-design-audit.md`  

## 1. Purpose

This document converts the remediated ELV3 architecture into executable implementation work packages P1–P9.

It is intentionally more concrete than P0. P0 defines what the model means. This specification defines how each capability is introduced, what may change, what must remain stable, which commands form transaction boundaries, what is persisted, how failures behave and what evidence closes each phase.

No phase may reintroduce any superseded first-P0 assumption.

## 2. Governing architecture

```text
ELV1 — logical topology
EngineeringSystem
  -> TopologyGroup
  -> EngineeringConnection
  -> Port

ELV2 — canonical reference identity
ReferenceSnapshot / project binding
  -> exact CableDefinition/Profile edition

ELV3 — physical realization
EngineeringConnection
  -> CableAllocation
      -> CableResourceSelection
      -> CableTerminationMapping[]
  -> Cable
  -> CableRun
  -> ordered CableTraversal[]
  -> reusable Route / geometry infrastructure
  -> optional PhysicalCarrier
  -> PathwayContext
```

Hard invariants:

1. `EngineeringConnection != Cable`.
2. `CableDefinition` uses ELV2 version/reference governance.
3. one Cable has at most one active CableRun per design revision.
4. room/floor/riser boundaries do not create additional Cable identities or CableRuns.
5. logical connectivity is never inferred from geometry crossings.
6. physical occupancy counts physical Cable identities, not allocation count.
7. multiple Cables for one continuous connection require explicit physical transition evidence.
8. legacy electrical routing remains valid until explicitly adopted.
9. ELV3 produces technical physical findings; ELV7 owns jurisdictional compliance.
10. commands, not UI row mutations, define consistency boundaries.

## 3. Common implementation rules for every phase

Every P1–P9 phase must provide:

- pure-domain model/validator changes in `engineering_core` where applicable;
- application command/service layer changes separated from Flutter widgets;
- Drift migration only when persistence is introduced;
- repository APIs that preserve project isolation;
- stable structured validation/error codes;
- deterministic restart reconstruction;
- idempotency for replayable compound commands;
- optimistic revision guard for mutable aggregate roots;
- undo/redo contract for engineer-visible editor commands;
- affected-subgraph invalidation keys;
- pure-Dart tests before UI tests where business logic is involved;
- exact-SHA CI evidence before the next phase starts.

Generated Drift files are generated artifacts, never manually edited.

## 4. Common result/error envelope

Application commands should expose an equivalent typed outcome:

```text
CommandResult<T>
  Success<T>
  ValidationFailure(code, field?, details?)
  Conflict(code, expectedRevision?, actualRevision?)
  NotFound(code, entityType, entityId)
  DependencyBlocked(code, dependentIds[])
  StorageFailure(code, causeCategory)
```

Minimum common categories:

```text
ELV_PROJECT_MISMATCH
ELV_REVISION_CONFLICT
ELV_REFERENCE_NOT_FOUND
ELV_REFERENCE_VERSION_INVALID
ELV_DEPENDENCY_BLOCKED
ELV_IDEMPOTENCY_CONFLICT
ELV_RESTART_RECONSTRUCTION_FAILED
```

Domain validators return deterministic findings and do not throw storage exceptions.

## 5. State model

### Cable

```text
ACTIVE -> ARCHIVED
```

Archive is blocked while active allocations or an active CableRun require the Cable.

### CableAllocation

Implementation may use:

```text
DRAFT -> RESERVED -> ACTIVE -> RELEASED -> ARCHIVED
```

Resource-consuming states are exactly `RESERVED` and `ACTIVE`.

Rules:

- DRAFT does not reserve cable resources;
- RESERVED participates in overlap checks;
- ACTIVE is physical realization used by calculations/reports;
- RELEASED frees resources but preserves evidence where required;
- ARCHIVED is historical and never consumes resources.

Skipping states is allowed only through explicit command semantics and equivalent invariants.

### CableRun

```text
ACTIVE -> SUPERSEDED -> ARCHIVED
```

One active realization per `(cableId, designRevisionId)`.

## 6. Dependency keys

Canonical invalidation keys should be equivalent to:

```text
cable:<id>
allocation:<id>
cable-run:<id>
route:<id>
route-segment:<id>
carrier:<id>
pathway-context:<id>
connection:<id>
reference-binding:<id>
```

A command publishes/returns affected keys. Recalculation orchestrators consume them; UI must not guess dependency impact.

---

# P1 — Cable identity and exact definition binding

## 7. Objective

Introduce project-owned physical Cable identity without yet implementing resource allocation or routing.

P1 must prove that a Cable can be created, persisted, reconstructed and bound to the exact ELV2 cable-definition/profile edition without creating a new catalog lifecycle.

## 8. Domain contract

Conceptual model:

```text
Cable {
  id
  projectId
  label
  name
  definitionBindingId
  lifecycleState
  revision
}
```

Required invariants:

- id is stable and project-scoped;
- label is normalized and unique among active Cables in the project where project policy requires labels;
- `definitionBindingId` resolves to an exact immutable ELV2 reference/project binding;
- changing latest catalog content does not mutate existing Cable meaning;
- Cable has no room/floor/circuit ownership;
- Cable has no persisted editable calculated length;
- manufacturer SKU must not replace canonical definition identity.

## 9. P1 commands

```text
CreateCable
ChangeCableDefinitionBinding
ArchiveCable
RestoreCable? // optional only if project archive conventions already support restore
```

### CreateCable

Input:

```text
projectId
cableId / command-generated stable id
label
name
exactDefinitionBindingId
expectedProjectRevision? / command idempotency key
```

Process:

```text
validate project
validate exact definition binding belongs to allowed project/reference context
validate cable definition supports physical cable use
normalize label
check active-label uniqueness
create Cable revision 1
commit
```

### ChangeCableDefinitionBinding

Allowed only when all future dependent constraints still pass.

In P1, if no allocations/runs exist, binding may change through an explicit command. From P2 onward the command must revalidate downstream state before commit.

No silent latest-version adoption.

### ArchiveCable

Blocked when dependent active allocations or CableRun exist.

## 10. P1 persistence

Add only project Cable identity and the minimum exact binding reference.

Conceptual table:

```text
Cables
- id PK
- project_id FK
- label
- name
- cable_definition_binding_id
- lifecycle_state
- revision
- created_at
- updated_at
- archived_at?
- origin_device_id? // use existing offline convention if required
```

Do not introduce P2 allocation tables or P3 routing tables early.

## 11. P1 error codes

At minimum:

```text
ELV_CABLE_MISSING_IDENTITY
ELV_CABLE_LABEL_EMPTY
ELV_CABLE_LABEL_DUPLICATE
ELV_CABLE_DEFINITION_BINDING_MISSING
ELV_CABLE_DEFINITION_BINDING_PROJECT_MISMATCH
ELV_CABLE_DEFINITION_BINDING_INVALID
ELV_CABLE_ARCHIVE_BLOCKED
```

## 12. P1 tests

Pure-domain/application:

- create valid Cable;
- reject missing/foreign definition binding;
- exact edition remains unchanged after other catalog revision exists;
- duplicate active label rejected;
- archive allowed when unreferenced;
- idempotent CreateCable retry returns same logical result;
- revision conflict rejected.

Persistence/restart:

```text
create Cable
close database
reopen
resolve exact binding
reconstruct identical Cable
```

Cross-discipline fixtures:

- Cat6 whole-cable CCTV definition;
- Cat6 LAN definition;
- 8-core ACS definition;
- fire-resistant cable definition;
- 12-fiber definition.

P1 does not yet allocate resources.

## 13. P1 exit gate

P1 is closed only when:

- domain/API/schema tests pass;
- mobile/core format+analyze pass;
- Drift generation pass;
- restart test pass;
- no P2/P3 schema leaked into P1;
- exact branch SHA has green CI.

---

# P2 — CableAllocation, resources and terminations

## 14. Objective

Implement physical resource claims that realize ELV1 EngineeringConnections through Cable resources.

P2 must be concurrency-safe and must support ACS/fiber cases without free-form selectors.

## 15. CableDefinition resource contract

The exact ELV2 cable definition must expose a deterministic resource namespace.

Conceptual values:

```text
CableResourceDefinition {
  identity
  kind
  index?
  groupMembership?
  addressable
  metadata/provenance from exact definition
}
```

Supported standard kinds include:

```text
WHOLE_CABLE
PAIR
CONDUCTOR
FIBER
CORE_GROUP
SHIELD
DRAIN
PROTECTIVE_EARTH
FUNCTIONAL_EARTH
```

Definitions may expose additional typed resource kinds through canonical reference semantics; runtime arbitrary strings are not allowed as the only identity.

## 16. Selection contract

Equivalent sealed model:

```text
CableResourceSelection
  WholeCableSelection
  ResourceSetSelection(resourceIdentities[])
  DefinitionGroupSelection(groupIdentity)
```

Every selection resolves to normalized atomic definition resource identities.

Invariant:

```text
A.resources ∩ B.resources = empty
```

for all resource-consuming allocations on one Cable.

`WHOLE_CABLE` conflicts with every other resource-consuming allocation.

## 17. CableAllocation contract

```text
CableAllocation {
  id
  projectId
  engineeringConnectionId
  cableId
  lifecycleState
  transitionRef?
  revision
}
```

Selection and termination rows are children/evidence of the allocation.

Default rule:

```text
one continuous wired EngineeringConnection -> one Cable
```

A second Cable for the same connection requires `transitionRef` resolving to an explicit splice/termination/connector/patch/media-transition object or accepted transition contract.

## 18. CableTerminationMapping

```text
CableTerminationMapping {
  allocationId
  cableResourceIdentity
  endRole: A | B | INTERMEDIATE
  endpointPortId
  endpointTerminalRef?
  terminationRole?
}
```

Rules:

- endpointPortId must belong to the same project;
- end A/B must correspond to connection endpoints unless an explicit intermediate transition applies;
- display labels are not identity;
- one physical resource end cannot be terminated twice incompatibly;
- termination mapping does not create logical topology.

## 19. P2 commands

```text
AllocateCableResources
ReserveCableResources
ActivateCableAllocation
ReleaseCableResources
ArchiveCableAllocation
BindCableTermination
ReplaceCableTermination
```

### AllocateCableResources transaction

```text
BEGIN
  load connection + Cable + exact definition binding
  validate same project
  resolve normalized resource set
  load all RESERVED/ACTIVE claims for Cable
  reject WHOLE_CABLE conflict
  reject atomic overlap
  validate explicit transition if connection already uses another Cable
  validate requested endpoint mappings structurally
  persist allocation + atomic resource rows + mappings
  increment relevant revisions
COMMIT
```

Concurrency rule: two overlapping allocations cannot both commit successfully.

## 20. P2 persistence

```text
CableAllocations
CableAllocationResources
CableTerminationMappings
```

Preferred uniqueness anchor:

```text
UNIQUE(cable_id, definition_resource_identity)
```

for consuming states if implementable directly; otherwise enforce an equivalent atomic reservation mechanism plus deterministic tests.

## 21. P2 error codes

```text
ELV_ALLOC_CONNECTION_NOT_FOUND
ELV_ALLOC_CABLE_NOT_FOUND
ELV_ALLOC_PROJECT_MISMATCH
ELV_ALLOC_RESOURCE_UNKNOWN
ELV_ALLOC_RESOURCE_NOT_ADDRESSABLE
ELV_ALLOC_RESOURCE_OVERLAP
ELV_ALLOC_WHOLE_CABLE_CONFLICT
ELV_ALLOC_DUPLICATE_CLAIM
ELV_ALLOC_TRANSITION_REQUIRED
ELV_ALLOC_TRANSITION_INVALID
ELV_TERMINATION_ENDPOINT_INVALID
ELV_TERMINATION_RESOURCE_INVALID
ELV_TERMINATION_DUPLICATE
```

## 22. P2 acceptance fixtures

CCTV:

```text
camera ETH/PoE connection -> WHOLE_CABLE Cat6
```

LAN:

```text
outlet rear -> patch panel rear -> WHOLE_CABLE Cat6
```

ACS:

```text
8-core Cable
reader        -> cores 1,2
door contact  -> cores 3,4
REX           -> cores 5,6
lock          -> cores 7,8
```

Overlap `[2,3]` after `[1,2]` is rejected.

Fire:

- whole-cable or explicit conductor allocation only as allowed by exact definition.

Fiber:

```text
12 fibers
link A -> 1,2
link B -> 3,4
```

overlap touching fiber 2 rejected.

Required concurrency test: competing writes attempt the same resource; exactly one may commit.

Required restart test: all selections and terminations reconstruct exactly.

---

# P3 — CableRun, traversal and route coexistence

## 23. Objective

Introduce canonical physical path realization without destroying the existing mature electrical/room-routing implementation.

P3 is the highest-risk structural phase and must be implemented as controlled coexistence/evolution, not a bulk rewrite.

## 24. CableRun domain

```text
CableRun {
  id
  projectId
  cableId
  designRevisionId
  lifecycleState
  reservePolicy/facts
  revision
  traversals[]
}
```

Invariant:

```text
at most one ACTIVE CableRun per (cableId, designRevisionId)
```

## 25. CableTraversal

```text
CableTraversal {
  id
  cableRunId
  sequence
  routeReference / routeSegmentReference
  direction
  physicalCarrierId?
  carrierCompartmentId?
  startAttachment?
  endAttachment?
}
```

Rules:

- sequence starts at 1 and is gap-free after normalization;
- traversals form one continuous physical path;
- all referenced geometry belongs to same project;
- geometry crossing does not infer connectivity;
- room/floor/riser change is a path transition, not a new CableRun;
- a Cable cannot branch silently; physical branching requires explicit termination/splice semantics and normally creates distinct downstream Cable identities.

## 26. Existing CableRoute coexistence

Current `CableRoute`, nodes and segments remain usable migration/evolution assets.

P3 must choose and document one concrete adapter strategy before schema mutation:

A. existing `CableRouteSegment` becomes reusable route infrastructure and CableTraversal references it; or
B. new reusable route infrastructure is introduced and current CableRoute is adapted/migrated incrementally.

Forbidden:

- duplicating full private geometry per every canonical CableRun merely to satisfy old schema;
- destructive migration that breaks electrical routes before adapter regression is proven.

A short P3 ADR must record the selected strategy.

## 27. P3 commands

```text
CreateCableRun
RerouteCableRun
SupersedeCableRun
ArchiveCableRun
AttachTraversalToRoute
ReplaceTraversalChain
AdoptLegacyElectricalRoute
```

### CreateCableRun

Requires Cable with no active run in the same design revision.

### RerouteCableRun

Engineer-visible atomic command:

```text
BEGIN
  load CableRun at expected revision
  build candidate ordered traversal chain
  validate continuity and project ownership
  validate route references structurally
  replace/supersede traversal set atomically
  invalidate length/occupancy/compatibility dependencies
  increment revision
COMMIT
```

Undo restores the prior valid traversal chain as one logical action.

## 28. Legacy electrical coexistence

Existing electrical routing remains operational.

`AdoptLegacyElectricalRoute` requires:

- explicit user/system adoption intent;
- sufficient physical Cable definition/identity evidence;
- stable mapping from legacy run to canonical Cable/CableRun;
- idempotent adoption record.

Ambiguous circuit data produces structured `REVIEW_REQUIRED`/blocked adoption, not an invented Cable.

## 29. P3 error codes

```text
ELV_RUN_ALREADY_ACTIVE
ELV_RUN_REVISION_CONFLICT
ELV_RUN_TRAVERSAL_EMPTY
ELV_RUN_TRAVERSAL_SEQUENCE_INVALID
ELV_RUN_TRAVERSAL_DISCONTINUITY
ELV_RUN_ROUTE_PROJECT_MISMATCH
ELV_RUN_BRANCH_NOT_EXPLICIT
ELV_LEGACY_ADOPTION_EVIDENCE_MISSING
ELV_LEGACY_ADOPTION_AMBIGUOUS
ELV_LEGACY_ADOPTION_ALREADY_EXISTS
```

## 30. P3 tests

- one Cable / one active run per design revision;
- multi-room/floor/riser path remains one CableRun;
- reroute preserves Cable/Connection identities;
- invalid discontinuity rejected;
- branch without explicit physical topology rejected;
- restart reconstructs traversal order;
- reroute undo/redo restores exact prior/new state;
- existing electrical routing regression suite remains green;
- explicit legacy adoption is idempotent;
- ambiguous adoption creates no Cable.

---

# P4 — PathwayContext, PhysicalCarrier and compartments

## 31. Objective

Represent installed physical containment facts separately from spatial pathway context.

## 32. PathwayContext

```text
PathwayContext {
  id
  projectId
  kind
  spatialHost/reference
  parentContextId?
  geometry/span reference?
  provenance
  lifecycleState
  revision
}
```

Kinds:

```text
ROOM_LOCAL
FLOOR_COMMON
CEILING_VOID
UNDERFLOOR
RISER
SHAFT
PROJECT_SHARED
```

Invalid host combinations must be rejected by typed validation.

## 33. PhysicalCarrier

```text
PhysicalCarrier {
  id
  projectId
  pathwayContextId
  code
  name
  kind
  crossSection
  usableCapacityFacts
  environmentFacts
  installationFacts
  provenance
  lifecycleState
  revision
}
```

Carrier kinds include:

```text
TRAY
BASKET_TRAY
LADDER_TRAY
CONDUIT
TRUNKING
DUCT
CUSTOM
```

`SHAFT` and `RISER` are not carrier kinds.

## 34. Compartments

```text
PhysicalCarrierCompartment {
  id
  carrierId
  code
  sequence
  crossSection/capacity facts
}
```

Traversal may reference at most one carrier/compartment target at a time.

## 35. P4 commands

```text
CreatePathwayContext
UpdatePathwayContext
ArchivePathwayContext
CreatePhysicalCarrier
UpdatePhysicalCarrier
ArchivePhysicalCarrier
CreateCarrierCompartment
UpdateCarrierCompartment
AttachTraversalToCarrier
DetachTraversalFromCarrier
```

Deletion/archive is restrictive while active traversals depend on the object.

## 36. P4 errors

```text
ELV_PATHWAY_INVALID_CONTEXT
ELV_PATHWAY_PROJECT_MISMATCH
ELV_CARRIER_INVALID_KIND
ELV_CARRIER_INVALID_DIMENSIONS
ELV_CARRIER_INVALID_CONTEXT
ELV_CARRIER_COMPARTMENT_INVALID
ELV_CARRIER_COMPARTMENT_MISMATCH
ELV_CARRIER_DEPENDENCY_BLOCKED
```

## 37. P4 acceptance

- tray inside shaft represented as `PhysicalCarrier(TRAY)` + `PathwayContext(SHAFT)`;
- conduit in room represented similarly;
- ACS multicore Cable occupying a tray counts as one physical Cable;
- several Cables may occupy one carrier;
- carrier facts survive restart;
- archive blocked while traversals reference carrier/context;
- compartment attachment survives restart.

---

# P5 — Technical physical compatibility engine

## 38. Objective

Evaluate technical physical compatibility from canonical facts without making jurisdictional/legal compliance claims.

## 39. Result contract

```text
PhysicalCompatibilityResult {
  status: OK | WARNING | FORBIDDEN | UNRESOLVED
  code
  affectedEntityIds[]
  inputFingerprint
  explanation
  sourceProfileRefs[]
}
```

The engine is deterministic and pure-domain where possible.

## 40. P5 checks

Minimum technical checks:

- Cable resource structural completeness;
- endpoint/cable medium compatibility basis;
- cable construction versus laying method;
- minimum bend-radius geometric basis;
- carrier dimensional compatibility;
- compartment target validity;
- factual environment compatibility where product/reference data supplies technical ratings;
- segregation-class basis and shared-containment technical findings;
- explicit unresolved state when required facts/rules are absent.

P5 MUST NOT claim compliance with KZ/EN/IEC/jurisdiction codes; ELV7 evaluates formal normative profiles.

## 41. P5 invalidation

Recompute only when one of these changes:

```text
Cable definition binding
allocation/resource selection
termination mapping
CableRun/traversal geometry
carrier/compartment facts
pathway context/environment facts
technical compatibility profile input
```

## 42. P5 tests

- compatible Cat6/tray scenario -> OK;
- cable too large for factual conduit -> FORBIDDEN;
- missing required carrier dimension -> UNRESOLVED;
- incompatible laying method -> FORBIDDEN;
- change unrelated Cable -> result unaffected;
- change referenced traversal -> old result becomes stale/recomputed;
- no jurisdictional compliance text emitted from P5 alone.

---

# P6 — Common physical calculations

## 43. Objective

Implement shared physical calculations consumed by multiple disciplines.

Stable process codes:

```text
ELV-ROUTE-01 cable installed length
ELV-ROUTE-02 carrier fill basis
ELV-ROUTE-03 segregation/separation basis
ELV-ROUTE-04 bend-radius compliance basis
ELV-ROUTE-05 congestion basis
ELV-ROUTE-06 service-loop/reserve allowance
```

## 44. Calculation result requirements

Every result must expose:

- process code;
- algorithm version;
- typed inputs;
- units;
- result;
- exact Cable/Run/Carrier revisions;
- reference/profile identity when used;
- structured trace/explanation;
- `CURRENT | STALE | BLOCKED | FAILED` state.

## 45. Length ownership

Installed cable length is derived from the ordered traversal geometry plus explicit run-scoped allowances.

No editable `Cable.totalLength` source of truth.

## 46. Fill basis

Fill occupancy is derived from distinct physical Cable identities traversing a carrier/compartment.

A multicore ACS Cable with four allocations counts once.

Threshold acceptance based on a jurisdictional rule belongs to ELV7; P6 computes factual/technical basis and may consume non-jurisdictional technical profile parameters where architecturally appropriate.

## 47. P6 tests

- geometry-derived length deterministic;
- reserve/allowance applied once according to contract;
- reroute changes only affected calculation;
- ACS one Cable/four allocations counted once for fill;
- two different Cables counted twice;
- restart reproduces same calculation inputs/result;
- missing facts produce BLOCKED/UNRESOLVED, not guessed defaults.

---

# P7 — Editor/application workflow

## 48. Objective

Expose the physical-routing model through one engineer-oriented workspace while keeping domain logic out of widgets.

No separate CCTV/LAN/ACS/Fire route editors.

## 49. Canonical engineer workflow

```text
select EngineeringConnection
  -> inspect physical-realization status
  -> choose existing Cable or CreateCable
  -> choose exact CableDefinition binding
  -> allocate resources
  -> map terminations
  -> create/edit CableRun
  -> build/attach traversal path
  -> attach traversal to carrier/compartment where applicable
  -> inspect technical findings
  -> inspect common physical calculations
```

The workflow must also allow starting from a Cable and tracing back to all allocated connections.

## 50. UI state progression

Recommended progressive disclosure:

```text
1 Logical connection
2 Cable identity
3 Resource allocation
4 Termination
5 Route
6 Carrier/pathway
7 Findings/calculations
```

Passive sections remain collapsed until preceding requirements are satisfied. This preserves the dry engineering-editor interaction model and avoids permanent overloaded side panels.

## 51. Required views/actions

- cable inspector;
- allocation/resource inspector;
- termination mapping inspector;
- physical route/traversal editor using existing geometry infrastructure;
- carrier/pathway inspector;
- trace endpoint-to-endpoint;
- show unresolved/blocked physical realization;
- show technical findings with affected entity highlight;
- undo/redo as logical commands;
- stale-result indicator.

## 52. UI prohibitions

- widget directly writing multiple repository tables;
- UI-only overlap validation;
- inferred cable identity from connection label;
- per-discipline duplicated route screens;
- hidden magic compatibility thresholds;
- silent creation of Cable when selecting a route.

## 53. P7 acceptance

For CCTV/LAN/ACS/Fire/fiber fixtures, an engineer can complete the physical-realization workflow using the same workspace with discipline-native labels/overlays.

Undo one reroute restores the complete prior traversal state.

Restart restores the same active editor-visible physical state.

---

# P8 — Persistence/restart vertical acceptance

## 54. Objective

Prove the whole P1–P7 model survives close/reopen and that failure injection cannot leave partial physical-realization state.

## 55. Mandatory restart fixtures

### CCTV

Camera -> PoE switch, whole Cat6 Cable, multi-traversal route, tray/wall transition.

### LAN

Outlet rear -> patch panel rear, permanent-link Cable, internal patch-panel mapping remains non-cable.

### ACS

One 8-core Cable with four allocations and explicit terminations; one physical carrier occupancy.

### Fire

ELV1 loop topology preserved; separate physical Cable sections and technical routing facts; no ELV3 normative-compliance claim.

### Fiber

12-fiber Cable with at least two independent duplex allocations and explicit fiber terminations.

After reopen verify exact IDs, definition binding, allocations, resources, terminations, run revision, traversal order, route references, carrier/context refs, calculation state and provenance.

## 56. Failure injection

Must test rollback for failures at least at:

- after Cable insert before command completion;
- after allocation row before resource atoms;
- after resource atoms before terminations;
- midway through traversal replacement;
- carrier attachment failure;
- legacy adoption failure;
- revision conflict during compound command.

Expected: no partial canonical state.

## 57. Idempotent retry

Repeat the same successful command identity after simulated lost response.

Expected:

```text
same logical result
no duplicate Cable
no duplicate allocation
no duplicate resource claim
no duplicate CableRun
no duplicate legacy adoption
```

## 58. Migration regression

All existing electrical routing tests remain green.

No global legacy electrical migration is required to open an existing project.

---

# P9 — Hard closure and exact-SHA gate

## 59. Objective

Prove the implemented ELV3 vertical matches the remediated architecture and is safe to merge.

## 60. Architecture audit checklist

Reject closure if implementation contains any of:

```text
Connection == Cable shortcut
Cable 1 -> N room-local active CableRuns
private route per CableRun as only canonical route model
parallel ELV3 catalog/version lifecycle
free-form canonical resource selectors
multi-cable continuity inferred only from ordering
shaft/riser as carrier kind
automatic circuitId -> cableId invention
ELV3 jurisdictional compliance without ELV7
UI multi-row writes bypassing commands
fill counted by allocations instead of physical Cables
```

## 61. Required CI evidence

On final branch SHA:

```text
Drift generation                      PASS
tracked generated-artifact guard      PASS
mobile formatting                     PASS
mobile analyze                        PASS
mobile tests                          PASS
engineering_core formatting           PASS
engineering_core analyze              PASS
engineering_core tests                PASS
all ELV3 restart fixtures             PASS
legacy electrical regression          PASS
```

No documentation-only or generated-code commit may be added after the final gate without rerunning exact-SHA CI.

## 62. P9 deliverables

- final architecture-vs-code audit;
- schema/migration inventory;
- test-count/evidence inventory;
- exact final SHA;
- CI links/evidence;
- known deferred risks explicitly assigned to ELV4–ELV8 or later optimization;
- roadmap status update only after exact-SHA green.

---

# 63. Execution sequence and dependency rules

```text
P1 Cable identity / exact ELV2 binding
  ↓
P2 Allocation / resources / terminations
  ↓
P3 CableRun / traversal / legacy coexistence
  ↓
P4 PathwayContext / PhysicalCarrier
  ↓
P5 Technical physical compatibility
  ↓
P6 Common physical calculations
  ↓
P7 Engineer workflow
  ↓
P8 Restart / rollback / idempotency verticals
  ↓
P9 Hard audit / exact-SHA closure
```

A later phase may prepare interfaces for the next phase but must not persist future-phase canonical entities early merely to simplify implementation.

## 64. Definition of Done for ELV3

ELV3 is complete only when:

1. five fixtures (CCTV/LAN/ACS/Fire/fiber) are physically realizable using the common model;
2. each wired connection has explicit CableAllocation or explicit non-wired status according to its semantics;
3. Cable identity is pinned to exact ELV2 reference definition;
4. resource overlaps are transactionally impossible;
5. physical terminations are reconstructable where modelled;
6. each Cable has at most one active CableRun per design revision;
7. CableRun traversals form a continuous route over reusable geometry;
8. PhysicalCarrier and PathwayContext are separately modelled;
9. length/fill/segregation/bend/congestion/service-loop basis are reproducible;
10. ELV3 technical findings are separated from ELV7 normative compliance;
11. existing electrical routing remains usable without invented Cable migration;
12. all persisted state survives restart exactly;
13. compound command failure rolls back atomically;
14. retries are idempotent;
15. undo/redo preserves valid aggregate states;
16. affected-subgraph invalidation is proven;
17. final exact-SHA CI is green.
