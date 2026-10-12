# Electra Architecture

Electra is a local-first engineering application for field professionals.

## Core principles

1. Mobile-first and offline-first.
2. SQLite/Drift is the local operational source of truth.
3. Backend is used for authentication, subscriptions, synchronization, sharing, collaboration and cloud backup.
4. Engineering calculations must not depend on network availability.
5. The graphical editor is 2D, but the engineering model is height-aware (2.5D / x-y-z aware).
6. Heavy files are stored outside the relational database and referenced by metadata.
7. The system starts as a modular monolith, not microservices.
8. Code, domain names, database schema, API contracts and technical documentation are English-first; user-facing text is localization-ready.
9. Physical routing is modeled as graph topology, not as a single calculated length.
10. The project owns one shared spatial model; engineering disciplines are independent, versionable layers over the same geometry.
11. Electrical is the first commercial vertical, not the architectural boundary of the platform.
12. Room editing uses edge-driven surface navigation: the user moves between concrete adjacent room surfaces directly through the geometry rather than through a separate complex navigator.
13. Room boundaries use polygonal piecewise-planar geometry so walls, floors and ceilings may contain folds, slopes, steps, beams, niches and other construction features without requiring a full BIM editor.

## High-level structure

```text
Flutter Mobile
    |
    +-- UI / Editor
    +-- SQLite / Drift
    +-- Sync Outbox
    |
    +--> Pure Dart Engineering Core
          +-- Spatial Core
          +-- Network Core
          +-- Routing Core
          +-- Equipment / Ports
          +-- Electrical Module
          +-- Future Discipline Modules
          +-- BOM / Labels / Document Models

Optional Network
    |
    v
Spring Boot Backend
    |
    +-- PostgreSQL
    +-- Object Storage (S3-compatible)
    +-- Auth / Subscription
    +-- Project Sync
    +-- Sharing / QR
    +-- Collaboration / Audit
    +-- Layer permissions / revisions
```

## Shared spatial model

The spatial model is discipline-neutral.

```text
Project
  -> Floor
    -> Room
      -> Wall
      -> Opening
      -> RoomSurface[]
          -> SurfacePatch[]
              -> SurfaceEdge[]
      -> SurfaceAdjacency[]
      -> SpatialFeature[]
      -> shared reference geometry
```

Rooms, walls and openings are created once and reused by every discipline. An electrician and a plumber work on the same room geometry instead of maintaining duplicate plans.

### Room surfaces and patches

A room exposes concrete editable surfaces rather than only generic surface labels.

Representative logical surface types:

```text
FLOOR
CEILING
WALL
CUSTOM
```

`RoomSurface` is the logical grouping. It may consist of one or more planar `SurfacePatch` objects.

```text
RoomSurface
  id
  roomId
  type

SurfacePatch
  id
  surfaceId
  boundary
  localCoordinateFrame
  plane
  normal
  elevation/orientation
```

A patch is a bounded planar polygon with its own local 2D coordinate frame mapped into project 3D coordinates. This lets a logical ceiling, wall or floor contain multiple levels, slopes or folds while preserving simple deterministic geometry per patch.

Examples:

```text
CeilingSurface
  -> Patch A horizontal at z=2700
  -> Patch B vertical soffit face
  -> Patch C horizontal underside at z=2400

FloorSurface
  -> Patch A at z=0
  -> Patch B vertical step face
  -> Patch C raised platform at z=150
```

### Spatial features

Common construction elements that alter room geometry are represented explicitly.

```text
SpatialFeature
  -> BEAM
  -> COLUMN
  -> SOFFIT
  -> NICHE
  -> SHAFT
  -> STEP
  -> PLATFORM
  -> RECESS
  -> PROTRUSION
  -> CUSTOM
```

A feature may own/generate several patches. A beam, for example, may expose bottom, side and end patches. This preserves semantic identity for measurements, annotations, routing constraints, clash detection and documentation.

### Surface edges and adjacency

Each patch owns boundary edges:

```text
SurfaceEdge
  id
  surfacePatchId
  localStart
  localEnd
  worldStart
  worldEnd
  adjacentPatchId?
  adjacentSurfaceId?
```

`SurfaceAdjacency` represents topological continuity between concrete patches/surfaces. This allows complex and non-rectangular rooms without relying on hardcoded top/bottom/left/right navigation.

A wall/floor/ceiling is therefore allowed to be piecewise-planar rather than globally flat.

## Edge-driven surface navigation

The editor has one active editing patch/surface at a time. As the pointer or touch location approaches an edge, the editor identifies the adjacent patch/surface and progressively reveals it.

Conceptually:

```text
far from edge
  -> no preview

near edge
  -> edge highlight

closer
  -> adjacent patch/surface appears

very close
  -> strong preview / snap hint

tap edge
  -> adjacent patch/surface becomes active
```

The reveal may visually fold the adjacent plane toward the user, including an intermediate preview around 45 degrees. Fold angle and opacity are UI state only; they are not persisted engineering data.

This makes room navigation geometry-driven:

```text
            CEILING
               ^
               |
WALL D <- WALL A -> WALL B
               |
               v
             FLOOR
```

The actual neighbors come from patch/surface topology, not from fixed assumptions.

This also applies to local construction geometry:

```text
ceiling patch
  -> beam side
  -> beam underside
  -> opposite beam side
  -> ceiling patch
```

and:

```text
main floor
  -> step face
  -> raised platform
```

### Editor navigation state

Flutter presentation/application state is expected to maintain concepts such as:

```text
SurfaceNavigationState
  activeSurfaceId
  activePatchId
  previewSurfaceId?
  previewPatchId?
  nearestEdgeId?
  proximity
```

`proximity` may drive:

```text
edgeOpacity
previewOpacity
foldAngle
snapStrength
```

This state is transient and must not pollute the persistent domain model.

### Route continuation across surfaces and patches

Routing remains active when changing surfaces or patches.

Examples:

```text
Wall A patch segment
  -> SURFACE_TRANSITION node
  -> Ceiling patch segment
```

```text
Ceiling patch
  -> SURFACE_TRANSITION
  -> Beam side patch
  -> SURFACE_TRANSITION
  -> Beam underside patch
```

A tap/crossing at an adjacent edge while drawing a route creates a transition node at the shared boundary and continues the same route on the new patch.

`RouteSegment.surfacePatchId` references the concrete `SurfacePatch` when surface-bound. `surfaceId` may be retained as a denormalized/logical association, but patch identity is authoritative for exact geometry.

This interaction applies equally to:

- cable routing;
- conduit/tray routing;
- plumbing pipe routing;
- heating loops;
- ventilation ducts;
- CCTV/data runs;
- fire-alarm loops.

The product remains a precise 2D/2.5D editor rather than a full free-camera 3D/BIM application.

## Geometry scope

The spatial foundation deliberately targets polygonal, piecewise-planar geometry.

Supported direction:

- horizontal planes;
- vertical planes;
- arbitrary sloped planes;
- polygonal boundaries;
- explicit folds and steps;
- beams, soffits, niches, columns, shafts, platforms and recesses.

Not required initially:

- NURBS;
- arbitrary curved surfaces;
- free-form mesh editing;
- BIM-grade constructive solid geometry.

Curved construction may later be approximated by multiple planar patches when that is sufficiently accurate for field engineering.

## Engineering layers

Engineering content belongs to a project-scoped `EngineeringLayer`.

```text
Project
  -> Shared Spatial Model
  -> EngineeringLayer[]
```

Initial discipline codes reserved by the platform:

```text
ARCHITECTURE
ELECTRICAL
LOW_VOLTAGE
CCTV
FIRE_ALARM
SECURITY
ACCESS_CONTROL
PLUMBING
HEATING
HVAC
GAS
DRAINAGE
SOLAR
EV_CHARGING
```

`ARCHITECTURE` may expose architectural annotations and design content, while authoritative room/wall/opening geometry remains part of the shared spatial model.

An `EngineeringLayer` is expected to carry at least:

```text
id
projectId
discipline
name
ownerId
revision
baseSpatialRevision
visibility
createdAt
updatedAt
```

Only `ELECTRICAL` is required for the first production vertical. Other discipline codes are architectural extension points.

## Independent object dimensions

Discipline, project phase and installation status are separate dimensions.

```text
Discipline:
  ELECTRICAL | PLUMBING | HVAC | ...

Phase:
  EXISTING | DEMOLITION | NEW | TEMPORARY

InstallationStatus:
  PLANNED | APPROVED | INSTALLED | TESTED | COMMISSIONED
```

This prevents layer proliferation such as `ELECTRICAL_INSTALLED`, `ELECTRICAL_EXISTING`, `PLUMBING_INSTALLED`, etc.

## Collaboration model

Future project collaboration is discipline-aware.

Example:

```text
Owner
  -> EDIT_GEOMETRY
  -> EDIT_ELECTRICAL

Plumber
  -> VIEW_GEOMETRY
  -> VIEW_ELECTRICAL
  -> EDIT_PLUMBING
  -> EDIT_HEATING

Client
  -> VIEW_PROJECT
```

A QR/share invitation may therefore expose an entire project read-only, or grant authenticated editing rights only to selected disciplines.

## Spatial revisions and layer revisions

Shared geometry is versioned independently from engineering layers. Edits to surfaces, patches or spatial features create a new `SpatialRevision` because engineering layers may depend on their exact geometry.

```text
SpatialRevision 17
  -> Electrical revision 21 (baseSpatialRevision=17)
  -> Plumbing revision 8   (baseSpatialRevision=17)
  -> HVAC revision 4       (baseSpatialRevision=17)
```

If walls, room geometry, patches or features change and `SpatialRevision` becomes 18, layers based on revision 17 become stale until reviewed/rebased where required.

## Spatial Core

The discipline-neutral spatial core contains concepts such as:

```text
Project
Floor
Room
Zone
Wall
Opening
RoomSurface
SurfacePatch
SurfaceEdge
SurfaceAdjacency
SpatialFeature
Point2Mm
Point3Mm
BoundingBox
MountingSurface
HeightProfile
SpatialRevision
```

The spatial core owns deterministic conversion between project/world coordinates and per-patch local 2D coordinates.

## Network Core

Many engineering disciplines can be represented as networks over the same geometry.

```text
EngineeringNetwork
NetworkNode
Run
Endpoint
Port
Route
RouteNode
RouteSegment
```

The common layer captures topology and spatial routing. Physical and calculation properties remain discipline-specific.

Examples:

```text
Electrical  -> CableRun
Plumbing    -> PipeRun
Heating     -> PipeRun / HeatingLoop
Ventilation -> DuctRun
CCTV        -> Data/PoE CableRun
Fire alarm  -> FireLoop / CableRun
```

Do not collapse these into a single JSON property bag. Shared topology is generic; engineering properties are strongly typed inside each discipline module.

## Equipment and ports

Equipment can participate in multiple engineering networks through typed ports.

```text
EquipmentItem
  -> Port[]
```

Examples:

```text
AirConditionerIndoorUnit
  -> POWER
  -> REFRIGERANT_IN
  -> REFRIGERANT_OUT
  -> DRAIN
  -> CONTROL

Sink
  -> COLD_WATER
  -> HOT_WATER
  -> DRAIN

Camera
  -> ETHERNET_POE
```

This is the primary integration point between discipline modules.

## Room semantics

Room semantics are split into category and type.

```text
Room
  -> RoomCategory
  -> RoomTypeDefinition
  -> HeightProfile
  -> EnvironmentProfile
```

Initial room categories are `RESIDENTIAL`, `WET`, `TECHNICAL`, `COMMERCIAL`, `OUTDOOR` and `OTHER`.

Room types such as `KITCHEN`, `BATHROOM`, `BOILER_ROOM`, `OFFICE`, `TERRACE` and `CUSTOM` are represented by language-neutral codes. A room type may later select recommended equipment, defaults and engineering rule profiles.

## Height and coordinate model

Canonical persisted geometry uses millimetres.

```text
xMm
yMm
zMm
```

The editor is primarily 2D, while domain objects carry physical project-space coordinates where required.

Height inheritance:

```text
Project defaults
  -> Floor defaults
    -> Room overrides
```

Structural height and finished ceiling height remain distinct. Devices have their own installation height and mounting surface. Local patch geometry may override the effective local floor/ceiling elevation, for example below a beam or on a raised platform.

## Editor views

Named views such as Plan, Ceiling, Floor and Wall elevation may still be offered as shortcuts, exports or orientation aids, but they are not the primary navigation model.

The preferred editing interaction is continuous movement between adjacent `SurfacePatch` instances through their shared edges.

Engineering layer visibility remains independently selectable.

## Equipment model

Specific appliances must not require a new hardcoded domain class for every product type.

```text
DeviceDefinition
  -> category
  -> code
  -> defaultMountingSurface
  -> defaultInstallationHeight
  -> defaultPower
  -> connection port definitions
  -> discipline recommendations
  -> presentation metadata

PointItem / EquipmentItem
  -> deviceDefinitionCode
  -> x/y/z
  -> overrides
  -> layer association
```

This supports standard devices such as sockets and switches as well as ovens, air conditioners, curtain motors, pumps, boilers and user-defined equipment.

## Routing topology

Engineering grouping, physical runs and physical routing are separate concepts.

Electrical example:

```text
Circuit
  -> CableRun
      -> Route
          -> RouteNode[]
          -> RouteSegment[]
```

Plumbing example:

```text
PlumbingNetwork
  -> PipeRun
      -> Route
          -> RouteNode[]
          -> RouteSegment[]
```

Ventilation example:

```text
VentilationNetwork
  -> DuctRun
      -> Route
          -> RouteNode[]
          -> RouteSegment[]
```

### RouteNode

A node is a physical routing position in 2.5D space.

Typical semantics:

- endpoint;
- bend;
- junction;
- `SURFACE_TRANSITION`;
- entry/exit;
- vertical riser/drop.

### RouteSegment

A segment connects two nodes and describes one spatial installation section. A surface-bound segment references the concrete `surfacePatchId` on which it lies.

Discipline-specific run segments reference this geometry and add physical characteristics such as cable/conduit properties, pipe diameter or duct dimensions.

### Junctions

A branching/distribution point is not modeled as a generic bend. Junction semantics are specialized by discipline: electrical junction box, plumbing tee/manifold, HVAC branch, network splitter, etc.

## Cross-discipline coordination

The 2.5D model must permit future clash detection without requiring full BIM in the first releases.

Possible inputs:

- route centerlines;
- physical run dimensions;
- z ranges;
- equipment bounding boxes;
- spatial feature bounds;
- surface patch geometry;
- clearance envelopes;
- room/wall/opening boundaries.

Example future collision:

```text
HVAC duct z=2400..2700
Electrical tray z=2500..2550
-> potential clash
```

## Persistence boundary

SQLite/Drift persists normalized project entities, shared spatial geometry, engineering layers and routing topology. Heavy binary content remains in the filesystem.

Primary local entities are expected to include:

```text
Project
SpatialRevision
Floor
Room
Wall
Opening
RoomSurface
SurfacePatch
SurfaceEdge
SurfaceAdjacency
SpatialFeature
EngineeringLayer
PointItem
EquipmentItem
EquipmentPort
EngineeringNetwork
Route
RouteNode
RouteSegment
Circuit
CableRun
Junction
ConduitRun
DocumentMetadata
SyncOutbox
```

Future discipline modules add their own strongly typed entities such as `PipeRun`, `HeatingLoop` and `DuctRun` without changing the spatial core.

`project_id` is the logical partition key for local project-scoped access. Physical SQLite table partitioning is not required.

## Spatial validation

Spatial Core validation must detect at least:

- degenerate patch polygons;
- invalid local/world transforms;
- broken or asymmetric adjacency;
- gaps/overlaps where topology requires a shared edge;
- invalid feature-to-patch ownership;
- route transitions that do not lie on valid adjacent boundaries.

## Backend boundary

The backend stores the cloud representation only when the user opts into sync/sharing. PostgreSQL stores structured data, spatial/layer revisions, permissions and metadata; S3-compatible storage holds PDFs, images, scans and other heavy artifacts.

Project QR sharing resolves through opaque share tokens and may expose either a live read-only model, discipline-specific collaboration access, or an immutable published project snapshot.
