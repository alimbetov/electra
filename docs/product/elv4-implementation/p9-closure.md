# P9 — Requirement reconciliation, exact-head gate and handoff

Status: IMPLEMENTATION RECONCILED / RUNTIME ACCEPTANCE PENDING — see [current P9 audit](../../audit/elv4-p9-reconciliation.md).
Consumes P0–P8 implementation and evidence.
Shared rules: [runtime contracts](shared-contracts.md).
Resolved audit decisions: [RM01–RM15](remediation-contract.md).

## Required work and acceptance

| Requirement | Implementation obligation | Planned acceptance |
|---|---|---|
| ELV4-P9-001 | Resolve every requirement to actual source/test/evidence and review design deviations explicitly | P9-T01 requirement coverage |
| ELV4-P9-002 | Audit every public command for scope, CAS, replay, rollback, invalidation and lifecycle | P9-T02 command coverage |
| ELV4-P9-003 | Reconcile all six process boundaries, typed results and no-double-count invariants | P9-T03 process accounting audit |
| ELV4-P9-004 | Reconcile baseline closure, migration, history and frozen hash guarantees | P9-T04 baseline/history audit |
| ELV4-P9-005 | Run required generation/format/analyze/core/mobile/P8 checks at one exact source SHA | P9-T05 exact-head gate |
| ELV4-P9-006 | Disposition defects and unsupported models without hiding blocked engineering | P9-T06 issue/limitation audit |
| ELV4-P9-007 | Update authoritative stage status and publish explicit ELV5–ELV8 handoff | P9-T07 stage reconciliation |
| ELV4-P9-008 | Separate design approval, runtime acceptance, merge and CLOSED events with immutable evidence refs | P9-T08 closure event audit |

## Requirement and evidence schema

[requirements.json](requirements.json) records requirementId, package, summary, designDocument, plannedAcceptanceIds and runtimeStatus. During implementation add sourcePaths, testPaths/test case names, testedSha, workflow/run IDs and artifact refs, disposition and reviewer decision. Empty evidence is NOT_STARTED/OPEN, never PASS.

P9 checks each actual public method and command schema against the ledger, including inherited ELV1/ELV2/ELV3 mutations. A newly added mutation without a requirement is an audit finding. Each process result must identify its input boundary, algorithm version, quantity units and dependency set; unsupported cases cannot be relabelled as skipped passing tests.

## Mandatory runtime gate

Use actual commands from the repository workflow pinned to the accepted source SHA. Starting inspected workflow: `.github/workflows/flutter-local.yml`. Required categories:

1. Reject tracked generated build artifacts using existing guard.
2. Verify required ELV3 foundation guard.
3. Install locked dependencies in supported Flutter/Dart environment.
4. Generate Drift and validate expected generated-code policy.
5. Run repository formatting and both analyzers.
6. Run engineering_core and mobile suites, including legacy regressions.
7. Run every P8 migration/vertical/restart/rollback/replay/race/history assertion.
8. Record source SHA, workflow/run/job IDs, toolchain versions and check outcomes.

Do not substitute a successful run on the parent SHA. Do not infer runtime success from documentation checks. If later source changes occur, rerun affected required gate and final exact-head evidence; no stale green label.

## Accounting and architecture audit checklist

- Same canonical component/port/connection/cable/revision identities persist through power binding.
- Own load, idle, conversion, PoE allowance, cable loss, reserve and bank usable factors each have exactly one applicable accounting owner.
- PWR-01/02/03/04/05/06 expose consistent scenario/segment scope; no dependency-driven numerical feedback loop.
- Shared project budgets remain complete under discipline/system filter.
- Complete overloaded evaluation reports FAIL; missing safety-critical input cannot report overall PASS.
- Supported DC/PoE/bank model boundary is enforced in code and UI, not only documented.
- Frozen trace reads captured facts and hashes only; no current/latest fallback.
- Mutations, ledger, history, dependency invalidation and revision token share transaction.
- Old evaluate replay does not change current pointer; late publish cannot revive stale/frozen state.
- Component/port/catalog/delete/membership paths enforce references and exact project/revision scope.

## Defect disposition and supported limitations

Zero open BLOCKER/HIGH at runtime closure. Lower findings require explicit decision, owner and target scope. Unsupported general meshes/parallel sources, nonlinear DC outside RM06 single-CP feeders, unimplemented explicit-loss PoE, detailed battery curves and guaranteed recharge-time predictions are declared scope limits, not silently passing capabilities. A required vertical that depends on an unsupported model blocks acceptance; it cannot be waived by calling the model a limitation after implementation.

No national compliance or manufacturer guarantee is asserted without verified edition provenance and the later responsible-stage process. ELV4 physical estimates retain their assumptions and unresolved dimensions in exported evidence.

## Handoff and event record

ELV5 receives typed physical results, required-input findings and scenario/policy interfaces. ELV6 receives existing equipment/enclosure refs and supplied bank dimensions without a cabinet-fit claim. ELV7 receives exact provenance/calculation versions for verified normative policy. ELV8 receives required capability/margins and selected profile evidence without product ranking or procurement decisions.

Record separate events with timestamp, source SHA and evidence refs: DESIGN_REVIEWED, IMPLEMENTED, RUNTIME_ACCEPTED, MERGED and CLOSED. Merge commit and tested source may differ; identify both and any required post-merge evidence. Documentation-only status updates link back to accepted source evidence and do not masquerade as a new runtime run.

Current outcome: all 80 rows reconciled to source/tests, with concrete blocking gaps in [closure.json](closure.json). No RUNTIME_ACCEPTED, MERGED or CLOSED event has occurred. The permanent exact-head workflow verifies technical regressions; it cannot erase unresolved integration findings.

## Remediation closure interpretation

A finding is SPEC_RESOLVED only when all linked governing/shared/package contracts and wire/qualification artifacts agree. It stays RUNTIME_NOT_IMPLEMENTED until source and RMxx-T evidence pass. Consume qualification.json as the sole positive process×dimension gate; required UNRESOLVED/BLOCKED/NOT_CALCULATED prevents closure. Recheck all existing result consumers for RM01 and both revision creation/port writer paths for RM03/RM07/RM10. Historical audit reports remain immutable evidence of the old design; later remediation status is recorded separately.
