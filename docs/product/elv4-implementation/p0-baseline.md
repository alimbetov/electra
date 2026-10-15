# P0 — Baseline, ownership and implementation entry

Status: DESIGN DRAFT / EVIDENCE GATE OPEN
Depends on existing ELV1–ELV3 source and closure evidence. Supplies all later packages.
Shared rules: [runtime contracts](shared-contracts.md).

## Required work and acceptance

| Requirement | Implementation obligation | Planned acceptance |
|---|---|---|
| ELV4-P0-001 | Inventory merged source, schema and supported migration origins at an exact commit; distinguish document claims from code and executed tests | P0-T01 source/schema inventory |
| ELV4-P0-002 | Map each ELV3 RC0–RC9 gate to source, public entry point and exact-head evidence or an explicit unresolved gap | P0-T02 baseline evidence reconciliation |
| ELV4-P0-003 | Identify every mutable port/profile/connection/mapping/load/route fact consumed by power and its current command owner | P0-T03 mutation-owner coverage |
| ELV4-P0-004 | Record exact existing error codes and transaction/replay/result interfaces reused by ELV4 | P0-T04 reuse map |
| ELV4-P0-005 | Freeze supported/deferred electrical model boundary and generic power catalog binding strategy | P0-T05 scope walkthrough |
| ELV4-P0-006 | Design deterministic FK-valid fixture builders for four disciplines, shared budgets, historical/legacy and negative cases | P0-T06 fixture design review |
| ELV4-P0-007 | Identify snapshot freeze/create-next/delete/adopt integration and all operations requiring revision-token advancement | P0-T07 race-boundary map |
| ELV4-P0-008 | Record entry outcome with no fabricated runtime closure or implicit resolution of BASE-01…04 | P0-T08 gate decision |

## Source inventory record

Each entry contains path/symbol, entity owner, persisted table/key, command/query path, current revision guard, transaction boundary, dependencies, snapshot inclusion, existing tests and evidence SHA. Start with the map in the [coordinated contract](../elv4-coordinated-p0-p9-contract.md), then follow concrete implementations rather than planned filenames.

Required mutation categories: component/port removal and restore; system membership detach; catalog/profile bind/release/adopt; external connect/disconnect; passive mapping replacement; allocation reserve/release/termination; run/reroute/carrier evidence; freeze/create-next/supersede/archive; derived-result publication/invalidation; undo/redo.

A category is COVERED only when all public entry points use the agreed guard/invalidation path. Report direct repository paths separately from editor paths. UI-only protection is insufficient.

## Baseline discrepancy disposition

| Existing item | Required evidence / decision | Blocks |
|---|---|---|
| BASE-01 source/schema/status mismatch | Actual schema 21 at inspected base, migration policy, reconciled RC status with original historical assertions preserved | Runtime entry |
| BASE-02 concrete runtime/vertical proof | Actual implementation equivalents and accepted exact-head migration/restart/race/freeze evidence; otherwise explicit ELV3 remediation | Runtime entry |
| BASE-03 catalog/port compatibility | Existing codec behavior and ownership handoff to typed extension, including old hashes | P1/P2 acceptance |
| BASE-04 freeze/materialization | Current physical hash semantics and safe companion power envelope | P2 acceptance |

Do not convert a missing test log into a proven source defect. Do not convert a merged PR into a proven passed test. Every gap has severity, owner package, action, evidence needed and disposition.

## Concrete deliverables

Proposed audit outputs under docs/audit: baseline source inventory, mutation-owner matrix and entry-gate decision. Populate requirement ledger runtime evidence only after execution. Generic power templates remain independent of ReferenceDiscipline; no fifth discipline or duplicated equipment identity.

Fixture builder design returns named handles for project/revision, catalog refs, components, ports, connections, passive mappings, allocations/resource selections/terminations, canonical runs and scenarios. Required valid writes use public commands. Raw SQL may only inspect state or construct explicitly documented historical migration inputs.

## Work order and exit

1. Pin implementation base and inspect current generated/migration policy.
2. Reconcile RC evidence and identify required ELV3 remediation.
3. Complete ownership/error/revision/freeze integration maps.
4. Review supported electrical slice against all four discipline scenarios.
5. Freeze fixture/public-command design and publish entry disposition.

P0 design acceptance means the maps and unresolved obligations are concrete. P0 runtime entry requires baseline blockers closed with evidence; design of P1–P9 does not close them. No app code is implemented in this documentation package.
