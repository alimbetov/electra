# ELV5 — P0–P9 delivery plan

Status: DESIGN HARDENED / ALL RUNTIME PACKAGES NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent: ELV4 `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`.
Authority: [authoritative design index](elv5-authoritative-spec-index.md); [governing design](elv5-discipline-calculations-design-specification.md); [implementation contracts](elv5-implementation/README.md).

Implementation obeys the explicit authority precedence, including [third-pass hardening](elv5-implementation/code-level-hardening-v2.md), the [27-process code-level specification](elv5-implementation/process-code-level-specification.md), all four process dossier files, [calculation oracle errata](elv5-implementation/calculation-oracle-errata-v1.md) and the [Flutter performance contract](elv5-implementation/flutter-performance-contract.md). Runtime remains deliberately NOT_STARTED: specification hardening is not implementation evidence.

| Package | Scope | Depends on |
|---|---|---|
| P0 | [Baseline and stage integration](elv5-implementation/p0-baseline.md) | Existing ELV1–ELV4 source/design/evidence; complete authority manifest/ownership reconciliation |
| P1 | [Typed discipline profiles and process registry](elv5-implementation/p1-profiles-registry.md) | P0; typed identities/fields/quantities, exact arithmetic, common solver/result/trace types, workload metadata |
| P2 | [Persistence, command boundaries and revision evidence](elv5-implementation/p2-persistence-commands.md) | P1 plus shared command/history/revision platform; additive schema 24; bounded bulk capture/publish |
| P3 | [CCTV calculation implementation](elv5-implementation/p3-cctv.md) | P1/P2, ELV3 routes, exact ELV4 evidence, CCTV 25-section dossiers |
| P4 | [LAN and structured-cabling implementation](elv5-implementation/p4-lan.md) | P1/P2, ELV3 lengths/resources, exact PWR-06, LAN dossiers |
| P5 | [Access-control implementation](elv5-implementation/p5-acs.md) | P1/P2, canonical assemblies, shared power kernels, ACS dossiers + oracle errata |
| P6 | [Fire-alarm implementation](elv5-implementation/p6-fire.md) | P1/P2, signal topology, supported electrical/fault models, Fire dossiers |
| P7 | [Incremental dependencies and engineer workspace](elv5-implementation/p7-dependencies-workspace.md) | P1/P2 foundations; integrates P3–P6, executor scheduling, selector-aware invalidation and targeted UI projection |
| P8 | [Integrated verification and qualification](elv5-implementation/p8-acceptance.md) | P0–P7 implemented; 54 primary verticals, 135 process vectors, worker/performance suites |
| P9 | [Architecture reconciliation and stage handoff](elv5-implementation/p9-closure.md) | P8 plus exact-head functional/performance/manifest evidence |

## 1. Frozen inventories

```text
80 stable package requirements
27 process codes = CCTV-01..06 + LAN-01..07 + ACS-01..06 + FA-01..08
27 algorithm mappings
25 mandatory code-level dossier sections per process
5 process vector classes = positive/boundary/negative/adversarial/cross-discipline
16 public ELV5 discipline command operations
schema 23 inherited -> additive schema 24 target
engineering-node-v3 / owner ELV5 result identity
canonical encoder electra.canonical-json.v1
54 primary P8 process entries = POS + NEG/unsupported for every process
135 total process-vector cases minimum
authority-controlled oracle errata, currently ACS-03 = 23.51 V / +1.51 V
shared ELV4 freeze/create-next command boundary
shared command ledger/history/UoW platform
```

Four audit passes have resolved **56 design findings** in specification: 8 + 14 + 15 + 19. None is a runtime fix.

## 2. Implementation sequence

Foundation-first sequence:

```text
P0 exact baseline + authority fingerprint
  -> P1 primitives / identities / common solver-result-trace / workload metadata
  -> P2 schema24 / repositories / UoW / strict 16-command infrastructure
  -> executor/scheduler/cache/cancellation skeleton
  -> priority computational core
  -> remaining P3/P4/P5/P6 processes
  -> P7 dependency/workspace integration
  -> P8 135-vector + L0-L6 + performance qualification
  -> P9 exact-head closure
```

Priority computational core:

```text
1  CCTV-02  directed bandwidth/flow accounting
2  CCTV-03  storage/time integration
3  LAN-01   installed path length
4  LAN-05   bidirectional optical interval budget
5  ACS-03   lock electrical/transient evidence
6  ACS-04   source/PSU requirement projection
7  ACS-05   backup/autonomy projection
8  FA-02    standby/alarm/startup current aggregation
9  FA-04    source requirement projection
10 FA-05    standby/alarm autonomy sequence
11 FA-06    notification circuit capacity
```

This order deliberately exercises exact quantities, intervals, time rules, keyed set/path accounting, shared ELV4 evidence, transient events, deterministic requirement composition and governing-case logic before the simpler wrappers/basis processes.

UI-first or isolated formula-by-formula development that bypasses P1/P2/executor foundations is rejected.

## 3. P0 gate

Before production ELV5 classes stabilize, P0 establishes:

- exact accepted ELV4 source/merge/runtime evidence and schema 23 baseline;
- supported historical migration origins;
- result-owner/read-dispatch map across legacy/ELV3/ELV4/ELV5;
- canonical ownership map for revisions/components/ports/cables/sources/batteries/capabilities;
- actual shared command ledger/history/UoW/freeze/create-next owners;
- generated contract manifest/fingerprint covering the full active authority chain, including all four dossier files, oracle errata and performance contract;
- explicit ELV6/ELV7/ELV8 claim boundaries.

Missing inherited platform capability becomes an explicit shared-platform delta, never an ELV5 duplicate.

## 4. P1 gate

P1 must provide:

```text
opaque typed identities and closed subject/scope kinds
Known/Missing/NotApplicable/Unsupported/Unresolved field algebra
dimension-safe exact quantity/value objects
code-owned legal quantity algebra
bounded exact decimal/rational/interval operations
evidence/applicability/measurement uncertainty
operating-case + transient/simultaneity policies
captured timezone-rule evidence
coordinate frame/transform evidence
stable finding/comparison/margin/limiting-factor types
stable equation-code calculation trace
canonical request/input/output/snapshot hashing
exact 27 process definitions + 27 algorithm mappings
pure workload/complexity/resource metadata
```

Every process definition must map to one exact 25-section dossier. `String`, nullable scalar, generic `Map<String,dynamic>` or generic arithmetic is not accepted where a typed engineering meaning is required.

## 5. P2 gate

P2 implements additive Drift schema 24 and exactly 16 public operations while preserving prior ownership.

Every durable replacement follows replay-first, CAS/reviewed-impact, atomic root+children replacement, selector-aware old+new invalidation, complete history and ledger commit in one short transaction.

Calculation architecture:

```text
short indexed/bulk coherent CAPTURE
-> pure typed calculation outside DB write transaction
-> short bounded all-or-nothing guarded PUBLISH
```

No server-side silent splitting of one coherence group; no N+1 capture/publish at scale.

## 6. P3–P6 discipline gates

Every process implementation must match its dossier sections 1–25. Package-level prose is not an alternate algorithm. If an authority-controlled oracle erratum applies, the corrected value governs the executable fixture.

### P3 CCTV
Must preserve frame identity, explicit unicast/multicast flow accounting, expected/peak/wire separation, exact interval storage integration, one reserve/ceil/redundancy boundary, estimate-vs-guaranteed scope and one global PSE evidence identity.

### P4 LAN
Must preserve installed-path accounting, physical resource identity, weakest-path compatibility, four-case bidirectional sensitivity/overload optical algebra, reach isolation and ELV6-safe rack basis.

### P5 ACS
Must preserve role/resource multiplicity, control-versus-feed distinction, bounded startup/transient envelope, one shared source/bank result and complete five-cause fail-safe/fail-secure/project-defined release matrix. ACS-03 executable positive fixture uses the corrected **23.51 V terminal / +1.51 V headroom** oracle for the frozen 24 V / 0.8 A / 0.5 Ω trunk plus 0.3 A / 0.3 Ω branch inputs.

### P6 Fire
Must preserve full expanded address claims, complete state-current origins, supported-vs-unsupported electrical models, shared source requirement, ordered autonomy sequence, notification startup/terminal/fault dimensions, signal topology separate from electrical topology and technical-policy/compliance separation.

## 7. Runtime performance gate

Native production runtime uses `Elv5CalculationExecutor`; medium/large workloads run outside the Flutter UI isolate. Repeated work uses a bounded long-lived worker strategy rather than one isolate per node.

Web has a separate qualified policy: it must not assume Flutter `compute()` gives native isolate parallelism.

Runtime performance architecture requires:

```text
deterministic topological batch planning
canonical aggregation independent of worker completion order
incremental affected-node recomputation via reverse dependencies
full semantic input-fingerprint result cache
cancellation + supersession + coalescing/backpressure
minimal worker payloads
bulk/indexed capture/publish
no engineering math/SQLite in widget build()
immutable targeted process-card projections
lazy/virtualized large lists/tables
profile-mode performance evidence
```

Performance optimization may change wall-clock behavior only, never engineering hashes/verdicts.

## 8. P7 dependency/workspace gate

Dependency capture covers positive and negative knowledge:

```text
FACT
SET
SELECTOR
POLICY
EVAL
POINTER
MISSING
```

Mutation invalidates old/new direct+selector closure. Recalculation batch contains only affected nodes and transitive dependents. Scheduler coalesces superseded work; stale worker completion cannot advance CURRENT. Workspace presents immutable engineering result separately from review/waiver state; acknowledgement never rewrites technical FAIL/outputHash.

## 9. P8 executable qualification gate

P8 executes production source/file SQLite. Minimum process vector inventory:

```text
27 positive
27 negative/unsupported
27 boundary
27 adversarial
27 cross-discipline
= 135 process-vector cases
```

The original **54 primary public-command entries remain unchanged** and are the positive + negative/unsupported pair for every process. Boundary/adversarial/cross-discipline suites supplement them.

P8 additionally proves:

- L0 exact numeric/type/hash/time/evidence primitives;
- L1 dossier equations/worst-case/governing/trace, including corrected oracle arithmetic;
- L2 all 16 command codecs/replay/resource limits;
- L3 schema24 migration/restart/owner isolation;
- L4 UoW/history/failure/executor scheduling;
- L5 public process verticals/cross-discipline ownership;
- L6 DB/worker concurrency, cancellation, freeze/create-next;
- workerCount=1 vs N deterministic 500-node batch;
- incremental recomputation exact affected set;
- semantic cache correctness;
- no N+1/query-plan regressions;
- profile-mode UI/raster/worker metrics on scale fixtures;
- targeted rebuild and virtualization behavior;
- no-false-PASS sentinels.

## 10. P9 closure gate

At one exact SHA and authority fingerprint reconcile:

```text
80 requirements
27 typed process definitions
27 algorithm mappings
27×25 process dossiers
oracle errata/executable corrected vectors
16 command codecs/handlers
schema24 implementation/indexes/migration
54 primary entries / 135 process vectors
worker/executor/incremental/cache/cancellation evidence
profile-mode performance artifact
contract manifest/fingerprint
source/test/evidence ledger
ELV6/7/8 handoff
zero open BLOCKER/HIGH
```

Any normative or source change after accepted SHA invalidates affected closure until rerun.

## 11. Stage boundaries

- **ELV6** owns actual rack/cabinet U-position, physical layout, depth/clearance, thermal/ventilation and cable-management fit.
- **ELV7** owns verified jurisdictional/normative applicability, compliance/certification and normative waiver/approval semantics.
- **ELV8** owns concrete commercial SKU selection, BOM, quote, procurement and deliverables.

ELV5 outputs exact technical requirements, margins, provenance and limitations; it does not pre-claim downstream outcomes.

## 12. Current ledger

| Package | Design | Runtime | Evidence |
|---|---|---|---|
| P0 | HARDENED | NOT_STARTED | design contracts only |
| P1 | HARDENED | NOT_STARTED | design contracts only |
| P2 | HARDENED | NOT_STARTED | design contracts only |
| P3 | HARDENED | NOT_STARTED | 6×25 dossier design only |
| P4 | HARDENED | NOT_STARTED | 7×25 dossier design only |
| P5 | HARDENED | NOT_STARTED | 6×25 dossier + oracle errata design only |
| P6 | HARDENED | NOT_STARTED | 8×25 dossier design only |
| P7 | HARDENED | NOT_STARTED | scheduler/dependency/workspace design only |
| P8 | HARDENED | NOT_STARTED | 135-vector/performance specification only |
| P9 | HARDENED | NOT_STARTED | exact-head closure specification only |

Four audit passes resolve **56 design findings** in specification. This ledger intentionally does not convert them into runtime fixes.
