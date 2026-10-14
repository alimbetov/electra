# Electra — Development roadmap

The detailed scope and evidence live in [Flutter delivery plan](flutter-delivery-plan.md).
Electrical delivery branch: `feat/flutter-routing-cablerun`.
Current ELV design branch: `feat/flutter-elv3-physical-routing-design`.
Accepted ELV1/ELV2 baseline: `main@786a28ac6e4b532b1e7ac2083502799935ca51ed`.
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
| ELV3 | Cable resources, allocation/termination, cable-run traversal, reusable routing/carriers/pathways and physical compatibility | CODE REMEDIATION CLOSED / P2-P5 HARDENED / P1 CODE AUTHORIZED |
| ELV4 | Power, PoE, PSU, UPS, converters and backup graph | Planned |
| ELV5 | Versioned CCTV/LAN/ACS/fire calculations | Planned |
| ELV6 | Racks, cabinets, patching and physical capacity | Planned |
| ELV7 | Jurisdiction profiles, normative rule packs and findings | Planned |
| ELV8 | Manufacturer selection, snapshots, BOM and deliverables | Planned |

ELV3 architecture/process specification remains accepted after P0, R2 and dual-review hardening. General code readiness was later reopened by CR-01..CR-16, then restored after remediation and re-review. A subsequent dedicated P2-P5 implementation review found and closed additional phase-local ambiguities in allocation claims/terminations, route project/handoff semantics, carrier lifecycle/dependencies and compatibility-profile applicability/combination.

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

Latest code readiness evidence:

- `docs/audit/elv3-code-implementation-technical-rereview.md` — general PASS;
- `docs/audit/elv3-p2-p5-code-technical-review.md` — dedicated P2-P5 PASS.

Historical finding evidence remains in the earlier code technical review/audits and does not override the current hardened authority set.

Dedicated P2-P5 hardening now freezes:

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

Canonical implementation sequence remains:

```text
P1 Cable identity / CableDefinitionRef / P1 resource-definition types
  ↓ exact-SHA
P2 Allocation / runtime resource selection + atomic claims / terminations
  ↓ exact-SHA
P3 ProjectDesignRevision / frozen snapshot / revision fork / CanonicalCableRun / traversal / route coexistence
  ↓ exact-SHA
P4 sealed PathwayContext / typed PhysicalCarrier facts / compartments
  ↓ exact-SHA
P5 sealed physical-compatibility profile rules / exact project profile set
  ↓ exact-SHA
P6 revision-scoped calculations + persisted RouteSeparationEvidence
  ↓ exact-SHA
P7 Engineer Physical Routing workspace
  ↓ exact-SHA
P8 Restart / rollback / failure injection / persisted idempotency verticals
  ↓ exact-SHA
P9 Architecture-vs-code hard audit / command-matrix audit / final exact-SHA closure
```

Current authorization:

```text
P1 implementation      AUTHORIZED
P2 code specification  HARDENED / PASS
P3 code specification  HARDENED / PASS
P4 code specification  HARDENED / PASS
P5 code specification  HARDENED / PASS
```

Implementation authorization remains sequential: P2 starts only after P1 exact-SHA gate, P3 only after P2 gate, P4 only after P3 gate, and P5 only after P4 gate.

All four discipline fixtures plus a fiber fixture remain mandatory throughout the track. Legacy electrical routing regression is mandatory from P3 onward. National rule packs remain ELV7 concerns with verified provenance.

## Validation at FL15

Engineering implementation gate: `af08e7bba4094bd96b5650fafc175cc7e2deddaf`.
58 mobile tests and 102 pure-Dart core tests; format, Drift generation and analyzers passed.
Final branch-head commits are checked by the same CI workflow.
