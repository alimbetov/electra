# ADR-005: Multi-discipline engineering layers

## Status
Accepted

## Context
Electra starts commercially with the electrical workflow, but the shared spatial model must support future collaboration between electricians, plumbers, HVAC specialists, low-voltage installers, CCTV/security specialists and fire-alarm engineers.

A project must therefore be a shared engineering object, not an electrical-only document.

## Decision
Electra uses a shared spatial model plus discipline-specific engineering layers.

```text
Project
  -> Shared Spatial Model
      -> Floor
      -> Room
      -> Wall
      -> Opening
      -> shared reference geometry

  -> EngineeringLayer[]
      -> ELECTRICAL
      -> LOW_VOLTAGE
      -> CCTV
      -> FIRE_ALARM
      -> SECURITY
      -> ACCESS_CONTROL
      -> PLUMBING
      -> HEATING
      -> HVAC
      -> GAS
      -> DRAINAGE
      -> SOLAR
      -> EV_CHARGING
```

Additional coordination/presentation data is represented independently from discipline.

```text
Phase:
  EXISTING
  DEMOLITION
  NEW
  TEMPORARY

InstallationStatus:
  PLANNED
  APPROVED
  INSTALLED
  TESTED
  COMMISSIONED
```

This avoids creating combinations such as `ELECTRICAL_INSTALLED` or `PLUMBING_EXISTING` as distinct layer types.

## EngineeringLayer

An engineering layer is project-scoped and versionable.

Suggested fields:

```text
id
projectId
discipline
name
ownerId
revision
baseSpatialRevision
visibility
createdAt
updatedAt
```

## Shared geometry

Rooms, walls, openings and common spatial references belong to the shared project geometry and are not duplicated per discipline.

An electrician and plumber may therefore work on the same `Room` while owning different engineering objects.

## Permissions

Future collaboration permissions are discipline-aware.

Examples:

```text
VIEW_PROJECT
VIEW_GEOMETRY
EDIT_GEOMETRY
VIEW_ELECTRICAL
EDIT_ELECTRICAL
VIEW_PLUMBING
EDIT_PLUMBING
VIEW_HVAC
EDIT_HVAC
```

A shared project can therefore allow a plumber to read the electrical layer while editing only plumbing/heating layers.

## Revisions

Shared geometry is versioned independently from discipline layers.

```text
SpatialRevision 17
  -> Electrical layer revision 21
  -> Plumbing layer revision 8
  -> HVAC layer revision 4
```

When shared geometry advances, affected discipline layers must be able to detect that their `baseSpatialRevision` is stale and require review/rebase before critical derived calculations are accepted.

## Future coordination

The architecture must permit cross-discipline spatial coordination and clash detection without requiring a full 3D BIM engine.

Initial 2.5D checks may use:

- route centerlines;
- z ranges;
- equipment bounding boxes;
- required clearance envelopes;
- room/floor boundaries.

## Scope

Only the electrical vertical is required for the first production release. Other disciplines are architectural extension points, not V1 delivery commitments.
