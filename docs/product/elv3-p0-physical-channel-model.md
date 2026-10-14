# Electra — ELV3 P0.4 PhysicalChannel Factual Model

Status: DESIGN CONTRACT / P0.4  
Branch: `feat/flutter-elv3-physical-routing-design`  
Depends on: P0.1/P0.2 ownership/cardinality and P0.3 cable resource model  
Implementation status: NOT STARTED

## 1. Purpose

P0.4 freezes the factual model for pathways/containment used by ELV3 routing and compatibility.

The goal is to separate:

```text
persisted physical facts
from
versioned engineering/normative rules
```

`PhysicalChannel` describes what exists in the project. It MUST NOT embed anonymous mutable thresholds such as maximum fill percentage, mandatory segregation distance, permitted fire class or jurisdictional compliance decisions.

## 2. Scope

P0.4 covers factual modelling of:

- tray;
- conduit;
- trunking;
- channel compartments/dividers;
- usable geometry/capacity basis;
- spatial ownership/context;
- environment/install facts;
- route-segment attachment;
- vertical/riser continuity requirements;
- provenance of factual dimensions when imported or measured.

P0.4 does not define:

- regulatory fill percentages;
- separation distances;
- fire-code acceptance;
- electrical derating;
- PoE/power calculations;
- manufacturer product selection;
- legal compliance claims.

## 3. Canonical responsibility

`PhysicalChannel` is a spatial installation asset that may carry zero or many route segments.

Frozen cardinality from P0.1/P0.2:

```text
RouteSegment -> 0..1 PhysicalChannel
PhysicalChannel -> 0..N RouteSegment
```

A channel does not own cables or logical connections. Occupancy is derived from route segments and their owning CableRuns/Cables.

## 4. Channel kinds

Current kinds:

```text
CONDUIT
TRAY
TRUNKING
```

P0.4 preserves these and reserves extension for factual kinds such as:

```text
DUCT
BASKET_TRAY
LADDER_TRAY
UNDERFLOOR
RISER
SHAFT
CUSTOM
```

No discipline-specific kinds (`CCTV_TRAY`, `FIRE_TRAY`, etc.) are permitted.

The exact enum/value set may expand in P4 implementation, but every kind must remain a physical/pathway classification rather than a rule outcome.

## 5. PhysicalChannel conceptual contract

```text
PhysicalChannel {
  id
  projectId
  code
  name
  kind
  spatialContext
  crossSection
  usableCapacityFacts
  compartments[]
  environmentFacts
  installationFacts
  provenance
  lifecycleStatus
}
```

The current `roomId`-only model is insufficient for ELV3 because vertical and shared pathways may cross room/floor boundaries.

## 6. Spatial ownership/context

P0.4 rejects hard-coding every channel as room-owned.

Canonical concept:

```text
ChannelSpatialContext
  room-local
  floor-common
  riser/shaft
  project/shared infrastructure
```

A channel must have one authoritative spatial host/context.

Candidate typed fields:

```text
contextType
roomId?
floorId?
spatialFeatureId?
shaftOrRiserId?
```

The exact persistence shape is deferred to P0.8, but invalid combinations must be impossible in the domain model.

Examples:

```text
wall conduit        -> room-local
corridor tray       -> floor/common or corridor room context
vertical riser      -> shaft/riser context
main service duct   -> shared/project infrastructure
```

## 7. Cross-section model

A channel must expose factual geometry sufficient to derive usable cross-sectional area or support a documented direct capacity fact.

Canonical shapes:

```text
RECTANGULAR
CIRCULAR
CUSTOM
```

### 7.1 Rectangular

```text
widthMm  > 0
heightMm > 0
```

Gross area is derived:

```text
widthMm * heightMm
```

### 7.2 Circular

```text
diameterMm > 0
```

Gross area is derived geometrically.

### 7.3 Custom

For a channel whose usable geometry cannot be represented by the primitive shapes, P0.4 permits a factual explicit area with provenance:

```text
usableAreaMm2
source/evidence
```

A custom area without provenance is `UNRESOLVED` for calculations that require trusted capacity.

## 8. Gross vs usable area

P0.4 explicitly separates:

```text
gross physical area
usable factual area
normative permitted fill
```

`PhysicalChannel` may persist/derive:

```text
grossCrossSectionAreaMm2
usableCrossSectionAreaMm2
```

but MUST NOT persist an anonymous rule like:

```text
maxFillPercent = 40
```

unless that value is a versioned rule/profile reference, not a factual property of the channel.

The compatibility engine later evaluates:

```text
occupiedArea / usableArea
against
selected rule profile
```

## 9. Compartments and dividers

P0.4 requires first-class compartment modelling where the physical channel is divided.

Conceptual contract:

```text
ChannelCompartment {
  id
  channelId
  code
  order
  crossSection
  usableAreaMm2?
}
```

A divider is represented through compartment structure rather than as free text.

Canonical rule:

```text
RouteSegment may reference either
  PhysicalChannel as a whole
or
  one explicit ChannelCompartment
```

The implementation may eventually replace `physicalChannelId` with a typed channel target reference, but P0.4 does not approve schema yet.

## 10. Compartment occupancy semantics

If a segment is assigned to a compartment, occupancy belongs to that compartment, not to the undivided whole-channel pool.

Compatibility must therefore calculate fill/segregation against the selected compartment facts.

A segment cannot simultaneously occupy two compartments.

## 11. Environment facts

Persist only observed/declared facts, not conclusions.

Candidate factual dimensions:

```text
installationEnvironment:
  INDOOR
  OUTDOOR
  UNDERGROUND
  WET
  DAMP
  CORROSIVE
  PLENUM_OR_VOID
  HIGH_TEMPERATURE
  CUSTOM

exposure facts
fireZoneId?
penetrationIds?
mechanicalProtectionClass?
```

P0.4 does not prescribe a final exhaustive enum because project/source catalogs may require extension, but the model must use structured values rather than discipline-specific booleans such as `allowedForFireCable`.

## 12. Installation facts

Candidate facts:

```text
openOrClosed
embeddedOrExposed
accessibleForMaintenance
supportMethod
installationClass
```

These facts may later participate in compatibility rules.

They MUST NOT directly encode rule outcomes such as `compatible=true`.

## 13. Route-segment binding

The existing route kernel already attaches optional `physicalChannelId` to a `RouteSegment`.

P0.4 retains this architecture conceptually:

```text
RouteSegment
  -> channel target optional
```

Free/surface/wall-chase routing can remain without a channel reference.

Contained routing requires a channel target compatible with the segment's laying method.

Current validation rule matching laying method and channel kind is retained as a structural baseline, but future compatibility may allow richer mapping than exact enum-name equality.

## 14. Channel continuity

Channel continuity is a physical-pathway concept and MUST NOT imply cable continuity or logical topology.

Examples:

```text
tray branch
conduit branch
riser continuation
shaft transition
```

may connect pathway geometry without creating:

- an EngineeringConnection;
- a Cable splice;
- an electrical circuit edge.

This preserves the existing rule that crossing/connected geometry does not infer logical connectivity.

## 15. Vertical/riser modelling

A vertical riser is not correctly represented by pretending it belongs to one room.

P0.4 requires a spatial context capable of representing multi-floor infrastructure.

A cable may have:

```text
Run floor 1
Run riser section
Run floor 2
```

and the riser run may reference a riser/shaft channel whose spatial context spans floors.

The precise handoff model is completed in P0.6/P0.7, but no `roomId` fiction may be introduced merely to satisfy current schema constraints.

## 16. Capacity evidence/provenance

For every non-derived factual capacity/dimension, the system must be able to preserve where the fact came from.

Candidate provenance:

```text
MANUAL_ENTRY
MEASURED
IMPORTED_DRAWING
CATALOG
BIM_IMPORT
MIGRATED_LEGACY
```

with optional:

```text
sourceReference
sourceVersion
capturedAt
capturedBy
```

Detailed audit lifecycle is finalized in P0.5.

## 17. Occupancy derivation

`PhysicalChannel` MUST NOT maintain an independently editable list of cable IDs as source of truth.

Occupancy is derived from:

```text
PhysicalChannel
 <- RouteSegment
 <- CableRoute
 <- CableRun
 -> Cable
```

This avoids dual ownership and restart drift.

Cached/materialized occupancy may exist later for performance but must be rebuildable from canonical references.

## 18. Fill basis

ELV3-P6 will calculate a fill basis using cable physical facts and channel facts.

P0.4 only freezes required source semantics:

```text
CableDefinition.outerDiameter / equivalent occupied area basis
PhysicalChannel usable area / compartment usable area
RouteSegment -> selected channel target
```

No normative acceptance threshold is hard-coded in P0.4.

## 19. Segregation basis

P0.4 supports factual segregation by making compartment identity and pathway spatial facts explicit.

It does NOT decide whether two cable classes are legally allowed together.

Later compatibility evaluates:

```text
cable facts + other occupancy + channel/compartment facts + rule profile
```

## 20. Fire/penetration facts

Where a route crosses a fire boundary/penetration, P0.4 permits factual references such as:

```text
fireZoneId
penetrationId
penetrationType
seal/system reference
```

but compliance evaluation is deferred to ELV7 rules.

A factual penetration record must not contain an unproven `compliant=true` source-of-truth flag.

## 21. Structural validation

Minimum structural validation codes:

```text
CHANNEL_MISSING_IDENTITY
CHANNEL_PROJECT_MISMATCH
CHANNEL_INVALID_SPATIAL_CONTEXT
CHANNEL_INVALID_DIMENSIONS
CHANNEL_AREA_UNRESOLVED
CHANNEL_COMPARTMENT_DUPLICATE
CHANNEL_COMPARTMENT_INVALID
CHANNEL_TARGET_MISMATCH
CHANNEL_KIND_UNSUPPORTED
CHANNEL_PROVENANCE_MISSING
```

Structural invalidity blocks persistence/commit where required facts are malformed.

Engineering incompatibility remains a separate compatibility result.

## 22. Four-discipline walkthrough

### CCTV — PASS

```text
camera room wall segment
  -> no channel / surface route
corridor segment
  -> tray T-01
telecom room segment
  -> conduit C-12
```

Same physical cable can move through several pathway types without creating multiple logical connections.

### LAN — PASS

Permanent-link cables share a corridor tray. Occupancy is derived from each cable's route segments referencing the tray.

No tray-owned cable list is needed.

### ACS — PASS

Several logical ACS connections may share one multicore cable. The tray sees one physical cable occupancy through the cable's route/run geometry, not four independent logical connections.

This is a critical invariant for fill calculations.

### Fire — PASS

A fire cable may be routed through a compartment/channel. The channel persists facts only; compatibility rules later decide whether that containment is permitted.

An invalid scenario can therefore produce:

```text
FORBIDDEN: fire/segregation/containment
```

without mutating channel facts.

## 23. Important occupancy invariant for multicore cables

When several `CableAllocation` records share one `Cable`, pathway fill MUST count the physical `Cable` once, not once per allocation.

Canonical derivation:

```text
Channel occupancy
  -> distinct physical Cable identities on referencing runs/segments
```

NOT:

```text
number of EngineeringConnections
or
number of CableAllocations
```

This prevents severe over-counting in ACS and other multicore scenarios.

## 24. Invalid models rejected

P0.4 rejects:

```text
PhysicalChannel.allowedForFire = true
PhysicalChannel.maxFillPercent = anonymous mutable number
PhysicalChannel.cableIds[] as canonical ownership
PhysicalChannel.networkId
roomId required for every pathway including risers
CCTV/LAN/ACS/FIRE-specific channel entities
free-text compartment assignment
fill counted per CableAllocation rather than physical Cable
pathway continuity implying electrical/logical continuity
```

## 25. Required pure-domain direction

Equivalent pure-domain capabilities are required later:

```text
ChannelGeometryResolver
  -> gross/usable geometry facts

ChannelOccupancyResolver
  -> distinct cables occupying channel/compartment

PhysicalRoutingCompatibilityEngine
  -> evaluates facts against versioned rules
```

Facts/resolution must be deterministic and repository-independent.

## 26. Persistence direction, not schema approval

P0.4 implies future storage for:

```text
PhysicalChannels
ChannelCompartments
spatial context references
factual dimensions/capacity
provenance
```

but P0.8 will decide exact schema after lifecycle and migration analysis.

The current `PhysicalChannels(id, roomId, name, kind)` records must be migratable without data loss.

## 27. P0.4 acceptance gate

P0.4 is CLOSED when all statements below are accepted:

- [x] channel facts are separated from normative/rule thresholds;
- [x] room-only ownership is rejected for shared/riser infrastructure;
- [x] rectangular/circular/custom cross-section facts are representable;
- [x] gross area, usable area and allowed fill are distinct concepts;
- [x] compartments/dividers are first-class factual structures;
- [x] route segment targets at most one channel/compartment;
- [x] occupancy is derived from route/run/cable references;
- [x] multicore cable occupancy is counted once per physical Cable;
- [x] channel continuity does not imply cable/logical continuity;
- [x] environment/install/fire-zone facts are factual, not verdicts;
- [x] vertical/riser pathways do not require fake room ownership;
- [x] CCTV/LAN/ACS/Fire all fit the same model;
- [x] existing route geometry kernel remains reusable;
- [x] exact schema remains deferred to P0.8.

## 28. Remaining P0 work

```text
P0.5  Lifecycle / deletion / audit / provenance
P0.6  Migration from electrical CableRun
P0.7  Full four-discipline walkthrough
P0.8  Persistence proposal
P0.9  Hard design review
```

No implementation migration begins before P0.9 closes the design contract.
