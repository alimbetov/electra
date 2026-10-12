# Electra Engineering Core

Pure Dart package containing the engineering domain. It must not depend on Flutter widgets, mobile persistence, HTTP clients or Spring backend contracts.

## Planned modules

```text
geometry/
rooms/
routing/
electrical/
equipment/
panel/
materials/
labels/
units/
validation/
```

## Core rules

- canonical geometry uses millimetres;
- persisted engineering objects may have x/y/z semantics even when edited in a 2D UI;
- room height is resolved from project/floor defaults plus optional room overrides;
- structural height and finished ceiling height are distinct concepts;
- mounting surface and cable-routing surface are separate concepts;
- engineering calculations are deterministic, versioned and testable offline;
- equipment definitions are extensible and data-driven rather than hardcoded classes/enums for every appliance;
- cable length is derived from route topology, not treated as source data;
- circuits, physical cable runs, physical routes and conduits are separate concepts;
- domain and code identifiers use English language-neutral codes.

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

## Height model

```text
Project defaults
  -> Floor defaults
    -> Room overrides
```

Device installation height is independent from room height. For example, a wall socket can be at `z=300`, a switch at `z=900`, and a ceiling light at the resolved finished ceiling height.

## Equipment model

Representative concepts:

- `MountingSurface`: WALL, CEILING, FLOOR, FURNITURE, FREE
- `DeviceDefinition`: reusable catalog definition with defaults
- `PointItem`: socket, switch, light, low-voltage point
- `EquipmentItem`: oven, dishwasher, air conditioner, curtain motor, boiler, pump, etc.

User-specific equipment should be expressible through custom definitions without changing the domain package.

## Routing graph

```text
Circuit
  -> CableRun
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

A route segment connects two nodes and carries physical installation semantics such as laying method/route channel.

Representative laying methods:

- `CEILING_FREE`
- `CONDUIT`
- `FLOOR_SCREED`
- `WALL_CHASE`
- `CABLE_TRAY`
- `DUCT`
- `SURFACE_MOUNTED`
- `UNDERGROUND`
- `CUSTOM`

A single cable run may traverse multiple segment types.

### Junctions

Junctions are first-class branching/distribution semantics rather than ordinary bends. Examples include junction boxes, distribution boxes, splitters, panel entries, floor boxes and ceiling boxes.

### Conduit

`ConduitRun` represents a physical conduit/channel and may carry multiple `CableRun` instances.

```text
ConduitRun
  -> CableRun[]
```

This separation enables conduit-fill validation, shared-route analysis and material calculation.

## Derived cable length

```text
sum(RouteSegment geometric lengths)
+ reserve
+ termination allowance
= CableRun calculated length
```

Vertical rises and drops are explicit route geometry, so changes to room height or device installation height can trigger deterministic recalculation.

## Testing expectations

The engineering core should be testable without Flutter. Priority test areas:

- geometry and coordinate transforms;
- room-height inheritance;
- route node/segment topology;
- bend and transition inference;
- junction branching;
- cable-length calculation;
- conduit assignment/fill rules;
- electrical calculations;
- BOM derivation.
