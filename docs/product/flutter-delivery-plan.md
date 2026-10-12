# Electra Flutter Delivery Plan

## Purpose

This plan turns the Flutter development specification into executable work packages. The implementation remains local-first: SQLite/Drift is the operational source of truth; backend/auth/cloud are outside the Phase-1 dependency graph.

## Delivery rules

1. Work vertically and prove each slice with executable evidence.
2. Do not advance when a prior persistence or correctness gate is red.
3. Canonical engineering state belongs in SQLite-backed repositories, never in widget-owned collections.
4. `engineering_core` stays independent from Flutter and Drift.
5. Compact, medium and expanded layouts share one canonical domain model.
6. Every persisted geometry coordinate uses integer millimetres.

## WP-FL0 — Flutter foundation

### Scope

- Riverpod composition root;
- go_router navigation;
- UUIDv7 ID generation;
- application/repository boundaries;
- transaction boundary;
- adaptive layout tests;
- CI baseline.

### Acceptance

Foundation compiles, analyzes and tests on exact HEAD with no in-memory canonical project store.

## WP-FL1 — Drift / SQLite foundation

### Scope

- schema v1;
- Project/Floor/Room tables;
- repository adapters;
- metadata/tombstones;
- indexes;
- migration harness.

### Acceptance

SQLite is the source of truth and schema creation/migration tests are green.

## WP-FL2 — Project hierarchy vertical slice

### Scope

- Projects;
- Floors;
- Rooms;
- persistence-backed navigation;
- restart reconstruction;
- compact/medium/expanded layouts.

### Acceptance

The same persisted project is usable on compact, medium and expanded layouts without different domain models.

## WP-FL3 — Geometry kernel integration

**Implementation status: complete in `feat/flutter-geometry-kernel`; exact-HEAD CI is the closure gate.**

### Scope

- `Point2Mm` / `Point3Mm` persisted integer geometry;
- continuous `Point2D` / `Point3D` computation projections;
- vectors and segments;
- simple polygons with deterministic area and containment;
- planes;
- reversible local coordinate frames;
- explicit geometry tolerance;
- `SurfacePatch`;
- `SurfaceEdge`;
- `SurfaceAdjacency`;
- `Opening`;
- `SpatialFeature`;
- spatial topology validation;
- SQLite schema v2;
- geometry repositories;
- v1 -> v2 migration;
- SQLite close/reopen exact round-trip.

### Domain invariants

The FL3 gate requires at minimum:

- non-zero segments;
- polygons with at least three vertices;
- no zero-length polygon edges;
- non-zero polygon area;
- no polygon self-intersection;
- orthogonal local coordinate axes;
- world/local transform reversibility within tolerance;
- opening and feature containment inside the host patch;
- valid patch/edge/adjacency references;
- declared surface orientation consistent with the local-frame normal;
- duplicate patch/edge identifiers reported by validation.

### Persistence boundary

Drift remains an infrastructure adapter. Domain classes do not import Drift and Drift-generated row types use explicit `*Row` names to avoid becoming domain types.

Schema v2 persists:

```text
surface_patches
surface_edges
surface_adjacencies
openings
spatial_features
```

alongside the existing Project/Floor/Room hierarchy.

### Acceptance

A representative room containing two surface patches, a fold adjacency, an opening and a spatial feature must:

```text
construct valid pure-domain geometry
→ persist through GeometryRepository
→ close SQLite
→ reopen SQLite
→ reconstruct exact integer geometry/topology
→ pass domain validation
```

The migration gate must also prove:

```text
schema v1 hierarchy data
→ migrate to schema v2
→ preserve Project/Floor/Room
→ create geometry tables and indexes
```

No Room Editor work starts until the permanent CI workflow is green on the exact branch HEAD.

## WP-FL4 — Room Editor shell

### Scope

- room route and persistent room context;
- engineering canvas driven from `roomGeometryProvider`;
- pan/zoom;
- select tool;
- measure tool;
- context panel;
- bottom sheet in compact mode;
- desktop inspector in expanded mode;
- undo/redo command layer;
- technical linework renderer using geometry-domain data only.

### Acceptance

The same persisted room can be opened, selected, measured and navigated using touch and mouse without mutating geometry accidentally. Closing and reopening the application must render the same geometry from SQLite.

## WP-FL5 — Edge-driven surface navigation

### Scope

- active patch;
- nearest edge detection;
- adjacency resolution;
- progressive preview;
- surface activation;
- corner candidate ranking.

### Acceptance

A user can navigate:

```text
wall
→ ceiling
→ beam side
→ beam underside
→ opposite beam side
```

without switching to a 3D scene.

## WP-FL6 — Component catalog placement

### Scope

- layer component library;
- search/recent/favorites;
- placement on surfaces;
- repeated placement;
- component instance persistence.

### Acceptance

A component can be selected from the catalog, placed repeatedly, persisted and restored with exact host surface and local coordinates.

## WP-FL7 — Electrical loads

### Scope

- electrical load profiles;
- consumption groups;
- equipment-to-load association;
- validation.

### Acceptance

Loads are persisted and traceable back to equipment instances.

## WP-FL8 — Circuits

### Scope

- circuit creation;
- load assignment;
- design-current inputs;
- circuit status;
- explainable proposal state.

### Acceptance

A persisted consumption group can create a persisted circuit proposal without manufacturer-specific product coupling.

## WP-FL9 — Routing

### Scope

- routes;
- nodes;
- segments;
- surface transitions;
- CableRun;
- physical channel references.

### Acceptance

A route across multiple surface patches reconstructs exactly after restart and produces deterministic geometric length.

## WP-FL10 — Routing junctions

### Scope

- junction placement;
- incoming/outgoing connections;
- branch topology;
- validation;
- detail navigation.

### Acceptance

A one-in/two-out branch is represented as a first-class junction rather than a drawing-only line crossing.

## WP-FL11 — Floor Routing View

### Scope

- floor-wide panels/backbones;
- tray/conduit context;
- branches;
- junctions;
- trace upstream/downstream;
- display modes.

### Acceptance

An engineer can trace a selected branch from floor panel to room endpoint without losing project/floor context.

## WP-FL12 — Dependency recalculation

### Scope

- derived-state dependency graph;
- stale propagation;
- affected-subgraph recalculation;
- change explanation;
- manual override review.

### Acceptance

Changing one consumer invalidates only dependent circuit/cable/protection/panel results and exposes a `What changed?` explanation.

## WP-FL13 — Protection requirements

### Scope

- functional protection requirements;
- ruleset references;
- explainable decisions;
- validation states.

### Acceptance

Protection proposals remain vendor-neutral and show inputs, reasoning, ruleset version and warnings.

## WP-FL14 — Manufacturer catalogs

### Scope

- product variants;
- manufacturer/series metadata;
- functional requirement matching;
- project manufacturer policy.

### Acceptance

The same functional protection requirement can be mapped to different compatible manufacturer products without changing engineering logic.

## WP-FL15 — Panel generation

### Scope

- consumption groups to generated circuits;
- incoming/main protection requirements;
- phase assignment;
- panel proposal;
- reserve policy.

### Acceptance

Adding/removing a consumption group updates the proposed panel structure through dependency recalculation.

## WP-FL16 — Panel physical layout

### Scope

- enclosure geometry;
- DIN rows and rail length;
- module pitch/width;
- breakers/protection modules;
- terminal rails;
- cable ducts;
- reserved zones;
- capacity validation.

### Acceptance

The editor reports module/mm overflow and can represent the exact physical row arrangement of the generated panel.

## WP-FL17 — BOM

### Scope

- quantity takeoff;
- source references;
- aggregation by project/floor/room/system;
- manufacturer mapping.

### Acceptance

Every BOM quantity drills down to the project objects that produced it.

## WP-FL18 — Estimate

### Scope

- price books;
- estimate lines;
- labor/material separation;
- versioned pricing inputs.

### Acceptance

Changing prices changes the estimate without changing the engineering project model.

## WP-FL19 — Local PDF

### Scope

- report model;
- project/floor/room drawings;
- circuits/routes/panels;
- BOM/estimate;
- validation and decision evidence.

### Acceptance

A complete report can be generated offline from the local SQLite project.

## WP-FL20 — Field / commissioning

### Scope

- work packages;
- installation status;
- deviations/as-built;
- field issues;
- tests;
- commissioning checklist.

### Acceptance

A field user can record installation and commissioning evidence without network access and the resulting state survives restart.
