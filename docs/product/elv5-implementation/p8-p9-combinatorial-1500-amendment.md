# ELV5 — P8/P9 combinatorial qualification amendment

Status: DESIGN HARDENED / RUNTIME NOT STARTED

This document is a normative amendment to `p8-acceptance.md` and `p9-closure.md` for combinatorial engineering qualification. It supplements, and does not replace, the existing 54 primary public-command verticals, 135 dossier vectors and 450 market-shaped design simulations.

Where older P8/P9 wording lists only the 54/135/450 qualification inventories, this amendment adds the mandatory 1500-case combinatorial layer defined by:

- `combinatorial-engineering-requirements.json`;
- `combinatorial-engineering-1500-plan.md`.

## P8 amendment

P8 MUST generate and execute an exact-head combinatorial qualification matrix with:

```text
scenarioCount == 1500
priorityProcessCount == 11
priorityProcessMinimum == 72
regularProcessCount == 16
regularProcessMinimum == 42
systemWideScenarioCount == 36
legalPairwiseCoverage == 100%
targetedHighRiskThreeWiseCoverage == complete for the declared targeted inventory
```

The arithmetic is fixed:

```text
11 × 72 = 792
16 × 42 = 672
792 + 672 + 36 = 1500
```

P8 MUST NOT claim combinatorial acceptance merely because 1500 rows were generated. It must prove legal pair coverage, explicit excluded-pair reasons, targeted 3-wise coverage, order invariance/significance, boundary cardinalities, shared-resource composition and mutation/invalidation semantics.

The generated artifact schema is:

```text
electra.elv5-combinatorial-qualification.v1
```

and it must be bound to the exact source SHA and accepted authority fingerprint.

## P9 amendment

P9 exact-head closure additionally requires:

1. the 12 `ELV5-COMB-*` MUST requirements reconciled to executable evidence;
2. exactly 1500 combinatorial scenarios at the accepted source SHA;
3. all 27 processes meeting their minimum scenario density;
4. all 11 priority processes meeting at least 72 scenarios;
5. exactly 36 system-wide scenarios;
6. 100% legal pairwise coverage with no silent pair exclusions;
7. complete targeted high-risk 3-wise inventory for the declared triple families;
8. deterministic order-invariant and order-significant proofs;
9. exact-head scenario-matrix fingerprint in the closure ledger;
10. no combinatorial evidence pointing to a different source SHA or authority fingerprint.

A P9 closure artifact that omits the 1500-case matrix is incomplete even when all 54 primary entries, 135 dossier vectors and 450 market scenarios pass.

## Qualification pyramid

The required evidence pyramid is therefore:

```text
54     primary public-command verticals
135    process dossier vectors
450    market-shaped design simulations
1500   combinatorial engineering qualification scenarios
+      performance / concurrency / migration / failure-injection evidence
```

These inventories prove different properties and cannot be substituted for one another.

## Claim boundary

Until runtime implementation exists, the 1500-case files and CI guard prove only that the combinatorial qualification contract is internally consistent and machine-enforced. They do not claim that production Dart kernels have executed the 1500 scenarios.
