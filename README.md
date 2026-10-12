# Electra

Professional local-first mobile planner for multi-discipline field engineering.

## Repository model

Electra is maintained as a monorepo. Mobile UI, engineering domain logic, backend, infrastructure and technical documentation evolve together.

```text
electra/
├── apps/
│   └── mobile/                    Flutter client
├── packages/
│   └── engineering_core/          Pure Dart spatial/network/engineering core
├── backend/                       Spring Boot modular monolith
├── infra/                         Local/dev deployment assets
└── docs/
    ├── product/
    ├── architecture/
    └── adr/
```

## Platform architecture

```text
Shared Spatial Model
  -> piecewise-planar room geometry
  -> SurfacePatch / SurfaceEdge / adjacency
  -> doors/windows/openings/features

Engineering Layers
  -> Electrical
  -> Plumbing / Heating
  -> HVAC
  -> Low Voltage / CCTV / Fire / Security
  -> future disciplines

Generic Network + Routing Core
  -> Run
  -> Route
  -> RouteNode
  -> RouteSegment
  -> surface transitions
```

Electrical remains the first commercial vertical, but it is not the architectural boundary of the product.

## Mobile stack

- Flutter / Dart
- SQLite + Drift (next persistence gate)
- CustomPainter
- Riverpod / go_router planned after initial UI/domain contracts stabilize

The initial source skeleton now supports the product flow:

```text
Projects
  -> Create Project
  -> Rooms
  -> Create Room
  -> Room Editor
      -> discipline selection
      -> surface navigation shell
      -> Door / Window / Beam / feature selection
      -> Calculations placeholder
      -> Reports placeholder
```

Engineering calculations and final reports are deliberately deferred until geometry and routing contracts are validated.

## Spatial/editor principles

1. Local-first and offline-first.
2. Canonical persisted geometry uses millimetres.
3. Metric/imperial selection affects input/output only.
4. UI is 2D/2.5D, while spatial objects are x/y/z aware.
5. Room surfaces may be piecewise-planar and include slopes, beams, steps, niches and other construction geometry.
6. The primary navigation model is edge-driven: approaching/tapping an edge reveals or activates the adjacent surface/patch.
7. Routing remains continuous across surface transitions.
8. Windows, doors and other openings are real spatial constraints, not decoration.
9. Shared geometry is reused by all engineering disciplines.
10. Cloud sync/collaboration is optional; offline engineering work does not require the backend.

## Backend target

- Java 21+
- Spring Boot modular monolith
- Spring Security / OIDC
- PostgreSQL
- Liquibase
- REST/JSON
- S3-compatible object storage

The backend is responsible for authentication, subscriptions, optional project synchronization, sharing, revisions, published snapshots, collaboration and audit. It is not required for offline geometry editing or engineering calculations.

## Current development branch

`feat/platform-foundation`

The branch is transitioning from architecture-only discovery to the first implementation foundation. Next gates are geometry kernel, surface topology, editor edge proximity/navigation, Drift persistence and automated tests.
