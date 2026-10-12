# ADR-019: Physical panel layout editor models enclosure geometry, rows and rail length

## Status
Accepted

## Context

The panel builder must support the physical arrangement of electrical distribution boards and automation cabinets, not only circuit assignment and abstract DIN module counts.

Engineers need to reason about:

- enclosure width, height and depth;
- number of mounting rows;
- usable DIN rail length per row;
- module occupancy and spare capacity;
- physical device width in millimetres where relevant;
- terminal rails and busbar zones;
- cable ducts / wiring channels;
- reserved and forbidden installation zones;
- row ordering and device grouping;
- future service and heat-clearance constraints.

A simple `capacityModules` integer is insufficient for realistic board/cabinet layout.

## Decision

Introduce an explicit physical layout model under `PanelAssembly`.

```text
PanelAssembly
├── enclosureGeometry
├── MountingSection[]
│   ├── DinRail[]
│   │   └── PanelModulePlacement[]
│   ├── TerminalRail[]
│   ├── CableDuct[]
│   └── ReservedZone[]
└── validation
```

## Enclosure geometry

```text
PanelEnclosureGeometry
- widthMm
- heightMm
- depthMm
- usableWidthMm?
- usableHeightMm?
```

The enclosure definition may originate from a system, user, project or manufacturer component library.

Exact enclosure dimensions are data-driven; no universal cabinet dimensions are hardcoded.

## Row model

A mounting section may contain ordered rows.

```text
PanelMountingSection
- id
- name
- rows[]
```

Each DIN rail row is explicitly indexed and has both logical and physical capacity:

```text
DinRail
- id
- rowIndex
- railLengthMm
- capacityModules
- modulePitchMm?
- placements[]
```

`capacityModules` is convenient for modular devices while `railLengthMm` supports non-standard and automation devices whose width is better represented physically.

Module pitch must come from a component/manufacturer/ruleset definition when needed rather than being assumed globally.

## Placement model

```text
PanelModulePlacement
- componentDefinitionId
- position
- moduleWidthUnits
- physicalWidthMm?
```

A placement must not exceed either the modular capacity or physical rail length when both are known.

The editor should support:

- drag/reorder within a row;
- move between rows;
- insert before/after another device;
- reserve explicit free positions;
- auto-pack as a suggestion;
- manual override with validation.

## Reserved and forbidden zones

The physical layout may include zones such as:

```text
MAIN_INCOMING
BUS_BAR
PE_N_BAR
TERMINALS
PLC_IO
CONTROL_POWER
CABLE_DUCT
SPARE
NO_MOUNT
CUSTOM
```

These zones are layout constraints, not merely decoration.

## Cable ducts / wiring channels

Automation and control panels require internal wire routing space.

Representative model:

```text
PanelCableDuct
- id
- orientation
- widthMm
- lengthMm
- sectionId
```

Detailed internal wire routing is a future capability, but space for ducts must be representable from the beginning so cabinet layouts do not consume all physical area with components.

## Editor UX

The physical panel editor uses a front-elevation technical view.

```text
+-----------------------------------------------------------+
| AP-F02 | 800 x 1200 x 300 mm | 4 rows | validation       |
+----------+-----------------------------------+-------------+
| Library  |                                   | Context     |
|          | Row 1  [Q0][SPD][Q1][Q2][----]   | Device      |
| MCB      |        540 mm rail                | properties  |
| RCD      |                                   |             |
| PLC      | Row 2  [PSU][CPU][DI][DO][AI]    |             |
| Terminal |                                   |             |
| Duct     | Row 3  [K1][K2][OL][relay...]     |             |
| Reserve  |                                   |             |
|          | X1 terminal rail                  |             |
+----------+-----------------------------------+-------------+
| Row: 3/4 | modules used | mm used | spare | warnings      |
+-----------------------------------------------------------+
```

The user must be able to edit:

- enclosure dimensions/definition;
- row count;
- row order;
- DIN rail length;
- module capacity where applicable;
- reserved/spare zones;
- terminal rail placement;
- cable duct placement;
- component position and grouping.

## Validation

At minimum, the physical panel validator must detect:

- module capacity overflow;
- rail physical-length overflow;
- overlapping placements;
- device outside usable enclosure bounds;
- insufficient spare target;
- missing/invalid mounting section;
- placement in forbidden/reserved zone;
- required clearance violation when a rule is available.

Future validation may add thermal, EMC and segregation constraints.

## Outputs

The physical layout must be reusable for:

- panel front-elevation drawing;
- DIN rail layout sheet;
- device labels;
- BOM quantities;
- installation instructions;
- as-built comparison;
- commissioning documentation.

## Consequences

Positive:

- panel design becomes constructible rather than schematic-only;
- residential boards and industrial automation cabinets share one extensible model;
- manufacturer-specific enclosures and devices can be represented without hardcoded dimensions;
- row/module/spare validation becomes deterministic.

Trade-offs:

- physical layout adds another coordinate/capacity domain inside the panel builder;
- enclosure and component dimensions must be managed as catalog data;
- later thermal/segregation rules will require richer validation.
