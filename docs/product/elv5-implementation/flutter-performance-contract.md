# ELV5 — Flutter ultra-performance runtime contract

Status: DESIGN HARDENING / RUNTIME NOT STARTED  
Scope: `apps/mobile` orchestration/UI plus scheduling boundary around pure `packages/engineering_core` ELV5 kernels.

This contract exists because mathematically correct engineering software is not production-grade if a 500-node recalculation freezes the UI, a 10,000-segment schedule blocks a frame, or a large workspace rebuilds thousands of widgets after one pointer changes.

Official platform references used by this design:

- Flutter performance best practices: https://docs.flutter.dev/perf/best-practices
- Flutter rendering/performance profiling: https://docs.flutter.dev/tools/devtools/performance
- Flutter isolates: https://docs.flutter.dev/perf/isolates
- Dart isolates/concurrency: https://dart.dev/language/isolates
- Flutter `compute`: https://api.flutter.dev/flutter/foundation/compute.html
- Impeller: https://docs.flutter.dev/perf/impeller

The contract deliberately avoids an invented production millisecond SLO for the 27 engineering kernels until measured on representative hardware. Frame budgets, algorithmic bounds and regression policy are normative now; device-specific throughput budgets are recorded from executed benchmarks.

## 1. Performance goals

ELV5 runtime MUST satisfy all of these architectural goals:

1. no medium/large engineering kernel blocks the main/UI isolate;
2. result determinism is independent of worker count and worker completion order;
3. changing one project fact recalculates only the typed dependency closure, not all 27 processes/all subjects;
4. same accepted immutable input fingerprint is reusable without recomputation;
5. capture and publish DB transactions are short and bounded; pure calculation occurs outside a write transaction;
6. no partial multi-node publish after cancellation, stale capture or worker failure;
7. workspace UI builds only visible/changed projections and never performs engineering arithmetic in `build()`;
8. large data is captured as the minimum process-specific closure, not as a copy of the entire project graph;
9. all hot paths are profileable with stable timeline labels;
10. performance optimization never changes canonical result/hash semantics.

## 2. Frame-time contract

Flutter targets the device refresh interval. Approximate full-frame budgets are:

```text
60 Hz  -> 16.67 ms
90 Hz  -> 11.11 ms
120 Hz ->  8.33 ms
```

Both UI-thread and raster-thread work must remain inside the actual refresh budget in profile-mode performance evidence. Debug-mode timing is not acceptance evidence.

ELV5 adds a stricter project target for synchronous engineering-related work on the UI isolate:

```text
p99 single synchronous orchestration slice <= min(2 ms, 25% of refresh interval)
```

This budget applies to request validation, state projection, scheduling and lightweight result adoption—not to pure medium/large calculation kernels, which must be offloaded on native platforms.

A measured violation does not authorize silently raising the budget; first remove main-isolate work, N+1 queries, excessive rebuilds or serialization overhead.

## 3. Cost classes

Every process runtime definition MUST expose a code-owned workload/cost class independent of current device timing:

```dart
enum Elv5WorkloadClass {
  tiny,       // bounded O(1)/small-set checks
  small,      // linear over a small local aggregate
  medium,     // path/set aggregation, graph traversal, non-trivial exact arithmetic
  large,      // interval sorting, large flow accounting, large batch/graph fixture
}
```

Default process family mapping:

```text
CCTV-01  medium       bounded geometry/polygon work
CCTV-02  medium/large by flow-edge incidence count
CCTV-03  large        recurrence expansion + O(N log N) interval union
CCTV-04  small        evidence projection
CCTV-05  medium       assignment/capability aggregation
CCTV-06  small/medium ordered path
LAN-01   small/medium ordered path
LAN-02   medium       assignment/resource maps
LAN-03   small        evidence projection
LAN-04   medium       ordered path property checks
LAN-05   medium       exact interval optical budget
LAN-06   medium       equipment aggregation
LAN-07   medium       mapping/resource maps
ACS-01   small/medium requirement tree + role map
ACS-02   medium       resource assignment maps
ACS-03   medium       event envelope + upstream evidence projection
ACS-04   small/medium requirement merge + evidence projection
ACS-05   small/medium sequence/evidence projection
ACS-06   medium       five graph reachability cases
FA-01    large by address-claim cardinality
FA-02    medium/large by load-origin cardinality
FA-03    small/medium terminal evidence projection
FA-04    small/medium requirement merge
FA-05    small/medium sequence projection
FA-06    medium       device/case + optional local fault graph
FA-07    medium/large by graph/fault sweep
FA-08    medium       route × bounded predicates
```

Runtime may refine the class from captured cardinalities using code-owned thresholds, but imported project data cannot choose an executor directly.

## 4. Execution topology

Recommended production topology:

```text
Flutter UI isolate
  |
  | public command / query
  v
Elv5CalculationService
  |
  +--> short consistent CAPTURE (SQLite)
  |
  +--> Elv5CalculationExecutor
  |      |
  |      +--> native long-lived worker isolate(s)
  |      |      pure engineering_core kernels only
  |      |
  |      +--> web executor policy
  |
  +--> short guarded PUBLISH transaction
  |
  v
workspace projection / targeted UI notification
```

`engineering_core` MUST NOT depend on Flutter, Drift, SQLite, platform channels or widget state.

## 5. Executor abstraction

```dart
abstract interface class Elv5CalculationExecutor {
  Future<Elv5ExecutedBatch> execute(
    Elv5CapturedBatch batch, {
    required Elv5CancellationToken cancellation,
  });
}

final class NativeElv5WorkerPool implements Elv5CalculationExecutor {}
final class WebElv5ChunkedExecutor implements Elv5CalculationExecutor {}
final class InlineElv5Executor implements Elv5CalculationExecutor {} // tests/tiny only
```

The application service chooses executor by platform capability and workload class. Process kernels never call `Isolate.run`, `compute`, scheduling APIs or platform code themselves.

## 6. Native isolate policy

On native Flutter platforms, `medium` and `large` workloads MUST execute outside the UI isolate. `tiny/small` may run inline only when profile evidence proves the synchronous slice stays under the UI budget.

Do not spawn one new isolate for every node. Repeated ELV5 work SHOULD use a long-lived worker isolate/pool because isolate spawn and message transfer have non-zero overhead.

Pool requirements:

- bounded worker count from application configuration/platform capability;
- at least one core remains available for UI/raster/platform activity on multi-core systems where practical;
- no mutable project state shared across isolates;
- worker registry/algorithm code is immutable/code-owned;
- inputs/results are sendable immutable DTO/value graphs;
- same task may execute on different workers without changing deterministic output hash;
- completion order never defines result order.

## 7. Web policy

Flutter `compute()` runs on the current event loop on web; it is not a true parallel-isolate guarantee. Therefore ELV5 MUST NOT assume that `compute()` removes CPU work from the web UI thread.

Until a true supported worker backend is implemented and qualified, web behavior is:

- execute only bounded process-local kernels;
- split multi-node batches into deterministic chunks;
- yield between chunks;
- use virtualized UI and avoid simultaneous heavy layout/recalculation;
- mark very large workloads outside qualified web bounds rather than freezing the page;
- keep web performance qualification separate from native-isolate qualification.

A future Web Worker/Wasm worker adapter may replace this without changing pure process APIs.

## 8. Captured batch must be minimal

Forbidden:

```text
send entire project database to worker
send all ELV3/ELV4 facts “just in case”
send Drift rows/generated companions
send BuildContext/Widget/ChangeNotifier
send mutable repository/service objects
```

Required:

- resolve only exact process dependency closure;
- share repeated immutable definition/policy data inside one captured batch by compact typed refs/indexes;
- flatten DB rows into pure domain DTOs before worker boundary;
- preserve canonical IDs/hashes rather than verbose duplicate display metadata;
- keep localized strings/UI labels outside worker payload.

## 9. Deterministic parallel batch plan

`Elv5BatchPlan` is a DAG over requested/affected engineering nodes. Parallelism is allowed only for nodes whose required upstream results are already available and which are independent in the plan.

Rules:

1. topological levels are deterministic;
2. nodes inside one level may execute concurrently;
3. each result is stored by canonical `Elv5EngineeringNodeKeyV3`;
4. aggregation sorts by canonical node key, never worker completion time;
5. if one node fails execution, batch policy determines whether remaining independent nodes may finish for diagnostics, but **publication remains all-or-nothing** for the requested coherent batch;
6. upstream process outputs in the same requested batch are passed by immutable value/ref, not observed through partially published DB state.

## 10. Incremental recomputation

The reverse dependency index is the primary performance feature, not an optional optimization.

A mutation resolves:

```text
changed FACT/SET/POLICY/SELECTOR keys
→ reverse index
→ affected current node keys
→ transitive dependent node closure
→ deduplicated calculation batch
```

Must include negative/selector dependencies so creation of a newly matching fact invalidates the correct nodes.

Never implement “recalculate all 27 processes after any edit” as a fallback production strategy.

## 11. Input-fingerprint cache

Pure result reuse key MUST include at least:

```text
processCode
algorithmVersion
inputSchemaVersion
outputSchemaVersion
numericBackendVersion
authorityFingerprint
canonicalInputFingerprint
```

If an immutable successful/blocked deterministic evaluation with the same complete key already exists and policy permits reuse, runtime may reuse it instead of recomputing the kernel.

Cache MUST NOT ignore:

- policy edition/hash;
- timezone rules hash;
- geometry transform hash;
- evidence basis/uncertainty;
- operating-case identity;
- upstream output hash/generation where semantically consumed.

Cache hit changes neither deterministic output hash nor engineering trace semantics. Evaluation/publication metadata may create a new pointer relation only if lifecycle rules permit it; immutable result content is not mutated.

## 12. Worker-local memoization

Long-lived workers MAY retain bounded LRU caches for pure intermediate artifacts such as:

- canonical policy/matrix decode by immutable hash;
- timezone-rule expansion helper tables by rules hash;
- geometry transform composition by transform-chain hash;
- compatibility-matrix index by edition hash.

Worker cache entries must be semantically immutable and disposable. Eviction changes performance only, never results.

## 13. Cancellation and supersession

Every calculation request receives a monotonic application-level request epoch/cancellation token. Cancellation is cooperative at safe boundaries:

- before starting a node;
- between large interval/flow chunks;
- between topological levels;
- before guarded publish.

A newer edit/calculation may supersede an older not-yet-published batch. Worker completion after cancellation is discarded unless reusable by exact fingerprint cache; it must not advance CURRENT.

No cancellation check may interrupt an exact arithmetic primitive mid-invariant and expose partial output.

## 14. Backpressure/coalescing

Rapid edits can invalidate the same node repeatedly. The scheduler MUST coalesce pending recalculation by canonical node key/input generation:

```text
edit A -> node X generation 10 queued
edit B -> node X generation 11 queued before X10 starts
=> X10 may be dropped; only newest required generation executes
```

If X10 is already running, cancellation/supersession prevents stale publish. Do not grow an unbounded FIFO of obsolete recalculations.

## 15. Capture database performance

Capture is one bounded consistent-read phase. Required patterns:

- bulk repository methods per aggregate/process family;
- `WHERE id IN (...)`/indexed scoped loads rather than N+1 per child;
- indexes required by schema-24 contract for revision/scope/owner/member lookups;
- resolve upstream evaluation pointers/hashes in bulk;
- load only required member sets/selectors;
- transaction closes before CPU-heavy pure calculation.

A capture transaction MUST NOT wait for worker calculation.

## 16. Publish database performance

Publish is a short guarded write transaction:

1. revalidate revision lifecycle;
2. revalidate dependency fingerprints/generations;
3. revalidate target pointer generations;
4. insert immutable evaluations/trace summary/evidence refs;
5. replace reverse dependency rows using bounded bulk operations;
6. advance all pointers atomically;
7. update snapshot/history/ledger evidence as required;
8. commit.

No JSON pretty printing, explanation localization, graph solving or large sorting inside the write transaction.

## 17. SQL/indexing requirements

Performance qualification MUST inspect query plans for high-cardinality capture/publish paths. Required key shapes include revision+scope/root IDs, parent FK/member ordinal where ordered, reverse dependency key→node lookup, current pointer key and immutable evaluation ID/hash lookup.

A missing index that turns the 10k scale fixture into repeated full-table scans is a closure blocker even if functional tests pass.

## 18. Process algorithmic complexity matrix

| Process | Required hot-path complexity |
|---|---|
| CCTV-01 | O(Vf×Vz) bounded polygon clip; four rays O(1) |
| CCTV-02 | O(F) accounting + O(F log F) optional canonical explanation order |
| CCTV-03 | O(N log N) interval sort/union |
| CCTV-04 | O(K) upstream contributor projection |
| CCTV-05 | O(S) assignments/capability checks |
| CCTV-06 | O(P) ordered path |
| LAN-01 | O(P) ordered path |
| LAN-02 | O(P+A) indexed resources/assignments |
| LAN-03 | O(K) contributor projection |
| LAN-04 | O(P×R), bounded R properties |
| LAN-05 | O(P+E) loss sections/events |
| LAN-06 | O(E) equipment aggregation |
| LAN-07 | O(P+M) ports/mappings |
| ACS-01 | O(A+R) assignments/requirement nodes |
| ACS-02 | O(R+A) resources/assignments |
| ACS-03 | O(Ev) bounded temporal events + evidence projection |
| ACS-04 | O(Q+C) dimensions/requirement contributors |
| ACS-05 | O(S+C) sequence/contributors |
| ACS-06 | O(5×(V+E)) door-local graph |
| FA-01 | O(D+A) address claims |
| FA-02 | O(N×C), bounded C cases |
| FA-03 | O(T×C) terminals/cases |
| FA-04 | O(C+R) cases/requirements |
| FA-05 | O(S+C) sequence/contributors |
| FA-06 | O(N×C + F×(V+E)) bounded fault cases |
| FA-07 | O(C×(V+E)); bounded fault sweep if enabled |
| FA-08 | O(S×R), bounded R predicates |

Any accidental O(N²) implementation where the contract expects keyed O(N) behavior is a performance defect.

## 19. UI state architecture

The workspace projection layer exposes immutable, process-card-sized view models. UI subscribes to the smallest relevant state slice.

Forbidden:

- one global `setState`/notifier event rebuilding the entire engineering workspace after one dimension changes;
- querying SQLite directly in widget `build()`;
- formatting thousands of hidden rows on every state update;
- re-running explanation/canonicalization math in widgets;
- mutable list reuse that forces broad equality/rebuild ambiguity.

Required:

- stable keys by engineering node/dimension/finding ID;
- immutable VMs;
- targeted selectors/listenables/stream projections equivalent to “only this card changed”;
- localized strings generated after stable-code result projection;
- expensive explanation details loaded/expanded lazily.

This contract does not mandate a specific state-management package.

## 20. Virtualized lists/tables

Large result collections MUST use lazy/virtualized widgets (`ListView.builder`, Slivers or equivalent) rather than eagerly building all children. Tables with thousands of process findings/members require viewport/pagination strategy rather than a giant `Column`.

Do not allocate widget trees for off-screen trace rows.

## 21. Rebuild and paint rules

Follow measured Flutter best practices:

- keep `build()` cheap and free of engineering computation;
- localize state changes;
- prefer reusable widgets/const subtrees where configuration is stable;
- use `AnimatedBuilder.child`-style stable subtrees for animation-independent content;
- avoid broad `Opacity`, clipping, `saveLayer`, image filters and shadows in scrolling hot paths unless profiling proves acceptable;
- use `RepaintBoundary` selectively after measurement, not everywhere;
- never override Widget `operator==` globally as a rebuild optimization.

## 22. Rendering backend

Use the platform-default supported Flutter renderer. Current Flutter uses Impeller by default on iOS and Android API 29+; do not add a project-specific renderer switch as a “performance fix” without measured evidence.

Renderer-specific behavior is not part of engineering result semantics.

## 23. Timeline instrumentation

Every public calculation run MUST emit stable timeline spans such as:

```text
ELV5.capture
ELV5.plan
ELV5.worker.batch
ELV5.worker.CCTV-03
ELV5.worker.LAN-05
ELV5.publish
ELV5.workspace.project
```

Worker labels include process code/batch size but not high-cardinality random IDs in event names. IDs may be structured timeline arguments.

Use `dart:developer` timeline APIs or equivalent production-safe tracing hooks. Instrumentation must be disableable/low-overhead outside profiling.

## 24. Performance metrics artifact

P8 SHALL produce a machine-readable benchmark artifact with at least:

```text
sourceSha
authorityFingerprint
flutterVersion
dartVersion
platform/device profile
refreshRate if known
fixtureId
processCode/batch composition
input cardinalities
capture duration
worker queue duration
kernel duration
publish duration
workspace projection duration
UI frame build/raster percentiles during run
peak RSS/heap where measurable
cache hit/miss counts
affected node count
recomputed node count
```

Timing numbers are evidence, not deterministic hashes.

## 25. Required scale fixtures

Reuse the qualification scale inventory at minimum:

- 1000 CCTV streams;
- 10,000 recording schedule segments;
- 5000 LAN mappings;
- 2000 ACS assignments;
- 10,000 fire address claims;
- 5000 dependency edges;
- 500-node coherent calculation batch.

Performance tests MUST verify the expected algorithmic shape and that the UI remains responsive while native calculation executes off-main.

## 26. Regression policy

Because CI hardware varies, PR timing gates should use two levels:

**Deterministic structural gates** (blocking on every PR):

- algorithm complexity implementation pattern tests where practical;
- bounded input/resource guards;
- no forbidden Flutter/Drift dependencies in `engineering_core`;
- no medium/large process executed through inline production executor on native;
- exact affected-node recomputation assertions;
- no N+1 repository call-count regressions in instrumented fixtures;
- worker result determinism across worker counts/order.

**Measured benchmark gates** (controlled runner/nightly/release):

- profile-mode frame budget;
- kernel/capture/publish percentiles;
- memory high-water mark;
- throughput regression versus accepted baseline.

A recommended initial regression guard is to investigate any >=15% degradation in median/p95 on the same controlled runner before accepting a new baseline; this is a software-regression threshold, not an engineering calculation rule.

## 27. Determinism under parallelism

Mandatory test:

```text
same captured batch
run with workerCount=1
run with workerCount=N
randomize task completion delays
=> identical per-node deterministic output hashes
=> identical canonical batch output ordering/hash
=> identical governing cases/findings/trace equation sequence per node
```

Parallelism may change only wall-clock scheduling evidence.

## 28. Allocation discipline

Hot kernels SHOULD:

- build maps/sets once and reuse within invocation;
- avoid repeated `where(...).toList()` chains in inner loops;
- avoid copying large immutable lists merely to sort for display—sort a compact index/projection when possible;
- use typed value objects but avoid pathological per-scalar wrapper churn in inner loops when a value-class representation can preserve type safety;
- union intervals in-place on a local sorted working list where immutability contract permits internal scratch buffers;
- store trace operands by stable ref rather than duplicating full source objects.

Optimization must preserve immutable public API semantics.

## 29. Explanation/UI lazy materialization

The deterministic kernel returns stable findings/trace primitives. Human-readable explanation trees, contribution charts and localized formatted values may be projected lazily when a process card is expanded.

Do not eagerly build a full prose explanation for all 500 nodes after every calculation.

## 30. What-if execution performance

What-if uses the same pure kernels/executor but a separate non-publishable request identity. It may reuse immutable caches by exact input fingerprint.

Rules:

- lower scheduling priority than active edit/official calculation where platform scheduler supports it;
- cancellation on new what-if input;
- no CURRENT pointer publication;
- no history/ledger mutation intended for project edits;
- bounded concurrent what-if jobs to prevent CPU saturation.

## 31. Failure isolation

Worker crash/exception for one execution batch:

- returns typed execution failure;
- does not corrupt DB because calculation occurs outside write transaction;
- does not partially advance pointers;
- worker may be recreated;
- exact input may be retried according to application policy;
- deterministic technical FAIL results are not exceptions and do not trigger retry.

## 32. Source blueprint changes

Recommended additions:

```text
apps/mobile/lib/application/elv5/calculation/
  elv5_calculation_executor.dart
  elv5_native_worker_pool.dart
  elv5_web_chunked_executor.dart
  elv5_calculation_scheduler.dart
  elv5_cancellation_token.dart
  elv5_cost_model.dart
  elv5_execution_metrics.dart
  elv5_result_cache.dart

packages/engineering_core/lib/src/elv5/performance/
  process_workload.dart       # pure metadata only
  resource_limits.dart        # code-owned deterministic limits
```

`engineering_core/performance` must not import Flutter scheduling APIs.

## 33. Definition of Done for performance

ELV5 cannot claim production performance closure until:

1. all 27 process kernels have their dossier complexity bounds implemented;
2. medium/large native workloads execute off UI isolate;
3. 500-node batch results are deterministic across worker counts/order;
4. incremental invalidation proves only affected nodes recompute;
5. same-fingerprint result cache proves semantic reuse without stale publication;
6. capture/publish use bounded bulk queries and required indexes;
7. scale fixtures run without unbounded memory growth/resource-limit bypass;
8. profile-mode UI/raster frames remain within target refresh budget during representative recalculation/workspace interaction;
9. workspace lists/tables are virtualized and targeted rebuild tests exist;
10. performance metrics artifact is attached to P8/P9 exact-head evidence.

Performance acceptance never weakens calculation correctness, evidence completeness or atomic publication.