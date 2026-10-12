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
      -> shared reference geometry
```

Rooms, walls and openings are created once and reused by every discipline. An electrician and a plumber work on the same room geometry instead of maintaining duplicate plans.

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

Shared geometry is versioned independently from engineering layers.

```text
SpatialRevision 17
  -> Electrical revision 21 (baseSpatialRevision=17)
  -> Plumbing revision 8   (baseSpatialRevision=17)
  -> HVAC revision 4       (baseSpatialRevision=17)
```

If walls or room geometry change and `SpatialRevision` becomes 18, layers based on revision 17 become stale until reviewed/rebased where required.

This supports the future workflow:

```text
Electrician creates project geometry
  -> publishes/syncs project
  -> shares project with plumber
  -> plumber adds plumbing/heating layer
  -> both disciplines continue against the same spatial model
```

## Spatial Core

The discipline-neutral spatial core contains concepts such as:

```text
Project
Floor
Room
Zone
Wall
Opening
Point3Mm
BoundingBox
MountingSurface
HeightProfile
```

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

The editor is primarily 2D, while domain objects may carry a physical `z` position.

Height inheritance:

```text
Project defaults
  -> Floor defaults
    -> Room overrides
```

Structural height and finished ceiling height remain distinct. Devices have their own installation height and mounting surface.

## Editor views

The same spatial model can be presented using multiple engineering views:

- Plan
- Ceiling
- Floor
- Wall elevation

These are views over the same domain objects, not duplicated project data. Discipline visibility is independently selectable.

Example:

```text
Plan
  [x] Electrical
  [ ] Plumbing
  [ ] HVAC

Ceiling
  [x] Electrical
  [x] HVAC
```

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
- surface transition;
- entry/exit;
- vertical riser/drop.

### RouteSegment

A segment connects two nodes and describes one spatial installation section. Discipline-specific run segments reference this geometry and add physical characteristics such as cable/conduit properties, pipe diameter or duct dimensions.

### Junctions

A branching/distribution point is not modeled as a generic bend. Junction semantics are specialized by discipline: electrical junction box, plumbing tee/manifold, HVAC branch, network splitter, etc.

## Cross-discipline coordination

The 2.5D model must permit future clash detection without requiring full BIM in the first releases.

Possible inputs:

- route centerlines;
- physical run dimensions;
- z ranges;
- equipment bounding boxes;
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

## Backend boundary

The backend stores the cloud representation only when the user opts into sync/sharing. PostgreSQL stores structured data, spatial/layer revisions, permissions and metadata; S3-compatible storage holds PDFs, images, scans and other heavy artifacts.

Project QR sharing resolves through opaque share tokens and may expose either a live read-only model, discipline-specific collaboration access, or an immutable published project snapshot.
