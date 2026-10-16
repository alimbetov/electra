# P9 — Architecture reconciliation and stage handoff

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P8 plus complete requirement/source/test evidence.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [engineering primitives](engineering-primitives-contract.md); [typed process API](typed-process-api.md); [schema 24 contract](persistence-schema-contract.md); [qualification contract](qualification-contract.md); [command registry](command-registry.json); [canonical command examples](command-examples.json).

Inherited implementation and mandatory new extensions: [baseline contract P9](implemented-baseline.md#p9); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P9-001 | Reconcile all 80 requirements, 27 typed processes, exact 16 public codecs and 54 primary process oracles to actual source/tests/versions | P9-T01 |
| ELV5-P9-002 | Audit all inherited/new mutation/query entry points for owner/scope/replay/canonical-hash/transaction behavior | P9-T02 |
| ELV5-P9-003 | Verify no duplicated physical kernels, source budgets, cable/load/capability ownership, reserves or storage intervals | P9-T03 |
| ELV5-P9-004 | Verify inherited ELV4 acceptance and new ELV5 schema-24 migration/hash/remapping/historical compatibility | P9-T04 |
| ELV5-P9-005 | Run design guards/generation/format/analyzers/core/mobile/L0–L6 qualification at one exact source SHA | P9-T05 |
| ELV5-P9-006 | Disposition findings and unsupported scope without replacing positive technical qualification by blocked/estimated shortcuts | P9-T06 |
| ELV5-P9-007 | Publish explicit ELV6/ELV7/ELV8 handoff and technical claim limits | P9-T07 |
| ELV5-P9-008 | Record design acceptance, runtime acceptance, merge and CLOSED as separate evidenced events | P9-T08 |

## Closed inventories

P9 must reconcile these closed inventories at one runtime SHA:

1. **80** stable requirements from `requirements.json`;
2. exactly **27** typed process definitions matching `process-registry.json`;
3. exactly **16** public discipline operations matching `command-registry.json` and runtime semantic codecs;
4. canonical valid/rejection examples matching those exact 16 payload key sets;
5. schema **24** migration/table/index/ownership inventory;
6. exactly **54** primary POS/NEG/unsupported public process entries from `qualification-manifest.json`;
7. engineering primitive/canonical-hash test inventory;
8. failure-injection/race/freeze/restart/historical qualification inventory;
9. complete requirement/process/command/source/test evidence ledger.

Any extra runtime codec, undocumented operation, missing typed process, changed payload key, unregistered table owner or missing primary oracle is an architecture defect, not an implementation detail.

## Architecture reconciliation

P9 explicitly verifies:

- no process kernel accepts a generic semantic `Map<String,Object?>` where a typed input is required;
- no dB/dBm or bit/s/byte-capacity dimension collapse exists in production APIs;
- expected/typical/estimated evidence cannot satisfy guaranteed-bound requirements;
- no host timezone/locale/map iteration order affects deterministic engineering result/hash;
- recorder/VMS capability comes from one exact immutable canonical definition rather than ELV5-authored duplicate limits;
- no ELV5 table becomes canonical owner of ELV3/ELV4 cable/port/component/source/battery/revision/history identities;
- shared source/bank/PSE physical evidence is reused rather than recalculated per discipline;
- reserve/derating/redundancy/loss/accounting factors are applied at exactly one declared boundary;
- multi-node calculation publication is coherent and atomic;
- old immutable evaluations stay attached to old revision provenance after create-next.

## Exact-head closure ledger

Closure evidence links at least:

```text
requirementId/processCode/command operation/oracleId
production source path + symbol
runtime schema/algorithm/input/output/numeric/canonical versions
executed test path + exact test name
fixture/manifest entry
exact tested git SHA
workflow run/job/artifact identity
PASS/FAIL/BLOCKED status
known claim limitation / downstream owner
```

Evidence generated at another SHA cannot silently close current HEAD.

## Required exact-head gate

At the accepted source SHA, all of the following pass without ignored failures:

- no-generated-artifact guard and inherited ELV3/ELV4 baseline guards;
- ELV5 27-process/80-requirement specification guard;
- exact 16-command registry guard;
- canonical command-example guard;
- engineering hardening structural guard;
- Drift schema-24 generation/migration checks;
- formatting;
- mobile/core analyzers;
- complete mobile/core tests;
- L0 primitive/hash tests;
- L1 all typed process kernels;
- L2 all 16 command adversarial/replay tests;
- L3 schema-24 migration/reopen matrix;
- L4 UoW/history/failure-injection matrix;
- L5 all 54 public process vertical entries;
- L6 deterministic concurrency/freeze/historical matrix;
- frozen R1/create-next R2 historical immutability proof;
- closure-ledger reconciliation with no evidence pointing to a different SHA.

A later source or normative documentation change invalidates exact-head closure until the gate is rerun on the new HEAD.

## Runtime finding policy

P9 requires zero open BLOCKER/HIGH. Lower findings require explicit disposition and owner. No finding may be “closed” by weakening required dimensions, removing a positive oracle, replacing a guaranteed requirement with an estimate, or moving a defect into localized UI text.

The two design audits remain historical evidence:

```text
initial discipline audit: 8 findings SPEC_RESOLVED
second engineering/architecture hardening audit: 14 findings SPEC_RESOLVED
total specification findings resolved: 22
```

Every corresponding runtime obligation must still be proven in executable tests.

## Handoff boundaries

### ELV6

Receives rack/enclosure demand, RU/weight/depth evidence, equipment memberships and technical margins. ELV5 must not claim U-position, clearance, thermal/ventilation, cable-management or real cabinet fit.

### ELV7

Receives exact policy/evidence refs, applicability gaps, technical policy matches and claim limitations. ELV5 must not convert fictional/project policy match or ACS/fire topology into verified jurisdictional compliance.

### ELV8

Receives required capacities/margins/storage/ports/resources and qualification evidence. ELV5 must not select commercial SKU/BOM/quote/procurement results.

## No-false-PASS closure sentinels

P9 checks that P8 contains explicit tests preventing:

```text
unsupported model -> PASS
missing required evidence -> PASS
stale PASS -> current PASS
fictional policy -> verified compliance
rack RU basis -> actual layout fit PASS
camera geometry/pixel density -> obstruction/DORI/legal identification claim
optical power budget -> reach/dispersion claim without model
ACS release topology -> verified egress/fire compliance
ELV5 subtotal -> global shared-source total
legacy snapshot -> ELV5 captured/current PASS
old evaluation -> new-revision retag
```

Any sentinel failure blocks closure.

## Acceptance event separation

P9 records these as separate events:

```text
design specification hardened
runtime implemented
runtime exact-head qualification accepted
PR/merge accepted
stage CLOSED
```

A merge event never retroactively creates missing runtime qualification.

## Exit

P9 runtime acceptance requires all P9-T01…T08 at the same exact source SHA, with zero open BLOCKER/HIGH and complete L0–L6 evidence.

This document is a design contract, not proof that runtime implementation has started or passed.
