# ELV6 — P0–P9 delivery plan

Status: DESIGN DRAFT / ALL RUNTIME PACKAGES OPEN
Branch: `feat/flutter-elv6-enclosure-layout-design`
Pinned upstream ELV5: `a20ae91ecbef1da0d16443201e48f7e1b99e8701`
Specification: [design](elv6-enclosure-layout-design-specification.md).

| Package | Scope | Mandatory outputs | Depends on |
|---|---|---|---|
| P0 | Baseline, ownership and stage-entry audit | accepted upstream SHA/schema/API matrix; no-duplication map; migration baseline | Accepted ELV1–ELV5 |
| P1 | Domain/revision model | enclosure/layout/placement/plane/zone/cable-entry types; IDs; exact units; revision and stale contracts | P0 |
| P2 | Persistence and commands | Drift schema, repositories, command wire registry, replay/UoW/history, migration and create-next/freeze hooks | P1 + shared runtime |
| P3 | Rack/enclosure geometry | bounds, front/rear planes, rack-U occupancy, shelf/backplate placement, intrinsic collision engine | P1/P2 |
| P4 | DIN, battery, service and reserved-space fit | DIN intervals; battery envelopes; service/ventilation/keep-out zones; partial/unresolved semantics | P1–P3 + ELV4 evidence |
| P5 | Deterministic auto-layout | pure solver, versioned policy, stable scoring/tie-break, immutable proposal and CAS acceptance | P3/P4 |
| P6 | Cable-entry and patching integration | typed entry anchors, assignments/capacity, ELV3 termination refs, dependency invalidation | P2–P5 + ELV3/ELV5 facts |
| P7 | Engineer workspace | front/rear/internal views, drag preview, inspector, findings, capacity, stale/proposal diff, frozen view | P2–P6 |
| P8 | Qualification | positive/negative/history/replay/rollback/race/restart/performance fixtures and evidence manifest | P0–P7 |
| P9 | Closure and handoff | exact-head reconciliation, limitations, ELV7 validation projection, ELV8 impact contract | P8 |

## P0 — baseline and stage ownership

P0 must prove, not assume:

- exact current schema and migration origin;
- exact existing `ElvCommandResult`, replay, command-ledger, history and UoW semantics;
- exact revision/freeze/create-next hooks;
- exact upstream physical/power/discipline facts available to ELV6;
- identity ownership for every subject placed in an enclosure;
- absence of a competing enclosure-layout source of truth.

P0 blocks runtime work if a required upstream fact is not actually available. The resolution is either an explicit upstream extension or a blocked ELV6 dimension, never a duplicate local calculation.

## P1 — typed layout model

Freeze:

- canonical IDs and logical/revision identity;
- integer-mm and rack/DIN interval conventions;
- coordinate-frame semantics;
- placement occupancy and mounting capabilities;
- reserved/clearance/service zones;
- exact upstream `subjectRef` and fingerprint format;
- `PASS/FAIL/UNRESOLVED/NOT_APPLICABLE` dimensions;
- stale and historical-read rules.

Acceptance design must include examples for wall cabinet, floor rack, DIN enclosure and battery placement.

## P2 — persistence and mutation contract

Freeze the public command registry before implementation. Every mutating operation carries `commandId`, project/revision scope and required expected revisions. Replay runs before mutable-state preconditions. State, dependency invalidation, history, ledger and sync outbox commit atomically.

Migration tests cover fresh DB, accepted previous schema, restart and rollback. New rows never rewrite historical ELV3/4/5 evidence.

## P3 — enclosure/rack placement kernel

Implement pure deterministic kernels for:

- enclosure containment;
- 2D footprint + depth collision;
- rack-U interval occupancy;
- front/rear mounting compatibility;
- shelf/backplate capability;
- exact capacity summaries.

Findings must be structured and stable-order. Widgets must not contain collision logic.

## P4 — specialized fit

Implement DIN linear occupancy, service/removal envelopes, battery footprint/orientation and intrinsic ventilation/keep-out geometry. Unknown mandatory source dimensions produce unresolved dimensions. Jurisdictional spacing values are not embedded here.

## P5 — proposal solver

Auto-layout is a preview engine. Required proofs:

- identical canonical input + algorithm version => byte-stable canonical proposal payload/hash;
- locked placements never move;
- unsatisfied hard constraints return unresolved subjects and diagnostics;
- tie-breaks are stable-ID based;
- stale input fingerprint prevents acceptance;
- rejection has no project mutation.

## P6 — cable and patching integration

Cable-entry assignment reads ELV3 cable/endpoints and ELV5 capacity/patching facts but does not own them. Test duplicate claims, entry capacity, release/reassign, old/new dependency closure and create-next remapping.

## P7 — workspace

The UI must remain a projection over application/query services. Minimum UX qualification:

- desktop + compact navigation;
- front/rear/internal switching preserves selection;
- exact position/dimension inspector;
- keyboard and pointer movement through the same command path;
- conflict does not destroy the engineer's draft;
- stale/frozen states are visually distinct;
- proposal before/after and score diagnostics are inspectable.

## P8 — integrated qualification

At one exact SHA record source, tests, migrations and CI for:

- valid/invalid geometry;
- rack/DIN/battery/cable-entry cases;
- proposal determinism;
- replay and duplicate command ID;
- rollback on injected failure;
- concurrent edit/proposal acceptance race;
- restart persistence;
- R1 freeze → R2 changes → historical R1 proof;
- targeted invalidation;
- corrupted/missing upstream reference fail-closed behavior;
- project-scale performance budget.

Planned fixture IDs are not PASS until executed.

## P9 — closure

P9 must reconcile requirements ↔ code ↔ migrations ↔ tests ↔ exact-head CI. It publishes:

- ELV6 accepted/blocked/unsupported matrix;
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

P0 → P1 → P2 → P3/P4 → P5/P6 → P7 → P8 → P9 is the default runtime sequence. Interface/fixture design for downstream packages should start earlier, but no package may mark accepted before its actual dependencies are qualified.