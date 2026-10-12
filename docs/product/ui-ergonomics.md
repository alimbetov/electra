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

## Tablet layout

```text
+---------------------------------------------------------------+
| Room / surface       discipline          units     tools       |
+--------+--------------------------------------+----------------+
|        |                                      |                |
| tool   |                                      | inspector      |
| rail   |                CANVAS                |                |
|        |                                      | context        |
|        |                                      |                |
+--------+--------------------------------------+----------------+
| undo | redo | snap | grid | status | zoom                     |
+---------------------------------------------------------------+
```

Recommended proportions:

- tool rail: ~80 px;
- inspector: ~300 px;
- remaining width: canvas;
- inspector may collapse when not needed.

## Phone layout

```text
+----------------------------+
| room / surface / discipline|
+----------------------------+
|                            |
|           CANVAS           |
|                            |
+----------------------------+
| select point route ...     |
+----------------------------+
| contextual bottom sheet    |
+----------------------------+
```

The inspector appears as a bottom sheet. Tool selection stays reachable by thumb near the bottom edge.

## Tool vocabulary

Primary tools:

- Select
- Point
- Route
- Measure
- Architectural Feature

Every tool has one stable semantic icon throughout the product. Tool icons must not change meaning between screens.

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

Repeated placement remains active until the user explicitly finishes or changes tools.

## Object placement presets

Future engineering object palettes should support presets such as:

```text
Socket 300 mm
Switch 900 mm
Kitchen socket 1100 mm
Ceiling light
Camera ceiling
```

A preset combines object definition + common mounting defaults. This reduces repetitive property editing.

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

## Inspector

Inspector content is contextual and progressively disclosed:

```text
Basic
Geometry
Engineering
Advanced
```

Do not show dozens of fields for an unselected object. Room/surface context remains visible while nothing is selected.

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
- identifying active discipline, surface and units without opening settings.
