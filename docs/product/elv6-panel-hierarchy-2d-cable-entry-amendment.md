# ELV6 — Panel Hierarchy, 2D Cabinet Editor & Cable-Entry Amendment

Status: **DESIGN AMENDMENT / RUNTIME NOT CLAIMED / ACCEPTANCE NOT CLAIMED**

This amendment is normative for future ELV6 runtime entry. Where older ELV6 prose is silent or less specific about panel hierarchy, cabinet 2D layout, cable entry or internal routing, this amendment supplies the required contract. Contradictions require explicit reconciliation; implementation MAY NOT choose an arbitrary interpretation.

## 1. Ownership

ELV6 owns physical enclosure/layout evidence. It does not redefine canonical cable identity, electrical fault physics, normative authority or exact commercial SKU selection.

```text
canonical cable/topology facts      -> upstream electrical / ELV3 owners
panel physical hierarchy/layout     -> ELV6
cable entry/internal cabinet route  -> ELV6
normative applicability             -> ELV7
exact SKU/catalog selection         -> ELV8
short-circuit/disturbance physics   -> shared electrical study producer
```

## 2. Modular panel hierarchy

ELV6 MUST support hierarchical distribution, not a flat list of cabinets.

```text
GRID / TR / GEN
      ↓
MDB / MAIN BOARD
      ↓
FLOOR DISTRIBUTION BOARD
      ↓
LOCAL / SYSTEM / MACHINE PANEL
      ↓
CIRCUITS
      ↓
LOADS
```

A parent-child relation MUST represent a real feeder path:

```text
parent bus
 -> outgoing protection
 -> feeder circuit
 -> cable / busduct
 -> child incomer
 -> child bus
```

A plain `parentPanelId` is insufficient engineering evidence.

### 2.1 Repeated-floor modularity

Target objects:

```text
PanelModuleTemplate
PanelModuleInstance
PanelInstanceOverride
PanelHierarchyNode
PanelFeederBinding
```

A template MAY be instantiated across repeated floors. Instance-specific differences MUST be explicit overrides. Updating a template MUST NOT silently rewrite frozen or accepted instances.

### 2.2 Bottom-up / top-down behavior

Bottom-up roll-up SHALL support connected load, demand load, phase totals, critical/normal/emergency classifications and scenario-specific contributions.

Diversity/simultaneity MUST have explicit ownership so it is not applied repeatedly at each hierarchy level.

Top-down constraints MAY include feeder maximum current, voltage-drop budget, source capacity, short-circuit evidence and reserve policy. A child panel candidate that violates an upstream hard constraint is not valid.

## 3. 2D Panel & Cabinet Editor — mandatory ELV6 target

The 2D editor is a first-class ELV6 capability, not a decorative drawing layer.

Canonical units are millimetres. Screen coordinates are presentation only. DIN placement is expressed by rail/module occupancy where applicable.

### 3.1 Required primitives

```text
Panel2DLayout
CabinetSection2D
MountingSurface2D
DinRailPlacement2D
DevicePlacement2D
TerminalBlockPlacement2D
BusbarPlacement2D
NeutralBarPlacement2D
PeBarPlacement2D
WiringDuctPlacement2D
CableEntryZonePlacement2D
GlandPlatePlacement2D
LabelPlacement2D
```

### 3.2 Required coordinated views

```text
PHYSICAL
ELECTRICAL
WIRING
CABLE_ENTRY_ROUTING
VALIDATION
```

All views MUST reference the same canonical project objects. SLD and 2D panel layout MUST NOT become independent databases.

### 3.3 P0 editor interactions

- select / multi-select;
- pan / zoom;
- device drag;
- deterministic DIN snap;
- move between compatible rails;
- reorder on rail;
- terminal-block placement;
- N/PE/busbar/duct placement;
- cable-entry-zone placement;
- reserve/free-zone placement;
- lock placement;
- working-revision undo/redo;
- preview/compare K0 candidates;
- accept, regenerate or reject candidate.

Every manual edit MUST re-run dependent physical validation. The editor MUST NOT support a freehand bypass around hard engineering constraints.

## 4. Cabinet cable entry

ELV6 MUST model cable entry as typed zones. No universal TOP-versus-BOTTOM rule is permitted.

Entry sides:

```text
TOP
BOTTOM
LEFT
RIGHT
MIXED
CUSTOM
UNSPECIFIED
```

Target objects:

```text
CableEntryZone
CableEntryAssignment
GlandPlate
GlandInterface
```

A zone may define geometry, purpose, allowed cable/service classes, capacity, gland plate, environmental/IP constraints and reserve.

Typical mixed example:

```text
TOP-LEFT      CONTROL
TOP-RIGHT     ELV / DATA
BOTTOM-LEFT   POWER
BOTTOM-RIGHT  RESERVED
```

## 5. Internal cabinet cable route

ELV6 MUST be able to represent:

```text
External CableRun
 -> CableEntryZone
 -> gland / entry interface
 -> CabinetInternalCablePath
 -> terminal / device
```

`CabinetInternalCablePath` SHALL be revision-scoped and may include ordered segments, calculated internal length, governing bend radius, service loop, segregation class and target termination.

Where sufficient evidence exists, validation SHALL cover:

- minimum bend radius;
- cable/gland compatibility;
- entry capacity;
- internal duct/tray fill;
- power/control/ELV segregation;
- termination reachability;
- accessibility/maintainability;
- service-loop policy;
- shield/PE termination path;
- reserve entry capacity;
- collision/impossible transition.

Missing mandatory evidence returns `UNRESOLVED/BLOCKED`; it never fabricates PASS.

## 6. K0 Automatic Switchboard Synthesis integration

K0 candidate generation SHALL treat physical fit, cable entry and internal route feasibility as constraints.

```text
circuits / requirements
 -> hierarchy candidate
 -> device/enclosure candidate
 -> cable-entry assignment
 -> internal-route feasibility
 -> 2D layout candidate
 -> physical validation
 -> engineer preview/edit
 -> revalidation
 -> accept / regenerate / reject
```

A panel that fits devices but cannot physically route required feeders/cables to valid terminations is infeasible.

## 7. Live validation families

When applicable evidence exists, the 2D editor/layout engine SHALL evaluate at least:

- enclosure boundary fit;
- DIN/module occupancy;
- placement overlap;
- mounting compatibility;
- mandatory adjacency/clearance;
- reserve policy;
- terminal capacity;
- cable-entry capacity;
- wiring-duct capacity;
- bend radius;
- service segregation;
- N/PE termination availability;
- accessibility/maintainability;
- internal-route feasibility;
- catalog physical compatibility;
- applicable ELV7 findings.

## 8. Electrical-study consumption boundary

ELV6 MAY display/use qualified short-circuit, voltage-disturbance, motor-start or source-transfer results as physical/layout context, but MUST NOT implement a hidden competing electrical-study engine. It consumes `ElectricalStudyRef` defined by `elv-integration/electrical-study-handoff-contract.md`.

Examples of legitimate use:

- show fault level at panel;
- show protection/source-study provenance;
- mark study stale after topology change;
- use qualified thermal/clearance facts when explicitly supported.

## 9. Deliverables handed downstream

ELV6 SHALL expose deterministic physical projections sufficient for ELV8 to produce:

- panel front layout;
- DIN rail layout;
- cable-entry plan;
- terminal plan;
- wiring/termination schedule;
- marker anchor positions;
- hierarchy tree and feeder references;
- physical validation findings.

## 10. Deferred

Not required for initial ELV6 runtime:

- general-purpose CAD;
- photorealistic rendering;
- full 3D cabinet authoring;
- mechanical fabrication drawings;
- thermal CFD.

2D front/layout engineering is P0; 3D remains a later specialization.
