# P8 — Integrated verification and qualification

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P0–P7 implemented prerequisites.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [code-level runtime contract](code-level-runtime-contract.md); [unified calculation engine](calculation-engine-contract.md); [algorithm registry](algorithm-registry.json); [executable qualification contract](qualification-contract.md).

Inherited implementation and mandatory new extensions: [baseline contract P8](implemented-baseline.md#p8); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P8-001 | Implement FK-valid public-command integrated fixtures for all disciplines plus real shared-source contexts | P8-T01 |
| ELV5-P8-002 | Execute all **54** primary POS/NEG/unsupported process entries with required dimension/claim-scope manifest | P8-T02 |
| ELV5-P8-003 | Prove exact schema-24 roots/snapshots/evaluations/policies/assignments after file-SQLite close/reopen | P8-T03 |
| ELV5-P8-004 | Freeze R1, create/remap R2, change profiles/routes/states and prove immutable R1 results/hashes | P8-T04 |
| ELV5-P8-005 | Inject durable failure checkpoints and verify same-open/reopened atomic rollback including history/ledger | P8-T05 |
| ELV5-P8-006 | Prove response-loss replay/payload conflict and deterministic two-connection edit/publish/freeze/adoption races | P8-T06 |
| ELV5-P8-007 | Verify supported migrations through schema 24 and mixed legacy/ELV3/ELV4/ELV5 result-owner isolation | P8-T07 |
| ELV5-P8-008 | Assert affected/unaffected sets, exact arithmetic/provenance, 27 algorithm mappings, governing/margin/limiting/trace invariants and all no-false-PASS sentinels | P8-T08 |

## Normative qualification contract

The complete test architecture is [qualification-contract.md](qualification-contract.md). P8 implements its seven layers:

```text
L0 primitive / exact numeric / canonical hash
L1 pure typed process kernels + unified solver protocol
L2 strict wire codecs / semantic rejection
L3 schema 24 / persistence / migration / restart
L4 application UoW / replay / history / failure injection
L5 public-command vertical qualification
L6 deterministic concurrency / freeze / historical matrix
```

No single layer substitutes for another. In particular, formula tests, registry checks and JSON examples do not close a public vertical.

## Qualification manifest

P8 MUST introduce:

```text
docs/product/elv5-implementation/qualification-manifest.json
schema = electra.elv5-qualification-manifest.v1
```

The manifest contains **exactly 54 primary process entries**: POS plus NEG/unsupported for every one of the 27 process codes.

Each entry includes at least:

```text
processCode
oracleId
fixtureId
setupCommandIds
calculationCommandId
scope
subject
operatingCaseId
requiredDimensions
expectedExecution
expectedCompletion
expectedAssessment
expectedDimensionStatuses
expectedFindingCodes
expectedAffectedProcessCodes
expectedUnaffectedProcessCodes
claimScope
sourceBasisExpectations
publicSetupOnly
```

Tests read the manifest and fail if process registry membership, algorithm registry membership, required dimensions or expected status inventory diverges.

## Public vertical path

Every primary oracle executes:

```text
strict public setup commands
  -> file SQLite persisted roots + canonical ELV3/ELV4 facts
  -> CALCULATE_DISCIPLINE_PROCESS
  -> production capture resolver
  -> typed process + algorithm registry
  -> applicability/input normalization/operating-case builder
  -> pure deterministic kernel
  -> requirement composition + conservative comparisons
  -> governing case / limiting factor / margin / trace
  -> guarded coherent publication
  -> engineer projection/read API
  -> close DB
  -> reopen DB
  -> verify immutable evidence/current pointer/explanation
```

A direct call to `calculate()` is L1 evidence only.

## Unified calculation-engine qualification

P8 treats [calculation-engine-contract.md](calculation-engine-contract.md) as executable behavior, not presentation guidance.

Required cross-process tests:

1. `algorithm-registry.json` contains exactly the same 27 codes as `process-registry.json`, exactly once each;
2. every registered solver family is code-owned and known to runtime;
3. every multi-case process emits a deterministic governing case, or an explicit typed reason why no governing case applies;
4. every resolved finite capacity/limit comparison emits a signed margin with **positive = acceptable headroom** convention;
5. every limiting factor is stable under unrelated project mutations and deterministic after restart/replay;
6. interval comparison uses the conservative edge; overlap at a required threshold cannot silently PASS;
7. manufacturer-typical/estimated evidence cannot satisfy a guaranteed-bound comparison;
8. calculation step equation codes, operand order and typed results are deterministic and participate in output hashing where specified;
9. optional sensitivity/what-if calculations cannot publish CURRENT authoritative evidence unless the corresponding input mutation was actually committed;
10. two ELV5 wrappers consuming the same exact ELV4 physical result preserve the same upstream evaluation ID/hash and cannot create discipline-reduced physical totals;
11. host locale/timezone changes do not alter deterministic kernel output, input fingerprint or output hash;
12. a process-specific kernel cannot bypass centralized verdict derivation to turn PARTIAL/BLOCKED/UNRESOLVED into PASS.

## Exact wire/codec qualification

The initial ELV5 runtime has exactly 16 public discipline command codecs under `electra.elv5-discipline-command.v1`. P8 proves for every operation:

1. exactly one registered codec and no extra/missing codec;
2. canonical valid example;
3. missing/unknown top-level field rejection;
4. wrong top-level type and unsupported schema/operation/version rejection;
5. missing/unknown/wrong-type nested payload rejection;
6. semantic duplicate/foreign identity rejection;
7. server-side reviewed impact resolution;
8. same command ID + same canonical request hash replay after state changed;
9. same command ID + different canonical request hash conflict;
10. atomic rollback of root/members/dependencies/history/ledger after injected failure and reopen.

Hardened operation coverage specifically includes:

- CCTV stream subscriptions + transport overhead model ref;
- recording temporal policy/tzdb/rules-evidence/reserve/redundancy/policy basis;
- ACS safety mode + release truth table.

## Engineering primitive qualification

P8 executes L0 regression coverage from [engineering-primitives-contract.md](engineering-primitives-contract.md), including:

- dB vs dBm type separation;
- exact bit/s→byte arithmetic and process-boundary ceil;
- rational/decimal normalization;
- guaranteed vs typical/estimated evidence basis;
- reserve distinct from uncertainty/evidence certainty;
- stable canonical hash under unordered map/set insertion order;
- ordered path/sequence hash sensitivity;
- output hash independence from evaluation ID/timestamp;
- deterministic timezone/DST captured-rules policy;
- mixed coordinate-frame rejection without captured transform.

## Process qualification highlights

### CCTV

P8 includes bounded H/V FOV, frame mismatch, unicast/multicast copy accounting, governing-edge peak utilization, payload-vs-wire-rate separation, schedule union/tzdb, expected-vs-guaranteed retention, one-time reserve/redundancy, channel-accounting alternatives, recorder limiting dimension and shared PWR-06 contribution evidence.

### LAN

P8 includes exact-limit/over-limit link lengths, spare ceilings, weakest-section compatibility with limiting-section identity, bidirectional sensitivity/overload with smallest signed optical margin, dB/dBm separation, optional reach claim isolation, rack gross/net equivalence and ELV6 layout `NOT_ASSESSED` sentinel.

### ACS

P8 includes role alternatives, separate resource pools, holding/active/startup shared-trunk cases, shared supply/bank, governing temporal event and ACS-06 truth-table cases for:

```text
NORMAL_ACCESS
REQUEST_TO_EXIT
FIRE_RELEASE
EMERGENCY_BREAK_GLASS
POWER_FAILURE
```

with at least one fail-safe and one fail-secure/project-defined fixture. Technical topology evidence never becomes verified legal/egress compliance.

### Fire

P8 includes expanded address-set collisions, partial standby/alarm/startup evidence, supported-vs-unsupported electrical model, complete shared source/bank loads, explicit standby/alarm durations, governing energy/current segment, notification active/startup current + terminal voltage, signal-loop closure/branch/fault-state policy and policy-match-vs-certified-compliance separation.

## Persistence/restart proof

All P2/P7/P8 persistence evidence uses real temporary file SQLite. After close/reopen assert exact preservation of:

- all schema-24 roots and ordered member sets;
- camera subscriptions;
- recording temporal/reserve/redundancy basis;
- ACS release truth table;
- immutable policy refs/hashes;
- command ledger canonical request/logical response evidence;
- complete forward/inverse history and cursor;
- immutable evaluation input/output hashes;
- operating-case results, governing-case codes, limiting factors and deterministic trace projection required by the result schema;
- pointer generation/freshness/evaluation IDs;
- reverse dependency keys including SET/MISSING/selector markers;
- snapshot discipline section and manifest `disciplineHash`.

In-memory-only tests cannot close P2/P7/P8.

## Failure injection

For replacement commands, failure probes cover transaction boundaries after replay, root write, child replacement, invalidation, history append and ledger save. Every injected failure is checked after reopen and must leave the previous committed aggregate intact. No hybrid old/new member set is allowed.

## Deterministic concurrency

Use explicit barriers/hooks, not sleeps as correctness synchronization. Required races include:

- capture → relevant edit → publish conflict/no stale CURRENT;
- capture → unrelated edit → publish allowed when all consumed fingerprints/generations are unchanged;
- two publishers from the same pointer generation: at most one advances from that generation;
- capture → policy adoption → stale/conflict;
- shared ELV4 pointer generation change → exact dependent wrappers stale/conflict;
- capture → freeze → late publish rejected;
- replace vs replace same aggregate → one deterministic conflict, no hybrid members;
- undo/redo vs new edit → cursor-generation conflict;
- response loss after commit → same-hash replay returns stored logical result;
- create-next vs old-revision late publish → no retagging/new-revision contamination.

A multi-node `CALCULATE_DISCIPLINE_PROCESS` publish is all-or-nothing for the requested coherent batch.

## Migration and owner isolation

Migration tests cover:

```text
fresh schema 24
accepted 23 -> 24
supported historical origin -> existing chain -> 23 -> 24
failed migration rollback/reopen
legacy snapshot -> ELV5_NOT_CAPTURED
new empty discipline section -> CAPTURED_EMPTY
```

Historical legacy rows, ELV4 power rows and new ELV5 discipline rows coexist. Generic readers dispatch by explicit owner/schema and never decode or retag one store as another.

Recorder capability ownership is explicitly checked: capability facts resolve from one exact immutable canonical catalog/component definition; ELV5 does not become a second editable capability source.

## No-false-PASS sentinels

P8 must fail if runtime ever produces any of these implications:

```text
unsupported model -> PASS
missing mandatory input -> PASS
interval overlaps threshold -> PASS without an explicit supported comparison rule
typical/estimated evidence -> guaranteed-bound PASS
stale old PASS -> current PASS
fictional/project policy -> verified jurisdictional compliance
LAN-06 RU basis -> actual rack fit PASS
FA-08 policy match -> certified fire compliance
CCTV geometry -> visibility through obstruction
CCTV pixel density -> DORI/legal identification claim
optical power budget -> reach/dispersion PASS without reach model
ACS release topology -> verified legal egress compliance
ELV5 discipline contribution -> shared physical source total
what-if result -> CURRENT without committed input mutation
old immutable evaluation -> retagged into new revision
legacy pre-ELV5 snapshot -> captured-empty/current PASS
```

Any false-PASS sentinel is closure-blocking.

## Scale fixture

P8 executes deterministic supported-scale fixtures from the qualification contract, including 1000 streams, 10000 schedule segments, 5000 LAN assignments, 2000 ACS assignments, 10000 fire address claims and a 500-node workspace batch. Benchmark evidence is recorded without inventing an unmeasured production millisecond SLO.

## Exit

P8 closes only from executed public-command, file-SQLite, restart, migration, failure-injection, unified-engine invariant, race/freeze and 54-process-oracle evidence at one tested source SHA and matching authority fingerprint.

Structural design validators—including the ELV5 specification/registry/example/hardening/calculation-engine CI guards—prove design consistency only. They cannot be cited as runtime implementation acceptance.
