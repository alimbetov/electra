# Electra — ELV5 Authoritative Design Index

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent branch: `feat/flutter-elv4-power-topology-design`
Pinned parent: `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`

The branch name is retained as requested. ELV5 is **discipline-specific engineering calculations**, not a second power-topology foundation. ELV4 owns common physical power models; ELV5 owns explicit calling context, discipline policies and the remaining discipline calculations.

## Entry documents

1. [ELV5 design specification](elv5-discipline-calculations-design-specification.md).
2. [P0–P9 delivery plan](elv5-p0-p9-delivery-plan.md).
3. [Detailed implementation index](elv5-implementation/README.md), with one contract for each package.
4. [Code-level runtime contract](elv5-implementation/code-level-runtime-contract.md): base runtime types, strict wire envelope, 16-operation public command surface, replay/CAS/publication/persistence/dependency contracts.
5. [Engineering primitives contract](elv5-implementation/engineering-primitives-contract.md): dimension-safe exact quantities, evidence basis/applicability, operating cases, deterministic time/frames and canonical hashing.
6. [Typed process API](elv5-implementation/typed-process-api.md): process-specific Dart input/output boundaries for all 27 calculations.
7. [Unified calculation engine](elv5-implementation/calculation-engine-contract.md): common deterministic execution lifecycle for all 27 processes, solver families, applicability, operating cases, conservative comparisons, headroom/margins, governing cases, limiting factors, deterministic trace and sensitivity rules.
8. [Machine algorithm registry](elv5-implementation/algorithm-registry.json): exact 27/27 process-to-solver-family/operating-case/governing/margin/limiting-factor binding.
9. [27-process code-level specification](elv5-implementation/process-code-level-specification.md) plus the four production dossiers: [CCTV](elv5-implementation/process-specifications/cctv-processes.md), [LAN](elv5-implementation/process-specifications/lan-processes.md), [ACS](elv5-implementation/process-specifications/acs-processes.md), [Fire](elv5-implementation/process-specifications/fire-processes.md). Every process has the same **25 mandatory implementation sections** including exact equations, worst-case/governing/limiting algorithms, complexity, pseudocode, Dart surface and five reference-vector classes.
10. [Flutter ultra-performance runtime contract](elv5-implementation/flutter-performance-contract.md): workload classes, native worker-isolate execution, web policy, deterministic parallel DAG, incremental recomputation, cache/cancellation/backpressure, DB capture/publish constraints, virtualized UI and profile-mode performance evidence.
11. [Drift schema 24 persistence contract](elv5-implementation/persistence-schema-contract.md): concrete ELV5 roots/members, PK/FK/index rules, immutable evaluations/pointers, dependency index, migration/restart and shared ledger/history reuse.
12. [Code-level hardening amendments](elv5-implementation/code-level-hardening-amendments.md): normative reconciliation of hardened wire/storage semantics.
13. [Third-pass code-level engineering hardening](elv5-implementation/code-level-hardening-v2.md): strongly typed identities, explicit field-resolution algebra, bounded exact arithmetic, captured timezone-rule evidence, deterministic requirement merger, transient/simultaneity model, ACS release matrix, fire supervision/fault states, selector invalidation and bounded atomic publication. **Where it conflicts with older ELV5 wording, this document governs.**
14. [Production source blueprint](elv5-implementation/production-source-blueprint.md): recommended Dart/Drift source tree, class/interface responsibilities, 16-handler mapping, capture/publish services, repository/UoW boundaries, UI projection and implementation slices. The performance contract adds the executor/scheduler/runtime-performance obligations.
15. [Executable qualification contract](elv5-implementation/qualification-contract.md): L0–L6 test architecture, 54 primary process verticals, adversarial commands, failure/race/migration/freeze and false-PASS sentinels. Third/fourth-pass and unified-engine focused suites supplement rather than replace the 54 process verticals.
16. [Machine-readable 16-command registry](elv5-implementation/command-registry.json), the exact schema/operation/payload-key authority subject to later normative hardening semantics.
17. [Canonical command examples](elv5-implementation/command-examples.json), one valid payload and one deterministic rejection mutation for every registered ELV5 operation.
18. [27-process contract registry](elv5-implementation/process-contracts.md) and [machine-readable process registry](elv5-implementation/process-registry.json).
19. [Authority manifest generator](../../scripts/ci/generate-elv5-contract-manifest.py): emits an exact-head SHA-256 manifest/fingerprint over process, algorithm, command, requirement, all 27 code-level dossiers and performance contracts, and publishes it as a CI artifact.
20. [Baseline and boundary audit](../audit/elv5-baseline-alignment-audit.md).
21. [Initial technical audit](../audit/elv5-technical-audit.md), [second-pass engineering/architecture hardening audit](../audit/elv5-engineering-architecture-hardening-audit.md), [third-pass production-readiness audit](../audit/elv5-third-pass-production-readiness-audit.md) with its [machine-readable registry](../audit/elv5-third-pass-production-readiness-audit.json), and [fourth-pass algorithm/performance audit](../audit/elv5-fourth-pass-algorithm-performance-audit.md) with its [machine-readable registry](../audit/elv5-fourth-pass-algorithm-performance-audit.json).
22. [Implemented baseline and extension contract](elv5-implementation/implemented-baseline.md) and [evidence manifest](elv5-implementation/baseline.json).

## Authority and acceptance

Existing ELV1–ELV4 identities, ownership, reference editions, physical routing, revision lifecycle and resolved RM01–RM15 contracts remain authoritative. ELV5 adds typed discipline definitions and versioned process registration, not replacement ports/cables/cache/history/revision lifecycles. Shared platform extensions must update both stages' contracts explicitly.

Within ELV5 the precedence is explicit. Highest authority first:

1. `code-level-hardening-v2.md`;
2. `code-level-hardening-amendments.md`;
3. machine-readable command/process/algorithm registries for membership/key/solver inventories not superseded by later hardening;
4. `process-contracts.md` plus the 27 process code-level dossiers as one calculation layer: process contracts own physical mathematical intent/claim boundaries; dossiers own the implementation-complete 25-section refinement and may not contradict those boundaries;
5. engineering primitives, typed process API, unified calculation engine, Flutter performance, schema-24 persistence and qualification contracts;
6. base runtime contract and production source blueprint;
7. package P0–P9 prose.

A contradiction between active normative artifacts is a specification failure, not a developer choice. P0 implementation entry therefore requires the generated authority fingerprint/manifest and CI consistency guards covering process/algorithm/command/requirement counts, all **27×25** process dossier sections, solver mappings, payload inventories, registries, canonical format, performance contract and schema version.

Semantic changes require synchronized updates. Free-form package-local reinterpretation is a specification defect.

The initial ELV5 discipline command registry remains exactly **16 operations** under `electra.elv5-discipline-command.v1`, payload version 1. Hardened design changed exact payload content for three not-yet-shipped operations without changing operation count/schema identity. ELV4 revision freeze/create-next commands remain the public revision boundary; ELV5 extends their transaction/snapshot payload internally rather than adding competing revision commands.

All ELV5 P0–P9 runtime packages remain NOT_STARTED. ELV4 is implemented, runtime accepted at the pinned source SHA and merged through PR #11 at `d2b059d4c11a284cdd32965140f6df3c40020c8d`. The [implemented baseline contract](elv5-implementation/implemented-baseline.md) governs reuse and new integration work. ELV4 acceptance does not qualify the 27 new ELV5 processes or any of the 16 ELV5 command codecs.

## Audit status

The initial all-package/process audit reviewed 80 requirements and 27 process contracts, identified **6 HIGH + 2 MEDIUM** discipline-contract findings and resolved all eight in specification.

The second-pass engineering/architecture audit identified **10 HIGH + 4 MEDIUM** findings covering type safety, provenance/uncertainty, operating cases, deterministic time/frames, typed APIs, storage/schema ownership, batch publication, ACS release behavior, CCTV wire-rate basis, optical reach scope, executable qualification and scale fixtures. All 14 are `SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED`.

The third-pass production-readiness audit identified **11 HIGH + 4 MEDIUM** findings covering strongly typed identities, explicit missing/N-A/unsupported semantics, resource-bounded exact arithmetic, legal quantity algebra, reproducible timezone rules, measurement uncertainty, deterministic policy composition, transient simultaneity, ACS release completeness, fire supervision/fault states, negative dependency selectors, bounded atomic publication, review/result separation, diagnostic cardinality and authority-manifest drift protection. All 15 are `SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED`.

The fourth-pass algorithm/performance audit identified **14 HIGH + 4 MEDIUM** findings covering per-process implementation dossier uniformity, exact equations/boundaries, governing/limiting rules, five-class vectors, algorithmic complexity, Flutter main-isolate isolation, web false-parallelism risk, deterministic parallelism, cancellation/backpressure, semantic result caching, DB N+1/query-plan risks, UI virtualization/rebuild scope, profile-mode performance evidence, atomic publish on worker failure, equation trace codes, cross-stage vectors, what-if isolation and regression policy. All 18 are `SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED`.

Total design findings resolved across the four audited passes: **55**. This count is specification hardening, not runtime fixes.

The unified calculation-engine pass remains an architectural consolidation rather than a separate finding count. It standardizes how all 27 processes determine applicability, operating cases, conservative verdicts, engineering margins, governing cases, limiting factors, explanations and optional what-if results.

## Implementation-readiness gate

The following design artifacts are frozen enough to start P1/P2 implementation:

- exactly 27 process codes/scopes/dependencies and typed process input/output boundaries;
- exactly 27 machine-checkable algorithm mappings to legal solver families/operating cases/governing/margin/limiting semantics;
- exactly **25 code-level implementation sections for each process** with physical meaning, applicability, typed inputs, evidence, cases, equations, exact arithmetic, comparison/margin, governing/limiting logic, failure behavior, dependencies, trace, complexity, pseudocode, Dart API and five vector classes;
- positive/boundary/negative/adversarial/cross-discipline vectors for all 27 processes;
- one deterministic cross-discipline calculation lifecycle from capture through guarded publication;
- dimension-safe exact quantities plus code-owned legal quantity algebra;
- strongly typed domain identities and explicit field-resolution semantics;
- canonical hash projections and captured timezone-rule evidence;
- deterministic requirement composition/conflict algebra and operating/transient composition rules;
- conservative interval comparison with no false PASS at uncertain thresholds;
- positive=headroom signed margin convention, governing-case and limiting-factor projections where meaningful;
- deterministic semantic calculation trace and non-authoritative bounded sensitivity/what-if semantics;
- exactly 16 public command operations with hardened exact payload-key sets and canonical examples;
- additive Drift target **schema 24** with ownership/PK/FK/index/migration rules;
- selector-aware dependency invalidation including previously missing/newly matching members;
- replay/history/freeze/create-next integration contract;
- bounded coherent all-or-nothing publication contract;
- production source/class decomposition with strict dependency direction and 16-handler mapping;
- native medium/large calculation execution outside the Flutter UI isolate through a deterministic worker executor;
- web execution policy that does not treat `compute()` as native isolate parallelism;
- incremental recomputation, semantic result cache, cancellation/supersession/backpressure and deterministic parallel batch ordering;
- bulk/indexed capture/publish and virtualized/targeted UI projection requirements;
- L0–L6 qualification architecture and exact 54-entry primary process-oracle requirement plus mandatory third/fourth-pass/unified-engine suites;
- profile-mode performance evidence using the existing scale fixtures and exact-head benchmark artifact;
- exact-head CI authority manifest generation with SHA-256 fingerprints for process/algorithm/command/requirement inventories, all four dossier files and performance contracts.

The generated manifest is **authority/design-entry evidence**, not runtime acceptance. Production P0/P9 source must record/verify the accepted authority fingerprint so an implementation cannot be closed against a different specification fingerprint.

Remaining runtime artifacts are deliberately executable rather than prose:

- implement production Dart definitions/codecs/resolvers/repositories and schema-24 migration following the source blueprint and all hardening amendments;
- implement the unified calculation engine/common result envelope and all 27 dossier algorithms without duplicating ELV3/ELV4 physical ownership;
- implement `Elv5CalculationExecutor`, native worker pool, web policy, scheduler, semantic cache and cancellation/backpressure boundaries;
- implement the priority computational core first: CCTV-02, CCTV-03, LAN-01, LAN-05, ACS-03, ACS-04, ACS-05, FA-02, FA-04, FA-05, FA-06;
- publish the machine-readable `qualification-manifest.json` with exact fixtures/commands/statuses for all 54 primary POS/NEG entries plus focused third/fourth-pass/unified-engine suites;
- execute schema/migration/restart, 16-codec adversarial, resource-limit, failure-injection, selector-invalidation, race/freeze, worker-determinism and cross-discipline vertical tests;
- execute profile-mode scale/performance evidence and prove targeted UI rebuild/virtualization behavior;
- perform post-schema ownership reconciliation proving no ELV5 table duplicates canonical ELV3/ELV4 cable/port/component/source/battery ownership;
- close P9 only from evidence generated at the exact tested source SHA **and matching accepted authority fingerprint**.
