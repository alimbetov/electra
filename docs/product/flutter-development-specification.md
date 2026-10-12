# Electra Flutter Development Specification

## Status
Draft v0.1 — implementation baseline

## 1. Purpose

This document defines the implementation requirements for the first production-oriented Flutter phase of Electra.

The first phase is deliberately local-first and offline-first. The application must provide a complete usable engineering workflow on the device without authentication, backend availability or network access.

Authentication, cloud synchronization, publication and server-side report delivery are later phases and must not become dependencies of the local engineering workflow.

## 2. Product goal for the Flutter phase

Build a professional electrical engineering workstation that runs on:

- Android phones;
- iPhone;
- Android tablets;
- iPad;
- Windows;
- macOS;
- Linux where Flutter support permits.

The application uses one engineering domain model, one command model and one local SQLite/Drift persistence model across all form factors.

Target UX strategy:

```text
Tablet-first engineering workspace
+ desktop-enhanced productivity
+ mobile field-optimized compact UX
```

## 3. Phase-1 scope

Phase 1 must work entirely locally and cover the following progression:

```text
Project
→ Floor
→ Room
→ Geometry
→ Equipment
→ Consumption groups / loads
→ Circuits
→ Routing
→ Floor Routing View
→ Routing Junctions
→ Panel generation
→ Panel physical layout
→ BOM
→ Estimate
→ Local reports / PDF
```

Installation, as-built and commissioning are part of the target local architecture and may be delivered after the core design vertical is stable.

## 4. Explicit non-goals for Phase 1

The following must not block Phase 1:

- login;
- account registration;
- subscription management;
- remote project synchronization;
- multi-user collaboration;
- backend API dependency;
- QR cloud sharing;
- server-side PDF generation.

The architecture must preserve integration boundaries for these capabilities, but the local application must not require them.

## 5. Architectural principles

### 5.1 Layering

```text
Flutter Presentation
        ↓
Application / Use Cases
        ↓
engineering_core
        ↓
Repository Interfaces
        ↓
Drift Repositories
        ↓
SQLite
```

Rules:

1. Flutter widgets must not implement engineering formulas.
2. `engineering_core` must not depend on Flutter widgets, SQLite, HTTP or backend DTOs.
3. Drift row classes must not leak into engineering widgets or `engineering_core`.
4. Application services coordinate commands, transactions and recalculation.
5. SQLite is the operational source of truth.
6. Canonical project state must not live only inside `ChangeNotifier`, widget state or transient providers.

### 5.2 Commands and queries

Commands mutate project state:

```text
CreateProject
CreateFloor
CreateRoom
UpdateRoomGeometry
PlaceEquipment
CreateConsumptionGroup
CreateCircuit
CreateCableRun
UpdateRoute
GeneratePanelProposal
AcceptEngineeringDecision
BuildBom
BuildEstimate
```

Queries observe state:

```text
watchProjects
watchProject
watchFloors
watchRooms
watchRoomEditorModel
watchFloorRouting
watchCircuits
watchPanel
watchBom
watchEstimate
```

Queries must not mutate engineering state.

## 6. Project structure

Target structure:

```text
apps/mobile/lib/
├── app/
│   ├── electra_app.dart
│   ├── adaptive_layout.dart
│   ├── navigation/
│   ├── commands/
│   └── theme/
├── application/
│   ├── projects/
│   ├── spatial/
│   ├── equipment/
│   ├── electrical/
│   ├── routing/
│   ├── panels/
│   ├── bom/
│   └── reports/
├── data/
│   ├── database/
│   │   ├── app_database.dart
│   │   ├── tables/
│   │   ├── daos/
│   │   └── migrations/
│   ├── repositories/
│   ├── mappers/
│   ├── catalogs/
│   └── files/
├── features/
│   ├── projects/
│   ├── floors/
│   ├── rooms/
│   ├── editor/
│   ├── floor_routing/
│   ├── panels/
│   ├── bom/
│   ├── reports/
│   ├── installation/
│   └── commissioning/
└── shared/
    ├── widgets/
    ├── formatting/
    ├── dialogs/
    └── validation/
```

The exact folder names may evolve, but dependency direction must remain stable.

## 7. Local persistence

### 7.1 Technology

Use:

- SQLite;
- Drift;
- typed migrations;
- reactive query streams;
- local filesystem for heavy artifacts.

### 7.2 Persistence guarantees

The application must survive process termination without losing committed project state.

Acceptance baseline:

```text
create project
→ create floor
→ create room
→ terminate process
→ reopen application
→ exact values restored
```

### 7.3 Identity

Persist globally unique local IDs suitable for later synchronization.

Preferred direction: UUIDv7 or equivalent time-sortable globally unique identifiers.

IDs must not depend on auto-increment values as cross-device identity.

### 7.4 Common entity metadata

Shareable domain records should support:

```text
id
projectId
revision
createdAt
updatedAt
deletedAt?
originDeviceId
```

`deletedAt` supports later tombstone-based synchronization.

### 7.5 Initial table families

#### Project hierarchy

```text
project
floor
room
```

#### Spatial

```text
room_surface
surface_patch
surface_edge
surface_adjacency
opening
spatial_feature
spatial_revision
```

#### Catalog and equipment

```text
component_definition
component_port_definition
equipment_instance
equipment_port
```

#### Electrical

```text
consumption_group
electrical_load
circuit
circuit_member
cable_run
protection_assignment
engineering_decision
```

#### Routing

```text
route
route_node
route_segment
routing_junction
conduit_run
cable_tray_run
route_channel_membership
```

#### Panels

```text
panel_assembly
panel_section
din_rail
panel_module_placement
terminal_block
terminal
io_assignment
```

#### Commercial/reporting

```text
bom_item
price_book
price_book_item
estimate_line
report_snapshot_meta
```

Later local tables:

```text
work_package
installation_deviation
field_issue
test_record
commissioning_item
```

## 8. Database migration policy

1. No destructive schema recreation for user projects.
2. Every schema change must have a tested migration path.
3. Migration tests must use representative old database fixtures where feasible.
4. Database version must be explicit.
5. Data migrations and schema migrations must be deterministic.

## 9. Reactive state model

Persistent project state is observed from repositories.

The UI may cache projections for rendering performance, but SQLite remains authoritative.

Transient UI state includes:

- active tool;
- selection;
- hover;
- canvas transform;
- temporary route gesture;
- active context slide;
- expanded panel state;
- unsaved form values.

Transient state must be clearly separated from canonical engineering state.

## 10. State management

The implementation must support:

- dependency injection;
- scoped feature state;
- reactive repository streams;
- testable application services;
- predictable lifecycle disposal.

The exact Flutter state-management library may be selected during implementation, but the architecture must avoid a single global mutable application object containing the full project model.

Recommended direction: Riverpod or another strongly testable DI/reactive state solution.

Selection of the package must be documented before broad adoption.

## 11. Navigation

Navigation is workspace-oriented rather than screen-list-oriented.

Primary logical workspaces:

```text
Projects
Room
Floor Routing
Panels
BOM / Estimate
Reports
Installation
Commissioning
```

Expected hierarchy:

```text
Projects
→ Project
  → Floor
    → Room
      → Room Editor
```

Cross-workspace navigation examples:

```text
Floor Routing
→ Junction
→ Room
→ Surface / Object
```

```text
Panel
→ Circuit
→ CableRun
→ Route
→ Equipment
```

Navigation must preserve project context and avoid rebuilding canonical state from route arguments.

## 12. Adaptive UI requirements

Use semantic size classes:

```text
COMPACT   < 700 logical px
MEDIUM    700..1099 logical px
EXPANDED  >= 1100 logical px
```

### Compact

Primary targets: phones and narrow windows.

Composition:

```text
Primary content / canvas
+ compact navigation
+ compact tool palette
+ contextual bottom sheet
```

### Medium

Primary target: tablet.

Composition:

```text
Tool Rail | Engineering Canvas | Context Panel
```

### Expanded

Primary target: desktop.

Composition:

```text
Project Navigator | Tool Rail | Engineering Canvas | Inspector
```

Layout changes must not alter engineering state.

## 13. Input requirements

### Touch

Must support:

- tap selection;
- drag placement;
- pinch zoom;
- pan;
- large touch targets;
- repeated placement workflows;
- cancellation without destructive side effects.

### Mouse / trackpad

Must support:

- precise selection;
- wheel/trackpad zoom;
- pan;
- hover feedback;
- context menu where useful;
- drag selection where useful.

### Keyboard

Initial shortcut contract:

```text
Ctrl/Cmd+Z           undo
Ctrl/Cmd+Shift+Z     redo
Delete/Backspace     delete selection
Escape               cancel active command
Enter                confirm active command
Space + pointer      pan canvas
```

Shortcuts should be routed through a command layer.

## 14. Visual design requirements

Electra uses an engineering drafting visual language.

Required:

- neutral/off-white drawing surface;
- precise thin technical linework;
- restrained semantic color;
- dimensions and engineering labels;
- clear selection/hover state;
- legible printed/monochrome representation;
- no decorative interior rendering.

Avoid:

- photorealistic walls;
- decorative textures;
- architectural visualization effects;
- heavy shadows;
- visual noise unrelated to engineering work.

## 15. Workspace shell

Persistent conceptual regions:

```text
Header / project context
Tool Rail or compact tool controls
Engineering Canvas / primary content
Context Panel or bottom sheet
Tool Context Bar
```

UX invariant:

```text
1 active tool
+ 1 primary context surface
+ focused fast actions
```

Do not show all engineering panels simultaneously by default.

## 16. Project management feature

### Project list

Must support:

- create;
- rename;
- duplicate later;
- archive later;
- delete with confirmation;
- sort by recent update;
- search later;
- show local-only state.

### Project creation

Minimum fields:

```text
name
reference
measurement system
default structural height
default finished ceiling height
```

Project creation must persist immediately.

## 17. Floor feature

A project contains one or more floors.

Minimum fields:

```text
id
projectId
name
code/order
default structural height?
default finished ceiling height?
```

Floor is a first-class entity because routing, panels and reports may operate at floor scope.

## 18. Room feature

Minimum fields:

```text
id
floorId
name
RoomType
RoomCategory
width/depth for simple creation
structural height override?
finished ceiling height override?
```

Simple rectangle creation is acceptable for the first persistence gate, but storage must not constrain future polygonal geometry.

## 19. Geometry editor

Target domain:

```text
RoomSurface
→ SurfacePatch
→ SurfaceEdge
→ SurfaceAdjacency
```

Initial geometry capabilities:

- rectangular room bootstrap;
- polygonal room boundaries;
- wall/floor/ceiling surfaces;
- openings;
- beam/soffit/step/niche feature support;
- exact millimetre coordinates;
- local patch coordinate frame;
- snap;
- measurement;
- undo/redo.

No free-form BIM solid modeling in the first phase.

## 20. Room Editor UX

Tools:

```text
Select
Point
Equipment
Route
Feature
Measure
```

The active tool controls the visible context.

Repeated placement is required for high-frequency equipment placement.

Example:

```text
select Socket 300 mm
→ tap
→ tap
→ tap
→ Done
```

The user must not reopen the full catalog for every identical placement.

## 21. Surface navigation

The editor must support edge-driven navigation between adjacent surface patches.

Interaction intent:

```text
far edge       -> no preview
near edge      -> highlight
closer         -> adjacent patch preview
very close     -> strong snap/preview
tap/cross      -> adjacent patch active
```

Routing mode must continue across a surface transition without ending the active route command.

## 22. Equipment and component catalog

Catalog hierarchy:

```text
SYSTEM
USER
PROJECT
IMPORTED
```

Definitions are separate from instances.

```text
ComponentDefinition
        ↓
ComponentInstance
```

Initial electrical categories include:

- socket;
- switch;
- lighting;
- panel;
- motor;
- pump;
- fan;
- VFD;
- control panel;
- PLC-related equipment;
- custom equipment.

Catalog UI must support:

```text
Search
Recent
Favorites
System
My Components
Project Components
```

## 23. Loads and consumption groups

Equipment may create or reference electrical load profiles.

The user must be able to organize loads into consumption groups and circuits.

Adding/changing a consumer must trigger dependency analysis for affected engineering decisions.

## 24. Dependency-driven recalculation

Changes to:

- consumers;
- load values;
- consumption groups;
- circuits;
- cable routing length;
- installation method;
- cable selection;
- protection;
- phase assignment;
- ruleset;
- manufacturer policy;

must mark the affected downstream engineering graph stale and produce a recalculation proposal.

Do not silently overwrite engineer-confirmed manual decisions.

Required states include concepts equivalent to:

```text
CURRENT
STALE
RECALCULATING
REVIEW_REQUIRED
VALIDATED
ERROR
```

The UI must provide a `What changed?` explanation.

## 25. Engineering decision UX

Every normative recommendation should be inspectable.

Example:

```text
Recommended cable: 4 mm²

Inputs
- design current
- route length
- installation method

Rules
- ruleset/version
- applied table/factors

Reasoning
- ampacity criterion
- voltage-drop criterion
- protection coordination

Warnings
- ...
```

Manual override must remain explicit and traceable.

## 26. Routing

Routing is represented as topology rather than a single calculated length.

```text
Circuit
→ CableRun
→ Route
  → RouteNode[]
  → RouteSegment[]
```

Required route node concepts:

- endpoint;
- bend;
- junction;
- surface transition;
- entry/exit;
- riser.

Initial laying methods include:

- ceiling free;
- conduit;
- floor screed;
- wall chase;
- cable tray;
- duct;
- surface mounted;
- underground;
- custom.

## 27. Floor Routing View

The application must provide floor-level engineering routing, not only room-local routing.

Target composition:

```text
Floor
├── panels
├── tray/conduit backbones
├── routing junctions
├── rooms
└── outgoing branches
```

Initial modes:

```text
Overview
Power Backbone
Control Backbone
Branch Detail
Installation Sequence
```

Required interactions:

- select panel and highlight downstream;
- select endpoint and trace upstream;
- select junction and open detail;
- select room and drill into Room Editor;
- layer/discipline filtering;
- route state visualization.

## 28. Routing Junction Detail

A junction is a real engineering node, not merely a visual crossing.

Views:

```text
In-place
Schematic
Installation detail
```

The UI must distinguish a true connected branch from two routes that visually cross without electrical/physical connection.

## 29. Circuit and protection generation

The target flow is:

```text
ConsumptionGroup[]
→ PanelGenerationEngine
→ CircuitProposal[]
→ FunctionalDeviceRequirement[]
→ Manufacturer matching
→ PanelAssembly
```

Phase 1 may start with simplified deterministic rules, but all normative data must be versioned and must not be hardcoded inside Flutter widgets.

## 30. Manufacturer catalog architecture

Engineering requirements remain vendor-neutral.

```text
Ruleset
→ FunctionalDeviceRequirement
→ ManufacturerCatalog
→ ManufacturerProductVariant
```

Future catalogs may include Schneider Electric, ABB, Siemens, Legrand and others.

A project may define preferred/allowed manufacturers and preferred product series.

Manufacturer selection must not change the underlying normative requirement.

## 31. Panel Builder

Panel design consists of two related models:

1. electrical/control topology;
2. physical assembly layout.

Target physical structure:

```text
PanelAssembly
→ enclosure
→ mounting sections
→ rows
→ DIN rails
→ module placements
→ terminal rails
→ cable ducts
→ reserved zones
```

Editor requirements:

- set enclosure dimensions;
- set number of rows;
- set DIN rail length/module capacity;
- place/reorder devices;
- display occupied/free modules;
- display reserved capacity;
- detect over-capacity;
- support automatic placement proposal later;
- retain engineer manual edits.

## 32. Panel generation from consumption groups

The panel generator must be driven by project engineering data.

Typical flow:

```text
new consumer
→ affected load group
→ affected circuit
→ design current recalculation
→ cable/protection recalculation
→ functional protective-device requirements
→ phase assignment
→ panel capacity impact
→ manufacturer rematch
→ BOM impact
```

The application must show what changed rather than silently rebuilding the panel.

## 33. BOM

BOM is derived from engineering objects.

Each BOM quantity should retain provenance/source references where possible.

Examples:

```text
cable lengths
conduit lengths
tray lengths
junction boxes
panel devices
terminals
equipment
supports later
```

## 34. Estimate

Estimate is separate from engineering quantities.

```text
Engineering Model
→ Quantity Takeoff / BOM
→ Manufacturer Mapping
→ Price Book
→ Estimate
```

Changing prices must not mutate electrical engineering decisions.

## 35. Local reports

Before backend delivery exists, the device should support local engineering report generation.

Target report sections:

```text
Project Summary
Floor Summary
Room Drawings
Floor Routing
Circuits
Cable Schedule
Panel Schedule
DIN Layout
BOM
Estimate
Validation / Warnings
Engineering Decisions
```

The same report model should later be reusable for server-side PDF generation.

## 36. Undo / redo

Engineering editing must have explicit command history for user-facing reversible operations.

Requirements:

- undo and redo must work across mouse/touch/keyboard;
- persisted state after undo/redo must remain valid;
- large derived recalculations should be represented coherently as one user operation when appropriate;
- irreversible operations require confirmation.

## 37. Validation model

Validation issues must be domain objects or projections, not ad-hoc snackbar strings.

Minimum categories:

```text
INFO
WARNING
ERROR
BLOCKING
```

Examples:

- disconnected route;
- circuit without source;
- unassigned circuit;
- panel capacity exceeded;
- terminal overcapacity;
- incompatible phase assignment;
- stale engineering decision;
- missing ruleset data.

Validation must link to the affected object when possible.

## 38. Performance targets

Initial targets for typical project sizes:

- project list opens without reading complete project graphs;
- floor/room lists are indexed by `projectId` / `floorId`;
- canvas rendering does not rebuild unrelated panels on pointer movement;
- database queries are scoped and indexed;
- expensive engineering recalculation runs outside hot paint/layout paths;
- large reports use prepared projections rather than widget-tree scraping.

Exact performance budgets will be established after the first representative workshop fixture exists.

## 39. Test strategy

### engineering_core

Pure Dart unit tests for:

- invariants;
- calculations;
- recalculation impact;
- panel generation;
- manufacturer matching;
- routing topology;
- geometry primitives.

### data layer

Tests for:

- repository CRUD;
- reactive queries;
- migrations;
- transactions;
- exact reconstruction after reopen.

### application layer

Tests for use cases and transaction orchestration.

### Flutter widgets

Widget tests for:

- compact layout;
- medium/tablet layout;
- expanded/desktop layout;
- contextual progressive disclosure;
- repeated placement;
- validation navigation.

### integration

End-to-end local vertical slice.

## 40. Reference acceptance project

The primary engineering fixture should be a workshop project:

```text
Workshop 01
Room: 8m x 6m x 3.5m
Features:
- door
- 2 windows
- beam
- column

Equipment:
- 6 sockets
- 8 lights
- CNC machine
- motor
- VFD
- control panel

Networks:
- power
- control
- Ethernet
- compressed air reference
```

Electrical acceptance flow:

```text
create project/floor/room
→ create geometry
→ place equipment
→ define loads/groups
→ generate/confirm circuits
→ route cable across surfaces
→ view floor routing
→ inspect junction
→ generate panel proposal
→ arrange panel rows
→ build BOM
→ build estimate
→ generate local report
→ terminate app
→ reopen
→ exact project reconstruction
```

## 41. Delivery gates

### FL-0 — Application foundation

- adaptive shell;
- routing/navigation baseline;
- dependency injection baseline;
- repository interfaces;
- test harness.

### FL-1 — SQLite foundation

- Drift configured;
- `project`, `floor`, `room` tables;
- migrations;
- repository adapters;
- restart persistence green.

### FL-2 — Spatial persistence

- surfaces;
- patches;
- edges;
- openings;
- features;
- geometry fixtures.

### FL-3 — Room Editor vertical

- technical canvas;
- selection;
- placement;
- measurements;
- edge navigation;
- persistence.

### FL-4 — Equipment and loads

- component catalog;
- placement;
- load profiles;
- consumption groups.

### FL-5 — Circuits and recalculation

- circuit proposals;
- engineering decisions;
- dependency invalidation;
- explainable recalculation.

### FL-6 — Routing

- route graph;
- CableRun;
- junctions;
- conduit/tray references;
- Floor Routing View.

### FL-7 — Panel engineering

- normative panel proposal;
- manufacturer-independent requirements;
- physical enclosure/rows/DIN layout;
- capacity validation.

### FL-8 — BOM / estimate

- quantity takeoff;
- manufacturer mapping;
- local price books;
- estimate.

### FL-9 — Local reporting

- drawings;
- schedules;
- BOM/estimate;
- PDF generation.

### FL-10 — Field lifecycle

- work packages;
- deviations;
- issues;
- test records;
- commissioning;
- as-built revisions.

## 42. Definition of Done for a Flutter feature

A core feature is complete only when:

1. domain behavior is not implemented in widgets;
2. canonical state persists in SQLite;
3. reopening the application reconstructs state;
4. validation behavior is defined;
5. compact behavior is defined;
6. tablet behavior is defined;
7. desktop behavior is defined;
8. relevant touch behavior works;
9. relevant mouse/keyboard behavior works;
10. unit/widget/integration tests cover critical paths;
11. no backend is required for normal local operation;
12. no hidden hardcoded normative value is introduced without a ruleset/version source.

## 43. Implementation priority

The immediate implementation priority is deliberately narrow:

```text
FL-0
→ FL-1
→ exact Project/Floor/Room persistence gate
```

Do not implement the full editor, routing or panels before the local persistence foundation is proven.

After FL-1 passes, proceed vertically through one complete representative project rather than implementing all architecture horizontally.
