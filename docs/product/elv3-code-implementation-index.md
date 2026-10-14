# Electra — ELV3 Code Implementation Index

Status: CODE IMPLEMENTATION AUTHORITY / P1-P6 DOMAIN-APPLICATION FOUNDATION / P7-P9 FOUNDATION DESIGNED  
Branch: `feat/flutter-elv3-physical-routing-design`

## 1. Purpose

This is the implementation entry point for ELV3. Architecture/process meaning remains governed by the ELV3 authority chain. This index governs code structure, public types, command ownership, Drift schema, transaction/concurrency contracts and test placement.

The branch has progressed beyond the historical `P1 authorized / P2-P5 hardened` label. Domain/application contracts now reach P7-P9, while the actual Drift baseline remains P2/schema 19. That distinction is mandatory: design or application contracts are not persistence/runtime closure.

## 2. Code-level authority order

1. `docs/product/elv3-p7-p9-foundation-design.md` — implementation-ready P7-P9 foundation and runtime promotion gates.
2. `docs/product/elv3-code-p2-p5-hardening.md` — exact P2-P5 claims/termination/routing/pathway/profile semantics.
3. `docs/product/elv3-code-remediation-final-clarifications.md` — phase-specific UoW, ledger replay, exact P6 evidence, P1 graph validation, legacy-route validation reuse.
4. `docs/product/elv3-code-implementation-remediation-cr01-cr16.md` — closed CR-01..CR-16 remediation.
5. `docs/product/elv3-code-contract-p1-p3.md`.
6. `docs/product/elv3-code-contract-p4-p6.md`.
7. `docs/product/elv3-code-contract-p7-p9.md`.
8. `docs/product/elv3-dual-review-process-hardening.md`.
9. `docs/product/elv3-r2-execution-clarifications.md`.
10. `docs/product/elv3-r2-final-readiness-remediation.md`.
11. `docs/product/elv3-implementation-specification-v2.md`.
12. accepted ADR/P0 authority chain.

The foundation design refines implementation sequencing but does not override domain semantics in the authoritative phase contracts.

## 3. Layer map

```text
engineering_core
  pure domain/value objects/validators/calculations/codecs

application
  commands/services/repository ports/workspace state/impact coordination

data/repositories
  Drift adapters/phase-specific UoW/transaction-bound stores/error translation

app_database.dart
  tables/indexes/migrations/FKs

presentation
  render + command dispatch only
```

Hard rules:

```text
engineering_core MUST NOT import Drift/Flutter
application MUST NOT depend on Drift row types
widgets MUST NOT own compound DB mutations
calculation engines MUST NOT query repositories
command services are the sole use-case orchestration owner
```

## 4. P1-P2 physical allocation foundation

Canonical claim uniqueness is `UNIQUE(cable_id, resource_atom)`. Selection evidence is immutable history; claims are temporary exclusivity ownership. Claim resolution and termination resolution are separate.

Lifecycle:

```text
DRAFT -> RESERVED -> ACTIVE -> RELEASED -> ARCHIVED
DRAFT -> ARCHIVED
RESERVED -> RELEASED
```

Reserve/termination/activate always reload current connection endpoints. Physical history protects destructive ELV1 topology mutation.

## 5. P3-P6 domain/application foundation

P3 defines ProjectDesignRevision, immutable frozen physical snapshots, canonical CableRun/traversal, route handoff/bend evidence and legacy adoption contracts.

P4 defines PathwayContext, PhysicalCarrier and compartments with project isolation, dependency-aware archive and factual capacity invariants.

P5 defines exact physical compatibility profile sets, selector-aware deterministic combination and intrinsic-only findings.

P6 defines revision-scoped calculation/evidence contracts and process codes `ELV-ROUTE-01` through `ELV-ROUTE-06`.

These contracts exist in source, but their canonical P3-P6 Drift persistence is still pending.

## 6. P7 shared engineer workspace

P7 has one workspace; there are no per-discipline route editors.

Canonical progression:

```text
Connection -> Cable -> Allocation -> Termination -> Route -> Carrier -> Findings
```

`canEdit` is derived from `PhysicalDesignContext` plus command permission evidence. Actual execution re-authorizes through `ElvWorkspaceCommandAuthorizer`.

ELV3 undo/redo is persisted command evidence, not `EditorCommandHistory`. Reversible history requires inverse payload + precondition fingerprint. Freeze/revision-history/release/adoption history stays irreversible.

## 7. P8 deterministic acceptance foundation

Deterministic fixture builders are frozen for catalog/project/topology/routing plus canonical ID prefixes. Five fixture plans are frozen for CCTV, LAN, ACS, Fire and Fiber.

Fixture-contract tests are foundation evidence only. They become runtime vertical evidence only after they execute against the real P3-P6 Drift persistence and the mandatory reopen/failure/idempotency protocols.

## 8. P9 executable architecture guard

`scripts/ci/check-elv3-p7-p9-foundation.sh` fails fast when P7-P9 structural contracts drift. The Flutter workflow executes it before Flutter setup.

P9 final closure still requires the complete implementation inventory, command matrix, runtime forbidden-shortcut assertions and exact-SHA evidence.

## 9. Common ELV command result

All P1-P9 commands use `ElvCommandResult<T>` / `ElvFailure`. Raw Drift/SQLite exceptions never cross the application boundary.

## 10. Transaction and concurrency model

Correctness relies on:

```text
FKs
partial unique indexes
expectedRevision conditional updates
atomic Drift transaction
persisted command ledger
real two-connection SQLite race tests where applicable
```

P7 command history state changes must commit in the same transaction as the underlying inverse/forward command.

## 11. Actual Drift baseline

Current implemented schema baseline is **P2 / schema version 19**.

Implemented ELV tables:

```text
ElvCables
CableAllocations
CableAllocationResourceSelections
CableResourceClaims
CableTerminationMappings
CommandExecutionRecords
```

Planned persistence waves:

```text
P3 / schema 20  ProjectDesignRevisions, snapshots, canonical runs/traversals, handoffs/bend evidence, legacy adoption
P4 / schema 21  PathwayContexts, PhysicalCarriers, PhysicalCarrierCompartments
P5 / schema 22  ProjectPhysicalCompatibilityProfileSets + exact refs
P6 / schema 23  RouteSeparationEvidenceRecords + revision-scoped derived results
P7 follow-up       persisted command-history records/cursor evidence
```

Only monotonic schema-number rebasing is allowed if the branch advances first.

## 12. Required phase gates

Every persistence phase includes format/analyze, core/mobile tests, Drift generation, migration/restart/failure tests, race tests where applicable, command-matrix update and exact-SHA evidence.

P7 adds shared-workspace stage/permission/history/trace acceptance. P8 adds five real DB verticals plus rollback/reopen/idempotency/frozen reconstruction. P9 adds architecture inventory/assertions and final exact-SHA evidence.

## 13. Current authorization

```text
P1-P2 runtime persistence foundation          IMPLEMENTED / TESTED IN BRANCH
P3-P6 domain/application contracts            PRESENT
P3-P6 canonical Drift persistence             OPEN
P7 workspace orchestration foundation         IMPLEMENTED
P7 persisted history + concrete trace         OPEN
P8 deterministic fixture foundation           IMPLEMENTED
P8 real DB vertical/restart proof              OPEN
P9 structural CI guard                        IMPLEMENTED
P9 final runtime exact-SHA closure             OPEN
```

No `ELV3 COMPLETE` label is permitted while any OPEN row above remains.

## 14. Next implementation sequence

```text
P3 persistence
 -> P4 persistence
 -> P5 persistence
 -> P6 persistence
 -> P7 concrete query/trace/history adapters
 -> P8 five DB verticals + failure/reopen/idempotency/frozen proof
 -> P9 runtime audit + exact-SHA closure
```
