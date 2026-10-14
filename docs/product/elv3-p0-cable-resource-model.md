# Electra — ELV3 P0.3 Cable Resource Model

Status: DESIGN CONTRACT / P0.3  
Branch: `feat/flutter-elv3-physical-routing-design`  
Depends on: `docs/product/elv3-p0-ownership-cardinality-contract.md`  
Implementation status: NOT STARTED

## 1. Purpose

P0.3 freezes the physical resource model used by `CableAllocation` before persistence or implementation begins.

The objective is to answer precisely:

1. Which parts of a physical `Cable` are addressable resources?
2. How does an allocation select those resources?
3. When do two allocations overlap?
4. Which overlaps are forbidden?
5. How are multi-core, paired-copper and fiber cables represented without discipline-specific code?
6. How can one logical connection use more than one cable deterministically?

This document does not define route geometry, pathway dimensions, PoE, voltage drop, optical loss or discipline calculations.

## 2. Upstream invariants

P0.3 inherits the following frozen decisions:

```text
EngineeringConnection != Cable
EngineeringConnection -> CableAllocation -> Cable
Cable 1 -> N CableRun
CableRun 1 -> 1 CableRoute
```

A physical cable may carry multiple independent logical connections only through explicit `CableAllocation` records.

`CableAllocation` is therefore the only canonical relation between logical topology and physical cable resources.

## 3. Canonical resource kinds

ELV3 defines the following resource kinds:

```text
WHOLE_CABLE
PAIR
CONDUCTOR
FIBER
CORE_GROUP
```

These values describe physical resource addressability, not engineering discipline.

No values such as `CCTV_PAIR`, `ACS_CORE`, `FIRE_LOOP`, `LAN_PAIR` or similar discipline-specific resource types are permitted.

## 4. Resource-kind semantics

### 4.1 WHOLE_CABLE

`WHOLE_CABLE` means the allocation consumes the cable as one indivisible resource.

Typical use cases:

- LAN permanent link on a four-pair balanced copper cable;
- CCTV camera Ethernet/PoE cable;
- simple two-core fire cable where internal conductor assignment is intentionally not modelled separately;
- coaxial cable;
- preterminated assembly treated as one installed cable resource.

Canonical rule:

```text
if active WHOLE_CABLE allocation exists
then no other active allocation may consume any sub-resource of that Cable
```

Similarly, a `WHOLE_CABLE` allocation cannot be created while any active partial allocation exists.

### 4.2 PAIR

`PAIR` addresses explicitly numbered pairs.

Example:

```text
pair 1
pair 2
pair 3
pair 4
```

A pair is an atomic allocation resource for P0.3. Allocation of `PAIR 1` consumes the pair as a unit.

P0.3 does not allow another allocation to consume individual conductors inside an already allocated pair unless a future cable-definition model explicitly declares independent conductor addressability for that construction. Mixed pair/conductor addressing is therefore forbidden by default.

### 4.3 CONDUCTOR

`CONDUCTOR` addresses individually numbered insulated conductors/cores.

Example:

```text
core 1
core 2
core 3
...
core 8
```

This is the primary model for ACS and other multicore control cables.

Each conductor is atomic for overlap validation.

### 4.4 FIBER

`FIBER` addresses individually numbered optical fibers.

Example:

```text
fiber 1
fiber 2
fiber 3
...
```

P0.3 models only physical allocation. Tx/Rx direction, optical budget, connector loss and wavelength calculations belong to later phases.

### 4.5 CORE_GROUP

`CORE_GROUP` is a named group explicitly declared by the exact `CableDefinition`.

It is NOT an arbitrary runtime range alias.

Examples where a definition may expose a group:

```text
POWER_PAIR
SIGNAL_PAIR
SHIELDED_PAIR_A
QUAD_1
BUNDLE_1
```

Canonical rule:

```text
CORE_GROUP must resolve deterministically to a finite set of atomic resources
```

A group is valid only when its membership is part of the exact cable-definition edition/provenance.

This prevents `CORE_GROUP` from becoming an escape hatch that bypasses overlap validation.

## 5. Atomic resource space

Every `CableDefinition` that supports partial allocation must expose a deterministic atomic resource space.

Conceptually:

```text
CableResourceSpace {
  allocationMode
  atomicResources[]
  declaredGroups[]
}
```

Examples:

### 5.1 Four-pair balanced copper cable

```text
atomic resources:
  PAIR:1
  PAIR:2
  PAIR:3
  PAIR:4
```

If the cable is intended to be treated only as a complete permanent-link cable, the definition may expose only:

```text
WHOLE_CABLE
```

The application must not invent lower-level addressability absent from the exact definition.

### 5.2 Eight-core multicore cable

```text
CONDUCTOR:1
CONDUCTOR:2
CONDUCTOR:3
CONDUCTOR:4
CONDUCTOR:5
CONDUCTOR:6
CONDUCTOR:7
CONDUCTOR:8
```

Optional definition-owned groups may resolve to these conductors.

### 5.3 Twelve-fiber cable

```text
FIBER:1 ... FIBER:12
```

## 6. CableResourceSelector

`CableAllocation` MUST use a typed selector. Raw comma-separated strings such as `"1,2,4-6"` are forbidden as canonical domain state.

Conceptual contract:

```text
sealed CableResourceSelector

WholeCableSelector

IndexedResourceSelector {
  kind: PAIR | CONDUCTOR | FIBER
  indexes: non-empty sorted unique positive integers
}

NamedGroupSelector {
  groupCode: stable definition-owned identifier
}
```

The persisted representation may differ, but the reconstructed domain state must be equivalent to this typed model.

## 7. Selector normalization

Every selector must normalize before validation/persistence.

Examples:

```text
[4,2,2,1] -> [1,2,4]
```

Invalid selectors include:

```text
[]
[0]
[-1]
PAIR indexes on a conductor-only definition
FIBER selector on copper definition
unknown groupCode
WHOLE_CABLE plus indexes in one selector
```

Normalization is deterministic and must not silently substitute missing resources.

## 8. CableAllocation contract

Canonical conceptual fields:

```text
CableAllocation {
  id
  projectId
  engineeringConnectionId
  cableId
  selector
  sequence
  role
  lifecycleStatus
}
```

### 8.1 `engineeringConnectionId`

Required. References exactly one ELV1 `EngineeringConnection`.

### 8.2 `cableId`

Required. References exactly one installed `Cable`.

### 8.3 `selector`

Required. References resources exposed by the exact `CableDefinition` bound to the cable.

### 8.4 `sequence`

Required positive integer within one connection when that connection has multiple cable allocations.

Default single-allocation case:

```text
sequence = 1
```

For a multi-cable realization:

```text
Connection C1
  A1 cable C-001 sequence 1
  A2 cable C-002 sequence 2
```

Duplicate active sequence numbers for the same connection are forbidden.

### 8.5 `role`

Role is descriptive physical realization metadata, not discipline identity.

Candidate values:

```text
PRIMARY
CONTINUATION
SPLICE_SECTION
TRANSITION_SECTION
REDUNDANT
CUSTOM
```

P0.3 does not use role to infer connectivity. Sequence and explicit topology/termination facts remain authoritative.

## 9. Canonical overlap model

All selectors must resolve to a canonical consumed resource set.

Conceptually:

```text
resolve(selector, cableDefinition) -> Set<ResourceAtom>
```

Examples:

```text
WholeCableSelector -> { WHOLE_CABLE }
Conductor[1,2] -> { CONDUCTOR:1, CONDUCTOR:2 }
Pair[2] -> { PAIR:2 }
NamedGroup(READER) -> { CONDUCTOR:1, CONDUCTOR:2 }
```

Overlap is evaluated only after group resolution.

## 10. Double-allocation rules

### R1 — WHOLE_CABLE exclusivity

If one active allocation consumes `WHOLE_CABLE`, no other active allocation may exist on that cable.

### R2 — atomic intersection forbidden

Two active allocations on the same cable are incompatible when their resolved atomic resource sets intersect.

```text
A.resources ∩ B.resources != empty
  -> FORBIDDEN
```

### R3 — exact duplicate is also forbidden

Two allocations must not consume the same resource set even if they reference the same logical connection.

Retries must resolve through idempotency at the command/repository layer, not by allowing duplicate rows.

### R4 — cross-connection overlap forbidden

Different `EngineeringConnection` records cannot consume the same atomic resource concurrently.

### R5 — same-connection overlap also forbidden

One connection cannot duplicate-consume the same resources through several allocations.

### R6 — mixed addressability forbidden unless definition explicitly supports it

Example forbidden by default:

```text
PAIR:1
and
CONDUCTOR:1
```

when conductor 1 physically belongs to pair 1.

The resource model must have one unambiguous atomic addressability scheme per resource family in an exact cable definition.

### R7 — archived/released allocation does not consume capacity

Only lifecycle states defined as active/reserved consume resources.

Deletion semantics are finalized in P0.5, but overlap validation must depend on explicit lifecycle state rather than physical row presence alone.

## 11. Resource capacity invariants

For an indexed selector:

```text
1 <= index <= definition.resourceCount(kind)
```

Unknown resources are invalid, not `UNRESOLVED`, when the cable definition itself is complete and the index is out of range.

`UNRESOLVED` is appropriate only when required source facts are missing or unavailable, not when an explicit invalid index is supplied.

## 12. Allocation compatibility boundary

P0.3 separates two classes of checks.

### Structural allocation validity

Deterministic domain invariant:

- referenced cable exists;
- exact definition exists;
- resource kind exists in definition;
- indexes/groups resolve;
- no overlap;
- sequence valid;
- project isolation holds.

Failure means the allocation must not be committed.

### Engineering compatibility

Later compatibility engine responsibility:

- endpoint medium compatibility;
- shielding requirements;
- fire class suitability;
- environment suitability;
- segregation;
- pathway fill;
- bend radius;
- installation constraints.

These may produce `COMPATIBLE/WARNING/FORBIDDEN/UNRESOLVED` findings but must not be confused with malformed resource selectors.

## 13. Allocation status proposal

P0.3 requires lifecycle semantics sufficient to distinguish resource consumption.

Candidate state machine:

```text
DRAFT
  -> RESERVED
  -> ACTIVE
  -> RELEASED
  -> ARCHIVED
```

Resource-consuming states:

```text
RESERVED
ACTIVE
```

Non-consuming states:

```text
DRAFT
RELEASED
ARCHIVED
```

Exact lifecycle transitions are finalized in P0.5. Until then, implementation must not invent alternative status meaning.

## 14. Project isolation

All allocation validation must be project-safe.

Canonical rule:

```text
connection.projectId == cable.projectId == allocation.projectId
```

Cross-project allocation is a hard failure.

A selector cannot refer to a cable-definition instance/provenance belonging to another project/catalog context through accidental IDs.

## 15. CableDefinition implications

P0.3 imposes the following requirements on P1 `CableDefinition`.

A definition must be able to declare:

```text
allocationCapability:
  WHOLE_ONLY
  INDEXED_PAIRS
  INDEXED_CONDUCTORS
  INDEXED_FIBERS
  DECLARED_GROUPS
  combinations explicitly allowed by definition
```

It must also expose exact resource counts and group membership where applicable.

The application must never derive pair/conductor/fiber count from product name text.

## 16. Four-discipline acceptance

### 16.1 CCTV — PASS

Typical camera Ethernet/PoE cable:

```text
Connection CAMERA-ETH-01
  -> Allocation
     cable = CCTV-001
     selector = WHOLE_CABLE
     sequence = 1
```

Expected:

- no partial allocation may coexist on `CCTV-001`;
- PoE budget is outside P0.3/ELV3;
- physical route is independent of allocation selector.

### 16.2 LAN — PASS

Permanent link:

```text
Outlet.REAR -> PatchPanel.REAR
Allocation:
  cable = LAN-001
  selector = WHOLE_CABLE
```

Expected:

- internal patch-panel connectivity does not allocate another cable;
- no pair-level resource splitting is inferred unless an exact cable definition explicitly allows that engineering use case.

### 16.3 ACS — PASS

Eight-core cable:

```text
Cable ACS-001
CONDUCTOR:1..8

Reader        -> [1,2]
Door contact  -> [3,4]
REX           -> [5,6]
Lock          -> [7,8]
```

Expected valid state:

```text
{1,2} ∩ {3,4} = empty
{1,2} ∩ {5,6} = empty
...
```

Expected invalid state:

```text
Reader -> [1,2]
Lock   -> [2,3]

intersection = {2}
-> allocation commit rejected
```

This is the mandatory P0.3 anti-regression fixture.

### 16.4 Fire — PASS

Two valid modelling modes are possible depending on exact cable definition:

```text
WHOLE_CABLE
```

or, when individual cores are intentionally engineered:

```text
CONDUCTOR indexes
```

The system must use the exact definition capability and may not switch addressing modes heuristically.

Fire loop semantics remain ELV1 topology. P0.3 models only physical resource consumption.

## 17. Fiber acceptance extension

Although the four mandatory acceptance disciplines do not require fiber, P0.3 must prove genericity.

Example:

```text
Cable F-001 / 12 fibers

Connection A -> fibers [1,2]
Connection B -> fibers [3,4]
```

Overlapping allocation `[2,5]` must be rejected because fiber 2 is already consumed.

This fixture prevents the model from being accidentally copper-only.

## 18. Invalid designs explicitly rejected

The following representations are forbidden as canonical domain state:

```text
CableAllocation.resource = "1,2,3"
CableAllocation.cores = "1-4"
CableAllocation.freeText = "blue/white + blue"
CableAllocation.discipline = CCTV | LAN | ACS | FIRE
CableAllocation.ownerType/ownerId
CableDefinition resource count parsed from product name
silent automatic resource selection
silent reuse of already consumed resource
CORE_GROUP with runtime arbitrary members
whole-cable allocation coexisting with partial allocations
```

Human labels may exist for UI/reporting but cannot be the source of resource identity.

## 19. Required pure-domain API direction

Implementation naming may evolve, but P0.3 requires an equivalent pure-domain capability:

```text
CableResourceResolver.resolve(
  definition,
  selector,
) -> ResolvedCableResources

CableAllocationValidator.validate(
  candidate,
  cable,
  definition,
  activeAllocations,
) -> AllocationValidationResult
```

The validator must be deterministic, side-effect free and repository-independent.

Repository transactions are responsible for preventing race conditions around concurrent allocations.

## 20. Concurrency requirement deferred to P2 implementation

The domain overlap check alone is insufficient under concurrent writes.

P2 implementation must guarantee that two commands cannot both observe a resource as free and commit overlapping allocations.

Accepted implementation strategies may include:

- serialized transaction boundary for one cable;
- database uniqueness via normalized allocation atoms;
- conflict detection with optimistic versioning;
- another proven atomic mechanism.

P0.3 does not choose the persistence mechanism, but atomic overlap protection is mandatory.

## 21. Persistence direction, not schema approval

P0.3 does not approve schema yet, but persistence must be able to reconstruct selectors exactly.

Two viable patterns for later evaluation:

```text
A. allocation row + normalized allocation-resource child rows
B. allocation row + typed structured selector with deterministic canonical encoding
```

Preference for P2/P8 should be given to a representation that supports database-enforced or transactionally safe overlap detection and exact restart reconstruction.

No comma-separated resource list should be treated as authoritative persistence.

## 22. Error/findings vocabulary

Structural validation should expose stable machine-readable codes.

Minimum set:

```text
ALLOCATION_MISSING_REFERENCE
ALLOCATION_PROJECT_MISMATCH
ALLOCATION_INVALID_SEQUENCE
RESOURCE_KIND_UNSUPPORTED
RESOURCE_INDEX_OUT_OF_RANGE
RESOURCE_GROUP_UNKNOWN
RESOURCE_SELECTOR_EMPTY
RESOURCE_SELECTOR_MALFORMED
RESOURCE_MODE_CONFLICT
RESOURCE_OVERLAP
WHOLE_CABLE_CONFLICT
DUPLICATE_ALLOCATION
```

User-facing text is not the contract; codes are.

## 23. P0.3 acceptance gate

P0.3 is CLOSED when all statements below are accepted:

- [x] resource kinds are discipline-neutral;
- [x] `WHOLE_CABLE`, `PAIR`, `CONDUCTOR`, `FIBER`, `CORE_GROUP` semantics are defined;
- [x] selectors are typed, normalized and deterministic;
- [x] `CORE_GROUP` membership comes only from exact definition provenance;
- [x] whole-cable allocation is exclusive;
- [x] atomic resource intersection defines partial-allocation conflict;
- [x] same-connection and cross-connection overlap are both rejected;
- [x] resource capacity comes from exact `CableDefinition`, never product-name parsing;
- [x] multi-cable connection allocations have deterministic sequence;
- [x] structural validation is separated from engineering compatibility findings;
- [x] CCTV and LAN whole-cable scenarios pass;
- [x] ACS multi-core allocation passes and overlap fixture fails;
- [x] Fire supports definition-driven whole/partial addressing;
- [x] fiber allocation proves the model is medium-generic;
- [x] concurrency-safe overlap protection is mandatory for P2 implementation;
- [x] persistence must reconstruct selectors exactly after restart.

## 24. Remaining ELV3-P0 work

With P0.1/P0.2/P0.3 frozen, continue in this order:

```text
P0.4  PhysicalChannel factual model
      dimensions / compartments / environment / spatial ownership

P0.5  Lifecycle / deletion / audit / provenance

P0.6  Migration from electrical CableRun

P0.7  Full CCTV / LAN / ACS / Fire walkthrough

P0.8  Persistence proposal

P0.9  Hard design review
```

No ELV3 schema migration should begin before P0.9 closes the complete design contract.
