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
- engineering layers reference the same `Floor`, `Room`, `Wall`, `Opening` and `RoomSurface` entities;
- discipline, project phase and installation status are independent dimensions;
- room height is resolved from project/floor defaults plus optional room overrides;
- structural height and finished ceiling height are distinct concepts;
- mounting surface and physical routing surface are separate concepts;
- engineering calculations are deterministic, versioned and testable offline;
- equipment definitions are extensible and data-driven;
- physical run length is derived from route topology, not treated as authoritative source data;
- domain and code identifiers use English language-neutral codes;
- navigation between wall/floor/ceiling surfaces is driven by explicit surface topology.

## Spatial core

```text
Project
Floor
Room
Zone
Wall
Opening
RoomSurface
SurfaceEdge
SurfaceAdjacency
Point3Mm
BoundingBox
MountingSurface
HeightProfile
SpatialRevision
```

The spatial core must not know whether a routed object is a cable, pipe or ventilation duct.

### RoomSurface

`RoomSurface` is a concrete editable surface belonging to a room.

Representative types:

```text
FLOOR
CEILING
WALL
CUSTOM
```

Each surface has its own identity and local 2D coordinate frame mapped to global project coordinates.

### SurfaceEdge

A `SurfaceEdge` is a concrete boundary of one `RoomSurface`. It exposes local 2D and world 3D start/end positions and may resolve to an adjacent surface.

All navigable edges are equivalent from the Spatial Core perspective. The editor may therefore navigate through:

```text
upper edge   -> adjacent ceiling-like surface
lower edge   -> adjacent floor-like surface
left edge    -> adjacent lateral wall
right edge   -> adjacent lateral wall
custom edge  -> any explicitly adjacent surface
```

These labels describe common UI orientation only. The actual relationship is always determined by `SurfaceAdjacency`.

### SurfaceAdjacency

`SurfaceAdjacency` captures topological continuity between concrete surfaces.

Examples:

```text
Wall A <-> Ceiling
Wall A <-> Floor
Wall A <-> Wall B
Wall A <-> Wall D
```

Adjacency is explicit so complex/non-rectangular rooms do not depend on hardcoded navigation assumptions.

### Surface navigation support

The engineering core provides the data needed for the editor to resolve:

```text
activeSurface
  -> candidate SurfaceEdge[]
  -> nearest/target edge
  -> adjacentSurface
```

The UI owns proximity thresholds, highlighting, preview opacity, fold animation and gesture interpretation.

When several edges are simultaneously close, such as near a corner, the core exposes the valid adjacency candidates while the editor selects a primary preview deterministically.

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

A route segment connects two nodes and provides reusable spatial geometry. Surface-bound segments reference a concrete `RoomSurface` through `surfaceId`.

This supports continuous transitions such as:

```text
Wall A segment
  -> SURFACE_TRANSITION
  -> Ceiling segment
```

and lateral transitions:

```text
Wall A segment
  -> SURFACE_TRANSITION
  -> Wall B segment
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

Vertical rises, drops and surface transitions are explicit route geometry, so changes to room height or equipment installation height can trigger deterministic recalculation.

## Collaboration compatibility

Layer objects retain their `layerId`, `discipline`, `revision` and `baseSpatialRevision` so local projects can later be synchronized and shared across specialists without duplicating geometry.

## Testing expectations

The engineering core should be testable without Flutter. Priority test areas:

- shared geometry and coordinate transforms;
- room surface local/world coordinate conversion;
- surface edge adjacency;
- lateral wall adjacency;
- corner cases with multiple adjacent edge candidates;
- room-height inheritance;
- layer/spatial revision compatibility;
- equipment port compatibility;
- route node/segment topology;
- surface-transition continuity;
- bend, transition and junction inference;
- discipline-specific run lengths;
- electrical conduit assignment/fill rules;
- electrical calculations;
- future pipe/duct topology contracts;
- BOM derivation.
