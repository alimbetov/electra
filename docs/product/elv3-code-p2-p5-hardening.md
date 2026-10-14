# Electra — ELV3 P2-P5 Code Implementation Hardening

Status: AUTHORITATIVE P2-P5 CODE HARDENING / CLOSED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Parent authority: `docs/product/elv3-code-remediation-final-clarifications.md`

## 1. Purpose

Close remaining implementation ambiguities in P2-P5 after the CR-01..CR-16 remediation. This document wins over earlier P2-P5 code-level wording on conflict. It does not change the accepted ELV3 domain architecture.

Pass criterion:

```text
P2-P5 implementation choices affecting behavior are frozen
open BLOCKER findings = 0
open HIGH findings = 0
```

---

# P2 hardening — allocation, atomic claims and terminations

## 2. P2-01 — resource claims use exact `(cableId, atomicResourceIdentity)` uniqueness

`claim_key` is removed as an architectural identity. A string-composed claim key MUST NOT be the source of truth.

`CableResourceClaims` canonical identity:

```text
allocation_id FK
cable_id FK
resource_atom
created_at
origin_device_id
PRIMARY KEY(allocation_id, resource_atom)
UNIQUE(cable_id, resource_atom)
```

The unique `(cable_id, resource_atom)` constraint is the concurrency backstop.

Stable conflict:

```text
ELV_ALLOC_RESOURCE_CONFLICT
```

### Whole-cable semantics

Every published `CableDefinition` contains exactly one reserved resource identity:

```text
__WHOLE_CABLE__
```

with `kind = wholeCable`.

Rules:

- it may be atomic only when the definition exposes no finer allocatable physical resource;
- otherwise it is the root of the physical resource graph;
- `WholeCableSelection` selects `__WHOLE_CABLE__`;
- claim resolution recursively expands the selected resource to the complete sorted set of atomic descendants;
- therefore WHOLE_CABLE conflicts with every partial selection through the same `(cable_id, resource_atom)` uniqueness;
- no sentinel-only claim is used.

`ResourceSetSelection` and `DefinitionGroupSelection` also resolve to the union of atomic descendants, sorted and deduplicated before persistence/hash calculation.

## 3. P2-02 — separate claim resolution from termination-obligation resolution

Claim atoms and termination targets are different concepts.

Add pure type:

```dart
final class CableTerminationObligation {
  const CableTerminationObligation({
    required this.obligationKey,
    required this.resourceIdentity,
    required this.end,
    required this.terminalRequired,
    required this.allowedRoles,
  });

  final String obligationKey;
  final String resourceIdentity;
  final CableTerminationEnd end;
  final bool terminalRequired;
  final List<String> allowedRoles;
}
```

Add pure resolver:

```dart
abstract final class CableTerminationObligationResolver {
  static List<CableTerminationObligation> resolve({
    required CableDefinition definition,
    required CableResourceSelection selection,
  });
}
```

Exact rules:

1. Claim resolution always expands to atomic physical resources.
2. Termination resolution starts from the explicitly selected resource identities, not from claim rows.
3. If a selected resource has `TerminationPolicyMode.groupLevel`, the obligation target remains that selected composite/group resource; descendants do not produce duplicate obligations.
4. Otherwise termination resolution descends to atomic descendants and uses each atomic resource's own policy.
5. `bothEnds` -> obligations A and B.
6. `aEndOnly` -> obligation A only.
7. `bEndOnly` -> obligation B only.
8. `optional` -> no required obligation; a supplied mapping is still validated if present.
9. `terminalRequired=false` means endpoint port binding is required but `endpointTerminalRef` may be null.
10. `terminalRequired=true` requires non-empty `endpointTerminalRef`.
11. `allowedRoles` is enforced after canonical role normalization.

Obligation key is deterministic:

```text
<resourceIdentity>|<A-or-B>
```

`CableTerminationMappings.resource_identity` stores the obligation resource identity, not necessarily an atomic claim identity.

Activation succeeds only when the complete persisted mapping set satisfies every required obligation exactly once and contains no mapping outside the allowed obligation set.

## 4. P2-03 — exact allocation mutation lifecycle

Command guards are frozen:

```text
CreateCableAllocationDraft  -> creates DRAFT only
ReserveCableResources       -> DRAFT -> RESERVED
ReplaceCableTerminationSet  -> RESERVED or ACTIVE only
ActivateCableAllocation     -> RESERVED -> ACTIVE
ReleaseCableResources       -> RESERVED or ACTIVE -> RELEASED
ArchiveCableAllocation      -> DRAFT -> ARCHIVED OR RELEASED -> ARCHIVED only
```

No other state is accepted.

Every successful mutation increments `CableAllocation.revision`, including complete-set termination replacement.

`RELEASED` and `ARCHIVED` are immutable historical states in P2-P9 except technical soft-delete tooling outside ordinary engineering workflow.

## 5. P2-04 — releasing the last consuming allocation while a current run exists

A CableRun is cable-level, while allocations may be many-to-one. Therefore release logic is:

```text
release allocation X
  -> compute remaining RESERVED/ACTIVE allocations for same Cable excluding X
  -> if remaining count > 0: release allowed
  -> if remaining count == 0 and current WORKING revision has ACTIVE CanonicalCableRun for Cable:
       reject ELV_ALLOC_RELEASE_BLOCKED_BY_ACTIVE_RUN
  -> otherwise release allowed
```

Before P3 exists, the run-dependency adapter returns no current run. P3 extends the adapter without changing P2 command API.

This prevents an active canonical route from becoming detached from all logical consuming allocations while still permitting one physical multicore Cable to serve several connections.

## 6. P2-05 — EngineeringConnection endpoint integrity

Every Reserve/ReplaceTermination/Activate transaction reloads the current `EngineeringPortConnection` and exact endpoint ports.

Persistent termination mappings MUST bind only to the connection's current `fromPortId` and `toPortId` according to A/B mapping semantics.

Introduce application integration port:

```dart
abstract interface class ElvConnectionPhysicalDependencyInspector {
  Future<bool> hasSelectionHistory(String projectId, String connectionId);
  Future<bool> hasConsumingAllocation(String projectId, String connectionId);
  Future<List<String>> blockingPhysicalDependencyIds(
    String projectId,
    String connectionId,
  );
}
```

Any existing or future ELV1 command that destructively deletes/re-endpoints an `EngineeringPortConnection` MUST consult this inspector once P2 is installed. A connection with immutable P2 selection history cannot be silently re-endpointed; engineering change requires forward physical reallocation/history semantics.

P9 audits this integration if such a topology mutation API exists.

## 7. P2 persistence corrections

`CableResourceClaims`:

```text
UNIQUE(cable_id, resource_atom)
```

not `UNIQUE(claim_key)`.

`CableTerminationMappings` retains:

```text
UNIQUE(allocation_id, resource_identity, end_role)
```

and complete-set replacement is the only persisted mutation path in RESERVED/ACTIVE.

Required tests:

```text
WHOLE_CABLE vs conductor overlap -> conflict
PAIR composite vs one child conductor -> conflict
GROUP selection vs overlapping member -> conflict
group-level termination -> one group obligation/end, not child duplicates
one-ended shield policy -> no false B-end requirement
last allocation release with active run -> blocked
release one of multiple allocations on same Cable -> allowed
```

---

# P3 hardening — revision routing and reusable geometry

## 8. P3-01 — exact project ownership resolver for legacy reusable route graph

Existing `CableRoutes` are room-owned, not project-owned. ELV3 MUST derive project identity through the canonical existing chain:

```text
CableRoute.roomId
  -> Room.floorId
  -> Floor.projectId
```

Introduce transaction-bound read helper/port:

```dart
abstract interface class ElvRouteProjectResolver {
  Future<String> projectIdForRoute(String routeId);
  Future<String> projectIdForSegment(String routeSegmentId);
  Future<String> projectIdForNode(String routeNodeId);
}
```

All CreateCableRun/Reroute/RouteHandoff/BendEvidence/shared-route-edit operations require the resolved project to equal command project.

No route project is inferred from selected Cable or current UI room.

## 9. P3-02 — exact RouteHandoff continuity semantics

P3 v1 uses no numeric tolerance.

A `RouteHandoff` is valid only when one of these deterministic proofs holds:

### Exact world-interface proof

```text
fromNode.worldXmm == toNode.worldXmm
fromNode.worldYmm == toNode.worldYmm
fromNode.worldZmm == toNode.worldZmm
```

or

### Exact adjacency proof

`adjacencyRef` resolves to an existing project-local `SurfaceAdjacency`/accepted typed adjacency whose endpoints correspond to the two route-node surfaces/interfaces.

Rules:

- both nodes must resolve to same project;
- self-handoff is forbidden;
- handoff remains zero length;
- absence of exact-coordinate or typed-adjacency proof -> `ELV_ROUTE_HANDOFF_INTERFACE_MISMATCH`;
- no arbitrary millimeter tolerance or floating geometry epsilon may be introduced in P3 v1.

Direction semantics:

- `bidirectional=true` accepts both traversal directions;
- otherwise continuity is only `fromRouteNodeId -> toRouteNodeId`.

## 10. P3-03 — canonical candidate geometry type for shared route edit

Freeze public application candidate:

```dart
final class CableRouteGeometryCandidate {
  const CableRouteGeometryCandidate({
    required this.route,
    required this.nodes,
    required this.segments,
  });

  final CableRoute route;
  final List<CableRouteNode> nodes;
  final List<CableRouteSegment> segments;
}
```

`EditReusableRouteGeometryCommand.candidateGeometry` uses this type.

Candidate validation must run the same `CableRouteValidator` path as persisted routing and additionally the canonical+legacy impact validation defined by CR-07/FC-05.

## 11. P3-04 — no orphan active run after allocation changes

`CreateCableRun` prerequisite remains >=1 RESERVED/ACTIVE allocation for the Cable.

The reverse invariant is enforced by P2-04: releasing the last consuming allocation is blocked while current WORKING revision has an ACTIVE canonical run.

Archiving/superseding the run first then permits releasing the final allocation.

Required cross-phase test:

```text
ACTIVE run + one ACTIVE allocation
release allocation -> blocked
supersede/archive run
release allocation -> succeeds
```

---

# P4 hardening — PathwayContext, carrier and compartments

## 12. P4-01 — exact lifecycle types

Add:

```dart
enum PathwayContextLifecycleState { active, archived }
enum PhysicalCarrierLifecycleState { active, archived }
enum CarrierCompartmentLifecycleState { active, archived }
```

`PathwayContext`, `PhysicalCarrier`, and `PhysicalCarrierCompartment` each carry their lifecycle state and revision in domain state.

Transitions are only:

```text
ACTIVE -> ARCHIVED
```

No restore in ELV3 P4.

## 13. P4-02 — host reference validation is transaction-bound

Pure `PathwayContextValidator` validates shape/matrix/acyclicity over materialized facts. The P4 command service must also materialize actual host ownership inside one write session.

P4 write session includes read capabilities for:

```text
Project
Floor
Room
SpatialFeature
PathwayContext parent
CanonicalCableRun/traversal dependencies
```

Exact host rules:

- `RoomHost.roomId` exists and belongs to project;
- `FloorHost.floorId` exists and belongs to project;
- `SurfaceVoidHost.floorId` and `spatialFeatureId` both exist in same project and the spatial feature's surface/room resolves to that floor;
- `VerticalHost.fromFloorId` and `toFloorId` exist in same project and MUST differ;
- optional vertical `spatialFeatureId` must belong to one of the involved vertical/pathway project contexts and same project;
- `ProjectHost.projectId == context.projectId`;
- parent context exists, same project, ACTIVE, and passes the frozen parent-kind matrix;
- no direct or transitive parent cycle.

No host FK is accepted merely because a raw id exists in another project.

## 14. P4-03 — archive dependency guards

### ArchivePathwayContext

Allowed only when:

```text
no ACTIVE child PathwayContext
no ACTIVE PhysicalCarrier references the context
```

else:

```text
ELV_PATHWAY_ARCHIVE_BLOCKED
```

### ArchivePhysicalCarrier

Allowed only when:

```text
no traversal in current WORKING revision references carrier or any compartment
```

else:

```text
ELV_CARRIER_ARCHIVE_BLOCKED
```

### ArchiveCarrierCompartment

Allowed only when no current WORKING traversal references it; else:

```text
ELV_CARRIER_COMPARTMENT_ARCHIVE_BLOCKED
```

Historical FROZEN snapshots do not block archive because they embed their facts and remain immutable.

## 15. P4-04 — compartment capacity invariant

Define factual cross-sectional usable area:

```text
Rectangular = widthMm * heightMm
Circular    = PI * diameterMm^2 / 4
Custom      = explicit usableAreaMm2
```

All dimensions/areas must be finite and > 0.

For a carrier with ACTIVE compartments:

```text
sum(active compartment usableAreaMm2)
  <= carrier usableAreaMm2
```

Otherwise reject:

```text
ELV_CARRIER_COMPARTMENT_CAPACITY_EXCEEDED
```

This is a necessary factual capacity check, not a geometric proof that compartment shapes tile perfectly. P4 does not invent compartment offsets/shape packing.

Any carrier cross-section update revalidates this invariant before commit.

## 16. P4-05 — exact command-service/UoW split

Earlier repository mutation methods are superseded.

Application mutation owner:

```text
ElvPathwayCommandService
ElvPhysicalCarrierCommandService
```

Read repositories remain query/watch ports only.

P4 phase-specific session extends `ElvWriteSession` with only P4-required stores; it must not require P5/P6 stores.

---

# P5 hardening — deterministic compatibility profiles and engine

## 17. P5-01 — exact profile/domain shape

Add:

```dart
final class PhysicalCompatibilityProfile {
  const PhysicalCompatibilityProfile({
    required this.code,
    required this.label,
    required this.rules,
    this.deprecated = false,
  });

  final String code;
  final String label;
  final List<PhysicalCompatibilityRule> rules;
  final bool deprecated;
}
```

Rules:

- `code` canonical normalized and unique in exact catalog edition;
- deprecated profile cannot be newly placed into an ACTIVE project profile set;
- rule codes unique after normalization inside profile;
- unknown rule kind fails profile decoding/publication;
- profile hash covers exact canonical v1 profile JSON.

## 18. P5-02 — typed rule applicability selector

Every compatibility rule has an explicit selector; no rule applies through implicit heuristics.

```dart
final class PhysicalCompatibilitySelector {
  const PhysicalCompatibilitySelector({
    this.mediaCodes = const {},
    this.cableCategoryCodes = const {},
    this.cableTechnicalClassCodes = const {},
    this.carrierKinds = const {},
    this.pathwayKinds = const {},
  });

  final Set<String> mediaCodes;
  final Set<String> cableCategoryCodes;
  final Set<String> cableTechnicalClassCodes;
  final Set<PhysicalCarrierKind> carrierKinds;
  final Set<PathwayContextKind> pathwayKinds;
}
```

Matching semantics:

- empty selector dimension = wildcard;
- non-empty dimension = subject must match at least one value in that dimension;
- dimensions combine with AND;
- selector matching is deterministic and occurs before rule combination/evaluation.

Every concrete `PhysicalCompatibilityRule` contains:

```text
ruleCode
selector
rule payload
```

## 19. P5-03 — exact v1 rule semantics

### AllowedCableClassRule

Payload:

```text
allowedTechnicalClassCodes
```

Applicable CableDefinition must have at least one `technicalClassCode` in allowed set. If the applicable definition has no technical classes -> UNRESOLVED, not automatic allow.

### AllowedCarrierKindRule

Applicable `PhysicalCarrier.kind` must belong to `allowedKinds`.

### AllowedInstallationClassRule

Compares `CarrierInstallationFacts.installationClassCode` against `allowedClassCodes`. Missing applicable installation class -> UNRESOLVED.

### AllowedEnvironmentClassRule

Payload includes exact environment dimension:

```dart
enum CompatibilityEnvironmentDimension {
  exposure,
  moisture,
  contamination,
  climate,
}
```

It compares the corresponding typed `CarrierEnvironmentFacts` code against `allowedClassCodes`. Missing applicable fact -> UNRESOLVED.

### MaximumCableDiameterRule

Uses exact `CableDefinition.outerDiameterMm`. Missing diameter -> UNRESOLVED. Value above maximum -> FORBIDDEN.

### MinimumCarrierUsableAreaRule

Uses factual carrier/compartment usable area. Missing/invalid area -> UNRESOLVED. Value below minimum -> FORBIDDEN.

### DirectIntrinsicProhibitionRule

If selector matches and typed subject code/value matches the prohibition payload -> FORBIDDEN with exact reason code.

No P5 v1 rule applies jurisdictional KZ/IEC/EN acceptance thresholds.

## 20. P5-04 — explicit combiner API and deterministic result

Add pure types:

```dart
final class CombinedPhysicalCompatibilityRules {
  final List<PhysicalCompatibilityRule> rules;
  final List<PhysicalCompatibilityProfileRef> sourceRefs;
  final String combinedFingerprint;
}

abstract final class PhysicalCompatibilityProfileCombiner {
  static CombinedPhysicalCompatibilityRules combine({
    required List<ResolvedPhysicalCompatibilityProfile> profiles,
    required PhysicalCompatibilitySubjectFacts subject,
  });
}
```

Combination occurs only across applicable rules after selector filtering.

Rules with the same semantic key combine as already frozen:

```text
allowed sets -> intersection
maximum numeric -> minimum
minimum numeric -> maximum
direct prohibition -> union
```

Empty intersection or incompatible typed combination -> `UNRESOLVED_PROFILE_CONFLICT`.

The combiner never relies on profile list order for precedence.

## 21. P5-05 — exact engine version and status ordering

Initial engine version:

```text
elv.physical-compatibility.v1
```

Engine version is included in every finding input fingerprint and derived result payload.

Stable status severity order for sorting/aggregation:

```text
FORBIDDEN
UNRESOLVED
WARNING
OK
```

Then sort by:

```text
code
first affected entity id
```

No implementation-defined enum ordinal is used as persisted severity meaning.

## 22. P5-06 — profile-set mutation requires current WORKING revision

After P3 is installed, these mutations require `PhysicalDesignContext.editingAllowed == true` and one WORKING design revision:

```text
CreatePhysicalCompatibilityProfileSet
ReplaceActivePhysicalCompatibilityProfileSet
ArchivePhysicalCompatibilityProfileSet
```

Reason: changing the active technical profile set changes current physical compatibility evidence and P5/P6 dependency state.

The active set itself remains project-owned, but every mutation is performed in the current WORKING physical design context and invalidates only that revision's current derived nodes.

FROZEN snapshots preserve the exact profile refs used when frozen.

## 23. P5-07 — exact active-set reference validation

Before activating a set:

```text
all refs unique by (catalogId, catalogVersion, profileCode)
all refs resolve same project
all profile content hashes match
no referenced profile deprecated
all referenced profile schemas supported
all rules validate
```

Duplicate exact refs are rejected:

```text
ELV_PROFILE_SET_DUPLICATE_REF
```

Profile-set lifecycle is explicitly:

```dart
enum PhysicalCompatibilityProfileSetState { active, archived }
```

Do not model canonical state as an independent `bool active` plus lifecycle column.

## 24. P5 command/UoW ownership

Mutation owner:

```text
ElvPhysicalProfileSetCommandService
```

Query ports expose reads only.

P5 write session includes only:

```text
command ledger
physical design context/revision read
reference profile reads
profile-set writes
P5/P6 derived invalidation primitive
```

It does not require P6 separation-evidence persistence to compile P5.

---

# 25. Required P2-P5 acceptance tests

## P2

```text
whole-cable claim conflicts with child atom
composite/group claim conflicts through atomic expansion
group-level termination obligations do not duplicate child obligations
one-ended shield termination activates correctly
invalid extra termination mapping is rejected
termination replacement increments allocation revision
last consuming allocation release blocked by active run
allocation archive state guards deterministic
```

## P3

```text
route/segment/node project derived through Room->Floor->Project
cross-project route segment rejected
handoff exact world coordinate accepted
handoff typed adjacency accepted
handoff arbitrary near-coordinate without adjacency rejected
shared geometry candidate uses existing CableRouteValidator
```

## P4

```text
cross-project Room/Floor/SpatialFeature host rejected
vertical host requires distinct same-project floors
parent cycle rejected
archive context with active carrier rejected
archive carrier/compartment with current traversal rejected
sum compartment factual areas > carrier factual area rejected
```

## P5

```text
selector wildcard/AND semantics deterministic
missing applicable environment fact -> UNRESOLVED
allowed-set intersection conflict -> UNRESOLVED_PROFILE_CONFLICT
max/min numeric combination deterministic
profile order does not change combined result/fingerprint
profile-set duplicate ref rejected
profile mutation without WORKING revision rejected
engine result includes algorithm version and stable status order
```

## 26. Closure

```text
P2 atomic claim identity/WHOLE semantics          CLOSED
P2 termination obligation semantics              CLOSED
P2 lifecycle/release-run integration             CLOSED
P2 ELV1 endpoint dependency integration          CLOSED
P3 route project ownership                       CLOSED
P3 handoff continuity                            CLOSED
P3 candidate geometry contract                   CLOSED
P4 lifecycle/host/archive/capacity guards        CLOSED
P5 profile shape/applicability/rule semantics    CLOSED
P5 combiner/version/status/work-context          CLOSED
```
