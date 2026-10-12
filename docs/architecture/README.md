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
9. Physical cable routing is modeled as graph topology, not as a single calculated length.

## High-level structure

```text
Flutter Mobile
    |
    +-- UI / Editor
    +-- SQLite / Drift
    +-- Sync Outbox
    |
    +--> Pure Dart Engineering Core
          +-- Geometry
          +-- Rooms / Environment
          +-- Equipment Catalog
          +-- Routing Graph
          +-- Cable / Conduit
          +-- Electrical Rules
          +-- Panel
          +-- BOM
          +-- Labels
          +-- Document Models

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
```

## Project hierarchy

```text
Project
  -> Floor
    -> Room
      -> Wall
      -> Opening
      -> PointItem / EquipmentItem
      -> Route topology
```

A room has an effective height resolved from project/floor defaults and optional room overrides.

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

The same room model can be presented using multiple engineering views:

- Plan
- Ceiling
- Floor
- Wall elevation

These are views over the same domain objects, not duplicated project data.

## Equipment model

Specific appliances must not require a new hardcoded domain class for every product type.

```text
DeviceDefinition
  -> category
  -> code
  -> defaultMountingSurface
  -> defaultInstallationHeight
  -> defaultPower
  -> circuit recommendations
  -> presentation metadata

PointItem / EquipmentItem
  -> deviceDefinitionCode
  -> x/y/z
  -> overrides
  -> circuit association
```

This supports standard devices such as sockets and switches as well as ovens, air conditioners, curtain motors, pumps, boilers and user-defined equipment.

## Routing topology

Electrical grouping, physical cable instances and physical routing are separate concepts.

```text
Circuit
  -> CableRun
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

A segment connects two nodes and describes one physical installation section. Laying method belongs to the segment because a single cable run may move through several installation methods.

Examples:

```text
panel
  -> cable tray
  -> ceiling conduit
  -> wall chase
  -> socket
```

Segment length is derived from node geometry.

### Junctions

A branching/distribution point is not modeled as a generic bend. Junction metadata may describe junction boxes, distribution boxes, splitters, panel entries, floor boxes and ceiling boxes.

### Physical channels

Cable and conduit are not the same object.

```text
ConduitRun
  -> CableRun[]
```

A physical conduit/tray may carry multiple cable runs. This allows fill calculation, BOM generation and shared-path analysis.

## Derived values

Values such as cable length are derived rather than authoritative source data.

```text
RouteNode positions
  + RouteSegments
  + vertical transitions
  + reserve
  + termination allowance
  = calculated cable length
```

Moving a device, changing room height or rerouting a segment therefore triggers deterministic recalculation instead of requiring manual length maintenance.

## Persistence boundary

SQLite/Drift persists normalized project entities and routing topology. Heavy binary content remains in the filesystem.

Primary local entities are expected to include:

```text
Project
Floor
Room
Wall
Opening
PointItem
EquipmentItem
Circuit
CableRun
Route
RouteNode
RouteSegment
Junction
ConduitRun
DocumentMetadata
SyncOutbox
```

`project_id` is the logical partition key for local project-scoped access. Physical SQLite table partitioning is not required.

## Backend boundary

The backend stores the cloud representation only when the user opts into sync/sharing. PostgreSQL stores structured data and metadata; S3-compatible storage holds PDFs, images, scans and other heavy artifacts.

Project QR sharing resolves through opaque share tokens and may expose either a live read-only model or an immutable published project snapshot.
