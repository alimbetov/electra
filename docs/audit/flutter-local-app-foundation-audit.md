# Audit: feat/flutter-local-app-foundation

## Scope

Audit target: `feat/flutter-local-app-foundation` before starting the execution sequence:

```text
WP-FL0
→ WP-FL1
→ WP-FL2
```

The audit checks consistency between the Flutter development specification, delivery plan, inherited mobile scaffold, engineering_core boundaries and the required local-first implementation strategy.

## Executive conclusion

Status: **GO WITH PRE-FL0 REMEDIATION**.

The branch is suitable as an implementation baseline. The specification is coherent, correctly local-first and aligned with the existing Electra domain architecture. No architectural rewrite is required before implementation.

However, several implementation seams must be closed as part of WP-FL0/FL1 rather than carried forward as accidental architecture:

1. replace global in-memory canonical project state;
2. introduce first-class Floor persistence and repository APIs;
3. replace timestamp-derived local IDs with globally unique synchronization-safe IDs;
4. make the state-management/navigation/DI baseline explicit;
5. introduce Drift dependencies, database bootstrap and migration tests;
6. add test harness and CI evidence before declaring gates green;
7. separate draft/form models from canonical domain/persistence models;
8. define transaction boundaries for Project/Floor/Room commands.

## Branch condition

At audit time the branch is two commits ahead of `main` and contains only specification documents:

- `docs/product/flutter-development-specification.md`
- `docs/product/flutter-delivery-plan.md`

This is a positive property: implementation has not started before the execution contract was written.

No CI/status checks are currently attached to the branch HEAD, therefore no green build/test claim is made.

## What is already correct

### Local-first architecture

The specification correctly establishes SQLite/Drift as the operational source of truth and keeps authentication/backend/cloud capabilities outside the Phase-1 dependency graph.

### Layering

The intended dependency direction is sound:

```text
Flutter Presentation
→ Application / Use Cases
→ engineering_core
→ Repository Interfaces
→ Drift Repositories
→ SQLite
```

Drift types are explicitly prevented from leaking into engineering_core or feature widgets.

### Command/query separation

Mutations are modeled as commands and reactive repository reads as queries. This is appropriate for future dependency-driven recalculation and auditable engineering changes.

### Adaptive product model

Phone/tablet/desktop use the same canonical project model while only workspace composition and input affordances change. This avoids platform-specific domain forks.

### Delivery strategy

The sequence is correctly vertical and evidence-driven. In particular, the rule "No geometry implementation before Project → Floor → Room restart persistence passes" is the right gate.

## Findings

### F01 — Canonical state still lives in ChangeNotifier

Severity: **BLOCKER for WP-FL1 completion**

Current scaffold uses `ElectraAppState extends ChangeNotifier` with an in-memory `List<ProjectDraft>`.

This contradicts the target architecture once persistence begins. `ChangeNotifier` may remain for ephemeral UI state but must not remain the authoritative project store.

Required remediation:

```text
UI
→ application command
→ repository
→ SQLite transaction
→ repository watcher
→ UI
```

### F02 — Floor is missing from the current runtime model

Severity: **BLOCKER for WP-FL1/WP-FL2**

The current `ProjectDraft` owns `List<RoomDraft>` directly. The target model requires:

```text
Project
→ Floor
→ Room
```

Required remediation:

- introduce `Floor` as a first-class canonical/application model;
- room must reference `floorId`;
- repositories must expose `watchFloors(projectId)` and `watchRooms(floorId)`;
- project UI must navigate Project → Floor → Room.

### F03 — Current local IDs are not synchronization-safe

Severity: **HIGH**

Current helper derives IDs from `DateTime.now().microsecondsSinceEpoch` with a prefix.

This is insufficient as a long-term cross-device identity contract.

Required remediation:

- adopt UUIDv7 or another globally unique time-sortable identifier;
- centralize ID generation behind an injected `IdGenerator`;
- test uniqueness and deterministic injection in unit tests.

### F04 — Draft models mix form/scaffold and canonical model responsibilities

Severity: **HIGH**

`ProjectDraft` and `RoomDraft` currently act as both UI data and pseudo-domain state.

Required remediation:

Separate:

```text
ProjectFormDraft / RoomFormDraft     ephemeral UI input
ProjectRecord / FloorRecord / RoomRecord  application/domain projection
Drift row types                       infrastructure only
```

The exact naming may differ, but the boundary must be explicit before persistence spreads.

### F05 — Repository contract is incomplete for the first persistence gate

Severity: **HIGH**

The current repository contract has projects and rooms but no floor operations.

Required WP-FL0 contract:

```text
watchProjects()
findProject(id)
create/update/deleteProject

watchFloors(projectId)
findFloor(id)
create/update/deleteFloor

watchRooms(floorId)
findRoom(id)
create/update/deleteRoom
```

### F06 — State-management technology is intentionally undecided

Severity: **MEDIUM, must close in WP-FL0**

The specification recommends Riverpod but does not make it normative.

Recommendation:

Use Riverpod for:

- dependency injection;
- repository/application-service wiring;
- scoped async/reactive UI state;
- test overrides.

Do not place canonical project data in provider-owned mutable collections; providers observe repository streams.

### F07 — Navigation baseline is not yet formalized in code

Severity: **MEDIUM**

The current app uses direct `Navigator.push` calls while the specification requires workspace-oriented navigation and persistent project context.

Recommendation:

Adopt `go_router` in WP-FL0 with semantic routes such as:

```text
/projects
/projects/:projectId
/projects/:projectId/floors/:floorId
/projects/:projectId/floors/:floorId/rooms/:roomId
```

Later workspaces may extend from the same context.

### F08 — Drift dependency/bootstrap does not exist yet

Severity: **EXPECTED GAP / WP-FL1**

Current `pubspec.yaml` does not yet include Drift/database packages. This is expected at this stage but must be the first persistence implementation work.

Required:

- `drift`;
- SQLite runtime package appropriate for supported Flutter platforms;
- code generation/build tooling;
- database opening strategy for mobile + desktop;
- migration strategy;
- test database strategy.

### F09 — No migration evidence exists

Severity: **HIGH for WP-FL1 gate**

The specification correctly forbids destructive recreation, but there is no executable migration harness yet.

WP-FL1 must introduce:

- schema version 1;
- migration test setup;
- round-trip persistence test;
- future migration fixture convention.

### F10 — No CI/status evidence exists for the branch

Severity: **MEDIUM**

The branch HEAD has no attached status checks/workflow runs.

Before WP-FL0 is called green, CI should verify at minimum:

```text
dart format --set-exit-if-changed
flutter analyze
flutter test
engineering_core tests
```

Desktop/mobile build checks can be added progressively depending on runner availability.

### F11 — Adaptive layout foundation exists but lacks tests

Severity: **MEDIUM**

`ElectraBreakpoints` and `ElectraAdaptiveBuilder` provide a useful foundation, but WP-FL0 requires tests for boundaries:

```text
699 -> compact
700 -> medium
1099 -> medium
1100 -> expanded
```

and widget rendering at representative sizes.

### F12 — Transaction boundary must be explicit before repositories multiply

Severity: **HIGH**

Application commands should own a single transaction where multiple persistent mutations must remain atomic.

For FL1/FL2 this is simple, but the API should not force each repository method to independently commit in a way that later makes engineering mutations non-atomic.

Recommended pattern:

```text
ApplicationService
→ database transaction / UnitOfWork boundary
→ repositories participate
→ commit
```

Do not introduce an elaborate generic UnitOfWork framework unless needed; Drift transaction closures are sufficient initially.

### F13 — Delete semantics need an explicit Phase-1 decision

Severity: **MEDIUM**

Future sync requires tombstones, while current Phase 1 is local-only.

Recommendation:

Persist `deletedAt` from schema v1 for shareable project entities, even if UI initially behaves as hard delete/hidden delete. This avoids a destructive migration of identity semantics when cloud sync arrives.

### F14 — Audit fields should be present from schema v1

Severity: **MEDIUM**

For Project/Floor/Room use common metadata from the beginning:

```text
id
revision
createdAt
updatedAt
deletedAt?
originDeviceId
```

`projectId`/`floorId` are added where appropriate.

This reduces future sync migration risk.

## Recommended WP-FL0 concrete baseline

Before starting Drift tables, WP-FL0 should produce:

```text
AppCompositionRoot
Riverpod ProviderScope
GoRouter navigation
ElectraAdaptiveBuilder tests
IdGenerator abstraction + UUIDv7 implementation
ProjectRepository / FloorRepository / RoomRepository contracts
Application command skeletons
Common AppFailure / ValidationIssue presentation
Test fixtures and repository fakes
```

## Recommended WP-FL1 schema v1

### project

```text
id TEXT PK
name TEXT
reference TEXT
measurementSystem TEXT
defaultStructuralHeightMm INTEGER
defaultFinishedCeilingHeightMm INTEGER
revision INTEGER
createdAt INTEGER
updatedAt INTEGER
deletedAt INTEGER NULL
originDeviceId TEXT
```

### floor

```text
id TEXT PK
projectId TEXT FK
name TEXT
code TEXT
sortOrder INTEGER
defaultStructuralHeightMm INTEGER NULL
defaultFinishedCeilingHeightMm INTEGER NULL
revision INTEGER
createdAt INTEGER
updatedAt INTEGER
deletedAt INTEGER NULL
originDeviceId TEXT
```

### room

```text
id TEXT PK
floorId TEXT FK
name TEXT
roomType TEXT
roomCategory TEXT
widthMm INTEGER
depthMm INTEGER
structuralHeightMmOverride INTEGER NULL
finishedCeilingHeightMmOverride INTEGER NULL
revision INTEGER
createdAt INTEGER
updatedAt INTEGER
deletedAt INTEGER NULL
originDeviceId TEXT
```

Indexes:

```text
floor(projectId, sortOrder)
room(floorId, name)
project(updatedAt)
```

## Recommended WP-FL2 UX gate

The persisted hierarchy must be usable without separate domain models on all layouts:

### Compact

```text
Projects
→ Project
→ Floors
→ Rooms
```

### Medium

```text
Project/Floor navigation | primary content | context
```

### Expanded

```text
Project navigator | primary content | inspector/context
```

Resizing must not recreate or duplicate canonical project records.

## Go / No-Go

**GO** for `WP-FL0 → WP-FL1 → WP-FL2` provided the findings above are treated as part of those work packages rather than deferred architectural debt.

There is no reason to redesign the whole branch before implementation. The specification is sufficiently mature.

### Hard gates before WP-FL3

Do not start geometry until all are green:

1. Project/Floor/Room are first-class persisted entities.
2. Drift schema v1 migration passes.
3. UUID-safe identity is in place.
4. App restart restores exact values.
5. Compact/medium/expanded tests pass.
6. Canonical project state no longer depends on `ElectraAppState` in-memory collections.
7. Repository fakes and application-service tests exist.
8. `flutter analyze` and `flutter test` are green for the exact HEAD.

## Resolution

The branch is architecturally ready to move from specification into implementation. The next execution loop should begin with WP-FL0 and close F01-F07/F10-F12, then WP-FL1 closes F08-F09/F13-F14, and WP-FL2 proves the first end-to-end local product slice.