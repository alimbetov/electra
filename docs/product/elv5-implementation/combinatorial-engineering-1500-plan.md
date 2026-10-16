# ELV5 — 1500-case combinatorial engineering qualification plan

Status: DESIGN HARDENED / RUNTIME NOT STARTED

This plan adds a fourth qualification layer on top of the existing primary vertical, dossier-vector and market-simulation inventories. It is a deterministic design/runtime qualification contract, not evidence that ELV5 runtime is already implemented.

## Frozen target

```text
ELV5 combinatorial engineering matrix

target: exactly 1500 deterministic scenarios

minimum:
- 42 scenarios for every process;
- 72 for 11 priority computational processes;
- 36 system-wide cross-process scenarios;
- 100% legal pairwise factor coverage;
- targeted 3-wise coverage for high-risk engineering interactions.
```

The arithmetic is intentionally exact:

```text
11 priority processes × 72 = 792
16 regular processes  × 42 = 672
system-wide scenarios       =  36
--------------------------------
total                       = 1500
```

The 11 priority processes are:

```text
CCTV-02 CCTV-03
LAN-01  LAN-05
ACS-03  ACS-04  ACS-05
FA-02   FA-04   FA-05   FA-06
```

## Relationship to existing qualification

The inventories are cumulative rather than substitutive:

```text
54    primary public-command verticals
135   mandatory dossier vectors
450   market-shaped design simulations
1500  combinatorial engineering scenarios
```

The 1500-case layer targets composition/cardinality/order/shared-resource/mutation interactions that cannot be proven by a market sample alone.

## Factor model

Every executable combinatorial scenario is derived from the versioned factor model in `combinatorial-engineering-requirements.json`.

Mandatory factors:

1. vector class — 5 levels;
2. component cardinality — 7 levels;
3. component composition — 6 levels;
4. order/topology mode — 3 levels;
5. shared-resource context — 4 levels;
6. evidence quality/model support — 4 levels;
7. mutation/revision state — 4 levels;
8. project scale — 4 levels.

The unrestricted Cartesian product is intentionally not executed. Coverage is obtained through a deterministic constrained covering matrix.

## Legal pairwise coverage

Acceptance requires **100% coverage of all legal factor-value pairs**.

A pair is legal when the process applicability, subject scope, topology and ownership contracts permit both values to coexist. A pair may be excluded only through a machine-readable constraint with a stable reason code. Silent omission is forbidden.

The CI/qualification artifact must report at least:

```text
legalPairCount
coveredLegalPairCount
pairwiseCoveragePercent
excludedPairCount
excludedPairs[] { factorA, valueA, factorB, valueB, reasonCode }
```

`pairwiseCoveragePercent` must equal `100.0` for P8/P9 acceptance.

## Targeted 3-wise coverage

Full Cartesian 3-wise coverage is not required for all 27 processes. Targeted 3-wise coverage is mandatory for high-risk interactions in the 11 priority processes.

Required triple families include at least:

```text
cardinality × composition × sharedResourceContext
operatingCase × evidenceQuality × reserve/policy basis
orderMode × mutationState × upstreamEvidenceState
composition × transientState × sharedPhysicalSource
cardinality × capacityBoundary × spare/reserve policy
```

Each targeted triple family must have explicit legal-combination inventory and coverage metrics in the qualification artifact.

## Cardinality semantics

Base cardinality classes:

```text
ZERO
ONE
TWO
SMALL_MANY
LIMIT_MINUS_1
LIMIT
LIMIT_PLUS_1
```

Where a finite engineering limit exists, the exact `limit-1 / limit / limit+1` cases are mandatory. The symbolic classes resolve to process-specific physical quantities. Examples include port counts, address counts, channel counts, notification device counts, recorder channels and shared-source consumers.

The symbolic class never invents a normative limit; the limit comes from the selected explicit policy/evidence/product capability.

## Composition semantics

Required composition classes:

```text
HOMOGENEOUS
HETEROGENEOUS
SHARED_TRUNK
BRANCHED
MULTI_ROLE
CROSS_DISCIPLINE_SHARED
```

The matrix must prove that logical memberships never manufacture new physical components and that one physical component serving several roles remains one physical load/resource unless the process contract explicitly defines separate consumptions.

## Order semantics

Three order modes are mandatory:

```text
ORDER_INVARIANT
ORDER_SIGNIFICANT
TOPOLOGY_MUTATED
```

For an order-invariant set:

```text
[A,B,C]
[C,A,B]
[B,C,A]
```

must normalize to the same semantic input, canonical input hash and deterministic result.

For an ordered path/sequence, a physical reorder must change canonical input meaning when it changes the engineering system. Production code may not globally sort an order-significant path merely to make hashing stable.

## Shared-resource combinations

Required shared-resource contexts:

```text
NONE
SAME_DISCIPLINE_SHARED
CROSS_DISCIPLINE_SHARED
GLOBAL_SOURCE_OR_BANK
```

Critical examples include:

- CCTV + LAN + ACS on one PSE/source;
- ACS + other protected loads on one DC bank;
- fire + non-fire auxiliary demand on one supported shared source;
- several optical/channel consumers sharing common physical sections;
- shared trunk voltage-drop/current before individual branches.

A discipline subtotal is explanatory only and cannot replace the physical global total.

## Evidence-quality interactions

Mandatory levels:

```text
GUARANTEED_COMPLETE
TYPICAL_OR_ESTIMATED
MISSING_OR_PARTIAL
UNSUPPORTED_MODEL
```

The same topology/cardinality may yield PASS, FAIL, PARTIAL/BLOCKED or NOT_ASSESSED solely because evidence quality/applicability differs. The matrix must prove that typical/estimated or unsupported evidence cannot be promoted into a guaranteed PASS.

## Mutation/revision interactions

Mandatory mutation states:

```text
BASELINE
ADD_REMOVE_MEMBER
REORDER_OR_REWIRE
REVISION_REPLAY_OR_STALE
```

Required proofs include:

- adding a new selector-matching member invalidates prior dependent results;
- removing a member invalidates old closure without leaving ghost load/capacity;
- reordering an unordered set does not recalculate when canonical meaning is unchanged;
- rewiring an ordered physical path changes the affected fingerprint/closure;
- stale worker completion cannot publish CURRENT;
- replay returns the stored logical outcome for an identical command request;
- create-next preserves immutable old-revision results.

## The 36 system-wide cases

Exactly 36 scenarios are reserved outside per-process minimums. They test integration rather than a single process kernel.

The inventory must include scenarios in these families:

1. cross-discipline shared source/PSE;
2. cross-discipline protected bank;
3. selector gains a new matching fact;
4. selector loses a matching fact;
5. physical path rewire affecting multiple process families;
6. policy edition adoption invalidation;
7. stale capture versus publish;
8. worker supersession/cancellation;
9. response-loss replay;
10. concurrent publishers from one pointer generation;
11. revision freeze versus late publish;
12. create-next with old-revision late worker completion;
13. undo/redo plus new edit generation conflict;
14. deterministic workerCount=1 versus N;
15. canonical unordered reordering invariance;
16. ordered-path permutation significance;
17. cache hit under semantically identical input;
18. cache miss after authority/input semantic change;
19. schema restart/reopen preservation;
20. failure injection before pointer advance;
21. no partial coherent batch publish;
22. shared ELV4 evaluation reuse by multiple wrappers;
23. reserve/derating single-ownership proof;
24. typical/estimated evidence false-PASS sentinel;
25. unsupported model false-PASS sentinel;
26. threshold-overlapping interval sentinel;
27. large dependency DAG incremental closure;
28. no N+1 capture at scale;
29. targeted workspace rebuild under background calculation;
30. virtualized large findings/trace list;
31. web large-workload chunk/yield behavior;
32. native worker-pool bounded backpressure;
33. what-if result cannot become CURRENT;
34. historical result remains attached to old authority/revision provenance;
35. ELV6/ELV7/ELV8 claim-boundary cross-check;
36. exact-head closure ledger/fingerprint reconciliation.

## Required generated artifact

P8 must publish an exact-head artifact with schema:

```text
electra.elv5-combinatorial-qualification.v1
```

Minimum fields:

```text
sourceSha
authorityFingerprint
generationVersion
scenarioCount = 1500
processScenarioCounts
systemWideScenarioCount = 36
factorInventory
legalPairCount
coveredLegalPairCount
pairwiseCoveragePercent = 100.0
excludedPairInventory
targetedThreeWiseFamilies
targetedThreeWiseLegalCount
targetedThreeWiseCoveredCount
orderInvariantProofCount
orderSignificantProofCount
boundaryCardinalityProofCount
crossDisciplineSharedResourceProofCount
mutationInvalidationProofCount
scenarioMatrixFingerprint
```

## Closure rule

P8/P9 may not claim combinatorial qualification from scenario count alone. Closure requires all of the following simultaneously:

```text
scenarioCount == 1500
all 27 processes >= 42
all 11 priority processes >= 72
systemWideScenarioCount == 36
pairwiseCoveragePercent == 100.0
all excluded pairs have stable reasons
targeted high-risk 3-wise inventory is fully covered
order-invariant and order-significant proofs pass
exact-head authority/source fingerprints match
```

Any weakening of the factor model or silent deletion of legal pairs to make coverage reach 100% is a specification defect.
