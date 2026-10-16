# ELV4 P9 implementation and ELV1–ELV3 alignment review

Date: 2026-10-16. Latest fully executed technical evidence reviewed at `fcf1ece97507a981e88e2afd31826d2e8aeeb4aa`; later C02 hardening commits remain subject to their own exact-head run.
Branch: `feat/flutter-elv4-power-topology-design`. PR: [#11](https://github.com/alimbetov/electra/pull/11), still draft/unmerged.

## Decision

**IMPLEMENTATION_RECONCILED / RUNTIME_ACCEPTANCE_BLOCKED.** Technical regression is green through the real historical migration matrix; C03 and C04 are closed on executed evidence. Three HIGH integration findings remain: C01, C02 and C05. `RUNTIME_ACCEPTED`, `MERGED` and `CLOSED` remain distinct events; none is recorded by this review.

The [80-row ledger](../product/elv4-implementation/requirements.json) provides implementation traceability. The [live closure register](../product/elv4-implementation/closure.json) is authoritative for current blockers. Passing technical tests do not by themselves satisfy the mandatory seven-case runtime qualification matrix.

## Executed exact-head evidence

### C03 historical materialization baseline

At `eeadf3fb83c209c6280953413edab6790c3dc7b8` the permanent read-only exact-head workflow passed its technical job:

- [Exact-head run 38792145445](https://github.com/alimbetov/electra/actions/runs/38792145445), technical job `116619140018`: PASS.
- Evidence artifact `12001250252`, digest `sha256:ae3055f15b1245dc5caa9bc599db657aa4b950a47d029a9d06fdb00c4e3d5763`.
- generation, formatting and both analyzers: PASS;
- **278 mobile tests**: PASS;
- **307 engineering_core tests**: PASS;
- **71 explicit P7/P8/alignment subset tests**: PASS;
- clean source verification: PASS.

The executed mobile suite includes `elv4_p9_snapshot_materialization_test.dart` and its nonempty R1 -> R2 -> operational mutation/corruption -> reopen regression.

### C04 real historical migration matrix

At `fcf1ece97507a981e88e2afd31826d2e8aeeb4aa`, [Exact-head run 38839558588](https://github.com/alimbetov/electra/actions/runs/38839558588), technical job `116776257460`, passed every technical phase including the new `historical-migrations` phase:

- baseline/specification/reconciliation guards: PASS;
- Drift generation, mobile format/analyze/tests: PASS;
- **real v21/v22 historical migrations: PASS**;
- engineering_core format/analyze/tests: PASS;
- explicit P7/P8/alignment acceptance subset: PASS;
- clean tree: PASS.

Evidence artifact `12020474364`, digest `sha256:bab094660a9c1274140ace80f5c53061569f9d92c67ad18bba02f71532e5611c`.

The historical runner checks out exact origin SHA `74c61f6443c3beaf98e69f0d5f21af3f09474c5c` for schema v21 and `b5e3dc94ba026ecb76e3b6e1b17853bf0f63ccb4` for schema v22, regenerates Drift from each historical source, creates the SQLite fixture under that historical application code, and opens a copy with the current v23 `AppDatabase`. The test preserves historical project/revision rows, physical snapshot payload/hash and legacy result state; v22 retains its existing power scenario while v21 remains power-empty. Neither path invents power/history rows and `PRAGMA foreign_key_check` is empty.

The separate runtime-acceptance job correctly remains FAIL because unresolved HIGH findings are still present.

## Current integration findings

| ID | Severity | Status | Actual source behavior / remaining obligation |
|---|---|---|---|
| C01 | HIGH | OPEN | The public four-vertical coverage publishes calculated persisted-load evidence, but it is not the mandatory Q-CCTV/Q-LAN/Q-ACS/Q-FIRE/Q-SHARED/Q-GENERIC/Q-CHARGE matrix across every required process/context/dimension. Build and execute the complete manifest from persisted canonical and physical facts. |
| C02 | HIGH | OPEN | Port/reference/membership write bypasses are being closed with full ELV4 ownership guards, including indirect load/transfer/capacity/supply/PoE/backup references and P6 adoption. This remains only defensive closure: RM03 still requires a reviewed positive `PowerCanonicalProjectionWriteStore`-equivalent inside one UoW, full candidate-graph validation, exact old/new dependency capture/invalidation, and direct-writer/concurrency evidence. |
| C03 | HIGH | RESOLVED | Freeze captures versioned immutable power/canonical facts, verifies power/physical/manifest hashes, create-next materializes scoped power configuration with run/traversal identity remapping, and frozen workspace reads use captured facts. The executed nonempty R1/R2/reopen test proves historical scenario/budget/workspace invariance and FK validity while CURRENT pointers are deliberately not copied into R2. |
| C04 | HIGH | RESOLVED | Real historical v21 and v22 source origins are exported and migrated to current v23 in exact-head CI. Legacy identities, physical hash/payload and result rows survive; v22 power scenario survives; no synthetic power/history rows are created; FK check is clean. |
| C05 | HIGH | OPEN | The strict wire envelope/registry matches the authoritative command schema and rejects unknown schema/operation/version or malformed envelope. However, this is not yet the complete public semantic adapter: documented aggregate payloads such as `loads[]`/`transfers[]` do not map one-to-one to the current single-item runtime command objects, and wire envelopes do not carry a safe precomputed `changedDependencies`. Implement the reviewed resolver/aggregate handler rather than inventing dependencies or merely renaming command strings. |
| C06 | GATE | RESOLVED | Exact-head technical job is green through `fcf1ece`; every later source HEAD, including C02 hardening/reconciliation commits, must be checked independently. |

## C03 closure evidence

The C03 repair is no longer only prospective design text:

1. `DriftPowerPublicationRuntime` writes `electra.elv4-power-freeze-section.v2` with captured facts and verifies `power_sha256`, `physical_sha256` and the snapshot manifest before historical reads/materialization.
2. `DriftPowerSnapshotFacts` captures revision-scoped power aspects plus required canonical/project facts and historical evaluation records.
3. `DriftElvDesignRevisionRepository.createNext` reconstructs R2 physical run/traversal identities and materializes power configuration with explicit physical-ID remapping.
4. `DriftPowerWorkspaceRepository` and overlay reads consume captured facts for frozen revisions instead of consulting mutable operational rows.
5. `elv4_p9_snapshot_materialization_test.dart` uses nonempty load, scenario, capacity and evaluation data, mutates R2 and adversarially changes R1 operational rows, closes/reopens SQLite, then proves the captured R1 payload, workspace metrics, scenarios and budgets remain invariant and `PRAGMA foreign_key_check` remains empty.
6. R2 receives configuration but not R1 CURRENT evaluation pointers; recalculation remains explicit under the new revision.

## C04 closure evidence

The former migration gap is closed by reproducible historical-origin execution rather than by setting `PRAGMA user_version` on a current database:

1. `run-elv4-historical-migration-matrix.sh` creates detached worktrees at exact v21/v22 source SHA values.
2. Each worktree runs `flutter pub get` and regenerates its own Drift code before fixture creation, so the SQLite schema is generated from that historical source rather than current generated output.
3. `elv4_historical_fixture_export.dart` executes inside `flutter test`, allowing the historical Flutter-backed database to create a real fixture.
4. The current migration test copies that immutable fixture and opens it with schema v23.
5. It verifies `user_version == 23`, legacy project/design revision/physical payload/hash/result invariance, v21 no-power behavior, v22 scenario preservation, zero synthetic mutable power/evaluation/history rows and an empty FK check.
6. This complete phase is part of exact-head technical run `38839558588`, not a manually asserted PASS.

## C02 hardening performed after the C04 baseline

The following defensive writer repairs reduce the remaining RM03 attack surface but do not close C02 by themselves:

- `guardMutableEngineeringPortAgainstPowerOwnership` checks direct binding plus transfer input/output, load, capacity-member, supply-input, PoE endpoint and backup-output ownership;
- ELV1 `savePort` and port archive use that complete ownership guard while retaining exact no-op behavior;
- P6 reference adoption uses the same guard before reusing/updating or retiring an existing port inside its owner transaction;
- engineering-system membership role changes/detach reject active revision-scoped power ownership;
- regression coverage includes direct port ownership, indirect load ownership, membership ownership and P6 adoption rollback/zero-mutation behavior.

The remaining positive obligation is RM03: a reviewed canonical projection writer that can intentionally perform compatible static projection with exact expected revisions, graph validation, old/new dependency closure and design-token/invalidation coordination in one transaction. Blocking all writes is not an acceptable substitute for that supported path.

## Repairs retained from the previous review

- project-maximum revision sequence allocation prevents sequence reuse when restoring an older frozen base;
- versioned physical snapshot hashes are recomputed before create-next materialization;
- committed power-operation replay is resolved before WORKING lifecycle rejection, while command/schema fingerprint reuse is rejected;
- load/transfer/group/supply ports are checked against their declared canonical component owner;
- the public vertical test calculates PWR-01 evidence from persisted typed loads rather than publishing a synthetic PASS;
- temporary source-mutating workflows/scripts were removed and the exact-head gate is read-only.

## ELV1–ELV3 consistency

| Contract | Current state |
|---|---|
| Canonical identities | Power rows continue to reference existing component/port/connection/allocation identities; no parallel ELV identity model is introduced. C02 remains open for reviewed projection/invalidation ownership, not identity duplication. |
| Physical cable accounting | Existing allocation/run identities remain authoritative. C03 create-next remaps captured run/traversal references explicitly. C01 must still prove every mandatory physical qualification path. |
| Revisions/history | Existing lifecycle and receipt APIs are reused. Sequence, physical-hash verification and nonempty power materialization are implemented. |
| Legacy results | Power uses dedicated evaluation/pointer tables rather than the originally planned shared `ProjectDerivedResults` owner/kind extension. This recorded deviation remains acceptable only with explicit invalidation isolation; C02 still blocks acceptance. |
| Schema | Merged ELV3 baseline is v21; power migration is v22; revision-history migration is v23. Real v21/v22 -> v23 origin migrations pass exact-head CI. |
| Accounting | Core regressions cover PSE conversion/idle, feeder loss, charger conversion and usable-bank factors. Application runtime qualification remains C01. |

## C05 boundary analysis

The wire work completed so far is useful but not sufficient for closure:

- `Elv4WireCommandEnvelope` validates a strict fixed top-level envelope and dispatch key `(schema, operation, payloadSchemaVersion)`;
- the registry regression compares runtime registrations against every branch of `power-command.schema.json` exactly;
- unknown operations, unknown versions, schema/version cross-dispatch, missing/extra fields, malformed revisions/fingerprints and a missing installed codec all fail closed.

The remaining semantic mismatch must not be hidden. The schema defines complete aggregate replacement payloads (for example `SET_POWER_LOAD_PROFILE` with `loads[]` and `REPLACE_POWER_TRANSFERS` with a complete transfer set), while current `PowerMutationCommand` implementations are primarily single-aspect mutation objects and accept runtime `changedDependencies`. The canonical wire envelope deliberately does not accept caller-supplied arbitrary changed-dependency lists. Therefore the final public adapter must reload/review current state, derive exact old/new dependency sets and execute the aggregate through the same transaction/ledger/projection boundary. A direct JSON-to-current-command shim would violate P2/RM03/RM11.

## Technical verification versus runtime acceptance

`bash scripts/ci/run-elv4-exact-head.sh` remains the technical gate. `python3 scripts/ci/check-elv4-closure.py` validates reconciliation integrity; `--require-accepted` must continue to fail while any HIGH finding is OPEN or mandatory qualification evidence is absent.

A future runtime acceptance report must cover every manifest process/context/dimension row at one immutable source SHA with evaluation IDs/digests. Unknown, missing, duplicate, stale or unresolved rows fail closed. Validator unit tests and row counts are negative/control evidence, not substitutes for application qualification.

## Recommended closure order

1. C02 — implement the reviewed RM03 canonical projection plus writer/invalidation transaction coordination and concurrency evidence.
2. C01 — execute the seven mandatory persisted qualification scenarios on the stable canonical writer contract.
3. C05 — finish aggregate semantic wire adapters/version dispatch through the actual public runtime boundary.
4. Reconcile ledgers at one final source SHA, run exact-head technical gate, then require `runtime-acceptance` PASS before removing draft status.

## Handoff boundary

ELV5 may consume typed physical demand/capability and explicit assumptions, but ELV4 is not yet a runtime-accepted baseline. ELV6 remains responsible for cabinet/battery fit, ELV7 for verified jurisdictional rules, and ELV8 for product selection/BOM. Do not move unresolved ELV4 integration guarantees into later stages.

The C04 closure event is based on executed source `fcf1ece97507a981e88e2afd31826d2e8aeeb4aa`. Later C02 hardening and this reconciliation commit must receive their own exact-head technical PASS before becoming the next technical baseline. No `RUNTIME_ACCEPTED`, `MERGED` or `CLOSED` event is claimed here.
