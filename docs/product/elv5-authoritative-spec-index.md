# Electra — ELV5 Authoritative Design Index

Status: **DESIGN READY FOR DEVELOPMENT / PROJECT ALIGNMENT CLOSED / RUNTIME NOT STARTED**  
Branch: `feat/flutter-elv5-power-topology-design`  
Parent design branch: `feat/flutter-elv4-power-topology-design`  
Accepted ELV4 source: `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`  
Merged accepted ELV4 baseline: `main@d2b059d4c11a284cdd32965140f6df3c40020c8d`

ELV5 is **discipline-specific engineering calculations**, not a second power-topology foundation. ELV4 owns common physical power models; ELV5 owns discipline-specific calling context, policies, technical calculations and their immutable evidence.

## Entry documents

1. [Project-wide alignment hardening v1](elv5-implementation/project-alignment-hardening-v1.md) — highest ELV5 reconciliation layer for authority/status/resolver/schema/oracle/downstream handoff and the eighth-pass implementation-readiness corrections ELV5-R8-01…R8-10.
2. [ELV5 design specification](elv5-discipline-calculations-design-specification.md).
3. [P0–P9 delivery plan](elv5-p0-p9-delivery-plan.md).
4. [Detailed implementation index](elv5-implementation/README.md), with one contract for each package.
5. [Implementation binding/performance hardening](elv5-implementation/implementation-binding-hardening-v1.md) plus machine registries: [implementation bindings](elv5-implementation/implementation-binding-registry.json), [repository contracts](elv5-implementation/repository-contract-registry.json), [runtime versions](elv5-implementation/runtime-version-registry.json), [algorithm performance](elv5-implementation/algorithm-performance-registry.json), and [finding/trace codes](elv5-implementation/finding-trace-code-registry.json). The pure-core/application resolver and nested-module architecture is frozen by [ADR-031 — ELV5 pure-core and module boundary](../adr/ADR-031-elv5-pure-core-and-module-boundary.md).
6. [Code-level runtime contract](elv5-implementation/code-level-runtime-contract.md): base runtime types, strict wire envelope, 16-operation public command surface, replay/CAS/publication/persistence/dependency contracts.
7. [Engineering primitives contract](elv5-implementation/engineering-primitives-contract.md): dimension-safe exact quantities, evidence basis/applicability, operating cases, deterministic time/frames and canonical hashing.
8. [Typed process API](elv5-implementation/typed-process-api.md): process-specific Dart input/output boundaries for all 27 calculations. For the ten explicitly corrected implementation-entry clauses, section 11 of project-alignment hardening supersedes older schematic snippets.
9. [Unified calculation engine](elv5-implementation/calculation-engine-contract.md): deterministic execution lifecycle for all 27 processes.
10. [Machine algorithm registry](elv5-implementation/algorithm-registry.json): exact 27/27 process-to-solver mapping.
11. [27-process code-level specification](elv5-implementation/process-code-level-specification.md) plus [CCTV](elv5-implementation/process-specifications/cctv-processes.md), [LAN](elv5-implementation/process-specifications/lan-processes.md), [ACS](elv5-implementation/process-specifications/acs-processes.md), and [Fire](elv5-implementation/process-specifications/fire-processes.md) dossiers.
12. [Calculation reference-oracle errata v1](elv5-implementation/calculation-oracle-errata-v1.md): canonical ACS-03 positive oracle **23.51 V / +1.51 V**.
13. [Flutter ultra-performance runtime contract](elv5-implementation/flutter-performance-contract.md).
14. [Drift schema 24 persistence contract](elv5-implementation/persistence-schema-contract.md). Section 11 of project-alignment hardening additionally freezes global `evaluationId` uniqueness, one-active-root aggregate identities, schedule-profile ownership and recorder storage-pool identity.
15. [Code-level hardening amendments](elv5-implementation/code-level-hardening-amendments.md) and [third-pass hardening v2](elv5-implementation/code-level-hardening-v2.md).
16. [Production source blueprint](elv5-implementation/production-source-blueprint.md).
17. [Executable qualification contract](elv5-implementation/qualification-contract.md): L0–L6 test architecture and 54 primary process verticals.
18. [Normative requirements registry](elv5-implementation/normative-requirements-registry.json): 80 P0–P9 requirement IDs + 42 cross-cutting MUST obligations.
19. [450-case market simulation](elv5-implementation/market-simulation-450-plan.md): design stress evidence only.
20. [1500-case combinatorial engineering plan](elv5-implementation/combinatorial-engineering-1500-plan.md) and machine constraint/3-wise/system inventories: exactly **1500 deterministic scenarios**, **16 011 / 16 011 legal pairs** and **330 / 330 targeted 3-wise obligations**.
21. [Machine-readable command registry](elv5-implementation/command-registry.json) and [canonical command examples](elv5-implementation/command-examples.json). The command registry now freezes nested schemas for all 16 operations.
22. [27-process contract registry](elv5-implementation/process-contracts.md) and [machine process registry](elv5-implementation/process-registry.json).
23. [Downstream handoff registry](elv5-implementation/downstream-handoff-registry.json): ELV5 → ELV6/ELV7/ELV8 boundary.
24. [Authority manifest generator](../../scripts/ci/generate-elv5-contract-manifest.py): exact-head SHA-256 authority manifest/fingerprint.
25. Baseline/audit evidence through the [seventh-pass project-alignment audit](../audit/elv5-seventh-pass-project-alignment-audit.md).
26. [Implemented baseline](elv5-implementation/implemented-baseline.md) and [baseline evidence](elv5-implementation/baseline.json).
27. [Development-readiness registry](elv5-implementation/development-readiness-registry.json) and [eighth-pass development-readiness audit](../audit/elv5-eighth-pass-development-readiness-audit.md): **7 HIGH + 3 MEDIUM = 10 resolved, open=0**. The registry is transitively exact-head pinned by its SHA-256 in `command-registry.json` and verified by the project-alignment CI guard.

## Authority and acceptance

Existing ELV1–ELV4 identities, ownership, reference editions, physical routing, revision lifecycle and accepted ELV4 runtime evidence remain authoritative. ELV5 adds typed discipline definitions and versioned process registration, not replacement ports/cables/power sources/batteries/cache/history/revision lifecycles.

Within ELV5 the precedence is explicit. Highest authority first:

1. `project-alignment-hardening-v1.md` for authority/status/resolver/source-layout/schema/oracle/downstream and ELV5-R8-01…R8-10 implementation-readiness reconciliation;
2. `implementation-binding-hardening-v1.md` plus `implementation-binding-registry.json`, `repository-contract-registry.json`, `runtime-version-registry.json`, `algorithm-performance-registry.json`, `finding-trace-code-registry.json` and ADR-031;
3. `code-level-hardening-v2.md`;
4. `code-level-hardening-amendments.md`;
5. `calculation-oracle-errata-v1.md`;
6. machine-readable command/process/algorithm registries, including nested command schemas and the transitively pinned development-readiness registry;
7. `process-contracts.md` plus the 27 process dossiers;
8. engineering primitives, typed process API, unified calculation engine, Flutter performance, schema-24 persistence and qualification contracts;
9. stable requirement ledger + normative registry + combinatorial requirements/registries;
10. base runtime contract and production source blueprint;
11. package P0–P9 prose;
12. market-simulation requirements/catalog/plan as **stress and coverage evidence only**.

A contradiction between active normative artifacts without an explicit higher-authority reconciliation is a specification failure, not a developer choice. The ten eighth-pass discrepancies are explicitly reconciled by the highest-authority section 11 and machine registry.

### Resolver and source-layout rule

Repository-aware `InputResolver` execution belongs to the application layer. Pure `engineering_core` process definitions/kernels receive immutable typed inputs and never read DB/Drift/UI/platform state.

Public symbols, process identities, semantic contracts and layer ownership are normative. Exact filenames are tracked implementation coordinates. ADR-031 is the architectural decision for this pure-core/application-resolver boundary.

### Version/status rule

Production acceptance uses `runtime-version-registry.json`. Registry integer schema versions canonicalize to base-10 strings at Dart/hash boundaries (`1 -> "1"`). Older `1-design` and `DESIGN DRAFT` labels are provenance when a later frozen registry/amendment exists. Initial ELV5 DB target is **schema 24**.

### Downstream runtime rule

ELV6/ELV7/ELV8 design work may continue, but runtime entry is blocked until downstream P0 reconciles to the exact accepted ELV5 runtime/source SHA, authority fingerprint, implemented schema/projection versions and runtime acceptance evidence. ELV6 cannot infer layout PASS from LAN-06 basis; ELV7 alone owns verified jurisdictional compliance; ELV8 selection cannot rewrite upstream calculations.

The initial ELV5 discipline command registry remains exactly **16 operations** under `electra.elv5-discipline-command.v1`, payload version 1. ELV4 revision freeze/create-next commands remain the public revision boundary.

All ELV5 production runtime packages remain `NOT_STARTED`. `READY FOR DEVELOPMENT` is an implementation authorization state, not a runtime acceptance state.

## Audit status

Historical specification hardening:

- first pass: **6 HIGH + 2 MEDIUM = 8**, resolved;
- second pass: **10 HIGH + 4 MEDIUM = 14**, resolved;
- third pass: **11 HIGH + 4 MEDIUM = 15**, resolved;
- fourth pass: **15 HIGH + 4 MEDIUM = 19**, resolved; historical subtotal through fourth pass = **56**;
- fifth-pass specification/combinatorial closure: **6 HIGH + 2 MEDIUM = 8**, resolved, open=0;
- sixth-pass implementation binding/performance closure: **7 HIGH + 3 MEDIUM = 10**, resolved, open=0;
- seventh-pass project alignment: **5 HIGH + 5 MEDIUM = 10**, resolved, open ELV5 findings=0;
- eighth-pass implementation readiness: **7 HIGH + 3 MEDIUM = 10**, resolved, open=0.

The market-simulation layer adds **12 mandatory simulation requirements** and exactly **450 deterministic design scenarios**. The combinatorial layer adds exactly **1500 deterministic scenarios**, full legal pair coverage and exact targeted 3-wise coverage. Neither is production runtime acceptance.

## Implementation-readiness gate

The following are frozen enough to start implementation:

- exactly **27** process codes/scopes/dependencies and typed process input/output boundaries;
- exactly **27** algorithm mappings and **27×25** process dossier sections;
- pure application-resolver → immutable input → engineering-core kernel/evaluate → guarded publication layering;
- positive/boundary/negative/adversarial/cross-discipline vectors for all 27 processes;
- synchronized ACS-03 canonical oracle **23.51 V / +1.51 V**;
- exact/bounded engineering quantities and deterministic hashing;
- exactly **16** public command operations with machine-frozen top-level **and nested** payload schemas;
- CCTV-02 explicit subscription/multicast group/tree identity and deterministic de-duplication;
- CCTV-03 explicit assignment→schedule-profile ownership and `reserveMultiplier >= 1`;
- CCTV-05 explicit recorder assignment→`storagePoolId`;
- additive Drift **schema 24**, global evaluation-ID uniqueness and one-active-root canonical aggregate identities;
- revision-wide fire address uniqueness within the canonical physical address domain;
- dimension-safe LAN-06 mass handoff to ELV6;
- selector-aware invalidation, replay/history/freeze/create-next integration and bounded atomic publication;
- frozen bulk repository access with N+1 forbidden;
- frozen per-process complexity/workload/hard bounds and deterministic worker execution;
- **54** primary process oracles + **135** dossier vectors + **450** market scenarios + **1500** combinatorial scenarios;
- **80** stable P0–P9 requirements + **42** cross-cutting MUST obligations;
- exact-head authority manifest/fingerprint and enhanced project-alignment guard.

Package decision:

```text
P0  GO
P1  GO
P2  READY FOR IMPLEMENTATION
P3  READY FOR IMPLEMENTATION
P4  READY FOR IMPLEMENTATION
P5  READY FOR IMPLEMENTATION
P6  READY FOR IMPLEMENTATION
P7  READY FOR IMPLEMENTATION
P8  ACCEPTANCE DESIGN READY
P9  CLOSURE DESIGN READY
```

**ELV5 specification status: READY FOR DEVELOPMENT.**

The generated authority manifest, market simulation and combinatorial matrix are design-entry evidence, not runtime acceptance. Remaining work is executable runtime work: production Dart/Drift source, schema-24 migration, 27 process kernels/resolvers, 16 codecs/handlers, worker executor/scheduler/cache, public-command qualification, migration/restart/race/failure evidence, performance evidence and exact-SHA P9 closure.

Downstream ELV6 runtime remains blocked until the accepted ELV5 runtime/source/fingerprint handoff is reconciled.

## Executable audits — 2026-10-16

The scoped diff audit fixed authority/source integrity, market-plan versus diagnostic evidence, cross-binding fire-address uniqueness, CCTV rate-window/bound claims and executed command rejection probes while keeping runtime `NOT_STARTED`.

The eighth-pass development-readiness audit then closed the ten remaining contract-to-implementation gaps ELV5-R8-01…R8-10. The affected implementation-entry semantics are frozen in the highest-authority project-alignment amendment and `development-readiness-registry.json`; the command registry pins that registry by SHA-256 and the existing project-alignment CI step verifies it.
