# ADR-026: Local-Only Flutter Implementation Phase

## Status
Accepted

## Context

Electra is primarily a field engineering application. The core engineering workflow must remain fully usable without authentication, cloud connectivity, synchronization, or backend availability.

The project already defines a local-first architecture where SQLite/Drift is the operational source of truth and cloud services are optional. For implementation sequencing, building authentication and backend services before the local engineering workflow would increase delivery risk and distract from the product's primary value: engineering work on the device.

## Decision

Phase 1 is a **local-only Flutter application**.

The following capabilities must work completely on-device:

- project creation and management;
- floors and rooms;
- geometry and surfaces;
- equipment/component placement;
- loads and consumption groups;
- circuits;
- routing and floor routing views;
- junctions;
- panel generation and panel physical layout;
- dependency-driven recalculation;
- manufacturer catalog matching from locally installed catalog data;
- BOM and estimate calculation from local price books;
- installation/as-built/commissioning records;
- local report model generation;
- local PDF export where supported;
- project backup/export.

Authentication, subscriptions, cloud synchronization, collaboration, QR publication and server-side report generation are explicitly deferred to a later phase.

## Source of truth

SQLite/Drift is the mobile operational source of truth.

```text
Flutter UI
   ↓
Application services
   ↓
Engineering Core
   ↓
Repository interfaces
   ↓
Drift repositories
   ↓
SQLite
```

The UI must never depend directly on Drift tables or SQL details.

## Layer boundaries

### Presentation

Flutter widgets, navigation, canvas interaction, context panels and view state.

### Application

Use cases and orchestration, for example:

```text
CreateProject
CreateRoom
PlaceEquipment
AssignLoadToCircuit
GeneratePanelProposal
ApplyEngineeringRecalculation
BuildBom
GenerateLocalReport
```

Application services coordinate repositories and `engineering_core`, but contain no widget logic.

### Domain

`packages/engineering_core` remains the pure Dart engineering model and calculation layer. It must not depend on Flutter, SQLite, HTTP, authentication or backend contracts.

### Infrastructure

Local implementation details:

```text
Drift database
SQLite migrations
repository adapters
filesystem storage
local manufacturer catalogs
local price books
local PDF/export adapters
```

## Feature-oriented Flutter structure

Recommended structure:

```text
apps/mobile/lib/
├── app/
│   ├── bootstrap/
│   ├── navigation/
│   ├── theme/
│   └── workspace/
├── application/
│   ├── projects/
│   ├── rooms/
│   ├── editor/
│   ├── electrical/
│   ├── routing/
│   ├── panels/
│   ├── reports/
│   └── installation/
├── data/
│   ├── database/
│   ├── repositories/
│   ├── mappers/
│   ├── catalogs/
│   └── files/
├── features/
│   ├── projects/
│   ├── rooms/
│   ├── room_editor/
│   ├── floor_routing/
│   ├── panels/
│   ├── reports/
│   ├── installation/
│   └── commissioning/
└── ui/
    ├── components/
    ├── engineering_canvas/
    └── icons/
```

## Persistence rule

A user command that changes engineering state is persisted transactionally.

Representative flow:

```text
User command
   ↓
Application service
   ↓
Engineering validation / recalculation
   ↓
SQLite transaction
   ├── persist domain changes
   ├── persist engineering decisions
   ├── persist stale/recalculated dependencies
   └── update project revision
   ↓
reactive UI observes committed state
```

During the local-only phase no cloud outbox is required for normal application behavior. The schema should nevertheless retain revision/tombstone fields so later synchronization does not require a destructive redesign.

## State management

Persistent engineering state belongs in SQLite, not in widget/global in-memory state.

Ephemeral UI state may remain in memory:

- active tool;
- selected object;
- zoom/pan transform;
- active context panel;
- hover/proximity state;
- temporary route being drawn;
- unsaved form input before commit.

The application must be reconstructable after process death from SQLite plus local files.

## Navigation

Navigation should reflect engineering hierarchy rather than backend concepts:

```text
Projects
→ Project Workspace
   → Floor
      → Floor Routing
      → Rooms
         → Room Editor
      → Panels
   → Reports
   → Installation
   → Commissioning
```

## Local identity

Entity identifiers are generated locally. The identifier strategy must remain globally unique so later cloud synchronization does not require renumbering.

UUIDv7 remains the preferred target unless implementation constraints justify an equivalent sortable globally unique identifier.

## Deferred backend boundary

Future backend/auth integration must be additive:

```text
local repositories
      ↓
optional sync adapter
      ↓
backend
```

No Phase-1 feature may require a login or network request to open, edit, calculate, save or export a project locally.

## Acceptance criteria

Phase 1 is successful when a user can:

1. install/open Electra with no account;
2. create a project, floor and room;
3. close and reopen the application and recover the exact project from SQLite;
4. place engineering components;
5. create circuits and routes;
6. generate/review panel proposals;
7. modify a load and observe deterministic dependent recalculation;
8. build a local BOM;
9. generate a local engineering report/PDF;
10. export/backup the project locally.

Only after this vertical slice is stable should authentication, cloud synchronization and collaborative backend work begin.
