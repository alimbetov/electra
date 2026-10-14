# Electra — ELV3 Code-Level Implementation Contract P4–P6

Status: AUTHORITATIVE CODE DESIGN / P4–P6  
Branch: `feat/flutter-elv3-physical-routing-design`  
Parent authority: `docs/product/elv3-dual-review-process-hardening.md`

## 1. Purpose

Freeze the code-level implementation shape for pathway/carrier persistence, physical compatibility profiles and reproducible physical calculations. This document assumes P1–P3 exact-SHA gates are closed.

---

# P4 — PathwayContext / PhysicalCarrier / compartments

## 2. Exact source-file plan

Core:

```text
packages/engineering_core/lib/src/elv_pathway_context.dart
packages/engineering_core/lib/src/elv_physical_carrier.dart
```

Application:

```text
apps/mobile/lib/application/elv_pathway_command.dart
apps/mobile/lib/application/elv_pathway_repository.dart
apps/mobile/lib/application/elv_physical_carrier_command.dart
apps/mobile/lib/application/elv_physical_carrier_repository.dart
```

Data:

```text
apps/mobile/lib/data/repositories/drift_elv_pathway_repository.dart
apps/mobile/lib/data/repositories/drift_elv_physical_carrier_repository.dart
```

Tests:

```text
packages/engineering_core/test/elv_pathway_context_test.dart
packages/engineering_core/test/elv_physical_carrier_test.dart
apps/mobile/test/data/elv_carrier_fanout_test.dart
apps/mobile/test/data/elv_p4_restart_test.dart
```

## 3. Pathway domain types

```dart
enum PathwayContextKind {
  roomLocal,
  floorCommon,
  ceilingVoid,
  underfloor,
  riser,
  shaft,
  projectShared,
}

sealed class PathwayContextHost {
  const PathwayContextHost();
}

final class RoomHost extends PathwayContextHost {
  final String roomId;
}

final class FloorHost extends PathwayContextHost {
  final String floorId;
}

final class SurfaceVoidHost extends PathwayContextHost {
  final String floorId;
  final String spatialFeatureId;
}

final class VerticalHost extends PathwayContextHost {
  final String fromFloorId;
  final String toFloorId;
  final String? spatialFeatureId;
}

final class ProjectHost extends PathwayContextHost {
  final String projectId;
}
```

Canonical validator:

```dart
abstract final class PathwayContextValidator {
  static List<ElvPathwayFailure> validate({
    required PathwayContext context,
    required Map<String, PathwayContext> projectContexts,
  });
}
```

It validates kind/host matrix, project ownership, parent compatibility and transitive acyclicity.

## 4. Carrier domain types

```dart
enum PhysicalCarrierKind {
  tray,
  basketTray,
  ladderTray,
  conduit,
  trunking,
  duct,
  custom,
}

sealed class CarrierCrossSection {}
final class RectangularCarrierCrossSection extends CarrierCrossSection {
  final double widthMm;
  final double heightMm;
}
final class CircularCarrierCrossSection extends CarrierCrossSection {
  final double diameterMm;
}
final class CustomCarrierCrossSection extends CarrierCrossSection {
  final double usableAreaMm2;
  final String provenance;
}

final class PhysicalCarrier {
  final String id;
  final String projectId;
  final String pathwayContextId;
  final String code;
  final String name;
  final PhysicalCarrierKind kind;
  final CarrierCrossSection crossSection;
  final Map<String, Object?> environmentFacts;
  final Map<String, Object?> installationFacts;
  final int revision;
}

final class PhysicalCarrierCompartment {
  final String id;
  final String carrierId;
  final String code;
  final int sequence;
  final CarrierCrossSection crossSection;
  final int revision;
}
```

## 5. P4 command API

Exact commands:

```text
CreatePathwayContextCommand
UpdatePathwayContextCommand
ArchivePathwayContextCommand
CreatePhysicalCarrierCommand
UpdatePhysicalCarrierCommand
ArchivePhysicalCarrierCommand
CreateCarrierCompartmentCommand
UpdateCarrierCompartmentCommand
ArchiveCarrierCompartmentCommand
AttachTraversalToCarrierCommand
DetachTraversalFromCarrierCommand
```

Commands that can fan out (`UpdatePathwayContext`, `UpdatePhysicalCarrier`, `UpdateCarrierCompartment`) MUST contain:

```dart
required String expectedImpactFingerprint;
```

`AttachTraversalToCarrierCommand` must contain expected `CanonicalCableRun.revision` because attachment changes revision-scoped traversal evidence.

## 6. P4 repository ports

```dart
abstract interface class ElvPathwayRepository {
  Future<List<PathwayContext>> loadContexts(String projectId);
  Future<PathwayContext?> findContext(String projectId, String id);
  Future<CommandResult<PathwayContext>> create(CreatePathwayContextCommand c);
  Future<CommandResult<PathwayContext>> update(UpdatePathwayContextCommand c);
  Future<CommandResult<void>> archive(ArchivePathwayContextCommand c);
}

abstract interface class ElvPhysicalCarrierRepository {
  Future<List<PhysicalCarrier>> loadCarriers(String projectId);
  Future<CarrierImpactPreview> previewImpact(CarrierMutationCandidate c);
  Future<CommandResult<PhysicalCarrier>> create(CreatePhysicalCarrierCommand c);
  Future<CommandResult<PhysicalCarrier>> update(UpdatePhysicalCarrierCommand c);
  Future<CommandResult<void>> archive(ArchivePhysicalCarrierCommand c);
}
```

UI first calls preview for shared carrier mutation, displays affected run count/list, then submits command with the returned fingerprint.

## 7. P4 Drift tables

Exact names:

```text
PathwayContexts
PhysicalCarriers
PhysicalCarrierCompartments
```

PathwayContexts columns:

```text
id PK
project_id FK
kind
host_type
room_id nullable FK
floor_id nullable FK
from_floor_id nullable FK
to_floor_id nullable FK
spatial_feature_id nullable FK
parent_context_id nullable self-FK
provenance_json
lifecycle_state
revision/audit
```

Host columns are validated transactionally. Do not introduce generic `hostJson` as authoritative identity.

PhysicalCarriers:

```text
id PK
project_id FK
pathway_context_id FK
code
normalized_code
name
kind
cross_section_json
environment_facts_json
installation_facts_json
lifecycle_state
revision/audit
UNIQUE active(project_id, normalized_code)
```

Compartments:

```text
id PK
carrier_id FK
code
normalized_code
sequence
cross_section_json
lifecycle_state
revision/audit
UNIQUE active(carrier_id, normalized_code)
UNIQUE active(carrier_id, sequence)
```

## 8. Attach traversal transaction

```text
BEGIN IMMEDIATE
  command/idempotency check
  load WORKING PhysicalDesignContext
  load CanonicalCableRun expected revision
  load traversal
  load carrier + optional compartment
  validate project equality
  validate compartment belongs to carrier
  validate carrier/context lifecycle active
  update traversal carrier refs
  increment CableRun revision
  invalidate segment/carrier/pathway dependent keys
  command record
COMMIT
```

A traversal may reference either whole carrier or one compartment, not several compartments simultaneously.

## 9. Shared carrier mutation

```text
preview:
  find all traversals using carrier/compartment
  collect CanonicalCableRun id+revision
  compute impact fingerprint

commit:
BEGIN IMMEDIATE
  recompute impact set
  require same fingerprint
  validate candidate carrier/context
  revalidate every affected traversal attachment
  update shared fact
  invalidate all affected run/carrier calculation keys
COMMIT
```

No mutation may silently detach or repair dependent traversals.

---

# P5 — Technical physical compatibility

## 10. Exact source-file plan

Core:

```text
packages/engineering_core/lib/src/elv_physical_compatibility.dart
packages/engineering_core/lib/src/elv_physical_compatibility_profile.dart
```

Application:

```text
apps/mobile/lib/application/elv_physical_compatibility_repository.dart
apps/mobile/lib/application/elv_physical_compatibility_service.dart
apps/mobile/lib/application/elv_physical_profile_set_command.dart
```

Data:

```text
apps/mobile/lib/data/repositories/drift_elv_physical_profile_set_repository.dart
apps/mobile/lib/data/repositories/drift_elv_physical_compatibility_repository.dart
```

Tests:

```text
packages/engineering_core/test/elv_physical_compatibility_test.dart
packages/engineering_core/test/elv_physical_profile_combination_test.dart
apps/mobile/test/data/elv_p5_restart_test.dart
```

## 11. P5 profile types

```dart
final class PhysicalCompatibilityProfileRef {
  final String catalogId;
  final String catalogVersion;
  final String profileCode;
  final String profileContentHash;
}

final class ProjectPhysicalCompatibilityProfileSet {
  final String id;
  final String projectId;
  final List<PhysicalCompatibilityProfileRef> refs;
  final bool active;
  final int revision;
}
```

`PhysicalCompatibilityProfile` is added to `EngineeringReferenceCatalog` only in P5. Existing `profiles` and P1 `cableDefinitions` wire fields remain unchanged.

Hash helper:

```dart
String physicalCompatibilityProfileContentHashV1(
  PhysicalCompatibilityProfile profile,
);
```

Marker exactly `electra.physical-compatibility-profile.v1`.

## 12. Profile-set commands

```text
CreatePhysicalCompatibilityProfileSetCommand
ReplaceActivePhysicalCompatibilityProfileSetCommand
ArchivePhysicalCompatibilityProfileSetCommand
```

There is at most one ACTIVE set/project.

Replace-active transaction:

```text
BEGIN IMMEDIATE
  resolve every exact profile ref/hash
  validate all same project
  validate typed profile rules
  archive previous active set if present
  create/activate new set
  invalidate all P5/P6 dependency keys for project WORKING revision
  command record
COMMIT
```

No implicit latest profile lookup.

## 13. Compatibility engine interface

```dart
enum PhysicalCompatibilityStatus { ok, warning, forbidden, unresolved }

final class PhysicalCompatibilityFinding {
  final PhysicalCompatibilityStatus status;
  final String code;
  final List<String> affectedEntityIds;
  final String inputFingerprint;
  final String explanation;
  final List<PhysicalCompatibilityProfileRef> sourceProfileRefs;
}

abstract final class PhysicalCompatibilityEngine {
  static List<PhysicalCompatibilityFinding> evaluate(
    PhysicalCompatibilityInput input,
  );
}
```

`PhysicalCompatibilityInput` is immutable and fully materialized before pure evaluation. Core engine never queries repositories.

Minimum typed inputs:

```text
CableDefinition
Cable allocation/resource evidence
termination evidence
CanonicalCableRun + traversals
route geometry facts
RouteBendEvidence
PhysicalCarrier/compartment facts
PathwayContext facts
combined PhysicalCompatibilityProfile rules
```

## 14. Deterministic rule ordering

Engine evaluates categories in stable order:

```text
1 structural resource completeness
2 endpoint/media intrinsic compatibility
3 laying-method/construction
4 bend evidence
5 dimensional fit
6 environment compatibility
7 shared-containment factual findings
```

Findings sort by:

```text
severity/status order
code
first affected entity id
```

Profile combination occurs before evaluation. Conflict returns `UNRESOLVED_PROFILE_CONFLICT`; engine never silently picks one profile.

## 15. P5 persistence

Exact tables:

```text
ProjectPhysicalCompatibilityProfileSets
ProjectPhysicalCompatibilityProfileRefs
```

Compatibility findings SHOULD be derived/cache state rather than canonical business rows. Reuse the project derived-result infrastructure with revision-scoped keys instead of adding a second result cache.

Node key prefix:

```text
elv3:<designRevisionId>:P5:<subjectType>:<subjectId>
```

Fingerprint includes every exact source revision/hash.

---

# P6 — Common physical calculations / evidence

## 16. Exact source-file plan

Core:

```text
packages/engineering_core/lib/src/elv_physical_calculations.dart
packages/engineering_core/lib/src/elv_physical_evidence.dart
```

Application:

```text
apps/mobile/lib/application/elv_physical_calculation_service.dart
apps/mobile/lib/application/elv_physical_calculation_nodes.dart
```

No new canonical calculation tables unless existing `ProjectDerivedResults` cannot carry required typed result JSON/state. Preferred design is reuse of existing dependency-recalculation storage with revision-scoped node keys.

Tests:

```text
packages/engineering_core/test/elv_installed_length_test.dart
packages/engineering_core/test/elv_carrier_occupancy_test.dart
packages/engineering_core/test/elv_bend_evidence_test.dart
apps/mobile/test/application/elv_dependency_invalidation_test.dart
apps/mobile/test/data/elv_p6_restart_test.dart
```

## 17. Stable process codes

```dart
enum ElvPhysicalProcessCode {
  installedLength,       // ELV-ROUTE-01
  carrierFillBasis,      // ELV-ROUTE-02
  segregationEvidence,   // ELV-ROUTE-03
  bendRadiusBasis,       // ELV-ROUTE-04
  congestionBasis,       // ELV-ROUTE-05
  reserveAllowance,      // ELV-ROUTE-06
}
```

Persist canonical string values exactly:

```text
ELV-ROUTE-01 ... ELV-ROUTE-06
```

## 18. Calculation result type

```dart
enum ElvCalculationState { current, stale, blocked, failed }

final class ElvPhysicalCalculationResult<T> {
  final String processCode;
  final String algorithmVersion;
  final String projectId;
  final String designRevisionId;
  final String subjectId;
  final T? value;
  final String unit;
  final ElvCalculationState state;
  final String inputFingerprint;
  final Map<String, Object?> trace;
  final List<String> blockingCodes;
}
```

No calculation returns a numeric fallback when required facts are absent.

## 19. Installed length implementation

Pure function:

```dart
ElvPhysicalCalculationResult<double> calculateInstalledLength({
  required CanonicalCableRun run,
  required List<CableRunTraversalGeometry> traversals,
});
```

Formula exactly:

```text
geometricTraversalLengthMm = sum(segment physical lengths)
handoff length = 0
installedLengthMm =
  geometricTraversalLengthMm * (1 + reservePercent / 100)
  + terminationAllowanceMm
```

`terminationAllowanceMm` is run-total, not per endpoint.

Algorithm version initial value:

```text
elv.route.length.v1
```

## 20. Cable occupied area

```dart
double? cableOccupiedAreaMm2(CableDefinition definition);
```

Rules:

```text
if explicit occupiedAreaMm2 -> use it
else if outerDiameterMm -> PI*d^2/4
else -> null/BLOCKED
```

Explicit occupied area wins over derived circular area because it may represent non-circular construction.

## 21. Occupancy key and aggregation

```dart
final class CarrierUsageKey {
  final String routeSegmentId;
  final String physicalCarrierId;
  final String? carrierCompartmentId;
}
```

Source rows are traversals. For every key:

```text
distinct cableId set
sum occupied area once per cable
carrier/compartment usable factual area
```

Do not aggregate by CableAllocation.

Result:

```dart
final class CarrierOccupancyEvidence {
  final CarrierUsageKey key;
  final List<String> cableIds;
  final double occupiedAreaMm2;
  final double usableAreaMm2;
  final double factualFillRatio;
}
```

`factualFillRatio = occupied/usable`; it is evidence only. P6 does not compare to jurisdictional maximum fill.

## 22. Bend-radius process

For every traversed route node classified as bend:

```text
minimumBendRadiusMm from exact CableDefinition
actual radius from active RouteBendEvidence
```

Missing evidence when minimum exists -> BLOCKED.

Comparison is intrinsic technical evidence:

```text
actual >= minimum -> OK basis
actual < minimum  -> intrinsic technical failure
```

Do not label this result as code/jurisdiction compliance.

## 23. Segregation / congestion evidence

P6 may output:

```text
same carrier
same compartment
barrier present
actual measurable separation when geometry supports it
number of distinct cables per CarrierUsageKey
occupied/usable factual area
```

P6 must not store or apply KZ/IEC/EN required distance/fill thresholds.

## 24. Dependency nodes

Node keys MUST include design revision:

```text
elv3:<designRevisionId>:ELV-ROUTE-01:cable-run:<runId>
elv3:<designRevisionId>:ELV-ROUTE-02:carrier-usage:<segment>/<carrier>/<compartment-or-none>
elv3:<designRevisionId>:ELV-ROUTE-04:route-node:<nodeId>:cable:<cableId>
```

Inputs MUST include stable revisions/hashes, not whole mutable repository objects.

Example installed-length inputs:

```text
run id/revision
traversal ids/order/direction
segment ids + geometry revision/hash
reservePercent
terminationAllowanceMm
algorithmVersion
```

## 25. Invalidation rules

Minimum invalidation map:

```text
CableDefinitionRef/physical facts change
  -> P5 + P6 affected Cable keys

Traversal chain/route geometry change
  -> length + bend + occupancy + segregation + compatibility

Carrier/compartment change
  -> occupancy + segregation + compatibility

PathwayContext environment change
  -> compatibility + affected environment evidence

Profile-set change
  -> P5 + any P6 process consuming intrinsic profile facts
```

Application commands emit dependency keys; calculation service does not discover changes by scanning the whole project.

## 26. P4–P6 exact-SHA gate

Each phase gate adds:

```text
pure core tests
mobile repository/service tests
restart reconstruction
fan-out/dependency tests
legacy routing regression
Drift generation/analyze/format/full existing suite
```

P6 gate additionally requires deterministic expected numeric fixtures for CCTV/LAN/ACS/Fire/Fiber and verifies identical result fingerprints after database reopen.