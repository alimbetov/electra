# ELV5 — Baseline and boundary reconciliation

Date: 2026-10-16. Branch: `feat/flutter-elv5-power-topology-design`.
Accepted ELV4 source: `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`.
Merged main baseline: `d2b059d4c11a284cdd32965140f6df3c40020c8d` via [PR #11](https://github.com/alimbetov/electra/pull/11).
Scope: actual merged source, existing executed ELV4 CI evidence and ELV5 design reconciliation. No new discipline runtime qualification is claimed.

## Confirmed changes since the original design baseline

| Area | Implemented ELV4 | Required ELV5 change |
|---|---|---|
| Baseline | Schema 23; C01–C06 resolved | Start from merged main; additive schema above 23 |
| Result ownership | Dedicated PowerEvaluationRecords/PowerEvaluationPointers and reverse index | Add isolated discipline stores; preserve legacy ProjectDerivedResults and power codecs |
| Canonical writers | Reviewed projection/UoW and fail-closed legacy topology/reference/membership paths | Extend coordinated impact and cross-stage invalidation; no direct writer bypass |
| Command boundary | Strict command v1/revision command v2, server-reviewed impact, aggregate CAS/ledger | Separate strict discipline command registration; replay before lifecycle checks |
| Freeze/history | Captured facts in power section v2; manifest v1; historical reads; typed create-next materialization | Version discipline section/manifest; preserve old hashes; NOT_CAPTURED for old revisions |
| Revision recovery | Project-max sequence allocator; physical payload hash verification | Reuse allocator/remapping; no copied CURRENT/evaluation/receipt/history state |
| Qualification | Seven persisted public-command cases with actual evaluators | Add all 27 discipline processes, dimensions and shared-context proofs |
| Migrations | Real v21/v22 origin matrix to schema 23 | Retain origins and add real merged v23 → ELV5 migration |
| Closure | Read-only exact-head technical/qualification/acceptance evidence | Extend for ELV5; acceptance stays an external artifact |

[Full P0–P9 integration contract](../product/elv5-implementation/implemented-baseline.md) and [machine-readable evidence](../product/elv5-implementation/baseline.json) define source/test references and remaining work. The original planned common ProjectDerivedResults owner extension was not the implemented ELV4 architecture; ELV5 now follows the recorded dedicated-store deviation.

## Entry obligations

| ID | Current disposition | Remaining scope |
|---|---|---|
| ELV5-BASE-01 | EVIDENCED_INHERITED | Accepted ELV4 is reusable; new discipline wrappers still need proof |
| ELV5-BASE-02 | RECONCILED_INHERITED | Canonical/history/migration boundary mapped; no blanket certification of all historical schemas or new consumers |
| ELV5-BASE-03 | OPEN_ELV5_EXTENSION | Discipline stores/keys/dispatch and cross-owner consumer isolation |
| ELV5-BASE-04 | OPEN_ELV5_EXTENSION | Strict discipline codecs and complete executable qualification manifest |

## Evidence and limitations

[Exact-head run 38859878752](https://github.com/alimbetov/electra/actions/runs/38859878752): technical job 116839507912 PASS; runtime-acceptance job 116842014688 PASS at accepted source SHA. [Foundation run 38859878966](https://github.com/alimbetov/electra/actions/runs/38859878966) also passed. PR #11 is merged; merge and acceptance retain separate SHAs/events.

All 80 ELV5 runtime requirements and all 27 new process runtime statuses remain NOT_STARTED. The eight initial discipline design findings remain SPEC_RESOLVED, with runtime tests still required. No ELV6 layout, ELV7 verified compliance or ELV8 product-selection claim is added.
