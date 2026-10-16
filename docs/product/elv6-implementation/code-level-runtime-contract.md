# ELV6 — Code-level enclosure/rack layout runtime contract

Status: **DESIGN DRAFT / RUNTIME NOT STARTED**  
Branch: `feat/flutter-elv6-enclosure-layout-design`  
Pinned design upstream: ELV5 `ed7db01adb27ff184b0b8c91a710082fb9eafb9a`  
Authority: `../elv6-authoritative-spec-index.md` → this contract → process/command registries → package contracts.

This document is normative for implementation. It closes the gap between enclosure-layout prose and executable Dart/Drift/application boundaries. Where the legacy `PanelAssembly` model cannot express a required physical fact, ELV6 extends the persisted layout domain deliberately; it must not pretend an in-memory class is already a revisioned runtime owner.

---

## 1. Hard architectural decision: semantic baseline is not runtime ownership

The repository contains an accepted **semantic design baseline** in `packages/engineering_core/lib/src/panel_assembly.dart` and ADR-019. At the audited branch baseline it does **not** prove all of the following runtime capabilities:

```text
PERSISTED_CANONICAL_OWNER
REVISION_SCOPED_IDENTITY
PUBLIC_MUTATION_SERVICE
REPLAY_LEDGER_INTEGRATION
UNDO_REDO_HISTORY
FREEZE_CAPTURE
CREATE_NEXT_REMAP
CONCURRENCY_CAS
```

Therefore P0 classifies every legacy panel capability independently:

```dart
enum Elv6BaselineCapabilityState {
  absent,
  semanticModelOnly,
  persisted,
  publicWriter,
  revisionIntegrated,
  qualified,
}
```

A class or ADR is never enough to mark `qualified`.

If P0 finds no accepted persisted panel-layout owner, ELV6 SHALL **promote the existing PanelAssembly semantics into the first revision-scoped runtime owner** instead of creating a competing model. The same stable panel identity and terminology are retained. If an accepted writer is discovered later, the owner adapter maps to it and the promotion path is not duplicated.

The runtime source-of-truth rule is absolute:

> one physical host, mounting surface, placement, zone, cable entry or assignment has exactly one active canonical writer in one design revision.

---

## 2. Scope and engineering claim boundary

ELV6 owns constructible physical arrangement evidence for:

- electrical/automation panels;
- telecom/ELV wall cabinets and floor racks;
- DIN rails, rack rails, shelves, backplates and door-mounted surfaces;
- equipment placement envelopes;
- reserved/service/removal/ventilation envelopes;
- cable entries, gland/knockout occupancy and internal cable-manager/duct capacity basis;
- terminal/patch physical capacity basis;
- battery physical placement and handling envelope;
- support load, total mass and centre-of-gravity basis;
- physical ventilation/airflow and thermal-input basis;
- measured physical segregation distances;
- declared protective-bonding points and physical bond assignments;
- deterministic engineer-assisted auto-layout proposals.

ELV6 does **not** claim:

- IEC/KZ/EU/other jurisdictional compliance;
- IP rating verification after arbitrary modifications;
- temperature-rise conformity;
- creepage/clearance regulatory conformity;
- manufacturer/SKU selection;
- electrical source sizing, short-circuit, voltage-drop or battery-runtime calculations;
- cable route ownership outside the enclosure;
- full 3D CAD/BIM solid modelling.

Intrinsic physical impossibility may be `FAIL`. A jurisdictional minimum is never hardcoded into ELV6; ELV7 consumes ELV6 measurements/evidence and applies the selected normative profile.

---

## 3. Exact geometry: no persisted binary floating point

### 3.1 Canonical mechanical scalar

New ELV6 persisted geometry uses integer micrometres:

```dart
extension type const Elv6LengthUm(int value) {
  static const int umPerMm = 1000;

  Elv6LengthUm.fromWholeMm(int mm) : value = mm * umPerMm;
}
```

Rules:

1. Persisted/hash-significant ELV6 lengths are signed/unsigned integer µm as defined by the field contract.
2. Positive physical dimensions MUST be `> 0`.
3. Coordinates may be signed within a local frame.
4. JSON canonical form is a base-10 integer, not locale text and not a floating value.
5. The allowed magnitude MUST remain within the cross-platform exact integer range chosen by P1; values outside it fail decoding.
6. Project geometry expressed as integer millimetres converts exactly with `mm * 1000`.
7. Legacy `double` dimensions are compatibility inputs only. Import must reject NaN/infinity, decimal-normalize under a versioned codec, and prove the conversion error is within the declared import tolerance. Binary-double text is never hashed directly.

This supports sub-millimetre rack mechanics without making the project floor-geometry model fractional.

### 3.2 Geometry primitives

```dart
final class Elv6Point3 {
  final int xUm;
  final int yUm;
  final int zUm;
}

final class Elv6Size3 {
  final int widthUm;
  final int heightUm;
  final int depthUm;
}

final class Elv6Aabb3 {
  final Elv6Point3 min;
  final Elv6Point3 max; // half-open occupancy [min,max)
}

enum Elv6AxisDirection { posX, negX, posY, negY, posZ, negZ }

final class Elv6OrthoFrame {
  final Elv6Point3 origin;
  final Elv6AxisDirection xAxis;
  final Elv6AxisDirection yAxis;
  final Elv6AxisDirection zAxis;
}
```

V1 persisted placements use orthogonal frames only. Arbitrary-angle geometry may be added only with a separately versioned conservative backend and canonical serialization.

### 3.3 Local coordinate convention

Each host has one right-handed enclosure-local frame. Default engineering projection:

```text
+X = viewed-left to viewed-right from host front
+Y = bottom to top
+Z = front to rear
```

Front, rear, side and section views are projections of the same canonical geometry. The UI MUST NOT maintain separate mutable front/rear positions.

### 3.4 Half-open occupancy

Physical solids and discrete intervals use half-open semantics where possible:

```text
AABB: [minX,maxX) × [minY,maxY) × [minZ,maxZ)
Rack U span: [firstU, firstU + heightU)
DIN module span: [position, position + widthUnits)
```

Touching faces are not an overlap unless a required service/clearance envelope makes them one.

---

## 4. Stable owner and identity model

```dart
enum Elv6HostOwnerKind {
  panelAssembly,
  elvRack,
}

enum Elv6HostKind {
  electricalPanel,
  automationPanel,
  mixedPanel,
  wallCabinet,
  floorRack,
  floorCabinet,
  box,
  custom,
}

final class Elv6HostRef {
  final Elv6HostOwnerKind ownerKind;
  final String projectId;
  final String designRevisionId;
  final String hostId;
  final String logicalId;
  final int rowRevision;
  final String fingerprint;
}
```

`hostId` is revision-local. `logicalId` is stable across create-next revisions. Cross-stage subject references are immutable typed references:

```dart
final class Elv6SubjectRef {
  final String owner; // ELV2 / ELV3 / ELV4 / ELV5 / PANEL / ELV6
  final String kind;
  final String id;
  final String designRevisionId;
  final String fingerprint;
}
```

No label/SKU/name matching is allowed for identity.

### 4.1 Placement identity

```dart
final class Elv6Placement {
  final String id;
  final String logicalId;
  final String projectId;
  final String designRevisionId;
  final Elv6HostRef host;
  final String mountingSurfaceId;
  final Elv6SubjectRef subject;
  final Elv6OrthoFrame pose;
  final Elv6Aabb3 occupiedEnvelope;
  final Elv6MountingSide mountingSide;
  final Elv6DiscreteSpan? rackSpan;
  final Elv6DiscreteSpan? dinSpan;
  final bool locked;
  final int rowRevision;
  final String sourceProposalId;
}
```

A subject may have multiple placements only if its exact technical definition declares a multi-part physical installation. The default cardinality is one active placement per `(revision, subject, installationRole)`.

---

## 5. Mounting surfaces and physical capabilities

```dart
enum Elv6MountingSurfaceKind {
  dinRail,
  frontRackRails,
  rearRackRails,
  fourPostRackRails,
  shelf,
  backplate,
  doorInner,
  doorOuter,
  terminalRail,
  batteryTray,
  customPlane,
}

enum Elv6MountingSide { front, rear, internal, door, custom }
```

Each surface stores exact position/frame and capability facts, never just a display label:

```text
id / logicalId / revision
hostId
kind
frame
usableEnvelope
supportedMountingModes
rackProfileRef? / rackUCapacity?
railDepthRange?
dinPitchUm? / dinModuleCapacity?
maxStaticLoadGrams?
sourceDefinitionRef?
rowRevision / fingerprint
```

Unknown capability does not mean unlimited capability.

### 5.1 Rack profile

The engine does not hardcode “19-inch = every rack”. A versioned technical rack profile supplies interface dimensions:

```dart
final class Elv6RackMechanicalProfile {
  final String profileId;
  final int rackUnitPitchUm;
  final int frontInterfaceWidthUm;
  final int? rearInterfaceWidthUm;
  final int minRailDepthUm;
  final int maxRailDepthUm;
  final Set<String> mountingModes;
  final String sourceRef;
  final String contentHash;
}
```

A profile may reference IEC 60297 or a project/manufacturer definition, but ELV6 records provenance; ELV7 decides whether the reference is required/acceptable for the project.

---

## 6. Equipment physical definition contract

A placement cannot be validated from `moduleWidthUnits` alone. ELV6 resolves an exact immutable physical definition:

```dart
final class Elv6PhysicalSubjectDefinition {
  final Elv6SubjectRef subject;
  final Elv6Size3 bodyEnvelope;
  final List<Elv6MountingRequirement> mountingRequirements;
  final List<Elv6EnvelopeFeature> connectorProtrusions;
  final List<Elv6EnvelopeFeature> serviceEnvelopes;
  final List<Elv6EnvelopeFeature> removalEnvelopes;
  final List<Elv6EnvelopeFeature> airflowKeepouts;
  final int? massGrams;
  final Elv6Point3? centerOfGravityLocal;
  final int? heatLossMilliwatt;
  final Set<String> supportedOrientations;
  final String definitionHash;
}
```

Missing body dimensions blocks containment/collision. Missing mass blocks load/CoG only. Missing heat loss blocks thermal-input completeness only. Partial engineering evidence remains useful and must not be discarded.

Product/manufacturer dimensions from legacy catalogs are inputs only when an exact adopted edition/variant is already selected upstream. ELV6 does not select a product to make something fit.

---

## 7. Zones, ducts, access and door mechanics

The legacy `PanelReservedZone` and `PanelCableDuct` types lack enough spatial information for collision checks. ELV6 requires positioned geometry.

```dart
enum Elv6ZoneKind {
  noMount,
  reserved,
  futureExpansion,
  service,
  removal,
  ventilation,
  cableBend,
  highVoltageObserved,
  lowVoltageObserved,
  fireSystemObserved,
  batteryHandling,
  custom,
}

final class Elv6LayoutZone {
  final String id;
  final String hostId;
  final Elv6Aabb3 envelope;
  final Elv6ZoneKind kind;
  final bool blocksEquipment;
  final String? policyRef;
}
```

Legacy width/height-only zones may be imported only as `UNLOCATED_LEGACY_ZONE`; they cannot participate in geometric PASS until an anchor is supplied.

Door geometry is first-class:

```text
door panel envelope
hinge axis
closed frame
allowed opening interval
inside-mounted subjects
conservative swept envelope backend/version
```

A door-mounted device that fits when closed but collides during opening must not pass the access process.

---

## 8. Cable entries, gland plates, bend and strain-relief evidence

ELV3 remains external cable/run owner. ELV6 owns only enclosure-local physical ingress/termination assignment.

```dart
enum Elv6CableEntryKind {
  gland,
  glandPlate,
  knockout,
  brushPanel,
  floorOpening,
  roofOpening,
  sideOpening,
  rearOpening,
  custom,
}

final class Elv6CableEntry {
  final String id;
  final String hostId;
  final Elv6CableEntryKind kind;
  final Elv6OrthoFrame frame;
  final Elv6Aabb3 openingEnvelope;
  final int? maxCableCount;
  final int? usableAreaUm2;
  final String? technicalDefinitionRef;
}
```

Assignment stores exact cable/cable-end ref, entry, local approach direction and termination target.

The physical evaluator may enforce an exact cable/connector minimum bend radius or strain-relief envelope when that value is an adopted technical fact. A regulatory fill percentage or segregation minimum belongs to ELV7 unless explicitly supplied as a project engineering constraint with provenance.

---

## 9. Internal wiring duct and termination capacity basis

A constructible panel must reserve wiring space. ELV6 models:

```text
positioned duct body
usable internal cross-section
usable length
optional manufacturer fill/capability facts
assigned conductor/cable bundle refs
observed occupied area/volume basis
```

ELV6 reports used/free physical basis and missing facts. It does not invent conductor packing factors or normative maximum fill.

Terminal/patch capacity similarly separates:

```text
physical positions available
positions occupied
reserved positions
termination identity
connector/media compatibility facts
```

Logical LAN port capacity remains ELV5; physical patch-panel/termination arrangement is ELV6.

---

## 10. Battery, support load, mass and centre-of-gravity

Battery placement consumes exact ELV4 battery/bank identity and selected physical definition facts. It does not recompute Ah/runtime.

Required independent dimensions:

```text
body containment
orientation support
terminal/service access
handling/removal envelope
support load capability
host aggregate mass
centre-of-gravity basis
```

Mass arithmetic uses integer grams. Moment arithmetic uses exact integer `gram*micrometre` values before rational division for CoG.

```dart
final class Elv6MassProperties {
  final int massGrams;
  final Elv6Point3 centerOfGravity;
}
```

ELV6 may report a physical support overload if an adopted host/shelf technical definition gives a maximum static load. Seismic, anchorage, anti-tip and jurisdictional stability compliance remain ELV7. ELV6 exports the measured/derived mass and CoG basis needed for those rules.

---

## 11. Ventilation and thermal-input basis

Thermal engineering is not optional metadata for dense panels/racks, but ELV6 must keep the claim boundary clean.

ELV6 stores/measures:

- enclosure outer/usable envelope;
- material/surface technical refs when available;
- positioned ventilation openings;
- free opening areas;
- fan identity, position, flow direction and adopted airflow rating;
- equipment heat-loss values from exact technical definitions;
- spatial heat-source distribution;
- adjacent-wall/exposed-surface facts;
- internal partitions;
- ambient/design-condition references when supplied upstream.

`LAY-19` produces a **thermal-input basis**, not a conformity verdict. It may sum exact declared heat losses and report missing thermal facts. IEC TR 60890 or other temperature-rise methods are versioned normative/engineering profiles applied downstream; ELV6 does not silently implement a universal thermal formula.

A device electrical load is NOT equal to heat loss unless an exact technical model says so.

---

## 12. Physical segregation and protective bonding basis

### 12.1 Segregation

ELV6 may calculate actual shortest physical distance between declared envelopes/zones and export observed adjacency/intersection. It does not decide the required minimum unless an intrinsic manufacturer constraint is part of the technical definition.

### 12.2 Protective bonding

ELV6 represents physical bonding points and declared bond links for enclosure body, door, mounting plate, DIN rail, PE bar and rack frame where such facts exist:

```text
bondPoint(id, host, physicalLocation, ownerRef)
bondLink(id, fromPoint, toPoint, conductorRef?, strapRef?, routeLength?)
```

This is physical evidence only. Protective-conductor sizing, mandatory bonding rules and verification are ELV7/other electrical-rule concerns.

---

## 13. Evaluation state model — reuse the proven ELV5 separation

ELV6 MUST preserve four independent axes:

```dart
enum Elv6Freshness { current, stale }
enum Elv6Completion { complete, partial, blocked }
enum Elv6Assessment { pass, fail, unresolved, notAssessed }
enum Elv6Execution { succeeded, failed }
```

Rules:

- `execution=failed`: no valid engineering evaluation produced.
- completed physical violation: `succeeded + complete + fail`.
- missing mandatory body geometry: `blocked + unresolved` for geometry-dependent dimensions.
- missing mass does not block a valid geometric containment result; overall becomes `partial` if mass is required by the selected process.
- `notAssessed` is only for an explicitly out-of-scope dimension.
- freshness lives on current pointers, not immutable result rows.
- `RUNNING`/`CANCELLED` are transient workspace states, never durable engineering verdicts.

---

## 14. Closed process registry

Initial ELV6 runtime registers exactly 24 process codes:

```text
LAY-01 HOST_ENVELOPE
LAY-02 MOUNTING_SURFACE_CAPABILITY
LAY-03 PLACEMENT_CONTAINMENT
LAY-04 VOLUMETRIC_COLLISION
LAY-05 RACK_U_OCCUPANCY
LAY-06 RACK_RAIL_DEPTH_FIT
LAY-07 DIN_OCCUPANCY
LAY-08 SURFACE_MOUNTING_FIT
LAY-09 SERVICE_REMOVAL_ENVELOPE
LAY-10 DOOR_SWING_ACCESS
LAY-11 CABLE_ENTRY_OCCUPANCY
LAY-12 CABLE_BEND_STRAIN_ENVELOPE
LAY-13 WIRING_DUCT_CAPACITY_BASIS
LAY-14 TERMINATION_PATCH_CAPACITY
LAY-15 BATTERY_PHYSICAL_FIT
LAY-16 SUPPORT_LOAD
LAY-17 MASS_COG_STABILITY_BASIS
LAY-18 VENTILATION_AIRFLOW_ENVELOPE
LAY-19 THERMAL_INPUT_BASIS
LAY-20 RESERVE_CAPACITY_BASIS
LAY-21 SEGREGATION_DISTANCE_PROJECTION
LAY-22 PROTECTIVE_BONDING_PHYSICAL_BASIS
LAY-23 AUTO_LAYOUT_PROPOSAL
LAY-24 LAYOUT_AGGREGATE_VALIDATION
```

Unknown/custom executable processes are rejected. A project may carry data/profile parameters, not code/scripts/formulas.

`process-registry.json` is the machine-readable source for scope, required inputs, required dimensions and dependencies.

---

## 15. Evaluation identity and immutable result

```dart
final class Elv6LayoutNodeKeyV1 {
  final String designRevisionId;
  final String hostOwnerKind;
  final String hostId;
  final String processCode;
  final String subjectKind;
  final String subjectId;
}
```

Canonical tuple:

```text
["layout-node-v1","ELV6",designRevisionId,hostOwnerKind,hostId,processCode,subjectKind,subjectId]
```

Evaluation record:

```dart
final class Elv6LayoutEvaluationRecord {
  final String evaluationId;
  final Elv6LayoutNodeKeyV1 nodeKey;
  final String algorithmVersion;
  final String inputSchemaVersion;
  final String outputSchemaVersion;
  final String geometryBackendVersion;
  final String inputFingerprint;
  final Elv6Execution execution;
  final Elv6Completion completion;
  final Elv6Assessment assessment;
  final List<Elv6DimensionResult> dimensions;
  final List<Elv6ConsumedEvidenceRef> consumedEvidence;
  final List<Elv6LayoutFinding> findings;
  final String outputHash;
  final DateTime completedAtUtc;
}
```

Result records are immutable. Current pointer publication is generation-guarded.

---

## 16. Dependency keys and invalidation

Every result/proposal stores exact consumed dependencies, including missing-set sentinels.

Canonical dependency kinds:

```text
HOST
SURFACE
PLACEMENT
ZONE
ENTRY
ENTRY_ASSIGNMENT
SUBJECT_DEFINITION
UPSTREAM_EVIDENCE
SET_MEMBERSHIP
POLICY
MISSING
EVALUATION
POINTER
```

Examples:

- device dimension change → placement containment + collision neighbors + host aggregate;
- placement move → old and new collision closures + service + segregation + aggregate;
- battery physical definition change → battery fit + support + mass/CoG + thermal if heat data changed;
- cable endpoint change → entry/bend/termination closure;
- unrelated CCTV recording retention change → no layout invalidation unless a consumed rack/storage physical requirement changed;
- normative threshold edition change → ELV7 stale, not intrinsic ELV6 geometry stale unless ELV6 explicitly consumed that project engineering constraint.

Mutation invalidation is `union(oldClosure,newClosure)`. Missing input markers ensure later creation of the missing fact invalidates blocked evidence.

---

## 17. Deterministic solver contract

Auto-layout is proposal-only.

```dart
abstract interface class Elv6LayoutSolver {
  String get algorithmVersion;
  Elv6LayoutProposal solve(Elv6LayoutProblem problem);
}
```

Hard constraints are never traded against score. Optimization is lexicographic, not a hidden floating weighted sum:

```text
0 feasibility of all hard intrinsic constraints
1 zero movement of locked placements
2 minimize movement of existing manual placements
3 minimize unresolved service/bend/access conflicts
4 minimize exact physical affinity cost where evidence exists
5 minimize fragmentation
6 maximize declared future reserve
7 stable readability/order objective
8 stable-ID lexical tie-break
```

Proposal stores the complete score vector. Identical canonical input + algorithm/profile version MUST produce byte-identical canonical proposal/hash.

No randomness, wall-clock values, DB row order, hash-map iteration order or widget order may affect the proposal.

### 17.1 Proposal lifecycle

```text
DRAFT -> GENERATED -> ACCEPTED | REJECTED | STALE
```

Acceptance re-captures all owner row revisions, dependency fingerprints and pointer generations. A stale proposal is not partially written.

Selective acceptance is allowed only if P5 defines it as a new proposal over the selected subset and re-solves/revalidates the remaining constraints. UI checkbox selection must not bypass solver invariants.

---

## 18. Strict public wire boundary

New schema:

```text
electra.elv6-layout-command.v1
```

Initial payload schema version: `1`.

Top-level fields exactly match the proven ELV4/ELV5 command discipline:

```text
schema
operation
payloadSchemaVersion
projectId
designRevisionId
commandId
expectedDesignRowRevision
expectedRows
reviewedImpactFingerprint
payload
```

Unknown/missing top-level fields fail before DB mutation. `reviewedImpactFingerprint` is mandatory for durable mutations and proposal acceptance. Server-side impact/dependency sets are recomputed; the client cannot author them.

ELV4 revision commands remain the single public freeze/create-next boundary. ELV6 extends the coordinated revision transaction/snapshot; it does not create competing revision commands.

---

## 19. Exact 21-operation ELV6 command registry

Initial ELV6 command schema contains exactly:

```text
CREATE_RACK_ENCLOSURE
UPDATE_RACK_ENCLOSURE
ARCHIVE_RACK_ENCLOSURE
REPLACE_PANEL_LAYOUT_ROOT
REPLACE_MOUNTING_SURFACES
REPLACE_LAYOUT_ZONES
REPLACE_CABLE_ENTRIES
PLACE_LAYOUT_SUBJECT
MOVE_LAYOUT_SUBJECT
REMOVE_LAYOUT_SUBJECT
LOCK_LAYOUT_PLACEMENT
UNLOCK_LAYOUT_PLACEMENT
ASSIGN_CABLE_ENTRY
RELEASE_CABLE_ENTRY
REPLACE_PHYSICAL_BONDING_ASSIGNMENTS
GENERATE_LAYOUT_PROPOSAL
ACCEPT_LAYOUT_PROPOSAL
REJECT_LAYOUT_PROPOSAL
CALCULATE_LAYOUT_PROCESS
REPLACE_LAYOUT_TECHNICAL_PROFILE
RELEASE_LAYOUT_TECHNICAL_PROFILE
```

`REPLACE_PANEL_LAYOUT_ROOT` is enabled only under the P0-proven panel owner adapter. If P0 finds an accepted existing panel writer, the same public semantic operation delegates to that writer; it must not write a shadow table.

Exact payload keys live in `command-registry.json`. Runtime startup must prove one semantic codec for every registered operation and no extra codec.

---

## 20. Replay-first transaction protocol

For every mutation:

```text
1 decode exact schema/operation/version
2 canonicalize request and calculate immutable requestHash
3 open transaction
4 lookup commandId in ledger
5 if same commandId + same requestHash -> return original committed response
6 if same commandId + different requestHash -> COMMAND_ID_PAYLOAD_CONFLICT
7 reload design revision and assert WORKING
8 resolve actual canonical owner and authorization
9 reload expectedRows and verify CAS
10 resolve old dependency closure
11 validate strict typed payload + intrinsic ownership/cardinality
12 build new state in memory
13 resolve new dependency closure
14 persist canonical rows
15 invalidate union(old,new) current pointers
16 append reversible history with full forward/inverse payload
17 append ledger response + outbox in same UoW
18 commit
```

Replay happens before mutable preconditions by design.

No widget performs multi-table writes directly.

---

## 21. Capture → pure run → guarded publication

Calculation/proposal generation:

```text
A short read transaction captures facts + row revisions + pointer generations
B transaction closes
C pure kernel/solver executes without DB access
D publication transaction reloads lifecycle/revisions/dependencies
E if any consumed generation/fingerprint changed -> STALE_CAPTURE / no CURRENT publication
F immutable record/proposal inserted
G pointer CAS updates generation
H commit
```

Late publication after freeze MUST fail.

A `FAIL`, `PARTIAL` or `BLOCKED` engineering evaluation is still publishable if the kernel executed correctly and the capture remains current.

---

## 22. Persistence contract

Current repository DB schema is 23; ELV5 has not yet allocated a final implementation migration. ELV6 MUST NOT reserve schema 24 prematurely. At runtime entry:

```text
ELV6 target schema = accepted ELV5 runtime schema + additive ELV6 migration(s)
```

P0 records exact origin versions and tested upgrade matrix.

If panel persistence is absent, ELV6 promotion uses normalized revision-scoped panel tables preserving `PanelAssembly` semantics. If existing tables are discovered, the mapping must show reuse/migration and no duplicates.

Required conceptual roots:

```text
panel_layout_root                 // only if runtime panel owner absent at P0
panel_mounting_section            // same rule
panel_din_rail                    // same rule
panel_layout_placement            // same rule
panel_layout_zone                 // positioned canonical zone
panel_cable_duct                  // positioned canonical duct

elv6_rack_enclosure
elv6_mounting_surface             // rack-owned + extension surfaces
elv6_rack_placement
elv6_layout_zone                  // non-panel / extension zones
elv6_cable_entry
elv6_cable_entry_assignment
elv6_bond_point
elv6_bond_link
elv6_technical_profile_binding
elv6_layout_proposal
elv6_layout_proposal_item
elv6_layout_evaluation
elv6_layout_pointer
elv6_layout_finding
elv6_layout_dependency_ref
```

### 22.1 Required columns/invariants

All revision-owned mutable roots include:

```text
id
logical_id
design_revision_id
project_id (direct or compositely provable)
row_revision
created_at
updated_at
deleted_at?
origin_device_id
```

Cross-owner refs store owner/kind/id/revision/fingerprint. Use real FK only where ownership and database lifetime permit it; otherwise validate transactionally and store immutable provenance.

Required uniqueness examples:

```text
UNIQUE(design_revision_id, logical_id)
UNIQUE(design_revision_id, host_id, placement_id)
UNIQUE(design_revision_id, subject_owner, subject_kind, subject_id, installation_role) WHERE active
UNIQUE(design_revision_id, cable_owner, cable_id, cable_end_role) WHERE exclusive_active
UNIQUE(design_revision_id, host_id, mounting_surface_id, rack_lane, rack_position) where discrete exclusive slot row model is used
```

Opaque JSON is allowed for immutable diagnostic payloads/canonical evidence, never as the only mutable placement truth.

---

## 23. Freeze, history and create-next

ELV6 extends the coordinated revision snapshot with versioned section:

```text
elv6LayoutSectionVersion
canonicalLayoutHash
proposalEvidenceHash
layoutEvaluationHash
```

Frozen snapshot contains canonical panel/rack layout facts needed to reproduce evidence plus selected immutable evaluations/proposals. Pre-ELV6 snapshots return `ELV6_NOT_CAPTURED`, distinct from captured empty layout.

Create-next remaps every ELV6 revision-owned ID using typed logical mappings. Historical R1 IDs remain immutable provenance. No latest-row fallback is allowed when reading frozen revisions.

Undo/redo uses full reversible payloads and revision-local cursor semantics shared with the accepted command history.

---

## 24. Finding model

```dart
enum Elv6FindingSeverity { info, warning, error }

final class Elv6LayoutFinding {
  final String code;
  final Elv6FindingSeverity severity;
  final Elv6HostRef host;
  final String? placementId;
  final Elv6SubjectRef? subject;
  final Map<String, Object?> measured;
  final Map<String, Object?> capability;
  final List<Elv6ConsumedEvidenceRef> evidence;
  final String stableSortKey;
}
```

Required stable codes include:

```text
HOST_GEOMETRY_MISSING
OUT_OF_BOUNDS
PLACEMENT_OVERLAP
MOUNTING_MODE_INCOMPATIBLE
RACK_U_CONFLICT
RACK_RAIL_DEPTH_INCOMPATIBLE
DIN_INTERVAL_CONFLICT
DEPTH_CONFLICT
SERVICE_ENVELOPE_CONFLICT
REMOVAL_ENVELOPE_CONFLICT
DOOR_SWING_CONFLICT
CABLE_ENTRY_CONFLICT
CABLE_ENTRY_CAPACITY_EXCEEDED
CABLE_BEND_ENVELOPE_CONFLICT
TERMINATION_CAPACITY_EXCEEDED
BATTERY_ENVELOPE_CONFLICT
BATTERY_ORIENTATION_UNSUPPORTED
SUPPORT_LOAD_EXCEEDED
MASS_DATA_MISSING
COG_BASIS_UNRESOLVED
VENTILATION_ENVELOPE_CONFLICT
THERMAL_INPUT_INCOMPLETE
SEGREGATION_GEOMETRY_UNRESOLVED
BONDING_PHYSICAL_BASIS_INCOMPLETE
UPSTREAM_EVIDENCE_MISSING
UPSTREAM_EVIDENCE_STALE
LEGACY_ZONE_UNLOCATED
```

Codes are machine stable. Human text is localization/display content and never drives logic.

---

## 25. Engineer workspace contract

The layout workspace is an engineering tool, not a drag-and-drop toy.

Mandatory interactions:

- host tree/list with project/revision/owner/status;
- front, rear, side and section projections where facts allow them;
- rack-U and DIN interval rulers;
- millimetre/sub-mm numeric inspector using exact canonical values;
- keyboard nudge and direct numeric entry; drag is optional convenience, never the only editor;
- snapping by rack U, DIN pitch/module, technical anchors and explicit grid;
- multi-select, lock/unlock, group move preview;
- layers for equipment, zones, ducts, entries, service/removal, airflow/thermal, segregation and bonding;
- “why cannot place here?” pre-commit diagnostic from the pure validator;
- used/free/reserved U, DIN, termination, entry and mass summaries;
- exact provenance navigation back to ELV3/4/5 inputs;
- stale capture/proposal warning distinct from engineering FAIL;
- proposal score vector and before/after diff;
- conflict keeps the engineer's draft and shows current canonical state;
- frozen revision is fully read-only;
- compact view retains selection/draft while suppressing nonessential layers, not data.

A canvas coordinate becomes canonical only after command success.

---

## 26. ELV7 projection contract

ELV6 publishes a versioned immutable owner-neutral projection containing measurements, not normative verdicts:

```text
projectionSchemaVersion
projectId / designRevisionId
host refs + physical definitions
placements + exact envelopes
zones / ducts / cable entries
rack/DIN occupancy
service/removal/door-sweep envelopes
cable bend/termination basis
battery/mass/CoG basis
ventilation openings/fans/heat-loss facts
observed segregation distances/intersections
physical bonding points/links
intrinsic findings
consumed evidence refs
canonicalHash
```

ELV7 must be able to apply a new normative profile without mutating ELV6 canonical geometry.

---

## 27. ELV8 substitution/revalidation contract

ELV8 may select an exact manufacturer/SKU only after ELV6 has expressed technical envelope requirements. A substitution that changes any consumed physical fact emits impact keys for targeted ELV6 invalidation.

Examples:

```text
width/height/depth -> containment/collision/service
mounting mode -> surface capability
mass/CoG -> support/mass basis
heat loss -> thermal basis
connector protrusion -> service/cable-bend
rack depth/mounting -> rack rail fit
```

ELV8 cannot silently resize a cabinet or rearrange a layout to force a product to fit.

---

## 28. Acceptance model

P8 qualification uses only public commands for current-version setup. Raw SQL is allowed solely for historical migration seeds/read assertions.

Minimum exact-head proof categories:

1. schema migration from accepted predecessor and fresh DB;
2. panel semantic-baseline promotion/reuse with no duplicate canonical owner;
3. file-SQLite close/reopen persistence;
4. exact µm serialization/hash and legacy-double import boundaries;
5. positive/negative/blocked oracle for every `LAY-01…24` process;
6. panel DIN, wall cabinet and floor rack public-command verticals;
7. battery/service/cable-entry/duct/termination/mass/thermal-basis fixtures;
8. deterministic solver golden/hash proof;
9. locked placement immutability;
10. response-loss replay and commandId payload conflict;
11. failure injection at canonical write/invalidation/history/ledger/snapshot/pointer publication boundaries;
12. two-connection stale proposal acceptance race;
13. freeze vs publish race;
14. R1 freeze → R2 create-next/remap → historical R1 reproduction;
15. old+new targeted invalidation with unrelated negative controls;
16. corrupted/missing upstream refs fail closed;
17. ELV7 projection canonical hash stability;
18. workload-scale performance benchmark under a pinned CI benchmark class.

No structural checker substitutes for runtime evidence.

---

## 29. Implementation package boundaries

Target code organization:

```text
packages/engineering_core/lib/src/elv6/
  fixed_geometry.dart
  host.dart
  physical_subject.dart
  mounting_surface.dart
  placement.dart
  zone.dart
  cable_entry.dart
  mass_thermal.dart
  process_registry.dart
  processes/
  solver/
  evaluation.dart
  projection.dart

apps/mobile/lib/application/elv6/
  elv6_wire_command.dart
  elv6_wire_semantic_adapter.dart
  elv6_command_service.dart
  elv6_query_service.dart
  elv6_capture_service.dart
  elv6_publication_service.dart
  elv6_workspace_controller.dart

apps/mobile/lib/data/elv6/
  elv6_database_tables.dart
  drift_elv6_repository.dart
  elv6_migrations.dart
  elv6_snapshot_codec.dart
```

`engineering_core` has no Flutter/Drift/HTTP imports. Drift rows are decoded into immutable core values before calculation. Widgets invoke application services only.

---

## 30. Closure rule

ELV6 may be marked runtime CLOSED only when:

- the baseline ownership matrix is evidence-backed;
- one and only one canonical writer is proven for every physical fact class;
- all 24 process contracts are implemented and qualified;
- all 21 command codecs are exact and public-path tested;
- migrations/restart/replay/rollback/concurrency/freeze/create-next are proven at one source SHA;
- ELV7/ELV8 projections are versioned and hash-stable;
- there are zero open BLOCKER/HIGH findings;
- unsupported dimensions remain explicit rather than converted into optimistic PASS.
