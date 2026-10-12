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
- edge-driven navigation between adjacent room surfaces;
- progressive neighbor-surface preview near all valid edges;
- tap-to-activate adjacent wall/floor/ceiling/feature surface;
- room default/custom heights;
- point installation height;
- mounting surface independent from routing path.

The UI is 2D, but the engineering model is 2.5D: persisted engineering objects may carry `x`, `y` and `z` coordinates in millimetres.

## Piecewise-planar room geometry

Room boundaries are not assumed to be globally flat or rectangular. Walls, floors and ceilings are represented using polygonal piecewise-planar geometry.

```text
Room
  -> RoomSurface[]
       -> SurfacePatch[]
            -> SurfaceEdge[]
  -> SpatialFeature[]
```

A logical surface such as a ceiling or floor may contain several planar patches with different elevations or orientations.

Examples:

```text
Ceiling
  -> main horizontal patch at 2700 mm
  -> vertical soffit/beam side patch
  -> underside patch at 2400 mm

Floor
  -> main patch at 0 mm
  -> vertical step face
  -> raised patch at 150 mm
```

A `SurfacePatch` is an exact bounded planar polygon with a local 2D coordinate system mapped to global 3D project coordinates.

The initial geometry scope includes:

- horizontal planes;
- vertical planes;
- sloped planes;
- polygonal boundaries;
- folds and steps;
- lowered/raised zones;
- beams and soffits;
- niches and recesses;
- columns and shafts;
- platforms and protrusions.

Full free-form BIM/NURBS/mesh editing is not required for the initial product.

## Spatial features

Construction geometry with useful semantic identity is represented as `SpatialFeature`.

Initial feature types:

- `BEAM`;
- `COLUMN`;
- `SOFFIT`;
- `NICHE`;
- `SHAFT`;
- `STEP`;
- `PLATFORM`;
- `RECESS`;
- `PROTRUSION`;
- `CUSTOM`.

A feature may own/generate multiple surface patches. For example, a beam may expose side, bottom and end patches that can be used for placement and routing.

## Edge-driven navigation

The editor uses the geometry itself as the primary navigator.

When the pointer/touch approaches any valid edge of the active patch:

```text
far        -> no preview
near       -> weak edge highlight
closer     -> adjacent patch preview
very close -> strong preview / snap hint
tap        -> adjacent patch becomes active
```

This applies to all valid edges, including lateral wall edges.

Typical wall interaction:

```text
            CEILING
               ^
               |
WALL D <- WALL A -> WALL B
               |
               v
             FLOOR
```

The actual target is always resolved from explicit surface adjacency, not hardcoded orientation assumptions.

Around beams, niches, steps or other piecewise-planar geometry the same model applies:

```text
ceiling
  -> beam side
  -> beam underside
  -> opposite beam side
  -> ceiling
```

The adjacent surface may be shown as a progressive folded preview around an intermediate 45-degree visual angle. Fold angle is UI-only state.

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
- per-device installation height;
- local patch elevation/orientation.

Effective defaults are resolved by inheritance, while local piecewise-planar geometry may alter the actual usable floor/ceiling elevation at a specific location.

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

The generic mounting type describes the category; exact placement references a concrete `SurfacePatch` where applicable.

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
- `SURFACE_TRANSITION`
- `ENTRY`
- `EXIT`
- `RISER`

Bend nodes may be inferred automatically from adjacent segment geometry where possible.

### RouteSegment

A segment connects two route nodes and stores the physical path between them.

Important properties:

- `fromNodeId`;
- `toNodeId`;
- `surfacePatchId` when surface-bound;
- `layingMethod`;
- calculated geometric length;
- optional physical channel reference;
- conduit requirement/default metadata.

A single cable may transition across different methods and different patches, for example tray -> ceiling -> beam side -> beam underside -> wall chase -> device.

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
- surface/patch transition;
- room transition;
- floor transition.

When the user taps/crosses an adjacent edge during route drawing, the route operation remains active and a `SURFACE_TRANSITION` is created/reused at the shared boundary.

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

The total cable length is derived from exact route geometry plus configured reserve and termination allowances.

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
- `CEILING_BOX`.

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

## Editor routing UX

Routing mode creates route nodes and segments from taps/drag operations. The UI should automatically infer common bends and convert intersecting/branching topology into junction semantics when possible.

Surface navigation is continuous while routing: selecting an adjacent patch does not terminate the active drawing operation.

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

Spatial and routing entities are normalized rather than stored as one large JSON blob.

Expected spatial entities include:

```text
room_surface
surface_patch
surface_edge
surface_adjacency
spatial_feature
```

Route nodes, route segments, cable runs, conduit runs and junctions are also persisted as normalized entities.

All edits to shared geometry, including feature/patch changes, participate in `SpatialRevision` so engineering layers can detect that their base geometry changed.

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
3. Add walls/openings, room height and simple surface patches.
4. Navigate between floor/walls/ceiling by approaching and tapping adjacent edges.
5. Represent at least one non-flat feature such as a beam, soffit, step or sloped patch.
6. Add sockets/switches/lights/equipment with installation height and exact mounting patch.
7. Create a circuit and physical cable run.
8. Route cable with explicit bend/transition nodes continuously across adjacent patches.
9. Support at least one junction branch and optional conduit assignment.
10. Calculate route/cable length and basic protection/cable recommendation.
11. Generate BOM.
12. Generate labels/QR.
13. Export professional PDF.
