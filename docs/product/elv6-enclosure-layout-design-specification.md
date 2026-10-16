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

## 2. Ownership and upstream reuse

| Upstream owner | ELV6 consumes | ELV6 must not duplicate |
|---|---|---|
| ELV2 | exact component/catalog definition identity, immutable editions, technical envelopes when already defined | latest-edition lookup, mutable copies of canonical definitions |
| ELV3 | realized cables/runs, route endpoints, pathways, physical termination facts | cable allocation, installed-length calculation, route topology |
| ELV4 | power-source, PSU/UPS/battery evidence and exact physical requirement references | source sizing, battery capacity/runtime or DC-drop calculations |
| ELV5 | discipline calculations, rack demand/capacity basis, patching/load requirements | CCTV/LAN/ACS/Fire calculations |
| Shared runtime | project/revision identity, command result, replay ledger, history, UoW, stale/freeze protocol | parallel history/revision subsystem |

ELV6 creates only layout-owned data and immutable derived layout evidence.

## 3. Canonical domain model

The pure Dart domain shall introduce explicit immutable/value types. Names may be adjusted during implementation only if semantics remain one-to-one.

```dart
typedef EnclosureLayoutId = String;
typedef EnclosureId = String;
typedef MountingPlaneId = String;
typedef LayoutPlacementId = String;
typedef LayoutConstraintId = String;
typedef LayoutProposalId = String;
typedef CableEntryId = String;
typedef ReservedZoneId = String;
```

### 3.1 Enclosure root

`EnclosureAssembly` is a revision-scoped engineering aggregate and contains identity plus intrinsic physical capacity, not manufacturer commercial choice.

Required fields conceptually:

```text
id
projectId
revisionId
logicalId
kind: WALL_CABINET | FLOOR_RACK | PANEL | BOX | CUSTOM
coordinateSystem
outerEnvelopeMm
usableEnvelopeMm
frontAccess
rearAccess
sideAccess
mountingPlaneIds
cableEntryIds
reservedZoneIds
status
createdAt / updatedAt / deletedAt?
originDeviceId
```

The aggregate may reference an exact upstream component definition edition. If no adopted manufacturer product exists yet, dimensions are project-authored engineering requirements and must carry provenance.

### 3.2 Mounting surfaces

`MountingPlane` represents a physical plane or linear mounting system inside an enclosure:

```text
BACKPLATE
FRONT_RACK_RAILS
REAR_RACK_RAILS
DIN_RAIL
SHELF
DOOR
CUSTOM_PLANE
```

Every plane has an exact local transform, usable polygon/rectangle, depth envelope and mounting capability set. A DIN rail additionally has exact usable linear length. A rack plane has rack-unit origin, direction, pitch and allowed U span.

### 3.3 Placement

`LayoutPlacement` is the only authoritative statement that an engineering item occupies enclosure space.

```text
id
layoutId
enclosureId
subjectRef(owner, kind, id, revisionId)
mountingPlaneId
pose / anchor
occupiedEnvelopeMm
rackUnitSpan?
dinRailSpanMm?
depthMm
orientation
locked
manualOverrideReason?
sourceProposalId?
expectedSubjectFingerprint
```

A placement references one upstream subject. It does not clone that subject.

### 3.4 Zones and access envelopes

`ReservedZone` and `ClearanceEnvelope` represent intrinsic physical areas that must remain free or accessible. At minimum support:

- door swing/hinge envelope;
- cable bend/entry envelope;
- ventilation keep-out area;
- service/removal envelope;
- battery handling/service envelope;
- reserved future expansion zone;
- explicit engineer-authored keep-out zone.

ELV6 may enforce an intrinsic envelope encoded in an adopted technical definition. Jurisdiction-specific required clearances are evaluated by ELV7.

### 3.5 Cable entry and patching anchors

`CableEntry` is a typed physical ingress/egress anchor with capacity facts:

```text
location / orientation
entryKind
usableArea or slot count
allowed intrinsic media/mounting capabilities
assignedCableRefs
```

A cable may reference an entry assignment without changing ELV3 cable ownership. Assignment validation prevents the same physical cable endpoint from being claimed inconsistently within one layout revision.

### 3.6 Battery placement

Battery placement uses the same `LayoutPlacement` mechanism but requires exact battery evidence reference from ELV4 plus footprint, orientation, mass if known, service envelope and containment capability. Unknown mandatory dimensions block fit validation rather than assuming a default battery form factor.

## 4. Coordinate, dimension and occupancy rules

### 4.1 Units

Persist physical length in integer millimetres where possible. Any derived rational quantity uses the existing exact numeric strategy. UI conversion to other units is presentation-only.

### 4.2 Coordinate frames

Every placement is resolved into a stable enclosure-local coordinate frame. Front/rear visualizations are projections of the same canonical geometry, not separate mutable layouts.

### 4.3 Rack units

Rack-unit placement stores both logical U span and resolved millimetre envelope. Rules:

- U spans are half-open `[startU, endU)` or another single canonical representation selected in P1;
- no two exclusive placements overlap in the same occupancy lane;
- front/rear compatible equipment may share U only if their depth envelopes do not collide and their mounting capabilities explicitly permit it;
- usable U range cannot be exceeded;
- zero/negative U spans are invalid;
- reserved U capacity is represented by an explicit reserved zone, not fake equipment.

### 4.4 DIN rail

DIN placement is linear and exact. Each placement has an occupied interval plus required intrinsic side gap if supplied by technical definition. Intervals may not overlap. Unknown required module width blocks placement.

### 4.5 Shelves and backplates

Shelf/backplate placement uses 2D footprint plus depth. Collision is evaluated in the common local frame. A shelf placement must also satisfy shelf load/usable-depth capability when both facts exist. Unknown load data yields `UNRESOLVED` only for the load dimension; it must not erase valid geometric results.

## 5. Fit and intrinsic validation engine

ELV6 produces structured `LayoutFinding` records. Required finding families:

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

Each finding stores affected refs, measured facts, expected capability, provenance and deterministic ordering key.

`PASS`, `FAIL`, `UNRESOLVED` and `NOT_APPLICABLE` are separate states. Missing data never becomes PASS.

## 6. Deterministic auto-layout

Auto-layout is advisory. It must be implemented as a pure deterministic solver over an immutable input snapshot.

### 6.1 Input

```text
layout revision
selected enclosure(s)
current locked placements
unplaced subjects
intrinsic placement capabilities
reserved zones
cable-entry affinity facts
battery/service envelopes
stable optimization policy edition
```

### 6.2 Output

`LayoutProposal` contains proposed placements, unresolved subjects, score breakdown, conflicts and exact input fingerprint. It does not mutate the project.

### 6.3 Determinism

For identical canonical input and solver/policy versions, proposal ordering and coordinates must be identical. Tie-breaking uses stable IDs, never hash-map iteration or UI ordering.

### 6.4 Optimization priorities

Default policy must be versioned and explicit. A reasonable initial priority order is:

1. satisfy hard fit/mounting constraints;
2. preserve locked/manual placements;
3. keep patching/power relationships physically coherent using available affinity evidence;
4. preserve service/cable-entry access;
5. minimize fragmentation of rack/DIN capacity;
6. preserve declared expansion reserve;
7. produce stable, visually readable ordering.

These are engineering layout priorities, not normative rules. ELV7 may later reject an otherwise mechanically valid proposal.

### 6.5 Proposal acceptance

Accepting a proposal is a reviewed command that revalidates expected revisions/fingerprints. Any changed dependency causes conflict and requires a fresh preview; stale proposals are never applied blindly.

## 7. Revision, dependency and stale semantics

Every layout root is tied to exact `projectId` + `revisionId`. A layout stores an immutable `LayoutInputManifest` or equivalent normalized references/fingerprints covering all consumed upstream subjects.

Dependency invalidation is targeted:

- equipment envelope change invalidates placements of that subject and collision closure;
- battery requirement change invalidates battery placement/fit only plus affected enclosure totals;
- cable endpoint/entry change invalidates entry and patching closure;
- unrelated CCTV recording-policy changes must not invalidate rack geometry unless they changed a consumed physical/capacity requirement;
- normative-profile changes do not change intrinsic ELV6 geometry, but ELV7 findings may become stale independently.

Frozen historical revisions retain exact ELV6 capture. Pre-ELV6 historical revisions return `ELV6_NOT_CAPTURED`, not an empty valid layout.

Create-next-revision remaps revision-owned identities while preserving logical IDs and provenance. No historical placement row is overwritten.

## 8. Public command surface

Use existing `ElvCommandResult<T>`, replay-before-precondition semantics, command ledger/history and atomic UoW. Proposed public operations:

```text
CreateEnclosureLayout
ArchiveEnclosureLayout
CreateEnclosure
UpdateEnclosureGeometry
ArchiveEnclosure
CreateMountingPlane
UpdateMountingPlane
ArchiveMountingPlane
CreateReservedZone
UpdateReservedZone
ArchiveReservedZone
PlaceLayoutSubject
MoveLayoutSubject
RemoveLayoutSubject
LockLayoutPlacement
UnlockLayoutPlacement
AssignCableEntry
ReleaseCableEntry
GenerateLayoutProposal
AcceptLayoutProposal
RejectLayoutProposal
ValidateEnclosureLayout
```

Exact wire registry and operation count are frozen in P2 before runtime implementation. Commands that affect multiple aggregates carry expected revisions and reviewed impact. Replay must return the original committed result even when current mutable preconditions no longer hold.

No command may silently update ELV3/4/5-owned engineering facts.

## 9. Persistence design

Drift tables are normalized and project/revision scoped. Proposed family:

```text
elv_enclosure_layout
elv_enclosure
elv_mounting_plane
elv_layout_placement
elv_reserved_zone
elv_clearance_envelope
elv_cable_entry
elv_cable_entry_assignment
elv_layout_constraint
elv_layout_proposal
elv_layout_proposal_item
elv_layout_evaluation
elv_layout_finding
elv_layout_dependency_ref
```

Requirements:

- stable logical IDs plus revision-owned row IDs;
- foreign keys wherever both sides are locally owned;
- exact upstream owner/kind/id/revision/fingerprint for cross-stage refs;
- tombstones for shared mutable objects;
- indexes by project/revision/layout/enclosure/subject;
- uniqueness preventing duplicate active placement identity and duplicate exclusive cable-entry claims;
- derived proposal/evaluation records immutable after publication;
- guarded current pointers if the existing derived-result pattern requires them;
- schema migration never retags existing ELV4/ELV5 results as ELV6.

Opaque JSON may be used for immutable diagnostics/export payload details only when it is not the relational source of truth.

## 10. Application and code boundaries

Expected implementation shape:

```text
packages/engineering_core/lib/src/elv6/
  enclosure/
  layout/
  constraints/
  solver/
  evaluation/

apps/mobile/lib/application/
  elv6_enclosure_repository.dart
  elv6_layout_repository.dart
  elv6_layout_command_service.dart
  elv6_layout_query_service.dart
  elv6_layout_workspace_controller.dart

apps/mobile/lib/data/repositories/
  drift_elv6_enclosure_repository.dart
  drift_elv6_layout_repository.dart
```

`engineering_core` stays pure Dart. Drift entities never leak into core APIs. Widgets never query Drift directly.

## 11. Workspace UX

The enclosure workspace must support desktop and compact layouts without becoming a CAD subsystem.

Required views:

- enclosure/rack list and status;
- front view;
- rear view where applicable;
- internal/backplate or DIN view;
- palette of eligible upstream subjects;
- placement inspector with exact dimensions/provenance;
- capacity summary (U, DIN length, reserved space, cable-entry use);
- finding overlay and navigation;
- stale banner showing changed dependencies;
- auto-layout preview with before/after diff;
- explicit accept/reject;
- lock/unlock indication;
- read-only frozen revision view.

Drag/drop is a command preview followed by a validated commit; UI position is never authoritative before commit success.

## 12. Handoff to ELV7

ELV6 exports a stable validation projection, not UI state. Minimum projection:

```text
layout/enclosure/placement identities
exact physical envelopes and coordinates
mounting modes
rack/DIN capacity and utilization
battery placement and service envelope facts
cable-entry assignments/capacity facts
intrinsic findings
upstream provenance fingerprints
layout revision/hash
```

ELV7 attaches versioned jurisdictional rules to these facts. ELV6 must not contain country-specific `if` branches.

## 13. Handoff to ELV8

ELV8 may use ELV6 physical requirements to filter exact manufacturer candidates. A manufacturer substitution can change dimensions and therefore must return through an explicit impact/revalidation workflow. ELV8 may not silently resize or rearrange ELV6 placements.

## 14. Acceptance requirements

Runtime closure requires at least:

1. full offline create/edit/restart restore;
2. deterministic collision and bounds evaluation;
3. rack-U and DIN interval positive/negative fixtures;
4. battery fit positive/negative/unknown-dimension fixtures;
5. cable-entry conflict and capacity fixtures;
6. locked-placement auto-layout proof;
7. identical-input deterministic proposal proof;
8. stale proposal rejection after concurrent dependency mutation;
9. command replay/idempotency proof;
10. atomic rollback when placement plus history/outbox write fails;
11. create-next/freeze/historical-read proof;
12. targeted invalidation proof;
13. no duplicate upstream calculation ownership;
14. ELV7 projection provenance/hash proof;
15. performance fixture for a project-scale rack/enclosure set with documented budget.

No acceptance fixture may treat missing evidence as PASS or use fictional arithmetic to claim normative compliance.

## 15. Explicit non-goals

ELV6 does not own:

- product ranking, manufacturer/SKU selection or purchasing;
- commercial BOM/estimate/price books;
- jurisdictional code compliance;
- ELV4 power/source/battery sizing;
- ELV5 CCTV/LAN/ACS/Fire algorithms;
- ELV3 cable routing/allocation;
- full 3D CAD, collision mesh import or photorealistic rendering.

Future features may extend the model only through versioned contracts that preserve existing snapshots and deterministic replay.