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

**Status: CLOSED. Exact-SHA gate passed on `2bdb1545666216a940c221005b6801e003c49e53`; later Room Editor gates continue to execute the same kernel/persistence suite.**

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
- adjacent patch edges represent the same physical world-space segment within tolerance;
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

Geometry replacement preserves version metadata:

```text
create    revision 1
update    revision +1, preserve createdAt
tombstone revision +1, set deletedAt
restore   revision +1, clear deletedAt
```

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

## WP-FL4 — Room Editor shell

**Status: BASELINE GREEN. Exact-SHA gate passed on `81f95f351fff83dfb1b6b89a9ade372ab53db134`.**

### Implemented baseline

- canonical persisted `ProjectRecord` / `RoomRecord` route context;
- engineering canvas driven from `roomGeometryProvider` and `RoomGeometrySnapshot`;
- technical linework from persisted `SurfacePatch`, `Opening` and `SpatialFeature` geometry;
- millimetre-to-viewport transform isolated from persisted geometry;
- pan/zoom;
- deterministic Select hit-testing;
- selection overlay and contextual inspector state;
- deterministic two-point Measure tool in millimetres;
- compact context bar with bottom-sheet inspector;
- expanded side inspector;
- reversible command-history abstraction with undo/redo regression tests;
- pure interaction tests and widget-level Select/Measure flow tests.

### Remaining FL4 boundary

The command history is deliberately not attached to fake geometry mutations. Undo/redo controls become active when the first real placement/edit command is introduced. Mutation tools must execute reversible commands and persist canonical snapshots through repository/application boundaries rather than modifying widget-owned collections.

### Acceptance

The same persisted room can be opened, selected, measured and navigated using touch and mouse without mutating geometry accidentally. Closing and reopening the application renders the same geometry from SQLite.

The baseline acceptance is covered by the FL3 SQLite round-trip tests plus FL4 pure interaction and widget tests. Further geometry mutation acceptance belongs to the first real placement/edit work package rather than to a demo-only editor mutation.

## WP-FL5 — Edge-driven surface navigation

**Status: BASELINE GREEN. Core exact-SHA gate passed on `ad6d0ec16a08a5702b290f8dfe6af89597187fe8`; Flutter integration and two-surface transition gate passed on `e5e8dc7922132aa3841061d57e542ffe80eb6efb`.**

### Implemented baseline

- active persisted surface patch;
- finite-segment edge distance in engineering millimetres;
- bidirectional adjacency resolution;
- deterministic proximity states: `none`, `highlight`, `preview`, `strongPreview`;
- bounded preview hysteresis for stable corner behavior;
- candidate ranking with a stable current-preview bias;
- nearest-navigable-edge resolution so plain boundaries cannot mask real folds;
- Flutter pointer position converted through the same mm-to-viewport transform used by the editor;
- progressive edge emphasis in the technical renderer;
- textual context for edge highlight/preview/open state so navigation is not color-only;
- strong-preview tap activates the adjacent persisted patch;
- core tests for thresholds, ranking, hysteresis, adjacency and physical world-space validity;
- widget test proving a real `Wall A -> Wall B` persisted adjacency transition.

### Scope

- active patch;
- nearest edge detection;
- adjacency resolution;
- progressive preview;
- surface activation;
- corner candidate ranking.

### Acceptance

The first vertical proof is green:

```text
Wall A
→ pointer enters strong-preview zone 50 mm from the fold
→ Open → Wall B
→ tap
→ Wall B becomes the active persisted patch
```

The generalized navigation model supports the intended folded sequence:

```text
wall
→ ceiling
→ beam side
→ beam underside
→ opposite beam side
```

without switching to a 3D scene. Additional multi-patch fixtures can extend coverage without changing the navigation contract.

## WP-FL6 — Component catalog placement

**Status: CLOSED. Full Flutter/core exact-SHA gate passed on `59a925e27be3b9738dd1c6aa12cf32ab5f97aab4`.**

### Implemented behavior

- searchable system catalog and repeated component placement;
- SQLite schema v3 component instances with exact host/local coordinates;
- schema v4 local catalog preferences: favorites and eight deduplicated recent selections;
- favorite toggling writes SQLite before updating the visible state;
- async placement undo/redo tombstones/restores the individual instance with the same ID;
- failed history operations preserve their stacks for retry;
- new placement clears redo; room changes clear session history;
- undo/redo history is session-local; the resulting project state and catalog preferences survive restart;
- close/reopen, migration, revision, catalog interaction and failure regression tests.


### Scope

- layer component library;
- search/recent/favorites;
- placement on surfaces;
- repeated placement;
- component instance persistence.

### Acceptance

A component can be selected from the catalog, placed repeatedly, persisted and restored with exact host surface and local coordinates.

## WP-FL7 — Electrical loads

**Status: BASELINE CLOSED. Full Flutter/core exact-SHA gate passed on `65c9ae32f2f5881cddc36657e5b6e7d26c2414c8`.**

### Implemented behavior

- validated project electrical profiles reference exact placed component instance IDs;
- schema v5 persists every `ElectricalLoadProfile` field as a typed column;
- room-owned `RoomConsumptionGroup` records and optional load-to-group assignment;
- cross-room assignments, missing/deleted equipment and invalid parameters are rejected transactionally;
- electrical-load screen opens from Room Editor project tools, edits voltage/supply/phases/power/current/power factor/efficiency and assigns a group;
- other profile fields are preserved during editing;
- equipment undo hides its loads; redo restores visibility without losing profile or group identity;
- exact profile/group close-reopen, v4-to-v5 migration and UI validation tests;
- these persisted room groups are input records; the existing `ConsumptionGroup` panel-proposal aggregate remains a derived model for later FL8/FL15 integration.

### Remaining boundary

Circuit generation/design-current calculation belongs to FL8. This baseline does not infer rated power for generic catalog definitions, and does not auto-create loads for switches, junction boxes or panels. An engineer explicitly configures an equipment load. Advanced motor/profile fields are persisted but are not all exposed in the initial form.


### Scope

- electrical load profiles;
- consumption groups;
- equipment-to-load association;
- validation.

### Acceptance

Loads are persisted and traceable back to equipment instances.

## WP-FL8 — Circuits

**Status: BASELINE CLOSED. Initial full Flutter/core exact-SHA gate passed on `27ba2e62cedb5a27f8d7c732a4be6626bbaad645`; subsequent changes run the same gate.**

### Implemented behavior

- pure domain circuit inputs, assigned load IDs, proposal snapshots and per-load calculation evidence;
- schema v6 persists circuits, one-circuit-per-load assignments and confirmation input signatures;
- v5 load power basis migrates to unknown, requiring explicit electrical-input/mechanical-output interpretation when calculating from power;
- named proposals can be created from persisted consumption groups or explicit selected room loads;
- circuit/assignment replacement is transactional; missing, inactive, cross-room and already-assigned loads are rejected without partial writes;
- demand factor kD is persisted explicitly in (0, 1]; default 1 is visible and editable;
- rated current takes priority; otherwise single-phase AC, balanced three-phase AC and DC use explicit voltage/power inputs;
- explicitly conflicting AC phase configurations/frequencies block calculation and invalidate confirmation;
- AC requires power factor; mechanical output power additionally requires efficiency; no implicit unity PF/efficiency and no partial total when inputs are incomplete;
- `Ib = kD * sum(load current magnitudes)` is a conservative aggregation, not vector or phase-balancing analysis;
- result/evidence are recomputed from current SQLite data and are not saved as authoritative current values;
- proposed/confirmed/review-required state is tied to a deterministic versioned input signature; load changes invalidate confirmation;
- inactive equipment remains assigned but blocks current/confirmation; restoring identical equipment restores the same evidence;
- compact and expanded circuit forms edit supply, phases, voltage, kD and assignments; formula details and issues appear on demand;
- regression coverage includes formulas, missing data, live load updates, confirmation freshness, assignments, rollback, v5-to-v6 migration, close/reopen and form interactions.

### Calculation references and limits

Motor current and voltage/power interpretation follow [Schneider Electric Electrical Installation Guide — Induction motors](https://www.electrical-installation.org/enwiki/Induction_motors): three-phase voltage is line-to-line; mechanical output power is converted through efficiency before calculating input current.

Mixed phase counts or voltages are reported as incompatible. Custom/control supplies and unbalanced phase allocation require future capabilities. Starting/inrush current, cable sizing and protection selection are separate later stages; FL8 confirms a load-current proposal without manufacturer-specific product coupling.


### Scope

- circuit creation;
- load assignment;
- design-current inputs;
- circuit status;
- explainable proposal state.

### Acceptance

A persisted consumption group can create a persisted circuit proposal without manufacturer-specific product coupling.

## WP-FL9 — Routing

**Status: BASELINE CLOSED on `feat/flutter-routing-cablerun`. Full Flutter/core exact-SHA gate passed on `534ac9e162e56ad19004cbaa37dc6adea4405701`. Branch starts at the verified FL8 `d1c0f90d3fc90fea5f4275221d7c94b7b2232b0c`.**

### Implemented behavior

- typed `CableRoute`, ordered nodes/segments, physical channels and circuit-bound `CableRun`;
- canonical local anchors and rounded world points are persisted in integer millimetres;
- transition nodes bind one physical point to two local frames and an explicit adjacency;
- shared finite edges must coincide in world space and be real patch boundaries;
- segments cannot leave their host polygon, cross/touch openings or teleport between surfaces;
- non-branching chain validation reports duplicate IDs, zero lengths, missing references and stale world coordinates;
- geometric length is the sum of segment lengths projected from exact local anchors; world quantization is not used to shorten sloped segments;
- physical length adds only explicit reserve percentage and integer-mm termination allowance, both initially zero;
- schema v7: `physical_channels`, `cable_routes`, `cable_route_nodes`, `cable_route_segments`, `cable_runs` and query indexes;
- route/graph/CableRun replacement is one transaction, preserves creation times, advances revisions and tombstones removed nodes/segments;
- IDs cannot be borrowed from another route; circuit/channel references must be active in the same room and channel kind must match the laying method;
- coherent routing snapshots watch geometry, topology, channels, circuits and routing revisions; invalidated routes expose review instead of a misleading cached length;
- Route tool opens the room routing workspace; points, fold crossing, draft undo, per-segment methods/channels, allowance edits and saved-run editing are supported;
- tests cover perpendicular and sloped surfaces, beam folds, invalid topology/openings, graph replacement, watches, close/reopen, v6-to-v7 migration and compact editor interaction.

### Remaining boundary

Each CableRun follows a non-branching route. Routing junctions/branch relationships are FL10. Automatic route finding, collision policy for structural features, equipment-port endpoint binding and cable/conduit capacity/sizing are later capabilities. Openings are excluded including their boundaries; clearance and penetration rules are not inferred. Global world coordinates round the primary local projection to integer mm; exact local anchors remain canonical for length and transition coincidence.


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

**Status: BASELINE CLOSED on `feat/flutter-routing-cablerun`. Full Flutter/core exact-SHA gate passed on `b828f3cd6d1cd8547486be526885535bfb659eb8` (42 mobile tests, 72 engineering-core tests).**

### Implemented behavior

- first-class surface-anchored junctions with stable code, type, installation notes and directed CableRun connections;
- junction placement derives the exact local/world position from the selected incoming route endpoint;
- incoming connections bind the last route node; outgoing connections bind the first node; geometric crossings create no connection;
- one incoming/two outgoing runs form a persisted branch; direction, endpoint node, circuit and physical channel are explicit;
- electrical boxes require one circuit; tray/conduit branches permit multiple circuits while checking the corresponding laying method;
- validation rejects dangling/missing/invalid runs, duplicate run connections, cross-room links, mismatched endpoints, stale placement/circuit/channel metadata and already-owned run endpoints;
- schema v8 adds `routing_junctions` and `junction_connections` with typed foreign keys; junction and complete connection replacement commit atomically;
- creation timestamps survive edits, junction revisions advance, and failed writes preserve the previous topology;
- room routing snapshots include junctions and expose live review state when route geometry, endpoints, circuits or channels change;
- compact drawing symbols open a junction detail editor with a topology-derived branch schematic, incoming/outgoing assignment, circuit/route identifiers and navigation to the real route;
- unavailable run connections can be removed from the editor; failed saves retain the draft;
- tests cover exact close/reopen reconstruction of a 1→2 branch, atomic validation failure, connection replacement, live route-change review, v7-to-v8 migration and compact detail/navigation behavior.

### Remaining boundary

Connections currently meet on the same host surface. A cross-surface transition is represented inside a CableRoute before it terminates at the junction. Equipment-port binding, independent free placement before runs exist, physical box dimensions/entries, conductor sections, channel capacity, spare capacity and installation-status workflows are deferred. The branch schematic derives from connections; it is not separately persisted. Endpoint changes require explicit review and re-assignment rather than silently moving or re-wiring the saved junction.


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
