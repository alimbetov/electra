# P9 — Architecture reconciliation and stage handoff

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: P8 plus complete requirement/source/test evidence.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md).

Inherited implementation and mandatory new extensions: [baseline contract P9](implemented-baseline.md#p9); [pinned evidence](baseline.json). This contract supersedes the original design-only parent assumptions.

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P9-001 | Reconcile all 80 requirements and 27 registry processes to actual source/tests/versions | P9-T01 |
| ELV5-P9-002 | Audit all inherited/new mutation and query entry points for owner/scope/replay/transaction behavior | P9-T02 |
| ELV5-P9-003 | Verify no duplicated physical kernels, source budgets, cable length, loads/reserves or storage intervals | P9-T03 |
| ELV5-P9-004 | Verify inherited ELV4 acceptance and new ELV5 migration, hash, remapping and historical compatibility | P9-T04 |
| ELV5-P9-005 | Run required generation/format/analyzers/core/mobile/qualification at one exact source SHA | P9-T05 |
| ELV5-P9-006 | Disposition findings and unsupported scope without replacing a positive case by a blocked estimate | P9-T06 |
| ELV5-P9-007 | Publish explicit ELV6/ELV7/ELV8 handoff and technical claim limits | P9-T07 |
| ELV5-P9-008 | Record design/runtime acceptance, merge and CLOSED as separate evidenced events | P9-T08 |

## Concrete contract

Closure ledger links requirement/process ID, source path, test case, exact tested SHA, workflow/run/artifact, status and limitation. New source changes require renewed exact-head gate; a design-only checker or merge event is never runtime acceptance.

Zero open BLOCKER/HIGH at runtime closure; lower findings require explicit disposition/owner. All 27 codes must have implemented contract behavior, including supported positive technical basis and declared unsupported outcomes. For LAN-06/FA-08, required ELV5 basis dimensions remain distinct from ELV6 layout and ELV7 verified compliance; do not label those later dimensions successful.

ELV6 receives demand/assignment/enclosure inputs; ELV7 receives versioned policy/evidence and missing applicability; ELV8 receives technical capacities/margins/storage requirements without product selection. Historical and prerequisite baseline gates remain explicit until actual evidence closes them.

## Exit

P9 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

## Audit refinements

The initial technical audit found eight design defects, now SPEC_RESOLVED with explicit contracts and regression oracles. Keep that resolution distinct from runtime evidence. Close only with all corresponding implemented tests; signed optical loss/retention/channel/address/basis scope cannot be waived by a passing unrelated subtotal.
