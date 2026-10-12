# Electra Technical Specification

## Product
Professional mobile planner for electrical and engineering systems.

## Platform
Cross-platform Flutter application for iOS, Android and tablets.

## Product architecture
Local-first with optional privacy-preserving cloud synchronization and sharing.

## Initial commercial focus
Electrical installation workflow first. HVAC, low-voltage, plumbing and heating are future domain modules built on the same geometry/editor foundation.

## Language strategy
All source code, domain names, database schema names, API contracts, enum/code values and technical documentation are English-first. User-facing strings must be localization-ready from the beginning. Domain codes remain language-neutral, for example `BATHROOM`, while display names are localized later.

## Core editor

The editor operates as a field-oriented CAD-lite tool:

- exact room dimensions;
- walls and complex room forms;
- doors and windows;
- metric units by default;
- snap/grid and precise object placement;
- undo/redo;
- autosave;
- project/floor/room hierarchy;
- plan, ceiling, floor and wall-elevation views;
- room default/custom heights;
- point installation height;
- mounting surface independent from cable routing plane.

The UI is 2D, but the engineering model is 2.5D: persisted engineering objects may carry `x`, `y` and `z` coordinates in millimetres.

## Room classification

A room is not identified only by a free-form name. It has a semantic category and type that can drive engineering defaults and future rule profiles.

### RoomCategory

- `RESIDENTIAL`
- `WET`
- `TECHNICAL`
- `COMMERCIAL`
- `OUTDOOR`
- `OTHER`

### Initial RoomType codes

Residential:
- `LIVING_ROOM`
- `BEDROOM`
- `KITCHEN`
- `DINING_ROOM`
- `HALLWAY`
- `WARDROBE`

Wet:
- `BATHROOM`
- `TOILET`
- `SHOWER`
- `LAUNDRY`

Technical:
- `GARAGE`
- `BOILER_ROOM`
- `ELECTRICAL_ROOM`
- `SERVER_ROOM`
- `STORAGE`

Commercial:
- `OFFICE`
- `SHOP`
- `WAREHOUSE`
- `WORKSHOP`

Outdoor:
- `BALCONY`
- `TERRACE`
- `YARD`
- `FACADE`

Extensibility:
- `CUSTOM`

Room type must be modeled as a data-driven definition so that recommended devices, defaults and future engineering rule profiles can be associated with the room without hardcoding every behavior into UI code.

## Room height model

```text
Project defaults
  -> Floor defaults
    -> Room overrides
```

The model distinguishes at least:

- structural height;
- finished ceiling height;
- per-room overrides;
- per-device installation height.

Effective values are resolved by inheritance. Structural and finished ceiling heights may diverge.

## Engineering objects

### Points
- sockets;
- switches;
- dimmers;
- junction boxes;
- cable outlets;
- TV/network/low-voltage points.

### Lighting
- ceiling luminaires;
- spots;
- LED strips;
- wall lights;
- tracks;
- furniture lighting.

### Equipment
- hob;
- oven;
- dishwasher;
- refrigerator;
- extractor hood;
- microwave;
- air conditioner indoor/outdoor units;
- curtain/blind motors;
- underfloor heating;
- thermostats;
- boilers;
- pumps;
- fans;
- smart relays and sensors.

Equipment definitions must be extensible and user-customizable through a `DeviceDefinition`-style catalog. Definitions may include category, default mounting surface, default installation height, nominal power, circuit recommendations and icon metadata.

### Mounting surfaces

- `WALL`
- `CEILING`
- `FLOOR`
- `FURNITURE`
- `FREE`

Mounting surface describes where an object is physically installed. It is independent from the physical path used by its cable.

## Cable routing domain

`Circuit.calculatedLength` must not be treated as primary route data. Physical routing is represented explicitly as a graph.

```text
Circuit
  -> CableRun
      -> Route
          -> RouteNode[]
          -> RouteSegment[]
```

### RouteNode

A route node represents a significant routing position with `xMm`, `yMm`, `zMm`.

Initial node types:

- `ENDPOINT`
- `BEND`
- `JUNCTION`
- `TRANSITION`
- `ENTRY`
- `EXIT`
- `RISER`

Bend nodes may be inferred automatically from adjacent segment geometry where possible.

### RouteSegment

A segment connects two route nodes and stores the physical path between them.

Important properties:

- `fromNodeId`;
- `toNodeId`;
- `layingMethod`;
- `mountingSurface` or route plane;
- calculated geometric length;
- optional physical channel reference;
- conduit requirement/default metadata.

A single cable may transition across different segment methods, for example tray -> ceiling conduit -> wall chase -> device.

### Laying methods / route channels

Initial concepts:

- `CEILING_FREE`
- `CONDUIT`
- `FLOOR_SCREED`
- `WALL_CHASE`
- `CABLE_TRAY`
- `DUCT`
- `SURFACE_MOUNTED`
- `UNDERGROUND`
- `CUSTOM`

### Route transitions

Engineering relationships between consecutive segments may include:

- straight continuation;
- 90-degree bend;
- custom bend;
- vertical rise;
- vertical drop;
- surface transition;
- room transition;
- floor transition.

These can be inferred where deterministic, but must remain representable in the domain.

## CableRun

A `CableRun` is the physical cable instance between electrical endpoints. It belongs to a circuit and references its route.

Representative properties:

- circuit;
- cable type;
- conductor count;
- cross-section;
- source endpoint;
- destination endpoint;
- route;
- reserve percentage;
- termination allowance;
- calculated total length.

The total cable length is derived from route geometry plus configured reserve and termination allowances.

## Junctions and distribution nodes

A junction is not merely a bend. Junction-specific semantics must be represented for branching/distribution.

Initial junction types:

- `JUNCTION_BOX`
- `DISTRIBUTION_BOX`
- `TEE`
- `SPLITTER`
- `TERMINAL_BOX`
- `PANEL_ENTRY`
- `FLOOR_BOX`
- `CEILING_BOX`

Junction metadata may include box type, dimensions, accessibility, mounting surface and installation height.

## Conduit and shared physical channels

Conduit must not be modeled only as `conduitRequired = true` on a cable. Multiple cable runs may share a physical conduit or tray.

```text
ConduitRun
  -> CableRun[]
```

Representative conduit properties:

- type/material;
- nominal diameter;
- allowed fill percentage;
- calculated fill percentage;
- route/segment association.

This enables future conduit fill validation, BOM calculation and shared-route optimization.

## Editor routing UX

The same room supports multiple views over the same data:

- Plan;
- Ceiling;
- Floor;
- Wall elevation.

Routing mode creates route nodes and segments from taps/drag operations. The UI should automatically infer common bends and convert intersecting/branching topology into junction semantics when possible.

Route rendering must distinguish laying methods using more than color alone, for example line pattern plus icon/legend, so printed and monochrome documentation remains understandable.

## Electrical module

- circuits;
- connected loads;
- cable sizing;
- breaker/RCD selection;
- voltage-drop and routing-aware calculations;
- electrical panel design;
- bill of materials;
- QR/label generation;
- offline PDF documentation.

Calculation rules must be versioned and isolated from UI code.

## Local data

SQLite/Drift stores structured project information. Heavy files remain in the filesystem. A user may keep hundreds or thousands of local projects; `project_id` acts as the logical partition key and indexes are designed around project/floor/room access patterns.

Route nodes, route segments, cable runs, conduit runs and junctions are persisted as normalized entities rather than a single route JSON blob so that geometry, BOM and validation can query them efficiently.

## Cloud sharing

If the user enables technical-data sharing, the backend stores a cloud representation of the technical project plus document metadata. Heavy artifacts live in S3-compatible storage.

A project QR stores an opaque share URL/token. It may resolve to:

- a live read-only project;
- an authenticated share;
- an immutable published snapshot.

Project PII sharing is controlled separately from technical documentation sharing.

## MVP vertical slice

1. Create project.
2. Create floor and room with exact dimensions and semantic room type.
3. Add walls/openings and room height.
4. Add sockets/switches/lights/equipment with installation height and mounting surface.
5. Create a circuit and physical cable run.
6. Route cable with explicit bend/transition nodes through ceiling/floor/wall.
7. Support at least one junction branch and optional conduit assignment.
8. Calculate route/cable length and basic protection/cable recommendation.
9. Generate BOM.
10. Generate labels/QR.
11. Export professional PDF.
