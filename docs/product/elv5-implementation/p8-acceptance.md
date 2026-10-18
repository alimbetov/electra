# P8 — Integrated verification and qualification

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P0–P7 implemented prerequisites.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [code-level runtime contract](code-level-runtime-contract.md); [unified calculation engine](calculation-engine-contract.md); [algorithm registry](algorithm-registry.json); [27-process code-level specification](process-code-level-specification.md); [Flutter performance contract](flutter-performance-contract.md); [executable qualification contract](qualification-contract.md).

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
| ELV5-P8-008 | Assert affected/unaffected sets, exact arithmetic/provenance, 27 algorithm mappings, 27×25 dossier semantics, governing/margin/limiting/trace invariants, performance execution rules and all no-false-PASS sentinels | P8-T08 |

## Normative qualification contract

The complete test architecture is [qualification-contract.md](qualification-contract.md). P8 implements its seven layers:

```text
L0 primitive / exact numeric / canonical hash
L1 pure typed process kernels + unified solver protocol + dossier vectors
L2 strict wire codecs / semantic rejection
L3 schema 24 / persistence / migration / restart
L4 application UoW / replay / history / failure injection / executor scheduling
L5 public-command vertical qualification
L6 deterministic concurrency / worker determinism / freeze / historical matrix
```

No single layer substitutes for another. In particular, formula tests, registry checks and JSON examples do not close a public vertical.

## Qualification manifest

P8 MUST introduce:

```text
docs/product/elv5-implementation/qualification-manifest.json
schema = electra.elv5-qualification-manifest.v1
```

The manifest contains **exactly 54 primary process entries**: POS plus NEG/unsupported for every one of the 27 process codes.

Each primary entry includes at least:

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

## Fourth-pass process-vector matrix

The **54 primary entries do not change**. The 27 code-level dossiers add mandatory boundary/adversarial/cross-discipline vectors.

Required minimum inventory:

```text
27 positive vectors     -> satisfied by the 27 primary POS entries
27 negative vectors     -> satisfied by the 27 primary NEG/unsupported entries
27 boundary vectors     -> supplemental
27 adversarial vectors  -> supplemental
27 cross-discipline     -> supplemental
-----------------------------------------
135 process-vector cases total
```

A supplemental vector may execute at L1 when it tests pure numerical algebra only, but vectors that exercise persistence, dependency closure, shared ELV4 evidence, publication or stage ownership MUST execute through the public-command/file-SQLite path at L5/L6.

The test harness maps every vector to the matching dossier section and fails if a dossier vector has no executable test ID.

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
12. a process-specific kernel cannot bypass centralized verdict derivation to turn PARTIAL/BLOCKED/UNRESOLVED into PASS;
13. each process implementation satisfies every section 6–19 mathematical/algorithmic assertion in its matching dossier;
14. every boundary vector proves exact inclusivity/rounding/interval behavior without UI-display rounding affecting verdict;
15. every adversarial vector proves duplicate/alias/reordering/stale/false-evidence input cannot manufacture capacity or PASS;
16. every cross-discipline vector proves shared ELV3/ELV4 facts remain single-owner and ELV6/7/8 claims are not stolen by ELV5.

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

P8 includes bounded H/V FOV, frame mismatch, unicast/multicast copy accounting, governing-edge peak utilization, payload-vs-wire-rate separation, schedule union/tzdb, expected-vs-guaranteed retention, single pool-level reserve/ceil/redundancy behavior, channel-accounting alternatives, recorder limiting dimension and shared PWR-06 contribution evidence.

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

## Flutter/executor performance qualification

[flutter-performance-contract.md](flutter-performance-contract.md) is executable acceptance behavior.

### Native worker scheduling

Required tests:

1. `medium` and `large` production workloads never execute through the inline executor on supported native platforms;
2. `tiny/small` inline execution is allowed only for code-owned classes and only after profile evidence stays within the UI synchronous-slice target;
3. long-lived worker executor accepts only sendable pure captured DTO/value graphs—no Drift rows, DB handles, Flutter state or widgets;
4. worker crash/exception cannot partially publish a coherent batch;
5. deterministic technical FAIL is a result, not a worker exception/retry condition.

### Parallel determinism

For the same captured 500-node batch:

```text
workerCount=1
workerCount=N
randomized artificial task completion delays
```

MUST yield identical:

- per-node deterministic output hashes;
- governing cases;
- limiting factors;
- dimension statuses/findings;
- canonical calculation trace per node;
- canonical batch result ordering/hash.

Only wall-clock/timeline scheduling evidence may differ.

### Incremental recomputation

Mutation fixtures assert exact affected node set and recomputed node set. Production strategy “recalculate all 27 processes/all subjects after any edit” is forbidden.

Required cases include:

- one stream bitrate change affects only dependent CCTV-02/03/05 and exact downstream closures;
- one LAN path change invalidates exact path-dependent CCTV/LAN nodes but not unrelated doors/fire loops;
- new selector-matching fact invalidates nodes even if the fact did not exist during prior capture;
- unrelated metadata/display edit changes zero engineering input fingerprints and triggers zero kernel recomputation.

### Cancellation, supersession and backpressure

Use explicit scheduler hooks/barriers:

```text
queue generation 10
edit creates generation 11
before gen10 starts -> gen10 dropped
while gen10 runs -> completion may be cached by exact fingerprint but cannot publish CURRENT
rapid generations 12..100 -> pending work coalesces, queue stays bounded
```

No sleeps as correctness synchronization.

### Semantic cache

Same full key `(processCode, algorithm/input/output/numeric versions, authority fingerprint, canonical input fingerprint)` may reuse deterministic result. Tests mutate one key constituent at a time and prove cache miss when semantics change.

Mandatory miss cases include policy edition, timezone rules hash, frame transform hash, evidence basis/uncertainty, operating case and consumed upstream output hash.

### Capture/publish database performance

Instrumented repository fixtures assert bounded bulk access and no N+1 explosion at scale. Query-plan evidence verifies required indexes on high-cardinality revision/scope/member/dependency/pointer paths.

CPU-heavy kernel work MUST occur after capture transaction closes and before short guarded publish transaction opens.

### UI/render performance

Profile-mode evidence is required; debug-mode timing is rejected.

Acceptance includes:

- active target refresh frame budget (approximately 16.67 ms at 60 Hz, 8.33 ms at 120 Hz) for UI and raster work;
- p99 synchronous engineering-related UI orchestration slice target `<= min(2 ms, 25% of refresh interval)` on qualified test device/profile;
- no engineering arithmetic/SQLite access in widget `build()`;
- targeted process-card rebuild test proving one result update does not rebuild the entire workspace;
- lazy/virtualized rendering for large finding/member/trace lists;
- representative scrolling/expansion during background recalculation without jank regression.

### Web qualification

Web is qualified separately. Tests must prove the runtime does not assume Flutter `compute()` provides native isolate parallelism. Large web workload bounds/chunk/yield behavior are explicit; unqualified very-large workload may be rejected/degraded rather than freezing the page.

## Performance evidence artifact

P8 produces exact-head machine-readable performance evidence containing at least:

```text
sourceSha
authorityFingerprint
flutterVersion
dartVersion
platform/device profile
refreshRate
fixtureId
process/batch cardinalities
capture duration
worker queue duration
kernel duration
publish duration
workspace projection duration
UI/raster frame percentiles
memory high-water mark where measurable
cache hit/miss counts
affected node count
recomputed node count
```

Measured timing is not part of deterministic engineering hashes.

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

Calculation/executor failure probes additionally cover:

- worker exception before any result;
- one node exception after sibling nodes completed in memory;
- cancellation before/between topological levels;
- stale dependency generation discovered at publish;
- pointer-generation conflict during publish;
- storage failure after some immutable evaluation inserts but before pointer advance, proving transaction rollback leaves no partially current batch.

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
- create-next vs old-revision late publish → no retagging/new-revision contamination;
- old worker batch completion → newer edit/capture generation → old batch cannot publish;
- two independent worker nodes finish in opposite orders → canonical batch output unchanged.

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

P8 executes deterministic supported-scale fixtures from the qualification/performance contracts, including:

```text
1000 CCTV streams
10000 recording schedule segments
5000 LAN assignments
2000 ACS assignments
10000 fire address claims
5000 dependency edges
500-node coherent calculation batch
```

Scale tests prove the dossier complexity model, resource bounds, affected-node planning, worker determinism, bounded capture/publish and UI responsiveness. They record measured evidence without inventing an unmeasured production kernel-duration SLO.

## Exit

P8 closes only from executed public-command, file-SQLite, restart, migration, failure-injection, unified-engine invariant, **135 process-vector cases**, worker/performance evidence, race/freeze and 54-primary-process-oracle evidence at one tested source SHA and matching authority fingerprint.

Structural design validators—including the ELV5 specification/registry/example/hardening/calculation-engine/process-dossier CI guards—prove design consistency only. They cannot be cited as runtime implementation acceptance.
