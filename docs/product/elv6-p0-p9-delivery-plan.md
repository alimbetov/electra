# ELV6 — P0–P9 delivery plan

Status: DESIGN DRAFT / ALL RUNTIME PACKAGES OPEN
Branch: `feat/flutter-elv6-enclosure-layout-design`
Pinned upstream ELV5: `a20ae91ecbef1da0d16443201e48f7e1b99e8701`
Specification: [design](elv6-enclosure-layout-design-specification.md).

| Package | Scope | Mandatory outputs | Depends on |
|---|---|---|---|
| P0 | Baseline, ownership and stage-entry audit | accepted upstream SHA/schema/API matrix; `PanelAssembly`/ADR-019 ownership map; no-duplication matrix; migration baseline | Accepted ELV1–ELV5 + existing panel domain |
| P1 | Owner-neutral layout/revision model | host refs/adapters; rack/layout/zone/cable-entry extensions; accepted mm numeric convention; IDs; revision/stale contracts | P0 |
| P2 | Persistence and commands | reuse map for existing panel stores/commands; additive Drift schema; exact new command registry; replay/UoW/history; migrations/freeze hooks | P1 + shared runtime |
| P3 | Rack/panel geometry adapters | panel projection reuse; bounds/front/rear views; rack-U occupancy; shelf/backplate placement; collision engine | P1/P2 |
| P4 | DIN, battery, service and reserved-space fit | existing DIN hardening; battery envelopes; service/ventilation/keep-out extensions; partial/unresolved semantics | P1–P3 + ELV4 evidence |
| P5 | Deterministic auto-layout | owner-neutral pure solver; versioned policy; stable scoring/tie-break; owner-targeted immutable proposal and CAS acceptance | P3/P4 |
| P6 | Cable-entry and patching integration | typed entry anchors, assignments/capacity, ELV3 termination refs, dependency invalidation | P2–P5 + ELV3/ELV5 facts |
| P7 | Engineer workspace | unified panel/rack front/rear/internal views; drag preview; inspector; findings; stale/proposal diff; frozen view | P2–P6 |
| P8 | Qualification | baseline nonduplication, legacy regression, positive/negative/history/replay/rollback/race/restart/performance evidence | P0–P7 |
| P9 | Closure and handoff | exact-head reconciliation, limitations, ELV7 validation projection, ELV8 impact contract | P8 |

## P0 — baseline and stage ownership

P0 must prove, not assume:

- exact current schema and migration origin;
- exact existing `PanelAssembly`, `PanelEnclosureGeometry`, `DinRail`, `PanelModulePlacement`, panel reserved-zone/duct persistence and mutation APIs;
- ADR-019 physical panel ownership and current validator behavior;
- accepted millimetre scalar/serialization/tolerance convention used by panel/geometry code;
- exact existing `ElvCommandResult`, replay, command-ledger, history and UoW semantics;
- exact revision/freeze/create-next hooks;
- exact upstream physical/power/discipline facts available to ELV6;
- identity ownership for every host and every subject placed in it;
- absence of any other competing enclosure-layout source of truth.

P0 blocks runtime work if a required upstream fact is unavailable. The resolution is an explicit owner-stage extension or an unresolved ELV6 dimension, never a duplicate model/calculation.

## P1 — typed owner-neutral layout model

Freeze:

- `EnclosureHostRef` and owner-specific adapter semantics;
- existing panel ownership versus new non-panel rack ownership;
- stable IDs and logical/revision identity for ELV6-owned records;
- the accepted existing mm numeric representation rather than a new unit fork;
- rack/DIN interval conventions;
- coordinate-frame semantics;
- placement occupancy and mounting capabilities;
- reserved/clearance/service extension zones;
- exact upstream `subjectRef` and fingerprint format;
- `PASS/FAIL/UNRESOLVED/NOT_APPLICABLE` dimensions;
- stale and historical-read rules.

Acceptance design includes existing electrical/automation panel, wall cabinet, floor rack, DIN and battery placement cases.

## P2 — persistence and mutation contract

First produce an explicit reuse table: existing panel row/type/API → reused unchanged / compatibly extended / migrated with proof. No new table may shadow an existing `PanelAssembly` or `PanelModulePlacement` source of truth.

Freeze only the **new** public ELV6 command registry after inventorying canonical panel commands. Every mutation carries `commandId`, project/revision scope and required expected revisions. Replay precedes mutable-state preconditions. State, dependency invalidation, history, ledger and sync outbox commit atomically.

Migration tests cover fresh DB, accepted previous schema, restart and rollback. New rows never rewrite historical ELV3/4/5 or accepted panel evidence.

## P3 — panel/rack placement kernel

Implement owner-neutral immutable projections and pure deterministic kernels for:

- existing panel enclosure/row/DIN facts through adapters;
- new rack containment and rack-U occupancy;
- 2D footprint + depth collision;
- front/rear mounting compatibility;
- shelf/backplate capability;
- stable capacity summaries.

Findings are structured and stable-order. Widgets do not contain collision logic.

## P4 — specialized fit

Harden existing DIN occupancy using current `DinRail`/`PanelModulePlacement` facts; add only missing service/removal envelopes, battery footprint/orientation and intrinsic ventilation/keep-out semantics. Unknown mandatory source dimensions produce unresolved dimensions. Jurisdictional spacing values are not embedded here.

## P5 — proposal solver

Auto-layout is owner-neutral preview. Required proofs:

- identical canonical input + algorithm version => byte-stable canonical proposal payload/hash;
- locked placements never move;
- unsatisfied hard constraints return unresolved subjects/diagnostics;
- tie-breaks are stable-ID based;
- proposal items identify the canonical owner command target;
- stale owner/dependency fingerprint prevents acceptance;
- rejection has no project mutation.

## P6 — cable and patching integration

Cable-entry assignment reads ELV3 cable/endpoints and ELV5 capacity/patching facts but does not own them. Test duplicate claims, entry capacity, release/reassign, old/new dependency closure and create-next remapping.

## P7 — workspace

The UI is a projection over application/query services and owner adapters. Minimum UX qualification:

- one panel/rack host list with canonical owner visible in diagnostics;
- desktop + compact navigation;
- front/rear/internal switching preserves selection;
- exact position/dimension inspector;
- keyboard/pointer movement through canonical command path;
- conflicts retain engineer draft;
- stale/frozen states are distinct;
- proposal before/after and score diagnostics are inspectable.

## P8 — integrated qualification

At one exact SHA record source, tests, migrations and CI for:

- no duplicate panel enclosure/DIN/module truth;
- existing panel tests/regressions remain green;
- valid/invalid rack/panel geometry;
- rack/DIN/battery/cable-entry cases;
- proposal determinism across supported owner types;
- replay and duplicate command ID;
- rollback on injected failure;
- concurrent owner edit/proposal acceptance race;
- restart persistence;
- R1 freeze → R2 changes → historical R1 proof;
- targeted invalidation;
- corrupted/missing upstream reference fail-closed behavior;
- project-scale performance budget.

Planned fixture IDs are not PASS until executed.

## P9 — closure

P9 reconciles requirements ↔ existing/new owner code ↔ migrations ↔ tests ↔ exact-head CI and publishes:

- ELV6 accepted/blocked/unsupported matrix;
- explicit reused `PanelAssembly` baseline map;
- known limitations;
- ELV7 canonical validation projection schema/version/hash;
- ELV8 substitution/revalidation impact contract;
- current roadmap status.

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

Default runtime sequence: P0 → P1 → P2 → P3/P4 → P5/P6 → P7 → P8 → P9. Interface/fixture design for downstream packages starts earlier, but no package may mark accepted before actual dependencies are qualified.