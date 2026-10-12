# ADR-007: Piecewise-planar spatial geometry

## Status
Accepted

## Context

Real rooms are not always bounded by perfectly flat rectangular walls, floors and ceilings. Field conditions include beams, soffits, niches, shafts, columns, stepped floors, raised platforms, lowered zones, sloped ceilings, wall returns and other local geometry changes.

A model in which one room surface equals one infinite/flat plane would become a constraint for routing, equipment placement and cross-discipline coordination.

Electra still does not need a free-form BIM solid model for the first product generations. The editor must remain precise, mobile-friendly and suitable for deterministic routing and measurements.

## Decision

Electra will represent room boundaries as piecewise-planar geometry.

A logical room surface can consist of one or more planar patches:

```text
Room
  -> RoomSurface[]
       -> SurfacePatch[]
            -> SurfaceEdge[]
```

Each `SurfacePatch` is a bounded planar polygon in project 3D space and exposes a local 2D coordinate frame for editing.

Representative data:

```text
SurfacePatch
  id
  surfaceId
  boundary
  localCoordinateFrame
  plane
  normal
  elevation/orientation
```

The complete floor, ceiling or wall may therefore contain folds, level changes or slopes while each patch remains geometrically simple and deterministic.

## Surface hierarchy

`RoomSurface` is the logical surface grouping, for example the room floor, main ceiling or a particular wall assembly.

`SurfacePatch` is the editable planar component of that surface.

Examples:

```text
CeilingSurface
  -> Patch A horizontal at z=2700
  -> Patch B vertical soffit face
  -> Patch C horizontal underside at z=2400

FloorSurface
  -> Patch A at z=0
  -> Patch B vertical step face
  -> Patch C raised platform at z=150

WallSurface A
  -> Patch A main wall plane
  -> Patch B recessed niche back
  -> Patch C niche side return
```

## Spatial features

Common architectural intrusions and construction features are represented explicitly as `SpatialFeature` objects rather than encoded only as anonymous surface folds.

Initial feature types:

```text
BEAM
COLUMN
SOFFIT
NICHE
SHAFT
STEP
PLATFORM
RECESS
PROTRUSION
CUSTOM
```

A feature may own or generate one or more surface patches. For example a beam may expose bottom, side and end patches.

```text
SpatialFeature(BEAM)
  -> bottom patch
  -> left side patch
  -> right side patch
  -> end patch(es)
```

Feature identity is useful for measurements, annotations, clash detection, routing constraints and documentation.

## Adjacency

Adjacency is defined between concrete patch edges.

```text
SurfacePatch
  -> SurfaceEdge
       -> adjacentPatchId?
       -> adjacentSurfaceId?
```

This extends edge-driven navigation naturally. A user may move from a ceiling patch to the side of a beam, then to the underside of the beam, then back to another ceiling patch using the same tap/edge interaction model.

Examples:

```text
ceiling patch
  -> beam side patch
  -> beam underside patch
  -> opposite beam side patch
  -> ceiling patch
```

and:

```text
main floor
  -> step face
  -> raised platform
```

## Routing continuity

Routes remain continuous across patch transitions.

A surface-bound route segment references the concrete patch on which it lies:

```text
RouteSegment.surfacePatchId
```

When the route crosses a patch boundary, the editor creates or reuses a `SURFACE_TRANSITION` node at the shared edge.

```text
RouteSegment(patch A)
  -> SURFACE_TRANSITION
  -> RouteSegment(patch B)
```

This applies equally to cable, conduit, pipe and duct routing.

## Geometry scope

The first implementation deliberately supports polygonal, piecewise-planar geometry.

Supported direction:

- horizontal planes;
- vertical planes;
- arbitrary sloped planes;
- polygonal boundaries;
- explicit folds/steps between patches.

Not required initially:

- NURBS;
- spline surfaces;
- arbitrary curved solids;
- free-form mesh editing;
- BIM-grade constructive solid geometry.

Curved construction may later be approximated by multiple planar patches when acceptable for field design.

## Editor consequences

The editor treats a patch as the active precise 2D editing plane. Edge-driven navigation works at patch level while preserving logical surface identity.

The active editor state may therefore distinguish:

```text
activeSurfaceId
activePatchId
previewSurfaceId?
previewPatchId?
nearestEdgeId?
proximity
```

The user should not need to understand this internal hierarchy. Visually, they continue to move through room surfaces by approaching and tapping edges.

## Coordinate conversion

Every patch must support deterministic conversion:

```text
local Point2Mm <-> world Point3Mm
```

This is required for exact measurements, transitions, route length calculation and cross-discipline clash detection.

## Persistence

The normalized spatial model is expected to include:

```text
room_surface
surface_patch
surface_edge
surface_adjacency
spatial_feature
```

Patches and features are part of shared project geometry and therefore participate in `SpatialRevision`.

## Consequences

Benefits:

- supports realistic construction geometry without full BIM complexity;
- preserves the 2D/2.5D editor interaction model;
- supports beams, niches, soffits, steps, slopes and level changes;
- keeps routing deterministic and measurable;
- extends naturally across electrical, plumbing, heating, HVAC and other disciplines;
- provides better future inputs for clash detection and installation documentation.

Costs:

- surface topology becomes richer;
- local/world coordinate conversion must be implemented per patch;
- editing a spatial feature may regenerate multiple dependent patches/edges;
- spatial validation must detect gaps, overlaps and invalid adjacency.

## Validation expectations

The Spatial Core must be able to validate at least:

- planar patch validity;
- non-degenerate polygon boundaries;
- shared-edge consistency;
- adjacency symmetry where applicable;
- valid local/world transforms;
- feature-generated patch ownership;
- route continuity across patch transitions;
- spatial revision changes after geometry edits.
