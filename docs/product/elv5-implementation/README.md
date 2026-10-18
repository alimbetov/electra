# ELV5 — Implementation design index

Status: **DESIGN HARDENED / PROJECT ALIGNMENT CLOSED / RUNTIME NOT STARTED**  
Branch: `feat/flutter-elv5-power-topology-design`  
Accepted upstream: merged ELV4 `main@d2b059d4c11a284cdd32965140f6df3c40020c8d`.

ELV5 registers 27 discipline processes and consumes shared ELV3/ELV4 facts. It does not duplicate power topology or create a separate project/revision/history platform. [Governing design](../elv5-discipline-calculations-design-specification.md) defines shared extensions and stage boundaries; [project alignment hardening](project-alignment-hardening-v1.md) closes the latest project-wide authority/resolver/schema/oracle/downstream contradictions.

## Mandatory code-level contracts

The runtime specification is split by concern, with precedence defined by the [authoritative index](../elv5-authoritative-spec-index.md):

- [Project alignment hardening v1](project-alignment-hardening-v1.md): current authority-chain, resolver ownership, source-layout, ACS-03 oracle, schema-24, roadmap and downstream handoff reconciliation.
- [Implementation binding/performance hardening](implementation-binding-hardening-v1.md): direct P0–P6 symbol/layer/repository/version/performance rules.
- Machine binding registries: [implementation](implementation-binding-registry.json), [repositories](repository-contract-registry.json), [runtime versions](runtime-version-registry.json), [algorithm performance](algorithm-performance-registry.json), [findings/trace](finding-trace-code-registry.json).
- [Code-level runtime contract](code-level-runtime-contract.md): base runtime model, `engineering-node-v3`, status axes, strict ELV5 wire envelope, replay-first protocol, dependencies and guarded publication.
- [Engineering primitives](engineering-primitives-contract.md): dimension-safe exact quantities, evidence basis/applicability, operating cases, deterministic time/frames and `electra.canonical-json.v1` hashing.
- [Typed process API](typed-process-api.md): concrete Dart input/output semantics for all 27 process definitions. `engineering_core` is pure; repository-aware `InputResolver` belongs to the application layer.
- [Unified calculation engine](calculation-engine-contract.md): deterministic lifecycle for all 27 processes, solver families, applicability, operating cases, conservative comparison, governing case, limiting factor, trace and bounded sensitivity/what-if semantics.
- [Machine algorithm registry](algorithm-registry.json): exact 27/27 solver-family/operating-case/governing/margin/limiting-factor mapping.
- [27-process code-level specification](process-code-level-specification.md) and four production dossiers: [CCTV](process-specifications/cctv-processes.md), [LAN](process-specifications/lan-processes.md), [ACS](process-specifications/acs-processes.md), [Fire](process-specifications/fire-processes.md). Together: **27×25 implementation sections**.
- [Calculation oracle errata](calculation-oracle-errata-v1.md): synchronized ACS-03 fixture **23.51 V terminal / +1.51 V headroom**.
- [Flutter performance contract](flutter-performance-contract.md): native worker-isolate scheduling for medium/large kernels, deterministic parallel DAG, incremental recomputation, cache, cancellation/backpressure, bounded DB capture/publish and virtualized UI.
- [Drift schema 24 contract](persistence-schema-contract.md): concrete persistence/migration/root/member/evaluation/pointer/index/snapshot design. Schema 24 is frozen by `runtime-version-registry.json`.
- [Code-level hardening amendments](code-level-hardening-amendments.md) and [hardening v2](code-level-hardening-v2.md): type/evidence/time/policy/transient/fire/dependency/publication hardening.
- [Production source blueprint](production-source-blueprint.md): recommended Dart/Drift source tree and application/data/UI decomposition. Exact filenames are tracked coordinates; public symbols/layer ownership/contracts are normative.
- [Executable qualification contract](qualification-contract.md): L0–L6 proof model, 54 primary process verticals, command adversarial tests, failure/race/restart/migration/freeze and false-PASS sentinels.
- [Stable requirement ledger](requirements.json): exactly 80 P0–P9 requirement IDs.
- [Normative requirements registry](normative-requirements-registry.json): 42 cross-cutting MUST obligations.
- [450-case market simulation](market-simulation-450-plan.md) + requirements/catalog/P0–P9 bindings: market-shaped stress evidence only.
- [1500-case combinatorial plan](combinatorial-engineering-1500-plan.md) + requirements, [legal-pair constraints](combinatorial-legal-pair-constraints.json), [targeted 3-wise](combinatorial-targeted-three-wise.json), [42-row template](combinatorial-covering-template-v1.json), [36 system cases](combinatorial-system-wide-inventory.json): exactly **1500** deterministic scenarios, **16 011 / 16 011** legal pairs and **330 / 330** targeted 3-wise obligations.
- [Downstream handoff registry](downstream-handoff-registry.json): machine contract for ELV5 → ELV6/ELV7/ELV8 exact source/fingerprint/runtime-evidence reconciliation.

The machine wire authority remains [command-registry.json](command-registry.json), with exactly 16 operations; [command-examples.json](command-examples.json) must match exact key sets. Process inventory remains exactly 27 and must match both [process-registry.json](process-registry.json) and [algorithm-registry.json](algorithm-registry.json).

| Package | Specification | Outcome |
|---|---|---|
| P0 | [Baseline and stage integration](p0-baseline.md) | Pin merged ELV4/current schema/capabilities, verify complete authority fingerprint and project-alignment/downstream handoff contract |
| P1 | [Typed discipline profiles and process registry](p1-profiles-registry.md) | Register exactly 27 stable process codes; implement typed identities/primitives/definitions and pure process/kernel boundary |
| P2 | [Persistence, command boundaries and revision evidence](p2-persistence-commands.md) | Implement exact 16-operation wire family, additive schema 24, bulk repository contracts, revision-scoped aspects and isolated evaluation/pointer storage |
| P3 | [CCTV](p3-cctv.md) | CCTV-01…06 from dossiers; priority CCTV-02/03 computational core |
| P4 | [LAN](p4-lan.md) | LAN-01…07; priority LAN-01/05 and typed dB/dBm bidirectional budgets |
| P5 | [ACS](p5-acs.md) | ACS-01…06; priority ACS-03/04/05; ACS-03 executable oracle exactly 23.51 V / +1.51 V |
| P6 | [Fire](p6-fire.md) | FA-01…08; priority FA-02/04/05/06; unsupported safety/electrical models fail closed |
| P7 | [Dependencies/workspace](p7-dependencies-workspace.md) | Owner/scope-aware dependency keys, exact affected DAG, scheduler/cache/cancellation and targeted virtualized UI |
| P8 | [Acceptance](p8-acceptance.md) | 54 primary verticals + 135 dossier vectors + 450 market scenarios + 1500 combinatorial scenarios + migration/race/failure/performance suites |
| P9 | [Closure](p9-closure.md) | Reconcile authority/requirements/processes/algorithms/commands/schema/performance/qualification to one exact source SHA + accepted authority fingerprint |

## Pure core / resolver boundary

Canonical runtime direction:

```text
short DB capture
  -> application-layer InputResolver (bulk reads only)
  -> immutable typed input
  -> engineering_core ProcessDefinition/Kernel
  -> typed output + evaluation draft
  -> application guarded atomic publication
```

Forbidden:

```text
engineering_core -> Drift/SQLite
engineering_core -> Flutter/UI
kernel -> repository
resolver member loop -> point SQL query
worker completion order -> engineering result order/hash
```

A path-only source move is allowed only with synchronized `implementation-binding-registry.json` and authority-manifest update. Moving ownership/layer or changing a public semantic contract is a specification change.

## Priority computational core

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

This order stresses exact quantities, intervals, time rules, path/set accounting, deterministic requirement composition, shared ELV4 evidence and transient/worst-case selection before simpler wrappers/basis checks.

## Qualification pyramid

Distinct evidence layers are retained rather than collapsed:

```text
54      primary POS/NEG process verticals
135     five-class dossier vectors
450     market-shaped design simulations
1500    deterministic combinatorial engineering scenarios
        including 100% legal pair coverage + targeted 3-wise
+       command/migration/restart/race/failure/performance/runtime suites
```

Design simulation never equals production runtime qualification.

## Audit/closure state

Historical design findings through fourth pass: **56 resolved**. Additional closure passes:

- fifth pass: **8 resolved / 0 open** — deterministic combinatorial authority closure;
- sixth pass: **10 resolved / 0 open** — direct source/repository/version/performance binding closure;
- seventh pass: **10 resolved in ELV5 / 0 open ELV5 findings** — project-wide authority/resolver/oracle/schema/roadmap/downstream alignment. Downstream ELV6/7/8 reconciliation is still required before ELV6 runtime.

Legacy `1-design` and older `DESIGN DRAFT` labels are provenance where superseded by frozen runtime registries/amendments; production source/result hashes use `runtime-version-registry.json`.

## Design-to-runtime consistency gate

Before a package can claim completion:

1. 27 process codes, 27 algorithm mappings and 27×25 dossiers agree.
2. Pure process definitions/kernels have no DB/UI/platform dependency; application resolvers use only declared bulk read contracts.
3. ACS-03 active oracle is exactly `23.51 V / +1.51 V`; stale `23.45/+1.45` is rejected.
4. 16 command operations, exact payload keys and 16 implementation handler/protocol bindings agree.
5. Runtime versions use `runtime-version-registry.json`; initial database target is schema 24.
6. Selector/set/missing dependency capture handles old/new closure and newly matching facts.
7. Medium/large kernels execute outside native UI isolate; worker count/order cannot change results.
8. Complexity/hard bounds and >15% controlled performance-regression rule remain enforced.
9. 54 + 135 + 450 + 1500 evidence layers remain distinct and machine checked.
10. Generated manifest fingerprints the complete active authority, including fifth/sixth/seventh-pass and downstream handoff files.
11. P9 evidence is generated at one exact tested source SHA matching the accepted authority fingerprint.
12. ELV6 runtime remains blocked until its P0 reconciles to the accepted ELV5 source SHA, authority fingerprint, implemented schema/projection versions and runtime acceptance evidence.

ELV4 is an implemented, runtime-accepted and merged prerequisite. ELV5 runtime remains **NOT STARTED** until executable source and qualification evidence exist.