# Electra — ELV3 P0 Physical Routing Design Inputs

Status: DISCOVERY / DESIGN BASELINE  
Branch: `feat/flutter-elv3-physical-routing-design`  
Baseline: `main@786a28ac6e4b532b1e7ac2083502799935ca51ed`  
Scope: ELV3 design and source-data inventory only; no ELV3 persistence refactor is approved by this document.

## 1. Purpose

ELV1 and ELV2 are closed and merged. ELV3 starts from the accepted logical topology and canonical profile model and adds physical cable resources, allocations, routes/pathways and physical compatibility without changing ELV1 connection semantics.

ELV3 answers four separate questions:

1. Which physical cable resource carries a logical connection?
2. Which pairs, conductors, fibers or whole-cable capacity are allocated to that connection?
3. Where is the physical cable routed?
4. Is that route/pathway physically compatible with the selected cable and installation facts?

The P0 objective is to freeze ownership and cardinality before adding tables or changing existing routing persistence.

## 2. Accepted upstream invariants

ELV3 MUST preserve:

```text
ELV1
Component -> Port -> Connection -> Port -> Component

ELV2
Component -> exact canonical profile/catalog edition -> frozen persisted ports
```

The following remain non-negotiable:

- `EngineeringConnection` is logical topology, not a physical cable;
- passive `InternalConnectivity` is not an external cable;
- crossing route geometry never creates logical connectivity;
- catalog/profile identity stays exact and versioned;
- manufacturer SKU is not engineering truth;
- no silent latest-edition adoption;
- physical routing cannot rewrite ELV1 topology;
- power/conversion calculations belong to ELV4/ELV5, not ELV3.

## 3. Current implementation inventory

### 3.1 Pure routing domain already available

`packages/engineering_core/lib/src/cable_routing.dart` already provides:

- `RouteNodeKind`;
- `LayingMethod`;
- `PhysicalChannelKind`;
- `SurfaceRouteAnchor`;
- `RouteNode`;
- `RouteSegment`;
- `CableRoute`;
- `PhysicalChannel`;
- `CableRun`;
- `RouteIssue` / `RouteCalculation`;
- `CableRouteValidator`.

Existing strengths to retain:

- exact surface-patch anchors in local millimetres;
- world-position reconstruction and stale geometry detection;
- explicit surface transitions through persisted adjacency;
- finite-edge / boundary validation;
- opening avoidance;
- physical-channel references on route segments;
- geometry-derived route length;
- explicit reserve percent and termination allowance;
- no topology is inferred from crossing geometry.

### 3.2 Existing floor routing graph

`packages/engineering_core/lib/src/floor_routing_graph.dart` already provides:

- room-level `CableRun + CableRoute` aggregation;
- `FloorRoutingPanel` and feeds;
- `FloorRoutingHandoff` between room runs;
- routing-junction graph edges;
- directed trace upstream/downstream;
- cycle detection;
- endpoint signatures used to detect stale physical handoffs.

Important current assumption: endpoint signatures include `run.circuitId`.

### 3.3 Persistence already available

Current Drift schema (schema version 17) already contains:

```text
PhysicalChannels
CableRoutes
CableRouteNodes
CableRouteSegments
CableRuns
RoutingJunctions
JunctionConnections
FloorRoutingPanels
FloorPanelFeeds
FloorRoutingHandoffs
```

The geometry tables referenced by the routing model already exist:

```text
Rooms
SurfacePatches
SurfaceEdges
SurfaceAdjacencies
Openings
SpatialFeatures
```

### 3.4 Existing repository/application layer

`apps/mobile/lib/application/cable_routing_repository.dart` exposes:

```text
RoomRoutingSnapshot
CableRoutingRepository
  loadRoomRouting(roomId)
  watchRoomRouting(roomId)
  saveRouteWithRun(route, run)
  saveJunction(junction)
  saveChannel(channel)
```

`DriftCableRoutingRepository` reconstructs a room routing snapshot from:

- geometry;
- routes/nodes/segments;
- physical channels;
- cable runs;
- routing junctions;
- electrical circuits.

It also validates route state inside transactions.

### 3.5 Existing tests/UI to reuse

Existing baseline coverage includes:

- `packages/engineering_core/test/cable_routing_test.dart`;
- `packages/engineering_core/test/floor_routing_graph_test.dart`;
- `packages/engineering_core/test/routing_junction_test.dart`;
- `apps/mobile/test/data/cable_routing_persistence_test.dart`;
- `apps/mobile/test/data/floor_routing_persistence_test.dart`;
- `apps/mobile/test/data/junction_persistence_test.dart`;
- `apps/mobile/test/features/editor/cable_route_editor_test.dart`;
- floor routing workspace tests.

These tests are regression assets. ELV3 must extend them rather than replace the existing spatial/routing foundation.

## 4. Confirmed electrical-specific coupling that ELV3 must resolve

The current routing foundation was designed for electrical circuits and contains direct coupling:

### 4.1 Domain

```text
CableRun.circuitId : required String
```

A CableRun is currently invalid if `circuitId` is empty.

### 4.2 Persistence

```text
CableRuns.circuitId -> ElectricalCircuits.id
JunctionConnections.circuitId -> ElectricalCircuits.id
```

### 4.3 Application snapshot

`RoomRoutingSnapshot` stores `activeCircuitIds`, and `cableLength(run)` returns null when `run.circuitId` is not an active electrical circuit.

### 4.4 Floor graph

`FloorRoutingRun.endpointSignature()` includes `run.circuitId`.

### 4.5 Repository watch/load

The routing repository watches and loads `electrical_circuits` as part of room routing state.

This coupling MUST NOT be solved by creating fake electrical circuits for CCTV, LAN, ACS or fire-alarm connections.

## 5. P0 target ownership model to validate

P0 will validate, adjust and then freeze the following conceptual ownership chain:

```text
EngineeringConnection             ELV1 logical relation
        |
        v
CableAllocation                   why/how cable resources are used
        |
        v
Cable                             one physical cable identity
        |
        v
CableRun                          routed physical run / section
        |
        v
CableRoute                        geometry
        |
        v
RouteSegment
        |
        v
PhysicalChannel / Pathway?        containment/carrier facts
```

This is a design hypothesis until P0 closes.

## 6. Cardinalities that must be decided explicitly

P0 must freeze exact cardinalities for at least:

```text
EngineeringConnection  <-> CableAllocation
Cable                   <-> CableAllocation
Cable                   <-> CableRun
CableRun                <-> CableRoute
RouteSegment            <-> PhysicalChannel
Cable                    <-> endpoint ports
CableRun                <-> room/floor handoff
```

Questions:

1. Can one logical connection use more than one cable sequentially?
2. Can one cable carry multiple logical connections?
3. Can one cable have multiple CableRuns across rooms/floors?
4. Is a CableRun always exactly one route, or can one run traverse several route objects?
5. Is `Cable` project-owned while `CableRun` is room-owned?
6. How are risers/shafts represented across floors?
7. Does a floor handoff connect CableRuns, Cable sections, or pathway continuity only?
8. Which entity owns service loops and endpoint allowances?
9. Which entity carries exact cable-definition provenance?
10. Which entity owns labels/installation IDs used in cable schedules later?

No schema work begins before these answers are frozen.

## 7. Cable resource questions

P0 must define a product-neutral `CableDefinition` model sufficient for later ELV3 compatibility, without importing ELV5 calculations.

Candidate engineering facts to classify as REQUIRED / OPTIONAL / DEFERRED:

```text
medium
construction
pairCount
conductorCount
fiberCount
conductorCrossSection
conductorMaterial
categoryOrClass
shielding
impedance
voltageRating
outerDiameterMm
minimumBendRadiusMm
firePerformanceClass
environmentClass
installation constraints
exact catalog/version provenance
```

Candidate cable resource units:

```text
WHOLE_CABLE
PAIR
CONDUCTOR
FIBER
CORE_GROUP
```

P0 must decide whether allocation units are explicit individually addressable resources or range/set descriptors.

## 8. PhysicalChannel / pathway source-data questions

Current `PhysicalChannel` only has:

```text
id
roomId
name
kind = conduit | tray | trunking
```

ELV3 must inventory which facts are necessary for physical compatibility and fill while keeping normative thresholds out of the entity.

Candidate facts to evaluate:

```text
kind
geometry/dimensions
usable cross-sectional area
width/height/diameter
compartment/divider layout
room/floor ownership
route/segment ownership
environment facts
fire-zone / penetration facts
installation class
capacity evidence source
```

Rule thresholds such as permitted fill percentage or minimum segregation distance should live in versioned compatibility/rule profiles, not as anonymous mutable channel fields.

## 9. Compatibility-engine boundary

ELV3 should follow the successful ELV2 pure-engine pattern.

Candidate contract:

```text
PhysicalRoutingCompatibilityEngine
  evaluate(cable, allocation, run, route, channels, evidence, profile)

RouteCompatibilityResult
  status = COMPATIBLE | WARNING | FORBIDDEN | UNRESOLVED
  findings[]
```

Candidate finding dimensions:

```text
allocation
endpoint
medium
installation
environment
segregation
containment
fill
bendRadius
fire
geometry
reserve
```

P0 must separate:

- factual persisted inputs;
- derived geometric inputs;
- versioned engineering rules;
- normative/legal rules deferred to ELV7.

## 10. Explicit ELV3 boundaries

### In ELV3

- canonical physical cable definition/resource;
- connection-to-cable resource allocation;
- pair/conductor/fiber allocation safety;
- reuse of spatial route geometry;
- CableRun ownership cleanup;
- pathway/channel facts;
- route length;
- physical fill basis;
- physical segregation basis;
- bend-radius basis;
- service-loop/reserve basis;
- explainable physical compatibility;
- restart/provenance.

### Not in ELV3

- PoE power budget;
- DC voltage drop as discipline result;
- PSU/UPS/battery sizing;
- fiber optical loss budget;
- Ethernet channel performance certification;
- CCTV bandwidth/storage;
- ACS controller/PSU calculations;
- fire loop current/autonomy;
- jurisdiction compliance claim;
- manufacturer SKU selection.

Those belong to ELV4/ELV5/ELV7/ELV8.

## 11. Four-discipline source scenarios

P0 must gather concrete input fixtures before implementation.

### CCTV

```text
Camera ETH/PoE port
-> ELV1 connection
-> one balanced-copper cable
-> wall/tray/wall route
-> PoE switch port
```

Questions: whole-cable allocation, Cat6-like medium, tray transition, endpoint allowance.

### LAN

```text
Outlet rear port
-> permanent-link connection
-> one balanced-copper cable
-> route/pathway
-> patch-panel rear port
```

Important: patch-panel rear/front `InternalConnectivity` remains ELV1 and does not create a phantom cable.

### ACS

```text
Reader bus
Lock control/power
Door contact
REX
```

P0 must include at least one multi-core cable scenario proving multiple independent logical connections can consume distinct conductor/core allocations in one physical cable when allowed.

### Fire

```text
FACP source/return
-> addressable devices
-> fire cable
-> route/pathway
-> explicit physical compatibility finding for incompatible containment
```

ELV1 owns loop topology. ELV3 only owns the physical cable/path.

## 12. Development roadmap

### ELV3-P0 — Discovery and canonical contract

Deliverables:

- existing routing/persistence inventory;
- ownership/cardinality matrix;
- current electrical-coupling map;
- Cable/CableDefinition/CableAllocation contract draft;
- CableRun/Route/Pathway responsibility matrix;
- deletion/lifecycle/provenance rules;
- four-discipline source fixtures;
- migration strategy options;
- architecture decision on `CableRun.circuitId` replacement.

Gate: design review only; no persistence change.

### ELV3-P1 — Canonical cable definitions and physical cable identity

Deliverables:

- immutable/versioned CableDefinition;
- physical `Cable` entity;
- exact project provenance;
- lifecycle and validation;
- four-discipline cable-definition fixtures.

### ELV3-P2 — CableAllocation

Deliverables:

- explicit Connection <-> Cable allocation;
- pair/conductor/fiber resource model;
- overlap/double-allocation guards;
- endpoint compatibility;
- wireless/no-cable explicit state where applicable.

### ELV3-P3 — CableRun ownership refactor

Deliverables:

- remove electrical-circuit-only identity assumption;
- preserve existing electrical runs through migration/adapter;
- define Cable <-> CableRun cardinality;
- preserve route geometry and floor handoffs;
- no fake electrical circuits for ELV.

### ELV3-P4 — Pathway / PhysicalChannel facts

Deliverables:

- canonical channel/pathway facts needed by compatibility;
- dimensions/usable geometry where required;
- compartments/dividers model if needed;
- room/floor/riser ownership;
- migration of current conduit/tray/trunking records.

### ELV3-P5 — Physical compatibility engine

Deliverables:

- pure compatibility engine;
- `COMPATIBLE/WARNING/FORBIDDEN/UNRESOLVED`;
- structured findings;
- no discipline switch-cases;
- deterministic inputs/output.

### ELV3-P6 — Common physical processes

Deliverables:

- ELV-ROUTE-01 geometric cable length;
- ELV-ROUTE-02 fill basis;
- ELV-ROUTE-03 segregation basis;
- ELV-ROUTE-04 bend-radius basis;
- ELV-ROUTE-05 congestion basis;
- ELV-ROUTE-06 service-loop allowance.

Normative thresholds remain profile-driven and are not hard-coded.

### ELV3-P7 — Editor/application integration

Deliverables:

- select logical connection;
- inspect compatible cable definitions;
- allocate cable resources;
- create/reuse physical route;
- inspect pathway/compatibility findings;
- trace logical vs physical topology separately.

### ELV3-P8 — Persistence/restart and four-discipline acceptance

Deliverables:

- CCTV acceptance;
- LAN permanent-link acceptance;
- ACS multi-core allocation acceptance;
- Fire route/compatibility acceptance;
- SQLite restart exact identity/provenance;
- project isolation/deletion guards/rollback.

### ELV3-P9 — Hard audit and exact-SHA closure

Deliverables:

- adversarial audit;
- migration/restart review;
- no ELV4/5 scope leakage;
- push + PR exact-SHA CI GREEN;
- post-merge `main` GREEN.

## 13. Source data to collect before P0 closure

### Repository evidence

- exact current routing domain contracts;
- exact Drift routing schema and migrations;
- routing repository transaction semantics;
- route/junction/floor tests;
- editor route creation flow;
- deletion guards touching routes/runs/channels;
- dependency recalculation nodes derived from CableRun length;
- any BOM/manufacturer code already referencing CableRun.

### Engineering fixtures

For each CCTV/LAN/ACS/Fire scenario collect:

- logical endpoints and exact ELV1 port/interface profiles;
- intended physical cable type;
- number/type of required allocation units;
- expected pathway type;
- expected route geometry pattern;
- reserve/service-loop assumptions;
- physical compatibility facts;
- expected invalid case.

### Standards/reference data

P0 may list relevant standards/categories but MUST NOT invent normative numeric thresholds. Any executable threshold needs a later verified source/provenance path.

## 14. Initial risks

| Risk | Severity | P0 action |
|---|---|---|
| `CableRun.circuitId` hard-wires electrical ownership | HIGH | freeze replacement/compatibility strategy before schema work |
| Junction connection also owns electrical `circuitId` | HIGH | separate physical continuity from electrical network identity |
| Floor endpoint signature contains circuit identity | HIGH | define physical identity fingerprint independent of electrical circuit |
| `PhysicalChannel` lacks geometry/capacity facts | HIGH | inventory minimum factual model before fill/compatibility |
| Connection == Cable shortcut | BLOCKER if introduced | require CableAllocation layer |
| ELV3 leaking PoE/voltage-drop calculations | HIGH | enforce ELV3/ELV4/ELV5 boundary |
| Rewriting mature route geometry | HIGH | reuse existing CableRoute/SurfacePatch kernel |
| Migration breaks existing electrical CableRuns | HIGH | compatibility/migration acceptance mandatory |

## 15. P0 Definition of Done

ELV3-P0 is complete when:

1. the current routing implementation is inventoried;
2. all electrical-specific couplings are enumerated;
3. ownership/cardinality for Connection, CableAllocation, Cable, CableRun, Route and PhysicalChannel is frozen;
4. physical cable resource units are frozen;
5. CableDefinition factual fields are classified;
6. PhysicalChannel factual fields are classified;
7. lifecycle/delete/provenance semantics are explicit;
8. migration strategy preserves existing electrical routing;
9. CCTV/LAN/ACS/Fire design fixtures are explicit;
10. ELV3 vs ELV4/ELV5 boundaries are explicit;
11. no implementation begins with unresolved ownership/cardinality questions.

Only after this gate should ELV3-P1 implementation start.
