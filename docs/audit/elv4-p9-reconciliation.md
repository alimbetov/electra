# ELV4 P9 implementation and ELV1–ELV3 alignment review

Date: 2026-10-15. Source reviewed: `626cb2d4500be6aba3e0230c1b4f52603dc0d38f`.
Branch: `feat/flutter-elv4-power-topology-design`. PR: [#11](https://github.com/alimbetov/electra/pull/11), still draft/unmerged.

## Decision

**IMPLEMENTATION_RECONCILED / RUNTIME_ACCEPTANCE_BLOCKED.** The claim that only documentation and CI cleanup remain is not supported by source. Core arithmetic, publication, history and editor functionality exist, but several required integration guarantees are absent. Do not assign an overall percentage from test counts. `RUNTIME_ACCEPTED`, `MERGED` and `CLOSED` are distinct events; none is recorded by this review.

The [80-row ledger](../product/elv4-implementation/requirements.json) maps every requirement to actual source and regression paths, differentiates pure-core scope, and identifies blocking gaps. Source paths establish implementation traceability, not test execution or requirement acceptance. The [live closure register](../product/elv4-implementation/closure.json) is authoritative for current gaps; earlier audits retain their historical conclusions.

## What existing runs establish

Run [38777994205](https://github.com/alimbetov/electra/actions/runs/38777994205), job `116570525640`, passed mobile analysis and selected rejection/public-vertical/durability/idempotency/failure tests. Its workflow normalized and formatted a test **before execution**, then committed the result as `626cb2d`. It is therefore not a read-only final-head gate. The associated foundation run `38778190445` at `626cb2d` has `action_required` and no jobs, not a passing full suite.

Local review bootstrap uses Flutter 3.47.7, framework `abaf9c5237`, Dart 3.13.5. The initial core-only review executed 307 tests and `dart analyze` successfully. Final source execution belongs to the permanent exact-head report, which includes full source SHA, toolchain, phase outcomes, run/attempt when available, and logs. This document does not fabricate a future run identifier or a self-referential tested SHA.

## Confirmed integration gaps

| ID | Severity | Actual source behavior | Required resolution |
|---|---|---|---|
| C01 | HIGH | The four-vertical test formerly constructed `status: pass` and `output: {qualified: true}`. It never consumed the seven-case qualification manifest, solved all six processes, or checked its required contexts/dimensions. The public builder does not create all manifest physical allocations, terminations and runs. | Execute Q-CCTV, Q-LAN, Q-ACS, Q-FIRE, Q-SHARED, Q-GENERIC and Q-CHARGE through persisted canonical/physical inputs. No boolean, core oracle or row count substitutes for this. |
| C02 | HIGH | `_bindPort` writes the aspect only, without projecting static ELV1 port fields. Generic topology/reference/membership writers do not share power token/invalidation coordination. Mutation dependencies are supplied by callers. | Reviewed static projection and field ownership, exact old/new invalidation, all direct/public writers, deletion/adoption/membership and two-connection regressions. New port/owner rejection guards are partial repairs, not full resolution. |
| C03 | HIGH | Freeze captures power pointer identities, not the full aspect/scenario/physical-input snapshot. `createNext` copies runs/traversals but no power bindings or scenarios. Workspace `_scenarioOptions`, `_scopeRecords`, `_budgets` and overlay helpers read operational state. Existing R1/R2 test uses captured-empty power. | Versioned captured facts and remapped R2 aspects, immutable historical reads with nonempty R1 and changed R2/catalog/membership. Keep old physical hashes valid. |
| C04 | HIGH | Current-schema P2 construction is not execution of upgrades from actual historical v21/v22. ELV1/P2 historical tests do not establish the complete new power/history migration matrix. | Upgrade supported real historical schemas, assert identity/hash/legacy result invariance, FK/integrity checks and no invented power defaults. |
| C05 | HIGH | Application mutation objects and evaluation envelopes do not demonstrate round-trip/version dispatch against the documented public wire schema. JSON specification examples alone are not application decoder evidence. | Reconcile the real envelope/decoder with the schema and prove malformed/unknown-version rejection through the public boundary. |
| C06 | RESOLVED gate | Exact-head technical job passed at `ca281015`; full logs and artifact are retained. | Every subsequent source HEAD is verified independently; PASS does not waive C01–C05. |

## Repairs in this review

1. `DriftElvDesignRevisionRepository.createNext` allocates `max(project.sequence)+1`, including retired rows. Restoring R1 after R2 no longer reuses sequence 2. Replay retains its original revision identity.
2. Before materialization it reconstructs the existing versioned `DesignRevisionPhysicalSnapshot` hash from the stored payload and scope. Altered payload is rejected before inserting R2. The original physical hash algorithm is preserved.
3. `DriftPowerRuntimeStore.executeReplayable` resolves committed receipts before WORKING checks. A lost response can replay after freeze; new operations remain forbidden. Reusing an operation under another command type or payload schema is rejected even with the same supplied fingerprint.
4. Load, transfer, group and supply-requirement ports must belong to the declared canonical component, not merely the same project. Rejected operations do not leave aspect/token/receipt changes.
5. The ELV1 topology port writer rejects modification/retirement of an actively power-bound port. Exact no-op remains allowed; revision-scoped release enables ordinary editing. This is a conservative ownership guard pending the reviewed projection bridge.
6. The public vertical test now reads persisted typed loads, runs `aggregatePowerDemand` and builds actual PWR-01 evidence. Guarded publication recaptures the actual persisted contribution. Known W and incomplete A/VA are asserted explicitly. This strengthens integration evidence but deliberately does not claim the mandatory matrix has passed.
7. Removed eight temporary ELV4 workflows and ten one-shot source-mutating scripts. The permanent workflow has read-only permissions, checks out the exact PR head/push SHA, pins the toolchain, never commits source, and retains logs even on failure.
8. Reconciled all P0–P9 and RM01–RM15 source/test mappings. The schema checker permits actual implementation progress instead of requiring every remediation to remain `NOT_IMPLEMENTED`. Acceptance still requires executed evidence.

## ELV1–ELV3 consistency

| Contract | Preserved or observed |
|---|---|
| Canonical identities | Power rows reference existing component/port/connection/allocation identities; no fifth discipline is introduced. New owner checks reject cross-component borrowing. |
| Physical cable accounting | Existing allocation/run identities remain authoritative. PoE core does not create a second cable claim. C01 remains open until physical verticals prove the complete path. |
| Revisions | Existing lifecycle and transaction/receipt APIs are reused. Sequence and snapshot integrity are repaired. Power materialization remains C03. |
| Legacy results | Actual implementation uses dedicated power evaluation/pointer tables rather than the planned shared ProjectDerivedResults owner/kind extension. This isolates power rows from legacy retirement but is an explicit architecture deviation, not proof of shared invalidation (C02). |
| Schema | Merged ELV3 baseline is v21; power migration is v22; revision-history migration is v23. Payload schema versions remain separate. Actual AppDatabase is v23. |
| Accounting | Existing core tests cover single ownership of PSE conversion/idle, feeder loss, charger conversion and usable-bank factors. Reserve/derating affect capability, not physical demand. Application qualification remains C01. |
| Historical audits | Earlier ELV1–ELV3 and ELV4 audits are not rewritten into retrospective acceptance. Current status is recorded here and in the live registers. |

## Technical verification versus acceptance

Run `bash scripts/ci/run-elv4-exact-head.sh` from a clean committed checkout with Flutter/Dart on PATH. It verifies guards, specification and reconciliation, locked dependencies, Drift, both formatters/analyzers, full mobile/core, explicit P7/P8/history/race/reopen tests and clean source. Set `ELV4_REPORT_DIR` outside the repository to retain JSON and logs.

`python3 scripts/ci/check-elv4-closure.py` checks reconciliation integrity. It must pass with honestly documented gaps. `--require-accepted` is a separate failing gate while HIGH findings or pending evidence remain. A report must cover all manifest process/context/dimension rows at the same SHA with immutable evaluation IDs/digests; unknown/missing/unresolved/duplicate/stale rows are rejected. Validator unit-test reports are structural negative controls, never application acceptance evidence.

## Handoff boundary

ELV5 receives typed physical demand/capability and explicit assumptions, not an invented policy or a fully accepted ELV4 baseline. ELV6 owns cabinet/battery fit; ELV7 owns verified jurisdictional rules; ELV8 owns product selection/BOM. Do not expand ELV4 into those stages to compensate for the integration gaps above.

## Executed exact-head evidence

At `ca281015876829b7d95c23dee0854bbb255f11b2`, both local and GitHub technical
validation passed: generation, format, both analyzers, **278 mobile**, **307 core**,
**71 explicit P7/P8/alignment subset tests**, and clean source. The subset is
already contained in the full mobile count and must not be added to it.

- [Exact-head run 38784483402](https://github.com/alimbetov/electra/actions/runs/38784483402): technical job `116592838704` PASS.
- Evidence artifact `11997121749`, digest `sha256:3af0ee825058d16fde0ab5a079776faf0576fb6dbda63d4f80e52a2535f0bb1a`.
- [Foundation run 38784483658](https://github.com/alimbetov/electra/actions/runs/38784483658) PASS at the same SHA.
- Runtime-acceptance job `116594846639` failed specifically on unresolved HIGH
  findings, after successfully downloading and verifying the technical artifact.

This evidence-only update references the executed source above; it does not claim
that its own commit has already run. Every new HEAD is independently checked by
the permanent workflow. No RUNTIME_ACCEPTED/MERGED/CLOSED event is recorded.
