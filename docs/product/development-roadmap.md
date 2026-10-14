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
| ELV3 | Cable resources, allocation/termination, cable-run traversal, reusable routing/carriers/pathways and physical compatibility | CODE REMEDIATION CLOSED / TECHNICAL RE-REVIEW PASS / P1 CODE AUTHORIZED |
| ELV4 | Power, PoE, PSU, UPS, converters and backup graph | Planned |
| ELV5 | Versioned CCTV/LAN/ACS/fire calculations | Planned |
| ELV6 | Racks, cabinets, patching and physical capacity | Planned |
| ELV7 | Jurisdiction profiles, normative rule packs and findings | Planned |
| ELV8 | Manufacturer selection, snapshots, BOM and deliverables | Planned |

ELV3 architecture/process specification remains accepted after P0, R2 and dual-review hardening. The code-implementation technical review later reopened readiness with CR-01..CR-16. Those findings are now closed by the authoritative code-remediation contracts, and a fresh implementation-level re-review reports zero open BLOCKER/HIGH code-design findings.

Architecture/process authority remains:

- `docs/product/elv3-authoritative-spec-index.md`;
- `docs/product/elv3-dual-review-process-hardening.md`;
- `docs/product/elv3-r2-execution-clarifications.md`;
- `docs/product/elv3-r2-final-readiness-remediation.md`.

Current code implementation authority:

- `docs/product/elv3-code-implementation-index.md`;
- `docs/product/elv3-code-remediation-final-clarifications.md`;
- `docs/product/elv3-code-implementation-remediation-cr01-cr16.md`;
- `docs/product/elv3-code-contract-p1-p3.md`;
- `docs/product/elv3-code-contract-p4-p6.md`;
- `docs/product/elv3-code-contract-p7-p9.md`.

Latest code readiness evidence:

- `docs/audit/elv3-code-implementation-technical-rereview.md` — PASS.

Historical finding evidence:

- `docs/audit/elv3-code-implementation-technical-review.md` — CR-01..CR-16 source review, superseded as authorization;
- `docs/audit/elv3-code-level-readiness-audit.md` — earlier historical PASS.

Closed code remediation set:

```text
CR-01 P1/P2 resource-definition ownership/compile order
CR-02 single command orchestration owner
CR-03 exact durable CommandExecutionRecords schema/codec
CR-04 DB-enforced partial unique invariants
CR-05 concrete phase-specific Drift write-unit-of-work strategy
CR-06 two-connection SQLite race tests
CR-07 shared route edit validates canonical + legacy electrical dependents
CR-08 pure snapshot assembler + transaction-bound coordinator
CR-09 typed carrier environment/installation facts
CR-10 exact P5 sealed compatibility-rule hierarchy
CR-11 persisted explicit P6 separation evidence
CR-12 DRAFT termination memory-only candidate
CR-13 CreateCableRun allocation prerequisite
CR-14 common ELV command result/failure envelope
CR-15 migration baseline schema 18→23
CR-16 exact Cable downstream dependency inspector port
```

Additional remediation self-review clarifications closed phase-specific UoW compile isolation, ledger replay semantics, exact P6 separation persistence, resource graph publication validation and reuse of legacy route validators.

Canonical implementation sequence is now:

```text
P1 Cable identity / CableDefinitionRef / P1 resource-definition types
  ↓ exact-SHA
P2 Allocation / runtime resource selection + claims / A-B terminations
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

P1 code implementation is AUTHORIZED. P2 may begin only after P1 closes on its own exact branch SHA with required green CI and acceptance evidence; the same sequential rule applies through P9.

All four discipline fixtures plus a fiber fixture remain mandatory throughout the track. Legacy electrical routing regression is mandatory from P3 onward. National rule packs remain ELV7 concerns with verified provenance.

## Validation at FL15

Engineering implementation gate: `af08e7bba4094bd96b5650fafc175cc7e2deddaf`.
58 mobile tests and 102 pure-Dart core tests; format, Drift generation and analyzers passed.
Final branch-head commits are checked by the same CI workflow.
