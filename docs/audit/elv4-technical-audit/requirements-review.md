# ELV4 — построчная проверка 80 требований

Проверенный HEAD: `4404c02bba777515f70e58150dd8a25bff0a1573`. Parent: [отчёт аудита](report.md).

FINDING — есть конкретное замечание к контракту/интеграции. BASELINE_GATE_OPEN — признанное незавершённое входное доказательство. NO_LOCAL_FINDING — противоречие в данном пункте не выявлено; runtime и package readiness не подтверждены. Связанные общие дефекты могут блокировать пакет независимо от локальной оценки отдельного пункта.

## P0

| Требование | Проверяемый смысл | Результат | Замечания | Приёмка |
|---|---|---|---|---|
| ELV4-P0-001 | Inventory merged source, schema and supported migration origins at an exact commit; distinguish document claims from code and executed tests | BASELINE_GATE_OPEN | — | P0-T01 |
| ELV4-P0-002 | Map each ELV3 RC0–RC9 gate to source, public entry point and exact-head evidence or an explicit unresolved gap | BASELINE_GATE_OPEN | — | P0-T02 |
| ELV4-P0-003 | Identify every mutable port/profile/connection/mapping/load/route fact consumed by power and its current command owner | FINDING | ELV4-AUD-01 | P0-T03 |
| ELV4-P0-004 | Record exact existing error codes and transaction/replay/result interfaces reused by ELV4 | FINDING | ELV4-AUD-01 | P0-T04 |
| ELV4-P0-005 | Freeze supported/deferred electrical model boundary and generic power catalog binding strategy | FINDING | ELV4-AUD-05, ELV4-AUD-06 | P0-T05 |
| ELV4-P0-006 | Design deterministic FK-valid fixture builders for four disciplines, shared budgets, historical/legacy and negative cases | FINDING | ELV4-AUD-05, ELV4-AUD-15 | P0-T06 |
| ELV4-P0-007 | Identify snapshot freeze/create-next/delete/adopt integration and all operations requiring revision-token advancement | FINDING | ELV4-AUD-07, ELV4-AUD-10 | P0-T07 |
| ELV4-P0-008 | Record entry outcome with no fabricated runtime closure or implicit resolution of BASE-01…04 | BASELINE_GATE_OPEN | — | P0-T08 |

## P1

| Требование | Проверяемый смысл | Результат | Замечания | Приёмка |
|---|---|---|---|---|
| ELV4-P1-001 | Implement typed validated quantities, edition refs and immutable value objects with explicit absent/zero semantics | FINDING | ELV4-AUD-02, ELV4-AUD-09 | P1-T01 |
| ELV4-P1-002 | Bind power roles to canonical port/component IDs with one owner per projected field | FINDING | ELV4-AUD-02, ELV4-AUD-03 | P1-T02 |
| ELV4-P1-003 | Define local transfers, efficiency accounting, capacity groups and unique own-load contribution identity | FINDING | ELV4-AUD-12 | P1-T03 |
| ELV4-P1-004 | Implement scenario segments, state/source selection, durations and charge/discharge interlock | FINDING | ELV4-AUD-03, ELV4-AUD-12 | P1-T04 |
| ELV4-P1-005 | Add versioned root-catalog power extension and generic equipment template support without changing old discipline codecs | FINDING | ELV4-AUD-05, ELV4-AUD-11 | P1-T05 |
| ELV4-P1-006 | Model PoE delivery and bank/charger definitions with exact provenance and model applicability | FINDING | ELV4-AUD-11 | P1-T06 |
| ELV4-P1-007 | Provide explicit legacy mapping/adoption preview; missing typed facts stay unresolved | FINDING | ELV4-AUD-02, ELV4-AUD-03 | P1-T07 |
| ELV4-P1-008 | Freeze process input/output/numeric schemas and exact canonical serialization behavior | FINDING | ELV4-AUD-04, ELV4-AUD-09, ELV4-AUD-11 | P1-T08 |

## P2

| Требование | Проверяемый смысл | Результат | Замечания | Приёмка |
|---|---|---|---|---|
| ELV4-P2-001 | Add scoped aspect/child tables, uniqueness, checks, foreign keys and indexes with additive migration | FINDING | ELV4-AUD-11 | P2-T01 |
| ELV4-P2-002 | Implement transaction-bound power stores and integrate canonical port writers without independent commits | FINDING | ELV4-AUD-02, ELV4-AUD-05 | P2-T02 |
| ELV4-P2-003 | Implement every mutation family with replay-first ledger, aggregate CAS and complete receipts | FINDING | ELV4-AUD-03, ELV4-AUD-05, ELV4-AUD-11 | P2-T03 |
| ELV4-P2-004 | Advance coordinated design token and invalidate old/new dependency closures atomically | NO_LOCAL_FINDING | — | P2-T04 |
| ELV4-P2-005 | Extend ProjectDerivedResults with immutable evaluation rows and guarded mutable pointers | FINDING | ELV4-AUD-01, ELV4-AUD-04 | P2-T05 |
| ELV4-P2-006 | Add coordinated power companion snapshot and manifest; preserve old physical hashes | FINDING | ELV4-AUD-07, ELV4-AUD-10, ELV4-AUD-14 | P2-T06 |
| ELV4-P2-007 | Persist reversible history and validate ordinary inverse/forward commands atomically | FINDING | ELV4-AUD-08 | P2-T07 |
| ELV4-P2-008 | Integrate adoption/deletion/membership guards and stable storage/error translation | FINDING | ELV4-AUD-02, ELV4-AUD-03 | P2-T08 |

## P3

| Требование | Проверяемый смысл | Результат | Замечания | Приёмка |
|---|---|---|---|---|
| ELV4-P3-001 | Build one deterministic derived graph per captured revision/scenario/segment from canonical identities | FINDING | ELV4-AUD-05 | P3-T01 |
| ELV4-P3-002 | Resolve availability, alternative-feed selection and transfer direction before connectivity checks | FINDING | ELV4-AUD-03 | P3-T02 |
| ELV4-P3-003 | Preserve passive continuity and independently validate power/data direction and domain | FINDING | ELV4-AUD-05 | P3-T03 |
| ELV4-P3-004 | Detect active cycles, reconvergent supply paths, ambiguous direction and unsupported returns | NO_LOCAL_FINDING | — | P3-T04 |
| ELV4-P3-005 | Check voltage guarantees, AC frequency, DC polarity and supported transfer envelopes | FINDING | ELV4-AUD-03 | P3-T05 |
| ELV4-P3-006 | Trace ordered provenance to explicit source boundaries with unresolved frontiers | NO_LOCAL_FINDING | — | P3-T06 |
| ELV4-P3-007 | Separate topology, realization, capacity and backup dimensions; retain missing-input dependencies | NO_LOCAL_FINDING | — | P3-T07 |
| ELV4-P3-008 | Read frozen trace entirely from verified captured evidence | NO_LOCAL_FINDING | — | P3-T08 |

## P4

| Требование | Проверяемый смысл | Результат | Замечания | Приёмка |
|---|---|---|---|---|
| ELV4-P4-001 | Resolve leaf state demands into typed contribution records without missing-to-zero coercion | NO_LOCAL_FINDING | — | P4-T01 |
| ELV4-P4-002 | Aggregate distinct contributions per output/group/source across all system memberships | NO_LOCAL_FINDING | — | P4-T02 |
| ELV4-P4-003 | Apply transfer efficiency and own loss at one declared boundary | NO_LOCAL_FINDING | — | P4-T03 |
| ELV4-P4-004 | Compute PSU required/available margins with independent reserve and derating policy | FINDING | ELV4-AUD-09 | P4-T04 |
| ELV4-P4-005 | Assess UPS W and VA independently using explicit input PF/VA basis | NO_LOCAL_FINDING | — | P4-T05 |
| ELV4-P4-006 | Assess peak duration/simultaneity separately from continuous demand | FINDING | ELV4-AUD-12 | P4-T06 |
| ELV4-P4-007 | Emit deterministic arithmetic trace, applicability and per-dimension result | FINDING | ELV4-AUD-04, ELV4-AUD-13 | P4-T07 |
| ELV4-P4-008 | Integrate P5/P6 through one bottom-up evaluator, with no process dependency cycle | FINDING | ELV4-AUD-06 | P4-T08 |

## P5

| Требование | Проверяемый смысл | Результат | Замечания | Приёмка |
|---|---|---|---|---|
| ELV4-P5-001 | Resolve exact PSE/PD roles and supported declared delivery, never RJ45/Ethernet inference | NO_LOCAL_FINDING | — | P5-T01 |
| ELV4-P5-002 | Validate full combined path, power-pass mappings and conducting resource evidence without new cable claims | NO_LOCAL_FINDING | — | P5-T02 |
| ELV4-P5-003 | Implement GUARANTEED_PD allocation/guarantee accounting with loss allowance applied once | NO_LOCAL_FINDING | — | P5-T03 |
| ELV4-P5-004 | Return BLOCKED for EXPLICIT_PATH_LOSS unless its exact pair/electrical model is implemented and verified | NO_LOCAL_FINDING | — | P5-T04 |
| ELV4-P5-005 | Check PD guarantee, per-port allocation and shared group budget independently | FINDING | ELV4-AUD-09 | P5-T05 |
| ELV4-P5-006 | Map PSE output demand to upstream input with own consumption/conversion exactly once | NO_LOCAL_FINDING | — | P5-T06 |
| ELV4-P5-007 | Model midspan/injector supply and data/power boundaries explicitly | FINDING | ELV4-AUD-05 | P5-T07 |
| ELV4-P5-008 | Include complete/missing path/group/scenario dependencies and restart-stable result evidence | FINDING | ELV4-AUD-07 | P5-T08 |

## P6

| Требование | Проверяемый смысл | Результат | Замечания | Приёмка |
|---|---|---|---|---|
| ELV4-P6-001 | Build typed radial section resistance/current model from exact installed resources and terminations | NO_LOCAL_FINDING | — | P6-T01 |
| ELV4-P6-002 | Solve constant-current trunks/branches and report every terminal/current limit at source bounds | FINDING | ELV4-AUD-09 | P6-T02 |
| ELV4-P6-003 | Block nonlinear/mesh/shared-return models outside the supported first slice | FINDING | ELV4-AUD-06 | P6-T03 |
| ELV4-P6-004 | Validate bank series/parallel compatibility, voltage, rating conditions and usable-capacity model | NO_LOCAL_FINDING | — | P6-T04 |
| ELV4-P6-005 | Compute piecewise protected energy and sequence margin with explicit duration/model/loss boundaries | FINDING | ELV4-AUD-04, ELV4-AUD-06 | P6-T05 |
| ELV4-P6-006 | Validate charge/discharge selection and charger operating plus recharge load | FINDING | ELV4-AUD-06, ELV4-AUD-12 | P6-T06 |
| ELV4-P6-007 | Distinguish required capacity, available capacity and supported autonomy estimate | FINDING | ELV4-AUD-06 | P6-T07 |
| ELV4-P6-008 | Persist complete arithmetic/model assumptions and target only affected dependencies | FINDING | ELV4-AUD-07 | P6-T08 |

## P7

| Требование | Проверяемый смысл | Результат | Замечания | Приёмка |
|---|---|---|---|---|
| ELV4-P7-001 | Encode typed dependency keys and persist present/missing exact inputs for every process | FINDING | ELV4-AUD-01, ELV4-AUD-04, ELV4-AUD-13 | P7-T01 |
| ELV4-P7-002 | Invalidate old/new graph closure across shared systems and disconnected paths atomically | FINDING | ELV4-AUD-01, ELV4-AUD-13 | P7-T02 |
| ELV4-P7-003 | Capture/calculate/publish with token/fingerprint/pointer CAS and stale-race rejection | FINDING | ELV4-AUD-04, ELV4-AUD-13, ELV4-AUD-14 | P7-T03 |
| ELV4-P7-004 | Implement revision/scenario-aware power overlay and shared-source budget view | FINDING | ELV4-AUD-03 | P7-T04 |
| ELV4-P7-005 | Implement one progressive side card with back/forward selection retention and explanation | NO_LOCAL_FINDING | — | P7-T05 |
| ELV4-P7-006 | Route preview, commit, failed draft, undo/redo through public application commands | FINDING | ELV4-AUD-08 | P7-T06 |
| ELV4-P7-007 | Implement frozen read-only, NOT_CAPTURED and captured-empty states distinctly | FINDING | ELV4-AUD-07, ELV4-AUD-14 | P7-T07 |
| ELV4-P7-008 | Cover compact width, keyboard/focus/back handling and findings remediation navigation | NO_LOCAL_FINDING | — | P7-T08 |

## P8

| Требование | Проверяемый смысл | Результат | Замечания | Приёмка |
|---|---|---|---|---|
| ELV4-P8-001 | Implement deterministic FK-valid public-command builders and all four discipline verticals | FINDING | ELV4-AUD-05, ELV4-AUD-06, ELV4-AUD-15 | P8-T01 |
| ELV4-P8-002 | Verify shared sources and exact affected/unaffected dependency sets | FINDING | ELV4-AUD-13 | P8-T02 |
| ELV4-P8-003 | Verify fresh and every supported historical migration origin without synthetic power backfill | FINDING | ELV4-AUD-11 | P8-T03 |
| ELV4-P8-004 | Close/reopen file SQLite and prove exact revision/profile/resource/result identity | FINDING | ELV4-AUD-04, ELV4-AUD-07, ELV4-AUD-08 | P8-T04 |
| ELV4-P8-005 | Inject every owned durable failure checkpoint and inspect atomic rollback | NO_LOCAL_FINDING | — | P8-T05 |
| ELV4-P8-006 | Verify lost-response replay, payload conflict and concurrent mutation/publication boundaries | FINDING | ELV4-AUD-08, ELV4-AUD-10, ELV4-AUD-14 | P8-T06 |
| ELV4-P8-007 | Prove frozen R1 independence from R2/current catalog/archive changes | FINDING | ELV4-AUD-04, ELV4-AUD-07 | P8-T07 |
| ELV4-P8-008 | Exercise malformed, missing, unsupported, overload and numerical/property cases with explicit negative controls | FINDING | ELV4-AUD-01, ELV4-AUD-02, ELV4-AUD-09, ELV4-AUD-12, ELV4-AUD-13, ELV4-AUD-15 | P8-T08 |

## P9

| Требование | Проверяемый смысл | Результат | Замечания | Приёмка |
|---|---|---|---|---|
| ELV4-P9-001 | Resolve every requirement to actual source/test/evidence and review design deviations explicitly | FINDING | ELV4-AUD-15 | P9-T01 |
| ELV4-P9-002 | Audit every public command for scope, CAS, replay, rollback, invalidation and lifecycle | FINDING | ELV4-AUD-01, ELV4-AUD-08 | P9-T02 |
| ELV4-P9-003 | Reconcile all six process boundaries, typed results and no-double-count invariants | FINDING | ELV4-AUD-15 | P9-T03 |
| ELV4-P9-004 | Reconcile baseline closure, migration, history and frozen hash guarantees | FINDING | ELV4-AUD-01, ELV4-AUD-10 | P9-T04 |
| ELV4-P9-005 | Run required generation/format/analyze/core/mobile/P8 checks at one exact source SHA | NO_LOCAL_FINDING | — | P9-T05 |
| ELV4-P9-006 | Disposition defects and unsupported models without hiding blocked engineering | FINDING | ELV4-AUD-06, ELV4-AUD-15 | P9-T06 |
| ELV4-P9-007 | Update authoritative stage status and publish explicit ELV5–ELV8 handoff | FINDING | ELV4-AUD-15 | P9-T07 |
| ELV4-P9-008 | Separate design approval, runtime acceptance, merge and CLOSED events with immutable evidence refs | FINDING | ELV4-AUD-14, ELV4-AUD-15 | P9-T08 |

## Итог покрытия

Проверено 80 уникальных требований. Оценки: BASELINE_GATE_OPEN=3, FINDING=57, NO_LOCAL_FINDING=20. Все runtimeStatus остались NOT_STARTED.

Конкретные path:line и объяснение каждой оценки находятся в [JSON реестре](findings-and-coverage.json); условия исправления — в [основном отчёте](report.md).
