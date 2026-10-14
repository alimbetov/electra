# Electra — ELV3 Authoritative Specification Index

Status: EXECUTION AUTHORITY / DUAL-REVIEW HARDENED / READY FOR EXECUTION  
Branch: `feat/flutter-elv3-physical-routing-design`

## 1. Purpose

This index removes document-precedence ambiguity before ELV3 implementation starts.

Implementation teams MUST use the documents below in this order. Historical files may remain for audit evidence but cannot override this set.

## 2. Authority order

1. `docs/product/elv3-dual-review-process-hardening.md` — final macro/process hardening: revision materialization, shared-infrastructure mutation boundaries, WORKING context, command ledger, undo/redo and deterministic flow.
2. `docs/product/elv3-r2-execution-clarifications.md` — frozen write guards, handoffs, selection history, exact hashes, CableDefinition semantics and P5 profile-set semantics.
3. `docs/product/elv3-r2-final-readiness-remediation.md` — authoritative closure of the second technical audit.
4. `docs/product/elv3-implementation-specification-v2.md` — executable P1-P9 contract where not superseded by items 1-3.
5. `docs/product/elv3-pre-p1-final-hardening.md` — F1-F7 closure where consistent with later hardening.
6. `docs/adr/ADR-029-elv3-reusable-route-traversal.md` — one routing evolution decision.
7. `docs/adr/ADR-030-project-design-revision-identity.md` — stable design revision identity.
8. `docs/product/elv3-p0-system-architecture-remediation.md` — system architecture meaning.
9. Remediated P0.1-P0.9 documents — supporting detail only where consistent with 1-8.

If wording conflicts, the earlier item wins.

## 3. Explicitly superseded implementation sources/wording

Do not implement from:

- `docs/product/elv3-implementation-specification.md` — first implementation draft, redirect only;
- any older wording contradicted by dual-review/R2 remediation;
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
- implicit/latest P5 compatibility-profile selection or hidden profile precedence;
- empty/lazy/implementation-selected inheritance for a new WORKING design revision;
- route-geometry mutation hidden inside `RerouteCableRun`;
- project-level derived-result keys that omit design revision scope;
- in-memory-only command idempotency;
- ordinary undo of frozen/migration/history evidence;
- in-place CableDefinitionRef change after resource-selection evidence exists.

## 4. Frozen implementation decisions

The following are not implementation choices:

```text
Cable definition provenance
  = CableDefinitionRef(catalogId, catalogVersion, definitionCode, contentHash)
  hash = SHA-256 over versioned canonical UTF-8 JSON
  immutable after resource-selection evidence or canonical run exists

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

Termination replacement
  = complete set-atomic replacement for RESERVED/ACTIVE allocations

Multi-cable continuous connection
  = NOT SUPPORTED in ELV3 P1-P9

Routing
  = existing/evolved CableRoute/Node/Segment graph
  + CableRunTraversal
  + zero-length interface RouteHandoff
  RerouteCableRun changes traversal only
  shared geometry edit is a separate impact-aware command

Bend radius
  = explicit RouteBendEvidence only

Design revision
  = ProjectDesignRevision.id != Projects.revision
  FROZEN source-of-truth = immutable embedded DesignRevisionPhysicalSnapshot
  revision-scoped writes require WORKING
  next WORKING = deterministic materialization from verified base snapshot

Physical write context after P3
  = exactly one WORKING revision required
  no writes in post-freeze/pre-next-working gap

Snapshot evolution
  = versioned by installed phase; historical snapshots never backfilled from current rows

Derived results
  = design-revision-scoped node identity

Pathway hosting
  = sealed host hierarchy + acyclic parent containment

P5 technical profiles
  = one explicit ACTIVE ProjectPhysicalCompatibilityProfileSet
  containing exact PhysicalCompatibilityProfile refs
  no latest lookup / no hidden precedence

Command idempotency
  = persisted key (projectId, commandId)
  + canonical payload hash + committed logical outcome

Undo/redo
  = explicit reversible versus irreversible command classes

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

## 6. Mandatory process-contract evidence

Every P1-P8 implementation phase MUST maintain a command-contract matrix containing:

```text
Command
Input identity / expected revisions
Required state
Read set
Validation set
Write set
State transition
Affected dependency keys
Idempotency behavior
Rollback postcondition
Undo class
Restart assertion
Error codes
```

P9 audits this matrix against the implemented commands.

## 7. Remaining implementation freedom

May vary without changing architecture:

- Dart source-file boundaries;
- private helper names;
- Drift schema-version integer assigned by migration order;
- equivalent SQL shape that proves required atomic behavior;
- widget composition inside the specified workflow;
- test-helper organization;
- non-semantic indexes/materialized projections.

No other domain, identity, cardinality, lifecycle, ownership, historical-evidence, command-result or persistence relationship may be selected ad hoc.

## 8. Execution authorization

Latest readiness evidence:

1. `docs/audit/elv3-macro-architecture-consistency-audit.md` — Architect A PASS.
2. `docs/audit/elv3-process-flow-consistency-audit.md` — Architect B PASS.
3. `docs/audit/elv3-dual-review-reconciliation-audit.md` — final reconciliation PASS.

The earlier third adversarial audit remains useful historical evidence but is superseded as the latest authorization by the dual-review reconciliation.

Result:

```text
Architect A macro consistency              PASS
Architect B process flow                    PASS
Developer A/B compatibility                PASS
open BLOCKER specification findings        0
open HIGH specification findings           0
P1 implementation                          AUTHORIZED
ELV3 master specification                  READY FOR EXECUTION
```

This authorizes P1 implementation only. P2 may start only after P1 earns its own exact-SHA implementation gate, and the same rule applies sequentially through P9.
