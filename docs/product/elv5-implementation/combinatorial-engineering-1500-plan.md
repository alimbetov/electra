# ELV5 — 1500-case combinatorial engineering qualification plan

Status: DESIGN HARDENED / RUNTIME NOT STARTED

This plan is the fourth ELV5 qualification layer. It supplements, and never replaces, the 54 primary public-command verticals, 135 dossier vectors and 450 market-shaped simulations.

## Frozen target

```text
ELV5 combinatorial engineering matrix

target: exactly 1500 deterministic scenarios

11 priority processes × 72 = 792
16 regular processes  × 42 = 672
system-wide scenarios       =  36
--------------------------------
total                       = 1500
```

Mandatory acceptance:

```text
all 27 processes have >= 42 scenarios
all 11 priority processes have exactly 72 scenarios in v1
all 16 regular processes have exactly 42 scenarios in v1
systemWideScenarioCount == 36
100% legal pairwise factor coverage
targeted high-risk 3-wise inventory fully covered
exact source SHA + accepted authority fingerprint
```

The priority processes are:

```text
CCTV-02 CCTV-03
LAN-01  LAN-05
ACS-03  ACS-04  ACS-05
FA-02   FA-04   FA-05   FA-06
```

## Qualification pyramid

```text
54     primary public-command verticals
135    process dossier vectors
450    market-shaped design simulations
1500   combinatorial engineering scenarios
+      performance / concurrency / migration / failure-injection evidence
```

The inventories prove different properties and are cumulative.

## Frozen factor model

The only v1 combinatorial factors are those declared in `combinatorial-engineering-requirements.json`:

1. `vectorClass` — 5 levels;
2. `cardinality` — 7 levels;
3. `composition` — 6 levels;
4. `orderMode` — 3 levels;
5. `sharedResourceContext` — 4 levels;
6. `evidenceQuality` — 4 levels;
7. `mutationState` — 4 levels;
8. `projectScale` — 4 levels.

A qualification rule may derive process-specific operating cases, transient states, reserve policy, capacity boundary or upstream evidence from these scenario factors and the process fixture, but such derived semantics are **not additional combinatorial factor names**. Adding a ninth factor is a schema change and requires regeneration/re-audit.

The unrestricted Cartesian product is not executed. Coverage is obtained through the frozen mixed-level strength-2 template plus targeted 3-wise rows.

## Constructive 42-row pairwise proof

`combinatorial-covering-template-v1.json` contains exactly 42 rows. Its columns are zero-based indices into the frozen factor arrays.

The current v1 mixed-level factor space contains exactly:

```text
593 factor-value pairs per process
27 × 593 = 16,011 pair obligations across all processes
```

The generator MUST independently enumerate all pair obligations and prove that the 42-row template covers all 593 pairs before it generates any priority 3-wise rows.

The 42 rows therefore are not a scenario-count heuristic. They are a constructive existence proof for the current strength-2 factor model.

## Legal-pair constraint registry

`combinatorial-legal-pair-constraints.json` is the only authority for pair exclusions.

Rules:

- default pair state is `LEGAL`;
- silent exclusion is forbidden;
- every exclusion requires exact factors, values and a stable reason code;
- a generated scenario may not contain an excluded pair;
- FAIL/BLOCKED/unsupported/missing/boundary outcomes are **not** reasons to exclude a difficult pair;
- changing exclusions changes the qualification contract fingerprint and requires matrix regeneration.

Current v1 closure intentionally has:

```text
excludedPairCount = 0
legalPairCountPerProcess = 593
legalPairCountAllProcesses = 16,011
```

This is the strongest closure: qualification states are abstract test intents, so difficult combinations remain representable rather than being removed to inflate coverage.

## Cardinality semantics

```text
ZERO
ONE
TWO
SMALL_MANY
LIMIT_MINUS_1
LIMIT
LIMIT_PLUS_1
```

Where a finite engineering limit exists, `LIMIT_MINUS_1`, `LIMIT`, and `LIMIT_PLUS_1` resolve to that explicit process capability/policy boundary. The symbolic class never invents a limit.

## Composition semantics

```text
HOMOGENEOUS
HETEROGENEOUS
SHARED_TRUNK
BRANCHED
MULTI_ROLE
CROSS_DISCIPLINE_SHARED
```

Logical membership must never manufacture a second physical component or remove a real physical load. Shared trunks, multi-role devices and cross-discipline consumers preserve canonical physical identity.

## Order semantics

```text
ORDER_INVARIANT
ORDER_SIGNIFICANT
TOPOLOGY_MUTATED
```

For unordered sets, canonical reorderings MUST preserve semantic input hash and engineering result. For ordered paths/sequences, a physical reorder MUST change canonical input meaning when the engineering topology changes. Production code may not sort an order-significant path merely to make hashing stable.

## Shared-resource semantics

```text
NONE
SAME_DISCIPLINE_SHARED
CROSS_DISCIPLINE_SHARED
GLOBAL_SOURCE_OR_BANK
```

Shared-source scenarios prove that discipline contributions are explanatory projections only. They never replace the complete physical source/bank/PSE total owned by ELV3/ELV4.

## Evidence-quality semantics

```text
GUARANTEED_COMPLETE
TYPICAL_OR_ESTIMATED
MISSING_OR_PARTIAL
UNSUPPORTED_MODEL
```

The same topology/cardinality may produce PASS, FAIL, PARTIAL/BLOCKED or NOT_ASSESSED because evidence/applicability differs. Typical, estimated, missing or unsupported evidence cannot be promoted to a guaranteed PASS.

## Mutation semantics

```text
BASELINE
ADD_REMOVE_MEMBER
REORDER_OR_REWIRE
REVISION_REPLAY_OR_STALE
```

Required behavior includes exact selector gain/loss invalidation, no ghost members, no recompute for semantically identical unordered reordering, changed fingerprint for real rewiring, stale-worker publication rejection, replay stability and old-revision immutability.

## Exact targeted 3-wise inventory

`combinatorial-targeted-three-wise.json` freezes exactly **30 targets per priority process** across five families, six targets per family:

```text
T3-CARD-COMP-SHARED
  cardinality × composition × sharedResourceContext

T3-ORDER-MUTATION-EVIDENCE
  orderMode × mutationState × evidenceQuality

T3-VECTOR-EVIDENCE-SHARED
  vectorClass × evidenceQuality × sharedResourceContext

T3-CARD-MUTATION-SCALE
  cardinality × mutationState × projectScale

T3-COMP-ORDER-SCALE
  composition × orderMode × projectScale
```

Therefore the exact v1 targeted inventory is:

```text
30 targets/process × 11 priority processes = 330 targeted 3-wise obligations
```

Every `T3-001..T3-030` tuple must appear for every priority process. The registry also records process-specific engineering risk bindings so the same abstract triple is interpreted against the correct process mathematics.

Full Cartesian strength-3 coverage is deliberately not claimed.

## Exact 36 system-wide cases

`combinatorial-system-wide-inventory.json` contains exactly `SYS-001..SYS-036` and is the machine authority for integration cases outside a single process kernel.

The inventory covers shared sources/banks, selector gain/loss, rewiring, policy adoption, stale publish, cancellation, replay, publisher races, freeze/create-next, undo/redo conflicts, worker determinism, canonical order behavior, cache hit/miss, restart, failure injection, atomic batch publication, ELV4 evidence reuse, reserve ownership, false-PASS sentinels, dependency scale, N+1 prevention, UI virtualization/rebuild scope, web/native executor behavior, what-if isolation, historical provenance, ELV6/7/8 boundaries and exact-head closure reconciliation.

No anonymous filler scenario may be used to reach 1500.

## Deterministic generator

`scripts/ci/generate-elv5-combinatorial-1500.py` MUST:

1. read the frozen requirements, legal-pair constraints, 42-row template, exact 3-wise inventory, 36 system-wide inventory and 27-process registry;
2. independently enumerate the mixed-level pair universe;
3. prove the base template covers all legal pairs;
4. generate exactly 42 base scenarios for every process;
5. add exactly 30 targeted 3-wise scenarios to each priority process;
6. append exactly 36 system-wide scenarios;
7. reject any scenario containing an excluded pair;
8. prove `16,011 / 16,011` legal pair obligations in the current closure;
9. prove `330 / 330` targeted 3-wise obligations;
10. emit one deterministic scenario-matrix fingerprint.

Unseeded randomness is prohibited.

## Generated artifact

Schema:

```text
electra.elv5-combinatorial-qualification.v1
```

Minimum fields include:

```text
sourceSha
authorityFingerprint
qualificationContractFingerprintSha256
scenarioCount = 1500
processScenarioCounts
systemWideScenarioCount = 36
factorInventory
legalPairCount
coveredLegalPairCount
pairwiseCoveragePercent = 100.0
excludedPairCount
targetedThreeWiseTemplateCount = 30
targetedThreeWiseLegalCount = 330
targetedThreeWiseCoveredCount = 330
pairwiseMetricsByProcess
targetedThreeWiseCoverageByProcess
scenarioMatrixFingerprintSha256
runtimeExecuted
```

### Source and authority integrity

The generator requires `--authority-manifest`. It verifies the manifest schema,
canonical SHA-256 fingerprint, complete code-owned artifact inventory, every file's
byte length/hash, and equality with the current manifest generator's result.
A 64-character string or matching `sourceSha` alone is insufficient.

Artifact provenance is read from checked-out Git HEAD. A supplied `GITHUB_SHA`
must match it. Tracked or untracked worktree changes reject normal evidence
publication. Local design checks may use `--allow-dirty`, which emits
`sourceTreeState=DIRTY` and `evidenceScope=WORKTREE_PREVIEW`; this cannot qualify
as exact-head P0/P9 evidence. Clean source emits `CLEAN` / `EXACT_HEAD`.
The same provenance rule applies to the authority manifest and market artifact.
CI always runs without `--allow-dirty` and writes generated artifacts outside the
repository. No fallback `UNKNOWN` SHA is accepted.

## Closure rule

P8/P9 may not claim combinatorial qualification from row count alone. Closure requires simultaneously:

```text
scenarioCount == 1500
all 27 processes satisfy their exact v1 density
systemWideScenarioCount == 36
coveredLegalPairCount == legalPairCount
pairwiseCoveragePercent == 100.0
all pair exclusions are explicit and machine-reasoned
targetedThreeWiseCoveredCount == targetedThreeWiseLegalCount == 330
order-invariant and order-significant runtime proofs pass
source SHA and authority fingerprint match exact-head closure
```

Until ELV5 runtime exists, generation of this matrix proves specification consistency and coverage construction only. It does not claim execution of production Dart kernels.
