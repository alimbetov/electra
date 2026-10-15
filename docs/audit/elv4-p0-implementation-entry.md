# ELV4 P0 — implementation entry reconciliation

Date: 2026-10-15. Design/source entry: `4c35840`.
Merged application baseline: `7f1c701cb4ba492589321f8f9827d20464ddaefb`.
User authorized implementation in `feat/flutter-elv4-power-topology-design`.

## Decision

P0 reconciliation and independent P1 pure-domain implementation have started.
Application runtime integration remains gated by the specific obligations below.
Neither a merged PR nor passing numeric tests establishes ELV3 RC9 or ELV4 closure.
No database migration, power binding writer or editor power feature is introduced
by the first P1 slice.

## Source and evidence inventory

All relative source paths below are under `apps/mobile/` unless stated otherwise.

| Gate | Concrete source / entry | Existing proof and remaining obligation |
|---|---|---|
| RC0 | `lib/data/database/app_database.dart`, `schemaVersion=21` | Sequential migration branches 1–21 exist; older-origin acceptance must be executed, not inferred |
| RC1 | P3 tables and `drift_elv_design_revision_repository.dart`, `drift_elv_cable_run_repository.dart` under `lib/data/repositories/` | `test/data/elv_p3_runtime_closure_test.dart`; stale schema-20 equality corrected to minimum P3 capability, table assertions retained |
| RC2 | `bootstrap/freeze/createNext/supersede/archive`, run create/reroute/archive | Three P3 tests cover empty freeze/reopen and create-next; complete nonempty rollback/replay/route matrix still required |
| RC3 | `drift_elv_pathway_repository.dart`, `drift_elv_physical_carrier_repository.dart` | `test/data/elv_p4_runtime_closure_test.dart`; schema 21 and pathway/carrier assertions exist |
| RC4 | `lib/application/elv_physical_compatibility_repository.dart`, service and core profile types | Repository is an interface; no production implementation or profile-set/finding tables found by implementation search |
| RC5 | `drift_elv_physical_calculation_result_store.dart`, application calculation service | Concrete result store exists; dependencies are written as `[]`, upsert is mutable, no owner/kind isolation; RM01/RM13 remain required before power persistence |
| RC6 | workspace service, `elv_physical_trace_service.dart`, `elv_command_history_repository.dart` | Trace and durable history have contracts, no production implementations found; test fake trace is not runtime proof |
| RC7 | `test/support/elv_vertical_fixture_plan.dart`, P2 acceptance tests | Plans and earlier P2 verticals do not prove five complete P3–P7 public-command restart verticals |
| RC8 | failure-probe constants, P1/P2 concurrency tests, P3/P4 tests | Full combined rollback/idempotency/nonempty frozen-history matrix not established |
| RC9 | historical closure plan and PR #10 | No final closure audit/evidence found. PR #10 merged, but head-associated run 38612920425 failed before analysis/tests |

CI detail: run 38612920425 checked PR merge `c2a3ebf`, associated with head
`a9f6592585a04fbf0e0410e39dbbd3dd2e5c70b4`. Its formatter changed zero files;
the following git diff failed because tracked `app_database.g.dart` was stale
after Drift generation. This is a generated-source synchronization defect, not
a passing test run or a source-formatting defect. No runs were returned for
the actual merged `7f1c701` SHA at inspection time.

Migration reality: v18 introduces cables/ledger, v19 allocations/resources/claims/
terminations, v20 revisions/snapshots/canonical runs/traversals/handoffs/bend/adoption,
v21 pathway/carrier/compartment/assignment. Earlier electrical CableRuns remain a
separate table. Fresh creation uses `createAll`; supported upgrade origins are the
explicit `from < n` branches, whose source presence is not execution evidence.

## Mutation owners and power handoff

| Facts / mutation | Current owner and persistent identity | ELV4 integration obligation |
|---|---|---|
| Component create/remove/restore | component instance and project hierarchy repositories; component ID | Guard all direct repository paths, not only editor commands; capture old/new power closure |
| System membership attach/detach | engineering system repository and placement membership writer; project/system/component | Preserve one equipment identity, reject removal of required shared-source membership |
| Port create/edit/archive | topology repository `savePort/archive`; EngineeringPortInstances | Existing row revision is not a power design-token CAS; RM03 reviewed projection must validate connected/shared-owned fields |
| Connection/internal mapping/group | topology `saveConnection/saveInternal/saveGroup/archive` | Advance power revision token, invalidate selected ancestry and membership facts |
| Catalog import/bind/unbind | reference repository; catalog edition and ComponentReferenceBindings | Preserve old canonical payload/hash; strict power extension remains unimplemented |
| Edition adoption | reference adoption repository | Reviewed owner conflict and impact, pinned exact editions, no scenario writes |
| Cable definition/archive | cable command service and write UoW | Retain existing dependency/lifecycle guards; include power path dependencies |
| Resource reserve/release and terminations | allocation service and write UoW | Same transaction as old/new path invalidation; no duplicated PoE allocation |
| Run/reroute/route/carrier evidence | run, routing, pathway and carrier repositories | Complete set/fan-out dependencies and remapping; public mutation inventory still needs behavioral coverage |
| Freeze/create-next/supersede/archive | revision repository, physical snapshot by revision ID | Existing physical hash preserved; companion power capture in same transaction; all write paths must share lifecycle/token guard |
| Derived read/recalculate/manual/removedKeys | dependency recalculation repository and physical result store; project/nodeKey | RM01 owner/kind classification/filtering must precede any ELV4 writes |
| Undo/redo | history interfaces and editor-local history | RM08 durable revision-scoped payload/cursor implementation required; project-only interface insufficient |

No row in this table is declared COVERED by inventory alone. Current standalone
repositories have their own transactions; a future power UoW must use the same
AppDatabase transaction rather than independently commit nested work.

## Exact reuse and snapshot boundaries

Reuse `ElvCommandResult`, `ElvCommandSuccess`, `ElvCommandFailureResult`,
`ElvFailureCategory`, cable/allocation UoW and CommandExecutionRecords scoped by
`(projectId,commandId)`. Runtime replay helpers are
`replayElvRuntimeCommand` and `recordElvRuntimeSuccess` in
`lib/data/repositories/drift_elv_runtime_support.dart`.

Existing spelling: `ELV_PROJECT_NOT_FOUND`, `ELV_IDEMPOTENCY_CONFLICT`,
`ELV_REPLAYED_REJECTION`, `ELV_DESIGN_REVISION_WORKING_EXISTS`,
`ELV_DESIGN_REVISION_NOT_FOUND`, `ELV_DESIGN_REVISION_NOT_WORKING`,
`ELV_DESIGN_REVISION_REVISION_CONFLICT`, `ELV_DESIGN_REVISION_BASE_NOT_FROZEN`,
`ELV_DESIGN_REVISION_SNAPSHOT_INVALID`, `ELV_DESIGN_REVISION_INVALID_TRANSITION`.

`_buildP3Snapshot` captures runs/traversals with physical payload schema 1.
`createNext` currently allocates `base.sequence+1`, remaps run/traversal IDs,
and compares stored snapshot hashes without recomputing the captured payload hash.
RM07/RM10 require project-wide allocation, verified payload and complete operational
remapping; neither is supplied by the new numeric types. `recordElvRuntimeSuccess`
currently hardcodes payloadSchemaVersion 1; RM11 version dispatch is still required.

## Supported scope and fixture entry

P1 begins with exact rational numbers/intervals, definition refs, static voltage
envelopes, DC constant-current/constant-power and AC explicit VA/PF demand unions,
and explicit loss accounting. It does not enable a graph solver. Later supported
solvers remain radial CC and RM06 single-terminal unbranched CP; meshes and parallel
sources are not silently accepted. Units and discipline policies remain explicit.

Fixture inputs come from `docs/product/elv4-implementation/qualification.json`
and the strict minimal catalog example. Future builders must return named project,
revision, catalog, component, canonical port, connection, allocation/resource/
termination, run/traversal, scenario and segment handles. They must call existing
public hierarchy/placement/membership/topology/reference/physical commands;
new power commands supply aspect handles only. No fake fifth discipline and no
direct SQL setup for a purported end-to-end acceptance case.

## BASE disposition

- BASE-01: schema mismatch corrected in live inventory and structural guard;
  RC9 execution evidence remains open.
- BASE-02: confirmed implementation gaps above require ELV3 remediation before
  application power integration; do not convert plans/fakes into proof.
- BASE-03: old catalog and port code remains unchanged by this slice. Complete
  generic catalog bridge/adoption compatibility stays a P1/P2 acceptance gate.
- BASE-04: companion snapshot, remapping and guarded publication remain P2 gates.

## First-slice verification

Pure Dart 3.13.5: analysis passed; **212 core tests passed**, including **40 new
power tests**. New tests cover exact overload at 1e-12, zero vs absent, malformed
wire values/nonfinite inputs, conservation through two efficiencies, rational and
interval persistence codecs, uncertainty boundaries, voltage/frequency/terminal
consistency, PF/VA/idle validation, pinned edition provenance and the approved
catalog's voltage/loss bodies. This is not full catalog-import or SQLite proof.

P0 and P1 remain IN_PROGRESS; no requirement is marked ACCEPTED. P2–P9 remain
NOT_STARTED. Remaining P1 work: port/transfer/capacity/scenario graph contracts,
generic catalog bridge, PoE/battery definitions and reviewed legacy adoption.
