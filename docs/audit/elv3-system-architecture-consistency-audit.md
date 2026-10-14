# Electra — ELV3 System Architecture Consistency Audit

Status: SYSTEM ARCHITECTURE REVIEW / P0 REOPEN REQUIRED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Reviewed head: `c7c794cbfe77213d340f363c879c5b1b23aaf5d0`  
Scope: consistency of ELV3 P0 contracts with accepted ELV1/ELV2 architecture, existing electrical/routing kernel and ELV4–ELV8 roadmap

## 1. Executive decision

The ELV3 direction is architecturally valid, but P0 MUST NOT be treated as closed yet.

The following decisions are sound and should remain:

- `EngineeringConnection != Cable`;
- explicit `CableAllocation` between logical topology and physical medium;
- a physical cable may carry several non-overlapping logical allocations;
- route geometry must not infer logical connectivity;
- the existing surface geometry/route validator should be reused rather than rewritten;
- channel/pathway facts must be separated from normative rule thresholds;
- physical occupancy must count physical cables, not connection/allocation count;
- ELV3 must remain discipline-neutral at infrastructure level;
- no fake electrical circuit/network IDs for CCTV/LAN/ACS/Fire;
- exact reference/provenance and restart determinism remain mandatory.

However several P0 decisions conflict with foundational documents or create future incompatibility. Those conflicts must be resolved before ELV3-P1 implementation.

System-architecture verdict:

```text
ELV3 direction                    PASS
P0.1–P0.9 internal consistency   PARTIAL
project-wide architecture fit     FAIL / REOPEN REQUIRED
P1 implementation authorization   HOLD
```

## 2. Sources of architectural truth used by this audit

The audit compares P0 against:

- `docs/architecture/elv-domain-model-and-invariants.md`;
- `docs/product/elv-canonical-discipline-model.md`;
- `docs/product/elv-domain-scenario-validation.md`;
- `docs/product/elv-reference-data-catalogs.md`;
- `docs/product/elv-delivery-plan.md`;
- `docs/product/elv12-pre-elv3-hardening-specification.md`;
- current `engineering_core` cable-routing/junction/floor graph implementation;
- current Drift routing persistence.

When foundational documents disagree with current implementation, the implementation is treated as migration evidence, not automatically as the target architecture.

## 3. Finding summary

| ID | Finding | Severity | Decision |
|---|---|---:|---|
| SA-01 | `Cable -> CableRun` cardinality conflicts with canonical domain model | BLOCKER | reopen P0.1/P0.2 |
| SA-02 | `CableRun 1:1 CableRoute` conflicts with reusable Route/traversal architecture | BLOCKER | distinguish target domain from legacy route representation |
| SA-03 | P0.8 risks creating a second cable catalog/versioning mechanism beside ELV2 reference catalogs | BLOCKER | CableDefinition must integrate with ELV2 reference snapshot/binding architecture |
| SA-04 | multiple cables for one Connection are allowed without a first-class splice/termination continuity model | HIGH | prohibit incomplete realization or add explicit physical transition contract |
| SA-05 | room/floor boundaries are being used to split one physical cable into several CableRuns | HIGH | spatial segmentation must not redefine cable-run identity |
| SA-06 | `PhysicalChannel` flattens carrier and spatial pathway/container concepts (`tray/conduit` vs `shaft/riser`) | HIGH | introduce explicit pathway/carrier layering or a typed containment model |
| SA-07 | cable resource model omits termination mapping and non-signal resources such as shield/drain/PE where required | HIGH | extend resource/termination contract before P2 |
| SA-08 | ELV3 compatibility boundary vs ELV7 normative compliance is not sharp enough | HIGH | split technical compatibility from jurisdictional compliance |
| SA-09 | migration from electrical `CableRun.circuitId` assumes a physical cable identity that legacy data may never have represented | BLOCKER | legacy electrical route adoption must be evidence-driven, not automatic backfill |
| SA-10 | generic Cable/CableRun integration with the existing electrical domain is unresolved | BLOCKER | define electrical coexistence/adapter strategy before dropping circuit ownership |
| SA-11 | design-revision semantics from the canonical model are absent from P0 lifecycle/schema | MEDIUM | define whether deferred or required for ELV3 persistence identity |
| SA-12 | command/undo/dependency invalidation boundaries are under-specified for multi-aggregate physical-routing edits | HIGH | add application architecture contract before editor integration |

## 4. SA-01 — Cable/CableRun cardinality conflict

Foundational domain contract:

```text
Cable
- owns at most one active CableRun realization per design revision

CableRun
- installed geometric realization of one physical Cable
- ordered traversals[]
```

P0.1/P0.2 instead freezes:

```text
Cable 1 -> N CableRun
CableRun N -> 1 Cable
```

with examples splitting one cable into room/corridor/riser runs.

These are different domain semantics.

A physical cable does not become several installed cable runs merely because it crosses spatial ownership boundaries. Room/floor/riser segmentation is a routing/path segmentation concern.

### Resolution

Target domain should preserve:

```text
Cable 1 -> 0..1 active CableRun per design revision
CableRun -> ordered physical traversal/path segments
```

If the current implementation requires room-local records, they may remain a persistence/legacy representation behind an adapter during migration, but MUST NOT redefine the canonical domain.

P0.1/P0.2 must therefore be reopened.

## 5. SA-02 — CableRoute semantics conflict

The foundational architecture defines `Route` as reusable physical routing infrastructure/path topology, while `CableRun` traverses route segments.

Current implementation has a room-local `CableRoute` that is effectively an ordered cable-specific geometric polyline and is coupled 1:1 to current `CableRun` usage.

P0 freezes the implementation shape as canonical:

```text
CableRun 1 <-> 1 CableRoute
```

This converts a tactical legacy representation into the future domain model and conflicts with the architecture in which many cable runs can occupy the same route/pathway segments.

### Resolution

Do not rewrite the mature geometry kernel, but separate names/responsibilities conceptually:

```text
CableRun
  -> ordered CablePathTraversal[]

CablePathTraversal
  -> geometry/path segment
  -> optional PhysicalCarrier/Channel

shared Pathway/Route infrastructure
  <- many cable traversals
```

The existing `CableRoute` may serve as a transitional geometric implementation, but P0 must explicitly classify it as legacy/tactical rather than the final reusable `Route` aggregate.

## 6. SA-03 — duplicate reference-data architecture

ELV2 architecture already requires typed/versioned cable media and cable catalog data with exact project pinning/provenance.

P0.8 proposes a new standalone table family beginning with `CableDefinitions` containing its own catalog ID, edition ID and content hash.

Without an explicit integration contract this creates two competing versioning systems:

```text
ELV2 ReferenceCatalog / project binding / snapshots
vs
ELV3 CableDefinitions / catalog_id / edition_id / content_hash
```

### Resolution

`CableDefinition` should be an ELV3 domain view/profile over the accepted ELV2 reference-data infrastructure, not a second catalog subsystem.

Required architectural rule:

```text
Cable instance
  -> exact CableDefinition/Profile edition
  -> edition belongs to accepted reference snapshot/catalog architecture
```

P1 must consume the existing version/provenance mechanism or intentionally extend it through an ADR.

P0.8 schema proposal must be amended before implementation.

## 7. SA-04 — one Connection using several Cables

P0 allows:

```text
EngineeringConnection
  -> Allocation sequence 1 -> Cable A
  -> Allocation sequence 2 -> Cable B
```

but explicitly defers a splice/termination object.

Sequence alone does not prove physical continuity between two cables.

Examples that require explicit semantics:

- cable splice;
- terminal block;
- junction terminal;
- media transition;
- patching boundary;
- connectorized extension.

### Resolution

Until an explicit continuity mechanism exists, the complete/installed state of a connection MUST NOT be inferred from allocation sequence alone.

Preferred rule:

```text
one continuous cabled Connection -> one Cable
```

unless continuity between several cables is proven by explicit physical termination/splice/port objects.

The model may retain 0..N allocations as a future cardinality, but P2 must not treat ordered allocations as sufficient physical realization.

## 8. SA-05 — spatial segmentation must not redefine CableRun

P0 examples use:

```text
Cable C-001
  -> Run room 101
  -> Run corridor
  -> Run riser
  -> Run room 305
```

This is convenient for the current room-owned route persistence, but domain identity should not depend on room boundaries.

### Resolution

Use one CableRun with ordered spatial traversals. Persistence may internally split geometry into room-local chunks while exposing one domain run.

Floor handoff then becomes a geometry/path continuity construct, not a boundary between separate CableRun identities.

## 9. SA-06 — PhysicalChannel conflates carrier and spatial pathway

P0.4 places the following into one kind family:

```text
CONDUIT
TRAY
TRUNKING
DUCT
BASKET_TRAY
LADDER_TRAY
UNDERFLOOR
RISER
SHAFT
```

But `tray/conduit/trunking` are physical carriers with cross-section/fill properties, while `shaft/riser/underfloor` may be spatial pathway/container contexts that can themselves contain several carriers.

Flattening them makes later occupancy, segregation and enclosure/pathway modelling ambiguous.

### Resolution

Before P4 freeze a typed layering such as:

```text
PathwayContext
  shaft / riser / underfloor / ceiling void / corridor path

PhysicalCarrier
  tray / basket / ladder / conduit / trunking / duct

Carrier may be hosted by PathwayContext
Route/traversal may use carrier or free-path context
```

A simpler alternative is an explicit parent/containment hierarchy in one model, but the type distinction must remain observable.

## 10. SA-07 — CableAllocation resource and termination model incomplete

P0.3 correctly types `WHOLE_CABLE`, `PAIR`, `CONDUCTOR`, `FIBER` and definition-owned groups.

However the foundational model expects cable resources and endpoint termination mapping. P0.3 currently lacks a complete contract for:

- resource-to-port/terminal termination mapping;
- shield/screen/drain conductor where it is an engineered termination resource;
- protective earth or functional earth conductor when applicable to common cable infrastructure;
- spare/unallocated but reserved resources;
- asymmetric termination of multicore resources.

### Resolution

Do not necessarily add every item as a top-level enum. Instead P0.3 must add a general `CableResourceDefinition` + `CableTerminationMapping` capability so exact CableDefinition editions can expose typed addressable resources beyond only indexed signal cores.

Overlap must still resolve to deterministic atomic physical resources.

## 11. SA-08 — ELV3 vs ELV7 rule boundary

ELV3 delivery scope includes physical compatibility such as segregation, containment, bend radius, environment and fire-related facts. ELV7 owns jurisdiction/versioned normative profiles and compliance findings.

P0 currently mixes the vocabulary sufficiently that a later implementation could accidentally claim normative compliance in ELV3.

### Resolution

Freeze two result layers:

```text
ELV3 TechnicalPhysicalCompatibility
- geometry
- resource occupancy
- definition-declared installation constraints
- factual environment compatibility
- deterministic engineering profile compatibility

ELV7 NormativeCompliance
- jurisdiction-specific legal/code thresholds
- normative edition/source
- compliance claim/finding
```

ELV3 may produce `UNRESOLVED/FORBIDDEN` technical findings but MUST NOT state regulatory compliance without ELV7 rule provenance.

## 12. SA-09 — legacy electrical migration cannot assume Cable identity

Current `CableRun.circuitId` describes an electrical-routing construct. There is no existing persisted Cable entity proving that one legacy circuit run corresponds to one installed physical cable.

Even a simple electrical circuit may eventually require:

- multiple conductors;
- several parallel cables;
- shared neutral/PE semantics;
- different cable construction/installation assumptions.

Creating a new Cable automatically from every legacy circuit run can invent physical facts that were never persisted.

### Resolution

Migration must distinguish:

```text
legacy route evidence
from
proven physical Cable identity
```

Recommended strategy:

```text
LegacyElectricalRouteBinding
  -> preserve old circuit/run behavior
  -> optionally adopt into Cable/CableRun only through deterministic evidence or explicit user migration
```

`REVIEW_REQUIRED` is necessary but not sufficient if the default path still fabricates a cable for apparently simple cases.

## 13. SA-10 — electrical coexistence is unresolved

The common architecture intends Cable/CableRun to be shared by electrical and ELV disciplines, but current electrical domain is circuit-centric and does not use the ELV1 `EngineeringConnection -> CableAllocation` chain.

Therefore simply removing `CableRun.circuitId` leaves electrical ownership/integration undefined.

### Resolution

Before P3 implementation choose and document one of these strategies:

1. migrate electrical physical realization onto the common Cable/CableRun model through an explicit typed electrical binding;
2. keep legacy electrical route persistence isolated while ELV adopts the common Cable model, then migrate electrical in a separate vertical;
3. unify electrical topology with the common connection kernel through a larger ADR/migration.

For ELV3, option 2 is lowest risk. It avoids forcing an incomplete electrical migration into the ELV schedule.

The canonical shared model can still be the long-term target.

## 14. SA-11 — design revision semantics

The foundational Cable contract says at most one active CableRun realization per design revision. P0 lifecycle currently uses `ACTIVE/ARCHIVED` plus optimistic `revision`, but does not define a project design-revision identity.

Optimistic row version and engineering design revision are not the same concept.

### Resolution

P0 must explicitly choose:

- design revision is out of ELV3 scope and current active state is single-revision only; or
- ELV3 persistence includes explicit design revision/snapshot identity.

Do not use row `revision` as an implicit substitute.

## 15. SA-12 — command, undo and dependency architecture

ELV3 editor operations can span multiple roots:

```text
Cable
CableAllocation
CableRun
route geometry
channel binding
compatibility invalidation
```

The project already treats undo/redo, atomic placement and affected-subgraph recalculation as architectural behavior.

P0 lifecycle transactions describe storage atomicity but not user-command atomicity or dependency events.

### Resolution

Before P7 implementation define canonical commands/events, at minimum:

```text
CreateCable
AllocateCableResource
CreateCableRun / RouteCable
RerouteCable
BindTraversalToCarrier
ReleaseAllocation
ArchiveCable
```

Each command must specify:

- aggregate transaction boundary;
- idempotency identity;
- undo/redo inverse or snapshot strategy;
- affected dependency keys;
- stale calculations/findings;
- restart behavior.

This does not need to block pure P1 domain classes, but it is a mandatory architecture gate before persistence/editor closure.

## 16. Revised target architecture

Recommended target conceptual model:

```text
ELV1 LOGICAL
EngineeringSystem
  -> TopologyGroup
  -> EngineeringConnection
  -> Ports

ELV2 REFERENCE
ReferenceSnapshot
  -> exact CableDefinition/Profile edition

ELV3 PHYSICAL
EngineeringConnection
  -> CableAllocation
  -> Cable
  -> CableRun (0..1 active run per design revision)
  -> ordered Traversal[]
  -> geometry/path segment
  -> optional PhysicalCarrier
  -> optional PathwayContext

CableAllocation
  -> typed CableResourceSelection
  -> CableTerminationMapping

ELV7
technical ELV3 evidence
  + jurisdiction rule pack
  -> normative findings/compliance evidence
```

This preserves the successful current routing geometry as an implementation asset without elevating every current room-local persistence compromise into the canonical domain.

## 17. What remains valid from current P0

The audit DOES NOT recommend discarding P0.

Keep and reuse:

- P0 inventory;
- separation of logical topology and physical cable;
- CableAllocation concept;
- deterministic resource overlap validation;
- immutable exact cable-definition provenance;
- factual-vs-normative channel separation;
- restart/audit principles;
- no fake circuit IDs;
- current geometry validator;
- four-discipline regression fixtures;
- staged migration principle;
- technical compatibility result structure;
- exact-SHA delivery gates.

Required work is targeted architectural correction, not restart from zero.

## 18. Required remediation before P1 authorization

Create a short `P0-R` remediation loop:

```text
P0-R1  resolve Cable <-> CableRun cardinality
P0-R2  resolve CableRun traversal vs CableRoute/Route semantics
P0-R3  integrate CableDefinition with ELV2 reference-data/versioning architecture
P0-R4  define multi-cable continuity / splice rule
P0-R5  split PhysicalCarrier vs PathwayContext (or equivalent typed hierarchy)
P0-R6  add termination/resource extensibility contract
P0-R7  freeze ELV3 technical compatibility vs ELV7 normative boundary
P0-R8  replace automatic electrical CableRun backfill with explicit coexistence/adoption strategy
P0-R9  update persistence proposal and four-discipline walkthrough
P0-R10 rerun system architecture + adversarial audit
```

Only after P0-R10 passes should roadmap return to:

```text
ELV3 P0 CLOSED / P1 AUTHORIZED
```

## 19. Final system-architect resolution

Current branch state should be interpreted as:

```text
ELV1                   CLOSED / ACCEPTED
ELV2                   CLOSED / ACCEPTED
Pre-ELV3 hardening     CLOSED
ELV3-P0                REOPENED FOR ARCHITECTURE REMEDIATION
ELV3-P1                HOLD
```

The project is not in a bad state. The design work exposed the correct abstractions, but the hard audit was too local to the new P0 documents and did not sufficiently reconcile them against the older foundational domain model and the electrical legacy architecture.

Correcting these issues now is significantly cheaper than encoding them into Drift schema and editor commands.