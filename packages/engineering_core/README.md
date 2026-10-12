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
- engineering layers reference the same `Floor`, `Room`, `Wall` and `Opening` entities;
- discipline, project phase and installation status are independent dimensions;
- room height is resolved from project/floor defaults plus optional room overrides;
- structural height and finished ceiling height are distinct concepts;
- mounting surface and physical routing surface are separate concepts;
- engineering calculations are deterministic, versioned and testable offline;
- equipment definitions are extensible and data-driven;
- physical run length is derived from route topology, not treated as authoritative source data;
- domain and code identifiers use English language-neutral codes.

## Spatial core

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
SpatialRevision
```

The spatial core must not know whether a routed object is a cable, pipe or ventilation duct.

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
- `TRANSITION`
- `ENTRY`
- `EXIT`
- `RISER`

A route node carries `xMm`, `yMm`, `zMm`.

### RouteSegment

A route segment connects two nodes and provides reusable spatial geometry. A discipline-specific run references the route and adds physical properties.

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

Vertical rises and drops are explicit route geometry, so changes to room height or equipment installation height can trigger deterministic recalculation.

## Collaboration compatibility

Layer objects retain their `layerId`, `discipline`, `revision` and `baseSpatialRevision` so local projects can later be synchronized and shared across specialists without duplicating geometry.

## Testing expectations

The engineering core should be testable without Flutter. Priority test areas:

- shared geometry and coordinate transforms;
- room-height inheritance;
- layer/spatial revision compatibility;
- equipment port compatibility;
- route node/segment topology;
- bend, transition and junction inference;
- discipline-specific run lengths;
- electrical conduit assignment/fill rules;
- electrical calculations;
- future pipe/duct topology contracts;
- BOM derivation.
