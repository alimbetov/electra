# Electra — ELV3 P0.1/P0.2 Ownership and Cardinality Contract

Status: DESIGN CONTRACT / P0.1 + P0.2  
Branch: `feat/flutter-elv3-physical-routing-design`  
Input baseline: `docs/product/elv3-p0-physical-routing-design-inputs.md`  
Implementation status: NOT STARTED

## 1. Purpose

This document freezes the ownership and cardinality model for the ELV3 physical-routing chain before any schema migration or implementation work begins.

The contract preserves the accepted upstream boundaries:

```text
ELV1 = logical topology
ELV2 = canonical component/profile identity
ELV3 = physical cable resource + allocation + route/pathway
```

The canonical chain is:

```text
EngineeringConnection
        |
        v
CableAllocation
        |
        v
Cable
        |
        v
CableRun
        |
        v
CableRoute
        |
        v
RouteSegment
        |
        v
PhysicalChannel
```

This is not an aggregate ownership chain in the DDD sense. It is a responsibility/reference chain. Each entity has an independent lifecycle boundary defined below.

## 2. Core design decisions

### D1 — `EngineeringConnection != Cable`

`EngineeringConnection` remains the ELV1 logical relation between ports. It MUST NOT acquire physical cable identity, route geometry, conductor allocation or pathway fields.

A connection may exist before a physical cable is selected.

### D2 — `CableAllocation` is mandatory for wired realization

A wired logical connection is realized physically only through one or more explicit `CableAllocation` records.

`CableAllocation` answers:

```text
which EngineeringConnection
uses which Cable
using which physical resource(s)
for which logical role/order
```

No direct `EngineeringConnection.cableId` shortcut is permitted.

### D3 — `Cable` is one installed physical cable identity

`Cable` represents one installed physical cable resource with stable project identity and exact cable-definition provenance.

It owns:

- project-scoped installation identity;
- cable label / schedule identity;
- exact `CableDefinition` binding/provenance;
- lifecycle state;
- physical resource namespace used by allocations.

It does not own room-local route geometry.

### D4 — `CableRun` is a routed section of exactly one Cable

`CableRun` represents one contiguous routed section of one physical cable within one route ownership context.

Canonical rule:

```text
Cable 1 -> N CableRun
CableRun N -> 1 Cable
```

A cable crossing rooms/floors may therefore be represented by multiple runs while retaining one physical cable identity.

### D5 — `CableRun` has exactly one `CableRoute`

Canonical rule:

```text
CableRun 1 -> 1 CableRoute
CableRoute 1 -> 1 CableRun
```

For P0/P1-P3, `CableRoute` is not a reusable route template shared by multiple runs. This deliberately preserves simple room ownership, restart semantics and the current mature route validator.

If future optimization needs reusable pathway geometry, it must introduce a separate pathway/template concept rather than silently changing `CableRoute` cardinality.

### D6 — `RouteSegment` may reference zero or one `PhysicalChannel`

Canonical rule:

```text
RouteSegment 0..1 -> PhysicalChannel
PhysicalChannel 0..N <- RouteSegment
```

A segment can be free/surface/chase routing with no channel, or can be carried by one explicit channel/compartment reference.

The same physical tray/conduit/trunking may carry many route segments and many cables.

### D7 — physical continuity is independent of circuit/network identity

`CableRun` physical identity MUST NOT depend on `ElectricalCircuit`, network ID, discipline or logical topology ID.

`CableRun.circuitId` is therefore a legacy electrical coupling to be removed/replaced in ELV3-P3.

Physical handoff/junction continuity is identified through cable/run/endpoint geometry facts, not through `circuitId`.

### D8 — endpoint ports belong to ELV1, not `Cable`

A `Cable` does not directly own endpoint port IDs.

Endpoint semantics are derived through:

```text
Cable
 <- CableAllocation
 -> EngineeringConnection
 -> endpoint ports
```

This avoids ambiguity when one multi-core cable carries multiple independent connections.

## 3. P0.1 ownership matrix

| Entity | Canonical owner/scope | Owns | References | MUST NOT own |
|---|---|---|---|---|
| `EngineeringConnection` | project / ELV1 topology | logical A↔B relation, connection semantics | endpoint ports | cable identity, route geometry, pathway facts |
| `CableAllocation` | project / ELV3 physical realization | allocation identity, resource selector, sequence/role | one connection, one cable | route geometry, cable definition, pathway dimensions |
| `Cable` | project / physical installation | installed cable identity, label, exact definition provenance, lifecycle | one `CableDefinition` | room geometry, electrical circuit ownership |
| `CableRun` | routing context, normally room-local | section identity, ordering/continuity metadata, reserve/allowance facts where section-scoped | one cable, one route | circuit/network identity as owner |
| `CableRoute` | room-local routing geometry | ordered nodes/segments | room geometry | logical connection semantics, cable resources |
| `RouteSegment` | route-owned | local geometric segment, laying method | surface patch, optional channel | cable allocation semantics |
| `PhysicalChannel` | spatial/project asset, located in room/floor/riser context | pathway identity and factual dimensions/environment | spatial host/context | normative limits, cable ownership, logical network |

### 3.1 Aggregate/lifecycle interpretation

The implementation may persist these records in separate tables, but lifecycle rules are:

```text
EngineeringConnection deletion
  -> blocked while active CableAllocation exists

Cable deletion
  -> blocked while CableAllocation or CableRun exists

CableRun deletion
  -> may delete its owned CableRoute atomically

CableRoute deletion
  -> not independently allowed while owned by CableRun

PhysicalChannel deletion
  -> blocked while active RouteSegment references it
```

Soft/archive lifecycle may be used later, but referential meaning must remain equivalent.

## 4. P0.2 cardinality matrix

| Relation | Cardinality | Decision |
|---|---:|---|
| `EngineeringConnection -> CableAllocation` | `1 -> 0..N` | a logical connection may be unallocated, use one cable, or be realized through sequential cable sections/splice transitions |
| `CableAllocation -> EngineeringConnection` | `N -> 1` | every allocation belongs to exactly one logical connection |
| `Cable -> CableAllocation` | `1 -> 0..N` | one cable may carry many logical connections via distinct resource allocations |
| `CableAllocation -> Cable` | `N -> 1` | every allocation consumes resources from exactly one physical cable |
| `Cable -> CableRun` | `1 -> 0..N` | one cable may have multiple routed sections across rooms/floors |
| `CableRun -> Cable` | `N -> 1` | every run section belongs to one physical cable |
| `CableRun -> CableRoute` | `1 -> 1` | every run has one geometry object |
| `CableRoute -> CableRun` | `1 -> 1` | route is owned by exactly one run in ELV3 |
| `CableRoute -> RouteSegment` | `1 -> 1..N` | route is an ordered non-branching sequence |
| `RouteSegment -> PhysicalChannel` | `N -> 0..1` | segment may be uncontained or carried by one explicit channel/compartment |
| `PhysicalChannel -> RouteSegment` | `1 -> 0..N` | pathway can carry many routed segments/cables |
| `Cable -> endpoint ports` | indirect only | endpoint relation is derived through allocation -> connection |
| `CableRun -> floor/room handoff` | `1 -> 0..N` references | handoff connects run endpoints; it does not create cable identity or logical splice |

## 5. Multiple cables for one logical connection

P0 permits:

```text
EngineeringConnection C1
  -> Allocation A1 -> Cable CA-01
  -> Allocation A2 -> Cable CA-02
```

but only when physical continuity semantics explicitly require it, for example:

- a declared splice/transition;
- a media converter boundary represented by distinct ELV1 ports/connections where applicable;
- an installation-specific segmented physical realization.

Allocations therefore require deterministic ordering/role metadata when more than one cable participates in one logical connection.

The preferred default remains:

```text
1 EngineeringConnection
  -> 1 CableAllocation
  -> 1 Cable
```

Multi-allocation is supported by the model but must never be inferred silently.

## 6. Multiple logical connections in one cable

P0 explicitly permits:

```text
Cable CA-ACS-01
  <- Allocation(reader bus: conductors 1-2)
  <- Allocation(door contact: conductors 3-4)
  <- Allocation(REX: conductors 5-6)
  <- Allocation(lock: conductors 7-8)
```

Therefore:

```text
N EngineeringConnections -> N CableAllocations -> 1 Cable
```

This is the decisive reason `Connection == Cable` is forbidden.

The resource-overlap rules are deferred to P0.3/P2, but the cardinality is frozen now.

## 7. Cable and CableRun identity

### 7.1 `Cable`

A `Cable` is the schedule/install identity visible to engineering deliverables later.

Example:

```text
Cable C-001
Definition = exact Cat6 U/UTP profile edition X
Label = C-001
```

### 7.2 `CableRun`

A `CableRun` is a spatial section of `C-001`:

```text
Cable C-001
  |
  +-- Run R1 / room 101
  +-- Run R2 / corridor
  +-- Run R3 / riser
  +-- Run R4 / room 305
```

All runs above retain `cableId = C-001`.

A floor/room handoff connects adjacent run endpoints of the same physical cable unless an explicit physical junction/splice says otherwise.

## 8. Junction and handoff semantics

### 8.1 Routing junction

A routing junction describes declared physical continuity/branching at route endpoints. It MUST NOT infer logical topology from geometric crossing.

For ELV3-P3 the validator must stop using `run.circuitId` as the continuity identity.

Candidate physical identity rule:

```text
non-branch splice/transition:
  connected runs must either
    a) belong to the same Cable, or
    b) be connected by an explicit splice/termination object introduced by a later contract
```

Pathway-only branch junctions such as tray/conduit branches may connect route/channel geometry without asserting cable splice or electrical continuity.

### 8.2 Floor handoff

`FloorRoutingHandoff` remains a declared physical continuation between run endpoints. It is not an electrical splice and not a measured segment.

The endpoint fingerprint must become circuit-independent. P0 target inputs are:

```text
run.id
run.cableId
run.roomId
route.id
endpoint node identity + anchor + world position
laying method
physical channel reference
```

`run.circuitId` must disappear from the fingerprint after migration.

## 9. Reserve and termination allowance ownership

Current `CableRun` owns:

```text
reservePercent
terminationAllowanceMm
```

P0 freezes the following rule for migration safety:

- route-section reserve remains `CableRun`-scoped;
- run endpoint allowance remains `CableRun`-scoped during ELV3;
- whole-cable total length is derived as the sum of valid run lengths;
- a future explicit service-loop object may refine this, but ELV3 must not duplicate allowances on `Cable` and `CableRun` simultaneously.

Therefore no `Cable.totalLength` persisted source-of-truth field is introduced.

## 10. Four-discipline walkthrough

### 10.1 CCTV — PASS

```text
Camera ETH/PoE port
  -> EngineeringConnection
  -> CableAllocation(WHOLE_CABLE)
  -> Cable CCTV-001
  -> Run room-camera
  -> Run corridor
  -> Run telecom-room
  -> Switch ETH/PoE port
```

Result:

- one logical connection can use one whole physical cable;
- the cable can cross several room-local runs;
- PoE budget is not evaluated in ELV3;
- route/pathway geometry remains common infrastructure.

### 10.2 LAN — PASS

```text
Outlet.REAR
  -> EngineeringConnection
  -> CableAllocation(WHOLE_CABLE)
  -> Cable LAN-001
  -> N CableRuns
  -> PatchPanel.REAR

PatchPanel.REAR
  <-> InternalConnectivity
PatchPanel.FRONT
```

Result:

- passive front/rear internal connectivity does not create a second physical cable;
- permanent-link cable identity remains singular;
- patch cord modelling, if later needed, is a separate cable/connection scope and is not inferred here.

### 10.3 ACS multi-core — PASS

```text
Cable ACS-001, 8 cores

Reader connection       -> Allocation cores 1-2
Door-contact connection -> Allocation cores 3-4
REX connection          -> Allocation cores 5-6
Lock connection         -> Allocation cores 7-8
```

All allocations may share the same `Cable` and therefore the same set of `CableRun` sections.

This validates the required N-connections-to-one-cable case.

### 10.4 Fire — PASS

```text
ELV1 loop topology
  -> explicit CableAllocation(s)
  -> fire-rated Cable identity
  -> CableRun(s)
  -> Route(s)
  -> PhysicalChannel(s)
```

An incompatible channel produces a physical compatibility finding later; it does not mutate the logical loop topology.

The model supports source/return loop semantics without making `CableRun` own the fire-loop/network identity.

## 11. Invalid models rejected by P0.1/P0.2

The following designs are rejected:

```text
EngineeringConnection.cableId
CableRun.circuitId as canonical owner
CableRun.networkId as a renamed replacement for circuitId
CableRoute shared by arbitrary unrelated CableRuns
PhysicalChannel owning connected cables
Connection inferred from crossing routes
Cable directly owning one fixed pair of endpoint ports
per-discipline CCTV/LAN/ACS/Fire route entities
```

A generic `ownerType/ownerId` polymorphic pair on `CableRun` is also rejected as the canonical model because it only hides the electrical coupling behind a string discriminator and weakens referential integrity.

## 12. Consequences for existing implementation

Current code has three confirmed electrical assumptions that P3 must remove without rewriting the geometry kernel:

1. `CableRun.circuitId` is required by the domain model.
2. `RoutingJunctionValidator` validates active electrical circuit membership and same-circuit junctions.
3. `FloorRoutingRun.endpointSignature()` fingerprints `run.circuitId`.

Target migration direction:

```text
CableRun
  circuitId              REMOVE as canonical physical owner
  cableId                ADD, required after migration
  routeId                RETAIN
  roomId                 RETAIN
  reservePercent         RETAIN
  terminationAllowanceMm RETAIN
```

Electrical behavior must be preserved through explicit mapping from electrical circuit/logical connection(s) to cable allocations, not through fake or overloaded cable-run ownership.

## 13. P0.1/P0.2 acceptance gate

P0.1/P0.2 are considered CLOSED when all statements below are accepted:

- [x] `EngineeringConnection` remains purely logical.
- [x] `CableAllocation` is the only connection-to-cable realization relation.
- [x] one connection may have `0..N` allocations.
- [x] one cable may have `0..N` allocations.
- [x] one cable may carry multiple independent logical connections.
- [x] one cable may have multiple routed sections.
- [x] every `CableRun` belongs to exactly one `Cable`.
- [x] every `CableRun` owns exactly one `CableRoute` for ELV3.
- [x] each route segment references at most one physical channel/compartment.
- [x] a physical channel may carry many route segments/cables.
- [x] cable endpoint ports are derived through allocation -> connection.
- [x] physical continuity is independent from electrical circuit/network identity.
- [x] CCTV, LAN, ACS and Fire all fit without discipline-specific route entities.
- [x] current route geometry kernel remains reusable.

## 14. Remaining P0 work

With P0.1 and P0.2 frozen, the next design steps are:

```text
P0.3  Cable resource model
      WHOLE_CABLE / PAIR / CONDUCTOR / FIBER / CORE_GROUP
      selectors, overlap rules, allocation ordering

P0.4  PhysicalChannel factual model
      dimensions, compartments, environment, riser/shaft ownership

P0.5  Lifecycle / deletion / audit / provenance

P0.6  migration from electrical CableRun

P0.7  detailed CCTV / LAN / ACS / Fire fixtures

P0.8  persistence proposal

P0.9  hard design review
```

No Drift schema change is authorized by this document.
