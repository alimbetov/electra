# Electra — ELV4 Expanded P0–P9 Delivery Plan

Status: DESIGN DRAFT / ALL PACKAGES OPEN
Branch: `feat/flutter-elv4-power-topology-design`
Baseline: `7f1c701cb4ba492589321f8f9827d20464ddaefb`
Parent: [ELV4 specification](elv4-power-topology-design-specification.md)
Shared interfaces: [coordinated P0–P9 contract](elv4-coordinated-p0-p9-contract.md)
Implementation detail: [P0–P9 package specifications](elv4-implementation/README.md)

## Delivery rules

P0–P9 are work-package IDs. Subpackages below add detail without renumbering the ten packages. Design work may proceed now; runtime implementation requires P0 entry evidence and a reviewed P1 contract. Each runtime package earns its own exact-SHA gate before its dependent package is accepted.

Every subpackage delivers a concrete contract, source/persistence mapping, command matrix entries, tests and recorded evidence. No package is accepted solely because classes/tables exist. All commands document input/expected revisions, read/validate/write sets, lifecycle, dependency keys, replay, rollback, undo, errors and restart assertions.

## Package map

| Package | Outcome | Depends on |
|---|---|---|
| P0 | Reconciled ELV1–ELV3 baseline and ELV4 boundary | Existing repository/source and closure evidence |
| P1 | Typed power/reference/operating-mode domain | P0 |
| P2 | Safe persistence, commands and coordinated revision history | P1 |
| P3 | Scenario power graph, validation and trace | P1–P2 |
| P4 | Load/conversion/PSU/UPS basis | P3 |
| P5 | PoE delivery and shared budgets | P3–P4 |
| P6 | DC drop, backup bank/charger/autonomy basis | P3–P5 |
| P7 | Dependency integration and progressive editor | P2–P6 |
| P8 | Real vertical/restart/race/failure acceptance | P0–P7 |
| P9 | Architecture/runtime reconciliation and final closure | P8 |

P7 dependency design starts during P2; no earlier package may postpone atomic invalidation until the UI package. P8 fixture design starts during P0; P8 is final integrated verification, not first testing.

## P0 — Baseline reconciliation and engineering boundaries

P0.1 Inventory actual ELV1 port/connection/profile/internal mapping types and guards.
P0.2 Inventory ELV2 catalog codecs, enums, binding/adoption commands, profile snapshots and palette.
P0.3 Inventory ELV3 schema, migration chain, revisions, snapshots, physical lengths/resources, command ledger, result storage/history and concrete adapters.
P0.4 Compare merged code against RC0–RC9 contracts. Record exact-head CI and runtime proof; open gaps as ELV3 remediation, not hidden ELV4 scope.
P0.5 Decide one power projection, one coordinated revision, passive continuity versus active transfer, AC boundary and unsupported redundancy.
P0.6 Freeze four-discipline scenarios plus shared-source and legacy-history cases.
P0.7 Produce authoritative source map and command/dependency inventories.

Tests/evidence: actual schema extraction; existing suites/CI evidence; migration and frozen-history proof; no unsupported claims of ELV3 closure.
Exit: no unexplained baseline discrepancy; any required ELV3 runtime blocker closed before ELV4 runtime starts. Design may continue while gaps are listed.

## P1 — Canonical profiles, aspect bindings and operating scenarios

P1.1 PowerPortProfile and extension of existing voltage/power fields without duplicate endpoint identity.
P1.2 Component transfer definitions for transformer, AC/DC, DC/DC, PSU, UPS, charger, distributor/fuse and PSE.
P1.3 Consumer own-load/demand profiles; watts versus amps versus VA; explicit zero/missing distinction.
P1.4 NORMAL/STANDBY/ALARM/STARTUP/BACKUP scenario composition and simultaneous-load groups.
P1.5 Exact PoE and battery-bank definitions and supported/deferred topology classification.
P1.6 ELV2 catalog wire extension, canonical code normalization, source/hash/deprecation/version lifecycle.
P1.7 Explicit legacy field mapping and adoption impact; ambiguous quantities stay unresolved.

Deliverables: pure domain source/type plan; versioned catalog JSON examples; field/unit/cardinality matrix and invariant tests.
Tests: serialization/legacy round-trip, edition immutability, bad/nonfinite units, voltage guarantees, independent data/power direction, shared groups, battery arrangement validation.
Exit: four disciplines use the same typed contracts; no vendor/discipline label branching; no silent power profile synthesis.

## P2 — Persistence, commands, freeze and adoption

P2.1 Additive schema proposal from the actual latest schema; project/revision FKs, uniqueness, checks and indexes.
P2.2 Concrete repositories/mappers and transaction-bound UoW; command ledger and stable error translation.
P2.3 Public aspect/scenario/profile commands with expectedRevision and reviewed-impact fingerprints.
P2.4 ELV2 adoption/ELV1 deletion guards aware of power transfer/profile dependencies.
P2.5 Versioned power section in coordinated freeze/create-next; preserve old physical snapshot hashes.
P2.6 Reversible command history and atomic inverse/forward state transitions.
P2.7 Derived-result node codec/key convention and immutable evaluation evidence using existing store.

Tests: fresh + oldest supported + latest baseline migration; legacy electrical/ELV1–ELV3 preservation; exact reopen; duplicate aspect protection; cross-project/revision rejection; atomic failure; replay after response loss.
Exit: no widget orchestration, no empty historical fallback, no split state/ledger/invalidation transaction; mixed-owner result consumers, durable redo and typed remapping/sequence allocation must satisfy RM01/07/08/10. Historical pre-ELV4 snapshot reports NOT_CAPTURED.

## P3 — Scenario power topology, compatibility and trace

P3.1 Project canonical connections to active power layers; resolve local transfers.
P3.2 Validate consumer supply requirements and declared alternative-feed selection.
P3.3 Check voltage guarantees, AC/DC, required AC frequency and DC polarity; passive stages cannot convert domains.
P3.4 Detect active scenario cycles, unsupported sharing/backfeed and unresolved upstream sources.
P3.5 Trace upstream/downstream through explicit converter/source boundaries with termination and realization evidence.
P3.6 Guard cross-system shared resources; distinguish reachability, compatibility and capacity.
P3.7 Frozen trace reads frozen payload only; WORKING trace reads current verified aggregate.

Tests: radial, explicit branching, mixed data/power, passive patching, relay control versus feed, selected backup source, missing source, wrong domain, cycle, cross-project path, historical trace.
Exit: trace explains every edge/transfer and why a consumer is powered, unresolved or incompatible. Signal topology is preserved.

## P4 — Load, converter, PSU and UPS processes

P4.1 ELV-PWR-01 demand by state and graph aggregation without duplicate component/self load.
P4.2 Converter loss/idle accounting, derating and shared output capacity groups.
P4.3 ELV-PWR-02 required capability versus selected available capability; reserve applied once.
P4.4 ELV-PWR-05 independent W/VA/PF constraints and protected output scope.
P4.5 Startup/peak duration and simultaneity basis; unknown peak capability remains unresolved.
P4.6 Structured arithmetic trace, fingerprint, provenance, process codecs and failure status.

Tests: golden arithmetic, enumeration-order invariance, shared branch capacity, two systems/one source, idle/efficiency double-count trap, missing PF, reserve versus derating, boundary/overload cases.
Exit: deterministic physical basis for all relevant modes; no product ranking or jurisdictional compliance; partial inputs cannot report complete totals.

## P5 — PoE delivery and power budget

P5.1 Exact PSE/PD profile roles, supported delivery negotiation and declared capability provenance.
P5.2 One combined connection/cable, compatible conductor resources and power-pass patch continuity.
P5.3 Midspan/injector ports and separately powered upstream path.
P5.4 ELV-PWR-06 per-port/shared budget and PSE-versus-PD loss boundary.
P5.5 Include switch own consumption and conversion losses in upstream PSU/UPS input once.
P5.6 Missing/unsupported cable path, fiber and incompatible power passage findings.

Tests: CCTV direct, LAN patched, injector, multiple PDs, one over-budget port, aggregate overload, source unavailable, wrong profile, fiber, duplicate cable/resource claims.
Exit: PoE never follows from RJ45/Ethernet label alone; shared budgets survive restart and scenario edits invalidate the right upstream results.

## P6 — DC drops, chargers, battery banks and backup

P6.1 ELV-PWR-03 exact installed length/resource/terminal resistance; temperature and forward/return convention.
P6.2 Radial branch current accumulation and worst terminal voltage; constant-current solver.
P6.3 Mandatory bounded single-terminal constant-power feeder solver (RM06); other nonlinear/shared-return/mesh models remain BLOCKED.
P6.4 Battery bank series/parallel composition, compatible units, voltage/capacity/usable model.
P6.5 Charger operating load plus recharge demand; scenario charge/discharge direction and limits.
P6.6 ELV-PWR-04 piecewise standby/alarm energy or supported Ah basis with explicit duration policy.
P6.7 UPS backup conversion chain and rate/temperature/aging assumptions; unsupported model limitations.

Tests: known 2-wire drop, shared trunk, asymmetric conductors, missing resistance, already-loop resistance, series Ah trap, parallel voltage trap, incompatible bank, missing autonomy policy, backup/charge scenario, factor double-count trap.
Exit: ACS and Fire produce explainable physical bases with selected assumptions, not regulatory claims; missing safety-critical inputs block full result.

## P7 — Incremental dependencies and engineer workspace

P7.1 Typed dependency keys across port/profile/connection/load/scenario/source/cable/run/process result.
P7.2 Fan-out for shared PSE/UPS, converters and DC trunks; unrelated edits leave results current.
P7.3 One shared power overlay, independent trace direction and exact revision/scenario selection.
P7.4 Progressive side cards for consumer/path/profile/realization/budget/backup/findings.
P7.5 How-calculated quantities/steps/source refs; blocked reason and remediation navigation.
P7.6 Application commands and persisted undo/redo; stale reviewed preview rejected at commit.
P7.7 FROZEN read-only view and historical NOT_CAPTURED state; compact-screen behavior.

Tests: targeted invalidation, shared-system fan-out, frozen result stability, scenario separation, UI command permissions, failed-write draft retention, keyboard/navigation and compact panel.
Exit: the engineer can place/bind → connect → realize → evaluate → trace → explain → freeze/reopen without hand-maintained numbers.

## P8 — Integrated runtime acceptance and adversarial proof

P8.1 Real public-command verticals for CCTV, LAN, ACS, Fire and cross-system shared source.
P8.2 Explicit temp SQLite close/reopen; exact port/connection/cable/binding/group/scenario IDs, refs/hashes/results.
P8.3 Freeze R1 → create R2 → change load/source/route/catalog/bank → reopen → identical R1.
P8.4 Inject failure at every durable command checkpoint; inspect same-open and reopened DB.
P8.5 Response-loss replay and same-command/different-payload conflict for every replayable mutation.
P8.6 Two independent SQLite connections race on profile/scenario replacement and freeze-versus-write; one valid winner or stable conflict.
P8.7 Missing/invalid input, active cycles, per-port/aggregate limits, unsupported sharing and legacy project regression.
P8.8 Dependency assertions cover both affected nodes and unaffected controls.

Failure points to freeze in P2 command matrix:
ELV4_BIND_AFTER_ASPECT_INSERT;
ELV4_TRANSFER_AFTER_DELETE_OLD_SET;
ELV4_SCENARIO_AFTER_STATE_WRITE;
ELV4_POE_AFTER_DELIVERY_BIND;
ELV4_BACKUP_AFTER_BANK_WRITE;
ELV4_FREEZE_AFTER_POWER_SECTION;
ELV4_COMMAND_BEFORE_LEDGER_COMMIT.
Add points for uncovered write boundaries before coding.

Exit: FK-valid fixtures with no disabled-FK/cardinality-only substitutes; all positive, negative, rollback, race, replay and history matrices pass on one exact SHA.

## P9 — Final audit, evidence and stage handoff

P9.1 Refresh type/file/table/schema/process/error/failure-point inventories.
P9.2 Audit all public mutation commands against transaction/replay/history matrix.
P9.3 Reconcile ELV1–ELV3 source contracts and ELV4 snapshot/dependency changes.
P9.4 Runtime assertions forbid duplicate graph identity, data-implies-power, duplicate budget/cable accounting, latest-profile frozen reads, policy defaults and unsupported-cycle success.
P9.5 Verify all six process codes and four discipline contexts, legacy migrations and historical power traces.
P9.6 Record exact head, workflow IDs, Drift generation, generated-artifact guard, formatting/analyzers/core/mobile tests and P8 matrices.
P9.7 Update authoritative stage status and handoff to ELV5 with remaining limitations explicitly listed.

Exit: zero open BLOCKER/HIGH; remaining lower-severity findings dispositioned with owner/scope; P0–P8 gates evidenced; exact final head green. Any later source commit invalidates prior exact-head closure until checks rerun. Merge and CLOSED are distinct recorded events.

## Execution checkpoints and evidence ledger

Recommended checkpoints: A P0/P1 design; B P2 persistence; C P3 graph; D P4 physical load; E P5 PoE; F P6 backup; G P7 UX/integration; H P8/P9 closure. Each package retains its own gate even when several share a PR.

| Package | Design | Runtime | Exact SHA / evidence |
|---|---|---|---|
| P0 | DRAFT — DESIGNED | NOT STARTED | Baseline alignment audit only |
| P1 | DRAFT — DESIGNED | NOT STARTED | — |
| P2 | DRAFT — DESIGNED | NOT STARTED | — |
| P3 | DRAFT — DESIGNED | NOT STARTED | — |
| P4 | DRAFT — DESIGNED | NOT STARTED | — |
| P5 | DRAFT — DESIGNED | NOT STARTED | — |
| P6 | DRAFT — DESIGNED | NOT STARTED | — |
| P7 | DRAFT — DESIGNED | NOT STARTED | — |
| P8 | DRAFT — DESIGNED | NOT STARTED | — |
| P9 | DRAFT — DESIGNED | NOT STARTED | — |

Each evidence entry must link source implementation, tests and CI at the same accepted SHA; planned filenames and examples are not proof.

## Coordinated design acceptance matrix

Every P0–P9 package is designed now. Runtime dependency order is unchanged. Read the corresponding section of the coordinated contract together with the subpackages above; the following obligations cannot be deferred to a later package.

| Package | Design section | Cross-package obligation before runtime acceptance |
|---|---|---|
| P0 | §2 source map/baseline | Resolve baseline evidence without rewriting historical closure claims |
| P1 | §3 types/fields/scenarios | All typed fields have one owner, unit, scope and exact edition; generic power catalogs do not break discipline codecs |
| P2 | §4 persistence/commands/history | Revision token, old/new invalidation, ledger and history commit atomically; immutable evaluation evidence is added explicitly |
| P3 | §5 active graph | Scenario source selection, passive/active boundaries and reconvergent source rejection feed all calculations consistently |
| P4 | §6.1–6.2 evaluation/load | Consume PoE/electrical boundary demand once; keep W/VA, reserve and derating distinct |
| P5 | §6.3 PoE | Select guaranteed-PD or explicit-loss accounting; preserve one canonical cable/resource claim |
| P6 | §6.4 DC/backup | Shared trunk current, supported solver bounds, capacity factors, charging direction and explicit duration policy |
| P7 | §7 dependencies/workspace | Current freshness is separate from engineering pass; shared project budgets remain visible under system filters |
| P8 | §8 acceptance manifest | Positive arithmetic, public-command verticals and all rollback/replay/race/history boundaries |
| P9 | §9 closure/handoff | One source SHA links requirements, code, tests and CI; limitations pass explicitly to later stages |

No design status in this table asserts implementation or review approval. Numerical fixtures are fictional; actual standard editions and discipline policy are external inputs to later verified catalogs.

## Implementation requirement traceability

Each package now has eight numbered MUST requirements, planned acceptance IDs, implementation boundaries and failure/exit behavior in the detailed specification (80 requirements total). [requirements.json](elv4-implementation/requirements.json) is the design traceability source, with empty runtime evidence by intention. [Fictional fixture data](../examples/elv4-power-design-fixtures.json) provides explicit numerical oracles and history/path assertions; it is not an app-import catalog.

## Technical audit remediation gates

All packages include applicable RM01-T…RM15-T acceptance refinements. The [resolved contract](elv4-implementation/remediation-contract.md), strict wire schemas/examples and [qualification manifest](elv4-implementation/qualification.json) are required design inputs. All 80 original requirement IDs remain stable; their runtime states remain NOT_STARTED. A specification resolution never substitutes for P0 baseline evidence or an exact-SHA runtime gate.
