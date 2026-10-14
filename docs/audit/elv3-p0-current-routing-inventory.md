# ELV3-P0 — Current Routing Kernel Inventory

Status: FACTUAL INVENTORY  
Baseline: `main@786a28ac6e4b532b1e7ac2083502799935ca51ed`  
Branch: `feat/flutter-elv3-physical-routing-design`

This document records current implementation facts only. It does not approve the future ELV3 schema.

## 1. Pure domain assets

### `cable_routing.dart`

Existing types:

- `RouteNodeKind { endpoint, bend, surfaceTransition }`
- `LayingMethod { surface, wallChase, conduit, tray, trunking }`
- `PhysicalChannelKind { conduit, tray, trunking }`
- `SurfaceRouteAnchor`
- `RouteNode`
- `RouteSegment`
- `CableRoute`
- `PhysicalChannel`
- `CableRun`
- `RouteIssue`
- `RouteCalculation`
- `CableRouteValidator`

Current `CableRun` fields:

```text
id
roomId
name
circuitId
routeId
reservePercent
terminationAllowanceMm
```

`circuitId` is required by domain validation.

## 2. Spatial routing behavior already implemented

Current route validation already covers:

- room ownership;
- non-branching ordered route chains;
- unique route-node identity;
- surface-patch ownership;
- point-inside-patch validation;
- persisted world-position reconstruction;
- stale geometry detection;
- two-sided surface transitions;
- declared adjacency validation;
- finite shared-edge validation;
- opening/cut-out crossing guards;
- laying method;
- physical-channel references;
- geometry-derived length;
- reserve percentage;
- termination allowance.

This kernel should be preserved unless P0 proves a concrete defect.

## 3. Floor-level routing behavior already implemented

`floor_routing_graph.dart` provides:

- `FloorRoutingRun`;
- `FloorRoutingPanel` / feeds;
- `FloorRoutingHandoff`;
- `FloorGraphEdge`;
- upstream/downstream tracing;
- directed-cycle detection;
- tray/conduit handoff compatibility;
- endpoint signatures for stale-assignment detection.

Current endpoint signature includes:

```text
run.id
run.roomId
run.circuitId
route.id
endpoint node identity
surface anchor
world position
laying method
physical channel
```

ELV3 must decide which parts are physical identity and which are electrical-owner identity.

## 4. Routing junction behavior already implemented

`routing_junction.dart` already has a relatively generic domain shape:

```text
RoutingJunctionConnection
- runId
- nodeId?
- direction
- circuitOrNetworkId?
- physicalChannelId?
- label?
```

However current validation still assumes electrical ownership:

- validator receives `activeCircuitIds`;
- a connected run is invalid unless `run.circuitId` is active;
- `connection.circuitOrNetworkId` must equal `run.circuitId`;
- non-physical junctions reject more than one circuit.

Physical branch types already distinguish:

```text
cableTrayBranch
conduitBranch
```

and geometric crossings do not imply connectivity.

## 5. Current Drift routing schema

Schema version: `17`.

### Physical channel

```text
physical_channels
- id
- room_id
- name
- kind
- audit columns
```

### Route

```text
cable_routes
cable_route_nodes
cable_route_segments
```

Segments reference:

```text
surface_patch_id
laying_method
physical_channel_id?
```

### Cable run

```text
cable_runs
- id
- room_id
- name
- circuit_id -> electrical_circuits.id
- route_id -> cable_routes.id
- reserve_percent
- termination_allowance_mm
- audit columns
```

### Junction

```text
routing_junctions
junction_connections
```

`junction_connections.circuit_id` currently has an FK to `electrical_circuits.id` even though the domain property is named `circuitOrNetworkId`.

### Floor routing

```text
floor_routing_panels
floor_panel_feeds
floor_routing_handoffs
```

Handoffs currently connect CableRun IDs and freeze endpoint signatures.

## 6. Application/repository coupling

`RoomRoutingSnapshot` currently contains:

```text
geometry
routes
junctions
runs
channels
activeCircuitIds
```

`cableLength(run)` returns no value when `run.circuitId` is not in `activeCircuitIds`.

`DriftCableRoutingRepository`:

- watches electrical circuits as routing dependencies;
- loads electrical circuits together with routes/runs/channels;
- rebuilds `CableRun(circuitId: row.circuitId)`;
- maps persisted junction `circuitId` into domain `circuitOrNetworkId`;
- performs routing writes inside Drift transactions.

## 7. Existing UI/assets

Existing editor/workspace assets include:

- `room_routing_screen.dart`;
- `junction_editor.dart`;
- floor routing workspace;
- room editor route flow;
- existing route drawing tests.

ELV3 should extend this UI rather than create a parallel discipline-specific routing application.

## 8. Existing regression assets

Pure domain:

```text
cable_routing_test.dart
floor_routing_graph_test.dart
routing_junction_test.dart
```

Persistence:

```text
cable_routing_persistence_test.dart
floor_routing_persistence_test.dart
junction_persistence_test.dart
```

UI:

```text
cable_route_editor_test.dart
floor_routing_workspace_test.dart
junction_editor_test.dart
```

These tests are baseline compatibility tests for any P3 migration/refactor.

## 9. Confirmed reuse candidates

Likely reusable without semantic rewrite:

```text
SurfaceRouteAnchor
RouteNode
RouteSegment
CableRoute
CableRouteValidator geometry logic
SurfacePatch/Edge/Adjacency
Opening checks
route editor interactions
physical handoff concept
junction geometry
route length geometry
```

## 10. Confirmed redesign/decoupling candidates

Must be explicitly resolved in P0 before implementation:

```text
CableRun.circuitId
CableRuns.circuit_id FK
JunctionConnections.circuit_id FK
RoomRoutingSnapshot.activeCircuitIds
RoutingJunctionValidator.activeCircuitIds
FloorRoutingRun endpoint signature circuit identity
save/load/watch dependencies on electrical_circuits
```

## 11. Missing ELV3 concepts

There is currently no first-class persisted concept for:

```text
CableDefinition
Cable physical identity
CableAllocation
pair/conductor/fiber allocation
ELV Connection -> Cable allocation
cable-definition edition provenance
pathway dimensions / usable area
pathway compartments/dividers
physical compatibility result/findings
```

These are the primary new ELV3 design surfaces.

## 12. P0 questions generated by the inventory

1. Does `CableRun` remain a generic routed section or become a child of a new `Cable`?
2. How are current electrical `CableRun` records migrated without breaking FL9-FL11?
3. Should electrical circuit ownership move to an allocation/usage relation rather than the run itself?
4. How should junction continuity refer to generic routed networks without a polymorphic FK anti-pattern?
5. Is a physical handoff continuity of Cable, CableRun, Route or PhysicalChannel?
6. Which endpoint fingerprint fields remain physical after circuit identity is removed?
7. How are multi-room and multi-floor cables represented?
8. How does CableAllocation refer to ELV1 `EngineeringPortConnections` while preserving electrical compatibility?
9. What is the minimum PhysicalChannel factual model needed for fill and compatibility?
10. Which existing electrical code must remain backward compatible through an adapter instead of being rewritten?

These questions are mandatory P0 decisions.
