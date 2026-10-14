# Electra — ELV3 Implementation Specification P1–P9 v2

Status: AUTHORITATIVE IMPLEMENTATION SPECIFICATION / READY FOR EXECUTION  
Branch: `feat/flutter-elv3-physical-routing-design`  
Architecture baseline: `docs/product/elv3-p0-system-architecture-remediation.md`  
Final hardening: `docs/product/elv3-pre-p1-final-hardening.md`  
Route ADR: `docs/adr/ADR-029-elv3-reusable-route-traversal.md`  
Design revision ADR: `docs/adr/ADR-030-project-design-revision-identity.md`

## 1. Purpose and authority

This is the single executable ELV3 master specification for P1-P9. The earlier `elv3-implementation-specification.md` is superseded and MUST NOT be used as an implementation source.

P0 defines domain meaning. This v2 freezes the implementation contracts needed so that coding does not invent architecture.

Priority on conflict:

```text
v2 implementation specification
  > PRE-P1 final hardening
  > accepted ADR-029 / ADR-030 for their decision scope
  > remediated P0 contracts
  > historical first-closure ELV3 documents
```

## 2. Canonical architecture

```text
ELV1 — logical topology
EngineeringSystem
  -> TopologyGroup
  -> EngineeringConnection
  -> Port

ELV2 — exact versioned reference semantics
EngineeringReferenceCatalog(project scoped, versioned)
  -> ComponentEngineeringProfile[]
  -> CableDefinition[]
  -> PhysicalCompatibilityProfile[]

ELV3 — physical realization
EngineeringConnection
  -> CableAllocation
      -> CableResourceSelection
      -> CableTerminationMapping[]
  -> Cable
      -> CableDefinitionRef
  -> CableRun
      -> ProjectDesignRevision
      -> CableRunTraversal[]
           -> reusable CableRouteSegment
           -> optional PhysicalCarrier/compartment
  -> PathwayContext
```

Hard invariants:

1. `EngineeringConnection != Cable`.
2. one continuous wired EngineeringConnection has at most one RESERVED/ACTIVE CableAllocation and therefore at most one physical Cable in ELV3 P1-P9.
3. one Cable may serve multiple different EngineeringConnections only through non-overlapping cable resources.
4. Cable meaning is pinned to exact `CableDefinitionRef`; no latest-version lookup is allowed on restart.
5. Cable has no room, floor, circuit or editable total-length ownership.
6. one Cable has at most one ACTIVE CableRun per `ProjectDesignRevision`.
7. room/floor/riser boundaries create traversals, not additional Cable/CableRun identity.
8. one existing/evolved route graph is reused; ELV3 does not create a second geometry engine.
9. geometry crossings never infer logical or physical continuity.
10. PhysicalCarrier and PathwayContext are distinct.
11. physical occupancy counts distinct Cable identities, not CableAllocation rows.
12. legacy electrical routing remains valid until explicit evidence-based adoption.
13. ELV3 computes physical facts/intrinsic technical findings; ELV7 owns jurisdictional compliance.
14. application commands, not widget-level row mutations, are transaction boundaries.

## 3. Common implementation rules

Every phase MUST provide where applicable:

- pure domain types/validators in `engineering_core`;
- application command/service layer outside Flutter widgets;
- project-isolated repository APIs;
- Drift migration only for entities introduced in that phase;
- deterministic structured error codes;
- optimistic `revision` guard for mutable roots;
- non-empty `commandId` for replayable compound commands;
- idempotent same-command retry;
- logical undo/redo for engineer-visible mutations;
- affected-subgraph invalidation keys;
- deterministic restart tests;
- pure-Dart tests before widget tests for business logic;
- exact branch SHA with green CI before next phase.

Generated Drift files are generated only; never hand edited.

## 4. Common command result contract

```text
CommandResult<T>
  Success<T>
  ValidationFailure(code, field?, details?)
  Conflict(code, expectedRevision?, actualRevision?)
  NotFound(code, entityType, entityId)
  DependencyBlocked(code, dependentIds[])
  StorageFailure(code, causeCategory)
```

Common codes:

```text
ELV_PROJECT_MISMATCH
ELV_REVISION_CONFLICT
ELV_REFERENCE_NOT_FOUND
ELV_REFERENCE_VERSION_INVALID
ELV_DEPENDENCY_BLOCKED
ELV_IDEMPOTENCY_CONFLICT
ELV_RESTART_RECONSTRUCTION_FAILED
```

Domain validators never throw storage exceptions.

## 5. Idempotency contract

Replayable commands carry `commandId`.

Required behavior:

```text
same commandId + same normalized payload
  -> same logical result, no duplicate effects

same commandId + different normalized payload
  -> ELV_IDEMPOTENCY_CONFLICT
```

The implementation may store command outcomes or effect identities, but the behavior above is mandatory and restart-safe.

## 6. Lifecycle contracts

### Cable

```text
ACTIVE -> ARCHIVED
```

ARCHIVED is terminal in ELV3 P1-P9. `RestoreCable` is not implemented.

### CableAllocation

```text
DRAFT -> RESERVED -> ACTIVE -> RELEASED -> ARCHIVED
```

Additional permitted cancellation transitions only:

```text
DRAFT    -> ARCHIVED
RESERVED -> RELEASED
```

No other direct transition is valid.

Only RESERVED and ACTIVE consume resources.

### CableRun

```text
ACTIVE -> SUPERSEDED -> ARCHIVED
```

At most one ACTIVE run per `(cableId, designRevisionId)`.

### ProjectDesignRevision

```text
WORKING -> FROZEN -> SUPERSEDED -> ARCHIVED
```

An abandoned WORKING revision may go directly to ARCHIVED. Exactly one WORKING revision exists per project.

## 7. Canonical dependency keys

```text
cable:<id>
allocation:<id>
cable-run:<id>
design-revision:<id>
route:<id>
route-segment:<id>
carrier:<id>
pathway-context:<id>
connection:<id>
reference-catalog:<id>
reference-cable-definition:<catalogId>/<version>/<code>
```

Commands return/publish affected keys. UI does not infer dependency impact.

---

# P1 — Cable identity and exact ELV2 CableDefinition reference

## 8. Objective

Introduce project-owned physical Cable identity and exact versioned CableDefinition provenance without allocation or routing persistence.

## 9. ELV2 catalog extension

P1 evolves the existing `EngineeringReferenceCatalog` payload; it does not create another catalog table.

Canonical shape:

```text
EngineeringReferenceCatalog {
  id
  code
  version
  source
  jurisdiction?
  componentProfiles[]
  cableDefinitions[]
  physicalCompatibilityProfiles[]
  vocabulary
}
```

Existing component profile behavior remains backward-compatible.

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

Rules:

- normalized code is unique within one catalog edition;
- published definition content is immutable inside that edition;
- validation rejects negative/non-finite dimensional facts;
- resource definitions are deterministic and stable within the exact edition.

## 10. CableDefinitionRef

```text
CableDefinitionRef {
  catalogId
  catalogVersion
  definitionCode
  definitionContentHash
}
```

The hash is deterministic over canonical serialized CableDefinition content.

Resolution algorithm:

```text
load EngineeringReferenceCatalog by catalogId and projectId
require catalog.version == ref.catalogVersion
resolve cableDefinitions[normalized definitionCode]
recompute canonical content hash
require hash == ref.definitionContentHash
return exact definition
```

No component reference binding is involved.

## 11. Cable domain

```text
Cable {
  id
  projectId
  label
  name
  definitionRef
  lifecycleState
  revision
}
```

Rules:

- `id` stable and project-scoped;
- label required;
- comparison normalization = trim + uppercase;
- active/non-archived label unique per project;
- exact definitionRef mandatory;
- no room/floor/circuit fields;
- no editable calculated total length;
- no manufacturer SKU as canonical definition identity.

## 12. P1 commands

```text
CreateCable
ChangeCableDefinitionRef
ArchiveCable
```

### CreateCable input

```text
commandId
projectId
cableId
label
name
definitionRef
```

Process:

```text
BEGIN
  validate non-empty commandId / payload id
  load project
  resolve exact CableDefinitionRef
  normalize and validate label
  check non-archived project label uniqueness
  idempotency check
  insert Cable revision=1 ACTIVE
COMMIT
```

### ChangeCableDefinitionRef

P1 permits change only while Cable has no CableAllocation and no CableRun. From P2 onward command revalidates all dependent resource semantics or rejects change.

### ArchiveCable

Blocked while RESERVED/ACTIVE allocations or ACTIVE CableRun exist. Archived Cable cannot be restored in ELV3 P1-P9.

## 13. P1 persistence

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

No `CableDefinitionBindings` table is introduced.

## 14. P1 errors

```text
ELV_CABLE_MISSING_IDENTITY
ELV_CABLE_LABEL_EMPTY
ELV_CABLE_LABEL_DUPLICATE
ELV_CABLE_DEFINITION_REF_MISSING
ELV_CABLE_DEFINITION_PROJECT_MISMATCH
ELV_CABLE_DEFINITION_VERSION_MISMATCH
ELV_CABLE_DEFINITION_NOT_FOUND
ELV_CABLE_DEFINITION_HASH_MISMATCH
ELV_CABLE_DEFINITION_CHANGE_BLOCKED
ELV_CABLE_ARCHIVE_BLOCKED
```

## 15. P1 tests and exit

Mandatory:

- catalog with cableDefinitions round-trips without breaking component profiles;
- valid Cable create;
- foreign catalog rejected;
- wrong catalog version rejected;
- unknown definition code rejected;
- hash mismatch rejected;
- later catalog version does not alter existing Cable meaning;
- duplicate active label rejected case-insensitively after trim;
- idempotent CreateCable retry;
- same commandId/different payload conflict;
- restart reconstructs identical definitionRef and exact definition;
- CCTV Cat6, LAN Cat6, ACS 8-core, fire-resistant, 12-fiber definitions resolve.

P1 gate: format/analyze/tests + Drift generation + restart + exact-SHA green. No P2/P3 schema allowed.

---

# P2 — CableAllocation, resource claims and terminations

## 16. Objective

Realize ELV1 EngineeringConnections through typed, concurrency-safe Cable resources.

## 17. Cable resources

```text
CableResourceDefinition {
  identity
  kind
  index?
  addressable
  groupMembership[]
  metadata
}
```

Standard kinds:

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

No arbitrary runtime string is accepted as sole canonical identity.

Selections:

```text
sealed CableResourceSelection
  WholeCableSelection
  ResourceSetSelection(resourceIdentities[])
  DefinitionGroupSelection(groupIdentity)
```

Every selection resolves to sorted unique atomic definition resource identities.

Reserved whole-cable atom identity:

```text
__WHOLE_CABLE__
```

## 18. CableAllocation

```text
CableAllocation {
  id
  projectId
  engineeringConnectionId
  cableId
  lifecycleState
  revision
}
```

No `transitionRef` exists in ELV3 P1-P9.

Hard policy:

```text
one continuous wired EngineeringConnection
  -> at most one RESERVED/ACTIVE CableAllocation
  -> one Cable
```

Attempt to reserve/activate another Cable for the same connection is rejected with `ELV_ALLOC_MULTI_CABLE_NOT_SUPPORTED`.

Multiple different connections may share one Cable if resource sets do not overlap.

## 19. Termination mapping

```text
CableTerminationMapping {
  id
  allocationId
  cableResourceIdentity
  endRole: A | B
  endpointPortId
  endpointTerminalRef?
  terminationRole?
}
```

`INTERMEDIATE` is not supported until an explicit CableTransition model exists.

Rules:

- A maps only to connection `fromPortId`;
- B maps only to connection `toPortId`;
- both ports belong to same project/allocation connection;
- one resource end cannot have two incompatible terminations;
- mapping never creates logical topology.

## 20. Strict P2 commands

```text
CreateCableAllocationDraft
ReserveCableResources
ActivateCableAllocation
ReleaseCableResources
ArchiveCableAllocation
BindCableTermination
ReplaceCableTermination
```

Convenience `AllocateCableResources` is permitted only as atomic `CreateDraft + Reserve` and commits RESERVED.

### ReserveCableResources

```text
BEGIN
  load DRAFT allocation at expected revision
  load Connection + Cable + exact CableDefinitionRef
  validate project equality
  reject another RESERVED/ACTIVE allocation for same connection on different Cable
  resolve normalized resource atoms
  load consuming claims for Cable
  if WHOLE_CABLE: require no consuming claim exists
  else: require no __WHOLE_CABLE__ claim and no atom overlap
  insert one claim row per atom
  state DRAFT -> RESERVED
  revision++
COMMIT
```

### ActivateCableAllocation

Requires RESERVED and structurally valid required terminations for the connection/definition. Transition RESERVED -> ACTIVE.

### ReleaseCableResources

RESERVED or ACTIVE -> RELEASED and frees consuming claim rows in the same transaction while preserving allocation/termination history.

## 21. P2 persistence

```text
CableAllocations
- id
- project_id
- engineering_connection_id
- cable_id
- lifecycle_state
- revision/audit

CableAllocationResources
- allocation_id
- cable_id
- definition_resource_identity
- claim_key

CableTerminationMappings
- id
- allocation_id
- cable_resource_identity
- end_role
- endpoint_port_id
- endpoint_terminal_ref?
- termination_role?
- audit/revision as required
```

`claim_key = <cableId>|<definitionResourceIdentity>` and is unique while present.

Application pre-check alone is insufficient; claim checks and inserts occur in one database transaction.

## 22. P2 errors

```text
ELV_ALLOC_INVALID_STATE_TRANSITION
ELV_ALLOC_CONNECTION_NOT_FOUND
ELV_ALLOC_CABLE_NOT_FOUND
ELV_ALLOC_PROJECT_MISMATCH
ELV_ALLOC_RESOURCE_UNKNOWN
ELV_ALLOC_RESOURCE_NOT_ADDRESSABLE
ELV_ALLOC_RESOURCE_OVERLAP
ELV_ALLOC_WHOLE_CABLE_CONFLICT
ELV_ALLOC_DUPLICATE_CLAIM
ELV_ALLOC_MULTI_CABLE_NOT_SUPPORTED
ELV_TERMINATION_ENDPOINT_INVALID
ELV_TERMINATION_RESOURCE_INVALID
ELV_TERMINATION_DUPLICATE
ELV_TERMINATION_INCOMPLETE
```

## 23. P2 acceptance

- CCTV whole Cat6;
- LAN whole Cat6;
- ACS one 8-core Cable: reader 1/2, contact 3/4, REX 5/6, lock 7/8;
- fiber duplex allocations 1/2 and 3/4;
- overlap rejected;
- WHOLE_CABLE vs partial rejected both directions;
- same connection second Cable rejected;
- competing same-resource writes: exactly one commits;
- strict lifecycle transition tests;
- restart reconstructs resources/terminations exactly.

P2 exact-SHA must be green before P3.

---

# P3 — ProjectDesignRevision, CableRun and reusable traversal routing

## 24. Objective

Introduce canonical physical path realization using the existing routing graph through ADR-029, while preserving legacy electrical routing.

## 25. ProjectDesignRevision

P3 first introduces `ProjectDesignRevisions` exactly as ADR-030.

```text
ProjectDesignRevision {
  id
  projectId
  code
  sequence
  state
  basedOnRevisionId?
  revision
}
```

Existing projects receive one persisted bootstrap WORKING revision idempotently.

`Projects.revision` is never used as designRevisionId.

## 26. CableRun

```text
CableRun {
  id
  projectId
  cableId
  designRevisionId
  lifecycleState
  reservePercent
  terminationAllowanceMm
  revision
}
```

Hard invariant: max one ACTIVE per `(cableId, designRevisionId)`.

## 27. CableRunTraversal

```text
CableRunTraversal {
  id
  cableRunId
  sequence
  routeSegmentId
  direction: FORWARD | REVERSE
  physicalCarrierId?
  carrierCompartmentId?
}
```

Sequence starts at 1 and is gap-free.

Continuity is valid only when adjacent traversal endpoint nodes are identical after applying direction, or one explicit accepted routing handoff connects them. Coordinate equality alone does not prove continuity.

Room/floor/riser transitions are traversals/handoffs, never additional CableRuns.

Cable branching is rejected in P3; branch topology requires future explicit transition/termination semantics.

## 28. Route strategy — frozen

Only ADR-029 strategy is permitted:

```text
existing CableRoute/Node/Segment graph
  -> evolved/reused as route infrastructure

CableRun
  -> CableRunTraversal[]
      -> CableRouteSegment
```

No option B, no second ELV route graph, no private geometry clone per canonical run.

Legacy electrical rows keep `circuitId` and `routeId`; adapter exposes their route segments as a traversal-compatible read model.

## 29. P3 commands

```text
CreateCableRun
RerouteCableRun
SupersedeCableRun
ArchiveCableRun
ReplaceTraversalChain
AdoptLegacyElectricalRoute
```

`AttachTraversalToRoute` is not a separate partial-write command; traversal chain replacement is atomic.

### RerouteCableRun

```text
BEGIN
  load ACTIVE CableRun at expected revision
  require its design revision is WORKING
  build complete candidate traversal chain
  validate segment project ownership
  validate sequence + directional continuity + explicit handoffs
  replace traversal rows atomically
  revision++
  return affected dependency keys
COMMIT
```

Undo stores/restores the prior complete valid traversal chain as one logical command.

### AdoptLegacyElectricalRoute

Requires explicit intent, exact CableDefinitionRef, target Cable identity and evidence that the legacy route describes that physical Cable. Ambiguity returns blocked/review-required and creates no Cable/Run.

## 30. P3 persistence

```text
ProjectDesignRevisions
CanonicalCableRuns
CableRunTraversals
LegacyRouteAdoptions
```

Canonical tables may use exact final names selected to avoid collision with legacy `CableRuns`, but semantics above are fixed. A destructive rename/reuse of the legacy table before regression proof is forbidden.

`LegacyRouteAdoptions` unique legacy source identity makes adoption idempotent.

## 31. P3 errors/tests

Codes:

```text
ELV_DESIGN_REVISION_INVALID_STATE
ELV_DESIGN_REVISION_BOOTSTRAP_CONFLICT
ELV_RUN_ALREADY_ACTIVE
ELV_RUN_REVISION_CONFLICT
ELV_RUN_TRAVERSAL_EMPTY
ELV_RUN_TRAVERSAL_SEQUENCE_INVALID
ELV_RUN_TRAVERSAL_DISCONTINUITY
ELV_RUN_ROUTE_PROJECT_MISMATCH
ELV_RUN_BRANCH_NOT_SUPPORTED
ELV_LEGACY_ADOPTION_EVIDENCE_MISSING
ELV_LEGACY_ADOPTION_AMBIGUOUS
ELV_LEGACY_ADOPTION_ALREADY_EXISTS
```

Tests include bootstrap restart idempotency, one run/revision, multi-room/floor/riser one run, reroute, undo/redo, discontinuity, crossing-not-continuity, legacy electrical regression, adoption idempotency and ambiguous adoption no-write.

---

# P4 — sealed PathwayContext, PhysicalCarrier and compartments

## 32. PathwayContext

```text
PathwayContext {
  id
  projectId
  kind
  host
  parentContextId?
  provenance
  lifecycleState
  revision
}
```

Closed host hierarchy:

```text
RoomHost(roomId)
FloorHost(floorId)
SurfaceVoidHost(floorId, spatialFeatureId)
VerticalHost(fromFloorId, toFloorId, spatialFeatureId?)
ProjectHost(projectId)
```

Mandatory mapping:

```text
ROOM_LOCAL     -> RoomHost
FLOOR_COMMON   -> FloorHost
CEILING_VOID   -> SurfaceVoidHost
UNDERFLOOR     -> SurfaceVoidHost
RISER          -> VerticalHost
SHAFT          -> VerticalHost
PROJECT_SHARED -> ProjectHost
```

No other kind/host combination is valid.

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

Kinds:

```text
TRAY
BASKET_TRAY
LADDER_TRAY
CONDUIT
TRUNKING
DUCT
CUSTOM
```

RISER/SHAFT are never carrier kinds.

Compartments are carrier-owned children with stable id/code/sequence and factual cross-section/capacity.

A traversal references either carrier as a whole or one compartment of that same carrier. Compartment mismatch is invalid.

## 34. P4 persistence

```text
PathwayContexts
- explicit host_type + typed nullable FK columns per hardening contract

PhysicalCarriers
PhysicalCarrierCompartments
```

No generic `spatialHostJson` is authoritative identity.

Archive/delete is restrictive while active traversal dependencies exist.

## 35. P4 acceptance

- tray in shaft = TRAY + VerticalHost/SHAFT;
- conduit in room = CONDUIT + RoomHost;
- vertical riser spans floors without fake room;
- invalid host combinations rejected;
- ACS four allocations/one Cable occupies carrier once;
- several Cables share carrier;
- compartment/restart/dependency guards pass.

---

# P5 — technical physical compatibility

## 36. Profile ownership

P5 reads `PhysicalCompatibilityProfile` from exact ELV2 `EngineeringReferenceCatalog` editions.

It MUST NOT silently reinterpret existing `EngineeringCompatibilityProfiles` rows, which remain ELV1 logical connection compatibility unless a separate future migration explicitly changes them.

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

## 37. Result

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

Input fingerprint includes exact CableDefinitionRef, relevant PhysicalCompatibilityProfile edition/hash, allocation/termination revisions, traversal geometry revisions and carrier/pathway revisions.

## 38. P5 checks

P5 owns intrinsic/factual technical checks only:

- resource structural completeness;
- endpoint/cable medium technical compatibility;
- construction vs laying-method intrinsic compatibility;
- minimum bend radius from exact definition/manufacturer-independent engineering reference;
- dimensional impossibility in carrier/compartment;
- environment rating vs factual environment;
- shared-containment facts required for later normative segregation evaluation;
- UNRESOLVED when required technical facts are missing.

P5 does not apply jurisdictional required separation, legal fill limits or formal fire-code acceptance.

Tests must prove no KZ/EN/IEC compliance claim is emitted by P5 alone.

---

# P6 — common physical calculations/evidence

## 39. Stable process codes

```text
ELV-ROUTE-01 installed cable length
ELV-ROUTE-02 carrier occupancy/fill factual basis
ELV-ROUTE-03 segregation evidence basis
ELV-ROUTE-04 bend-radius intrinsic technical basis
ELV-ROUTE-05 congestion factual basis
ELV-ROUTE-06 service-loop/reserve allowance
```

Every result contains process code, algorithm version, typed inputs, units, result, exact entity revisions, exact reference/profile refs, trace and `CURRENT | STALE | BLOCKED | FAILED`.

## 40. Ownership boundaries

Installed length = ordered traversal geometry + explicit run allowances. No editable `Cable.totalLength`.

Carrier occupancy counts distinct Cable ids on the carrier/compartment, never allocations.

`ELV-ROUTE-03` reports facts such as actual distance, shared compartment and barrier presence. It does NOT compare against a jurisdictional required distance.

P6 may apply only intrinsic physical limits from exact reference definitions/profiles. Jurisdictional thresholds are ELV7 inputs.

Tests must include ACS one-Cable/four-allocation occupancy count=1, two Cables count=2, deterministic reroute invalidation and missing-fact BLOCKED behavior.

---

# P7 — engineer workspace/application workflow

## 41. Canonical workflow

One shared Physical Routing workspace:

```text
select EngineeringConnection
  -> physical realization status
  -> choose/create Cable
  -> exact CableDefinitionRef
  -> create DRAFT allocation
  -> reserve resources
  -> map A/B terminations
  -> activate allocation
  -> create/edit CableRun in current WORKING ProjectDesignRevision
  -> build complete traversal chain on existing route graph
  -> attach carrier/compartment
  -> inspect technical findings
  -> inspect common physical evidence/calculations
```

Reverse trace from Cable to all allocated EngineeringConnections is mandatory.

Progressive side-panel stages:

```text
1 Logical connection
2 Cable
3 Allocation/resource
4 Termination
5 Route/traversal
6 Carrier/pathway
7 Findings/calculations
```

No per-discipline route editors.

Widgets never perform multi-table domain writes directly. They dispatch application commands and render typed outcomes.

Undo/redo works at logical command level; reroute undo restores complete previous traversal chain.

---

# P8 — vertical persistence/restart/failure acceptance

## 42. Five mandatory fixtures

CCTV: camera -> PoE switch, whole Cat6, multi-traversal route, carrier transition.

LAN: outlet rear -> patch-panel rear permanent link; InternalConnectivity remains non-cable.

ACS: one 8-core Cable, four non-overlapping allocations, A/B terminations, one carrier occupancy.

Fire: ELV1 loop preserved, physical Cable sections represented without ELV3 normative claim.

Fiber: 12-fiber Cable, at least two duplex allocations, exact terminations.

After reopen verify exact ids, CableDefinitionRef/hash, allocation states/resources, terminations, designRevisionId, active/superseded run identity, traversal order/direction/segment refs, carrier/pathway refs, derived-state fingerprints and provenance.

## 43. Failure injection

Mandatory rollback points:

- Cable insert before command completion;
- allocation DRAFT before reservation;
- partial resource claim insertion;
- terminations before activation;
- traversal replacement midpoint;
- carrier attachment;
- design-revision bootstrap/create conflict;
- legacy adoption;
- optimistic revision conflict.

No partial canonical state may remain.

Lost-response retry with same commandId must create no duplicates. Same commandId/different payload must conflict.

All legacy electrical routing tests remain green. Existing project opens without global Cable migration.

---

# P9 — hard closure / exact-SHA

## 44. Architecture rejection list

P9 FAILS if implementation contains any of:

```text
Connection == Cable shortcut
second RESERVED/ACTIVE Cable for one continuous connection
Cable 1 -> N room-local active CableRuns in one design revision
Projects.revision used as designRevisionId
second ELV route graph
private copied geometry per canonical CableRun
parallel ELV3 catalog lifecycle
ComponentReferenceBinding reused as Cable binding
free-form canonical cable resource selector
arbitrary CableAllocation state skipping
transitionRef without typed transition model
shaft/riser as carrier kind
open generic PathwayContext host identity
automatic circuitId -> cableId invention
existing logical EngineeringCompatibilityProfiles silently repurposed for P5
ELV3 jurisdictional threshold/compliance claim
UI direct multi-table writes
carrier occupancy counted by allocations
```

## 45. Required final evidence

On the exact final SHA:

```text
Drift generation                      PASS
tracked generated-artifact guard      PASS
mobile formatting                     PASS
mobile analyze                        PASS
mobile tests                          PASS
engineering_core formatting           PASS
engineering_core analyze              PASS
engineering_core tests                PASS
five ELV3 vertical restart fixtures   PASS
failure injection                     PASS
idempotent retry                      PASS
legacy electrical regression          PASS
architecture-vs-code audit            PASS
```

Any commit after this gate requires rerunning exact-SHA CI.

P9 deliverables: final SHA, CI evidence, schema/migration inventory, test inventory, architecture-vs-code audit and explicitly assigned deferred work.

---

# 46. Phase sequence

```text
P1 exact Cable identity/reference
  ↓ exact-SHA
P2 allocation/resources/terminations
  ↓ exact-SHA
P3 design revision/run/traversal/coexistence
  ↓ exact-SHA
P4 pathway/carrier
  ↓ exact-SHA
P5 technical compatibility
  ↓ exact-SHA
P6 common physical evidence/calculations
  ↓ exact-SHA
P7 engineer workflow
  ↓ exact-SHA
P8 vertical restart/failure acceptance
  ↓ exact-SHA
P9 final hard closure
```

A phase may declare interfaces for the next phase but MUST NOT persist future-phase canonical entities early.

## 47. ELV3 Definition of Done

ELV3 is complete only when all are true:

1. exact CableDefinitionRef resolves deterministically after restart;
2. no independent ELV3 catalog lifecycle exists;
3. resource overlap and WHOLE_CABLE conflicts are transactionally impossible;
4. one continuous connection cannot silently use multiple Cables;
5. terminations reconstruct exactly;
6. ProjectDesignRevision identity is stable and distinct from optimistic counters;
7. max one ACTIVE CableRun per Cable/design revision;
8. traversal chain uses the one existing/evolved route graph and is continuous by canonical nodes/handoffs;
9. PhysicalCarrier/PathwayContext are separately typed;
10. sealed pathway host invariants hold;
11. P5 profile ownership is exact and does not repurpose logical compatibility rows;
12. P6 segregation output is evidence, not jurisdictional compliance;
13. length/fill/bend/congestion/reserve evidence is reproducible;
14. legacy electrical routing remains usable without invented Cable migration;
15. five discipline/media fixtures survive restart exactly;
16. failure injection leaves no partial state;
17. retry is idempotent and payload conflicts are detected;
18. undo/redo preserves valid aggregate states;
19. affected-subgraph invalidation is proven;
20. final exact-SHA CI and architecture audit are green.
