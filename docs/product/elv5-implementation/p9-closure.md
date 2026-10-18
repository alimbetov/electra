# P9 — Architecture reconciliation and stage handoff

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P8 plus complete requirement/source/test/performance evidence.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [27-process code-level specification](process-code-level-specification.md); [oracle errata](calculation-oracle-errata-v1.md); [engineering primitives](engineering-primitives-contract.md); [typed process API](typed-process-api.md); [Flutter performance contract](flutter-performance-contract.md); [schema 24 contract](persistence-schema-contract.md); [qualification contract](qualification-contract.md); [command registry](command-registry.json); [canonical command examples](command-examples.json).

Inherited implementation and mandatory new extensions: [baseline contract P9](implemented-baseline.md#p9); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P9-001 | Reconcile all 80 requirements, 27 typed processes, 27 algorithm mappings, 27×25 dossiers, oracle errata, exact 16 public codecs and 54 primary process oracles to actual source/tests/versions | P9-T01 |
| ELV5-P9-002 | Audit all inherited/new mutation/query/calculation/executor entry points for owner/scope/replay/canonical-hash/transaction behavior | P9-T02 |
| ELV5-P9-003 | Verify no duplicated physical kernels, source budgets, cable/load/capability ownership, reserves, schedule/storage intervals or discipline-reduced shared totals | P9-T03 |
| ELV5-P9-004 | Verify inherited ELV4 acceptance and new ELV5 schema-24 migration/hash/remapping/historical compatibility | P9-T04 |
| ELV5-P9-005 | Run design guards/generation/format/analyzers/core/mobile/L0–L6/135-vector/performance qualification at one exact source SHA | P9-T05 |
| ELV5-P9-006 | Disposition findings and unsupported scope without replacing positive technical qualification by blocked/estimated shortcuts | P9-T06 |
| ELV5-P9-007 | Publish explicit ELV6/ELV7/ELV8 handoff and technical claim limits | P9-T07 |
| ELV5-P9-008 | Record design acceptance, runtime acceptance, performance acceptance, merge and CLOSED as separate evidenced events | P9-T08 |

## Closed inventories

P9 reconciles these closed inventories at one runtime SHA:

1. **80** stable requirements from `requirements.json`;
2. exactly **27** typed process definitions matching `process-registry.json`;
3. exactly **27** algorithm mappings matching `algorithm-registry.json`;
4. exactly **25 mandatory code-level sections per process** across the four dossier files;
5. exactly **5 vector classes per process**: positive, boundary, negative, adversarial, cross-discipline;
6. authority-controlled reference-oracle corrections, including ACS-03 `23.51 V / +1.51 V`;
7. exactly **16** public discipline operations matching `command-registry.json` and production semantic codecs/handlers;
8. canonical valid/rejection command examples matching exact payload key sets;
9. schema **24** migration/table/index/ownership inventory;
10. exactly **54** primary POS/NEG/unsupported public process entries;
11. at least **135 process-vector cases** total from the five vector classes;
12. engineering primitive/canonical-hash and unified-solver test inventory;
13. worker/executor/incremental-cache/cancellation/UI performance inventory;
14. failure-injection/race/freeze/restart/historical qualification inventory;
15. complete requirement/process/command/source/test/performance evidence ledger.

Any extra runtime codec, undocumented operation, missing typed process, missing dossier behavior, unapplied oracle erratum, changed payload key, unregistered table owner, missing primary oracle/vector or undocumented executor shortcut is an architecture defect.

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
- every process implements its dossier equation/boundary/worst-case/governing/limiting/trace/complexity semantics and any applicable higher-authority oracle correction;
- medium/large native kernels run through the qualified executor outside the Flutter UI isolate;
- web execution does not rely on `compute()` as native-style parallelism;
- parallel worker count/completion order cannot change deterministic output hashes or canonical result ordering;
- incremental invalidation recalculates only the typed affected closure; there is no production “recalculate everything” fallback;
- semantic cache keys include authority and full canonical input meaning;
- stale/cancelled worker work cannot advance CURRENT;
- capture/publish uses bounded bulk queries/indexes and no N+1 scale regression;
- large UI collections are virtualized and one result change does not rebuild the whole engineering workspace;
- multi-node calculation publication is coherent and atomic;
- old immutable evaluations stay attached to old revision provenance after create-next.

## Exact-head closure ledger

Closure evidence links at least:

```text
requirementId / processCode / algorithm mapping / dossier section / errata ref / command operation / oracle/vectorId
production source path + symbol
runtime schema/algorithm/input/output/numeric/canonical versions
workload/complexity/resource profile
executed test path + exact test name
fixture/manifest entry
exact tested git SHA
authority fingerprint
workflow run/job/artifact identity
PASS/FAIL/BLOCKED status
known claim limitation / downstream owner
```

Performance evidence additionally links device/platform profile, Flutter/Dart versions, refresh rate, cardinalities and profile-mode metrics. Evidence generated at another SHA or authority fingerprint cannot silently close current HEAD.

## Required exact-head gate

At the accepted source SHA, all of the following pass without ignored failures:

- no-generated-artifact guard and inherited ELV3/ELV4 baseline guards;
- ELV5 27-process/80-requirement specification guard;
- exact 27 algorithm mappings;
- exact 27×25 process-dossier guard with zero placeholders;
- oracle-integrity guard proving corrected ACS-03 `23.51 V / +1.51 V` fixture;
- exact 16-command registry guard;
- canonical command-example guard;
- engineering/third/fourth-pass hardening guards;
- authority manifest over the complete active chain;
- Drift schema-24 generation/migration/query-plan checks;
- formatting;
- mobile/core analyzers;
- complete mobile/core tests;
- L0 primitive/hash tests;
- L1 all typed process kernels plus dossier boundary/adversarial vectors;
- L2 all 16 command adversarial/replay tests;
- L3 schema-24 migration/reopen matrix;
- L4 UoW/history/failure-injection/executor scheduling matrix;
- L5 all 54 public process vertical entries and required cross-discipline vectors;
- L6 deterministic DB/worker races, cancellation/supersession, freeze/historical matrix;
- all **135 process-vector cases** mapped to dossier sections;
- 500-node workerCount=1 versus N deterministic batch proof;
- incremental affected/recomputed-node proof;
- semantic cache hit/miss proof;
- profile-mode scale/performance artifact and targeted UI rebuild/virtualization proof;
- frozen R1/create-next R2 historical immutability proof;
- closure-ledger reconciliation with no evidence pointing to a different SHA/fingerprint.

A later source or normative documentation change invalidates exact-head closure until the full affected gate is rerun.

## Runtime finding policy

P9 requires zero open BLOCKER/HIGH. Lower findings require explicit disposition and owner. No finding may be “closed” by weakening required dimensions, removing a positive/boundary/adversarial oracle, replacing a guaranteed requirement with an estimate, moving a defect into localized UI text or disabling a performance/worker test.

Historical specification audit ledger:

```text
initial discipline audit:                   8 findings SPEC_RESOLVED
second engineering/architecture audit:     14 findings SPEC_RESOLVED
third production-readiness audit:          15 findings SPEC_RESOLVED
fourth algorithm/performance/oracle audit: 19 findings SPEC_RESOLVED
-----------------------------------------------------------------
total specification findings resolved:    56
```

These are design resolutions, not runtime fixes. Every corresponding runtime obligation still requires executable proof.

## Handoff boundaries

### ELV6
Receives rack/enclosure demand, RU/weight/depth evidence, equipment memberships and technical margins. ELV5 never claims U-position, clearance, thermal/ventilation, cable-management or real cabinet fit.

### ELV7
Receives exact policy/evidence refs, applicability gaps, technical policy matches and claim limitations. ELV5 never converts fictional/project policy match or ACS/fire topology into verified jurisdictional compliance.

### ELV8
Receives required capacities/margins/storage/ports/resources and qualification evidence. ELV5 never selects commercial SKU/BOM/quote/procurement results.

## No-false-PASS closure sentinels

P9 checks explicit P8 tests preventing:

```text
unsupported model -> PASS
missing required evidence -> PASS
uncertain interval crossing threshold -> PASS
typical/estimated -> guaranteed PASS
stale/cancelled worker result -> CURRENT
what-if result -> CURRENT without committed mutation
fictional policy -> verified compliance
rack RU basis -> actual layout fit PASS
camera geometry -> obstruction/DORI/legal identification claim
optical power budget -> reach/dispersion claim without model
ACS release topology -> verified egress/fire compliance
ELV5 discipline subtotal -> global shared-source total
legacy snapshot -> ELV5 captured/current PASS
old evaluation -> new-revision retag
worker completion order -> changed deterministic output
incorrect reference oracle -> accepted golden test
```

Any sentinel failure blocks closure.

## Acceptance event separation

P9 records separate events:

```text
design specification hardened
runtime implemented
runtime exact-head functional qualification accepted
profile-mode performance qualification accepted
PR/merge accepted
stage CLOSED
```

A merge event never retroactively creates missing runtime or performance qualification.

## Exit

P9 runtime acceptance requires all P9-T01…T08 at the same exact source SHA and authority fingerprint, with zero open BLOCKER/HIGH, complete L0–L6 evidence, 135 process-vector coverage, applicable oracle errata tests and accepted performance artifact.

This document is a design contract, not proof that runtime implementation has started or passed.
