# ELV5 — Implementation design index

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent source/design: ELV4 `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`.

ELV5 registers 27 discipline processes and consumes shared ELV3/ELV4 facts. It does not duplicate power topology or create a separate project/revision/history platform. [Governing design](../elv5-discipline-calculations-design-specification.md) defines shared extensions and stage boundaries.

## Mandatory code-level contracts

The runtime specification is intentionally split by concern, with explicit precedence defined by the [authoritative index](../elv5-authoritative-spec-index.md):

- [Code-level runtime contract](code-level-runtime-contract.md): base runtime model, `engineering-node-v3`, status axes, strict ELV5 wire envelope, replay-first protocol, dependencies and guarded publication.
- [Engineering primitives](engineering-primitives-contract.md): dimension-safe exact quantities, evidence basis/applicability, operating cases, deterministic time/frames and `electra.canonical-json.v1` hashing.
- [Typed process API](typed-process-api.md): concrete Dart input/output semantics for all 27 process definitions.
- [Unified calculation engine](calculation-engine-contract.md): one deterministic solver lifecycle for all 27 processes, code-owned solver families, applicability resolution, operating-case evaluation, conservative comparison, margin/headroom, governing case, limiting factor, deterministic calculation trace and bounded sensitivity/what-if semantics.
- [Machine algorithm registry](algorithm-registry.json): exact 27/27 binding from process code to solver families, required operating cases, governing rule, margin policy and limiting-factor semantics.
- [27-process code-level specification](process-code-level-specification.md): requires the same **25 implementation sections** for every process.
- Production process dossiers: [CCTV](process-specifications/cctv-processes.md), [LAN](process-specifications/lan-processes.md), [ACS](process-specifications/acs-processes.md), [Fire](process-specifications/fire-processes.md). Together they provide 27×25 code-level sections with exact equations, worst-case/governing/limiting algorithms, complexity, pseudocode, Dart interfaces and positive/boundary/negative/adversarial/cross-discipline vectors.
- [Calculation reference-oracle errata v1](calculation-oracle-errata-v1.md): authority-controlled arithmetic corrections; ACS-03 canonical fixture is corrected to **23.51 V terminal / +1.51 V headroom** for the frozen inputs.
- [Flutter ultra-performance runtime contract](flutter-performance-contract.md): native worker-isolate scheduling for medium/large kernels, web-specific policy, deterministic parallel DAG, incremental recomputation, fingerprint cache, cancellation/backpressure, bounded DB capture/publish, virtualized UI and profile-mode performance evidence.
- [Drift schema 24 contract](persistence-schema-contract.md): concrete persistence/migration/root/member/evaluation/pointer/index/snapshot design.
- [Code-level hardening amendments](code-level-hardening-amendments.md): normative reconciliation of wire/storage details.
- [Third-pass code-level engineering hardening](code-level-hardening-v2.md): **highest-priority shared ELV5 hardening amendment** for strongly typed identities, explicit field-resolution semantics, bounded exact arithmetic, legal quantity algebra, captured timezone-rule evidence, measurement uncertainty, deterministic policy composition, transient simultaneity, ACS release completeness, fire supervision/fault states, selector invalidation, bounded atomic publication and result/review separation.
- [Production source blueprint](production-source-blueprint.md): recommended Dart/Drift source tree, one-way dependency direction, typed command/handler/repository boundaries, exact 16-handler mapping, capture/resolver/publication/invalidation/revision/workspace services and Definition of Done. It is subordinate to higher-priority hardening/errata and the performance contract where those tighten type/resource/execution behavior.
- [Executable qualification contract](qualification-contract.md): L0–L6 proof model, 54 primary process verticals, command adversarial tests, failure/race/restart/migration/freeze and false-PASS sentinels. Third/fourth-pass and unified-engine focused suites are additional mandatory evidence.
- [Stable requirement ledger](requirements.json): exactly 80 P0–P9 requirement IDs retained for traceability.
- [Normative requirements registry](normative-requirements-registry.json): 42 cross-cutting MUST obligations bound back to those stable requirement IDs so later hardening remains enforceable without renumbering the base ledger.
- [450-case market simulation requirements](market-simulation-requirements.json), [market archetype catalog](market-simulation-catalog.json) and [simulation plan](market-simulation-450-plan.md): 12 mandatory design-simulation requirements and exactly 450 deterministic market-shaped combinations spanning all 27 processes, all five vector classes, four project scales and aggregate P0–P9 coverage. These are stress evidence, not runtime acceptance, ELV7 compliance or ELV8 product selection.

The machine wire authority remains [command-registry.json](command-registry.json), with exactly 16 operations; [command-examples.json](command-examples.json) must match its exact key sets. The process inventory remains exactly 27 and must match both [process-registry.json](process-registry.json) and [algorithm-registry.json](algorithm-registry.json).

| Package | Specification | Outcome |
|---|---|---|
| P0 | [Baseline and stage integration](p0-baseline.md) | Pin actual parent source/design SHA, inherited schema/capabilities and migration origins; generate/verify authoritative contract manifest including normative/market requirements, process dossiers, oracle errata and performance contract |
| P1 | [Typed discipline profiles and process registry](p1-profiles-registry.md) | Register exactly 27 stable process codes; implement strongly typed identities, bounded engineering primitives, unified solver protocol, evidence/time/requirement algebra, typed definitions and deterministic workload metadata |
| P2 | [Persistence, command boundaries and revision evidence](p2-persistence-commands.md) | Implement the exact 16-operation wire family, additive schema 24, strict resource bounds, revision-scoped aspects and isolated evaluation/pointer storage; support bounded bulk capture/publish |
| P3 | [CCTV calculation implementation](p3-cctv.md) | Implement CCTV-01…06 exactly from CCTV 25-section dossiers, prioritizing CCTV-02/03 computational core; qualify market-shaped stream/storage/PSE/recorder/path combinations |
| P4 | [LAN and structured-cabling implementation](p4-lan.md) | Implement LAN-01…07 exactly from LAN dossiers, prioritizing LAN-01/05 and typed dB/dBm bidirectional budgets; qualify 8/24/48-port, shared-PoE, copper/fiber and rack-basis combinations |
| P5 | [Access-control implementation](p5-acs.md) | Implement ACS-01…06 exactly from ACS dossiers and oracle errata, prioritizing ACS-03/04/05 transient/source/backup core and five-cause ACS-06 behavior; stress low/high-current lock classes and shared-source scenarios |
| P6 | [Fire-alarm implementation](p6-fire.md) | Implement FA-01…08 exactly from Fire dossiers, prioritizing FA-02/04/05/06 current/source/autonomy/notification core; stress 50/198/954-point classes, current states, source/backup and topology/policy boundaries |
| P7 | [Incremental dependencies and engineer workspace](p7-dependencies-workspace.md) | Encode owner/scope-aware dependency keys, missing/set/selector markers, deterministic affected-node DAG, scheduler/coalescing, semantic reuse and targeted virtualized workspace projection; market simulation must expose error class and remediation direction |
| P8 | [Integrated verification and qualification](p8-acceptance.md) | Execute 54 primary POS/NEG public-command verticals plus 135 dossier vectors and the 450-case market simulation, unified-engine/fourth-pass, worker determinism, scale/performance, command/resource/restart/failure/selector/race/migration/freeze matrices |
| P9 | [Architecture reconciliation and stage handoff](p9-closure.md) | Reconcile 80 requirements, 42 normative obligations, 12 market-simulation requirements, 27 process definitions, 27 algorithm mappings, 27×25 dossiers, 450-case simulation artifact, oracle errata, 16 codecs/handlers, schema 24, performance evidence and contract manifest to one exact source SHA |

[Process contracts](process-contracts.md) and [process registry](process-registry.json) cover CCTV6/LAN7/ACS6/Fire8. [Algorithm registry](algorithm-registry.json) makes their common solver semantics machine-checkable. The four process dossier files make their implementation algorithms mechanically reviewable. [Requirement ledger](requirements.json) contains 80 stable package requirements. [Normative requirements registry](normative-requirements-registry.json) adds 42 MUST obligations, and [market simulation requirements](market-simulation-requirements.json) add 12 design-simulation MUST requirements without changing the stable 80 IDs. Every runtime evidence field is intentionally empty until implementation evidence exists.

ELV4 is an implemented, runtime-accepted and merged prerequisite. Reuse its dedicated power persistence, reviewed writers, captured facts and numerical kernels under the [implemented baseline contract](implemented-baseline.md). ELV5 schema 24 is additive and must not reinterpret or duplicate ELV3/ELV4 canonical ownership.

The [initial technical audit](../../audit/elv5-technical-audit.md) resolved 8 discipline-contract findings in specification. The [second-pass engineering/architecture audit](../../audit/elv5-engineering-architecture-hardening-audit.md) resolved a further 14 design findings. The [third-pass production-readiness audit](../../audit/elv5-third-pass-production-readiness-audit.md) resolves 15 more. Historical third-pass subtotal: **37** specification resolutions. The [fourth-pass algorithm/performance audit](../../audit/elv5-fourth-pass-algorithm-performance-audit.md) resolves another **19 (15 HIGH + 4 MEDIUM)** findings, including the independent ACS-03 reference-oracle arithmetic correction. Runtime remains NOT STARTED; **56 specification resolutions are not runtime fixes**.

## Priority computational core

Implementation should exercise the hardest/most reusable mathematical primitives first:

```text
1  CCTV-02  directed bandwidth/flow accounting
2  CCTV-03  storage/time integration
3  LAN-01   installed path length
4  LAN-05   bidirectional optical interval budget
5  ACS-03   lock electrical/transient evidence
6  ACS-04   source/PSU requirement projection
7  ACS-05   backup/autonomy projection
8  FA-02    standby/alarm current aggregation
9  FA-04    source requirement projection
10 FA-05    standby/alarm autonomy sequence
11 FA-06    notification circuit capacity
```

This order deliberately stresses exact quantities, interval arithmetic, time rules, path/set accounting, deterministic requirement composition, shared ELV4 physical evidence and transient/worst-case selection before implementing the simpler wrappers/basis checks. The 450-case matrix allocates 23–24 scenarios to each of these processes and 12 to every other process, yielding exactly 450 combinations.

## Market-simulation role

The market matrix is deliberately **below process mathematics in authority**. It provides realistic combinations, not alternate formulas. Current manufacturer facts are captured separately from market envelopes and synthetic fixtures.

The matrix is designed to expose recurring engineering mistakes, including:

```text
duplicate cable/port/address/resource counting
W vs Wh, A vs Ah, dB vs dBm, bit/s vs bytes
typical/estimated values used as guaranteed
reserve/derating/redundancy applied twice
discipline-filtered shared PSE/source/bank totals
stale result publication after edit/freeze
bitrate inferred from codec/resolution label
multicast false dedup
storage interval overlap / repeated ceil
optical overload ignored
optical budget mistaken for reach
rack capacity mistaken for ELV6 fit
relay control mistaken for conductive lock feed
startup/inrush omitted
incomplete fail-safe/fail-secure release truth
nominal Ah shortcut
fire address overlap
signal topology mistaken for electrical model
technical policy match mistaken for legal compliance
N+1 data capture and global Flutter rebuilds
```

Every generated scenario records a stable primary error class, expected disposition, relevant P0–P9 path and remediation direction. The future UI should use the same structured finding/remediation approach instead of unexplained prose.

## Design-to-runtime consistency gate

Before an implementation package can claim completion, these inventories must agree exactly:

1. **27** process codes/scopes/dependencies/required dimensions in registry, process contracts and typed runtime definitions.
2. **27** algorithm mappings with legal solver families, explicit operating cases, governing rules, margin policies and limiting-factor semantics.
3. **25 ordered code-level sections for every process**, with no TBD/placeholder, including five vector classes and explicit complexity/resource model.
4. Authority-controlled oracle corrections are applied to executable fixtures; ACS-03 exact fixture uses 23.51 V/+1.51 V.
5. **80** stable P0–P9 requirements remain 8 per package, while all **42 normative MUST obligations** stay bound to those IDs and all **12 market-simulation MUST requirements** stay tracked separately.
6. Exactly **450 deterministic market-simulation cases** cover 27/27 processes, all five vector classes per process, all P0–P9 packages in aggregate, current manufacturer evidence anchors and at least 18 distinct engineer error classes.
7. Strongly typed subject/scope identities and explicit known/missing/N-A/unsupported/unresolved field semantics at the domain/kernel boundary.
8. Engineering quantity/evidence/measurement/time/frame/hash semantics in primitives and production codecs/kernels, including captured timezone-rule evidence and code-owned legal quantity algebra.
9. Unified engine lifecycle `capture → applicability → resolve → normalize → cases → kernel → requirements → conservative compare → governing/margin → statuses → trace → findings → guarded publish` implemented without hidden UI/database dependencies.
10. Process-specific mathematical model/equations, exact/bounded arithmetic, worst-case, comparison, margin, governing and limiting behavior match the corresponding dossier/errata.
11. **16** command operations and their exact payload key sets in registry, examples, production handler registry and runtime semantic codecs.
12. Hardened camera subscriptions, recording temporal/reserve/redundancy basis and ACS release truth table across wire → persistence → typed resolver.
13. Deterministic requirement-merger and simultaneity/transient policies where required; no intuitive policy winner or hidden steady-state approximation.
14. Drift **schema 24** tables/indexes/migration and ownership map.
15. Selector/set/missing dependency capture invalidates on old/new closure and on creation of newly matching facts.
16. Coherent batch publication remains all-or-nothing while respecting explicit target/resource/SQL bounds.
17. Native medium/large kernels execute through `Elv5CalculationExecutor` outside UI isolate; worker count/order cannot change deterministic output.
18. Incremental recomputation, cancellation/supersession/backpressure and semantic fingerprint cache prevent stale/unnecessary work.
19. Capture/publish uses bounded bulk queries/indexes, with no N+1 scale-fixture regression.
20. Workspace projection uses immutable targeted view models and lazy/virtualized large collections; engineering math/DB access never runs in widget `build()`.
21. **54** primary POS/NEG entries plus **135 process-vector cases**, 450 market combinations and third/fourth-pass/unified-engine focused suites remain distinct evidence layers inside L0–L6 acceptance.
22. Profile-mode scale/performance artifact proves UI/raster frame budgets and records capture/kernel/publish/projection metrics on exact source SHA.
23. Pure engineering core has no Flutter/Drift dependency; application orchestration owns capture/publish/scheduling; repository adapters reconstruct typed domain identities and hide generated Drift rows.
24. Generated contract manifest fingerprints process, algorithm, command, stable/normative/market requirement inventories, market catalog, all four process dossier files, oracle errata, performance contract and full governing authority chain at the exact tested source SHA.

Any mismatch is a specification/runtime defect and must not be resolved by ad-hoc fallback, label inference, latest-definition lookup, `null` convention, UI-side engineering calculation, package-local formula override, main-isolate shortcut for medium/large production work, market-fixture promotion to guaranteed evidence or engineer waiver that mutates an immutable technical result.
