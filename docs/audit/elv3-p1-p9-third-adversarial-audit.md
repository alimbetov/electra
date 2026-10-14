# Electra — ELV3 P1-P9 Third Adversarial Readiness Audit

Status: THIRD ADVERSARIAL SPEC AUDIT / PASS  
Branch: `feat/flutter-elv3-physical-routing-design`  
Authority index: `docs/product/elv3-authoritative-spec-index.md`  
R2 remediation: `docs/product/elv3-r2-final-readiness-remediation.md`  
R2 clarifications: `docs/product/elv3-r2-execution-clarifications.md`

## 1. Objective

Re-audit P1 through P9 after the second technical audit reopened readiness. This audit attempts to falsify implementation readiness: find any remaining domain, identity, persistence, lifecycle, historical-evidence, calculation or process decision that two independent implementation teams could resolve incompatibly.

Pass criterion:

```text
open BLOCKER specification findings = 0
open HIGH specification findings    = 0
```

Runtime correctness is not claimed; it must be proved phase-by-phase by exact-SHA implementation gates.

## 2. Sources checked

- current ELV1 EngineeringConnection/Port topology and persistence;
- current ELV2 `EngineeringReferenceCatalog`, component-only binding API and immutable catalog import behavior;
- `canonicalEngineeringJson` dependency/fingerprint infrastructure;
- current Drift routing tables (`CableRuns`, `CableRoutes`, nodes, segments, channels, floor handoffs);
- current `CableRouteValidator` polyline/transition geometry;
- `docs/product/elv-reference-data-catalogs.md` cable/reference governance;
- ADR-004 routing graph;
- ADR-014 field/as-built lifecycle;
- ADR-029 route reuse;
- ADR-030 ProjectDesignRevision;
- P0 remediation;
- PRE-P1 hardening;
- v2 implementation specification;
- R2 remediation and final execution clarifications.

## 3. Second-audit findings closure

| Finding | Severity | R2 resolution | State |
|---|---:|---|---|
| FROZEN revision depended on mutable current rows | BLOCKER | immutable embedded `DesignRevisionPhysicalSnapshot` + write guard | CLOSED |
| bend radius impossible from point/polyline geometry | BLOCKER | explicit `RouteBendEvidence`; missing evidence => UNRESOLVED/BLOCKED | CLOSED |
| resource atom/composite ambiguity | HIGH | finite acyclic resource graph + exact atomic resolver | CLOSED |
| termination completeness undefined | HIGH | definition-owned `TerminationPolicy` | CLOSED |
| reusable route handoff undefined | HIGH | run-independent `RouteHandoff` with interface evidence | CLOSED |
| ProjectDesignRevision process commands missing | HIGH | bootstrap/freeze/new-working/supersede/archive commands frozen | CLOSED |
| CableDefinition hash unspecified | HIGH | canonical UTF-8 JSON + version marker + SHA-256 | CLOSED |
| P1 leaked P5 catalog payload | HIGH | P1 adds only `cableDefinitions`; P5 adds physical profiles later | CLOSED |
| P3 canonical table wording contradicted authority index | HIGH | exact P3 names frozen by R2 | CLOSED |
| P6 length/fill formulas under-specified | HIGH | exact length/area equations + per-segment occupancy key | CLOSED |
| PathwayContext parent cycles/compatibility undefined | MEDIUM/HIGH | project-local acyclic containment + parent matrix | CLOSED |
| P8 failure injection outcomes not executable | HIGH | deterministic command/failure/post-rollback matrix | CLOSED |

Additional integration findings:

| Finding | Severity | Resolution | State |
|---|---:|---|---|
| released allocation could lose historical resource selection | HIGH | immutable `CableAllocationResourceSelections` separate from temporary `CableResourceClaims` | CLOSED |
| P5 profile selection could depend on implicit catalog choice/precedence | HIGH | one explicit ACTIVE `ProjectPhysicalCompatibilityProfileSet` with exact refs and deterministic combination | CLOSED |
| snapshot hash representation not frozen | HIGH | versioned canonical snapshot wire/hash contract | CLOSED |
| CableDefinition still allowed opaque construction/environment semantics | HIGH | exact C7 semantic shape aligned to ELV2 reference catalogs | CLOSED |

## 4. P1 audit — Cable identity + exact CableDefinitionRef + ELV2 extension

Result: **PASS / AUTHORIZED AFTER THIS AUDIT**.

Deterministic decisions now include:

- existing `EngineeringReferenceCatalogs` remains the only catalog lifecycle;
- existing persisted `profiles` JSON field remains backward-compatible;
- P1 adds `cableDefinitions` only;
- `CableDefinition` has a fixed semantic field contract and canonical ELV2 reference codes;
- `CableDefinitionRef = catalogId + catalogVersion + definitionCode + definitionContentHash`;
- content hash uses `electra.cable-definition.v1`, canonical JSON, UTF-8 and SHA-256;
- Cable row persistence fields are explicit;
- no `ComponentReferenceBinding` misuse;
- catalog edition immutability is compatible with current repository behavior;
- no P2/P3/P5 canonical persistence leaks into P1.

Two independent implementations cannot choose different Cable definition identity/version semantics while conforming to the authority set.

## 5. P2 audit — allocation + atomic claims + A/B terminations

Result: **PASS AT SPEC LEVEL**.

Closed semantics:

```text
DRAFT -> RESERVED -> ACTIVE -> RELEASED -> ARCHIVED
```

Resource model:

```text
CableResourceDefinition graph
  -> typed selection
  -> deterministic atomic set
```

Persistence responsibilities are separated:

```text
CableAllocationResourceSelections = immutable historical evidence
CableResourceClaims                = temporary RESERVED/ACTIVE exclusivity rows
CableTerminationMappings           = persistent termination evidence
```

Termination completeness is definition-driven (`BOTH_ENDS`, one-ended, optional, group-level). WHOLE_CABLE does not create a fake terminal resource. Selection is immutable after RESERVE. Release removes claims but not evidence.

Concurrency implementation may use equivalent SQL/SQLite mechanics, but required observable behavior is singular: overlapping claims cannot both commit.

## 6. P3 audit — design revision + run/traversal + route reuse + legacy coexistence

Result: **PASS AT SPEC LEVEL**.

Identity and history:

```text
ProjectDesignRevision.id != Projects.revision
WORKING only is mutable
FROZEN -> immutable DesignRevisionPhysicalSnapshot
```

The snapshot embeds mutable route/carrier/pathway facts, not just references, so later edits do not rewrite frozen history. Snapshot integrity is content-addressed by a versioned SHA-256 wire contract.

Routing remains one kernel:

```text
existing/evolved CableRoute/Node/Segment
  <- CableRunTraversal
```

Continuity is same route node or canonical `RouteHandoff`. Handoff is zero-length interface continuity; measurable path spans must be route segments. Exact new table names are frozen. Legacy electrical `CableRuns(circuitId, routeId)` remains operational until explicit adoption.

ProjectDesignRevision commands and one-WORKING concurrency semantics are explicit.

## 7. P4 audit — sealed PathwayContext + carrier + compartments

Result: **PASS AT SPEC LEVEL**.

- carrier construction and spatial context remain separate;
- closed host hierarchy eliminates generic spatial JSON identity;
- kind-to-host mapping is fixed;
- parent containment is same-project, acyclic and restricted by parent matrix;
- vertical contexts are not fake room ownership;
- compartments remain carrier children and traversal target must belong to same carrier.

No BLOCKER/HIGH ambiguity remains.

## 8. P5 audit — technical physical compatibility

Result: **PASS AT SPEC LEVEL**.

Profile ownership is deterministic:

```text
one ACTIVE ProjectPhysicalCompatibilityProfileSet
  -> exact immutable PhysicalCompatibilityProfile refs
```

No latest lookup or hidden profile precedence exists. Profile combination uses typed intersection/max-min semantics and conflicts produce `UNRESOLVED_PROFILE_CONFLICT`.

Bend-radius check now has physically supportable inputs:

```text
CableDefinition.minimumBendRadiusMm
+ RouteBendEvidence.radiusMm
```

Missing evidence is UNRESOLVED/BLOCKED, never inferred from a polyline vertex.

P5 remains intrinsic/factual; ELV7 owns jurisdictional thresholds/compliance.

## 9. P6 audit — physical calculations/evidence

Result: **PASS AT SPEC LEVEL**.

Exact formulas are frozen:

```text
installedLengthMm = geometricTraversalLengthMm * (1 + reservePercent/100)
                    + terminationAllowanceMm

circularOccupiedAreaMm2 = PI * outerDiameterMm^2 / 4
```

Handoffs contribute zero length. Non-circular cable requires explicit occupied area. Occupancy source-of-truth is per:

```text
(routeSegmentId, carrierId, compartmentId?)
```

One Cable contributes once regardless of allocation count. Congestion and segregation outputs are factual evidence, not normative acceptance.

Calculation fingerprints/revisions can use the project's existing canonical JSON/dependency model without inventing new dependency semantics.

## 10. P7 audit — engineer Physical Routing workspace

Result: **PASS WITH PHASE DEPENDENCIES**.

Workflow remains singular and command-driven:

```text
Connection -> Cable -> Allocation -> Termination -> Run/Traversal
           -> Carrier/Pathway -> Findings/Calculations
```

Widgets cannot bypass command transactions. Frozen revision is view-only; edits require current WORKING revision. Per-discipline duplicate routing editors remain prohibited.

No new architecture choice is required in P7.

## 11. P8 audit — restart/rollback/idempotency verticals

Result: **PASS AT SPEC LEVEL**.

Five mandatory fixtures remain CCTV/LAN/ACS/Fire/Fiber. R2 supplies exact failure points and expected post-rollback states, including database reopen verification.

Historical checks now cover:

- released allocation selection evidence;
- snapshot hash verification;
- frozen revision reconstruction independent from current rows;
- lost-response retry with same commandId;
- same commandId/different payload conflict;
- legacy routing regression.

## 12. P9 audit — architecture-vs-code / exact-SHA closure

Result: **PASS AS FINAL GATE CONTRACT**.

P9 rejection list remains valid and R2 adds explicit evidence for:

- no mutable-row reconstruction of FROZEN revision;
- no inferred bend radius;
- no selection-history loss on release;
- no hidden P5 profile precedence/latest lookup;
- exact canonical table ownership.

Final implementation still requires exact-SHA CI; this audit does not substitute for runtime evidence.

## 13. Cross-project consistency

PASS.

The final contracts preserve:

```text
ELV1 logical topology
ELV2 exact/versioned engineering reference semantics
ELV3 physical realization and intrinsic evidence
ELV4 power graph
ELV5 discipline calculations
ELV6 enclosure/rack physical layout
ELV7 normative/jurisdictional compliance
ELV8 manufacturer/BOM/deliverables
```

ADR-014 as-built traceability is improved by immutable frozen physical snapshots. Existing electrical routing remains isolated during coexistence.

## 14. Remaining non-blocking implementation freedom

Only non-semantic choices remain, including:

- Dart file/private helper organization;
- Drift migration integer;
- equivalent SQL transaction/index implementation proving required behavior;
- widget composition within frozen workflow;
- test-helper organization;
- performance indexes/caches/materialized projections that do not alter source-of-truth.

Repository branch protection is currently not itself part of the domain specification; P1-P9 must enforce exact-SHA gates through workflow evidence, and repository rules may be strengthened separately.

## 15. Final verdict

```text
canonical ELV3 architecture                    PASS
P1 exact Cable identity/reference              PASS
P2 allocation/resource/termination contract    PASS
P3 history/routing/coexistence contract         PASS
P4 pathway/carrier contract                     PASS
P5 technical compatibility contract             PASS
P6 calculation/evidence contract                PASS
P7 application workflow contract                PASS
P8 restart/failure/idempotency contract         PASS
P9 final gate contract                          PASS

open BLOCKER specification findings             0
open HIGH specification findings                0

P1 implementation                               AUTHORIZED
ELV3 master specification                       READY FOR EXECUTION
```

`READY FOR EXECUTION` means the specification is sufficiently deterministic to begin P1. It does not claim that P1-P9 code already exists or is correct. Each phase must earn its own exact-SHA implementation gate before the next begins.
