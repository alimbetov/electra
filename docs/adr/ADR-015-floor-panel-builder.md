# ADR-015: Per-Floor Electrical and Automation Panel Builder

## Status
Accepted

## Context

Electra should ultimately consolidate room/floor loads into constructible electrical distribution boards and automation/control cabinets. A floor-level panel builder must not be a decorative one-line diagram editor only; it must be backed by circuits, protection, devices, terminals, rails, busbars, phase assignment, physical module occupancy and field documentation.

The initial electrical vertical needs a model that can later serve residential distribution boards, commercial floor panels and industrial automation cabinets.

## Decision

Electra introduces a generic `PanelAssembly` model with electrical-distribution and automation/control specializations.

```text
Project
└── Floor
    └── PanelAssembly[]
        ├── incoming supply
        ├── busbars
        ├── DIN rails / mounting rails
        ├── panel modules
        ├── terminal blocks
        ├── outgoing circuits
        ├── automation I/O
        └── documentation
```

A floor may own one or more panels. Panels may also be building-level, room-level or machine-level; floor scope is a common default, not a hard limitation.

## Panel types

Initial conceptual types:

```text
DISTRIBUTION_BOARD
FLOOR_DISTRIBUTION_BOARD
AUTOMATION_PANEL
MOTOR_CONTROL_PANEL
PLC_PANEL
MIXED_CONTROL_POWER_PANEL
CUSTOM
```

## Panel assembly

Representative `PanelAssembly` data:

```text
id
code
displayName
projectId
floorId?
roomId?
panelType
systemVoltage
supplySystem
ratedCurrentA?
ipRating?
enclosureDefinitionId?
revision
```

The assembly owns physical layout and electrical/control topology.

## Incoming supply

A panel may define:

```text
IncomingSupply
- sourcePanelId?
- sourceCircuitId?
- supplySystem
- phaseConfiguration
- designCurrentA
- protectiveDeviceId?
- cableRunId?
```

This allows a hierarchy such as:

```text
MDB
-> Floor DB 01
-> Floor DB 02
-> Automation Panel F02
-> Machine Panel M-101
```

## Panel component library

Panel components are `ComponentDefinition` records from the relevant layer library rather than hardcoded widgets.

Typical component families include:

```text
MCB
MCCB
RCD
RCBO
SPD
contactor
motor protection breaker
overload relay
fuse holder
isolator
power supply 24 VDC
PLC
remote I/O
VFD
soft starter
relay
interface relay
terminal block
bus coupler
Ethernet switch
meter
energy meter
current transformer
phase monitor
surge protection
busbar
neutral bar
PE bar
```

System, user, project and imported/manufacturer definitions remain supported.

## Physical layout

The panel builder models real mounting capacity.

```text
PanelAssembly
-> MountingSection[]
   -> DinRail[]
      -> PanelModulePlacement[]
```

A component definition may provide:

```text
moduleWidthUnits?
widthMm?
heightMm?
depthMm?
mountingType
heatDissipationW?
requiredClearanceMm?
```

The builder must validate at least:

- available rail/module capacity;
- enclosure dimensions where known;
- reserved spare capacity;
- incompatible placements;
- required clearance when rules exist.

## Electrical topology

A panel is not defined only by visual placement.

```text
Incoming Supply
-> Main Protection / Isolation
-> Busbar
-> Branch Protection
-> Circuit
-> CableRun
-> Load
```

Automation/control topology may additionally include:

```text
24 VDC PSU
-> PLC / Remote I/O
-> terminal blocks
-> field sensors / actuators
```

Power and control circuits remain distinct but may coexist in a mixed panel.

## Circuit assignment

The floor panel builder consumes circuit proposals and confirmed circuits from rooms/equipment on the floor.

Representative flow:

```text
Floor loads
-> CircuitPlanner
-> confirmed Circuit[]
-> assign to Floor Panel
-> choose protection
-> choose cable
-> phase allocation
-> terminal allocation
-> physical module placement
```

Unassigned circuits must remain visible as an explicit validation error/warning.

## Phase balancing

For three-phase panels, single-phase outgoing circuits should be assignable across L1/L2/L3 with a `PhaseBalancer` recommendation.

The UI should expose:

```text
L1 connected/design load
L2 connected/design load
L3 connected/design load
imbalance indicator
```

Automatic suggestions remain reviewable and user-confirmed rather than silently authoritative.

## Protection and sizing

The panel builder integrates future engines rather than duplicating electrical formulas:

```text
CircuitPlanner
CableSizingEngine
ProtectionCoordinator
PhaseBalancer
PanelValidator
```

A versioned ruleset provides jurisdiction/standard-specific values.

## Automation panel support

Automation cabinets require additional model elements:

```text
ControlPowerSupply
PLC / Controller
IOModule
SignalChannel
TerminalBlock
Terminal
NetworkDevice
Relay
Contactor
VFD / SoftStarter
```

Example:

```text
PLC CPU
├── DI module
│   ├── DI01 <- level switch
│   └── DI02 <- motor feedback
├── DO module
│   └── DO01 -> contactor K1
├── AI module
│   └── AI01 <- pressure transmitter
└── Ethernet
    └── VFD-101
```

The panel builder should eventually generate I/O schedules from these assignments.

## Terminal planning

Terminal allocation is first-class:

```text
CableCore
-> Terminal
-> internal wire / module channel
```

This enables:

- terminal plans;
- cable schedules;
- wire/core labels;
- commissioning traceability.

## Builder UX

The visual language remains dry engineering drafting, consistent with the room editor.

Recommended composition:

```text
+----------------------------------------------------------------+
| Floor 02 / Panel AP-F02 | 400/230 V | revision | validation    |
+----------+------------------------------------------+-----------+
| Library  |                                          | Context   |
|          |           PANEL / DIN RAIL CANVAS        | slide     |
| MCB      |                                          |           |
| RCD      | [Q0][SPD][Q1][Q2][Q3] ...               |           |
| PLC      | [PSU][CPU][DI][DO][AI] ...              |           |
| Terminal | [X1........................]             |           |
+----------+------------------------------------------+-----------+
| circuits | phase load | spare capacity | warnings | BOM        |
+----------------------------------------------------------------+
```

Like the room editor, only the active context panel should be visible. The builder should support drag/place for module layout, but electrical connectivity and validation are driven by domain data.

## Floor workflow

A useful floor-level workflow is:

```text
rooms/equipment complete
-> collect floor loads
-> propose/split circuits
-> assign circuits to floor panel
-> size feeders/outgoing cables
-> select protection
-> balance phases
-> lay out DIN modules
-> allocate terminals
-> validate spare capacity
-> generate panel schedule/BOM/labels
```

## Outputs

The panel builder should eventually produce:

```text
panel schedule
single-line diagram
DIN rail layout
terminal plan
I/O schedule
cable schedule
protection schedule
phase/load summary
BOM
labels / QR
commissioning checklist
PDF documentation
```

## Validation

Representative validation categories:

```text
unassigned circuit
panel overload
phase imbalance
insufficient module capacity
missing main isolation/protection
protection/cable coordination issue
missing PE/N termination
terminal capacity exceeded
missing spare capacity target
routing/segregation conflict
missing field termination
```

## Spare capacity

Panel design should support explicit reserve targets rather than filling the enclosure to 100 percent.

Possible project policy examples:

```text
minimum spare DIN modules
minimum spare terminal capacity
minimum spare current/load allowance
reserved future feeders
```

Exact numeric thresholds belong to project/ruleset configuration, not hardcoded product constants.

## Consequences

The panel builder becomes the aggregation point connecting room design, circuits, industrial equipment, cable routing, field installation and reporting. It should be implemented after stable circuits/routing/persistence, but its contracts are established now so earlier entities do not block later panel design.