# ADR-006: Edge-driven surface navigation

## Status
Accepted

## Context

Electra is primarily a 2D editor, but engineering work is spatial. A route may continue from a wall to a ceiling, floor or adjacent wall. Requiring the user to switch between separate `Plan`, `Wall`, `Ceiling` and `Floor` screens breaks spatial context and adds navigation overhead.

The editor therefore needs a lightweight 2.5D interaction model that preserves 2D precision while allowing continuous movement across adjacent room surfaces.

## Decision

Electra will use edge-driven surface navigation.

The active editing surface is a first-class spatial object. Each surface exposes explicit edges, and each edge may reference an adjacent surface.

```text
Room
  -> RoomSurface[]
       -> SurfaceEdge[]
            -> adjacentSurfaceId?
```

Representative surface types:

```text
FLOOR
CEILING
WALL
CUSTOM
```

A wall is not represented only by the generic value `WALL`; it is represented by a concrete `RoomSurface` instance such as `wall-surface-a`.

## Interaction model

When the pointer or touch location approaches an edge of the active surface, the UI progressively reveals the adjacent surface.

Illustrative behavior:

```text
far from edge       -> no preview
near edge           -> edge highlight
closer               -> adjacent surface preview
very close           -> strong preview / snap hint
tap edge             -> adjacent surface becomes active
```

The exact pixel thresholds are presentation concerns and may be tuned by device class and input method.

The preview strength should be derived from normalized edge proximity rather than binary hover state.

Possible presentation values driven by proximity:

```text
edgeOpacity
previewOpacity
foldAngle
snapStrength
```

The adjacent surface may visually unfold toward the user, with an intermediate preview around 45 degrees before activation. The visual fold angle is not persisted domain data.

## Tap navigation

A tap on an interactive edge activates the adjacent surface.

For a wall surface this commonly means:

```text
upper edge  -> ceiling
lower edge  -> floor
left edge   -> previous adjacent wall
right edge  -> next adjacent wall
```

Navigation is derived from topology, not from hardcoded left/right/top/bottom assumptions. Complex and non-rectangular rooms must use explicit surface adjacency.

## Routing continuity

If a route-drawing operation is active when the user crosses or taps an adjacent edge, the current operation continues instead of being cancelled.

The editor creates a route transition node at the shared boundary:

```text
RouteSegment(surfaceId = wallA)
  -> RouteNode(type = SURFACE_TRANSITION)
  -> RouteSegment(surfaceId = ceiling)
```

The route therefore remains physically continuous across surfaces.

`RouteSegment.surfaceId` references a concrete `RoomSurface`, not only a generic surface type.

## Spatial model

The Spatial Core will include at least:

```text
RoomSurface
SurfaceEdge
SurfaceAdjacency
```

A `RoomSurface` describes a concrete editable surface in 3D project space while also exposing a local 2D coordinate system for editing.

A `SurfaceEdge` describes a boundary of that local 2D surface and maps to a 3D segment.

`SurfaceAdjacency` captures the relationship between two surfaces sharing or logically connecting through an edge.

## Editor state

The Flutter editor should maintain presentation state similar to:

```text
SurfaceNavigationState
  activeSurfaceId
  previewSurfaceId?
  nearestEdgeId?
  proximity
```

This belongs to editor/application state, not the persistent engineering domain.

## Consequences

Benefits:

- preserves spatial context while remaining primarily 2D;
- reduces explicit navigation controls;
- supports continuous cable, pipe and duct routing;
- works for electrical, plumbing, heating, HVAC, CCTV and fire-alarm layers;
- avoids requiring a full 3D/BIM editor for field workflows;
- creates a consistent interaction model for phone and tablet.

Costs:

- room surfaces and adjacency must be explicitly modeled;
- coordinate conversion between global 3D and per-surface local 2D space is required;
- hit testing and edge proximity need dedicated editor logic;
- malformed surface topology must be detected and validated.

## Non-goals

- full free-camera 3D navigation;
- photorealistic room rendering;
- BIM-level solid modeling;
- persisting visual fold angles as engineering data.

The product remains a 2D/2.5D field engineering editor with spatial continuity.
