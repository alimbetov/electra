# ELV4 P9 implementation and ELV1–ELV3 alignment review

Date: 2026-10-16. Source implementation reviewed and executed at `eeadf3fb83c209c6280953413edab6790c3dc7b8`.
Branch: `feat/flutter-elv4-power-topology-design`. PR: [#11](https://github.com/alimbetov/electra/pull/11), still draft/unmerged.

## Decision

**IMPLEMENTATION_RECONCILED / RUNTIME_ACCEPTANCE_BLOCKED.** Technical regression is green and C03 historical power materialization is now closed on executed evidence. Four HIGH integration findings remain: C01, C02, C04 and C05. `RUNTIME_ACCEPTED`, `MERGED` and `CLOSED` remain distinct events; none is recorded by this review.

The [80-row ledger](../product/elv4-implementation/requirements.json) provides implementation traceability. The [live closure register](../product/elv4-implementation/closure.json) is authoritative for current blockers. Passing technical tests do not by themselves satisfy the mandatory seven-case runtime qualification matrix.

## Executed exact-head evidence

At `eeadf3fb83c209c6280953413edab6790c3dc7b8` the permanent read-only exact-head workflow passed its technical job:

- [Exact-head run 38792145445](https://github.com/alimbetov/electra/actions/runs/38792145445), technical job `116619140018`: PASS.
- Evidence artifact `12001250252`, digest `sha256:ae3055f15b1245dc5caa9bc599db657aa4b950a47d029a9d06fdb00c4e3d5763`.
- generation, formatting and both analyzers: PASS;
- **278 mobile tests**: PASS;
- **307 engineering_core tests**: PASS;
- **71 explicit P7/P8/alignment subset tests**: PASS;
- clean source verification: PASS.

The executed mobile suite includes `elv4_p9_snapshot_materialization_test.dart` and its nonempty R1 -> R2 -> operational mutation/corruption -> reopen regression. `runtime-acceptance` job `116621527959` correctly failed because unresolved HIGH findings remain.

## Current integration findings

| ID | Severity | Status | Actual source behavior / remaining obligation |
|---|---|---|---|
| C01 | HIGH | OPEN | The public four-vertical coverage now publishes calculated persisted-load evidence, but it is not the mandatory Q-CCTV/Q-LAN/Q-ACS/Q-FIRE/Q-SHARED/Q-GENERIC/Q-CHARGE matrix across every required process/context/dimension. Build and execute the complete manifest from persisted canonical and physical facts. |
| C02 | HIGH | OPEN | ELV1 port ownership protection exists, but `_bindPort` still lacks the complete reviewed field-level canonical projection bridge and generic topology/reference/membership writers do not yet coordinate exact old/new power invalidation through one transaction boundary. Implement projection/ownership plus direct-writer invalidation and concurrency regressions. |
| C03 | HIGH | RESOLVED | Freeze now captures versioned immutable power/canonical facts, verifies power/physical/manifest hashes, create-next materializes scoped power configuration with run/traversal identity remapping, and frozen workspace reads use captured facts. The executed nonempty R1/R2/reopen test proves historical scenario/budget/workspace invariance and FK validity while CURRENT pointers are deliberately not copied into R2. |
| C04 | HIGH | OPEN | Current-schema construction does not prove upgrades from all supported historical v21/v22 origins. Execute the migration matrix with legacy identity/hash invariance, FK/integrity checks and no invented power defaults. |
| C05 | HIGH | OPEN | Domain mutation objects and JSON schemas still do not prove that the documented envelope is the actual application decoder/version-dispatch boundary. Add public round-trip/dispatch and malformed/unknown-version rejection evidence. |
| C06 | GATE | RESOLVED | Exact-head technical job is green at `eeadf3fb`; every later source HEAD must be checked independently. |

## C03 closure evidence

The C03 repair is no longer only prospective design text:

1. `DriftPowerPublicationRuntime` writes `electra.elv4-power-freeze-section.v2` with captured facts and verifies `power_sha256`, `physical_sha256` and the snapshot manifest before historical reads/materialization.
2. `DriftPowerSnapshotFacts` captures revision-scoped power aspects plus required canonical/project facts and historical evaluation records.
3. `DriftElvDesignRevisionRepository.createNext` reconstructs R2 physical run/traversal identities and materializes power configuration with explicit physical-ID remapping.
4. `DriftPowerWorkspaceRepository` and overlay reads consume captured facts for frozen revisions instead of consulting mutable operational rows.
5. `elv4_p9_snapshot_materialization_test.dart` uses nonempty load, scenario, capacity and evaluation data, mutates R2 and adversarially changes R1 operational rows, closes/reopens SQLite, then proves the captured R1 payload, workspace metrics, scenarios and budgets remain invariant and `PRAGMA foreign_key_check` remains empty.
6. R2 receives configuration but not R1 CURRENT evaluation pointers; recalculation remains explicit under the new revision.

This closes the former C03 statement that freeze captured pointer identities only and create-next omitted power aspects.

## Repairs retained from the previous review

- project-maximum revision sequence allocation prevents sequence reuse when restoring an older frozen base;
- versioned physical snapshot hashes are recomputed before create-next materialization;
- committed power-operation replay is resolved before WORKING lifecycle rejection, while command/schema fingerprint reuse is rejected;
- load/transfer/group/supply ports are checked against their declared canonical component owner;
- ELV1 `savePort`/archive rejects modification or retirement of an actively power-bound port, while exact no-op and explicit release remain allowed;
- the public vertical test calculates PWR-01 evidence from persisted typed loads rather than publishing a synthetic PASS;
- temporary source-mutating workflows/scripts were removed and the exact-head gate is read-only.

## ELV1–ELV3 consistency

| Contract | Current state |
|---|---|
| Canonical identities | Power rows continue to reference existing component/port/connection/allocation identities; no parallel ELV identity model is introduced. C02 remains open for projection/invalidation ownership, not identity duplication. |
| Physical cable accounting | Existing allocation/run identities remain authoritative. C03 create-next now remaps captured run/traversal references explicitly. C01 must still prove every mandatory physical qualification path. |
| Revisions/history | Existing lifecycle and receipt APIs are reused. Sequence, physical-hash verification and nonempty power materialization are implemented. |
| Legacy results | Power uses dedicated evaluation/pointer tables rather than the originally planned shared `ProjectDerivedResults` owner/kind extension. This recorded deviation remains acceptable only with explicit invalidation isolation; C02 still blocks acceptance. |
| Schema | Merged ELV3 baseline is v21; power migration is v22; revision-history migration is v23. C04 must prove real supported-origin upgrades. |
| Accounting | Core regressions cover PSE conversion/idle, feeder loss, charger conversion and usable-bank factors. Application runtime qualification remains C01. |

## Technical verification versus runtime acceptance

`bash scripts/ci/run-elv4-exact-head.sh` remains the technical gate. `python3 scripts/ci/check-elv4-closure.py` validates reconciliation integrity; `--require-accepted` must continue to fail while any HIGH finding is OPEN or mandatory qualification evidence is absent.

A future runtime acceptance report must cover every manifest process/context/dimension row at one immutable source SHA with evaluation IDs/digests. Unknown, missing, duplicate, stale or unresolved rows fail closed. Validator unit tests and row counts are negative/control evidence, not substitutes for application qualification.

## Recommended closure order

1. C02 — complete canonical projection plus writer/invalidation transaction coordination.
2. C01 — execute the seven mandatory persisted qualification scenarios on the stable canonical writer contract.
3. C04 — execute the supported historical migration matrix.
4. C05 — close the public wire decoder/version-dispatch boundary.
5. Reconcile ledgers at one final source SHA, run exact-head technical gate, then require `runtime-acceptance` PASS before removing draft status.

## Handoff boundary

ELV5 may consume typed physical demand/capability and explicit assumptions, but ELV4 is not yet a runtime-accepted baseline. ELV6 remains responsible for cabinet/battery fit, ELV7 for verified jurisdictional rules, and ELV8 for product selection/BOM. Do not move unresolved ELV4 integration guarantees into later stages.

The commits that update this audit/closure register are evidence reconciliation commits after the executed `eeadf3fb` implementation. They must receive their own exact-head technical run before they can become new technical evidence. No `RUNTIME_ACCEPTED`, `MERGED` or `CLOSED` event is claimed here.
