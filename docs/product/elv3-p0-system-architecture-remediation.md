# Electra — ELV3 P0 System Architecture Remediation

Status: AUTHORITATIVE REMEDIATION CONTRACT / P0 REOPENED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Supersedes conflicting clauses in: P0.1–P0.9  
Triggered by: `docs/audit/elv3-system-architecture-consistency-audit.md`  
Implementation status: HOLD

## 1. Decision

ELV3 remains the correct next capability, but the first P0 closure is withdrawn.

This document is authoritative wherever it conflicts with earlier ELV3 P0 documents.

Current gate:

```text
ELV3 direction                    ACCEPTED
ELV3-P0                           REOPENED
ELV3-P1 implementation            HOLD
system architecture remediation  IN PROGRESS
```

No ELV3 schema/domain implementation may begin until the remediation acceptance gate in section 16 is closed.

## 2. Architecture invariants retained

The following P0 decisions remain valid:

- `EngineeringConnection != Cable`;
- physical realization uses explicit `CableAllocation`;
- one physical cable may expose several allocatable resources;
- logical connectivity is never inferred from crossing route geometry;
- common routing/geometry infrastructure is shared by electrical and ELV disciplines;
- discipline-specific routing entity copies are prohibited;
- physical occupancy is based on physical cable identity, not allocation count;
- channel/pathway facts are separated from normative thresholds;
- exact version/provenance and restart determinism are mandatory;
- fake `ElectricalCircuit`/network identities for ELV are prohibited.

## 3. Corrected canonical layering

The corrected model is layered as follows.

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
    -> Cable
    -> CableRun
    -> ordered CableTraversal[]
    -> Route / geometry infrastructure
    -> PhysicalCarrier
    -> PathwayContext
```

`CableAllocation` additionally owns physical resource use and termination mapping:

```text
CableAllocation
    -> CableResourceSelection
    -> CableTerminationMapping[]
```

This model preserves the five-way separation:

```text
discipline != topology != cable != run != routing infrastructure
```

## 4. R1 — corrected Cable ↔ CableRun cardinality

The earlier P0 rule:

```text
Cable 1 -> N CableRun
```

is withdrawn as the canonical target.

Correct rule per design revision:

```text
Cable 1 -> 0..1 active CableRun
CableRun 1 -> 1 Cable
```

`CableRun` represents the complete active geometric realization of one physical cable for one design revision.

A cable crossing room/floor/riser boundaries does NOT gain a new CableRun merely because the spatial host changes.

Example:

```text
Cable C-001
  -> CableRun CR-001
       -> Traversal 1 / room 101
       -> Traversal 2 / corridor
       -> Traversal 3 / riser
       -> Traversal 4 / floor 3
       -> Traversal 5 / room 305
```

A future revision may replace the active run while retaining historical evidence according to project revision policy.

## 5. R2 — CableRun traversal vs legacy CableRoute

The earlier canonical rule:

```text
CableRun 1 <-> 1 CableRoute
```

is withdrawn as a target-domain invariant.

The target domain is:

```text
CableRun
  -> ordered CableTraversal[]

CableTraversal
  -> route/path segment identity
  -> direction
  -> attachment/start/end facts as required
```

A `Route`/pathway is reusable physical routing infrastructure; many cable runs may traverse the same infrastructure.

Current `CableRoute`, `CableRouteNode`, `CableRouteSegment` remain valuable legacy/mature geometry implementation assets. ELV3 MUST reuse them through an adapter/evolution path, but their current one-run-local representation MUST NOT be elevated blindly into the final aggregate contract.

Implementation options allowed after P0 closure:

1. adapt current `CableRoute` records into traversal infrastructure;
2. introduce reusable route/path segments while preserving the current geometry validator;
3. retain room-local geometry records internally but expose one logical `CableRun` composed from ordered traversals.

Whichever option is chosen must preserve geometry validation and restart behavior.

## 6. R3 — CableDefinition integrates with ELV2 reference architecture

ELV3 MUST NOT create a second independent catalog/versioning subsystem.

Canonical rule:

```text
ELV2 ReferenceSnapshot / project binding
    -> exact cable definition/profile edition
    -> project Cable
```

`CableDefinition` remains a typed domain concept, but its identity/version/provenance must use the accepted ELV2 reference-data mechanisms.

ELV3 persistence may introduce projection/cache tables for performance, but it must not duplicate:

- catalog lifecycle;
- edition/version semantics;
- project pinning;
- deprecation/retirement rules;
- provenance governance.

A project cable stores an exact immutable reference binding sufficient to reconstruct the same engineering facts after restart.

## 7. R4 — multi-cable realization requires explicit physical transition

The earlier allowance for one `EngineeringConnection` to reference several cables merely by allocation `sequence` is narrowed.

Default invariant:

```text
one continuous wired EngineeringConnection
    -> one physical Cable
```

Multiple cables may realize one higher-level logical path only when an explicit physical transition/termination semantics exists, for example:

- splice;
- terminal block;
- connector pair;
- patching boundary;
- junction/termination component;
- media-conversion component represented through ELV1 ports/connections.

`sequence = 1,2,...` alone does not prove physical continuity.

Until an explicit splice/transition contract is introduced, P2 MUST reject multi-cable allocations for one continuous connection.

## 8. R5 — PhysicalCarrier vs PathwayContext

The earlier P0.4 list mixed carrier construction with spatial/pathway context.

Correct separation:

```text
PhysicalCarrier
  TRAY
  BASKET_TRAY
  LADDER_TRAY
  CONDUIT
  TRUNKING
  DUCT
  CUSTOM

PathwayContext
  ROOM_LOCAL
  FLOOR_COMMON
  CEILING_VOID
  UNDERFLOOR
  RISER
  SHAFT
  PROJECT_SHARED
  CUSTOM
```

A shaft/riser is not automatically a tray/conduit. A shaft may contain several carriers.

Conceptually:

```text
PathwayContext SHAFT-S1
  |- carrier TRAY-T1
  |- carrier CONDUIT-C1
  `- carrier TRUNKING-T2
```

`PhysicalCarrier` owns factual dimensions, compartments and installation facts.
`PathwayContext` owns spatial continuity/location context.

This does not require a new discipline-specific routing hierarchy.

## 9. R6 — extensible cable resource model and termination mapping

The resource kinds retained from P0.3 are still valid common cases:

```text
WHOLE_CABLE
PAIR
CONDUCTOR
FIBER
CORE_GROUP
```

But they are no longer assumed to be exhaustive.

A cable definition must expose a typed resource namespace capable of representing additional definition-owned resource roles when engineering requires them, such as:

```text
SHIELD
DRAIN
PROTECTIVE_EARTH
FUNCTIONAL_EARTH
BUNDLE/GROUP
CUSTOM_DEFINITION_RESOURCE
```

No arbitrary free-text resource IDs are permitted.

Canonical selection model:

```text
CableResourceDefinition[]
CableResourceSelection
```

Allocation must also support explicit termination mapping where resource-to-port/terminal identity matters:

```text
CableTerminationMapping {
  allocationId
  resourceId
  endpointSide
  portId
  terminal/contact/channel reference?
  role?
}
```

This mapping is physical realization evidence. It must not redefine ELV1 logical topology.

## 10. R7 — technical compatibility vs normative compliance

ELV3 and ELV7 boundaries are sharpened.

### ELV3 owns technical physical compatibility

Examples:

- selected resource exists and is not double allocated;
- cable physical diameter can be evaluated against carrier geometry;
- bend geometry vs cable minimum bend-radius fact;
- laying method vs carrier construction;
- factual environment mismatch where both facts are explicit;
- occupancy/fill basis;
- compartment placement;
- deterministic physical continuity.

ELV3 result vocabulary may use:

```text
COMPATIBLE
WARNING
FORBIDDEN
UNRESOLVED
```

but findings must identify themselves as technical/physical.

### ELV7 owns normative/jurisdictional compliance

Examples:

- legally permitted fill threshold;
- mandatory segregation distance;
- jurisdiction-specific fire routing requirement;
- code/standard compliance statement;
- normative exception/waiver handling.

ELV3 MUST NOT claim compliance with a jurisdiction or standard without an ELV7 versioned rule pack.

## 11. R8 — electrical coexistence and migration strategy

The earlier concept of automatically replacing:

```text
CableRun.circuitId -> CableRun.cableId
```

through inferred physical Cable creation is withdrawn.

Reason: a legacy electrical circuit route does not prove the exact number, construction or identity of physical cables.

Correct strategy:

```text
legacy electrical routing
    -> preserved legacy behavior / compatibility adapter

explicit evidence/adoption command
    -> create/bind canonical Cable
    -> create canonical CableRun realization
```

Rules:

- no automatic invention of physical cable identity;
- no guessed conductor/resource model;
- no fake mapping merely to satisfy new FK constraints;
- ambiguous legacy electrical records remain legacy/unadopted;
- adoption is idempotent and evidence-driven;
- ELV3 does not need to complete the whole electrical-domain migration before delivering ELV physical routing.

`circuitId` may remain in the legacy persistence path until a separately accepted electrical migration closes it.

## 12. R9 — project design revision semantics

Canonical physical realization is revision-aware.

At minimum the implementation must distinguish:

```text
current active realization
historical/superseded realization
```

Whether this uses an explicit `designRevisionId` or the existing project revision mechanism must be decided before schema implementation.

P0 persistence may not assume global destructive replacement when traceability requires reconstruction of a previous accepted design state.

## 13. R10 — command, undo/redo and dependency boundaries

ELV3 mutations cross several aggregates and therefore require application-level commands.

Required command families include at least:

```text
CreateCable
ChangeCableDefinitionBinding
AllocateCableResources
ReleaseCableResources
BindCableTermination
CreateOrReplaceCableRun
RerouteCableRun
AttachTraversalToCarrier
DetachTraversalFromCarrier
AdoptLegacyElectricalRoute
ArchiveCable
```

Each command must define:

- aggregate references;
- project/revision guard;
- atomic persistence boundary;
- validation inputs;
- dependency invalidation keys;
- undo inverse or snapshot strategy;
- idempotency identity where retry is possible.

UI must not mutate several repositories independently to simulate one engineering operation.

## 14. Revised persistence direction

P0.8 schema proposal is no longer implementation-authoritative where it conflicts with this remediation.

Target persistence must support these concepts without requiring these exact table names:

```text
Cable                         project physical identity
CableReferenceBinding         exact ELV2 reference edition identity
CableAllocation               connection -> cable realization
CableAllocationResource       normalized resource selection
CableTerminationMapping       physical termination evidence
CableRun                      one active run per cable/revision
CableTraversal                ordered traversal records
Route/geometry infrastructure reusable across runs where applicable
PhysicalCarrier               tray/conduit/trunking factual asset
CarrierCompartment            physical subdivision
PathwayContext                shaft/riser/floor/shared spatial context
LegacyElectricalRouteAdoption explicit migration/adoption evidence
```

Existing `CableRoutes/CableRouteNodes/CableRouteSegments` MUST be migrated/evolved rather than discarded.

## 15. Revised four-discipline acceptance

### CCTV

```text
Camera port
 -> Connection
 -> WHOLE_CABLE allocation
 -> Cable
 -> one CableRun
 -> ordered traversals through wall / tray / telecom room
 -> PoE switch port
```

No ELV3 PoE-budget calculation.

### LAN

```text
Outlet.REAR
 -> Connection
 -> Cable
 -> one CableRun
 -> reusable horizontal pathway
 -> PatchPanel.REAR
```

`InternalConnectivity` remains internal and does not create cable.

### ACS

One multicore cable may carry several logical connections through non-overlapping resource selections and explicit termination mappings.

The physical pathway counts the Cable once.

### Fire

ELV1 owns loop topology. ELV3 owns cable/resource/physical route. ELV7 owns jurisdiction-specific fire-routing compliance.

### Fiber extension

A multi-fiber cable must prove that resource selections and terminations work without copper-specific assumptions.

## 16. Remediation acceptance gate

P0 may be re-closed only when all statements are true:

- [ ] canonical `Cable 1 -> 0..1 active CableRun per design revision` is reflected across P0 docs;
- [ ] CableRun uses ordered traversal semantics rather than room-boundary run splitting as the target model;
- [ ] legacy `CableRoute` is explicitly an implementation asset/evolution input, not blindly the final Route aggregate;
- [ ] `CableDefinition` consumes ELV2 reference snapshot/version governance;
- [ ] multi-cable realization cannot rely on sequence alone;
- [ ] `PhysicalCarrier` and `PathwayContext` are semantically separated;
- [ ] cable resources support explicit typed extension and termination mapping;
- [ ] ELV3 technical compatibility is separated from ELV7 normative compliance;
- [ ] electrical legacy routing remains valid without invented Cable identities;
- [ ] explicit adoption/migration is evidence-driven and idempotent;
- [ ] revision semantics are resolved for active/historical run identity;
- [ ] application command/undo/dependency boundaries are specified;
- [ ] persistence proposal is revised against this contract;
- [ ] CCTV/LAN/ACS/Fire + fiber walkthroughs pass the revised model;
- [ ] final system architecture audit reports no BLOCKER;
- [ ] only then may ELV3-P1 implementation start.

## 17. Revised remediation sequence

```text
P0-R1  Cable <-> CableRun cardinality
P0-R2  CableRun traversal / reusable route architecture
P0-R3  CableDefinition <-> ELV2 reference binding
P0-R4  multi-cable transition/termination rule
P0-R5  PhysicalCarrier / PathwayContext
P0-R6  resource + termination model
P0-R7  ELV3 technical / ELV7 normative boundary
P0-R8  electrical coexistence/adoption strategy
P0-R9  revision + command + persistence revision
P0-R10 four-discipline/fiber walkthrough + final system audit
```

## 18. Status after this remediation document

```text
ELV1                  CLOSED / ACCEPTED
ELV2                  CLOSED / ACCEPTED
Pre-ELV3 hardening    CLOSED
ELV3-P0 initial pass  SUPERSEDED IN PART
ELV3-P0 remediation   ACTIVE
ELV3-P1               HOLD
```
