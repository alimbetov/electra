# Electra Engineering Workspace UI

## Purpose
Electra must feel like one coherent professional engineering instrument across room design, floor routing, panel assembly, reports, installation and commissioning. The interface should be useful, simple, intuitive and powerful without becoming a miniature desktop CAD system.

## Product UX principles

1. **Canvas first.** Engineering geometry remains the dominant region.
2. **One task, one context.** The active tool owns the primary contextual panel.
3. **Progressive disclosure.** Basic properties first; advanced engineering details only when requested.
4. **Stable spatial hierarchy.** Project -> Floor -> Room -> Surface -> Object remains visible and navigable.
5. **No decorative rendering.** Plans and surfaces use dry technical graphics, neutral backgrounds and engineering symbols.
6. **Use color sparingly.** Color indicates discipline, status, warnings or selection; engineering meaning is also encoded with icons, patterns and labels.
7. **Field ergonomics.** Large touch targets, minimal modal dialogs, persistent undo/redo, readable labels and strong selection states.
8. **Same domain state, different compositions.** Tablet/desktop and phone share logic but not layout.
9. **Drill-down, not clutter.** Move from project/floor overview into junction, room, surface or equipment details rather than showing everything simultaneously.
10. **Every number should be traceable.** Reports and summaries should drill down to the underlying room, circuit, route, component or test record.

## Global workspace shell

The preferred tablet/desktop structure is:

```text
+--------------------------------------------------------------------------------+
| Project / Floor / Room | Workspace | Discipline | Units | Status | Undo/Redo  |
+----------+-----------------------------------------------------+---------------+
|          |                                                     |               |
| Tool     |                                                     | Context Slide |
| Rail     |                  ENGINEERING CANVAS                 |               |
|          |                                                     |               |
|          |                                                     |               |
+----------+-----------------------------------------------------+---------------+
| Tool-specific Context Bar                                                      |
+--------------------------------------------------------------------------------+
```

Persistent regions:

- top context/navigation bar;
- narrow tool rail;
- engineering canvas;
- one contextual side slide;
- concise context bar.

The contextual slide may collapse completely.

## Workspace switcher

Primary workspace modes:

```text
Room
Floor Routing
Panels
Reports
Installation
Commissioning
```

The workspace switcher changes the engineering canvas and tool vocabulary but preserves selected project/floor/discipline context.

## Top context bar

The top bar should answer five questions without opening settings:

1. What project am I in?
2. What floor/room am I looking at?
3. Which workspace is active?
4. Which discipline/layer is active?
5. Is the current state saved/synchronized/validated?

Representative layout:

```text
<Project A / Floor 02 / Room 201> | Room | Electrical | Metric | Saved | Undo | Redo
```

Avoid placing low-frequency commands here.

## Tool rail

The tool rail contains stable, semantic tools only.

### Room workspace

```text
Select
Point
Equipment
Route
Feature
Measure
```

### Floor Routing workspace

```text
Select
Trace
Route
Junction
Tray/Conduit
Measure
Filter
```

### Panel workspace

```text
Select
Module
DIN rail
Terminal
Wire
I/O
Validate
```

### Installation workspace

```text
Select
Work package
Installed
Deviation
Issue
Photo/Note
Measure
```

### Commissioning workspace

```text
Select
Test
Checklist
Measured value
Issue
Approve
```

Tool semantics and icons must remain stable across the product.

## Contextual slide system

Only one primary detailed card is visible at once.

Navigation:

- swipe;
- previous/next;
- compact tabs;
- automatic switching based on active tool or selected object.

Representative cards:

```text
Object
Circuit / Network
Route
Surface
Room
Panel
Installation
Validation
```

The UI must never show several full inspectors side-by-side.

## Progressive property structure

Object properties are grouped into:

```text
Basic
Geometry
Engineering
Advanced
```

`Basic` should contain only what is needed for the current action.

Example for a socket:

```text
Basic
  type
  height
  circuit

Geometry
  surface
  local position

Engineering
  load profile
  protection relationship

Advanced
  identifiers
  custom metadata
```

## Context bar

The bottom context bar exposes the most frequent operations for the active tool.

Examples:

```text
Route:
Preset | Method | Channel | Snap | Finish | Cancel

Equipment:
Search | Recent | Favorites | Project presets | Multiple

Floor Routing Trace:
Upstream | Downstream | Power | Control | Clear

Panel:
Catalog | Assign circuit | Auto-layout | Validate | BOM

Commissioning:
Test type | Value | Pass/Fail | Next
```

Avoid duplicate controls between the context bar and context slide.

## Room workspace

Goal: place and route engineering objects on walls, ceiling, floor and piecewise-planar features.

Visual style:

- orthographic/unfolded technical surfaces;
- thin neutral construction lines;
- precise dimensions;
- clear engineering symbols;
- no realistic room textures or decorative interior rendering.

Primary flow:

```text
Select room/surface
-> choose tool
-> place/route/measure
-> contextual properties
-> continue repeated action
-> Done
```

## Floor Routing workspace

Goal: understand and edit floor-wide engineering routing.

The canvas should show:

```text
Floor outline
Rooms as context
Panels
Tray / conduit backbones
Routing junctions
Outgoing branches
Risers / floor transitions
```

Default view should suppress minor room-detail geometry so the routing topology remains readable.

### Floor routing display modes

```text
Overview
Power
Control / Automation
Data / Instrumentation
Branch detail
Installation state
Issues
```

### Trace interaction

Selecting a panel, route, junction, room or endpoint should allow:

```text
Trace upstream
Trace downstream
Show path to source
Show carried runs
Open junction
Open room
```

Non-selected infrastructure is visually de-emphasized rather than hidden when context is important.

## Routing junction view

A junction has three visual representations:

```text
In-place plan symbol
Logical schematic
Installation detail
```

The in-place representation must be compact. Selecting it opens the contextual slide with incoming/outgoing branches and a command to open detailed installation view.

## Panel Builder workspace

Goal: assemble floor distribution boards and automation cabinets from actual project circuits and I/O.

Canvas composition:

```text
Panel cabinet
├── DIN rows
├── protection modules
├── busbars
├── PLC / I/O
├── relays/contactors
├── terminal strips
└── spare capacity
```

The left rail is for placement tools; the right context slide shows selected module/circuit/terminal information.

### Panel-specific conveniences

- snap to DIN module grid;
- automatic module width handling;
- auto-numbering;
- drag circuit onto breaker;
- drag signal onto I/O channel;
- show occupied/free modules;
- show terminal capacity;
- show phase assignment;
- show warnings inline;
- one-tap BOM and validation.

## Reports workspace

Reports should be navigable, not merely printable.

Hierarchy:

```text
Project Overview
-> Floor Summary
-> Room Report
-> Circuit / Route / Equipment detail
```

Primary tabs:

```text
Overview
Rooms
Systems
Panels
Materials
Issues
Documentation
```

Any aggregate value should support drill-down.

## Installation workspace

The installation view should optimize for site use rather than design editing.

Show:

- work packages;
- installation status;
- planned vs as-built route;
- deviations;
- photos/notes;
- cable pulls;
- labels;
- field issues.

The canvas should emphasize actionable tasks and suppress design controls not needed by the installer.

## Commissioning workspace

The commissioning view is checklist-oriented.

Selected equipment/circuit shows:

```text
Required tests
Measured values
Pass / fail
Phase sequence
Protection settings
Open issues
Commissioning status
```

The workflow should allow one-handed sequential progression through test records.

## Information density

Electra should use three density levels:

### Overview density

Large map, very few labels, major topology only.

### Engineering density

Normal working mode with IDs, dimensions, routes and key values.

### Detail density

Focused object/junction/panel detail with terminal/core-level information.

The user changes density by navigation/zoom/context, not by opening giant global settings panels.

## Selection hierarchy

Selection must be visually unambiguous.

Priority:

```text
Active tool target
Selected object
Related objects
Context geometry
Inactive background
```

Do not allow selected routes, surfaces and equipment to compete visually at equal emphasis.

## Status language

Status must never depend on color alone.

Examples:

```text
Design        dashed line + label
Approved      solid technical line
Installed     solid line + installation mark
As-built      heavier verified mark
Warning       warning icon + annotation
Error         error icon + explicit message
```

## Responsive layout

### Tablet / desktop

- tool rail: 72-80 px;
- side slide: 288-320 px;
- canvas gets all remaining width;
- context slide collapsible;
- keyboard/mouse shortcuts supported when available.

### Phone

- no permanent right panel;
- contextual slide becomes bottom sheet;
- primary tools move to bottom/edge reach zone;
- room/floor context is condensed;
- canvas remains dominant;
- long property forms become paged sections.

## Touch and pointer targets

- minimum touch target: 48 logical px;
- preferred primary field actions: 52-56 px;
- narrow technical geometry may use larger invisible hit targets;
- drag handles must remain usable over dense drawings;
- hover affordances may enhance pointer use but must not be required.

## Command hierarchy

Every workspace should follow:

```text
Primary action      always visible
Secondary action    context bar / slide
Advanced action     progressive section / overflow
Rare administration dedicated settings screen
```

This prevents toolbar growth.

## Keyboard / productivity model

For desktop/tablet keyboard users, support predictable shortcuts later:

```text
Esc     cancel current operation
Enter   finish operation
Delete  delete selection
Ctrl/Cmd+Z undo
Ctrl/Cmd+Shift+Z redo
Space   temporary pan
F       focus selection
```

Shortcuts supplement touch UI; they never replace visible actions.

## Validation UX

Validation should be visible where the problem exists.

Bad:

```text
17 errors
```

Preferred:

```text
Circuit C-14
Overloaded
-> highlight C-14 route and connected loads
-> open recommended actions
```

Warnings should offer direct navigation to the affected object.

## Empty states

Empty states should instruct the next useful engineering action.

Example:

```text
No routing backbone on Floor 02.
Start from DB-F02 or place a tray/conduit backbone.
```

Avoid generic `No data` messages.

## Design tokens

The visual system should use restrained tokens rather than ad-hoc styling.

Recommended semantic groups:

```text
canvasBackground
surfaceBackground
panelBackground
constructionLine
engineeringLine
selection
focus
warning
error
success
inactive
```

Typography should prioritize legibility and numeric scanning. Dimensions, cable sizes, IDs and electrical values should align consistently.

## Acceptance criteria

A successful workspace should allow an experienced electrician/engineer to:

- understand the current project/floor/room/workspace within two seconds;
- place repeated components without reopening a palette;
- trace a circuit from panel to room and endpoint without changing apps/views manually;
- open a routing junction in one action;
- navigate from floor route to room/surface detail and back without losing context;
- see panel capacity and circuit assignment without a separate report;
- identify installation and commissioning status directly on the engineering object;
- complete common actions with one contextual panel and without stacked modal dialogs;
- work with gloves/touch on a tablet while preserving precision;
- print/export a view that remains understandable in monochrome.

## Product rule

Electra should feel simple because irrelevant complexity is hidden, not because engineering capability is removed.

The governing UX principle is:

> Show the engineer exactly what is needed for the current physical task, keep the technical drawing dominant, and make every deeper engineering detail reachable in one predictable drill-down path.
