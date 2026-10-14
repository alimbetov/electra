# Electra — ELV3 P0 Physical Routing Design Baseline

Status: REMEDIATED DESIGN BASELINE  
Branch: `feat/flutter-elv3-physical-routing-design`  
Baseline: `main@786a28ac6e4b532b1e7ac2083502799935ca51ed`  
Authoritative remediation: `docs/product/elv3-p0-system-architecture-remediation.md`  
Scope: design/source-data baseline; no ELV3 runtime implementation is approved solely by this document.

## 1. Purpose

ELV1 and ELV2 are accepted. ELV3 adds canonical physical cable realization without changing ELV1 logical topology and without duplicating ELV2 reference/version governance.

ELV3 answers:

1. Which physical Cable realizes a wired EngineeringConnection?
2. Which cable resources are allocated and where are they terminated?
3. What is the active physical CableRun for the Cable in the current design revision?
4. Which reusable route/geometry segments does that CableRun traverse?
5. Which PhysicalCarrier and PathwayContext contain/support those traversals?
6. Is the resulting physical arrangement technically compatible?

Formal jurisdiction/normative compliance remains ELV7.

## 2. Accepted upstream invariants

```text
ELV1
EngineeringSystem
 -> TopologyGroup
 -> EngineeringConnection
 -> persisted Port endpoints

ELV2
ReferenceSnapshot / project binding
 -> exact immutable engineering profile/definition edition
```

Non-negotiable rules:

- `EngineeringConnection != Cable`;
- `Connection` remains logical topology;
- `CableAllocation` realizes wired connections physically;
- `CableDefinition` consumes ELV2 reference governance;
- no silent latest-edition adoption;
- route geometry never infers logical connectivity;
- manufacturer SKU is not engineering truth;
- no fake electrical circuit/network IDs for ELV;
- ELV3 does not claim jurisdictional compliance.

## 3. Current implementation inventory

The existing routing kernel remains a key asset:

```text
SurfaceRouteAnchor
RouteNode
RouteSegment
CableRoute
PhysicalChannel
CableRun
CableRouteValidator
RoutingJunction
FloorRoutingHandoff
```

Strengths retained:

- surface-local anchors and world reconstruction;
- explicit surface adjacency/transitions;
- opening/boundary validation;
- laying-method/channel references;
- geometry-derived lengths;
- explicit reserve/allowance facts;
- no connectivity inferred from crossing geometry;
- room/floor routing UI and persistence tests.

## 4. Legacy electrical coupling

Current implementation still contains electrical-specific ownership assumptions:

```text
CableRun.circuitId
CableRuns.circuit_id -> ElectricalCircuits.id
JunctionConnections.circuit_id
RoomRoutingSnapshot.activeCircuitIds
FloorRoutingRun.endpointSignature includes circuitId
```

These are legacy electrical-routing semantics.

ELV3 does not solve them by globally replacing `circuitId` with `cableId`.

Instead:

```text
legacy electrical routing
  -> compatibility/coexistence adapter
  -> optional explicit adoption when physical cable evidence exists
```

## 5. Corrected target architecture

```text
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

## 6. Cardinality baseline

```text
EngineeringConnection 1 -> 0..N CableAllocation
Cable 1 -> 0..N CableAllocation
Cable 1 -> 0..1 active CableRun per design revision
CableRun 1 -> 1..N CableTraversal
Route/RouteSegment 1 <- 0..N CableTraversal
PhysicalCarrier 1 <- 0..N CableTraversal
PhysicalCarrier N -> 1 PathwayContext
```

Multiple cables for one continuous EngineeringConnection require explicit physical transition/termination semantics. Sequence/order metadata alone is insufficient.

## 7. Cable resource baseline

Initial typed resource semantics:

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

The exact definition edition may expose only the resources meaningful for that cable construction.

Resource allocations resolve to deterministic atomic resource identities. Concurrent double allocation must be impossible.

## 8. Cable termination baseline

Where physical termination detail is required, persist mapping from selected cable resource to exact project endpoint/terminal identity.

```text
CableResource -> endpoint port/terminal
```

Termination mapping is not free-text labeling and does not replace ELV1 port identity.

## 9. Route versus CableRun

`CableRun` is the installed physical realization of one Cable in one design revision.

Room/floor/riser boundaries do not create new CableRun identities.

`CableRun` instead uses an ordered traversal chain over reusable route/geometry infrastructure.

Current `CableRoute` storage remains an implementation asset to evolve/adapt; its present one-run/one-room assumptions are not frozen as final domain cardinality.

## 10. PhysicalCarrier versus PathwayContext

Carrier examples:

```text
tray
basket tray
ladder tray
conduit
trunking
duct
```

Pathway context examples:

```text
room-local
floor-common
ceiling void
underfloor
riser
shaft
project-shared
```

A shaft may contain multiple carriers. Shaft/riser is not itself a tray/conduit kind.

## 11. Facts versus rules

ELV3 persists factual physical inputs:

- cable dimensions/resource namespace;
- route geometry;
- carrier dimensions/compartments;
- pathway spatial context;
- environment/install facts;
- exact reference/provenance identity.

ELV3 may evaluate technical physical compatibility.

ELV7 owns jurisdictional/normative rule packs and formal compliance claims.

## 12. Stage boundaries

### ELV3

- Cable identity;
- resource allocation/termination;
- CableRun/traversal path;
- route/carrier/pathway facts;
- physical length/fill/bend/continuity basis;
- technical physical compatibility.

### ELV4

- PoE/power conversion;
- PSU/UPS/battery graph;
- common power capability.

### ELV5

- discipline-specific calculations such as LAN performance, optical loss, CCTV bandwidth/storage, ACS/fire calculations.

### ELV7

- jurisdictional/normative compliance.

### ELV8

- manufacturer selection, BOM, schedules and deliverables.

## 13. Mandatory acceptance fixtures

### CCTV

One Cat6 Cable from camera to PoE switch, one CableRun with multiple spatial traversals.

### LAN

One permanent-link Cable from outlet rear to patch-panel rear. Internal patch-panel connectivity creates no phantom Cable.

### ACS

One multicore Cable carries several non-overlapping allocations. Carrier occupancy counts one physical Cable.

### Fire

Loop topology remains ELV1/TopologyGroup. Device-to-device physical cable sections are separate Cables when explicit terminations exist between them.

### Fiber

Multi-fiber cable supports non-overlapping fiber allocations and termination mappings.

## 14. Remediation work packages

```text
P0-R1  Cable <-> CableRun cardinality
P0-R2  CableRun traversal vs reusable Route
P0-R3  CableDefinition <-> ELV2 reference architecture
P0-R4  multi-cable continuity / transition rule
P0-R5  PhysicalCarrier vs PathwayContext
P0-R6  resource + termination model
P0-R7  ELV3 technical vs ELV7 normative boundary
P0-R8  electrical coexistence/adoption strategy
P0-R9  revision + commands + persistence
P0-R10 cross-document/system architecture audit
```

## 15. Implementation gate

No P1 implementation is authorized until P0-R10 confirms:

- all P0 documents use the corrected cardinalities;
- no parallel cable catalog/versioning system remains;
- no mandatory synthetic migration from electrical circuit to Cable remains;
- route reuse/traversal semantics are consistent;
- carrier/pathway layering is consistent;
- command/revision/undo/concurrency requirements are explicit;
- CCTV/LAN/ACS/Fire/fiber scenarios all pass.
