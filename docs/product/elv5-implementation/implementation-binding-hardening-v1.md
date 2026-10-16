# ELV5 — Implementation binding and performance hardening v1

Status: DESIGN FROZEN / RUNTIME NOT STARTED

This amendment closes the remaining gap between the hardened ELV5 engineering design and direct P0–P6 source implementation. Where it tightens older source-blueprint, typed-API, process-registry version or package prose, this document and its machine registries govern implementation entry. The later `project-alignment-hardening-v1.md` governs only where it explicitly reconciles project-wide authority/status/handoff contradictions discovered after this amendment.

## Frozen machine authorities

Implementation MUST conform to:

- `implementation-binding-registry.json` — exact 27 process definition/resolver/kernel/type/read bindings plus tracked production module coordinates and exact 16 command handler bindings.
- `repository-contract-registry.json` — bulk-only capture/read contracts, no-N+1 policy and replay/publish write protocols.
- `runtime-version-registry.json` — implementation-entry algorithm/input/output/trace/numeric/canonical/wire/schema versions.
- `algorithm-performance-registry.json` — per-process complexity/workload/strategy/hard-bound contract.
- `finding-trace-code-registry.json` — stable finding namespaces and code-owned trace prefixes.

Legacy `1-design` version labels in older design registries are descriptive design provenance only. Production source, result hashes and acceptance evidence MUST use `runtime-version-registry.json`.

The runtime-version registry freezes the initial ELV5 additive database target at **schema 24**. This later freeze supersedes earlier baseline wording that deferred choosing an additive version greater than 23 until implementation. Any future schema-number change requires synchronized persistence/runtime-version/manifest/migration review; a developer may not choose another number locally.

## Process definition versus resolver ownership

Repository-aware input resolution belongs to the application layer.

`engineering_core` owns pure process metadata, typed input/output semantics, `calculate()` and `evaluate()`. It does **not** own repository-aware input resolution.

Application-layer `*InputResolver` symbols own semantic input assembly and may depend only on declared repository interfaces/capture projections. The architecture is:

```text
application capture/resolver
    -> immutable typed input
    -> engineering_core pure ProcessDefinition/Kernel
    -> typed output/evaluation draft
    -> application guarded publication
```

Any older `Elv5TypedProcessDefinition.resolveInput(...)` example is superseded. A pure process definition/kernel MUST NOT read repositories, Drift rows, UI state, platform services or mutable workspace state.

## Source-layout policy

Public implementation symbols, layer ownership, typed contracts, process codes and dependency direction are normative. The `definitionPath`/`resolverPath` values in `implementation-binding-registry.json` are tracked default production coordinates used for traceability and acceptance mapping; **the exact filename is not engineering semantics**.

A layout-only rename/move is allowed only when all of the following hold:

1. the process/handler public symbol and typed contract are unchanged;
2. `engineering_core` versus application/data/UI dependency direction is unchanged;
3. the implementation-binding registry is updated in the same change;
4. the authority manifest/fingerprint is regenerated;
5. no runtime evidence points to an obsolete source path.

Changing ownership/layer, public symbol meaning, input/output semantics or dependency direction is a specification change and requires architecture review. This reconciles older wording that allowed source-file split flexibility with the machine-owned binding registry without turning filenames into physical-engineering truth.

The nested `packages/engineering_core/lib/src/elv5/...` module is an intentional bounded-context decomposition of the existing `engineering_core` package, not a second core package. It preserves the public package boundary while avoiding a flat 27-process source namespace.

## P0–P2 binding rules

P0 MUST bind inherited ELV3/ELV4/platform capabilities through the shared adapters named by the repository registry. It may not create package-local cable, port, source, battery, revision, ledger or history ownership.

P1 MUST implement all 27 exact definition/resolver/kernel symbols and semantic I/O types named by the implementation binding registry. Path-only changes follow the source-layout policy above; symbol/ownership/semantic changes require authority review.

P2 MUST expose repository methods equivalent to the frozen bulk contracts. Query count must be independent of member cardinality. A resolver loop that performs one SQL query per stream/device/port/address is a release-blocking defect.

All 15 replacement mutations use `REPLAY_FIRST_REPLACEMENT`. Calculation uses `CAPTURE_RUN_GUARDED_PUBLISH`. The ordered protocol steps are normative.

## Resolver/source binding

Resolvers own semantic input assembly. Pure kernels never load repositories, Drift rows, UI state or platform services.

Every resolver MUST:

1. bulk-load only the exact dependency closure;
2. resolve immutable definition/policy/evidence editions by exact ref/hash;
3. capture upstream evaluation identity, deterministic output hash and pointer generation where required;
4. emit MISSING/SET/POLICY/EVAL/POINTER dependencies before returning blocked/unresolved input;
5. normalize order-invariant sets before hashing and preserve physical order for ordered paths/sequences;
6. enforce code-owned cardinality/resource limits before large allocation/sort;
7. return immutable sendable domain objects before worker execution.

## Algorithm performance rules

Engineering complexity is a correctness contract.

- Hash/set aggregation is preferred for identity accounting and uniqueness.
- Ordered physical paths are single-pass folds unless a dossier explicitly requires bounded secondary work.
- Canonical sorting occurs once at deterministic output/trace boundaries and cannot drive the engineering verdict.
- No process may introduce nested full scans that change a frozen O(N), O(P+E), O(F), or O(N log N) contract into accidental O(N²).
- No unbounded powerset, Cartesian fault/event enumeration or recursive alternative search is permitted.
- Bounded predicate/case/event counts are code-owned and authority-fingerprinted.
- Medium/large workloads are forbidden on the Flutter UI isolate on native platforms.
- Worker count and completion order cannot affect output hash, governing case, findings or trace ordering.
- Capture and publish remain short DB scopes; pure calculation never runs inside a transaction.
- Cache reuse is legal only on the complete frozen cache key from `algorithm-performance-registry.json`.
- A measured >15% regression on the controlled benchmark runner is a qualification failure unless the authority/performance baseline is explicitly re-reviewed.

## Critical hard bounds

At minimum these existing dossier bounds are now machine-owned:

```text
CCTV-02: 1000 streams, 10000 subscriptions, max path 64 edges
CCTV-03: 10000 schedule segments
FA-01:   10000 expanded address claims
ACS-06:  exactly five release causes
ACS-03:  bounded transient event set
FA-06/07: bounded code-owned fault-case set
LAN-04/FA-08: bounded code-owned predicate count
```

These are qualification minima or semantic bounds, not permission to allocate unbounded memory beyond shipping limits.

## Stable findings and trace

Engineering findings use stable codes/parameters; localized prose is projection only. Execution failure cannot be serialized as an engineering FAIL. Every process uses its frozen trace prefix and code-owned equation codes from dossier section 17. Trace operands reference canonical evidence/input IDs, not display strings.

## Implementation DoD

One process is not implementation-complete until:

```text
exact frozen symbols and runtime versions exist
resolver uses only declared bulk read methods
pure kernel has no DB/UI/platform dependency
complexity/hard bounds are tested
canonical hash/order metamorphic tests pass
positive + boundary + negative/unsupported + adversarial + cross-discipline vectors pass
public command path + persistence/restart path pass where applicable
workerCount 1 vs N produces identical deterministic output
finding/trace namespaces are valid
P9 source/test/evidence mapping points to one exact authority fingerprint
```

## Claim boundary

These files freeze implementation contracts. They do not claim runtime implementation exists. ELV5 remains `RUNTIME NOT STARTED` until executable source and qualification evidence exist.