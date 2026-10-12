# Electra Engineering Core

Pure Dart package containing the engineering domain. It must not depend on Flutter widgets, mobile persistence, HTTP clients or Spring backend contracts.

## Planned modules

```text
geometry/
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
- engineering objects may have x/y/z semantics even when edited in a 2D UI;
- room height is resolved from project/floor defaults plus optional room override;
- mounting surface and cable-routing surface are separate concepts;
- engineering calculations are deterministic, versioned and testable offline;
- equipment definitions are extensible and data-driven rather than hardcoded enums for every appliance.

## Example domain concepts

- `MountingSurface`: WALL, CEILING, FLOOR, FURNITURE, FREE
- `RoutePlane`: CEILING, FLOOR, WALL, TRAY, CUSTOM
- `PointItem`: socket, switch, light, low-voltage point
- `EquipmentItem`: oven, dishwasher, air conditioner, curtain motor, boiler, pump, etc.
- `Circuit`: electrical grouping and protection metadata
- `Route`: ordered route segments with calculated physical length
