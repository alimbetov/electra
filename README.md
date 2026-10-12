# Electra

Professional local-first mobile planner for electrical and engineering systems.

## Repository model

Electra is maintained as a monorepo. Mobile UI, engineering domain logic, backend, infrastructure and technical documentation evolve together.

```text
electra/
├── apps/
│   └── mobile/                    Flutter client
├── packages/
│   └── engineering_core/          Pure Dart engineering core
├── backend/                       Spring Boot modular monolith
├── infra/                         Local/dev deployment assets
└── docs/
    ├── product/                    Product and technical specification
    ├── architecture/               Architecture overview
    └── adr/                        Architecture Decision Records
```

## Target stack

### Mobile
- Flutter / Dart
- Riverpod
- go_router
- SQLite + Drift
- CustomPainter
- vector_math

### Engineering core
Pure Dart with no Flutter or backend dependency.

Main domains:
- geometry;
- units;
- routing;
- electrical rules;
- equipment;
- panels;
- BOM/materials;
- labels/document models.

### Backend
- Java 21+
- Spring Boot
- Spring Security / OIDC
- PostgreSQL
- Liquibase
- REST/JSON
- S3-compatible object storage

## Architectural principles

1. Local-first: offline engineering work must remain fully functional.
2. SQLite/Drift is the local operational source of truth.
3. Cloud synchronization is optional, asynchronous and privacy-aware.
4. UI is 2D while the engineering domain is height-aware (2.5D / x-y-z semantics).
5. Geometry uses canonical millimetre-based world coordinates, never screen pixels.
6. Mounting surface and cable route plane are separate concepts.
7. Technical project sharing uses secure share tokens and can publish immutable snapshots.
8. Start as a modular monolith. Do not introduce microservices without an actual scaling boundary.

## Initial product focus

Electrical workflow first:

```text
Room geometry
  -> Points / Equipment
  -> Circuits
  -> Routing
  -> Cable / protection calculations
  -> Panel
  -> BOM
  -> Labels / QR
  -> PDF documentation
```

HVAC, low-voltage, plumbing and heating are later modules on top of the same editor and geometry foundation.

## Current development branch

`feat/platform-foundation`

The foundation branch establishes the repository structure, architecture contracts and technical specification before application scaffolding begins.
