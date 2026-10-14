# Electra — ELV3 Authoritative Specification Index

Status: EXECUTION AUTHORITY / R2 HARDENED / THIRD AUDIT REQUIRED  
Branch: `feat/flutter-elv3-physical-routing-design`

## 1. Purpose

This index removes document-precedence ambiguity before ELV3 implementation starts.

Implementation teams MUST use the documents below in this order. Historical files may remain for audit evidence but cannot override this set.

## 2. Authority order

1. `docs/product/elv3-r2-final-readiness-remediation.md` — authoritative closure of the second technical audit; overrides conflicting P1-P9 wording.
2. `docs/product/elv3-implementation-specification-v2.md` — executable P1-P9 contract where not superseded by R2.
3. `docs/product/elv3-pre-p1-final-hardening.md` — F1-F7 closure where consistent with R2.
4. `docs/adr/ADR-029-elv3-reusable-route-traversal.md` — one routing evolution decision.
5. `docs/adr/ADR-030-project-design-revision-identity.md` — stable design revision identity.
6. `docs/product/elv3-p0-system-architecture-remediation.md` — system architecture meaning.
7. Remediated P0.1-P0.9 documents — supporting detail only where consistent with 1-6.

If wording conflicts, the earlier item in this list wins.

## 3. Explicitly superseded implementation sources/wording

Do not implement from:

- `docs/product/elv3-implementation-specification.md` — first implementation draft, redirect only;
- any v2 wording contradicted by R2 remediation;
- first-closure assumptions recorded in historical P0/audit text;
- `Cable 1 -> N room-local CableRuns`;
- `CableRun 1:1 private CableRoute` as final architecture;
- autonomous ELV3 CableDefinition catalog/version lifecycle;
- automatic `circuitId -> cableId` migration;
- generic `transitionRef` without typed transition topology;
- generic open-ended `PathwayContext.spatialHost/reference`;
- inferred bend radius from point/polyline geometry;
- mutable current rows as source-of-truth for FROZEN design revisions;
- one persistence row serving both historical resource-selection evidence and temporary consuming claims.

## 4. Frozen implementation decisions

The following are not implementation choices:

```text
Cable definition provenance
  = CableDefinitionRef(catalogId, catalogVersion, definitionCode, contentHash)
  contentHash = SHA-256(UTF-8(canonicalEngineeringJson(electra.cable-definition.v1 payload)))

ELV2 P1 wire extension
  = retain existing `profiles` field
  + optional `cableDefinitions`
  P5 later adds `physicalCompatibilityProfiles`

CableAllocation lifecycle
  = DRAFT -> RESERVED -> ACTIVE -> RELEASED -> ARCHIVED
  plus DRAFT->ARCHIVED and RESERVED->RELEASED cancellation paths only

Resource ownership
  = persistent selection/evidence rows
  + separate temporary consuming claim rows

Multi-cable continuous connection
  = NOT SUPPORTED in ELV3 P1-P9

Routing
  = one existing/evolved CableRoute/Node/Segment graph
    + CableRunTraversal references
    + canonical RouteHandoff

Bend radius
  = explicit RouteBendEvidence only; never inferred from polyline vertices

Design revision
  = ProjectDesignRevision.id != Projects.revision
  FROZEN source-of-truth = immutable DesignRevisionPhysicalSnapshot

Pathway hosting
  = sealed RoomHost/FloorHost/SurfaceVoidHost/VerticalHost/ProjectHost
  parent hierarchy is project-local and acyclic

P5 technical profiles
  = exact PhysicalCompatibilityProfile refs under ELV2 catalog governance

P6
  = exact length/area formulas + segment/carrier/compartment occupancy basis
  segregation output = factual evidence only; normative acceptance belongs to ELV7
```

## 5. Frozen P3 canonical table names

P3 uses exactly:

```text
ProjectDesignRevisions
DesignRevisionPhysicalSnapshots
CanonicalCableRuns
CableRunTraversals
RouteHandoffs
RouteBendEvidence
LegacyRouteAdoptions
```

Existing `CableRuns`, `CableRoutes`, `CableRouteNodes`, `CableRouteSegments` and `FloorRoutingHandoffs` remain legacy/coexistence inputs. A later independently gated convergence may rename/migrate them; P3 does not choose alternative canonical names.

## 6. Remaining implementation freedom

The following may vary without changing architecture:

- Dart source file boundaries;
- private helper class names;
- Drift schema version integer assigned by migration ordering;
- equivalent SQL statement shape that proves required atomic behavior;
- widget composition inside the specified progressive workspace;
- test helper organization;
- non-semantic indexes/materialized projections that do not change source-of-truth semantics.

No other domain, identity, cardinality, lifecycle, ownership, historical-evidence or persistence relationship may be selected ad hoc during implementation.

## 7. Execution authorization

R2 remediation must be followed by `docs/audit/elv3-p1-p9-third-adversarial-audit.md`.

P1 is authorized only if that third audit reports zero open BLOCKER/HIGH specification findings and the roadmap is updated accordingly.
