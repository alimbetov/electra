# Electra UI ergonomics

## Goal

Electra is a field engineering editor, not a generic CAD workstation. The interface must maximize usable canvas area, minimize modal interactions and keep engineering context visible while the user places objects and traces routes.

## Core ergonomic principles

1. Canvas first. On tablet/desktop-like widths the canvas should occupy roughly 70-80% of the editor width.
2. One active tool, one relevant context. Do not expose unrelated controls while drawing or placing objects.
3. Minimum touch target: 48 logical pixels. Prefer 52-56 px for primary field actions.
4. Persistent undo/redo access.
5. Avoid modal dialogs during repeated placement and route drawing.
6. Keep the current room, active surface, discipline and unit system visible.
7. Use icon + tooltip/label rather than icon-only controls for unfamiliar engineering actions.
8. Do not encode engineering meaning by color alone; use icon, line pattern, label or shape as a second channel.
9. Tablet and phone use different compositions over the same domain state. Phone is not a scaled-down tablet.
10. Surface navigation is geometry-driven. Edge proximity and tap navigation are preferred over a separate wall/ceiling/floor navigator.
11. Inactive feature groups are hidden, not merely disabled.
12. Detailed information is loaded progressively through the current tool/selection context.

## Canvas-first editor shell

Permanent editor chrome is intentionally small:

```text
Header
Tool Rail
Canvas
Context Bar
```

The editor is not a dashboard. Large palettes, layer management, route settings, navigation and object properties must not all remain visible at the same time.

## Contextual side panel carousel

On tablet and desktop-like widths, detailed information appears in one contextual side panel. The panel behaves as a slide stack/carousel rather than a long collection of simultaneously visible panels.

Only one primary card is visible at a time.

Navigation may use:

- swipe;
- previous/next arrows;
- compact tabs;
- automatic selection based on the active tool/object.

Representative cards:

```text
Object
Circuit / Network
Surface
Room
Layers
Navigation
```

The side panel may collapse completely when the current task does not require it.

## Tool-driven context

### Select

Show only selection-related context:

```text
Object Properties
Geometry
Engineering
```

If nothing is selected, show lightweight room/surface context instead of an empty full inspector.

### Point

Show:

```text
Point presets
Recent
Favorites
Placement height
Mounting defaults
```

### Equipment

Show:

```text
Search
Recent
Favorites
Project presets
Equipment categories
```

Categories may include electrical equipment, lighting, distribution, motors/drives, pumps/fans, industrial machines, automation/control, instrumentation, network and safety equipment.

### Route

Show only route-relevant controls:

```text
Run / cable / pipe / duct preset
Laying method
Conduit/channel
Snap
Finish
Cancel
```

Do not expose reports, equipment browsing or unrelated metadata while routing.

### Measure

Show:

```text
Linear
Area
Height
Clearance
```

### Architectural Feature

Show:

```text
Door
Window
Passage
Technical Opening
Beam
Column
Soffit
Niche
Shaft
Step
Platform
Recess
Protrusion
Custom
```

## Progressive disclosure

Object information is revealed gradually.

Representative property progression:

```text
Basic
Geometry
Engineering
Advanced
```

The initial card should contain only properties required for the current operation. Advanced engineering details are not rendered until explicitly requested.

## Tablet layout

```text
+----------------------------------------------------------------+
| Project / Room | Surface | Discipline | Units | Undo/Redo       |
+------+-------------------------------------------+---------------+
|      |                                           |               |
| Tool |                                           | Context Slide |
| Rail |                  CANVAS                   |               |
|      |                                           |               |
+------+-------------------------------------------+---------------+
| Tool-specific Context Bar                                        |
+----------------------------------------------------------------+
```

Recommended proportions:

- tool rail: ~72-80 px;
- context slide: ~280-320 px when open;
- remaining width: canvas;
- context panel collapses when unused.

The canvas remains dominant even when the side context is visible.

## Phone layout

```text
+-------------------------------+
| Room / Surface / Discipline   |
+-------------------------------+
|                               |
|             CANVAS            |
|                               |
+-------------------------------+
| Tool Rail / Context Bar       |
+-------------------------------+
| Swipeable Context Bottom Sheet|
+-------------------------------+
```

The inspector/context area becomes a swipeable bottom sheet. Tool selection stays reachable by thumb near the bottom edge.

## Context bar

The bottom context bar is tool-specific and keeps the most frequent action within one tap.

Examples:

```text
Route:
Cable preset | Method | Conduit | Snap | Finish | Cancel

Equipment:
Search | Recent | Favorites | Presets

Measure:
Linear | Area | Height | Clearance
```

The context bar must remain concise. Less frequent controls move into the contextual slide/bottom sheet.

## Tool vocabulary

Primary tools:

- Select
- Point
- Equipment
- Route
- Measure
- Architectural Feature

Every tool has one stable semantic icon throughout the product. Tool icons must not change meaning between screens.

## Repeated placement

Repeated placement remains active until the user explicitly finishes or changes tools.

Examples:

```text
Socket 300 mm
-> place
-> place
-> place
-> Done
```

and:

```text
Door 900x2100
-> place
-> place
-> Done
```

This applies to engineering points, equipment and architectural features where repeated placement is meaningful.

## Architectural feature palette

When `Architectural Feature` is active, show only the feature palette:

- Door
- Window
- Passage
- Technical Opening
- Beam
- Column
- Soffit
- Niche
- Shaft
- Step
- Platform
- Recess
- Protrusion
- Custom

## Object placement presets

Engineering object palettes should support presets such as:

```text
Socket 300 mm
Switch 900 mm
Kitchen socket 1100 mm
Ceiling light
Camera ceiling
Motor 7.5 kW
Pump
VFD
PLC panel
```

A preset combines object definition + common mounting/engineering defaults. This reduces repetitive property editing.

## Route mode

Target interaction:

```text
select route preset
-> tap start
-> tap intermediate points
-> approach edge
-> adjacent surface preview
-> tap/cross edge
-> SURFACE_TRANSITION
-> continue route
-> finish
```

Do not open a property dialog at every route point.

## Edge navigation behavior

Surface-edge preview must use progressive proximity plus hysteresis to avoid flicker.

Conceptual thresholds:

```text
far           no preview
near          edge highlight
closer        adjacent surface preview
very close    snap/activation emphasis
cross/tap     activate adjacent surface
```

Appearance and disappearance thresholds should differ slightly so the preview does not oscillate when the pointer hovers around one distance.

Near a corner, candidate selection should consider:

- distance to edge;
- gesture direction;
- current tool intent;
- previous preview lock.

## Passive component policy

Inactive component groups are hidden instead of left visible in a disabled state.

Examples:

- Reports are hidden during route drawing.
- Equipment browsing is hidden during measurement.
- Full layer management is hidden during repeated point placement.
- Detailed room metadata is not permanently shown while tracing a run.
- Calculations are not displayed as a permanent editor panel.

The user may still explicitly navigate to these contexts when required.

## Visibility overlays

The user may independently toggle visual overlays such as:

- object IDs;
- installation heights;
- dimensions;
- circuits/networks;
- routes;
- snap guides.

These are presentation settings and must not modify domain data.

## Units

Metric/imperial switching affects labels, form entry and grid presentation only. Canonical engineering values remain metric internally.

## Calculations and reports

Calculations and Reports remain separate destinations from the editor. They should not consume permanent canvas space. Until engineering engines are implemented, these screens remain explicit placeholders rather than displaying guessed values.

## Acceptance targets

A usability pass should ultimately demonstrate that an engineer can create a typical room containing four sockets, two switches, three lights and one routed run while:

- keeping the canvas visible throughout;
- using no more than 2-3 modal dialogs;
- placing repeated objects without reopening the palette;
- routing wall -> ceiling -> adjacent wall without a separate surface navigator;
- undoing the last action in one tap;
- identifying active discipline, surface and units without opening settings;
- never seeing more than one detailed contextual side panel at once;
- completing the active task without unrelated passive panels occupying canvas space.
