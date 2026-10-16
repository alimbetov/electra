# Electra — ELV5 Authoritative Design Index

Status: **DESIGN HARDENED / PROJECT ALIGNMENT CLOSED / RUNTIME NOT STARTED**  
Branch: `feat/flutter-elv5-power-topology-design`  
Parent design branch: `feat/flutter-elv4-power-topology-design`  
Accepted ELV4 source: `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`  
Merged accepted ELV4 baseline: `main@d2b059d4c11a284cdd32965140f6df3c40020c8d`

The branch name is retained as requested. ELV5 is **discipline-specific engineering calculations**, not a second power-topology foundation. ELV4 owns common physical power models; ELV5 owns explicit calling context, discipline policies and the remaining discipline calculations.

## Entry documents

1. [Project-wide alignment hardening v1](elv5-implementation/project-alignment-hardening-v1.md) — current top ELV5 reconciliation layer for authority/status/resolver/schema/oracle/downstream handoff contradictions.
2. [ELV5 design specification](elv5-discipline-calculations-design-specification.md).
3. [P0–P9 delivery plan](elv5-p0-p9-delivery-plan.md).
4. [Detailed implementation index](elv5-implementation/README.md), with one contract for each package.
5. [Implementation binding/performance hardening](elv5-implementation/implementation-binding-hardening-v1.md) plus machine registries: [implementation bindings](elv5-implementation/implementation-binding-registry.json), [repository contracts](elv5-implementation/repository-contract-registry.json), [runtime versions](elv5-implementation/runtime-version-registry.json), [algorithm performance](elv5-implementation/algorithm-performance-registry.json), and [finding/trace codes](elv5-implementation/finding-trace-code-registry.json). The pure-core/application resolver and nested-module architecture is separately frozen by [ADR-031 — ELV5 pure-core and module boundary](../adr/ADR-031-elv5-pure-core-and-module-boundary.md).
6. [Code-level runtime contract](elv5-implementation/code-level-runtime-contract.md): base runtime types, strict wire envelope, 16-operation public command surface, replay/CAS/publication/persistence/dependency contracts.
7. [Engineering primitives contract](elv5-implementation/engineering-primitives-contract.md): dimension-safe exact quantities, evidence basis/applicability, operating cases, deterministic time/frames and canonical hashing.
8. [Typed process API](elv5-implementation/typed-process-api.md): process-specific Dart input/output boundaries for all 27 calculations. Repository-aware input resolution is application-layer only; `engineering_core` process definitions/kernels remain pure.
9. [Unified calculation engine](elv5-implementation/calculation-engine-contract.md): common deterministic execution lifecycle for all 27 processes, solver families, applicability, operating cases, conservative comparisons, headroom/margins, governing cases, limiting factors, deterministic trace and sensitivity rules.
10. [Machine algorithm registry](elv5-implementation/algorithm-registry.json): exact 27/27 process-to-solver-family/operating-case/governing/margin/limiting-factor binding.
11. [27-process code-level specification](elv5-implementation/process-code-level-specification.md) plus the four production dossiers: [CCTV](elv5-implementation/process-specifications/cctv-processes.md), [LAN](elv5-implementation/process-specifications/lan-processes.md), [ACS](elv5-implementation/process-specifications/acs-processes.md), [Fire](elv5-implementation/process-specifications/fire-processes.md). Every process has the same **25 mandatory implementation sections** including exact equations, worst-case/governing/limiting algorithms, complexity, pseudocode, Dart surface and five reference-vector classes.
12. [Calculation reference-oracle errata v1](elv5-implementation/calculation-oracle-errata-v1.md). The ACS-03 shared-trunk positive oracle is **23.51 V / +1.51 V**; active process contract and dossier are synchronized to that value.
13. [Flutter ultra-performance runtime contract](elv5-implementation/flutter-performance-contract.md): workload classes, native worker-isolate execution, web policy, deterministic parallel DAG, incremental recomputation, cache/cancellation/backpressure, DB capture/publish constraints, virtualized UI and profile-mode performance evidence.
14. [Drift schema 24 persistence contract](elv5-implementation/persistence-schema-contract.md): concrete ELV5 roots/members, PK/FK/index rules, immutable evaluations/pointers, dependency index, migration/restart and shared ledger/history reuse. Initial ELV5 additive schema **24** is frozen by the runtime-version registry and supersedes older “choose >23 later” wording.
15. [Code-level hardening amendments](elv5-implementation/code-level-hardening-amendments.md) and [third-pass hardening v2](elv5-implementation/code-level-hardening-v2.md).
16. [Production source blueprint](elv5-implementation/production-source-blueprint.md): recommended Dart/Drift decomposition, class/interface responsibilities, 16-handler mapping, capture/publish services, repository/UoW boundaries and UI projection. Exact filenames are tracked coordinates; public symbols/layer ownership/contracts are normative.
17. [Executable qualification contract](elv5-implementation/qualification-contract.md): L0–L6 test architecture, 54 primary process verticals, adversarial commands, failure/race/migration/freeze and false-PASS sentinels.
18. [Normative requirements registry](elv5-implementation/normative-requirements-registry.json): binds the stable 80 P0–P9 requirement IDs to 42 cross-cutting MUST obligations.
19. [450-case market simulation](elv5-implementation/market-simulation-450-plan.md), requirements/catalog/P0–P9 bindings: design stress evidence only, never process mathematics, ELV7 compliance or ELV8 selection authority.
20. [1500-case combinatorial engineering plan](elv5-implementation/combinatorial-engineering-1500-plan.md), [requirements](elv5-implementation/combinatorial-engineering-requirements.json), [legal-pair registry](elv5-implementation/combinatorial-legal-pair-constraints.json), [targeted 3-wise inventory](elv5-implementation/combinatorial-targeted-three-wise.json), [42-row covering template](elv5-implementation/combinatorial-covering-template-v1.json), [36 system-wide inventory](elv5-implementation/combinatorial-system-wide-inventory.json) and P8/P9 amendment. The target is exactly **1500 deterministic scenarios**, **16 011 / 16 011 legal pairs** and **330 / 330 targeted 3-wise obligations**.
21. [Machine-readable 16-command registry](elv5-implementation/command-registry.json) and [canonical command examples](elv5-implementation/command-examples.json).
22. [27-process contract registry](elv5-implementation/process-contracts.md) and [machine-readable process registry](elv5-implementation/process-registry.json).
23. [Downstream handoff registry](elv5-implementation/downstream-handoff-registry.json): machine boundary for ELV5 → ELV6/ELV7/ELV8. Downstream runtime requires exact accepted ELV5 source SHA, authority fingerprint and runtime evidence; an older design SHA alone cannot authorize runtime.
24. [Authority manifest generator](../../scripts/ci/generate-elv5-contract-manifest.py): exact-head SHA-256 authority manifest/fingerprint.
25. Baseline/audit evidence: [baseline alignment](../audit/elv5-baseline-alignment-audit.md), initial technical audit, second-pass engineering/architecture audit, third-pass production-readiness audit, fourth-pass algorithm/performance audit, fifth-pass specification closure, sixth-pass code-binding/performance audit, and [seventh-pass project-alignment audit](../audit/elv5-seventh-pass-project-alignment-audit.md) with machine-readable JSON.
26. [Implemented baseline and extension contract](elv5-implementation/implemented-baseline.md) and [evidence manifest](elv5-implementation/baseline.json).

## Authority and acceptance

Existing ELV1–ELV4 identities, ownership, reference editions, physical routing, revision lifecycle and accepted ELV4 runtime evidence remain authoritative. ELV5 adds typed discipline definitions and versioned process registration, not replacement ports/cables/power sources/batteries/cache/history/revision lifecycles.

Within ELV5 the precedence is explicit. Highest authority first:

1. `project-alignment-hardening-v1.md` for the specific authority/status/resolver/source-layout/schema/oracle/downstream contradictions it reconciles;
2. `implementation-binding-hardening-v1.md` plus `implementation-binding-registry.json`, `repository-contract-registry.json`, `runtime-version-registry.json`, `algorithm-performance-registry.json`, `finding-trace-code-registry.json` and ADR-031 for direct implementation binding/version/performance/source-layer ownership;
3. `code-level-hardening-v2.md`;
4. `code-level-hardening-amendments.md`;
5. `calculation-oracle-errata-v1.md` for exact corrected arithmetic it names;
6. machine-readable command/process/algorithm registries for membership/key/solver inventories not superseded above;
7. `process-contracts.md` plus the 27 process dossiers as one calculation layer;
8. engineering primitives, typed process API, unified calculation engine, Flutter performance, schema-24 persistence and qualification contracts;
9. stable requirement ledger + normative registry + combinatorial requirements/registries;
10. base runtime contract and production source blueprint;
11. package P0–P9 prose;
12. market-simulation requirements/catalog/plan as **stress and coverage evidence only**.

A contradiction between active normative artifacts without an explicit higher-authority reconciliation is a specification failure, not a developer choice. P0 implementation entry requires the generated authority fingerprint/manifest and all CI consistency guards.

### Resolver and source-layout rule

Repository-aware `InputResolver` execution belongs to the application layer. Pure `engineering_core` process definitions/kernels receive immutable typed inputs and never read DB/Drift/UI/platform state.

Public symbols, process identities, semantic contracts and layer ownership are normative. Exact filenames are tracked implementation coordinates: a path-only move requires synchronized implementation-binding/manifest update but is not an engineering formula change when public semantics and dependency direction remain identical. ADR-031 is the architectural decision for this pure-core/application-resolver boundary and the nested `engineering_core/lib/src/elv5/...` bounded-context layout.

### Version/status rule

Production acceptance uses `runtime-version-registry.json`. Older `1-design` and `DESIGN DRAFT` labels are provenance where a later frozen registry/amendment exists; they do not authorize a competing runtime version. Initial ELV5 DB target is **schema 24**.

### Downstream runtime rule

ELV6/ELV7/ELV8 design work based on older ELV5 SHAs remains useful design material, but runtime entry is blocked until downstream P0 reconciles to the exact accepted ELV5 runtime/source SHA, authority fingerprint, implemented schema/projection versions and runtime acceptance evidence. ELV6 cannot infer layout PASS from LAN-06 basis; ELV7 alone owns verified jurisdictional compliance; ELV8 selection cannot rewrite upstream calculations.

The initial ELV5 discipline command registry remains exactly **16 operations** under `electra.elv5-discipline-command.v1`, payload version 1. ELV4 revision freeze/create-next commands remain the public revision boundary.

All ELV5 P0–P9 runtime packages remain `NOT_STARTED`. ELV4 is implemented, runtime accepted and merged through PR #11 at `d2b059d4c11a284cdd32965140f6df3c40020c8d`. ELV4 acceptance does not qualify the 27 new ELV5 processes or any of the 16 ELV5 command codecs.

## Audit status

Historical specification hardening:

- first pass: **6 HIGH + 2 MEDIUM = 8**, resolved;
- second pass: **10 HIGH + 4 MEDIUM = 14**, resolved;
- third pass: **11 HIGH + 4 MEDIUM = 15**, resolved; historical subtotal through third pass = **37**;
- fourth pass: **15 HIGH + 4 MEDIUM = 19**, resolved; historical subtotal through fourth pass = **56**;
- fifth-pass specification/combinatorial closure: **6 HIGH + 2 MEDIUM = 8**, resolved, open=0;
- sixth-pass implementation binding/performance closure: **7 HIGH + 3 MEDIUM = 10**, resolved, open=0;
- seventh-pass project alignment: **5 HIGH + 5 MEDIUM = 10**, resolved in ELV5 specification, open ELV5 findings=0; downstream reconciliation remains required before ELV6 runtime.

The unified calculation-engine pass is an architectural consolidation rather than a separate finding count.

The market-simulation layer adds **12 mandatory simulation requirements** and exactly **450 deterministic design scenarios**. The combinatorial layer adds exactly **1500 deterministic scenarios**, full legal pair coverage and exact targeted 3-wise coverage. Neither is production runtime acceptance.

## Implementation-readiness gate

The following are frozen enough to start implementation:

- exactly **27** process codes/scopes/dependencies and typed process input/output boundaries;
- exactly **27** algorithm mappings and **27×25** process dossier sections;
- pure application-resolver → immutable input → engineering-core kernel/evaluate → guarded publication layering;
- positive/boundary/negative/adversarial/cross-discipline vectors for all 27 processes;
- synchronized ACS-03 canonical oracle **23.51 V / +1.51 V**;
- exact/bounded engineering quantities, legal quantity algebra, captured time/frame/evidence semantics and deterministic hashing;
- exactly **16** public command operations and handler/protocol bindings;
- additive Drift **schema 24** with ownership/PK/FK/index/migration rules;
- selector-aware invalidation, replay/history/freeze/create-next integration and bounded atomic publication;
- frozen bulk repository access with N+1 forbidden;
- frozen per-process complexity/workload/hard bounds and deterministic worker execution;
- native medium/large kernels outside Flutter UI isolate; web policy does not assume native isolate parallelism;
- stable finding/trace namespaces and runtime process versions;
- **54** primary process oracles + **135** dossier vectors + **450** market scenarios + **1500** combinatorial scenarios as distinct evidence layers;
- **80** stable P0–P9 requirements + **42** cross-cutting MUST obligations + market/combinatorial requirement layers;
- exact-head authority manifest/fingerprint including binding, fifth/sixth/seventh-pass and downstream-handoff artifacts.

The generated authority manifest, market simulation and combinatorial matrix are **design-entry evidence**, not runtime acceptance. Production P0/P9 source must record/verify the accepted authority fingerprint so implementation cannot close against a different specification.

Remaining work is executable runtime work: implement production Dart/Drift source, schema-24 migration, 27 process kernels/resolvers, 16 codecs/handlers, worker executor/scheduler/cache, public-command qualification, migration/restart/race/failure evidence, performance evidence and exact-SHA P9 closure. Downstream ELV6 runtime remains blocked until the accepted ELV5 runtime/source/fingerprint handoff is reconciled.
## Executable diff audit — 2026-10-16

The [scoped diff audit](../audit/elv5-diff-review-2026-10-16.md) and
[executed check log](../audit/elv5-diff-review-checks.json) record five P1 and one P2
corrections after the historical seventh-pass closure: authority/source integrity,
market-plan versus diagnostic evidence, cross-binding fire-address uniqueness,
CCTV rate-window/bound claims, and executed command rejection probes. Historical
finding counts above remain historical; this pass does not create runtime acceptance.
The affected normative contracts are updated in place. ELV5 remains NOT_STARTED.
