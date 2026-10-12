# ADR-010: Contextual Progressive Editor UI

## Status
Accepted

## Context

Electra is a field engineering editor. A permanently visible collection of layers, equipment palettes, route controls, navigation, room metadata, object properties, calculations and report controls would reduce the usable canvas area and create unnecessary cognitive load.

The editor must keep the spatial work surface dominant while still allowing access to detailed engineering information when the current task requires it.

## Decision

Electra uses a canvas-first contextual editor with progressive disclosure.

The persistent editor shell contains only:

```text
Header
Tool Rail
Canvas
Context Bar
```

Detailed information is displayed through one active contextual side panel on tablet/desktop widths, or one contextual bottom sheet on compact/phone layouts.

Inactive feature groups are hidden rather than merely disabled.

## One active context

The editor follows this rule:

> One active tool -> one primary contextual surface.

Examples:

```text
Select
  -> Object Properties / Room Context

Point
  -> Point presets / placement options

Equipment
  -> Equipment catalog / search / recent / favorites

Route
  -> Route preset / laying method / conduit / snap / finish

Measure
  -> Linear / area / height / clearance tools

Architectural Feature
  -> Door / Window / Beam / Column / Niche / ...
```

Controls unrelated to the active task are not kept on screen.

## Side panel carousel

On tablet and desktop-like widths, the contextual information area behaves as a slide stack/carousel.

Only one card is visible at a time. The user may move backward/forward using:

- swipe;
- previous/next buttons;
- compact tabs;
- automatic context switching caused by the active tool or selection.

Representative cards:

```text
Object
Circuit / Network
Surface
Room
Layers
Navigation
```

The panel may be fully collapsed when it is not needed.

## Progressive disclosure

Complex object properties are revealed in layers of detail rather than displayed at once.

Representative structure:

```text
Basic
Geometry
Engineering
Advanced
```

The default view contains only the fields required for the current action.

## Context bar

The bottom context bar contains fast actions for the active tool.

Examples:

```text
Route:
Cable preset | Laying method | Conduit | Snap | Finish | Cancel

Equipment:
Search | Recent | Favorites | Presets

Measure:
Linear | Area | Height | Clearance
```

The context bar should remain lightweight and should not become another permanent dashboard.

## Repeated placement

Placement tools stay active until the user explicitly finishes or changes tools.

Example:

```text
Socket 300 mm
-> place
-> place
-> place
-> Done
```

This applies to engineering points, equipment and architectural features where repeated placement is meaningful.

## Tablet composition

```text
+----------------------------------------------------------------+
| Project / Room | Surface | Discipline | Units | Undo/Redo       |
+------+-------------------------------------------+---------------+
| Tool |                                           | Context Slide |
| Rail |                  CANVAS                   |               |
|      |                                           |               |
+------+-------------------------------------------+---------------+
| Tool-specific Context Bar                                        |
+----------------------------------------------------------------+
```

The canvas remains the dominant region.

## Phone composition

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

Phone UI is not a scaled-down tablet layout.

## Passive component policy

A passive feature group is hidden when it does not support the current action.

Examples:

- Reports are not visible while routing.
- Equipment catalog is not visible while measuring.
- Full layer management is not visible during repeated point placement.
- Detailed room metadata is not permanently displayed while editing a route.

The user can still explicitly navigate to these destinations when required.

## Rationale

This approach reduces cognitive load, increases effective canvas area, improves touch ergonomics and matches the mental model of field engineering work: complete one physical action, then expose the next relevant information.

## Consequences

The UI must maintain explicit editor mode/context state and deterministic transitions between contextual cards.

Contextual visibility is presentation state and must not change engineering domain data.

Usability tests must verify that the UI does not hide critical state such as active surface, active discipline, units, selection or unsaved/sync status.
