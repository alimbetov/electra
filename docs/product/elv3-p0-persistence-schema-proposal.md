# Electra — ELV3 P0.8 Persistence / Schema Proposal

Status: REMEDIATED DESIGN PROPOSAL / P0-R9  
Branch: `feat/flutter-elv3-physical-routing-design`  
Authoritative parent: `docs/product/elv3-p0-system-architecture-remediation.md`  
Implementation status: NOT AUTHORIZED UNTIL P0-R10

## 1. Purpose

Translate the remediated ELV3 domain model into a persistence direction without creating a second reference-data architecture or forcing legacy electrical routing into invented Cable identities.

This document supersedes the first P0.8 proposal where it introduced an independent `CableDefinitions` table family and modeled `Cable 1 -> N CableRun` with room-local route ownership.

## 2. Persistence principles

1. Reuse ELV2 reference snapshot/binding/version governance.
2. Persist project-owned physical Cable identity separately from reference definitions.
3. One Cable has at most one active CableRun per design revision.
4. CableRun persists ordered traversal usage of reusable route infrastructure.
5. PhysicalCarrier and PathwayContext are distinct persisted concepts.
6. Resource selections are normalized enough to enforce overlap atomically.
7. Cable terminations are persisted explicitly when required.
8. Legacy electrical routing remains valid without mandatory synthetic cable backfill.
9. Derived compatibility/calculation results are rebuildable evidence, not editable source truth.

## 3. ELV2 reference integration

ELV3 MUST NOT create a parallel catalog/versioning subsystem such as an autonomous `CableDefinitions` lifecycle.

A project Cable references the exact cable definition/profile edition through the accepted ELV2 reference architecture.

Conceptual field:

```text
cable_definition_binding_id
```

The exact FK target must use the already accepted ELV2 schema/project-binding concept available at implementation time.

Required semantics:

- exact immutable definition edition;
- project/reference snapshot provenance;
- no silent latest-edition adoption;
- explicit migration/adoption only.

## 4. Project-owned Cables

Conceptual table:

```text
Cables
- id
- project_id
- label
- name
- cable_definition_binding_id
- lifecycle_state
- revision
- created_at / created_by
- updated_at / updated_by
- archived_at / archived_by?
```

Constraints:

```text
unique active label inside project where applicable
project-safe definition binding
```

No room/floor ownership belongs on Cable.

## 5. CableAllocations

```text
CableAllocations
- id
- project_id
- engineering_connection_id
- cable_id
- lifecycle_state
- transition_ref?      // only for explicit multi-cable continuity
- revision
- audit columns
```

Do not use free-form selector text as canonical state.

## 6. Cable allocation resource atoms

Normalized child table/projection:

```text
CableAllocationResources
- allocation_id
- cable_id              // denormalized/indexed if needed for uniqueness
- resource_code
- resource_kind
- resource_index?
- definition_resource_identity
```

Database/repository must guarantee that two resource-consuming allocations cannot claim the same atom on the same Cable.

Preferred enforceable key where applicable:

```text
UNIQUE(cable_id, definition_resource_identity)
```

`WHOLE_CABLE` exclusivity may require a dedicated reservation atom or transaction guard.

## 7. Cable termination mappings

```text
CableTerminationMappings
- id
- allocation_id
- cable_resource_identity
- end_role                 // A | B | INTERMEDIATE
- endpoint_port_id
- endpoint_terminal_ref?
- termination_role?
- revision/audit metadata
```

Termination rows must reference persisted project endpoint identities and cannot substitute display labels for identity.

## 8. CableRuns

Canonical table:

```text
CableRuns
- id
- project_id
- cable_id
- design_revision_id
- lifecycle_state          // ACTIVE / SUPERSEDED / ARCHIVED as required
- reserve/slack policy facts where run-scoped
- revision
- audit columns
```

Constraint:

```text
at most one ACTIVE CableRun per (cable_id, design_revision_id)
```

No canonical `circuit_id` ownership field belongs on new ELV3 CableRun records.

No room ownership is required on CableRun itself.

## 9. CableRunTraversals

```text
CableRunTraversals
- id
- cable_run_id
- sequence_no
- route_segment_id / route_reference
- direction
- physical_carrier_id?
- carrier_compartment_id?
- start_attachment_ref?
- end_attachment_ref?
- revision/audit metadata as needed
```

Constraints:

```text
UNIQUE(cable_run_id, sequence_no)
ordered traversals form a continuous path
referenced route geometry belongs to same project
carrier/compartment references match traversal geometry/context
```

This replaces the old final-domain assumption `CableRun.route_id -> exactly one owned CableRoute`.

## 10. Reusable route geometry

The existing geometry tables remain valuable:

```text
CableRoutes
CableRouteNodes
CableRouteSegments
SurfacePatches
SurfaceEdges
SurfaceAdjacencies
Openings
SpatialFeatures
```

However, implementation must evolve them toward reusable route infrastructure rather than duplicating one independent canonical route per CableRun.

P0 does not require an immediate destructive rewrite. An adapter/evolution layer is acceptable if canonical traversal semantics are preserved.

## 11. PathwayContexts

Conceptual table:

```text
PathwayContexts
- id
- project_id
- kind
- room_id?
- floor_id?
- spatial_feature_id?
- parent_context_id?
- vertical_span_or_geometry_ref?
- provenance
- lifecycle_state
- revision
```

Typed validation makes invalid host combinations impossible.

Examples:

```text
ROOM_LOCAL
FLOOR_COMMON
CEILING_VOID
UNDERFLOOR
RISER
SHAFT
PROJECT_SHARED
```

## 12. PhysicalCarriers

```text
PhysicalCarriers
- id
- project_id
- pathway_context_id
- code
- name
- kind
- cross_section_shape
- width_mm?
- height_mm?
- diameter_mm?
- usable_area_mm2?
- environment/install facts
- provenance
- lifecycle_state
- revision
```

Kinds include tray/conduit/trunking/duct and other physical carrier constructions, not shaft/riser spatial contexts.

## 13. Carrier compartments

```text
PhysicalCarrierCompartments
- id
- physical_carrier_id
- code
- sequence_no
- width_mm?
- height_mm?
- usable_area_mm2?
```

A traversal may bind to one carrier or one compartment target.

## 14. Legacy electrical routing coexistence

Existing tables/columns such as:

```text
CableRuns.circuit_id
JunctionConnections.circuit_id
FloorRoutingHandoffs
```

remain valid legacy electrical persistence until explicit adoption.

ELV3 implementation MUST NOT require a global migration that fills `cable_id` for every existing row.

Possible implementation strategies:

- separate canonical ELV3 CableRun/traversal tables;
- staged schema with explicit legacy/canonical discriminator and strong constraints;
- compatibility views/adapters.

Selection must preserve referential integrity and existing electrical tests.

## 15. LegacyRouteAdoptions

When explicit adoption occurs, persist mapping/provenance:

```text
LegacyRouteAdoptions
- legacy_run_id
- legacy_circuit_id
- cable_id
- canonical_cable_run_id
- design_revision_id
- source_evidence_ref?
- status
- adopted_at
- adopted_by
```

Unique legacy source identity makes adoption idempotent.

## 16. Foreign-key/deletion rules

Restrictive by default:

```text
EngineeringConnection <- CableAllocation        RESTRICT
Cable <- CableAllocation                        RESTRICT
Cable <- active CableRun                        RESTRICT
CableRun <- CableRunTraversal                   aggregate controlled
Route/RouteSegment <- CableRunTraversal         RESTRICT
PhysicalCarrier <- CableRunTraversal            RESTRICT
PathwayContext <- PhysicalCarrier               RESTRICT
ELV2 CableDefinition binding <- Cable            governed by ELV2/restrictive
```

Cascade is acceptable only for strict owned child records such as allocation resource atoms or termination rows when the parent operation itself is authorized.

## 17. Command transaction boundaries

Persistence APIs must support atomic commands rather than arbitrary row operations:

```text
CreateCable
AllocateCableResources
ReleaseCableResources
BindCableTermination
CreateCableRun
RerouteCableRun
SupersedeCableRun
AttachTraversalToCarrier
CreateOrUpdatePhysicalCarrier
CreateOrUpdatePathwayContext
AdoptLegacyElectricalRoute
ArchiveCable
```

Each command validates project scope and expected revisions before commit.

## 18. Concurrency

Minimum protections:

- optimistic revision guard for mutable roots;
- atomic resource overlap protection;
- unique active CableRun realization per Cable/revision;
- idempotent legacy adoption;
- no duplicate command result after retry.

## 19. Restart requirements

After database reopen reconstruct exactly:

- Cable + exact ELV2 definition binding;
- allocations/resource atoms;
- termination mappings;
- active/superseded CableRun identity;
- ordered traversals;
- route geometry references;
- carrier/pathway context;
- provenance/audit metadata;
- legacy adoption mapping.

## 20. Derived evidence

If later persisted, these are cache/evidence only:

```text
installed cable length
occupied carrier area
fill basis
technical compatibility findings
```

They require an input fingerprint over exact revisions/identities and must be rebuildable.

## 21. Schema delivery sequence

Recommended capability order:

```text
P1
  Cable project identity + ELV2 exact definition binding

P2
  CableAllocation + resource atoms + termination mappings

P3
  CableRun + CableRunTraversal canonical path
  coexistence/adoption adapter for legacy electrical routing

P4
  PathwayContext + PhysicalCarrier + compartments

P5+
  compatibility evidence/calculation projections
```

Exact Drift schema-version numbers are implementation decisions, not P0 architecture.

## 22. P0.8 remediation acceptance

- [x] no parallel ELV3 CableDefinition catalog system.
- [x] Cable references exact ELV2 reference binding.
- [x] one active CableRun per Cable/design revision.
- [x] traversal storage replaces room-local multiple-run target model.
- [x] route infrastructure can be reused.
- [x] PhysicalCarrier and PathwayContext are separate.
- [x] termination mappings are persisted.
- [x] legacy electrical rows need no synthetic Cable backfill.
- [x] command/revision/concurrency constraints are represented.

P0.8 is synchronized and ready for P0-R10 final audit.