# ADR-001: Monorepo

## Status
Accepted

## Decision
Electra uses a single Git repository for the mobile frontend, backend, shared engineering packages, infrastructure and technical documentation.

## Repository layout

```text
apps/mobile/                  Flutter application
packages/engineering_core/   Pure Dart engineering domain
backend/                      Spring Boot backend
infra/                        Local/dev deployment assets
docs/                         Product and engineering documentation
```

## Rationale

- Product, domain contracts and implementation evolve together.
- Engineering rules can be reviewed alongside UI and persistence changes.
- CI can validate cross-boundary contracts in one pull request.
- Documentation is versioned with the implementation it describes.
- The initial team and architecture do not justify multi-repository operational overhead.

## Constraint
The Pure Dart engineering core must not depend on Flutter UI packages or backend implementation details.
