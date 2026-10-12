# Electra Flutter Delivery Plan

## Purpose

This plan translates `flutter-development-specification.md` into implementation work packages with explicit acceptance gates.

The development strategy is vertical and evidence-driven:

```text
small executable slice
→ persistence proof
→ editor proof
→ electrical proof
→ routing proof
→ panel proof
→ documentation proof
```

A work package is not complete when code merely exists. It is complete when its acceptance scenario is reproducible.

## WP-FL0 — Flutter application foundation

### Scope

- adaptive layout infrastructure;
- application composition root;
- dependency injection baseline;
- navigation baseline;
- command/shortcut registry foundation;
- repository interfaces;
- common error/validation presentation;
- test harness.

### Acceptance

- application runs on at least one mobile/tablet target and one desktop target;
- compact/medium/expanded layout classification works;
- no canonical project state is stored exclusively in global widget state;
- repository interfaces can be replaced by test doubles;
- widget tests can render at all three size classes.

## WP-FL1 — Drift / SQLite persistence foundation

### Scope

Tables:

```text
project
floor
room
```

Implement:

- database bootstrap;
- schema versioning;
- first migration;
- repository adapters;
- reactive watchers;
- create/update/delete transactions;
- globally unique local IDs.

### Acceptance scenario

```text
create project
→ create floor
→ create room
→ close application process
→ reopen application
→ project/floor/room restored exactly
```

### Gate

No geometry implementation before this scenario passes.

## WP-FL2 — Project workspace

### Scope

- project list;
- project creation;
- project edit;
- floor list;
- room list;
- recent-project ordering;
- adaptive navigation patterns.

### Acceptance

The same persisted project is usable on compact, medium and expanded layouts without different domain models.

## WP-FL3 — Geometry kernel integration

### Scope

- Point2Mm / Point3Mm;
- segments;
- polygons;
- planes;
- local coordinate frames;
- tolerance;
- surface patches;
- adjacency;
- openings/features persistence.

### Acceptance

Representative room geometry survives database round-trip with deterministic coordinates.

## WP-FL4 — Room Editor shell

### Scope

- engineering canvas;
- pan/zoom;
- select tool;
- measure tool;
- context panel;
- bottom sheet in compact mode;
- desktop inspector in expanded mode;
- undo/redo command layer.

### Acceptance

The same room can be selected, measured and navigated using touch and mouse without mutating geometry accidentally.

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
→ ceiling
```

without hardcoded wall orientation assumptions.

## WP-FL6 — Component catalog and placement

### Scope

- system catalog;
- user/project extension points;
- search;
- recent;
- favorites;
- equipment placement;
- repeated placement mode;
- installation height;
- exact surface binding.

### Acceptance

Place six identical sockets without reopening the catalog for every socket and reconstruct all placements after restart.

## WP-FL7 — Loads and consumption groups

### Scope

- ElectricalLoadProfile;
- consumption groups;
- equipment-to-load relation;
- local editing;
- dependency graph registration.

### Acceptance

Changing one equipment load marks only related downstream decisions stale.

## WP-FL8 — Circuit planning foundation

### Scope

- circuit proposals;
- group-to-circuit assignments;
- engineer confirmation;
- manual modification state;
- engineering decision records;
- ruleset references.

### Acceptance

A recommendation can be inspected, accepted, manually overridden and later marked review-required after a relevant load change.

## WP-FL9 — Routing graph

### Scope

- CableRun;
- Route;
- RouteNode;
- RouteSegment;
- laying methods;
- surface transitions;
- route length;
- route persistence.

### Acceptance

Route a cable continuously across at least three surface patches and reconstruct identical topology after restart.

## WP-FL10 — Junctions and physical channels

### Scope

- routing junctions;
- branching;
- true connection vs visual crossing;
- conduit references;
- tray references;
- routing compatibility validation.

### Acceptance

A branch node exposes one incoming path and multiple outgoing branches and is distinguishable from a non-connected crossing.

## WP-FL11 — Floor Routing View

### Scope

- floor-level topology projection;
- panels;
- backbones;
- tray/conduit runs;
- junctions;
- room references;
- outgoing branches;
- trace upstream/downstream;
- filters.

### Acceptance

From a floor panel, highlight the downstream path to one room and drill down into the room editor.

## WP-FL12 — Dependency-driven recalculation

### Scope

- stale propagation;
- affected-subgraph calculation;
- recalculation proposal;
- `What changed?` diff;
- manual override protection;
- validation state.

### Acceptance

Add one consumer and demonstrate that unrelated circuits are unchanged while the affected circuit, protection proposal, panel impact and BOM impact are recalculated.

## WP-FL13 — Functional protection requirements

### Scope

- vendor-neutral device roles;
- protection requirements;
- circuit-to-device requirement generation;
- explainable rule outputs.

### Acceptance

A circuit proposal produces a functional protective-device requirement without referencing Schneider/ABB/Siemens-specific SKUs.

## WP-FL14 — Manufacturer catalog foundation

### Scope

- manufacturer catalog model;
- product variants;
- compatibility matching;
- manufacturer policy;
- preferred series;
- provenance metadata later.

### Acceptance

The same functional requirement can resolve to two valid alternatives from different manufacturer catalogs without changing the engineering rule result.

## WP-FL15 — Panel generation

### Scope

- incoming section;
- branch protection requirements;
- phase assignment;
- unassigned circuit detection;
- spare-capacity policy;
- generation proposal/review.

### Acceptance

Consumption groups generate a reviewable panel proposal and every generated device can be traced back to the circuit/load requirement that caused it.

## WP-FL16 — Panel physical layout editor

### Scope

- enclosure dimensions;
- rows;
- DIN rails;
- module pitch;
- device placement;
- terminal rails;
- cable ducts;
- reserve zones;
- physical capacity validation.

### Acceptance

Changing panel device composition can create an explicit layout conflict and the UI can show whether the issue is module count, physical millimetres or reserved capacity.

## WP-FL17 — BOM

### Scope

- deterministic quantity takeoff;
- source references;
- aggregation by floor/project;
- manufacturer-selected products where available.

### Acceptance

Every aggregate cable quantity can drill down to contributing CableRuns.

## WP-FL18 — Local price book and estimate

### Scope

- price books;
- price items;
- labor/material separation later;
- estimate generation;
- currency metadata;
- snapshot-able pricing inputs.

### Acceptance

Changing a price updates the estimate without changing the engineering design or BOM quantities.

## WP-FL19 — Local reports and PDF

### Scope

- report model;
- project summary;
- floor routing sheet;
- room drawing;
- circuit schedule;
- panel schedule;
- DIN layout;
- BOM;
- estimate;
- validation summary;
- local PDF output.

### Acceptance

Generate an offline PDF from the workshop fixture with no backend connection.

## WP-FL20 — Field lifecycle

### Scope

- installation status;
- work packages;
- deviations;
- field issues;
- test records;
- commissioning checklist;
- as-built state/revisions.

### Acceptance

Record a designed route, installation deviation, test record and as-built result while preserving design intent.

## Cross-cutting gates

Every WP must satisfy applicable checks:

```text
engineering_core unit tests
repository/data tests
migration tests
widget tests
compact layout
medium/tablet layout
expanded/desktop layout
no backend dependency
restart persistence
validation behavior
```

## First execution sequence

Implementation starts with:

```text
WP-FL0
→ WP-FL1
→ WP-FL2
```

The first release gate is intentionally narrow:

> A professional adaptive Flutter shell that creates Project → Floor → Room, persists them in Drift/SQLite, survives process restart, and behaves correctly on phone/tablet/desktop layouts.

Only after this gate is green should geometry work begin.
