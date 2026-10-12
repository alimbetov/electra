# Electra Engineering Core

Pure Dart package containing the engineering domain. It must not depend on Flutter widgets, mobile persistence, HTTP clients or Spring backend contracts.

## Planned modules

```text
spatial/
network/
routing/
rooms/
equipment/
units/
validation/

electrical/
low_voltage/
cctv/
fire_alarm/
security/
access_control/
plumbing/
heating/
hvac/
gas/
drainage/
solar/
ev_charging/
```

Only the electrical vertical is implemented first. The other discipline modules are reserved architectural extension points.

## Core rules

- canonical geometry uses millimetres;
- persisted engineering objects may have x/y/z semantics even when edited in a 2D UI;
- shared project geometry is discipline-neutral;
- engineering layers reference the same shared spatial entities;
- room boundaries are polygonal and piecewise-planar rather than assumed globally flat;
- discipline, project phase and installation status are independent dimensions;
- room height is resolved from project/floor defaults plus optional room overrides;
- local patch geometry may override actual local floor/ceiling elevation;
- structural height and finished ceiling height are distinct concepts;
- mounting surface type and exact physical surface patch are separate concepts;
- engineering calculations are deterministic, versioned and testable offline;
- equipment definitions are extensible and data-driven;
- physical run length is derived from route topology, not treated as authoritative source data;
- domain and code identifiers use English language-neutral codes;
- navigation between surfaces is driven by explicit patch/edge topology.

## Spatial core

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

The spatial core must not know whether a routed object is a cable, pipe or ventilation duct.

## Piecewise-planar geometry

`RoomSurface` is a logical surface grouping such as a room floor, ceiling or wall. A logical surface may contain multiple planar `SurfacePatch` objects.

```text
RoomSurface
  -> SurfacePatch[]
       -> SurfaceEdge[]
```

Each `SurfacePatch` is a bounded planar polygon and owns a deterministic local 2D coordinate frame mapped to global project coordinates.

Representative patch data:

```text
SurfacePatch
  id
  surfaceId
  boundary
  localCoordinateFrame
  plane
  normal
  elevation/orientation
```

This supports geometry such as:

```text
CeilingSurface
  -> main horizontal patch
  -> vertical beam/soffit side patch
  -> lower underside patch

FloorSurface
  -> main floor patch
  -> vertical step patch
  -> raised platform patch

WallSurface
  -> main wall patch
  -> niche return patch
  -> niche back patch
```

Supported initial geometry includes horizontal, vertical and sloped planes with polygonal boundaries and explicit folds/steps.

Free-form mesh editing, NURBS and BIM-grade solid modeling are intentionally out of scope initially.

## Spatial features

Semantically meaningful construction geometry is represented as `SpatialFeature`.

Initial types:

```text
BEAM
COLUMN
SOFFIT
NICHE
SHAFT
STEP
PLATFORM
RECESS
PROTRUSION
CUSTOM
```

A feature may own/generate one or more patches. For example a beam may expose bottom, side and end patches.

Feature identity is retained for measurements, annotations, routing constraints, clash detection and documentation.

## SurfaceEdge

A `SurfaceEdge` is a concrete boundary of one `SurfacePatch`. It exposes local 2D and world 3D start/end positions and may resolve to an adjacent patch/surface.

All navigable edges are equivalent from the Spatial Core perspective. Common examples include:

```text
wall upper edge   -> ceiling patch
wall lower edge   -> floor patch
wall lateral edge -> adjacent wall patch
ceiling edge      -> beam/soffit side patch
floor edge        -> step/platform patch
custom edge       -> explicitly adjacent patch
```

These labels describe common UI orientation only. The actual relationship is always determined by topology.

## SurfaceAdjacency

`SurfaceAdjacency` captures topological continuity between concrete patches/surfaces.

Examples:

```text
Wall A patch <-> Ceiling patch
Wall A patch <-> Floor patch
Wall A patch <-> Wall B patch
Ceiling patch <-> Beam side patch
Beam side patch <-> Beam underside patch
Floor patch <-> Step face patch
Step face patch <-> Raised floor patch
```

Adjacency is explicit so complex/non-rectangular rooms do not depend on hardcoded navigation assumptions.

## Surface navigation support

The engineering core provides the data needed for the editor to resolve:

```text
activeSurface
activePatch
  -> candidate SurfaceEdge[]
  -> nearest/target edge
  -> adjacentPatch
  -> adjacentSurface
```

The UI owns proximity thresholds, highlighting, preview opacity, fold animation and gesture interpretation.

When several edges are simultaneously close, such as near a corner, the core exposes valid adjacency candidates while the editor selects a primary preview deterministically.

The navigation state is presentation/application state and may include:

```text
activeSurfaceId
activePatchId
previewSurfaceId?
previewPatchId?
nearestEdgeId?
proximity
```

## Coordinate conversion

Every patch must support exact conversion:

```text
Point2Mm localToWorld(Point2Mm local) -> Point3Mm
Point2Mm worldToLocal(Point3Mm world) -> Point2Mm
```

The precise API shape may differ, but the transformation must be deterministic and reversible within accepted numeric tolerance.

This is required for:

- placement;
- measurements;
- snap;
- surface transitions;
- route lengths;
- clash detection;
- exports.

## Engineering layers

```text
EngineeringLayer
  -> discipline
  -> revision
  -> baseSpatialRevision
```

Reserved disciplines include:

- `ARCHITECTURE`
- `ELECTRICAL`
- `LOW_VOLTAGE`
- `CCTV`
- `FIRE_ALARM`
- `SECURITY`
- `ACCESS_CONTROL`
- `PLUMBING`
- `HEATING`
- `HVAC`
- `GAS`
- `DRAINAGE`
- `SOLAR`
- `EV_CHARGING`

Object lifecycle dimensions remain separate:

```text
Phase = EXISTING | DEMOLITION | NEW | TEMPORARY
InstallationStatus = PLANNED | APPROVED | INSTALLED | TESTED | COMMISSIONED
```

## Room domain

```text
Room
  -> RoomCategory
  -> RoomTypeDefinition
  -> HeightProfile
```

Initial `RoomCategory` values:

- `RESIDENTIAL`
- `WET`
- `TECHNICAL`
- `COMMERCIAL`
- `OUTDOOR`
- `OTHER`

`RoomTypeDefinition` is data-driven and may provide recommended devices, environmental defaults and future rule-profile references.

## Equipment and ports

```text
DeviceDefinition
  -> PortDefinition[]

EquipmentItem
  -> EquipmentPort[]
```

Representative port types:

```text
POWER
CONTROL
DATA
ETHERNET
ETHERNET_POE
COLD_WATER
HOT_WATER
DRAIN
SUPPLY
RETURN
REFRIGERANT_IN
REFRIGERANT_OUT
AIR_SUPPLY
AIR_RETURN
```

A device can therefore participate in several disciplines at once. For example an air-conditioner indoor unit can expose power, control, refrigerant and drain ports.

Exact placement on construction geometry references a `surfacePatchId` when surface-bound.

## Network core

The generic network layer captures connectivity/topology without absorbing discipline-specific physics.

```text
EngineeringNetwork
NetworkNode
Endpoint
Port
Run
RouteBinding
```

Representative topologies include:

- `LINE`
- `STAR`
- `TREE`
- `RING`
- `BUS`

Specialized runs remain strongly typed:

```text
Electrical  -> CableRun
Plumbing    -> PipeRun
Heating     -> HeatingLoop / PipeRun
Ventilation -> DuctRun
CCTV        -> CableRun / DataRun
Fire alarm  -> FireLoop / CableRun
```

Do not replace these types with one generic JSON property bag.

## Routing graph

```text
Run
  -> Route
      -> RouteNode[]
      -> RouteSegment[]
```

### RouteNode

Representative types:

- `ENDPOINT`
- `BEND`
- `JUNCTION`
- `SURFACE_TRANSITION`
- `ENTRY`
- `EXIT`
- `RISER`

A route node carries `xMm`, `yMm`, `zMm`.

### RouteSegment

A route segment connects two nodes and provides reusable spatial geometry. Surface-bound segments reference the exact `SurfacePatch` through `surfacePatchId`.

This supports continuous transitions such as:

```text
Wall patch
  -> SURFACE_TRANSITION
  -> Ceiling patch
```

lateral transitions:

```text
Wall A patch
  -> SURFACE_TRANSITION
  -> Wall B patch
```

and construction-feature transitions:

```text
Ceiling patch
  -> SURFACE_TRANSITION
  -> Beam side patch
  -> SURFACE_TRANSITION
  -> Beam underside patch
```

A discipline-specific run references the route and adds physical properties.

Examples:

```text
CableRunSegment -> cable/conduit properties
PipeRunSegment  -> diameter/material/insulation
DuctRunSegment  -> width/height/diameter/orientation
```

### Junctions

Junction topology is shared, while junction semantics are discipline-specific:

```text
Electrical -> junction box / splitter
Plumbing   -> tee / manifold
HVAC       -> branch / plenum
Network    -> switch / splitter
```

## Electrical conduit

`ConduitRun` represents a physical conduit/channel and may carry multiple `CableRun` instances.

```text
ConduitRun
  -> CableRun[]
```

This enables conduit-fill validation, shared-route analysis and material calculation.

## Derived length

```text
sum(RouteSegment geometric lengths)
+ discipline-specific allowances
= calculated physical run length
```

Vertical rises, drops and patch/surface transitions are explicit route geometry, so changes to room geometry or equipment placement trigger deterministic recalculation.

## Spatial revision compatibility

`SurfacePatch`, `SurfaceEdge`, `SurfaceAdjacency` and `SpatialFeature` belong to the shared spatial model.

Any geometry edit that changes their topology or coordinates participates in `SpatialRevision`. Engineering layers retain `baseSpatialRevision` so they can detect stale routing/placement after shared geometry changes.

## Validation expectations

The Spatial Core should validate at least:

- planar patch validity;
- non-degenerate polygon boundaries;
- valid local/world transformations;
- surface-edge ownership;
- adjacency consistency/symmetry where applicable;
- required shared-edge coincidence within tolerance;
- feature-generated patch ownership;
- invalid gaps/overlaps where topology requires continuity;
- route transition location on valid adjacent boundaries.

## Collaboration compatibility

Layer objects retain their `layerId`, `discipline`, `revision` and `baseSpatialRevision` so local projects can later be synchronized and shared across specialists without duplicating geometry.

## Testing expectations

The engineering core should be testable without Flutter. Priority test areas:

- shared geometry and coordinate transforms;
- polygonal surface patch validation;
- horizontal, vertical and sloped patches;
- room surface local/world coordinate conversion;
- patch/edge adjacency;
- lateral wall adjacency;
- beam/soffit/step topology;
- corner cases with multiple adjacent edge candidates;
- room-height inheritance plus local patch elevation;
- spatial feature ownership;
- layer/spatial revision compatibility;
- equipment port compatibility;
- route node/segment topology;
- surface/patch-transition continuity;
- routes crossing beam/step/sloped geometry;
- bend, transition and junction inference;
- discipline-specific run lengths;
- electrical conduit assignment/fill rules;
- electrical calculations;
- future pipe/duct topology contracts;
- BOM derivation.
