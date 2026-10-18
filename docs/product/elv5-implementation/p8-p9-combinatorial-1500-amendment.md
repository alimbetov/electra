# ELV5 — P8/P9 combinatorial qualification amendment

Status: DESIGN HARDENED / RUNTIME NOT STARTED

This document is a normative amendment to `p8-acceptance.md` and `p9-closure.md`. Where older P8/P9 wording lists only the 54/135/450 qualification inventories, this amendment adds the mandatory constructive 1500-case layer and governs that additional inventory.

The active combinatorial authority set is:

- `combinatorial-engineering-requirements.json`;
- `combinatorial-engineering-1500-plan.md`;
- `combinatorial-legal-pair-constraints.json`;
- `combinatorial-targeted-three-wise.json`;
- `combinatorial-covering-template-v1.json`;
- `combinatorial-system-wide-inventory.json`;
- `scripts/ci/generate-elv5-combinatorial-1500.py`.

## P8 amendment

P8 MUST generate and execute an exact-head combinatorial qualification matrix with:

```text
scenarioCount == 1500
priorityProcessCount == 11
priorityProcessScenarioCount == 72
regularProcessCount == 16
regularProcessScenarioCount == 42
systemWideScenarioCount == 36
legalPairCountPerProcessCurrentClosure == 593
legalPairCount == 16011
coveredLegalPairCount == 16011
pairwiseCoveragePercent == 100.0
excludedPairCount == 0                    # current v1 closure
targetedThreeWiseTemplateCount == 30
targetedThreeWiseLegalCount == 330
targetedThreeWiseCoveredCount == 330
```

The arithmetic is fixed:

```text
11 × 72 = 792
16 × 42 = 672
792 + 672 + 36 = 1500
```

The base 42 rows are not a nominal lower bound. `combinatorial-covering-template-v1.json` is a frozen mixed-level strength-2 construction, and the generator MUST independently prove that those rows cover every legal factor-value pair for every process before accepting the matrix.

The current v1 constraint registry deliberately excludes zero pairs. FAIL/BLOCKED/unsupported/missing/boundary states are valid qualification states and may not be excluded merely to improve coverage. A future legal exclusion requires an explicit machine-readable reason, a regenerated matrix and a new authority fingerprint.

The 30 targeted `T3-001..T3-030` tuples apply to every one of the 11 priority processes, giving exactly 330 targeted high-risk 3-wise obligations. Full Cartesian strength-3 coverage is not claimed.

The 36 system-wide scenarios are exact identities `SYS-001..SYS-036`; arbitrary filler rows are forbidden.

P8 MUST NOT claim combinatorial acceptance merely because 1500 rows were generated. It must prove pair coverage, targeted 3-wise coverage, explicit constraint handling, order invariance/significance, boundary cardinalities, shared-resource composition, mutation/invalidation semantics and exact source/authority identity.

The generated artifact schema is:

```text
electra.elv5-combinatorial-qualification.v1
```

The artifact MUST contain the exact source SHA, accepted authority fingerprint, qualification-contract fingerprint and deterministic scenario-matrix fingerprint.

## P9 amendment

P9 exact-head closure additionally requires:

1. all 12 `ELV5-COMB-*` MUST requirements reconciled to executable evidence;
2. exactly 1500 combinatorial scenarios at the accepted source SHA;
3. exact v1 per-process density: 72 for each priority process and 42 for each regular process;
4. exactly 36 system-wide `SYS-*` scenarios;
5. constructive proof that the 42-row base covers the current 593 legal factor-value pairs per process;
6. `16,011 / 16,011` legal pair obligations covered in the current zero-exclusion closure;
7. `330 / 330` exact targeted 3-wise obligations covered;
8. no silent pair exclusions and no generated scenario containing an excluded pair;
9. deterministic order-invariant and order-significant runtime proofs;
10. exact-head scenario-matrix fingerprint in the closure ledger;
11. generator source SHA-256 included in authority identity;
12. no combinatorial evidence pointing to a different source SHA or authority fingerprint.

A P9 closure artifact that omits this matrix is incomplete even when all 54 primary entries, 135 dossier vectors and 450 market scenarios pass.

## Qualification pyramid

```text
54     primary public-command verticals
135    process dossier vectors
450    market-shaped design simulations
1500   combinatorial engineering qualification scenarios
+      performance / concurrency / migration / failure-injection evidence
```

These inventories prove different properties and cannot substitute for one another.

## Claim boundary

Until production ELV5 runtime exists, CI generation of the 1500 rows proves only that the specification has a deterministic constructive covering matrix bound to an exact authority fingerprint. It does **not** claim that production Dart kernels have executed those 1500 scenarios.
