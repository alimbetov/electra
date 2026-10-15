# P8 — Executable runtime acceptance specification

Status: IMPLEMENTATION RECONCILED / RUNTIME ACCEPTANCE PENDING — see [current P9 audit](../../audit/elv4-p9-reconciliation.md).
Consumes P0–P7; fixture design begins during P0/P1.
Shared rules: [runtime contracts](shared-contracts.md).
Resolved audit decisions: [RM01–RM15](remediation-contract.md).

## Required work and acceptance

| Requirement | Implementation obligation | Planned acceptance |
|---|---|---|
| ELV4-P8-001 | Implement deterministic FK-valid public-command builders and all four discipline verticals | P8-T01 four verticals |
| ELV4-P8-002 | Verify shared sources and exact affected/unaffected dependency sets | P8-T02 shared-source graph |
| ELV4-P8-003 | Verify fresh and every supported historical migration origin without synthetic power backfill | P8-T03 migration matrix |
| ELV4-P8-004 | Close/reopen file SQLite and prove exact revision/profile/resource/result identity | P8-T04 restart identity |
| ELV4-P8-005 | Inject every owned durable failure checkpoint and inspect atomic rollback | P8-T05 failure matrix |
| ELV4-P8-006 | Verify lost-response replay, payload conflict and concurrent mutation/publication boundaries | P8-T06 replay/races |
| ELV4-P8-007 | Prove frozen R1 independence from R2/current catalog/archive changes | P8-T07 historical invariance |
| ELV4-P8-008 | Exercise malformed, missing, unsupported, overload and numerical/property cases with explicit negative controls | P8-T08 adversarial matrix |

## Proposed test organization

Core: `packages/engineering_core/test/power_*_test.dart` for quantities/codecs, graph/trace, load/conversion, PoE, DC/backup and canonical determinism. Mobile application/data: `apps/mobile/test/application/elv_power_*_test.dart`, `apps/mobile/test/data/elv_power_*_test.dart`; UI tests follow existing editor feature test location. Shared builders under mobile/test/support use deterministic named handles and public command adapters.

Tests are organized by invariant/behavior, not a mirror of private functions. Requirement ledger maps stable acceptance IDs to actual test files/cases once written. Existing electrical/ELV1–ELV3 suites remain required regressions.

## Public-command vertical recipe

1. Create project/floor/room/placed equipment via existing supported setup APIs.
2. Import exact fictional reference editions and create working revision.
3. Bind mapped power profiles, instantiate canonical ports through the supported atomic path.
4. Create canonical connections/passive mappings; create/reserve/terminate/activate existing cables and installed runs using ELV3 commands.
5. Set loads/transfers/groups, supply requirements, scenarios, PoE and backup assemblies with exact preconditions.
6. Evaluate supported processes; assert topology, realization, quantities, contribution origins, statuses and dependencies.
7. Query trace and workspace; freeze, create-next, modify R2 and close the database completely.
8. Reopen another database instance and verify R1/R2, ledger replay, exact refs and foreign-key validity.

The actual public path must exist before a vertical is accepted. Internal raw INSERT fixtures do not prove command integration. Historical migration seeds are separate and clearly labelled.

## Vertical matrix

| Fixture | Required behavior | Required proof beyond arithmetic |
|---|---|---|
| CCTV | AC boundary → UPS → PSE → camera(s); PD/PSE loss and own-load boundary | Same canonical combined cable allocation; input PF explicit; upstream/backup dependencies |
| LAN | PSE → patching/outlet → PD; injector alternative | Each passive stage proves power passage; fiber-only negative preserves data independently |
| ACS | PSU/charger/bank → controller/reader/lock; shared DC trunk | Explicit relay control versus feed, .3/.5A trunk arithmetic, scenario-dependent bank direction |
| Fire | PSU/charger/bank → panel and declared loads; standby/alarm sequence | Explicit hours/model, no implicit fire policy; loop signal topology does not create power loop |
| Shared | CCTV + LAN consume same PSE/UPS | Single project group total and own load, independent-source negative control |
| Historical | R0 pre-power, frozen R1, working R2 | NOT_CAPTURED versus CAPTURED_EMPTY; old hashes and traces independent of current rows |

V1/V3/V4/V6 numerical cases are boundary arithmetic oracles. Full vertical builders must provide explicit remaining compatible profiles, ratings, source bounds and physical evidence; the oracle alone cannot assert whole-design PASS. In particular, a constant-W energy sequence does not prove a supported nonlinear DC terminal solution. Positive qualification uses supported CC trees or RM06 single-CP feeders with every manifest-required dimension COMPLETE/PASS. Unresolved model/boundary estimates are separate non-qualifying cases.

Binding positive qualification is specified in [qualification.json](qualification.json). Historical boundary numerical data remains in [design fixtures](../../examples/elv4-power-design-fixtures.json). This JSON is a design/test oracle, not an importable application catalog or proof that a vertical already executes.

## Migration and restart matrix

Use the repository's supported migration origins discovered in P0; required categories are fresh DB, oldest supported origin, pre-ELV1, ELV1/ELV2, schema 21 baseline and immediately preceding implementation schema where distinct/supported. Assert old identity sets, payload/hash equality and existing result behavior. Run foreign_key_check and integrity checks with foreign keys enabled.

Power-free legacy revisions stay uncaptured. New empty power sections are explicit. Reimport old catalog produces no new power defaults and preserves edition hash. Reopen must decode immutable evaluations/current pointers and successful ledger receipts without using latest reference data.

## Failure and replay matrix

For each public mutation family and each registered owned probe: snapshot baseline rows/ledger/history/pointers → execute with injected exception → inspect same-open DB → close/reopen → compare exact pre-state. No successful ledger, revision increment, partial child replacement, invalidation or canonical projection may survive a rolled-back command.

For response loss, commit normally then deliberately drop delivery of the response to the caller; retry same ID/payload after reopen and compare exact original receipt. Then reuse ID with a different payload and expect idempotency conflict. Do not simulate response loss by throwing before commit.

## Two-connection race matrix

| Pair | Synchronization boundary | Required valid outcome |
|---|---|---|
| Profile/load edit versus same aggregate edit | Both capture expected token before first commit | One CAS winner; loser conflict/review required |
| Shared-source edit versus PD edit | Old shared impact captured | Valid serialization or explicit stale conflict; full budget never lost |
| Preview versus adoption/change | After preview before commit | Reviewed fingerprint rejected when changed |
| Route/termination edit versus calculation | After pure input capture before publish | Publish rejected or fresh recalculation; no old CURRENT resurrection |
| Freeze versus canonical power edit | Before revision token CAS | One valid serialized state; frozen payload corresponds to winning token |
| Freeze versus calculate publish | After capture before publish | Publisher blocked after freeze; captured pointers coherent |
| Create-next versus retry/create-next | After initial frozen state read | One WORKING revision under existing lifecycle rules; replay returns original IDs |
| Undo versus intervening edit | After history cursor read | Stale inverse rejected; no blind state overwrite |

Use explicit barriers/hooks, bounded waits and two independent file DB connections. No sleep-only race assumptions, shared in-memory DB substitute or disabled-FK shortcut. BUSY recovery follows shared bounded policy and is asserted as a stable failure if exhausted.

## Numerical and metamorphic cases

Permutation of input iteration order preserves fingerprints/quantities/findings; adding an unrelated isolated source leaves existing logical results unchanged; adding one distinct load increases matching group demand once; a duplicate system membership does not add physical demand. Loop resistance input and explicit forward+return equivalent produce equal simple DC result. Series bank increases V, parallel count increases Ah; capacity factors apply once.

Include missing versus zero, nonfinite values, wrong units, voltage-overlap trap, no source, active cycle, same-source reconvergence, source unavailable, port/group overload, missing PF, missing resistance/temperature evidence, unsupported nonlinear load, incompatible bank and missing duration/extension policy.

Exit: all planned assertions are implemented and passing at the source SHA evaluated by P9. Fixture/code existence without execution leaves runtime gate open.

## Mandatory audit regression gates

Add RM01-T…RM15-T to existing P0–P9 acceptance IDs; they are refinements of the 80 requirement rows, not runtime PASS evidence. Include mixed-owner legacy recalculate/manual retirement; explicit zero and read-only scenario projection; two distinct segment keys plus sequence; power-only generic import/connect; bounded CP feeder and no-solution; run/traversal remapping and older-base restoration; durable redo after two restarts; exact-decimal boundary; project sequence allocator races; schema version dispatch; conservative startup; consumed-input completeness; nonblocking freeze serialization; and qualification validator rejection of required unresolved dimensions.

Every positive case in qualification.json must run through the public-command builder and real FK-valid file SQLite; record complete profile/policy/model facts and exact required process/dimension outcomes. Negative fixtures have their own IDs and cannot satisfy a positive row by being skipped or BLOCKED.
