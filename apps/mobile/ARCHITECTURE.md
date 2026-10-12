# Electra Mobile Architecture

## Current implementation target

The mobile application is implemented as a local-first, offline-capable engineering workstation. Authentication and backend integration are not part of the current implementation phase.

## Runtime architecture

```text
Flutter UI
   ↓
Application / use cases
   ↓
engineering_core
   ↓
Repository contracts
   ↓
Drift adapters
   ↓
SQLite
```

Heavy files such as photos, imported documents, exported project archives and generated PDFs are stored in the local filesystem and referenced from SQLite.

## What belongs where

### `features/`

Screens and feature-specific presentation logic.

Examples:

- projects;
- rooms;
- room editor;
- floor routing;
- panel builder;
- reports;
- installation;
- commissioning.

### `application/`

Use cases that coordinate engineering rules and persistence.

Examples:

```text
CreateProject
CreateFloor
CreateRoom
PlaceEquipment
CreateCircuit
RouteCable
GeneratePanelProposal
RecalculateAffectedEngineeringGraph
BuildBom
GenerateReport
```

### `data/`

Infrastructure adapters:

```text
database/
repositories/
mappers/
catalogs/
files/
```

Drift row types must not leak into feature widgets or `engineering_core`.

### `engineering_core`

Pure Dart engineering logic. It owns engineering semantics, invariants, calculations and validation, but not persistence or Flutter UI.

## Local database boundaries

SQLite should be normalized by engineering concept rather than storing an entire project as one JSON document.

Initial implementation order:

```text
1. projects / floors / rooms
2. geometry / surfaces / openings / features
3. component definitions / equipment instances
4. loads / groups / circuits
5. routes / segments / junctions / channels
6. panels / rails / placements / terminals
7. engineering decisions / recalculation state
8. BOM / price book / estimate
9. installation / commissioning
10. report snapshot metadata
```

## Reactive reads

Persistent lists and engineering summaries should be observed from repositories as streams.

Examples:

```text
watchProjects()
watchFloors(projectId)
watchRooms(floorId)
watchCircuits(projectId)
watchFloorRouting(floorId)
watchPanel(panelId)
watchBom(projectId)
```

This makes SQLite the authoritative state while Flutter reacts to committed database changes.

## Commands vs queries

Use an explicit distinction:

```text
Command
  changes project state
  runs validation/recalculation
  commits transaction

Query
  reads/observes derived or persisted state
  has no side effects
```

Representative command flow:

```text
AddConsumerCommand
       ↓
LoadApplicationService
       ↓
engineering_core
       ↓
RecalculationImpact
       ↓
Drift transaction
       ↓
committed state
       ↓
watchers update UI
```

## UI state

Keep only ephemeral interaction state outside SQLite.

Examples:

- active editor tool;
- currently selected object;
- current canvas transform;
- temporary drawing gesture;
- expanded context section;
- unsaved form draft.

Do not keep the canonical project model only in a `ChangeNotifier` or widget tree.

## Project lifecycle without backend

```text
Create project
→ save to SQLite
→ edit offline
→ calculate locally
→ save report locally
→ export backup/archive
```

The application must remain useful indefinitely with no account and no server.

## Later cloud integration

The future backend will connect outside the core local workflow:

```text
SQLite project
   ↓
optional sync/export boundary
   ↓
backend
```

The application layer should therefore depend on repository abstractions, not backend DTOs.

## First implementation milestone

The first persistence milestone is intentionally small:

```text
Project
Floor
Room
```

Acceptance test:

```text
create project
→ create floor
→ create room
→ kill app
→ reopen app
→ exact values restored from SQLite
```

Only after this gate passes should geometry and engineering persistence be layered on top.
