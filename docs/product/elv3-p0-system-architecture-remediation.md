# Electra — ELV3 P0 System Architecture Remediation

Status: AUTHORITATIVE REMEDIATION CONTRACT / CLOSED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Triggered by: `docs/audit/elv3-system-architecture-consistency-audit.md`  
Final audit: `docs/audit/elv3-p0-hard-design-audit.md`  
Implementation status: P1 AUTHORIZED AGAINST REMEDIATED CONTRACTS

## 1. Decision

The first ELV3 P0 closure was withdrawn after a project-wide architecture audit found conflicts with the accepted common engineering model. P0.1–P0.9 were then rewritten/synchronized through P0-R1–P0-R10.

This document remains authoritative wherever historical first-closure text conflicts with the remediated contracts.

Final gate:

```text
ELV3 direction                    ACCEPTED
ELV3-P0 remediation              CLOSED
project-wide architecture fit    PASS
ELV3-P1                          AUTHORIZED
runtime correctness              NOT YET CLAIMED
```

## 2. Corrected canonical layering

```text
ELV1 — logical topology

EngineeringSystem
  -> TopologyGroup
  -> EngineeringConnection
  -> Port

ELV2 — canonical reference identity

ReferenceSnapshot / project binding
  -> exact CableDefinition/Profile edition

ELV3 — physical realization

EngineeringConnection
  -> CableAllocation
      -> CableResourceSelection
      -> CableTerminationMapping[]
  -> Cable
  -> CableRun
  -> ordered CableTraversal[]
  -> reusable Route / geometry infrastructure
  -> optional PhysicalCarrier
  -> PathwayContext
```

## 3. Final remediation decisions

### R1 — Cable / CableRun cardinality

```text
Cable 1 -> 0..1 active CableRun per design revision
```

Room/floor/riser boundaries do not create additional CableRun identities.

### R2 — traversal versus private route

`CableRun` owns ordered path usage (`CableTraversal[]`), not one private final-domain Route. Route/geometry infrastructure is reusable by many CableRuns.

Current `CableRoute` implementation remains a migration/evolution asset.

### R3 — CableDefinition governance

`CableDefinition` consumes ELV2 reference snapshot/project-binding/version governance. ELV3 does not create a parallel catalog lifecycle.

### R4 — multi-cable continuity

One continuous wired connection normally uses one Cable. Multiple cables require explicit splice/termination/connector/patch transition evidence. Ordering metadata alone is insufficient.

### R5 — carrier/pathway layering

```text
PhysicalCarrier = tray / conduit / trunking / duct / etc.
PathwayContext  = room / ceiling void / riser / shaft / shared context
```

Shaft/riser is not a carrier type.

### R6 — resource and termination model

Typed resource definitions/selections are mandatory. The model supports whole cable, pairs, conductors, fibers, groups and definition-owned shield/drain/earth resources where applicable.

Physical termination mapping is first-class and references exact project endpoints/terminals.

### R7 — ELV3 versus ELV7

ELV3 owns technical physical compatibility and factual evidence. ELV7 owns jurisdiction/normative rule packs and formal compliance claims.

### R8 — electrical coexistence

Legacy electrical `CableRun.circuitId` routing remains valid through compatibility/adoption semantics. ELV3 does not auto-create physical Cable identities from electrical circuits.

Explicit `AdoptLegacyElectricalRoute` requires sufficient physical evidence and is auditable/idempotent.

### R9 — lifecycle/revision/commands/persistence

The design now requires:

- design-revision-aware CableRun identity;
- optimistic revision guards;
- atomic resource allocation;
- command-level transactions;
- idempotent retry;
- logical undo/redo;
- affected-subgraph dependency invalidation;
- deterministic restart reconstruction.

Target persistence concepts:

```text
Cables
CableAllocations
CableAllocationResources
CableTerminationMappings
CableRuns
CableRunTraversals
PathwayContexts
PhysicalCarriers
PhysicalCarrierCompartments
LegacyRouteAdoptions
```

plus reused/evolved route geometry and existing ELV2 reference-binding tables.

### R10 — scenario and system audit

CCTV, LAN, ACS, Fire and fiber scenarios all pass the corrected common model. The final architecture audit reports no unresolved P0 design blocker.

## 4. Invalid first-closure assumptions superseded

The following are explicitly obsolete:

```text
Cable 1 -> N room/floor CableRuns
CableRun 1 <-> 1 private CableRoute as final architecture
independent ELV3 CableDefinitions catalog/version lifecycle
multi-cable continuity inferred from sequence alone
SHAFT/RISER as PhysicalCarrier kinds
automatic circuitId -> cableId backfill
ELV3 formal normative compliance without ELV7
```

## 5. P1 entry constraints

P1 may implement Cable project identity and exact definition binding only if it preserves:

1. ELV2 reference governance reuse;
2. no routing/cardinality implementation leakage from superseded P0 contracts;
3. project isolation and exact provenance;
4. design-revision compatibility;
5. future resource/termination/traversal contracts;
6. restart determinism;
7. exact-SHA CI gates.

P1 must not prematurely implement P2–P4 persistence just to simplify Cable identity.

## 6. Final P0 status

```text
P0-R1   CLOSED / PASS
P0-R2   CLOSED / PASS
P0-R3   CLOSED / PASS
P0-R4   CLOSED / PASS
P0-R5   CLOSED / PASS
P0-R6   CLOSED / PASS
P0-R7   CLOSED / PASS
P0-R8   CLOSED / PASS
P0-R9   CLOSED / PASS
P0-R10  CLOSED / PASS
```

ELV3-P0 is now closed on the remediated architecture. P1 planning/implementation may begin.