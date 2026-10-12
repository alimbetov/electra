# ADR-009: Surface-bound openings and architectural features

## Status
Accepted

## Context

Room surfaces are not empty planes. Real installations must account for doors, windows, technical openings, beams, soffits, columns, niches, shafts, steps and other construction geometry. These objects must participate in editing, snapping, routing constraints and documentation.

## Decision

Electra models two related concepts.

### Openings

Openings remove or reserve area on a host surface patch.

Initial types:

```text
DOOR
WINDOW
PASSAGE
TECHNICAL_OPENING
CUSTOM
```

Representative contract:

```text
Opening
  id
  roomId
  hostSurfacePatchId
  type
  boundaryLocal2d
  depthMm?
  sillHeightMm?
  headHeightMm?
```

### Spatial features

Construction geometry that protrudes, recesses or creates additional surfaces is represented by `SpatialFeature`.

Initial types:

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

A feature may generate or own additional `SurfacePatch` objects. A beam, for example, may expose side, underside and end patches which are valid route surfaces.

## Editor behavior

The active surface editor provides an architectural-feature tool. The user selects a type and places a rectangle/polygon using local surface coordinates. The inspector then edits exact dimensions and feature-specific properties.

## Routing behavior

The routable area of a patch is derived from the host patch minus blocking openings/features unless a discipline-specific rule explicitly allows crossing.

A route may also intentionally traverse feature-generated patches:

```text
ceiling patch
  -> beam side patch
  -> beam underside patch
  -> beam side patch
  -> ceiling patch
```

Each transition is represented with normal route topology and `SURFACE_TRANSITION` nodes.

## Consequences

- windows/doors become real geometry constraints rather than decoration;
- beams/steps/niches integrate with edge-driven navigation;
- future clash detection has stable spatial identities;
- reports and measurements can reference architectural objects directly.
