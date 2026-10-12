# ADR-016: Routing junctions are first-class visual engineering nodes

## Status
Accepted

## Context

Electra already models physical routing as a graph with explicit route nodes and route segments. For field installation and commissioning, engineers must be able to inspect not only complete route lines but also the exact point where routes branch, merge, transition between physical channels or distribute toward several loads.

A junction must therefore be more than a generic graph vertex or a decorative crossing. It carries engineering meaning, connectivity, installation constraints and documentation requirements.

## Decision

Electra introduces a first-class `RoutingJunction` model and a dedicated junction-detail visualization.

A routing junction may represent:

- a junction box;
- distribution box;
- terminal box;
- tee/split;
- cable-tray branch;
- conduit branch;
- floor/ceiling box;
- riser take-off;
- panel entry;
- transition between routing systems;
- custom distribution point.

Representative model:

```text
RoutingJunction
  id
  type
  location
  surfacePatchId?
  roomId?
  floorId?
  incomingConnections[]
  outgoingConnections[]
  physicalContainerId?
  installationStatus
  notes?
```

A connection references the actual `CableRun`, `ConduitRun`, tray/run or other engineering run participating in the node.

## Junction detail view

Selecting a junction opens a focused engineering view rather than a generic property list.

```text
                 C-201 -> Room 201
                        /
DB-F02 ---- TR-02 ---- J-14 ---- C-202 -> Room 202
                        \
                         C-203 -> HVAC-02
```

The view should expose:

- incoming and outgoing runs;
- circuit/network identifiers;
- cable or pipe type;
- conductor count / section where applicable;
- laying method;
- source and destination;
- physical channel/container;
- branch direction;
- spare capacity;
- warnings and validation state.

The same node must be renderable as both a compact symbol on the room/floor drawing and an expanded detail card/schematic.

## Visualization modes

Electra should support at least three junction presentations:

1. `IN_PLACE` — compact symbol on the engineering drawing.
2. `SCHEMATIC` — logical branch diagram optimized for understanding connectivity.
3. `INSTALLATION_DETAIL` — physical view with tray/conduit/box dimensions, entries/exits and termination information where available.

The schematic is derived from topology; it is not a separate source of truth.

## Cross-layer junctions

A physical distribution location may carry several engineering layers. Example:

```text
Technical box J-14
├── electrical power
├── control
├── ethernet
└── instrumentation
```

Each layer keeps its own engineering runs and rules, while the physical box/location may be shared where permitted.

Compatibility and separation rules remain governed by the corresponding layer/routing ruleset.

## Interaction

From a route, the user can tap a junction to open its detail view.

From a junction detail view, the user can navigate to:

```text
Junction
 -> incoming route
 -> outgoing route
 -> circuit/network
 -> source device
 -> destination device
 -> room/floor
 -> containing tray/conduit/box
```

This supports rapid field tracing during installation and diagnostics.

## Validation

A junction validator should eventually detect:

- dangling branches;
- duplicate connections;
- incompatible route classes;
- conduit/tray capacity violations;
- missing physical box where required;
- impossible entry/exit geometry;
- missing labels;
- unassigned circuit/network;
- forbidden mixing of engineering systems.

## Documentation

Junctions may be included in:

- room reports;
- floor route drawings;
- cable schedules;
- junction schedules;
- installation work packages;
- as-built documentation;
- commissioning records.

Each junction should have a stable engineering identifier such as `J-014`, suitable for drawing labels, QR labels and field lookup.

## Consequences

Positive:

- routing becomes easier to understand and diagnose;
- field installers can trace branches without reading the complete project graph;
- installation drawings become more useful;
- junction BOM and labeling become possible;
- future automatic routing can treat distribution points explicitly.

Trade-offs:

- junction topology and physical-container semantics must remain synchronized;
- schematic layout needs deterministic rendering independent from stored route geometry;
- validation must distinguish simple geometric crossings from real connected junctions.
