# Electra — ELV3 P0.9 Hard Design Audit

Status: HARD DESIGN AUDIT / P0.9  
Branch: `feat/flutter-elv3-physical-routing-design`  
Scope: P0.1–P0.8 design closure before P1 implementation

## 1. Audit objective

P0.9 attempts to break the proposed ELV3 architecture before persistence/domain implementation begins.

Audit dimensions:

- ownership/cardinality correctness;
- physical-vs-logical separation;
- resource-allocation safety;
- migration safety;
- restart/provenance integrity;
- four-discipline universality;
- spatial/pathway modelling;
- transaction boundaries;
- scope leakage into ELV4/ELV5/ELV7/ELV8;
- compatibility with current routing kernel.

## 2. Design set audited

```text
P0.1/P0.2  ownership/cardinality
P0.3       cable resource model
P0.4       PhysicalChannel factual model
P0.5       lifecycle/deletion/audit/provenance
P0.6       electrical CableRun migration
P0.7       CCTV/LAN/ACS/Fire walkthrough
P0.8       persistence/schema proposal
```

## 3. Findings summary

| ID | Finding | Severity | Resolution |
|---|---|---:|---|
| A01 | `Connection == Cable` shortcut would break ACS | BLOCKER | rejected; mandatory CableAllocation |
| A02 | `CableRun.circuitId` is electrical ownership leakage | BLOCKER | target `CableRun.cableId`; staged migration |
| A03 | renaming to `networkId` would preserve same flaw | HIGH | explicitly rejected |
| A04 | free-form selector strings permit ambiguity | HIGH | typed selectors + normalized atomic resources |
| A05 | WHOLE_CABLE mixed with partial allocations | BLOCKER | mutual exclusion rule |
| A06 | overlap check only in UI/domain is race-prone | BLOCKER | repository transaction + DB uniqueness where feasible |
| A07 | CORE_GROUP could become escape hatch | HIGH | only exact CableDefinition-defined groups |
| A08 | channel fill counted by allocation overcounts ACS | BLOCKER | distinct Cable occupancy |
| A09 | mandatory `roomId` breaks risers/shafts | HIGH | spatial-context model |
| A10 | normative limits stored on channel become mutable truth | HIGH | facts/rules separated |
| A11 | immediate circuit column drop risks data loss | BLOCKER | staged dual-schema migration |
| A12 | ambiguous legacy mapping could be guessed | BLOCKER | REVIEW_REQUIRED |
| A13 | route geometry rewrite would destabilize mature kernel | HIGH | reuse current CableRoute kernel |
| A14 | CableRoute shared by arbitrary runs complicates ownership | MEDIUM | 1 Run <-> 1 Route for ELV3 |
| A15 | cable endpoint ports stored directly fail multi-connection cable | HIGH | derive through allocation -> connection |
| A16 | floor endpoint fingerprint tied to circuit | HIGH | cable/geometry fingerprint |
| A17 | junction continuity inferred from same circuit is invalid generically | HIGH | physical continuity separated from logical identity |
| A18 | cached compatibility could become stale source-of-truth | MEDIUM | cache/evidence only + input fingerprint |
| A19 | cascade deletion could erase engineering evidence | HIGH | RESTRICT by default |
| A20 | discipline-specific route entities would fragment kernel | HIGH | single Physical Routing model |

## 4. Adversarial model checks

### 4.1 One cable, multiple logical connections

ACS proves this is required.

Result: supported through multiple non-overlapping allocations to one Cable.

### 4.2 One logical connection, multiple cables

Model supports ordered allocations, but P0 correctly refuses to infer splice/continuity merely from sequence.

Result: supported cautiously; explicit transition/termination semantics required.

### 4.3 Cable through several rooms/floors

One Cable -> N CableRuns, each owning one room/spatial route.

Result: supported.

### 4.4 Shared tray carrying many cables

Many RouteSegments/Cables may reference one channel. Occupancy is derived from distinct cables.

Result: supported.

### 4.5 Riser shared across floors

PhysicalChannel is not forced into a single room.

Result: supported.

### 4.6 Wireless logical connection

A logical EngineeringConnection may have zero CableAllocation.

Result: model does not force fake cable.

### 4.7 Catalog edition update

Installed Cable remains bound to exact CableDefinition edition.

Result: no silent latest-edition adoption.

## 5. Current-code impact audit

The current routing kernel remains architecturally reusable because it already separates geometry into Route/Node/Segment and channel references.

Required implementation changes are concentrated around ownership and validation:

```text
CableRun.circuitId -> cableId
RoomRoutingSnapshot.activeCircuitIds -> physical cable readiness
RoutingJunctionValidator same-circuit logic -> physical continuity rules
FloorRoutingRun.endpointSignature circuit component -> cableId
Drift CableRuns FK -> staged cable FK migration
JunctionConnections circuit persistence -> staged provenance/removal
```

This is a controlled refactor, not a routing-engine rewrite.

## 6. Scope leakage audit

The design correctly keeps the following outside ELV3:

```text
PoE power budget
PSU/UPS/battery sizing
DC voltage drop
fiber optical loss
Ethernet certification/performance
CCTV bandwidth/storage
ACS controller power calculations
fire loop current/autonomy
jurisdiction/legal compliance claims
manufacturer SKU selection/BOM optimization
```

No BLOCKER scope leakage remains in P0.

## 7. Required implementation guards before P1-P4 closure

These are not P0 design blockers, but are mandatory delivery gates:

1. exact immutable CableDefinition edition identity;
2. normalized selector validation tests;
3. atomic double-allocation test with competing writes;
4. migration rerun/idempotency test;
5. unresolved migration review-state test;
6. electrical legacy regression suite preserved;
7. cross-project FK/reference guards;
8. restart tests for all four disciplines;
9. channel occupancy test proving ACS cable counted once;
10. endpoint fingerprint stability/staleness tests;
11. deletion restriction tests;
12. no fake circuit/network IDs in ELV fixtures.

## 8. Deferred design questions, intentionally not blockers

The following may be refined in later ELV3 phases without violating P0 contracts:

- explicit splice/termination entity;
- reusable pathway geometry/template abstraction;
- richer shaft/riser graph;
- manufacturer-specific channel/catalog mapping;
- persisted compatibility evidence tables;
- explicit service-loop objects;
- patch cords as later physical-cable scope;
- bundled cable/assembly specialization.

None requires changing the core chain:

```text
Connection -> Allocation -> Cable -> Run -> Route -> Channel
```

## 9. P0 exit decision

### Design verdict

```text
P0.1 ownership/cardinality           PASS
P0.3 cable resources                 PASS
P0.4 PhysicalChannel facts           PASS
P0.5 lifecycle/audit/provenance      PASS
P0.6 migration strategy              PASS
P0.7 four-discipline walkthrough     PASS
P0.8 persistence proposal            PASS
P0.9 adversarial audit               PASS
```

No unresolved design BLOCKER remains for starting ELV3-P1.

### Important qualification

P0 closure authorizes implementation of the frozen model; it does not claim runtime correctness yet. P1–P4 must independently pass tests, restart, migration and exact-SHA CI gates.

## 10. ELV3 implementation sequence after P0

```text
ELV3-P1
  CableDefinition + Cable identity
      ↓
ELV3-P2
  CableAllocation + selector safety
      ↓
ELV3-P3
  CableRun ownership migration
      ↓
ELV3-P4
  PhysicalChannel facts/compartments
      ↓
ELV3-P5
  compatibility engine
      ↓
ELV3-P6
  common physical calculations
      ↓
ELV3-P7
  editor/application integration
      ↓
ELV3-P8
  four-discipline persistence/restart acceptance
      ↓
ELV3-P9
  exact-SHA hard closure
```

P0 design stage is CLOSED subject to branch CI/document review.
