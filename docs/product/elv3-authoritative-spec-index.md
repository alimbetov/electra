# Electra — ELV3 Authoritative Specification Index

Status: EXECUTION AUTHORITY / DUAL-REVIEW + CODE-LEVEL HARDENED / READY FOR EXECUTION  
Branch: `feat/flutter-elv3-physical-routing-design`

## 1. Purpose

This index removes document-precedence ambiguity before ELV3 implementation starts.

Architecture and process meaning are governed by the authority chain below. Once coding starts, developers MUST additionally enter through `docs/product/elv3-code-implementation-index.md`, which translates that meaning into code-level types, files, repository ports, Drift ownership, transactions and tests.

## 2. Architecture/process authority order

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

## 3. Code implementation authority

Implementation entry point:

```text
docs/product/elv3-code-implementation-index.md
```

Code-level authority order:

1. `docs/product/elv3-code-contract-p1-p3.md`;
2. `docs/product/elv3-code-contract-p4-p6.md`;
3. `docs/product/elv3-code-contract-p7-p9.md`;
4. architecture/process authority above.

The code contracts freeze public type names, intended source locations, repository interfaces, canonical table ownership, transaction pseudocode, failure probes and mandatory test locations. They may refine implementation shape but MUST NOT override architecture/domain meaning.

Code-level readiness evidence:

```text
docs/audit/elv3-code-level-readiness-audit.md
```

## 4. Explicitly superseded implementation sources/wording

Do not implement from:

- `docs/product/elv3-implementation-specification.md` — first implementation draft, redirect only;
- any older wording contradicted by dual-review/R2/code-level remediation;
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
- in-place CableDefinitionRef change after resource-selection evidence exists;
- widget-level multi-table domain writes;
- raw Drift/SQLite errors crossing the application boundary.

## 5. Frozen implementation decisions

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

## 6. Frozen canonical persistence names

P1:

```text
ElvCables
CommandExecutionRecords
```

P2:

```text
CableAllocations
CableAllocationResourceSelections
CableResourceClaims
CableTerminationMappings
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

P4:

```text
PathwayContexts
PhysicalCarriers
PhysicalCarrierCompartments
```

P5:

```text
ProjectPhysicalCompatibilityProfileSets
ProjectPhysicalCompatibilityProfileRefs
```

Existing legacy routing tables remain coexistence inputs. P6 reuses revision-scoped derived-result persistence unless an implementation audit proves a non-semantic storage adaptation is required.

## 7. Mandatory process-contract evidence

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
Implementation file
Test file
```

P9 audits this matrix against the implemented commands.

## 8. Remaining implementation freedom

May vary without changing architecture:

- private Dart source-file splitting/helper names;
- Drift schema-version integer assigned by migration order;
- equivalent SQL shape that proves required atomic behavior;
- widget composition inside the specified workflow;
- test-helper organization;
- non-semantic indexes/materialized projections.

Public domain contracts, canonical persistence ownership, command/state semantics and historical-evidence rules cannot be changed ad hoc. Any required semantic deviation reopens architecture review.

## 9. Execution authorization

Latest specification evidence:

1. `docs/audit/elv3-macro-architecture-consistency-audit.md` — Architect A PASS.
2. `docs/audit/elv3-process-flow-consistency-audit.md` — Architect B PASS.
3. `docs/audit/elv3-dual-review-reconciliation-audit.md` — macro/process reconciliation PASS.
4. `docs/audit/elv3-code-level-readiness-audit.md` — code design PASS.

Result:

```text
Architect A macro consistency              PASS
Architect B process flow                    PASS
Developer A/B compatibility                PASS
Code-level layer/type/schema contract      PASS
open BLOCKER specification/code findings   0
open HIGH specification/code findings      0
P1 code implementation                     AUTHORIZED
ELV3 master/code specification             READY FOR EXECUTION
```

This authorizes P1 implementation only. P2 may start only after P1 earns its own exact-SHA implementation gate, and the same rule applies sequentially through P9.