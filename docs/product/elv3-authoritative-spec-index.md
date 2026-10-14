# Electra — ELV3 Authoritative Specification Index

Status: EXECUTION AUTHORITY / READY FOR EXECUTION  
Branch: `feat/flutter-elv3-physical-routing-design`

## 1. Purpose

This index removes document-precedence ambiguity before ELV3 implementation starts.

Implementation teams MUST use the documents below in this order. Historical files may remain for audit evidence but cannot override this set.

## 2. Authority order

1. `docs/product/elv3-implementation-specification-v2.md` — executable P1-P9 contract.
2. `docs/product/elv3-pre-p1-final-hardening.md` — explicit F1-F7 closure and any detail not repeated in v2.
3. `docs/adr/ADR-029-elv3-reusable-route-traversal.md` — single routing evolution decision.
4. `docs/adr/ADR-030-project-design-revision-identity.md` — stable design revision decision.
5. `docs/product/elv3-p0-system-architecture-remediation.md` — system architecture meaning.
6. Remediated P0.1-P0.9 documents — supporting detail only where consistent with 1-5.

If wording conflicts, the earlier item in this list wins.

## 3. Explicitly superseded implementation sources

Do not implement from:

- `docs/product/elv3-implementation-specification.md` — first implementation draft, now redirect only;
- first-closure assumptions recorded in historical P0/audit text;
- any historical statement requiring `Cable 1 -> N room-local CableRuns`;
- any historical statement requiring `CableRun 1:1 private CableRoute` as final architecture;
- any autonomous ELV3 CableDefinition catalog/version lifecycle;
- automatic `circuitId -> cableId` migration;
- generic `transitionRef` without typed transition topology;
- generic open-ended `PathwayContext.spatialHost/reference`.

## 4. Frozen implementation decisions

The following are not implementation choices:

```text
Cable definition provenance
  = CableDefinitionRef(catalogId, catalogVersion, definitionCode, contentHash)
  resolved from project EngineeringReferenceCatalog

CableAllocation lifecycle
  = DRAFT -> RESERVED -> ACTIVE -> RELEASED -> ARCHIVED
  plus DRAFT->ARCHIVED and RESERVED->RELEASED cancellation paths only

Multi-cable continuous connection
  = NOT SUPPORTED in ELV3 P1-P9

Routing
  = one existing/evolved CableRoute/Node/Segment graph
    + CableRunTraversal references

Design revision
  = ProjectDesignRevision.id
  != Projects.revision

Pathway hosting
  = sealed RoomHost/FloorHost/SurfaceVoidHost/VerticalHost/ProjectHost

P5 technical profiles
  = PhysicalCompatibilityProfile in exact ELV2 EngineeringReferenceCatalog edition

P6 segregation
  = factual evidence only; normative threshold/compliance belongs to ELV7
```

## 5. Frozen P3 canonical table names

To avoid collision with the existing legacy electrical `CableRuns` table, P3 uses these exact new Drift table/domain persistence names:

```text
ProjectDesignRevisions
CanonicalCableRuns
CableRunTraversals
LegacyRouteAdoptions
```

`CanonicalCableRuns` is the canonical common physical CableRun persistence introduced by ELV3. Existing `CableRuns` remains legacy electrical persistence during coexistence. A later independently gated convergence may rename/migrate after regression proof; ELV3 P3 does not choose another name.

## 6. Remaining implementation freedom

The following may vary without changing architecture:

- Dart source file boundaries;
- private helper class names;
- Drift schema version integer assigned by migration ordering;
- SQL statement shape that proves the required atomic result;
- widget composition inside the specified progressive workspace;
- test helper organization;
- performance indexes/materialized projections that do not change source-of-truth semantics.

No other domain, identity, cardinality, lifecycle, ownership or persistence relationship may be selected ad hoc during implementation.
