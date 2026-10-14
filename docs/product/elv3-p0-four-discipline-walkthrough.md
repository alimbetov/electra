# Electra — ELV3 P0.7 Four-Discipline Walkthrough

Status: DESIGN VALIDATION / P0.7  
Branch: `feat/flutter-elv3-physical-routing-design`  
Depends on: P0.1–P0.6  
Implementation status: NOT STARTED

## 1. Purpose

P0.7 validates the frozen ELV3 model end-to-end against CCTV, LAN, ACS and Fire without introducing discipline-specific route entities.

Validation chain:

```text
EngineeringConnection
 -> CableAllocation
 -> Cable
 -> CableRun
 -> CableRoute
 -> RouteSegment
 -> PhysicalChannel
 -> compatibility result
```

## 2. CCTV scenario

### Input

```text
Camera ETH/PoE port
Switch ETH/PoE port
Cat6-like balanced copper CableDefinition
wall + tray + wall geometry
```

### Canonical realization

```text
Connection CCTV-CONN-001
  -> Allocation WHOLE_CABLE
  -> Cable CCTV-C-001
      -> Run camera-room
      -> Run corridor
      -> Run telecom-room
```

Each run owns exactly one route. Tray segments reference an existing PhysicalChannel; wall surface segments may have no channel.

### Expected physical checks

- route geometry valid;
- channel exists and belongs to compatible spatial context;
- cable outer diameter known for fill basis;
- bend-radius basis resolvable;
- environment/install facts resolvable;
- no double allocation of cable.

### Explicitly deferred

- PoE class/power budget;
- switch power budget;
- Ethernet channel certification;
- bandwidth/storage.

### Invalid cases

1. same cable already partially allocated -> WHOLE_CABLE rejected;
2. tray segment references missing channel -> route invalid/unresolved;
3. selected channel environment incompatible -> compatibility FORBIDDEN/WARNING according to profile;
4. route crossing opening without declared transition -> geometry invalid.

Result: PASS.

## 3. LAN scenario

### Input

```text
DataOutlet.REAR
PatchPanel.REAR
PatchPanel.REAR <-> PatchPanel.FRONT InternalConnectivity
balanced copper permanent-link cable
```

### Canonical realization

```text
EngineeringConnection outlet-rear -> patch-panel-rear
  -> CableAllocation WHOLE_CABLE
  -> Cable LAN-C-001
  -> N CableRuns
```

`InternalConnectivity` between patch panel rear/front remains ELV1 and does not create another physical permanent-link cable.

### Invalid cases

- creating a phantom second cable from rear to front: FORBIDDEN by model;
- directly binding Cable to patch-panel front port while connection ends at rear: invalid endpoint derivation;
- reusing the same physical cable for a second independent whole-cable LAN connection: overlap.

Result: PASS.

## 4. ACS multi-core scenario

### Input

One 8-conductor physical cable supports multiple logical functions:

```text
Reader bus
Door contact
REX
Lock control/power
```

### Canonical realization

```text
Cable ACS-C-001
Definition: 8 individually addressable conductors

Allocation A1: Reader        -> CONDUCTOR {1,2}
Allocation A2: Door contact  -> CONDUCTOR {3,4}
Allocation A3: REX           -> CONDUCTOR {5,6}
Allocation A4: Lock          -> CONDUCTOR {7,8}
```

All four logical connections share the same physical Cable and therefore the same run chain.

### Critical invariants proven

- `Connection != Cable`;
- N logical connections -> one physical Cable is valid;
- channel occupancy counts the cable once, not four allocations;
- deletion of one allocation does not delete the Cable while other allocations/runs remain;
- overlap must be transactionally prevented.

### Invalid cases

```text
A1 -> {1,2}
A2 -> {2,3}
```

=> `RESOURCE_OVERLAP`.

A WHOLE_CABLE allocation on ACS-C-001 while A1–A4 exist => forbidden.

Result: PASS and decisive validation of CableAllocation layer.

## 5. Fire scenario

### Input

```text
FACP / loop controller
addressable devices
ELV1 loop topology
fire-performance CableDefinition
route through rooms/corridor/riser
```

### Canonical realization

ELV1 owns loop graph and device order. ELV3 maps logical connections to physical cable resources and routing:

```text
ELV1 connections
 -> explicit allocation(s)
 -> Cable FIRE-C-001 / additional cables as required by topology
 -> CableRuns
 -> routes
 -> physical channels
```

A loop does not make `CableRun` own a fire network ID.

### Physical compatibility cases

- cable routed in accepted channel/environment -> COMPATIBLE;
- missing factual evidence -> UNRESOLVED;
- incompatible containment/fire/environment facts under selected profile -> FORBIDDEN;
- questionable but not prohibited condition -> WARNING.

### Explicitly deferred

- loop current;
- voltage drop;
- battery/autonomy;
- legal/jurisdiction compliance claim.

Result: PASS.

## 6. Cross-floor / riser scenario

A single cable may cross:

```text
room 101
 -> corridor
 -> riser/shaft
 -> floor 2 corridor
 -> room 205
```

Canonical representation:

```text
Cable C-001
  Run R1 room 101
  Run R2 corridor floor 1
  Run R3 riser context
  Run R4 corridor floor 2
  Run R5 room 205
```

Run endpoints are linked through explicit handoff/continuity records. Cable identity remains C-001 throughout.

No room-local fake PhysicalChannel is required for a shared riser.

## 7. Sequential multi-cable logical realization

The model permits one EngineeringConnection to have multiple ordered allocations only when explicitly required.

```text
Connection C1
  A1 sequence=1 -> Cable C-A
  A2 sequence=2 -> Cable C-B
```

This does not by itself prove physical splice semantics. The transition must be represented by an accepted termination/splice boundary or later explicit object. Silent concatenation based only on allocation sequence is forbidden.

## 8. Occupancy/fill proof

For channel occupancy:

```text
occupied cables = distinct Cable identities whose RouteSegments use the channel
```

Not:

```text
count(CableAllocation)
count(EngineeringConnection)
```

Therefore ACS-C-001 with four allocations contributes one cable cross-section to the channel.

## 9. Restart acceptance fixtures

Each discipline requires a close/reopen test proving exact reconstruction of:

- logical connection reference;
- allocation selector;
- Cable identity/label/definition edition;
- run ordering and route identity;
- route geometry;
- PhysicalChannel references and facts;
- compatibility inputs/staleness markers.

## 10. P0.7 acceptance gate

| Scenario | Result |
|---|---|
| CCTV whole-cable + mixed wall/tray routing | PASS |
| LAN permanent link + patch panel InternalConnectivity | PASS |
| ACS multi-core multi-connection allocation | PASS |
| Fire loop physical realization | PASS |
| cross-floor/riser continuity | PASS |
| distinct-cable channel occupancy | PASS |
| restart identity/provenance | CONTRACT DEFINED; implementation deferred |

No discipline requires a separate CCTV/LAN/ACS/Fire routing entity.
