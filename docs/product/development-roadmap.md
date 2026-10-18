# Electra — Development roadmap

The detailed scope and evidence live in [Flutter delivery plan](flutter-delivery-plan.md).
Electrical delivery branch: `feat/flutter-routing-cablerun`.
Current ELV design branch: `feat/flutter-elv5-power-topology-design`.
Accepted ELV1/ELV2 baseline: `main@786a28ac6e4b532b1e7ac2083502799935ca51ed`.
Accepted ELV4 merged baseline (and therefore completed ELV1–ELV3 prerequisites): `main@d2b059d4c11a284cdd32965140f6df3c40020c8d`.
Delivery is incremental: each accepted baseline has an exact-commit Flutter/core CI gate.

> Current-stage status is governed by the tables and active authoritative indexes below. Older ELV3 runtime-closure narrative retained later in this file is historical closure evidence and must not be interpreted as saying ELV4 is still blocked.

| Milestone | Outcome | Status |
|---|---|---|
| FL0–2 | Flutter, SQLite, project/floor/room hierarchy | Implemented foundation |
| FL3–6 | Geometry kernel, room editor, surface navigation, component placement | Baseline closed |
| FL7–8 | Explicit electrical loads, circuits and design current | Baseline closed |
| FL9–11 | Surface routes, CableRun, junctions and floor topology | Baseline closed |
| FL12–13 | Dependency recalculation, protection requirements and normative catalog | Baseline closed |
| FL14 | Manufacturer catalogs, strict matching and preserved SKU selections | Baseline closed |
| FL15 | Generate panel structure from consumption groups; incoming protection, phase/reserve proposal | Baseline closed |
| FL16 | Enclosure and DIN-row layout, terminals/ducts/zones, module/mm capacity checks | Next |
| FL17 | Traceable BOM by project/floor/room/system and manufacturer mapping | Planned |
| FL18 | Versioned price books and labor/material estimates | Planned |
| FL19 | Offline PDF reports: drawings, schedules, BOM/estimate and engineering evidence | Planned |
| FL20 | Offline installation, deviations/as-built, tests and commissioning evidence | Planned |

## ELV extension track

| Stage | Outcome | Status |
|---|---|---|
| ELV0 | Systems, sixteen family editions, shared device participation | Baseline closed |
| ELV1 | Ports, connections, topology, passive mappings and assemblies | CLOSED / ACCEPTED |
| ELV2 | Canonical discipline profiles, versioned catalogs, placement and explicit adoption | CLOSED / ACCEPTED |
| ELV3 | Cable resources, allocation/termination, revision-scoped cable runs, reusable routing/carriers/pathways, physical compatibility and runtime evidence | CLOSED / ACCEPTED prerequisite inherited by merged ELV4 |
| ELV4 | Power, PoE, PSU, UPS, converters and backup graph | CLOSED / ACCEPTED |
| ELV5 | Versioned CCTV/LAN/ACS/fire calculations | DESIGN HARDENED / RUNTIME NOT STARTED |
| ELV6 | Racks, cabinets, patching and physical capacity | DESIGN HARDENED / RUNTIME NOT STARTED / ELV5 RECONCILIATION REQUIRED BEFORE RUNTIME |
| ELV7 | Jurisdiction profiles, normative rule packs and findings | DESIGN DRAFT / RUNTIME NOT STARTED / TRANSITIVE RECONCILIATION REQUIRED |
| ELV8 | Manufacturer selection, snapshots, BOM and deliverables | DESIGN DRAFT / RUNTIME NOT STARTED / TRANSITIVE RECONCILIATION REQUIRED |

ELV5 current execution authority is `docs/product/elv5-authoritative-spec-index.md`. ELV6–ELV8 design branches may continue as design work, but downstream runtime entry must reconcile to the exact accepted ELV5 source SHA, authority fingerprint and runtime evidence through `docs/product/elv5-implementation/downstream-handoff-registry.json`.

## Historical ELV3 runtime-closure record

The remainder of this ELV3 section records the closure program that preceded accepted ELV4. It is retained for provenance. Its historical labels such as `ELV4 BLOCKED` are superseded by the current ELV extension-track table and the accepted ELV4 merge at `main@d2b059d4c11a284cdd32965140f6df3c40020c8d`.

ELV3 architecture/process specification remained accepted after P0, R2 and dual-review hardening. General code readiness was later reopened by CR-01..CR-16, then restored after remediation and re-review. A subsequent dedicated P2-P5 implementation review found and closed additional phase-local ambiguities in allocation claims/terminations, route project/handoff semantics, carrier lifecycle/dependencies and compatibility-profile applicability/combination.

The historical merged ELV3 baseline contained real P1/P2 persistence plus P3-P8 domain/application foundations, and runtime closure was made an explicit delivery phase rather than implicit follow-up work.

### ELV3 runtime-closure authority

Authority order used for that closure phase:

```text
ELV3 architecture/process authority
  ↓
ELV3 code-level contracts P1-P9
  ↓
docs/product/elv3-runtime-closure-rcr0-remediation.md
  ↓
docs/product/elv3-runtime-closure-specification.md
  ↓
docs/product/elv3-runtime-closure-delivery-plan.md
  ↓
implementation
```

Runtime-closure documents:

- `docs/product/elv3-runtime-closure-rcr0-remediation.md` — authoritative RCR-0 amendment closing RC-A01…RC-A07 and overriding conflicting Runtime Closure wording;
- `docs/audit/elv3-runtime-closure-rcr0-rereview.md` — post-remediation re-review: APPROVED / READY FOR RC0;
- `docs/product/elv3-runtime-closure-specification.md` — execution specification for P3-P9 runtime closure subject to RCR-0 precedence;
- `docs/product/elv3-runtime-closure-delivery-plan.md` — ordered RC0-RC9 execution and exact-SHA gates subject to RCR-0 precedence;
- `docs/audit/elv3-implementation-inventory.md` — source-reality inventory used as the starting closure baseline;
- `docs/product/elv3-code-contract-p7-p9.md` — accepted workspace/restart/final-audit contract reused by closure.

Architecture/process authority remained:

- `docs/product/elv3-authoritative-spec-index.md`;
- `docs/product/elv3-dual-review-process-hardening.md`;
- `docs/product/elv3-r2-execution-clarifications.md`;
- `docs/product/elv3-r2-final-readiness-remediation.md`.

Code implementation authority used during closure:

- `docs/product/elv3-code-implementation-index.md`;
- `docs/product/elv3-code-p2-p5-hardening.md`;
- `docs/product/elv3-code-remediation-final-clarifications.md`;
- `docs/product/elv3-code-implementation-remediation-cr01-cr16.md`;
- `docs/product/elv3-code-contract-p1-p3.md`;
- `docs/product/elv3-code-contract-p4-p6.md`;
- `docs/product/elv3-code-contract-p7-p9.md`.

Historical design/code/runtime-closure readiness evidence:

- `docs/audit/elv3-code-implementation-technical-rereview.md` — general design/code readiness PASS;
- `docs/audit/elv3-p2-p5-code-technical-review.md` — dedicated P2-P5 PASS;
- `docs/audit/elv3-implementation-inventory.md` — runtime source reality and closure gaps at that point;
- `docs/audit/elv3-runtime-closure-rcr0-rereview.md` — Runtime Closure consistency PASS and RC0 authorization.

Historical finding evidence remains provenance and does not override later accepted ELV4/ELV5 authority.

Dedicated P2-P5 hardening froze:

```text
P2
  claim uniqueness = (cableId, atomic resource)
  WHOLE_CABLE expands to all atomic descendants
  claim resolution != termination-obligation resolution
  exact allocation mutation lifecycle
  final-allocation release blocked by current active run
  topology endpoint dependency inspector

P3
  route project = CableRoute.room -> Room.floor -> Floor.project
  RouteHandoff = exact world interface OR typed adjacency, no arbitrary tolerance
  exact CableRouteGeometryCandidate for shared edits
  run/allocation reverse dependency preserved

P4
  PathwayContext / PhysicalCarrier / compartment canonical roots are project-owned physical facts
  exact ACTIVE->ARCHIVED lifecycle for context/carrier/compartment
  typed host foreign keys; no generic hostKind+hostId authority
  traversal carrier relation has one source of truth; no duplicate assignment aggregate
  transaction-bound host/project ownership validation
  archive dependency guards
  factual compartment-area aggregate capacity

P5
  exact PhysicalCompatibilityProfile shape
  exact canonical tables ProjectPhysicalCompatibilityProfileSets / ProjectPhysicalCompatibilityProfileRefs
  findings persisted as revision-scoped ProjectDerivedResults, not a second canonical finding table
  typed selector applicability
  exact v1 rule semantics
  deterministic order-independent combiner
  engine version elv.physical-compatibility.v1
  stable status order FORBIDDEN->UNRESOLVED->WARNING->OK
  profile-set mutations require WORKING design revision

P6
  ELV-ROUTE-01..06 persisted through revision-scoped ProjectDerivedResults by default
  new process-specific result tables require a prior audited exception
```

Canonical historical ELV3 implementation/runtime-closure sequence was:

```text
P1 Cable identity / exact ELV2 reference / resource definitions                 MERGED
  ↓
P2 allocation / resource selection / atomic claims / terminations                MERGED
  ↓
RCR-0 project-consistency remediation                                             CLOSED / APPROVED
  ↓
RC0 baseline inventory + executable audit
  ↓
RC1 P3 canonical schema/repositories
  ↓ exact-SHA A
RC2 P3 design-revision/freeze/reroute runtime verticals
  ↓ exact-SHA B
RC3 P4 project-owned pathway/carrier/compartment runtime
  ↓ exact-SHA
RC4 P5 exact profile-set persistence + ProjectDerivedResults findings
  ↓ exact-SHA
RC5 P6 revision-scoped calculations/evidence via ProjectDerivedResults
  ↓ exact-SHA
RC6 P7 concrete workspace/trace/history
  ↓ exact-SHA
RC7 five real SQLite discipline verticals
  ↓
RC8 rollback/idempotency/frozen-history matrix
  ↓ exact-SHA
RC9 architecture-vs-runtime final audit
  ↓
ELV3 CLOSED / ACCEPTED
  ↓
ELV4 implementation AUTHORIZED
```

The old interim authorization snapshot that showed `ELV4 implementation BLOCKED` is superseded. Current project state is the table above: ELV4 is CLOSED / ACCEPTED and ELV5 is DESIGN HARDENED / RUNTIME NOT STARTED.

All four discipline fixtures plus a fiber fixture remain useful regression requirements inherited from ELV3. National rule packs remain ELV7 concerns with verified provenance.

## Validation at FL15

Engineering implementation gate: `af08e7bba4094bd96b5650fafc175cc7e2deddaf`.
58 mobile tests and 102 pure-Dart core tests; format, Drift generation and analyzers passed.
Final branch-head commits are checked by the same CI workflow.
