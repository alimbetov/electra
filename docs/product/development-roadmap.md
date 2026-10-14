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

The [ELV delivery plan](elv-delivery-plan.md) is the active product roadmap. Historical requirements from `docs/elv-engineering-systems-spec` were incorporated into the accepted ELV1/ELV2 implementation and retained in Git history; that branch is no longer an active delivery baseline.

| Stage | Outcome | Status |
|---|---|---|
| ELV0 | Systems, sixteen family editions, shared device participation | Baseline closed |
| ELV1 | Ports, connections, topology, passive mappings and assemblies | CLOSED / ACCEPTED |
| ELV2 | Canonical discipline profiles, versioned catalogs, placement and explicit adoption | CLOSED / ACCEPTED |
| ELV3 | Cable resources, allocation/termination, cable-run traversal, reusable routing/carriers/pathways and physical compatibility | READINESS REOPENED / R2 REMEDIATION REQUIRED / P1 HOLD |
| ELV4 | Power, PoE, PSU, UPS, converters and backup graph | Planned |
| ELV5 | Versioned CCTV/LAN/ACS/fire calculations | Planned |
| ELV6 | Racks, cabinets, patching and physical capacity | Planned |
| ELV7 | Jurisdiction profiles, normative rule packs and findings | Planned |
| ELV8 | Manufacturer selection, snapshots, BOM and deliverables | Planned |

ELV3-P0 remains architecturally remediated and accepted. PRE-P1 hardening closed the first implementation ambiguities, but a second adversarial P1–P9 technical audit found additional integrity gaps in frozen design-revision reproducibility, bend-radius input completeness, resource atomization/termination policy, route handoff identity and exact P6 calculation semantics. P1 is therefore on HOLD until the R2 remediation set is closed and the second audit is rerun.

Current readiness authority:

- `docs/audit/elv3-p1-p9-second-technical-audit.md`.

The prior `docs/audit/elv3-implementation-spec-readiness-audit.md` is SUPERSEDED and is not implementation authorization.

The single execution-document entry point remains `docs/product/elv3-authoritative-spec-index.md`, but its current READY status is suspended by the second technical audit until remediation updates the authoritative contracts.

The accepted ELV3 physical direction itself remains:

```text
EngineeringConnection
  -> CableAllocation
      -> CableResourceSelection
      -> CableTerminationMapping[]
  -> Cable
      -> exact CableDefinitionRef
  -> one active CableRun per ProjectDesignRevision
  -> ordered CableRunTraversal[]
  -> existing/evolved reusable CableRouteSegment geometry
  -> optional PhysicalCarrier/compartment
  -> sealed PathwayContext host
```

Second-audit remediation gate before P1:

```text
R2-01 frozen design revision source-of-truth strategy
R2-02 bend-radius evidence strategy
R2-03 exact CableDefinition canonical hash/wire compatibility
R2-04 resource atom/composite expansion contract
R2-05 termination requirement policy
R2-06 canonical reusable route handoff identity
R2-07 ProjectDesignRevision command/state process
R2-08 remove P1->P5 catalog phase leakage
R2-09 remove P3 table-name contradiction
R2-10 exact P6 formulas and occupancy granularity
R2-11 PathwayContext containment invariants
R2-12 P8 failure matrix
```

After those items close, rerun the P1–P9 technical audit. Only a new PASS may restore `READY FOR EXECUTION / P1 AUTHORIZED`.

The intended implementation sequence remains:

```text
P1 Cable identity / exact ELV2 CableDefinitionRef
P2 Allocation / resources / A-B terminations
P3 ProjectDesignRevision / CableRun / traversal / legacy coexistence
P4 sealed PathwayContext / PhysicalCarrier
P5 Technical physical compatibility
P6 Common physical evidence/calculations
P7 Engineer workflow
P8 Restart / rollback / idempotency verticals
P9 Hard audit / exact-SHA closure
```

Every phase closes on its own exact branch SHA before the next phase begins after execution authorization is restored.

All four discipline fixtures plus a fiber fixture remain required throughout the track. National rule packs require verified sources and provenance. FL16 and ELV6 share enclosure infrastructure; ELV8 reuses electrical BOM/reporting foundations.

## Parallel baseline extensions

- shared room placement transforms, measured floor geometry, inter-room segments and risers;
- complete verified regulatory datasets by jurisdiction and edition, plus additional protection roles/criteria;
- sourced manufacturer datasets and vendor import adapters; no fabricated SKU specifications;
- device-port binding, physical channel fill/capacity and fuller cable/protection coordination;
- complete decision history, broader discipline support and larger-project rendering/performance.

These extensions have separate acceptance criteria. Baseline closure does not claim that all future domain capabilities are complete.

## Validation at FL15

Engineering implementation gate: `af08e7bba4094bd96b5650fafc175cc7e2deddaf`.
58 mobile tests and 102 pure-Dart core tests; format, Drift generation and analyzers passed.
Final branch-head commits are checked by the same CI workflow.
FL15 baseline: one generated panel per floor, common explicit outgoing protection conditions and preserved proposals; detailed boundaries are in the delivery plan.
