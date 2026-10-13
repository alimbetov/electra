# Electra — Development roadmap

The detailed scope and evidence live in [Flutter delivery plan](flutter-delivery-plan.md).
Current delivery branch: `feat/flutter-routing-cablerun`.
Delivery is incremental: each baseline has an exact-commit Flutter/core CI gate.

| Milestone | Outcome | Status |
|---|---|---|
| FL0–2 | Flutter, SQLite, project/floor/room hierarchy | Implemented foundation |
| FL3–6 | Geometry kernel, room editor, surface navigation, component placement | Baseline closed |
| FL7–8 | Explicit electrical loads, circuits and design current | Baseline closed |
| FL9–11 | Surface routes, CableRun, junctions and floor topology | Baseline closed |
| FL12–13 | Dependency recalculation, protection requirements and normative catalog | Baseline closed |
| FL14 | Manufacturer catalogs, strict matching and preserved SKU selections | Baseline closed |
| FL15 | Generate panel structure from consumption groups; incoming protection, phase/reserve proposal | Next |
| FL16 | Enclosure and DIN-row layout, terminals/ducts/zones, module/mm capacity checks | Planned |
| FL17 | Traceable BOM by project/floor/room/system and manufacturer mapping | Planned |
| FL18 | Versioned price books and labor/material estimates | Planned |
| FL19 | Offline PDF reports: drawings, schedules, BOM/estimate and engineering evidence | Planned |
| FL20 | Offline installation, deviations/as-built, tests and commissioning evidence | Planned |

## Next vertical acceptance: FL15

Adding/removing a consumption group updates the proposed panel structure through dependency recalculation.
Normative requirements, manufacturer selection and physical placement remain separate concerns.
Panel generation will preserve proposals and explicit review instead of silently approving a design.

## Parallel baseline extensions

- shared room placement transforms, measured floor geometry, inter-room segments and risers;
- complete verified regulatory datasets by jurisdiction and edition, plus additional protection roles/criteria;
- sourced manufacturer datasets and vendor import adapters; no fabricated SKU specifications;
- device-port binding, physical channel fill/capacity and fuller cable/protection coordination;
- complete decision history, broader discipline support and larger-project rendering/performance.

These extensions have separate acceptance criteria. Baseline closure does not claim that all future domain capabilities are complete.

## Validation at FL14

Engineering implementation gate: `1ac7bcf107bc4297de06d794134c98eae6816220`.
55 mobile tests and 96 pure-Dart core tests; format, Drift generation and analyzers passed.
Final branch-head documentation commits are checked by the same CI workflow.
