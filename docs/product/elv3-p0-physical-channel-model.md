# Electra — ELV3 P0.4 Physical Carrier and Pathway Factual Model

Status: REMEDIATED DESIGN CONTRACT / P0-R5 + P0-R7  
Branch: `feat/flutter-elv3-physical-routing-design`  
Authoritative parent: `docs/product/elv3-p0-system-architecture-remediation.md`  
Implementation status: HOLD UNTIL P0-R10

## 1. Purpose

This document replaces the first P0.4 model where `PhysicalChannel` mixed physical carrier kinds with spatial pathway contexts.

ELV3 now separates:

```text
PhysicalCarrier
  = what physically carries the cable

PathwayContext
  = where that carrier/path exists spatially
```

It also sharpens the boundary between ELV3 technical compatibility and ELV7 normative compliance.

## 2. Corrected physical model

```text
CableRun
  -> CableTraversal[]
  -> reusable Route / geometry
  -> optional PhysicalCarrier
  -> PathwayContext
```

A free/surface route may have no carrier while still belonging to a spatial context.

## 3. PhysicalCarrier

`PhysicalCarrier` is a factual project asset such as:

```text
TRAY
BASKET_TRAY
LADDER_TRAY
CONDUIT
TRUNKING
DUCT
CABLE_LADDER
CUSTOM_CARRIER
```

Carrier kinds are physical construction/containment classifications. Discipline-specific kinds such as `CCTV_TRAY` or `FIRE_CONDUIT` are prohibited.

Conceptual contract:

```text
PhysicalCarrier {
  id
  projectId
  code
  name
  kind
  pathwayContextId
  crossSection
  compartments[]
  environmentFacts
  installationFacts
  provenance
  lifecycleStatus
  revision
}
```

## 4. PathwayContext

`PathwayContext` models spatial routing context independent from carrier construction.

Initial typed contexts:

```text
ROOM_LOCAL
FLOOR_COMMON
CORRIDOR
CEILING_VOID
UNDERFLOOR
RISER
SHAFT
PROJECT_SHARED
CUSTOM_CONTEXT
```

Conceptual contract:

```text
PathwayContext {
  id
  projectId
  kind
  roomId?
  floorId?
  spatialFeatureId?
  verticalSpan?
  parentContextId?
  geometry/evidence references
}
```

Examples:

```text
shaft S-01
  -> tray T-01
  -> conduit C-02

ceiling void CV-01
  -> basket tray BT-04
```

A shaft/riser is therefore not treated as if it were itself a tray or conduit.

## 5. Cross-section facts

Carrier cross-section may be:

```text
RECTANGULAR(widthMm, heightMm)
CIRCULAR(diameterMm)
CUSTOM(usableAreaMm2 + provenance)
```

Separate:

```text
gross physical area
usable factual area
normative allowed fill
```

`maxFillPercent` is not a mutable carrier fact.

## 6. Compartments/dividers

Where a carrier is physically divided, compartments are first-class facts:

```text
CarrierCompartment {
  id
  carrierId
  code
  order
  crossSection / usableArea
}
```

A traversal may occupy the whole carrier or one specific compartment, but never multiple compartments simultaneously for the same traversal segment unless a future explicit split model is introduced.

## 7. Occupancy

Occupancy is derived, not stored as a mutable cable list:

```text
PhysicalCarrier
  <- CableTraversal
  <- CableRun
  -> Cable
```

One physical Cable counts once for the occupied path segment regardless of how many `CableAllocation` records use resources inside that cable.

This is mandatory for ACS/multicore correctness.

## 8. Carrier continuity versus cable continuity

Connected carrier geometry does not imply cable continuity and never creates logical topology.

Examples:

```text
tray branch
conduit branch
shaft transition
carrier transition
```

are pathway facts only.

Cable continuity is established by the ordered CableRun traversal chain and explicit terminations/transitions where required.

## 9. Environment and installation facts

Persist factual inputs such as:

```text
INDOOR / OUTDOOR
WET / DAMP
UNDERGROUND
CORROSIVE
PLENUM_OR_VOID
HIGH_TEMPERATURE
open/closed
embedded/exposed
support method
maintenance accessibility
fire-zone reference
penetration reference
```

Do not persist verdict fields such as:

```text
allowedForFireCable=true
compliant=true
```

as source-of-truth facts.

## 10. ELV3 technical compatibility boundary

ELV3 may evaluate deterministic physical/technical facts such as:

- resource overlap;
- geometric continuity;
- carrier dimensional availability;
- cable minimum bend-radius versus actual geometry;
- definition-declared permitted installation method;
- technical environment compatibility;
- factual occupied-area/fill basis;
- physical compartment assignment;
- carrier/pathway availability.

ELV3 findings may use statuses such as:

```text
COMPATIBLE
WARNING
FORBIDDEN
UNRESOLVED
```

but the finding must identify itself as technical physical compatibility, not jurisdictional compliance.

## 11. ELV7 normative boundary

ELV7 owns evaluation that depends on a jurisdiction/normative rule pack, including:

- permitted maximum fill percentage;
- required segregation distance;
- statutory fire-cable routing requirements;
- mandatory firestop/penetration treatment;
- code-specific exceptions and waivers;
- formal standards/jurisdiction compliance claims.

Canonical composition:

```text
ELV3 physical facts/evidence
  + ELV7 versioned rule pack
  -> NormativeComplianceFinding
```

ELV3 must never claim `COMPLIES WITH <standard/jurisdiction>` without ELV7 rule provenance.

## 12. Vertical routing

A cable crossing several floors remains one Cable and one active CableRun per revision:

```text
CableRun
  -> traversal floor 1
  -> traversal carrier in shaft S-01
  -> traversal floor 2
```

No fake room ownership and no CableRun split are introduced merely because a pathway spans floors.

## 13. Provenance

Carrier and pathway factual data may originate from:

```text
MANUAL_ENTRY
MEASURED
IMPORTED_DRAWING
CATALOG
BIM_IMPORT
MIGRATED_LEGACY
MODEL_DERIVED
```

Persist source reference/revision when available. Derived area/occupancy remains reproducible from canonical facts.

## 14. Four-discipline validation

### CCTV

Camera wall route -> corridor tray -> telecom-room conduit, all within one CableRun traversal chain.

### LAN

Many permanent-link CableRuns traverse one shared tray. Occupancy counts distinct physical cables.

### ACS

Several logical connections may allocate one multicore Cable, but tray occupancy still counts one cable.

### Fire

Carrier/pathway facts are persisted in ELV3. A legal fire-routing decision is deferred to ELV7; ELV3 may still detect malformed geometry or definition-declared technical incompatibility.

## 15. P0-R5/P0-R7 acceptance

- [x] PhysicalCarrier and PathwayContext are separate concepts.
- [x] shaft/riser are spatial contexts, not carrier types.
- [x] carrier facts remain discipline-neutral.
- [x] compartments are factual first-class structures.
- [x] occupancy derives from physical CableRun traversals.
- [x] multicore cable counts once.
- [x] vertical routing does not split CableRun identity.
- [x] ELV3 technical compatibility and ELV7 normative compliance are explicitly separated.

These remediation points are CLOSED subject to P0-R10.