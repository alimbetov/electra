# Electra — Development roadmap

The detailed scope and evidence live in [Flutter delivery plan](flutter-delivery-plan.md).
Electrical delivery branch: `feat/flutter-routing-cablerun`.
Current ELV runtime-closure branch: `feat/elv3-runtime-closure`.
Accepted ELV1/ELV2 baseline: `main@786a28ac6e4b532b1e7ac2083502799935ca51ed`.
ELV3 merged baseline: `main@5a139ed64585c0df8d52e4da270417453f93e2af`.
Delivery is incremental: each baseline has an exact-commit Flutter/core CI gate.

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
| ELV3 | Cable resources, allocation/termination, revision-scoped cable runs, reusable routing/carriers/pathways, physical compatibility and runtime evidence | RUNTIME CLOSURE P3-P9 IN PROGRESS |
| ELV4 | Power, PoE, PSU, UPS, converters and backup graph | BLOCKED until ELV3 closure |
| ELV5 | Versioned CCTV/LAN/ACS/fire calculations | Planned |
| ELV6 | Racks, cabinets, patching and physical capacity | Planned |
| ELV7 | Jurisdiction profiles, normative rule packs and findings | Planned |
| ELV8 | Manufacturer selection, snapshots, BOM and deliverables | Planned |

ELV3 architecture/process specification remains accepted after P0, R2 and dual-review hardening. General code readiness was later reopened by CR-01..CR-16, then restored after remediation and re-review. A subsequent dedicated P2-P5 implementation review found and closed additional phase-local ambiguities in allocation claims/terminations, route project/handoff semantics, carrier lifecycle/dependencies and compatibility-profile applicability/combination.

The merged ELV3 baseline contains real P1/P2 persistence plus P3-P8 domain/application foundations, but it is not yet a closed runtime vertical. Runtime closure is now an explicit delivery phase rather than implicit follow-up work.

### ELV3 runtime-closure authority

- `docs/product/elv3-runtime-closure-specification.md` — authoritative execution specification for P3-P9 runtime closure;
- `docs/product/elv3-runtime-closure-delivery-plan.md` — ordered RC0-RC9 execution and exact-SHA gates;
- `docs/audit/elv3-implementation-inventory.md` — source-reality inventory used as the starting closure baseline;
- `docs/product/elv3-code-contract-p7-p9.md` — accepted workspace/restart/final-audit contract reused by closure.

Architecture/process authority remains:

- `docs/product/elv3-authoritative-spec-index.md`;
- `docs/product/elv3-dual-review-process-hardening.md`;
- `docs/product/elv3-r2-execution-clarifications.md`;
- `docs/product/elv3-r2-final-readiness-remediation.md`.

Current code implementation authority:

- `docs/product/elv3-code-implementation-index.md`;
- `docs/product/elv3-code-p2-p5-hardening.md`;
- `docs/product/elv3-code-remediation-final-clarifications.md`;
- `docs/product/elv3-code-implementation-remediation-cr01-cr16.md`;
- `docs/product/elv3-code-contract-p1-p3.md`;
- `docs/product/elv3-code-contract-p4-p6.md`;
- `docs/product/elv3-code-contract-p7-p9.md`.

Latest design/code readiness evidence:

- `docs/audit/elv3-code-implementation-technical-rereview.md` — general design/code readiness PASS;
- `docs/audit/elv3-p2-p5-code-technical-review.md` — dedicated P2-P5 PASS;
- `docs/audit/elv3-implementation-inventory.md` — runtime source reality and open closure gaps.

Historical finding evidence remains in the earlier code technical review/audits and does not override the current hardened authority set.

Dedicated P2-P5 hardening freezes:

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
  exact ACTIVE->ARCHIVED lifecycle for context/carrier/compartment
  transaction-bound host/project ownership validation
  archive dependency guards
  factual compartment-area aggregate capacity

P5
  exact PhysicalCompatibilityProfile shape
  typed selector applicability
  exact v1 rule semantics
  deterministic order-independent combiner
  engine version elv.physical-compatibility.v1
  stable status order FORBIDDEN->UNRESOLVED->WARNING->OK
  profile-set mutations require WORKING design revision
```

Canonical ELV3 implementation/runtime-closure sequence is now:

```text
P1 Cable identity / exact ELV2 reference / resource definitions                 MERGED
  ↓
P2 allocation / resource selection / atomic claims / terminations                MERGED
  ↓
RC0 baseline inventory + executable audit
  ↓
RC1 P3 canonical schema/repositories
  ↓ exact-SHA
RC2 P3 design-revision/freeze/reroute runtime verticals
  ↓ exact-SHA
RC3 P4 pathway/carrier/compartment runtime
  ↓ exact-SHA
RC4 P5 profile-set/finding persistence
  ↓ exact-SHA
RC5 P6 revision-scoped calculations/evidence
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

Current runtime authorization:

```text
P1/P2 persisted runtime baseline           MERGED
P3-P6 domain/application contracts         PRESENT
P7 workspace/history foundation            PRESENT
P8 fixture/failure foundation              PRESENT
P3-P6 canonical DB verticals               OPEN
P7 concrete persisted adapters             OPEN
P8 five real DB restart verticals          OPEN
P9 final closure                           OPEN
ELV4 implementation                        BLOCKED
```

All four discipline fixtures plus a fiber fixture remain mandatory throughout runtime closure. Legacy electrical routing regression is mandatory from RC1 onward. National rule packs remain ELV7 concerns with verified provenance.

## Validation at FL15

Engineering implementation gate: `af08e7bba4094bd96b5650fafc175cc7e2deddaf`.
58 mobile tests and 102 pure-Dart core tests; format, Drift generation and analyzers passed.
Final branch-head commits are checked by the same CI workflow.
