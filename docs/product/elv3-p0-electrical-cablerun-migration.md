# Electra — ELV3 P0.6 Electrical CableRun Migration Contract

Status: DESIGN CONTRACT / P0.6  
Branch: `feat/flutter-elv3-physical-routing-design`  
Depends on: P0.1–P0.5  
Implementation status: NOT STARTED

## 1. Purpose

P0.6 defines how the current electrical-only routing model migrates to canonical ELV3 physical cable identity without breaking existing electrical projects, route geometry, floor handoffs or junction persistence.

The legacy coupling is:

```text
CableRun.circuitId
CableRuns.circuit_id -> ElectricalCircuits.id
JunctionConnections.circuit_id -> ElectricalCircuits.id
FloorRoutingRun.endpointSignature includes run.circuitId
RoomRoutingSnapshot.activeCircuitIds
```

The target model is:

```text
Electrical logical topology
        |
        v
CableAllocation
        |
        v
Cable
        |
        v
CableRun(cableId)
```

## 2. Migration principles

1. Existing route geometry is retained.
2. No fake electrical circuit is created for ELV disciplines.
3. `networkId` or generic `ownerType/ownerId` MUST NOT replace `circuitId`.
4. Existing electrical circuit semantics remain available through explicit logical-to-physical mapping.
5. Migration must be restart-safe, deterministic and idempotent.
6. No legacy run may be silently dropped because mapping is incomplete.

## 3. Target CableRun contract

```text
CableRun {
  id
  roomId
  name
  cableId        REQUIRED
  routeId
  reservePercent
  terminationAllowanceMm
}
```

Canonical `circuitId` is removed from the domain model after migration compatibility expires.

## 4. Deterministic backfill strategy

For every legacy `CableRun`:

### Case A — one electrical circuit run maps to one installed cable

Create or resolve a deterministic migrated `Cable` using stable legacy identity, for example:

```text
migration source = electrical circuit + physical run grouping evidence
```

Then:

```text
legacy CableRun.circuitId
  -> migrated CableAllocation(s) referencing logical electrical connection/circuit-derived topology
  -> migrated Cable
  -> CableRun.cableId
```

The exact electrical connection source must be resolved from the accepted electrical domain model during P3 implementation; P0 does not invent a synthetic `EngineeringConnection` if none exists.

### Case B — insufficient evidence to identify canonical cable identity

The row is migrated into an explicit review state, never guessed.

```text
MIGRATION_REVIEW_REQUIRED
```

The original `circuitId`, run identity and route geometry remain preserved as migration provenance until resolved.

## 5. Transitional schema strategy

Recommended migration sequence:

```text
schema N
  add CableDefinition/Cable/CableAllocation structures
  add nullable CableRuns.cable_id
  retain circuit_id temporarily

backfill
  map legacy runs deterministically
  populate cable_id
  record unresolved rows

validation gate
  all active migrated rows either RESOLVED or REVIEW_REQUIRED
  no silently null ownership

schema N+1
  application reads canonical cable_id
  legacy circuit_id read only for migration diagnostics

schema N+2
  remove circuit FK/column when exact migration closure is proven
```

A single destructive migration that drops `circuit_id` immediately is rejected.

## 6. Junction migration

Current junction persistence carries electrical `circuitId`, while the domain already has a broader `circuitOrNetworkId` concept.

Target semantics:

- routing continuity references run endpoints and `cableId` where cable continuity is asserted;
- pathway-only tray/conduit branch junctions assert channel geometry, not cable/electrical continuity;
- logical splice/termination requires an explicit object/contract, not same-circuit inference;
- legacy `JunctionConnections.circuit_id` becomes migration provenance and is later removed from canonical validation.

## 7. Floor endpoint signature migration

Current signature includes `run.circuitId`.

Target fingerprint:

```text
run.id
run.cableId
run.roomId
route.id
endpoint node id
surface anchor
world position
laying method
physical channel id
```

Migration must regenerate signatures and mark stale handoffs for explicit review when the reconstructed physical identity differs.

No handoff is automatically reconnected solely because two runs used the same legacy electrical circuit.

## 8. RoomRoutingSnapshot migration

Current snapshot dependency:

```text
activeCircuitIds
```

Target physical snapshot must instead expose the physical resources needed for route readiness, for example:

```text
activeCableIds
CableRun -> Cable existence
route validity
channel availability
```

Electrical circuit information may still be joined in electrical-specific application views, but it is not a prerequisite for generic physical route validity.

## 9. Compatibility adapter

During migration a narrow adapter MAY expose legacy electrical behavior:

```text
legacy circuit -> migrated allocation/cable -> cable runs
```

The adapter must be one-way compatibility infrastructure. New ELV3 writes MUST NOT populate physical ownership through legacy `circuitId`.

## 10. Rollback and failure safety

Migration must be resumable and idempotent:

- deterministic migrated IDs or mapping table prevent duplicate Cable creation;
- every migrated row retains source legacy identity;
- failure midway leaves old schema/read path intact until a gate switches canonical reads;
- unresolved mappings are explicit and queryable;
- rollback must not destroy pre-migration electrical routing evidence.

## 11. Required migration tests

1. single electrical run -> cable -> restart;
2. multiple room runs for same confirmed physical cable -> one Cable / N CableRuns;
3. junction continuity survives migration;
4. floor handoff signatures regenerate deterministically;
5. unresolved ambiguity becomes REVIEW_REQUIRED;
6. rerunning migration creates no duplicates;
7. ELV cable run requires no electrical circuit;
8. legacy electrical screens remain functionally equivalent through adapter during transition.

## 12. P0.6 acceptance gate

- [x] target ownership is `CableRun.cableId`;
- [x] destructive one-step migration rejected;
- [x] unresolved mappings are explicit, never guessed;
- [x] junction continuity is decoupled from circuit identity;
- [x] floor signatures become cable/geometry-based;
- [x] generic routing no longer depends on `activeCircuitIds`;
- [x] migration is restart-safe and idempotent;
- [x] existing electrical behavior has a compatibility path.
