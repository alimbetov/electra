# Electra — ELV6 Enclosure, Rack and Layout Design Specification

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv6-enclosure-layout-design`
Pinned upstream ELV5: `a20ae91ecbef1da0d16443201e48f7e1b99e8701`
Entry: [authoritative index](elv6-authoritative-spec-index.md).

## 1. Purpose

ELV6 is the physical enclosure-layout stage. Its job is to answer, reproducibly and at code level:

- what cabinet/rack/enclosure contains each already-engineered item;
- on which mounting plane, rail, shelf or rack-unit span it is placed;
- whether placements overlap or exceed physical envelopes;
- whether battery assemblies and service envelopes fit;
- where cable entries and patching interfaces terminate inside the enclosure;
- what is locked by an engineer versus generated as a proposal;
- which exact upstream revisions and facts produced the current layout;
- what changed and what must be revalidated after an upstream mutation.

ELV6 is not a second equipment catalog, routing engine, power calculator or normative engine.

## 2. Existing physical-panel baseline is authoritative

ELV6 starts from an already accepted physical panel-layout model. The repository contains `PanelAssembly`, `PanelEnclosureGeometry`, `PanelMountingSection`, `DinRail`, `PanelModulePlacement`, `PanelTerminalRail`, `PanelCableDuct` and `PanelReservedZone`, and ADR-019 explicitly makes them the physical source of truth for electrical/automation panels.

Therefore ELV6 **must extend/reuse this model, not create a parallel enclosure/DIN model**.

### 2.1 Ownership rule

- Existing electrical/automation panel enclosure identity remains `PanelAssembly`.
- Existing panel DIN/module placement remains `DinRail` + `PanelModulePlacement` until an explicit migration/generalization contract proves a safe replacement.
- ELV6 may introduce new rack/cabinet entities only for enclosure kinds that have no existing canonical owner, for example telecom/server floor racks.
- A unified ELV6 workspace is built through typed adapters/projections over owner-specific sources; it does not require copying them into one mutable table.
- If future refactoring extracts a shared enclosure abstraction from `PanelAssembly`, the migration must preserve IDs, revision/history semantics and historical snapshots. No big-bang rename is assumed by this specification.

Conceptual host reference:

```text
EnclosureHostRef
- ownerKind: PANEL_ASSEMBLY | ELV_RACK_ENCLOSURE | FUTURE_CANONICAL_OWNER
- projectId
- revisionId
- entityId
- logicalId?
- expectedFingerprint
```

A given physical enclosure may have exactly one active canonical owner in one revision.

## 3. Upstream reuse and nonduplication

| Upstream owner | ELV6 consumes | ELV6 must not duplicate |
|---|---|---|
| Existing panel domain / ADR-019 | panel enclosure geometry, DIN rows, module placements, ducts, reserved zones | second panel/DIN/placement truth |
| ELV2 | exact component/catalog definition identity, immutable editions, technical envelopes when already defined | latest-edition lookup, mutable copies of canonical definitions |
| ELV3 | realized cables/runs, route endpoints, pathways, physical termination facts | cable allocation, installed-length calculation, route topology |
| ELV4 | power-source, PSU/UPS/battery evidence and exact physical requirement references | source sizing, battery capacity/runtime or DC-drop calculations |
| ELV5 | discipline calculations, rack demand/capacity basis, patching/load requirements | CCTV/LAN/ACS/Fire calculations |
| Shared runtime | project/revision identity, command result, replay ledger, history, UoW, stale/freeze protocol | parallel history/revision subsystem |

ELV6 creates only data with no accepted prior owner plus immutable layout proposals/evaluations and owner-safe extension metadata.

## 4. Canonical ELV6 model

The pure Dart domain uses explicit stable references. Exact names are frozen in P1 after the baseline audit.

```dart
typedef EnclosureLayoutId = String;
typedef RackEnclosureId = String;
typedef LayoutPlacementId = String;
typedef LayoutConstraintId = String;
typedef LayoutProposalId = String;
typedef CableEntryId = String;
typedef ReservedZoneId = String;
```

### 4.1 Non-panel rack enclosure

A new `ElvRackEnclosure` (name provisional) is allowed only when no existing canonical enclosure owns the object. It represents telecom/server/ELV rack physical capacity and provenance:

```text
id
projectId
revisionId
logicalId
kind: WALL_CABINET | FLOOR_RACK | BOX | CUSTOM
coordinateSystem
outerEnvelopeMm
usableEnvelopeMm
rackUnitRange?
frontAccess / rearAccess / sideAccess
mountingSurfaceRefs
cableEntryRefs
status
createdAt / updatedAt / deletedAt?
originDeviceId
technicalDefinitionRef?
```

For `PANEL`/electrical/automation cabinets, the host is `PanelAssembly`, not a new `ElvRackEnclosure` row.

### 4.2 Mounting surfaces and owner adapters

ELV6 exposes one read/proposal abstraction over owner-specific mounting surfaces:

```text
BACKPLATE
FRONT_RACK_RAILS
REAR_RACK_RAILS
DIN_RAIL
SHELF
DOOR
CUSTOM_PLANE
```

For a `PanelAssembly`, DIN/backplate/duct/reserved-zone facts are adapted from existing panel objects. For a new rack enclosure, ELV6 owns the corresponding rack mounting surfaces.

A proposal/evaluator may operate on a normalized immutable `MountingSurfaceSnapshot`; accepting a proposal writes through the canonical owner command path.

### 4.3 Placement ownership

A generic `LayoutPlacementSnapshot` is a solver/evaluation projection, not automatically a new source-of-truth row.

For existing panels:

```text
PanelModulePlacement / existing panel placement owner
    ↓ adapter
LayoutPlacementSnapshot
```

For new ELV racks:

```text
ElvRackPlacement (ELV6-owned)
    ↓ adapter
LayoutPlacementSnapshot
```

Required normalized fields:

```text
placementRef(ownerKind, entityId)
hostRef
subjectRef(owner, kind, id, revisionId)
mountingSurfaceRef
pose / anchor
occupiedEnvelopeMm
rackUnitSpan?
dinRailSpan?
depthMm
orientation
locked? / extension metadata
sourceProposalId?
expectedSubjectFingerprint
```

A subject is referenced, never cloned.

### 4.4 Zones and access envelopes

Existing `PanelReservedZone`/`PanelCableDuct` remain authoritative for current panel semantics. ELV6 may add typed extension records for concepts not represented there, such as service/removal envelope, cable-entry bend envelope, battery handling envelope and explicit future rack reserve.

Jurisdiction-specific clearance values belong to ELV7. ELV6 may enforce only intrinsic geometry/capability from adopted technical facts.

### 4.5 Cable entry and patching anchors

`CableEntry` is a typed ingress/egress anchor only where an equivalent canonical owner does not already exist. It contains location/orientation, kind, intrinsic capacity and non-owning cable endpoint assignments. ELV3 remains cable/run owner.

Assignment validation prevents inconsistent exclusive claims within one revision.

### 4.6 Battery placement

Battery placement consumes exact ELV4 battery evidence plus technical footprint/orientation/mass/service facts. It uses the canonical host placement mechanism for that enclosure owner. Missing mandatory dimensions produce unresolved fit, never a guessed form factor.

## 5. Coordinate, unit and occupancy rules

### 5.1 Units and numeric compatibility

The existing panel/geometry code uses millimetres with `double` fields (`widthMm`, `heightMm`, `depthMm`, rail lengths and placement widths). ELV6 must **not create an incompatible integer-mm fork**.

P0/P1 must pin the accepted geometry scalar/serialization/tolerance convention used by the existing geometry kernel and `PanelAssembly`. New ELV6 geometry follows that convention. Discrete capacities such as rack U, module positions and counts remain integer/discrete where naturally required.

UI unit conversion is presentation-only. Deterministic hashes use the project canonical numeric serialization, not locale-formatted floating-point strings.

### 5.2 Coordinate frames

Every normalized placement resolves into a stable enclosure-local frame. Front/rear views are projections of the same canonical geometry, not independent mutable layouts.

### 5.3 Rack units

Rack placement stores logical U span plus resolved physical envelope. Rules:

- one canonical interval convention is frozen in P1;
- exclusive occupancy lanes cannot overlap;
- front/rear sharing is allowed only when mounting/depth capabilities prove non-collision;
- usable U range cannot be exceeded;
- zero/negative spans are invalid;
- reserved U is an explicit zone/reservation, not fake equipment.

### 5.4 Existing DIN rails

Existing `DinRail.capacityModules`, `railLengthMm`, `modulePitchMm`, `PanelModulePlacement.position`, `moduleWidthUnits` and `physicalWidthMm` are reused for panel DIN placement. ELV6 hardens interval/collision validation around these facts instead of creating another DIN placement table.

If a future generic DIN abstraction is extracted, a compatibility adapter and migration proof are mandatory before `PanelModulePlacement` stops being authoritative.

### 5.5 Shelves/backplates

Shelf/backplate placement uses footprint plus depth in the accepted geometry representation. When load capacity is known, weight is another independent result dimension. Missing load data yields `UNRESOLVED` for load, without erasing valid geometry results.

## 6. Intrinsic fit evaluation

ELV6 emits structured findings such as:

```text
OUT_OF_BOUNDS
PLACEMENT_OVERLAP
MOUNTING_MODE_INCOMPATIBLE
RACK_U_CONFLICT
DIN_INTERVAL_CONFLICT
DEPTH_CONFLICT
SERVICE_ENVELOPE_CONFLICT
CABLE_ENTRY_CONFLICT
CABLE_ENTRY_CAPACITY_EXCEEDED
BATTERY_ENVELOPE_CONFLICT
BATTERY_ORIENTATION_UNSUPPORTED
WEIGHT_CAPABILITY_EXCEEDED
VENTILATION_ENVELOPE_CONFLICT
UPSTREAM_EVIDENCE_MISSING
UPSTREAM_EVIDENCE_STALE
```

Each finding stores host/placement/subject refs, measured facts, expected capability, provenance and stable ordering key.

`PASS`, `FAIL`, `UNRESOLVED` and `NOT_APPLICABLE` are separate. Missing data never becomes PASS.

Existing panel validation is not discarded. P0 maps each existing panel validator/result to ELV6 finding semantics and proves whether it is reused directly, wrapped or extended.

## 7. Deterministic auto-layout

Auto-layout is advisory and operates on immutable normalized host snapshots, regardless of underlying owner.

### Input

```text
exact project/revision
host snapshot(s)
current canonical placements
locked placements/extension metadata
unplaced subjects
intrinsic mounting/envelope capabilities
reserved/service zones
cable-entry affinity facts
battery/service facts
versioned optimization policy
```

### Output

`LayoutProposal` contains owner-targeted proposed mutations, unresolved subjects, score breakdown, conflicts and exact input fingerprint. It never mutates a host directly.

### Determinism

Identical canonical input + solver/policy version produces identical canonical proposal ordering/coordinates. Tie-breaking uses stable IDs, never map iteration, DB row order or widget order.

### Priorities

1. hard fit/mounting constraints;
2. locked/manual placements;
3. physical patching/power affinity where exact evidence exists;
4. service/cable-entry access;
5. rack/DIN fragmentation minimization;
6. declared expansion reserve;
7. stable readable ordering.

These are layout priorities, not jurisdictional law.

### Acceptance

Proposal acceptance rechecks host owner revisions, subject fingerprints and proposal input hash, then routes writes through owner-specific command services. Stale proposal acceptance fails without destroying the draft.

## 8. Revision and dependency semantics

A layout evaluation/proposal is tied to exact `projectId` + `revisionId` and an immutable consumed-input manifest.

Targeted invalidation examples:

- device envelope change → its placement + collision closure;
- battery requirement change → battery fit + affected host totals;
- cable endpoint/entry change → entry/patching closure;
- unrelated recording-policy change → no rack invalidation unless a consumed capacity/physical fact changed;
- normative profile change → ELV7 stale state, not intrinsic ELV6 geometry mutation.

Frozen revisions retain exact owner-specific panel/rack data plus ELV6 proposal/evaluation capture. Pre-ELV6 revisions return `ELV6_NOT_CAPTURED`, not empty-valid.

Create-next remapping preserves existing panel owner semantics and remaps ELV6-owned rack/layout extension identities without overwriting history.

## 9. Command boundary

Reuse existing `ElvCommandResult<T>`, replay-before-precondition, ledger/history and atomic UoW.

P0/P2 must first inventory current panel mutation services. The final command registry then has two classes:

1. **reused/extended canonical panel commands** for `PanelAssembly`/DIN/module/reserved-zone mutations;
2. **new ELV6 commands** only for non-panel rack hosts, ELV6 extensions, proposals/evaluations and cable-entry assignments not already owned elsewhere.

Conceptual operations include:

```text
Create/Update/ArchiveRackEnclosure
Create/Update/ArchiveRackMountingSurface
Create/Update/ArchiveLayoutExtensionZone
Place/Move/RemoveRackSubject
Lock/UnlockLayoutPlacement
Assign/ReleaseCableEntry
GenerateLayoutProposal
AcceptLayoutProposal
RejectLayoutProposal
ValidateEnclosureLayout
```

Do not create `CreateEnclosure` or `PlaceLayoutSubject` APIs that shadow existing `PanelAssembly` ownership without an explicit migration decision.

Cross-owner commands carry expected revisions/reviewed impact. Replay returns original committed result even if current mutable preconditions changed.

## 10. Persistence design

P0 must inventory existing panel persistence before adding schema. The target is additive, not duplicative.

Existing canonical panel tables/records continue to store panel enclosure geometry, DIN/module placement and current panel zones. New ELV6 tables are limited to missing domains, for example:

```text
elv_rack_enclosure
elv_rack_mounting_surface
elv_rack_placement
elv_layout_extension_zone
elv_layout_extension_metadata
elv_cable_entry
elv_cable_entry_assignment
elv_layout_constraint
elv_layout_proposal
elv_layout_proposal_item
elv_layout_evaluation
elv_layout_finding
elv_layout_dependency_ref
```

Exact table names are frozen only after the P0 schema audit.

Requirements:

- no second active row for one existing `PanelAssembly` enclosure or `PanelModulePlacement`;
- stable logical/revision IDs for new ELV6 owners;
- typed owner references for cross-domain hosts/placements;
- foreign keys where both sides share ownership;
- exact upstream owner/kind/id/revision/fingerprint for cross-stage refs;
- indexes by project/revision/host/subject;
- uniqueness for active ELV6-owned placements and exclusive cable-entry claims;
- immutable published proposal/evaluation evidence;
- no retagging of ELV3/4/5 results during migration.

Opaque JSON is diagnostics/export payload only, not mutable layout truth.

## 11. Code boundaries

Expected additive shape after P0:

```text
packages/engineering_core/lib/src/panel_assembly.dart     // reuse; extend compatibly only
packages/engineering_core/lib/src/elv6/
  host_projection/
  rack/
  constraints/
  solver/
  evaluation/

apps/mobile/lib/application/
  existing panel application APIs                          // reuse
  elv6_rack_repository.dart
  elv6_layout_command_service.dart
  elv6_layout_query_service.dart
  elv6_layout_workspace_controller.dart

apps/mobile/lib/data/repositories/
  existing panel Drift repository                          // reuse
  drift_elv6_rack_repository.dart
  drift_elv6_layout_repository.dart
```

The actual existing panel repository/service filenames are discovered in P0; this spec does not invent a competing abstraction merely to fit naming.

`engineering_core` remains Flutter/Drift/HTTP independent. Widgets never query Drift directly.

## 12. Workspace UX

One enclosure workspace may show panel and rack hosts uniformly while preserving canonical ownership.

Required views/capabilities:

- enclosure/rack list with owner/type/status;
- front view and rear view when supported;
- existing panel DIN/backplate view through adapter;
- rack U view;
- eligible-subject palette;
- exact inspector/provenance;
- U/DIN/reserve/cable-entry capacity summaries;
- findings and source navigation;
- stale dependency banner;
- auto-layout before/after proposal diff;
- explicit accept/reject and lock state;
- frozen historical read-only mode.

Drag/drop is preview then canonical owner command. Canvas position is never authoritative before commit success.

## 13. Handoff to ELV7

ELV6 exports a stable owner-neutral validation projection:

```text
host identity + canonical owner
placement identity + canonical owner
physical envelopes/coordinates
mounting modes
rack/DIN capacity/utilization
battery placement/service facts
cable-entry assignments/capacity
intrinsic findings
upstream fingerprints
revision/projection/hash
```

ELV7 adds jurisdictional rules. ELV6 contains no country-specific branches.

## 14. Handoff to ELV8

ELV8 may use ELV6 physical requirements to filter manufacturer candidates. A selected product dimension/mounting change triggers explicit impact/revalidation. ELV8 cannot silently resize or rearrange a panel/rack.

## 15. Acceptance requirements

Runtime closure requires at least:

1. **baseline ownership proof** that existing `PanelAssembly`/DIN/module data is not duplicated;
2. legacy panel persistence/restart behavior remains accepted;
3. existing panel layout fixtures remain green after ELV6 extensions;
4. new non-panel rack create/edit/restart restore;
5. owner-neutral deterministic collision/bounds evaluation;
6. existing panel DIN and new rack-U positive/negative fixtures;
7. battery fit positive/negative/unknown-dimension fixtures;
8. cable-entry conflict/capacity fixtures;
9. locked-placement auto-layout proof across supported host owners;
10. identical-input deterministic proposal proof;
11. stale proposal rejection after concurrent owner/dependency mutation;
12. command replay/idempotency and atomic rollback proof;
13. create-next/freeze/historical-read proof for both reused and new owners;
14. targeted invalidation proof;
15. ELV7 projection provenance/hash proof;
16. project-scale rack/panel performance budget.

No fixture may treat missing evidence as PASS or use fictional data to claim normative compliance.

## 16. Explicit non-goals

ELV6 does not own:

- replacement of accepted `PanelAssembly` merely for naming consistency;
- manufacturer/SKU selection or purchasing;
- commercial BOM/estimate/price books;
- jurisdictional compliance;
- ELV4 power/battery sizing;
- ELV5 discipline algorithms;
- ELV3 cable routing/allocation;
- full 3D CAD or photorealistic rendering.

Future shared-enclosure refactoring is a separately qualified migration, not an implicit prerequisite for ELV6.