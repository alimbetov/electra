# Electra Product Acceptance Criteria

## Purpose
This document converts recent product and field-engineering review findings into explicit acceptance criteria for the electrical-first product.

The goal is not to maximize feature count. The goal is to make Electra genuinely useful to an electrical engineer, installer and commissioning specialist while keeping the primary workflow simple and fast.

## Product positioning
Electra is an electrical-first, mobile-first engineering workspace for:

```text
Geometry
  -> Equipment
  -> Loads
  -> Circuits
  -> Routing
  -> Panels
  -> Installation
  -> Testing
  -> As-built
  -> Reports
```

The architecture may support other disciplines, but the first commercial workflow must remain electrical-first until it is proven end to end.

## UX acceptance principles

### Faster than paper for repetitive field actions
Common actions must minimize interaction cost.

Examples:

- repeated socket placement stays active until `Done`;
- equipment search supports recent/favorite/preset items;
- route drawing remains active across surface transitions;
- assigning several similar circuits must not require reopening the same dialogs;
- frequently used installation heights and component variants are available as presets.

A simple placement task must not require navigating through several modal screens.

### One active task, one primary context
At any moment the interface should normally expose:

```text
1 active tool
+ 1 primary contextual surface
+ 1 compact fast-action bar
```

Secondary capabilities remain discoverable but should not compete visually with the active engineering task.

### Progressive disclosure
Basic information appears first. Advanced electrical, geometry and ruleset properties are shown only when requested or when required by the selected object/task.

### Dry engineering visual language
Editor, floor routing, panel builder and reports use a consistent technical drawing language:

- neutral drawing background;
- technical linework and symbols;
- clear dimensions and labels;
- restrained semantic accents;
- no photorealistic interiors, decorative textures or scene rendering.

## Engineer trust criteria
Every non-trivial automated recommendation must be explainable.

The engineer must be able to inspect:

```text
Result
Inputs
Reasons
Ruleset / standard version
Warnings
Manual override state
```

The UI must not present an engineering recommendation as universally safe without identifying the ruleset under which it was calculated.

## Floor routing acceptance
A floor-level routing workspace must allow the user to:

- see floor panels/automation panels;
- see tray/conduit/backbone routes;
- see routing junctions and branch-off nodes;
- see room destinations without making rooms visually dominant;
- trace downstream from a panel;
- trace upstream from a room/equipment branch;
- filter by discipline, route class and installation state;
- open junction detail;
- drill down into a room and return to the same floor context.

## Panel builder acceptance
A floor distribution or automation panel must be represented as an engineering assembly rather than a drawing-only object.

Minimum expected model:

```text
Panel
├── incoming supply
├── protection
├── busbars
├── DIN rails
├── modules
├── terminals
├── outgoing circuits
├── PLC / I/O when applicable
└── spare capacity
```

The builder must ultimately validate at least:

- unassigned circuits;
- rail/module capacity;
- terminal capacity;
- phase assignment/balance where applicable;
- missing protection relationships;
- spare capacity.

## Installation and as-built acceptance
Designed and installed state must not be conflated.

The product must support the conceptual lifecycle:

```text
DESIGN
-> APPROVAL
-> INSTALLATION
-> AS_BUILT
-> TESTING
-> COMMISSIONING
-> MAINTENANCE
```

Field workflows should be able to record deviations, issues, actual cable quantities, installation status and test evidence without destroying the original design intent.

## End-to-end proof scenario
The foundation is not considered proven until one representative scenario works end to end.

### Workshop scenario

```text
Workshop 01
- room geometry with door/windows/beam/column
- sockets and lighting
- CNC or industrial machine
- motor
- VFD
- control panel
- power, control and Ethernet ports
```

Expected flow:

1. Create project, floor and room.
2. Build room geometry.
3. Place equipment from system/custom catalogs.
4. Create electrical loads and circuits.
5. Draw room routes and transition across surfaces.
6. Connect routes to floor backbone/junctions.
7. Inspect the complete floor routing map.
8. Assign circuits to a floor panel.
9. Assemble a basic panel layout.
10. Produce cable/run lengths and BOM.
11. Record at least one installation state/deviation.
12. Record at least one test/commissioning result.
13. Produce room/floor/project documentation.

## MVP scope guardrails
Do not block the first electrical vertical slice on unrelated discipline completeness.

Initially defer deep specialist studies such as:

- advanced load flow;
- arc flash;
- transient stability;
- full MV/HV engineering;
- advanced protection discrimination beyond implemented/tested rulesets.

Generic architecture remains valid, but product execution remains focused.

## Definition of a valuable MVP
The MVP is valuable when an engineer can stand on site with a tablet and complete a coherent workflow without exporting the project to another tool for every major step:

```text
measure / model
-> place equipment
-> plan circuits
-> route
-> inspect floor distribution
-> assemble panel
-> calculate quantities
-> document installation
-> export professional documentation
```

The success metric is workflow compression and engineering clarity, not maximum feature count.
