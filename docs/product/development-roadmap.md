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

## Next vertical acceptance: FL16

The editor reports module/mm overflow and represents the exact physical row arrangement of a generated panel.
Recommended enclosure width, height and depth must account for device dimensions, DIN rails, terminals, cable ducts, clearances and reserved space.
FL15 already supplies preliminary occupied/spare/total module capacity. This is not a physical enclosure dimension.
Normative requirements, manufacturer selection and physical placement remain separate concerns.

## ELV extension track

The [ELV delivery plan](elv-delivery-plan.md) is the active product roadmap.

| Stage | Outcome | Status |
|---|---|---|
| ELV0 | Systems, sixteen family editions, shared device participation | Baseline closed |
| ELV1 | Ports, connections, topology, passive mappings and assemblies | CLOSED / ACCEPTED |
| ELV2 | Canonical discipline profiles, versioned catalogs, placement and explicit adoption | CLOSED / ACCEPTED |
| ELV3 | Cable resources, allocation/termination, cable-run traversal, reusable routing/carriers/pathways and physical compatibility | ARCHITECTURE READY / CODE READINESS REOPENED / CR-01..CR-16 REMEDIATION / P1 HOLD |
| ELV4 | Power, PoE, PSU, UPS, converters and backup graph | Planned |
| ELV5 | Versioned CCTV/LAN/ACS/fire calculations | Planned |
| ELV6 | Racks, cabinets, patching and physical capacity | Planned |
| ELV7 | Jurisdiction profiles, normative rule packs and findings | Planned |
| ELV8 | Manufacturer selection, snapshots, BOM and deliverables | Planned |

ELV3 architecture/process specification remains accepted after P0, R2 and dual-review hardening. A later code-implementation technical review against the actual Dart/Drift code reopened only code-level readiness: one BLOCKER and eleven HIGH findings remain in implementation contracts. The canonical ELV3 domain architecture itself is not reopened.

Architecture/process execution authority remains:

- `docs/product/elv3-authoritative-spec-index.md`;
- `docs/product/elv3-dual-review-process-hardening.md`;
- `docs/product/elv3-r2-execution-clarifications.md`;
- `docs/product/elv3-r2-final-readiness-remediation.md`.

Current code implementation authority/readiness:

- `docs/product/elv3-code-implementation-index.md` — READINESS REOPENED;
- `docs/audit/elv3-code-implementation-technical-review.md` — current blocker/remediation review;
- `docs/product/elv3-code-contract-p1-p3.md`;
- `docs/product/elv3-code-contract-p4-p6.md`;
- `docs/product/elv3-code-contract-p7-p9.md`.

The prior `docs/audit/elv3-code-level-readiness-audit.md` is historical/superseded and is not implementation authorization.

Current code remediation set before P1:

```text
CR-01 P1/P2 resource-definition ownership/compile order
CR-02 single command orchestration owner
CR-03 exact durable CommandExecutionRecords schema/codec
CR-04 DB-enforced partial unique invariants
CR-05 concrete Drift write-unit-of-work transaction strategy
CR-06 two-connection SQLite race tests
CR-07 shared route edit validates canonical + legacy electrical dependents
CR-08 pure snapshot assembler + transaction-bound coordinator
CR-09 typed carrier environment/installation facts
CR-10 exact P5 sealed compatibility-rule hierarchy
CR-11 executable P6 separation evidence/algorithm
CR-12 DRAFT termination persistence contradiction
CR-13 CreateCableRun allocation prerequisite
CR-14 common ELV command result/failure envelope
CR-15 migration version baseline from schemaVersion 17
CR-16 exact Cable downstream dependency inspector port
```

Implementation sequence remains conceptually fixed:

```text
CR-01..CR-16 remediation
  ↓ code technical review PASS
P1 Cable identity / exact ELV2 CableDefinitionRef
  ↓ exact-SHA
P2 Allocation / resource selections + atomic claims / A-B terminations
  ↓ exact-SHA
P3 ProjectDesignRevision / frozen snapshot / deterministic revision fork / CanonicalCableRun / traversal / handoff / legacy coexistence
  ↓ exact-SHA
P4 sealed PathwayContext / PhysicalCarrier / compartments
  ↓ exact-SHA
P5 exact technical physical compatibility profile set / findings
  ↓ exact-SHA
P6 revision-scoped reproducible physical evidence/calculations
  ↓ exact-SHA
P7 Engineer Physical Routing workspace
  ↓ exact-SHA
P8 Restart / rollback / failure injection / persisted idempotency verticals
  ↓ exact-SHA
P9 Architecture-vs-code hard audit / command-matrix audit / final exact-SHA closure
```

P1 code implementation is currently on HOLD. Only a new PASS of `elv3-code-implementation-technical-review.md` after CR remediation restores authorization.

All four discipline fixtures plus a fiber fixture remain required throughout the track. National rule packs require verified sources and provenance. FL16 and ELV6 share enclosure infrastructure; ELV8 reuses electrical BOM/reporting foundations.

## Validation at FL15

Engineering implementation gate: `af08e7bba4094bd96b5650fafc175cc7e2deddaf`.
58 mobile tests and 102 pure-Dart core tests; format, Drift generation and analyzers passed.
Final branch-head commits are checked by the same CI workflow.
