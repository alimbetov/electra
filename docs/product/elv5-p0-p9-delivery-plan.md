# ELV5 — P0–P9 delivery plan

Status: DESIGN DRAFT / ALL RUNTIME PACKAGES OPEN
Branch: `feat/flutter-elv5-power-topology-design`
Parent: ELV4 `4c35840bf1453df8adc49cce18d937fe20a52801`.
Specification: [design](elv5-discipline-calculations-design-specification.md); [detailed contracts](elv5-implementation/README.md).

| Package | Scope | Depends on |
|---|---|---|
| P0 | [Baseline and stage integration](elv5-implementation/p0-baseline.md) | Existing ELV1–ELV4 source/design/evidence |
| P1 | [Typed discipline profiles and process registry](elv5-implementation/p1-profiles-registry.md) | P0 ownership/scope map |
| P2 | [Persistence, command boundaries and revision evidence](elv5-implementation/p2-persistence-commands.md) | P1 contracts plus evidenced shared platform |
| P3 | [CCTV calculation implementation](elv5-implementation/p3-cctv.md) | P1/P2 and relevant ELV3/ELV4 kernels |
| P4 | [LAN and structured-cabling implementation](elv5-implementation/p4-lan.md) | P1/P2, ELV3 lengths/resources and PWR-06 |
| P5 | [Access-control implementation](elv5-implementation/p5-acs.md) | P1/P2, canonical assemblies and power kernels |
| P6 | [Fire-alarm implementation](elv5-implementation/p6-fire.md) | P1/P2, signal topology and supported electrical kernels |
| P7 | [Incremental dependencies and engineer workspace](elv5-implementation/p7-dependencies-workspace.md) | Design begins P1/P2; complete integration P3–P6 |
| P8 | [Integrated verification and qualification](elv5-implementation/p8-acceptance.md) | P0–P7 implemented prerequisites |
| P9 | [Architecture reconciliation and stage handoff](elv5-implementation/p9-closure.md) | P8 plus complete requirement/source/test evidence |

## Sequencing and evidence

P0 → P1 → P2 → discipline packages P3/P4/P5/P6 → completed P7 → P8 → P9. P7 consumed-input/mutation design and P8 public fixture design start with P1/P2. Discipline packages may be developed independently only where their actual prerequisite kernels/registries are accepted. No package may invent a duplicated power/length calculation to bypass a missing dependency.

All packages have eight numbered requirements and planned acceptance IDs (80 total). Registry has 27 process codes, each with two planned positive/negative acceptance IDs. Planned IDs and fictional arithmetic are not executed tests.

Each runtime gate records source/test/migration/CI evidence at one exact accepted SHA, including lifecycle, replay, rollback and reopened-state assertions. BASE-01…04 and missing ELV4 runtime entry evidence stay open. Design may proceed without fabricating their closure.

## Stage boundaries

LAN-06 delivers rack demand/capacity basis; ELV6 owns layout and fit. FA-08 delivers technical cable/policy/evidence matching; ELV7 owns verified jurisdictional compliance. ELV8 owns product ranking/selection/BOM. Required positive dimension scope must be explicit before runtime qualification; unsupported cases are separately named negatives.

## Current ledger

| Package | Design | Runtime | Evidence |
|---|---|---|---|
| P0 | DRAFT | NOT_STARTED | — |
| P1 | DRAFT | NOT_STARTED | — |
| P2 | DRAFT | NOT_STARTED | — |
| P3 | DRAFT | NOT_STARTED | — |
| P4 | DRAFT | NOT_STARTED | — |
| P5 | DRAFT | NOT_STARTED | — |
| P6 | DRAFT | NOT_STARTED | — |
| P7 | DRAFT | NOT_STARTED | — |
| P8 | DRAFT | NOT_STARTED | — |
| P9 | DRAFT | NOT_STARTED | — |
