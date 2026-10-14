# Electra — ELV3 Authoritative Specification Index

Status: EXECUTION AUTHORITY / R2 HARDENED / READY FOR EXECUTION  
Branch: `feat/flutter-elv3-physical-routing-design`

## 1. Purpose

This index removes document-precedence ambiguity before ELV3 implementation starts.

Implementation teams MUST use the documents below in this order. Historical files may remain for audit evidence but cannot override this set.

## 2. Authority order

1. `docs/product/elv3-r2-execution-clarifications.md` — final execution clarifications for frozen write guards, handoffs, selection history, exact hashes, CableDefinition semantics and P5 profile-set semantics.
2. `docs/product/elv3-r2-final-readiness-remediation.md` — authoritative closure of the second technical audit.
3. `docs/product/elv3-implementation-specification-v2.md` — executable P1-P9 contract where not superseded by R2.
4. `docs/product/elv3-pre-p1-final-hardening.md` — F1-F7 closure where consistent with R2.
5. `docs/adr/ADR-029-elv3-reusable-route-traversal.md` — one routing evolution decision.
6. `docs/adr/ADR-030-project-design-revision-identity.md` — stable design revision identity.
7. `docs/product/elv3-p0-system-architecture-remediation.md` — system architecture meaning.
8. Remediated P0.1-P0.9 documents — supporting detail only where consistent with 1-7.

If wording conflicts, the earlier item wins.

## 3. Explicitly superseded implementation sources/wording

Do not implement from:

- `docs/product/elv3-implementation-specification.md` — first implementation draft, redirect only;
- any v2 wording contradicted by R2 remediation/clarifications;
- first-closure assumptions recorded in historical P0/audit text;
- `Cable 1 -> N room-local CableRuns`;
- `CableRun 1:1 private CableRoute` as final architecture;
- autonomous ELV3 CableDefinition catalog/version lifecycle;
- automatic `circuitId -> cableId` migration;
- generic `transitionRef` without typed transition topology;
- generic open-ended `PathwayContext.spatialHost/reference`;
- inferred bend radius from point/polyline geometry;
- mutable current rows as source-of-truth for FROZEN revisions;
- one table serving both immutable resource-selection history and temporary consuming claims;
- implicit/latest P5 compatibility-profile selection or hidden profile precedence.

## 4. Frozen implementation decisions

The following are not implementation choices:

```text
Cable definition provenance
  = CableDefinitionRef(catalogId, catalogVersion, definitionCode, contentHash)
  hash = SHA-256 over versioned canonical UTF-8 JSON

ELV2 P1 wire extension
  = retain existing `profiles`
  + optional `cableDefinitions`
  P5 later adds `physicalCompatibilityProfiles`

CableDefinition semantics
  = exact C7 field contract aligned with ELV2 cable/reference catalogs

CableAllocation lifecycle
  = DRAFT -> RESERVED -> ACTIVE -> RELEASED -> ARCHIVED
  plus DRAFT->ARCHIVED and RESERVED->RELEASED only

Resource persistence
  = immutable CableAllocationResourceSelections evidence
  + temporary CableResourceClaims for RESERVED/ACTIVE

Multi-cable continuous connection
  = NOT SUPPORTED in ELV3 P1-P9

Routing
  = existing/evolved CableRoute/Node/Segment graph
  + CableRunTraversal
  + zero-length interface RouteHandoff

Bend radius
  = explicit RouteBendEvidence only

Design revision
  = ProjectDesignRevision.id != Projects.revision
  FROZEN source-of-truth = immutable embedded DesignRevisionPhysicalSnapshot
  revision-scoped writes require WORKING

Pathway hosting
  = sealed host hierarchy + acyclic parent containment

P5 technical profiles
  = one explicit ACTIVE ProjectPhysicalCompatibilityProfileSet
  containing exact PhysicalCompatibilityProfile refs
  no latest lookup / no hidden precedence

P6
  = exact length/area formulas
  + occupancy per routeSegment/carrier/compartment
  + factual segregation/congestion evidence only
```

## 5. Frozen canonical persistence names

P2:

```text
CableAllocationResourceSelections
CableResourceClaims
```

P3:

```text
ProjectDesignRevisions
DesignRevisionPhysicalSnapshots
CanonicalCableRuns
CableRunTraversals
RouteHandoffs
RouteBendEvidence
LegacyRouteAdoptions
```

P5:

```text
ProjectPhysicalCompatibilityProfileSets
ProjectPhysicalCompatibilityProfileRefs
```

Existing legacy routing tables remain coexistence inputs.

## 6. Remaining implementation freedom

May vary without changing architecture:

- Dart source-file boundaries;
- private helper names;
- Drift schema-version integer assigned by migration order;
- equivalent SQL shape that proves required atomic behavior;
- widget composition inside the specified workflow;
- test-helper organization;
- non-semantic indexes/materialized projections.

No other domain, identity, cardinality, lifecycle, ownership, historical-evidence or persistence relationship may be selected ad hoc.

## 7. Execution authorization

Authoritative readiness evidence:

`docs/audit/elv3-p1-p9-third-adversarial-audit.md`

Result:

```text
open BLOCKER specification findings = 0
open HIGH specification findings    = 0
P1 implementation                   = AUTHORIZED
ELV3 master specification           = READY FOR EXECUTION
```

This authorizes P1 implementation only. P2 may start only after P1 earns its own exact-SHA implementation gate, and the same rule applies sequentially through P9.
