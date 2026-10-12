# ADR-003: English-first domain and localization strategy

## Status
Accepted

## Context
Electra is intended to evolve from an initial English product into a multilingual engineering platform. Domain terminology is shared across Flutter, Dart engineering packages, Spring Boot, PostgreSQL, SQLite, API contracts and technical documentation.

Using localized values inside the domain or persistence model would create unstable contracts and complicate future localization.

## Decision

All technical identifiers are English-first and language-neutral:

- source code identifiers;
- domain type names;
- database tables and columns;
- API contracts;
- enum/code values;
- technical documentation;
- logs and machine-readable events.

Examples:

```text
RoomType = BATHROOM
RoomCategory = WET
MountingSurface = WALL
LayingMethod = FLOOR_SCREED
```

User-facing strings must not be hardcoded into domain values. Flutter UI text is localization-ready from the beginning and may initially ship with English resources only.

User-entered content, such as project names and room names, is stored as entered and is not constrained to English.

## Consequences

Positive:

- stable domain/API/storage contracts;
- straightforward addition of Russian, Kazakh, German and other languages;
- consistent terminology across frontend/backend/documentation;
- international contributor friendliness.

Trade-off:

- localization infrastructure must be respected even while only one language is shipped.
