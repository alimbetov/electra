# ELV2 Hard Review — Round 2

Status: active adversarial post-closure audit  
Baseline SHA: `179f11d8afcbcf433466f4cdb34b60a993a13167`  
Audit branch: `audit/elv2-hard-review-round-2`  
Source PR: #7

## Purpose

This audit treats the previous P1–P7 closure as an assertion to disprove, not as evidence that the implementation is defect-free.

Rules:

1. Findings require code/schema/contract evidence.
2. Suspicions are not findings until proven.
3. Every remediation must add a regression test that fails before the fix.
4. The original closure SHA stays immutable; all Round-2 changes are isolated on this branch.
5. ELV3 work remains out of scope until Round-2 blockers/high findings are resolved and a new exact-SHA gate is green.

## Review sequence

```text
R2.0 repository / CI hygiene
  ↓
R2.1 P1 reference model + identity invariants
  ↓
R2.2 P2 compatibility / fail-closed semantics
  ↓
R2.3 P3 palette / stale UI evidence
  ↓
R2.4 P4 atomic placement / history / idempotency
  ↓
R2.5 P5 revision impact completeness
  ↓
R2.6 P6 adoption / migration / concurrency
  ↓
R2.7 P7 four-discipline + restart + provenance
  ↓
Round-2 exact-SHA CI
```

## Severity

- **BLOCKER** — can violate persisted engineering identity, atomicity, provenance, or graph safety; merge prohibited.
- **HIGH** — material correctness/reviewability issue; must fix before accepting ELV2 baseline.
- **MEDIUM** — deterministic or explainability gap with bounded impact; fix before final Round-2 closure unless explicitly waived.
- **LOW** — maintainability/hardening issue that does not invalidate engineering result.

## Confirmed findings

### R2-001 — HIGH — committed build/toolchain artifacts pollute PR #7

PR #7 contains tracked generated/runtime artifacts under paths such as:

- `apps/mobile/.dart_tool/**`
- `apps/mobile/build/**`
- generated native assets / snapshots / Drift intermediate JSON

No repository-level or `apps/mobile` `.gitignore` exists on the audited branch.

Impact:

- PR expands to hundreds of non-source files;
- meaningful domain diff is obscured;
- machine/toolchain-specific files become versioned input;
- review and reproducibility are weaker;
- future Flutter/Dart upgrades can create noisy or binary churn unrelated to engineering changes.

Required remediation:

1. add canonical ignore rules;
2. remove tracked `.dart_tool/**` and `build/**` artifacts from the audit branch;
3. keep source-controlled generated code only where intentionally required (`app_database.g.dart` policy must remain explicit);
4. add a CI/repository guard preventing these paths from returning.

### R2-002 — HIGH — profile identity normalization is inconsistent and can collide with P6 idempotency semantics

`EngineeringReferenceCatalog.validate()` checks profile-code uniqueness using exact case-sensitive strings:

```dart
profiles.map((profile) => profile.code).toSet()
```

But P6 `EngineeringReferenceAdoptionCommand.toMap()` canonicalizes `profileCode` using `trim().toUpperCase()` before command fingerprinting.

Therefore a catalog can structurally accept two profiles whose logical identity normalizes to the same code, e.g.:

```text
CAMERA
camera
```

while P6 treats both command identities as `CAMERA` in its durable fingerprint.

Impact:

- canonical profile identity is ambiguous;
- two distinct lookup targets can share one normalized operation fingerprint;
- deterministic revision/adoption semantics depend on caller casing;
- exact-edition provenance is not sufficient if profile identity inside the edition is not canonical.

Required remediation:

- define one canonical code normalization function;
- reject duplicate normalized profile codes at catalog validation/publication;
- use normalized lookup semantics consistently or require already-canonical stored codes;
- add import and P6 fingerprint regression tests for case/whitespace aliases.

### R2-003 — HIGH — P6 compatibility graph snapshot is loaded outside the adoption transaction

`DriftEngineeringReferenceAdoptionRepository.adopt()` loads:

```dart
final topologyBeforeCommit = await DriftEngineeringTopologyRepository(...)
    .load(command.projectId);
```

before entering:

```dart
return database.transaction(() async { ... });
```

Inside the transaction, durable connection/group/internal rows are re-read and fingerprint-checked, but `_validateCandidateGraph(...)` validates the candidate against the pre-transaction `topologyBeforeCommit` snapshot.

Impact:

- commit-time validation is not sourced from one transaction snapshot;
- an ABA/concurrent graph transition can make reviewed fingerprint state and validation snapshot diverge;
- the implementation does not strictly satisfy the P6 contract requirement to re-read and validate current durable graph state immediately before mutation inside the owning transaction.

Required remediation:

- resolve the topology snapshot inside the same top-level adoption transaction after stale-review checks, or construct validation graph directly from rows read by that transaction;
- prove via a regression/concurrency seam that validation cannot observe a different graph snapshot than the fingerprint/postcondition checks.

### R2-004 — MEDIUM — explicit port mapping normalization silently collapses duplicate logical keys

`EngineeringReferenceAdoptionCommand` constructs `explicitPortMappings` by trimming/uppercasing directly into a Map literal.

Inputs such as:

```text
"eth" -> "DATA"
" ETH " -> "DATA2"
```

normalize to the same key and one entry is silently overwritten before `validate()` runs.

Impact:

- ambiguous engineer intent is accepted instead of fail-closed;
- validation cannot report the duplicate because normalization already destroyed the evidence;
- migration behavior depends on input iteration order.

Required remediation:

- normalize through an explicit validation pass;
- reject duplicate normalized old codes and duplicate normalized target codes;
- only create the immutable normalized mapping after validation.

### R2-005 — MEDIUM — P5 reviewer-visible graph impact omits internal mappings even though P6 treats them as live dependencies

P5 `_graphImpact()` includes internal mappings in `graphFingerprint`, but `BoundProfileRevisionImpact` exposes only:

```text
connectionIds
topologyGroupIds
```

and `affectsProjectGraph` is true only when one of those lists is non-empty.

P6, however, explicitly loads internal mappings and treats their ports as dependent, capable of blocking retirement/remapping.

Impact:

- a component affected only by internal connectivity can appear to have no project-graph impact in the P5 review surface;
- P6 may later block adoption for a dependency the engineer was not explicitly shown;
- review explainability is weaker than commit-time safety.

Required remediation:

- expose deterministic `internalMappingIds` in `BoundProfileRevisionImpact` and preview summaries, or explicitly redefine/rename the review API so internal dependency impact cannot be mistaken for “no graph impact”;
- add an internal-mapping-only P5 acceptance case.

## Investigated and rejected findings

### Rejected — multiple binding rows could be resurrected by P6 update

Initial suspicion: P6 replaces a binding with `WHERE component_id = ?` and clears `deletedAt`, potentially updating historical rows.

Schema evidence rejects this: `ComponentReferenceBindings` has `PRIMARY KEY(componentId)`, so multiple rows for one component cannot coexist. P6 also requires an active binding row before replacement.

No finding retained.

### Rejected — P2 ignores graph degree/branch/loop rules accidentally

The P2 contract explicitly limits pre-placement topology validation to topology shape and intended role. Real loop closure, degree, branching and ordering belong to persisted graph validation/revision revalidation.

No P2 defect retained for this boundary.

## Open review targets

Not yet classified:

- catalog soft-delete visibility and immutable-edition lifecycle;
- normalized catalog/interface/protocol identity symmetry;
- P4/P6 concurrent same-operation behavior under SQLite WAL/deferred transactions;
- P4 history semantics after successful P6 adoption;
- candidate/current catalog payload-vs-row provenance integrity;
- P5 affected-set completeness for assemblies and remote endpoint changes;
- P6 exact same-edition adoption/no-op contract;
- UI presentation of stale/unresolved P5/P6 states;
- restart matrix independence (fresh process vs same executor warnings);
- CI guard authenticity and generated-source policy.

## Current verdict

The original ELV2 closure is **not yet accepted as merge-ready under Round-2 standards**.

Current confirmed severity count:

```text
BLOCKER  0
HIGH     3
MEDIUM   2
LOW      0
```

PR #7 should remain draft. ELV3 should remain blocked until Round-2 HIGH findings are remediated, all open review targets are classified, and a new exact-SHA push + PR gate is green.
