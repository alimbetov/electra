# ELV5 — fourth-pass algorithm and Flutter performance audit

Status: SPEC RESOLVED / RUNTIME NOT IMPLEMENTED  
Branch: `feat/flutter-elv5-power-topology-design`

## Objective

This pass reviewed ELV5 from two production perspectives simultaneously:

1. an electrical/ELV engineer needs every calculation to be explainable, conservative, scenario-aware and traceable to exact physical evidence;
2. a Flutter/system architect needs those same calculations to remain deterministic, incremental and responsive at project scale.

The prior hardening already established 27 process identities, exact engineering primitives, persistence, authority, execution status semantics and a common calculation engine. The fourth pass asks a stricter question: **can a developer now implement every process and the high-performance runtime without inventing mathematics, worst-case rules, scheduling semantics or UI performance behavior?**

The answer before this pass was “not fully”. Nineteen specification gaps, including one arithmetic reference-oracle defect found during independent vector cross-checking, were identified and resolved in design. Runtime remains not started.

## Findings summary

| Severity | Count |
|---|---:|
| HIGH | 15 |
| MEDIUM | 4 |
| Total | 19 |

All 19 are `SPEC_RESOLVED`. None is a runtime fix.

## HIGH findings

### ELV5-AUD4-01 — PROCESS_DOSSIER_UNIFORMITY

**Problem.** Process contracts described the engineering intent well, but did not force one implementation-complete shape across all 27 processes.

**Resolution.** `process-code-level-specification.md` requires exactly 25 sections for every process; four discipline dossier files provide those sections for all 27 codes.

### ELV5-AUD4-02 — EQUATION_AND_BOUNDARY_SEMANTICS

**Problem.** Shared comparison algebra existed, but equation boundaries, interval endpoints, rounding points and inclusive/exclusive limits were not frozen per process.

**Resolution.** Every dossier states mathematical model, equations, exact/bounded arithmetic and comparison equations. Examples such as CCTV storage pool-level `ceil`, LAN optical overload, ACS terminal-voltage ranges and Fire address expansion are explicit.

### ELV5-AUD4-03 — GOVERNING_AND_LIMITING_SELECTION

**Problem.** A process could calculate multiple valid dimensions but still leave the developer to decide which case appears as governing/limiting.

**Resolution.** Every process has deterministic worst-case, governing-case and limiting-factor algorithms including tie/order semantics where needed.

### ELV5-AUD4-04 — REFERENCE_VECTOR_COVERAGE

**Problem.** Positive/negative process oracles existed, but exact-limit, malicious-input and cross-discipline behavior was not consistently frozen per process.

**Resolution.** Every process now includes five mandatory vectors: positive, boundary, negative, adversarial and cross-discipline.

### ELV5-AUD4-05 — PROCESS_COMPLEXITY_BOUNDS

**Problem.** Scale fixtures existed globally, but algorithmic complexity and anti-quadratic expectations were not explicit per process.

**Resolution.** Every process dossier states complexity/resource bounds; `flutter-performance-contract.md` freezes a 27-process complexity matrix.

### ELV5-AUD4-06 — MAIN_ISOLATE_ENGINEERING_WORK

**Problem.** Pure kernels were architecturally isolated from Flutter, but nothing required medium/large native workloads to execute outside the UI isolate.

**Resolution.** The performance contract introduces `Elv5CalculationExecutor`, workload classes and a native long-lived worker-isolate/pool policy. Medium/large native engineering work may not execute inline on the UI isolate in production.

### ELV5-AUD4-07 — WEB_COMPUTE_FALSE_PARALLELISM

**Problem.** Using Flutter `compute()` as a generic performance answer would be unsafe because on web it executes on the current event loop rather than providing native isolate semantics.

**Resolution.** Web receives a separate executor policy with bounded chunks/yields and separate qualification. A future real worker backend may replace it without changing pure kernel APIs.

### ELV5-AUD4-08 — PARALLEL_DETERMINISM

**Problem.** Parallel execution could reorder results/findings/traces and therefore alter hashes if completion order leaked into aggregation.

**Resolution.** Batch execution is a deterministic DAG. Node results are keyed and canonically ordered; worker count/completion timing may change wall-clock metrics only. Worker-count/order determinism is mandatory evidence.

### ELV5-AUD4-09 — STALE_WORK_CANCELLATION_BACKPRESSURE

**Problem.** Rapid edits could enqueue obsolete calculations, waste CPU and eventually let stale work compete for publication.

**Resolution.** Monotonic request epochs, cooperative cancellation, supersession and node-key/generation coalescing are normative. Stale worker completion can never advance CURRENT.

### ELV5-AUD4-10 — SEMANTIC_RESULT_CACHE_KEY

**Problem.** Pure calculation reuse was possible conceptually, but an incomplete cache key could accidentally reuse a result across policy/timezone/algorithm changes.

**Resolution.** Reuse key includes process/algorithm/schema/numeric versions, authority fingerprint and canonical input fingerprint, which itself captures policy/time/frame/evidence/upstream semantics.

### ELV5-AUD4-11 — CAPTURE_PUBLISH_N_PLUS_ONE

**Problem.** Correct repository code could still be pathologically slow through child-by-child loads and long DB transactions.

**Resolution.** Capture and publish are explicitly short/bounded phases with bulk access, required indexes and query-plan evidence. Calculation happens outside write transactions; N+1 behavior on scale fixtures is closure-blocking.

### ELV5-AUD4-12 — UI_REBUILD_AND_VIRTUALIZATION

**Problem.** A calculation engine can be fast while a workspace remains slow because every result update rebuilds thousands of widgets or eagerly creates hidden rows.

**Resolution.** Immutable process-card projections, targeted subscriptions/selectors and lazy/virtualized lists/tables are required. Engineering math and DB access in `build()` are forbidden.

### ELV5-AUD4-13 — PERFORMANCE_EVIDENCE_GATE

**Problem.** “Fast” was not a measurable acceptance state.

**Resolution.** Profile-mode frame evidence, scale fixtures, timeline spans, controlled benchmark artifacts and regression policy are now part of P8/P9 performance closure. Debug-mode timing is not accepted.

### ELV5-AUD4-14 — PARTIAL_PUBLISH_ON_WORKER_FAILURE

**Problem.** Concurrent workers introduce a failure mode where some node results might be available while others fail/cancel.

**Resolution.** The requested coherent batch remains all-or-nothing at publish. Workers may finish independent nodes for diagnostics/cache, but no partial pointer advance is permitted.

### ELV5-AUD4-19 — REFERENCE_ORACLE_ARITHMETIC_INTEGRITY

**Problem.** Independent recomputation found an arithmetic inconsistency in the inherited ACS-03 positive reference vector. For a 24 V source, 0.8 A shared-trunk current over 0.5 Ω and a 0.3 A lock branch over 0.3 Ω, the old oracle stated 23.45 V.

**Resolution.** [calculation-oracle-errata-v1.md](../product/elv5-implementation/calculation-oracle-errata-v1.md) is normative: trunk drop is `0.8×0.5=0.4 V`, branch drop is `0.3×0.3=0.09 V`, therefore terminal voltage is **23.51 V** and headroom over a 22.00 V minimum is **+1.51 V**. Executable ACS-03 vectors must use the corrected arithmetic. This is an oracle correction, not permission for ELV5 to duplicate the ELV4 PWR-03 solver.

## MEDIUM findings

### ELV5-AUD4-15 — EQUATION_TRACE_CODES

Each process defines stable equation-code families so trace/evidence can be tested structurally instead of comparing localized prose.

### ELV5-AUD4-16 — CROSS_STAGE_VECTOR_PROOF

Every process includes a cross-discipline vector proving which ELV3/ELV4 facts are reused and which claims remain for ELV6/ELV7/ELV8.

### ELV5-AUD4-17 — WHAT_IF_RESOURCE_ISOLATION

What-if calculations reuse pure kernels/cache but are bounded, cancellable and never publishable as project CURRENT.

### ELV5-AUD4-18 — MEASURED_REGRESSION_POLICY

Deterministic performance architecture gates run on every PR; timing/memory regression gates require a controlled runner/profile setup to avoid treating noisy CI measurements as engineering truth.

## Engineering decisions strengthened by this pass

```text
expected != guaranteed
typical != worst-case evidence
reserve != uncertainty
demand != required capability
CURRENT != PASS
technical FAIL != execution failure
control path != power feed
signal closure != electrical mesh solution
optical power budget != reach/dispersion proof
rack capacity basis != physical rack fit
technical fire policy match != verified compliance
contribution != global physical total
parallel completion order != canonical result order
worker completion != publication authority
what-if result != CURRENT
reference oracle != trusted until independently recomputed
```

## Priority computational core

```text
1  CCTV-02  directed bandwidth/flow accounting
2  CCTV-03  storage/time integration
3  LAN-01   installed path length
4  LAN-05   bidirectional optical interval budget
5  ACS-03   lock transient/electrical evidence
6  ACS-04   source/PSU requirement projection
7  ACS-05   backup/autonomy projection
8  FA-02    standby/alarm current aggregation
9  FA-04    source requirement projection
10 FA-05    standby/alarm autonomy sequence
11 FA-06    notification circuit capacity
```

These processes exercise exact arithmetic, intervals, time integration, path accounting, shared-source evidence, transient cases and worst-case selection first.

## Flutter performance architecture verdict

The runtime is deliberately split into:

```text
short consistent capture
    ↓
pure deterministic calculation outside write transaction
    ↓
short guarded atomic publication
```

On native Flutter, medium/large workloads use long-lived worker isolate(s); on web, the runtime must not mistake `compute()` for native-style parallelism. Incremental dependency closure and semantic input-fingerprint reuse are more important than simply adding workers.

UI performance is separate from compute throughput: virtualized collections, targeted immutable projections and cheap `build()` paths remain mandatory.

## Closure impact

Fixed public inventory remains:

- processes: 27;
- public ELV5 commands: 16;
- primary process verticals: 54;
- target Drift schema: 24.

The authority chain includes:

- `process-code-level-specification.md`;
- all four discipline dossier files;
- `flutter-performance-contract.md`;
- `calculation-oracle-errata-v1.md`;
- this audit and machine-readable audit registry.

## Final audit verdict

After this pass, formulas, comparison boundaries, worst-case behavior, trace shape, complexity, pseudocode and typed APIs are no longer left to local developer interpretation for any of the 27 processes. Reference vectors themselves are now explicitly subject to arithmetic-integrity validation and authority-controlled errata.

The remaining risk is implementation fidelity: P1/P2 primitives, executor/scheduler, schema-24 repositories and the first 11 computational kernels must prove runtime agreement under exact-head CI, 135 process vectors, scale fixtures and profile-mode performance evidence.