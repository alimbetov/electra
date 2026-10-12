# Electra Implementation Blueprint

## Goal

Electra is implemented as a local-first engineering application. The engineer must be able to create and edit a complete project without a backend connection. Cloud services are used for synchronization, sharing, published snapshots, collaboration and server-side document delivery.

The implementation path is:

```text
Flutter engineering workspace
        ↓
Application services / use cases
        ↓
Engineering domain core
        ↓
Repository interfaces
        ↓
Drift / SQLite
        ↓
Transactional sync outbox
        ↓ optional network
Spring Boot project-sync API
        ↓
PostgreSQL project replica + revisions
        ↓
Published immutable snapshot
        ↓
Share token / QR
        ↓
Report service
        ↓
PDF + drawings + schedules + BOM / estimate
        ↓
S3-compatible object storage
```

## 1. Mobile application boundaries

Recommended Flutter package layout:

```text
apps/mobile/lib/
├── app/
├── features/
│   ├── projects/
│   ├── rooms/
│   ├── editor/
│   ├── floor_routing/
│   ├── panels/
│   ├── calculations/
│   ├── reports/
│   ├── installation/
│   └── commissioning/
├── application/
│   ├── commands/
│   ├── queries/
│   ├── services/
│   └── sync/
├── infrastructure/
│   ├── persistence/
│   │   ├── drift/
│   │   ├── repositories/
│   │   └── migrations/
│   ├── network/
│   ├── files/
│   └── export/
└── ui/
```

The existing `packages/engineering_core` remains pure Dart and must not depend on Flutter, Drift, HTTP or platform APIs.

## 2. Local source of truth

SQLite managed through Drift is the operational source of truth on the mobile device.

Every mutable project entity carries at least:

```text
id
project_id
revision
created_at
updated_at
deleted_at?
origin_device_id
```

Use UUIDv7-compatible sortable identifiers once the ID strategy is finalized.

Project-scoped indexes must be designed around the common navigation path:

```text
project → floor → room → engineering object
```

## 3. Local relational schema

Initial table families:

### Project hierarchy

```text
project
floor
room
```

### Spatial model

```text
room_surface
surface_patch
surface_edge
surface_adjacency
opening
spatial_feature
spatial_revision
```

### Component catalogs and placed equipment

```text
component_definition
component_port_definition
equipment_item
equipment_port
```

### Electrical engineering

```text
consumption_group
electrical_load
circuit
circuit_member
cable_run
protection_assignment
panel_assembly
panel_section
din_rail
panel_module_placement
terminal_block
terminal
io_assignment
engineering_decision
```

### Routing

```text
route
route_node
route_segment
routing_junction
conduit_run
cable_tray_run
route_channel_membership
```

### Field lifecycle

```text
work_package
installation_deviation
field_issue
test_record
commissioning_item
```

### Reporting / costing

```text
material_item
bom_item
price_book
price_book_item
estimate_line
report_snapshot_meta
```

### Synchronization

```text
sync_outbox
sync_checkpoint
sync_conflict
```

## 4. Repository boundary

UI and application services must not query Drift tables directly.

```text
UI
 ↓
Use Case
 ↓
Repository interface
 ↓
Drift repository implementation
```

Representative repositories:

```text
ProjectRepository
SpatialRepository
EquipmentRepository
RoutingRepository
CircuitRepository
PanelRepository
BomRepository
ReportRepository
SyncRepository
```

A repository operation may update several normalized tables inside one SQLite transaction.

## 5. Transactional mutation pattern

Every shareable domain mutation follows:

```text
SQLite transaction
  1. validate command
  2. mutate normalized domain rows
  3. increment affected revisions
  4. mark dependent derived records STALE when required
  5. append sync_outbox event
COMMIT
  6. notify reactive UI
  7. schedule asynchronous sync
```

The outbox entry and local mutation must either both commit or both roll back.

## 6. Derived engineering data

Do not persist opaque calculation outputs as unquestioned truth.

Persist:

```text
input references
result
ruleset reference
calculation revision
engineering decision reasoning
status: CURRENT / STALE / REVIEW_REQUIRED / VALIDATED
```

When a dependency changes, only the affected dependency graph is invalidated and recalculated.

## 7. Sync architecture

Cloud synchronization is project-scoped and optional.

The client uploads ordered mutations from `sync_outbox` with:

```text
event_id
project_id
entity_type
entity_id
operation
base_revision
new_revision
payload
occurred_at
device_id
```

The server processes each `event_id` idempotently.

The client tracks a server checkpoint per project.

```text
push local outbox
→ server applies accepted mutations
→ server returns acknowledgements/conflicts
→ client pulls changes after checkpoint
→ local transaction applies remote changes
→ checkpoint advances
```

## 8. Deletion

Shared objects use tombstones rather than immediate physical deletion:

```text
deleted_at != null
```

Tombstones are retained long enough to synchronize deletions to every active replica. Physical cleanup is a separate retention process.

## 9. Conflict policy

Conflicts are explicit and domain-aware.

Automatic resolution is acceptable for safe cases such as independent metadata edits.

Geometry, routing, circuit membership, panel layout and engineering decisions must not be silently merged when both sides changed the same logical object.

Conflict output must contain:

```text
entity
local revision
remote revision
changed fields / relationships
resolution options
```

## 10. Project publication

Sharing a project and publishing a project are different actions.

### Live share

Authorized users may access a synchronized live project according to permissions.

### Published snapshot

For reports and QR delivery, create an immutable `PublishedProjectSnapshot`.

```text
Working Project
      ↓ publish
Validate requested scope
      ↓
Canonical snapshot
      ↓
Snapshot hash
      ↓
Report jobs
      ↓
Share token / QR
```

A report must always identify the snapshot/revision it was generated from.

## 11. QR sharing

The QR code contains only an opaque URL/token, for example conceptually:

```text
https://electra.example/p/<opaque-token>
```

It must never embed the whole engineering project or confidential client data.

The share record controls:

```text
published_snapshot_id
permissions
expires_at?
password_required?
download_allowed
revoked_at?
```

The token must be revocable.

## 12. Server-side report generation

The backend supports report generation from an immutable published snapshot.

```text
PublishedProjectSnapshot
  ↓
ReportAssembler
  ├── Project summary
  ├── Floor routing sheets
  ├── Room engineering drawings
  ├── Circuit schedules
  ├── Panel schedules / DIN layouts
  ├── Single-line diagrams
  ├── Terminal / I/O schedules
  ├── Cable schedules
  ├── BOM
  ├── Estimate
  ├── Validation / issues
  └── Engineering decisions / ruleset references
  ↓
PDF renderer
  ↓
S3-compatible storage
```

The backend report pipeline supplements, but does not remove, local offline PDF export.

## 13. BOM and estimate

Separate physical quantity from price.

```text
Engineering objects
   ↓
Quantity takeoff
   ↓
BOM
   ↓
PriceBook mapping
   ↓
Estimate
```

`BOM` is engineering-derived. `Estimate` is commercial and may change without changing engineering geometry.

Representative estimate line:

```text
item
manufacturer / SKU?
quantity
unit
unit_material_price?
material_total?
installation_rate?
installation_total?
source_price_book
price_date
```

Manufacturer selection may be unresolved at engineering time. A functional requirement can later map to Schneider Electric, ABB, Siemens, Legrand or another compatible catalog.

## 14. Backend modular monolith

Recommended modules:

```text
auth
subscription
project-sync
project-query
sharing
publication
reporting
pricing
documents
storage
collaboration
audit
```

Internal module boundaries should be explicit even inside one Spring Boot deployment.

## 15. Backend persistence

PostgreSQL stores the cloud replica and immutable published snapshots.

Recommended families:

```text
project / project_revision
project_member
sync_event / idempotency_key
published_snapshot
share_token
report_job
report_document
price_book / price_book_item
audit_event
```

Large generated PDFs, images and exports live in S3-compatible object storage; PostgreSQL stores metadata and object keys.

## 16. API surface

Conceptual REST endpoints:

```text
POST /api/v1/projects/{id}/sync/push
GET  /api/v1/projects/{id}/sync/pull?after=<checkpoint>

POST /api/v1/projects/{id}/publish
GET  /api/v1/published/{snapshotId}

POST /api/v1/published/{snapshotId}/shares
DELETE /api/v1/shares/{shareId}
GET  /p/{token}

POST /api/v1/published/{snapshotId}/reports
GET  /api/v1/report-jobs/{jobId}
GET  /api/v1/documents/{documentId}
```

Exact wire contracts are defined later, but the responsibility boundaries are fixed by this blueprint.

## 17. Report determinism

A generated report must be reproducible from:

```text
snapshot id
snapshot content hash
ruleset versions
manufacturer catalog versions
price book version/date
report template version
```

Changing the live project does not mutate an already published report.

## 18. First implementation gates

### L1 — local persistence
- Drift setup and migrations.
- Project/Floor/Room persistence.
- repository interfaces.
- restore after app restart.

### L2 — geometry persistence
- surfaces/patches/edges/openings/features.
- normalized storage.
- geometry revision.

### L3 — electrical/routing persistence
- equipment, loads, circuits, routes, junctions, panels.
- dependency invalidation.

### L4 — local documentation
- BOM.
- local PDF export.
- project archive export/import.

### C1 — cloud sync
- outbox.
- idempotent push.
- checkpoint pull.
- tombstones.
- conflict records.

### C2 — publication/share
- immutable snapshot.
- QR/share token.
- permissions/revocation.

### C3 — server report pipeline
- report job.
- deterministic PDF.
- S3 storage.
- download/share view.

### C4 — pricing/estimate
- price books.
- manufacturer/SKU mapping.
- estimate generation.

## 19. Non-negotiable invariants

1. Engineering work remains usable offline.
2. SQLite is the mobile source of truth, not an HTTP cache.
3. A local write and its outbox entry are atomic.
4. Server sync is idempotent.
5. Shared deletion uses tombstones.
6. Reports are generated from immutable snapshots, not a moving live project.
7. QR contains an opaque token, not project payload.
8. Engineering quantities and commercial prices are separate domains.
9. Ruleset/catalog/template versions are recorded for reproducibility.
10. Server-side report generation is optional; offline local export remains possible.
