# ELV5 — Fifth-pass specification closure audit

Status: **SPEC_RESOLVED / RUNTIME NOT STARTED**

Branch: `feat/flutter-elv5-power-topology-design`

## Scope

This pass was triggered after the 1500-case combinatorial qualification target was added. The purpose is not to re-audit ELV4 or re-open the 27 process mathematics. It checks whether the new combinatorial layer is executable, machine-authoritative and consistent with P8/P9 closure.

The audit covers:

- deterministic generation of exactly 1500 scenarios;
- proof of the mixed-level strength-2 factor space;
- legal-pair exclusion authority;
- exact targeted 3-wise inventory;
- exact system-wide inventory;
- P8/P9 closure language;
- authority-manifest completeness;
- exact-head CI artifact binding.

## Result

The pass found **6 HIGH + 2 MEDIUM = 8 closure findings**. All eight are resolved in specification. They are tracked separately from the historical four-pass design-finding total of 56 so the prior invariant remains auditable.

```text
HIGH    6
MEDIUM  2
TOTAL   8
OPEN    0
```

## Findings and resolutions

### ELV5-FIFTH-001 — Declaration-only combinatorial gate — HIGH

**Finding:** the prior 1500-case CI guard validated only declared counts and factor inventory. It did not construct the matrix or prove pairwise/3-wise coverage.

**Resolution:** `scripts/ci/generate-elv5-combinatorial-1500.py` now builds the matrix from machine authorities and proves exact counts and coverage before emitting an artifact.

### ELV5-FIFTH-002 — Legal-pair exclusion authority missing — HIGH

**Finding:** the specification allowed legal-pair exclusions in principle but had no machine registry or stable reason codes.

**Resolution:** `combinatorial-legal-pair-constraints.json` is now the only exclusion authority. Current v1 intentionally excludes **zero** pairs, producing the strongest closure:

```text
593 legal factor-value pairs per process
27 × 593 = 16,011 legal pair obligations
```

FAIL, BLOCKED, missing, unsupported and boundary states are not exclusion reasons.

### ELV5-FIFTH-003 — 3-wise factor-model contradiction — HIGH

**Finding:** the prose plan named `operatingCase`, `transientState`, `upstreamEvidenceState`, reserve/policy and capacity-boundary concepts as if they were frozen combinatorial factors, while the normative factor model contains only eight factors.

**Resolution:** the plan is reconciled to five exact triple families built only from the eight declared factors. `combinatorial-targeted-three-wise.json` freezes `T3-001..T3-030`; every one applies to all 11 priority processes:

```text
30 × 11 = 330 targeted 3-wise obligations
```

Process-specific operating/transient/policy meaning remains derived fixture semantics, not an undeclared ninth factor.

### ELV5-FIFTH-004 — System-wide inventory prose-only — MEDIUM

**Finding:** the 36 integration scenarios could previously be replaced with arbitrary rows while preserving the count.

**Resolution:** `combinatorial-system-wide-inventory.json` freezes exact identities `SYS-001..SYS-036` and their owning package paths. Anonymous filler is forbidden.

### ELV5-FIFTH-005 — Authority fingerprint incomplete — HIGH

**Finding:** the authority manifest predated the constructive proof and therefore did not fingerprint the legal-pair registry, 3-wise inventory, 42-row template, 36-case inventory or generator source.

**Resolution:** all five now participate in the authority fingerprint. Generator source itself is hashed so algorithm drift invalidates closure.

### ELV5-FIFTH-006 — P8/P9 closure chain stale — HIGH

**Finding:** the main P8/P9 documents predated the constructive covering proof and relied on the amendment for the new layer.

**Resolution:** P8/P9 now directly require the generated exact-head combinatorial artifact while the amendment remains the detailed normative extension.

### ELV5-FIFTH-007 — Artifact not bound to authority — HIGH

**Finding:** a declaration-only CI check emitted no 1500-row matrix artifact and therefore no matrix fingerprint could be tied to the accepted authority fingerprint.

**Resolution:** CI generates the authority manifest first, then passes that exact manifest to the combinatorial generator and publishes the resulting matrix artifact.

### ELV5-FIFTH-008 — Generator algorithm not pinned — MEDIUM

**Finding:** a deterministic generator could change behavior without changing the declarative JSON contracts.

**Resolution:** `combinatorialGeneratorSha256` is part of the authority manifest. Any generator source change changes authority identity and invalidates previous exact-head closure evidence.

## Constructive coverage proof

The frozen 42-row mixed-level template uses factors with level counts:

```text
vectorClass             5
cardinality             7
composition             6
orderMode               3
sharedResourceContext   4
evidenceQuality         4
mutationState           4
projectScale            4
```

The generator independently enumerates all pair combinations and must prove:

```text
base template rows                     = 42
factor-value pairs/process             = 593
covered pairs/process                  = 593
all-process legal pair obligations     = 16,011
all-process covered legal obligations  = 16,011
pairwise coverage                      = 100.0%
```

Priority processes receive the 42-row base plus 30 exact targeted 3-wise rows:

```text
11 × (42 + 30) = 792
```

Regular processes receive the 42-row base:

```text
16 × 42 = 672
```

The machine-owned system inventory contributes:

```text
36
```

Therefore:

```text
792 + 672 + 36 = 1500
```

## Claim boundary

This fifth pass closes the **specification construction** of the combinatorial layer. It does not claim ELV5 runtime implementation. Until P0–P9 production code exists, the generated 1500-row artifact proves design coverage construction only; production Dart kernels have not executed those rows.

## Closure verdict

```text
fifth-pass closure findings: 8
resolved:                    8
open:                        0
specification closure:       PASS
runtime implementation:      NOT_STARTED
```

The remaining work after this audit is implementation and executable runtime qualification against the frozen authority fingerprint, not further architectural definition of the 1500-case matrix.
