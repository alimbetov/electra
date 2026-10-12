# ADR-017: Floor Routing View as an engineering floor map

## Status
Accepted

## Context
Electra already models routing as explicit topology: routes, route nodes, route segments, junctions, conduits, trays and panel relationships.

For practical engineering work this topology must be visualized not only at room-surface level, but also at floor level. Engineers, installers and reviewers need a floor-wide routing map to understand how distribution boards, trays, risers, junctions, rooms and outgoing branches relate to one another.

A room-centric editor alone is insufficient for:

- tracing feeders across corridors and multiple rooms;
- visualizing tray/conduit backbone routes;
- understanding branch-off points and distribution nodes;
- reviewing floor-level coordination and installation sequencing;
- validating routing continuity from panel to endpoint;
- generating floor routing sheets and floor BOM summaries.

## Decision
Introduce a first-class `FloorRoutingView` concept.

```text
FloorRoutingView
├── floorId
├── rootPanels[]
├── routeBackbones[]
├── trayRuns[]
├── conduitRuns[]
├── routingJunctions[]
├── roomReferences[]
├── outgoingBranches[]
└── displayMode
```

The floor routing view is an engineering floor map, not a decorative plan. It renders a dry technical representation of:

- floor outline and room references;
- floor distribution boards and automation panels;
- cable tray and conduit backbones;
- routing junctions and distribution nodes;
- outgoing branches toward rooms and equipment;
- optional discipline/layer filtering.

## Display modes
Initial display modes:

- `OVERVIEW` — balanced floor map for review and navigation;
- `POWER_BACKBONE` — trays, feeders and power branches;
- `CONTROL_BACKBONE` — control, automation and instrumentation routes;
- `BRANCH_DETAIL` — emphasizes local branch-off paths;
- `INSTALLATION_SEQUENCE` — installation-oriented view with work-package emphasis.

## Interaction model
The view must support:

- selecting a panel and highlighting downstream routes;
- upstream/downstream trace mode;
- selecting a tray/conduit and highlighting its carried runs;
- selecting a routing junction and opening its detail view;
- selecting a room and seeing incoming/outgoing engineering branches;
- drill-down from floor routing view to room editor and back;
- discipline/layer filtering;
- route-state highlighting (`DESIGN`, `APPROVED`, `INSTALLED`, `AS_BUILT`, `TESTED`, `COMMISSIONED`).

## Zoom hierarchy
The view should preserve a stable mental model across three levels:

```text
Floor overview
  -> Branch network
      -> Junction / room detail
```

At overview scale, minor labels and local details are suppressed. Detail appears progressively with selection and zoom.

## Visual language
The floor routing view must remain a dry engineering map:

- neutral background;
- technical linework;
- no photo-like interior rendering;
- limited semantic accent colors;
- symbols and line patterns must remain readable in monochrome reports;
- rooms are context, while engineering routes and nodes remain primary.

## Consequences
Positive:

- practical floor-level understanding of routing topology;
- clear relationship between panels, routes, junctions and rooms;
- strong workflow for installers and commissioning staff;
- foundation for routing sheets, installation packages and as-built review;
- future clash, fill and issue overlays can reuse the same map.

Trade-offs:

- requires floor-scale rendering in addition to room-surface rendering;
- requires route aggregation and level-of-detail rules;
- large floors require careful visual decluttering and filtering.
