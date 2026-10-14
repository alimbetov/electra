# Electra — ELV3 P0.1/P0.2 Ownership and Cardinality Contract

Status: REMEDIATED DESIGN CONTRACT / P0-R1 + P0-R2  
Branch: `feat/flutter-elv3-physical-routing-design`  
Authoritative parent: `docs/product/elv3-p0-system-architecture-remediation.md`  
Implementation status: HOLD UNTIL P0-R10

## 1. Purpose

This document defines the corrected ownership and cardinality model for ELV3 after the system-architecture consistency audit.

The first P0 closure is superseded where it stated:

```text
Cable 1 -> N CableRun
CableRun 1 <-> 1 CableRoute
room/floor boundaries split one physical cable into several CableRuns
```

Those statements are no longer canonical.

## 2. Architectural layers

```text
ELV1 — logical topology
EngineeringSystem -> TopologyGroup -> EngineeringConnection -> Port

ELV2 — canonical reference identity
ReferenceSnapshot/project binding -> exact CableDefinition/Profile edition

ELV3 — physical realization
EngineeringConnection
  -> CableAllocation
  -> Cable
  -> CableRun
  -> ordered CableTraversal[]
  -> reusable Route/geometry infrastructure
  -> PhysicalCarrier
  -> PathwayContext
```

This is a navigation/responsibility chain, not one aggregate ownership tree.

## 3. Core ownership decisions

### D1 — `EngineeringConnection != Cable`

`EngineeringConnection` owns logical adjacency and connection semantics only. It never owns cable geometry or cable resources.

### D2 — `CableAllocation` is the physical realization relation

A wired connection is realized through explicit allocation to physical cable resources.

```text
EngineeringConnection 1 -> 0..N CableAllocation
Cable 1 -> 0..N CableAllocation
```

The normal continuous case is one connection -> one allocation -> one cable.

Multiple cable allocations for one connection are valid only when an explicit physical transition/termination contract proves continuity. Sequence numbers alone are not proof of continuity.

### D3 — `Cable` is one installed physical cable identity

`Cable` is project-owned and retains exact ELV2 reference-definition provenance. It is independent from room/floor segmentation and from electrical circuit/network identity.

### D4 — one active `CableRun` per Cable per design revision

Canonical rule:

```text
Cable 1 -> 0..1 active CableRun per design revision
CableRun N -> 1 Cable
```

A cable crossing rooms, corridors, risers and floors remains one Cable and one active CableRun for that revision.

Historical/superseded runs may coexist across design revisions, but only one is active for one Cable in one revision context.

### D5 — `CableRun` is path usage, not a room-local route copy

`CableRun` owns the installed physical realization of one Cable and an ordered sequence of traversals:

```text
CableRun
  -> CableTraversal[1..N]
```

Each traversal references reusable routing/geometry infrastructure and direction/order.

### D6 — Route infrastructure is reusable

Canonical target:

```text
Route / RouteSegment 1 <- 0..N CableTraversal
```

Many cable runs may traverse the same tray/conduit/route segment. Route identity is not owned exclusively by one CableRun.

The current `CableRoute` implementation is retained as migration/implementation evidence but is not the final domain cardinality contract.

### D7 — physical carrier and pathway context are distinct

A traversal may use a `PhysicalCarrier` such as tray/conduit/trunking/duct. The carrier is located inside a `PathwayContext` such as room-local, ceiling void, riser or shaft.

### D8 — physical continuity is independent from circuit/network identity

`ElectricalCircuit`, network ID, discipline ID and topology group ID are not physical CableRun ownership keys.

## 4. Corrected cardinality matrix

| Relation | Cardinality | Rule |
|---|---:|---|
| EngineeringConnection -> CableAllocation | 1 -> 0..N | zero for wireless/unrealized; N only with explicit physical transition semantics |
| CableAllocation -> EngineeringConnection | N -> 1 | exactly one logical connection per allocation |
| Cable -> CableAllocation | 1 -> 0..N | distinct non-overlapping resources may serve multiple connections |
| CableAllocation -> Cable | N -> 1 | exactly one physical cable per allocation row |
| Cable -> active CableRun | 1 -> 0..1 per design revision | one installed route realization per cable/revision |
| CableRun -> Cable | N -> 1 | each run realizes exactly one cable |
| CableRun -> CableTraversal | 1 -> 1..N | ordered continuous path usage |
| CableTraversal -> Route/RouteSegment | N -> 1 target per traversal unit | route infrastructure may be reused by many cables |
| Route/RouteSegment -> CableTraversal | 1 -> 0..N | shared infrastructure |
| CableTraversal -> PhysicalCarrier | N -> 0..1 | free/surface path may have no carrier |
| PhysicalCarrier -> CableTraversal | 1 -> 0..N | occupancy derived from traversals |
| PhysicalCarrier -> PathwayContext | N -> 1 | every carrier has one authoritative spatial context |
| Cable -> endpoint ports | indirect | via Allocation -> Connection -> Port |

## 5. CableRun example

Correct:

```text
Cable C-001
  -> CableRun CR-001
      -> T1 room 101 wall route
      -> T2 corridor tray T-01
      -> T3 riser tray T-02 in shaft S-01
      -> T4 floor 3 corridor tray T-03
      -> T5 room 305 wall route
```

Incorrect:

```text
Cable C-001
  -> CableRun room 101
  -> CableRun corridor
  -> CableRun riser
  -> CableRun room 305
```

Spatial boundaries do not redefine physical-cable-run identity.

## 6. Multiple cables for one connection

Default:

```text
Connection -> one CableAllocation -> one Cable
```

Multiple cables require an explicit physical transition boundary, for example:

- splice;
- terminal block;
- connector/patch boundary;
- junction with termination semantics;
- media converter represented by explicit ports/connections.

Until such transition is modeled, multiple active cable allocations for one continuous wired connection are invalid.

## 7. Lifecycle consequences

- deleting Connection is blocked while active allocations exist;
- deleting Cable is blocked while active allocation/run exists;
- rerouting creates/replaces CableRun realization, not Cable identity;
- route infrastructure deletion is blocked while active traversals reference it;
- historical CableRuns remain addressable when required by design-revision evidence.

## 8. Current implementation compatibility

Current code remains useful but is legacy-shaped:

```text
CableRun.circuitId
CableRun.routeId
CableRoute room-local ordered geometry
FloorRoutingHandoff between run endpoints
```

ELV3 implementation must evolve this without pretending current 1:1 `CableRun -> CableRoute` storage is the final domain architecture.

## 9. P0-R1/P0-R2 acceptance

- [x] Connection remains logical.
- [x] CableAllocation remains mandatory for wired realization.
- [x] one Cable has at most one active CableRun per design revision.
- [x] room/floor/riser segmentation no longer creates CableRun identity.
- [x] CableRun uses ordered traversal semantics.
- [x] Route infrastructure is reusable by multiple cable runs.
- [x] physical continuity is circuit/network independent.
- [x] multi-cable realization requires explicit transition semantics.
- [x] current CableRoute kernel is retained as migration evidence, not frozen as final aggregate cardinality.

P0-R1 and P0-R2 are CLOSED subject to the final P0-R10 cross-document audit.