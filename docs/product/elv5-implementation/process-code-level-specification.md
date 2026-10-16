# ELV5 — code-level process implementation specification

Status: DESIGN HARDENING / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`

This document is the entry contract for the fourth ELV5 hardening pass. It makes every one of the 27 discipline processes implementation-complete at the level required to write production Dart without inventing engineering semantics locally.

It is subordinate only to `code-level-hardening-v2.md` where that document intentionally tightens shared type/resource/authority semantics. Process mathematics remains owned by `process-contracts.md`; the detailed dossiers below refine those formulas into executable algorithms without changing stage ownership.

## 1. Mandatory dossier shape

Every process code MUST have exactly the following 25 normative sections, in this order:

1. Physical meaning
2. Applicability matrix
3. Exact typed inputs
4. Evidence requirements
5. Operating cases
6. Mathematical model
7. Equations
8. Exact/bounded arithmetic
9. Worst-case selection
10. Requirement composition
11. Comparison equations
12. Margin equation
13. Governing-case algorithm
14. Limiting-factor algorithm
15. Missing/unsupported behavior
16. Dependency set
17. Calculation trace
18. Complexity/resource bounds
19. Pseudocode
20. Dart interfaces
21. Positive reference vector
22. Boundary vector
23. Negative vector
24. Adversarial vector
25. Cross-discipline vector

A process is not implementation-ready if any section is replaced with “TBD”, hidden in UI code, inferred from product labels, or delegated to a developer decision.

## 2. Dossier locations

- `process-specifications/cctv-processes.md` — CCTV-01…06.
- `process-specifications/lan-processes.md` — LAN-01…07.
- `process-specifications/acs-processes.md` — ACS-01…06.
- `process-specifications/fire-processes.md` — FA-01…08.

The implementation priority remains:

```text
CCTV-02  bandwidth/flow
CCTV-03  storage/time integration
LAN-01   path length
LAN-05   optical budget
ACS-03   lock electrical/transient
ACS-04   PSU requirement
ACS-05   backup
FA-02    standby/alarm current
FA-04    source requirement
FA-05    battery/autonomy
FA-06    notification circuit
```

The remaining 16 processes are specified at the same contract level and may be implemented after the computational core unless dependency sequencing requires otherwise.

## 3. Shared calculation semantics

All dossiers inherit `calculation-engine-contract.md` and therefore execute:

```text
CAPTURE
→ RESOLVE_APPLICABILITY
→ RESOLVE_INPUTS
→ NORMALIZE_ENGINEERING_STATE
→ BUILD_OPERATING_CASES
→ RUN_PROCESS_KERNEL
→ COMPOSE_REQUIREMENTS
→ CONSERVATIVE_COMPARE
→ DERIVE_MARGINS_AND_GOVERNING_CASE
→ DERIVE_DIMENSION_STATUSES
→ BUILD_CALCULATION_TRACE
→ BUILD_FINDINGS_AND_RECOMMENDATIONS
→ GUARDED_PUBLISH
```

The following rules are universal:

- positive signed margin means acceptable headroom;
- zero margin is a passing boundary only when the selected requirement uses an inclusive limit;
- negative margin means quantified deficit;
- exact equality is never rounded through display formatting before comparison;
- intervals are compared conservatively, never by midpoint;
- all required operating cases are evaluated before a governing case is selected;
- a missing guarantee cannot be replaced by a typical/estimated value;
- reserve, derating, uncertainty and measurement error are separate transformations;
- discipline wrappers do not re-run or partially reproduce ELV4 physical power kernels;
- `CURRENT` is freshness, not assessment;
- a completed engineering violation is `SUCCEEDED/COMPLETE/FAIL`, not an execution failure;
- unsupported model is never `PASS`;
- a what-if result is never publishable as the official current project evaluation.

## 4. Common implementation types

Production Dart SHOULD expose equivalent closed domain types:

```dart
sealed class Elv5Field<T> {
  const Elv5Field();
}
final class Known<T> extends Elv5Field<T> { final T value; }
final class Missing<T> extends Elv5Field<T> { final String code; }
final class NotApplicable<T> extends Elv5Field<T> { final String reasonCode; }
final class Unsupported<T> extends Elv5Field<T> { final String modelCode; }
final class Unresolved<T> extends Elv5Field<T> { final String reasonCode; }

enum Elv5ComparisonStatus { pass, fail, unresolved, notAssessed }

enum Elv5LimitInclusivity { inclusive, exclusive }

final class Elv5SignedMargin<Q> {
  final Q value; // positive = acceptable headroom
  final String requirementCode;
  final String operatingCaseId;
}

final class Elv5LimitingFactor {
  final String dimensionCode;
  final String operatingCaseId;
  final String? subjectId;
  final String? pathElementId;
  final String reasonCode;
}

final class Elv5CalculationStep {
  final String equationCode;
  final int equationVersion;
  final List<String> inputRefs;
  final Object exactResult;
  final Set<String> affectedDimensions;
}

final class Elv5ProcessEvaluation<O> {
  final O output;
  final List<Elv5CalculationStep> trace;
  final List<Elv5DimensionAssessment> dimensions;
  final String? governingCaseId;
  final Elv5LimitingFactor? limitingFactor;
  final List<Elv5Finding> findings;
}
```

Concrete implementations may use records/value classes, but must preserve the semantics and canonical hashing projection.

## 5. Comparison algebra

For an upper limit `x <= L`:

```text
margin = L - x
PASS iff lowerBound(margin) >= 0 for inclusive requirement
PASS iff lowerBound(margin) > 0 for exclusive requirement
```

For a lower limit `x >= L`:

```text
margin = x - L
PASS iff lowerBound(margin) >= 0 for inclusive requirement
```

For an allowed range `L <= x <= U`:

```text
lowerMargin = x - L
upperMargin = U - x
governingMargin = min(lowerMargin, upperMargin)
```

For interval-valued `x=[xMin,xMax]`, conservative comparison uses the adverse endpoint for the tested inequality. Midpoint comparison is forbidden.

For boolean/topological dimensions there is no fabricated numeric margin. The limiting factor is the first canonical failed requirement according to the process-defined deterministic order.

## 6. Requirement composition

Where multiple applicable requirements constrain the same physical dimension:

1. filter by explicit applicability;
2. reject incompatible requirement semantics rather than choosing silently;
3. normalize to a common dimension and comparison direction;
4. select the strongest applicable bound deterministically;
5. retain all contributing requirement refs in provenance;
6. apply reserve/derating only at the owner-defined boundary and only once.

A project policy can make a technical requirement more restrictive, but cannot create verified regulatory compliance; that boundary remains ELV7.

## 7. Deterministic trace and explanation

Every numerical assessment MUST be reconstructible from stored/captured inputs and versioned equation codes. Required trace properties:

- canonical process-local sequence numbers;
- stable equation code/version;
- exact operands by reference, not UI strings;
- exact or conservative-bounded result;
- requirement ref for comparisons;
- operating-case ref;
- no timestamps/random IDs inside deterministic output hash;
- same input fingerprint + same algorithm/numeric versions => same deterministic output hash.

Trace is engineering evidence. Localized prose is a projection generated from stable codes.

## 8. Resource and complexity contract

Each dossier specifies its asymptotic model and bounded cardinalities. Implementations MUST:

- reject configured hard-limit excess with a typed resource-limit result before unbounded allocation;
- avoid quadratic joins where a keyed/set formulation is available;
- sort only where order is semantically required or where deterministic canonical output requires it;
- keep pure kernels side-effect free so the application layer can schedule them outside the UI isolate;
- make cancellation/supersession safe at batch boundaries;
- publish only a result computed from the captured fingerprint and still-current dependencies.

Performance architecture is governed by `flutter-performance-contract.md`.

## 9. Vector policy

Every process has five vector classes:

- **Positive** — ordinary passing case with exact expected output.
- **Boundary** — exact limit/equality/edge-case demonstrating inclusivity, rounding and interval behavior.
- **Negative** — valid and fully evaluable engineering failure.
- **Adversarial** — duplicates, reordered sets, stale evidence, missing guarantees, overflow/resource attacks or misleading labels that must not create false PASS.
- **Cross-discipline** — verifies shared project facts/ELV4 evidence are neither dropped nor double counted and downstream stage boundaries stay intact.

Vector numbers are fictional product-neutral test data. They are not standards or product recommendations.

## 10. Acceptance

P1/P3/P4/P5/P6 cannot claim algorithm implementation readiness until the CI process-dossier guard proves:

- exactly 27 process headings;
- exact parity with process and algorithm registries;
- all 25 sections exist for every code;
- no TBD/placeholder section;
- each process contains pseudocode and a Dart interface surface;
- each process contains all five vector classes;
- every process states a complexity/resource model;
- the authority manifest fingerprints all four dossier files and the Flutter performance contract.

Runtime qualification still requires the public-command/file-SQLite L0–L6 evidence defined by P8.