# ELV5 — Unified engineering calculation engine contract

Status: DESIGN HARDENED / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`

This contract defines the **common deterministic calculation protocol** for all 27 ELV5 processes. It does not replace process-specific formulas. `process-contracts.md` owns process mathematics and claim boundaries; `algorithm-registry.json` binds every process to the common solver families below; `code-level-hardening-v2.md` remains higher authority where applicable.

The objective is that CCTV, LAN, ACS and fire-alarm calculations behave like one professional engineering system rather than 27 unrelated calculators.

## 1. Non-negotiable project alignment

ELV5 MUST reuse the canonical project facts and kernels already owned by earlier stages:

- ELV2 owns immutable catalog/profile editions and explicit adoption;
- ELV3 owns canonical components, ports, cables, route/resource realization and installed physical lengths;
- ELV4 owns shared electrical topology and `ELV-PWR-01…06` physical power kernels/evidence;
- ELV5 owns discipline-specific engineering inputs, policy composition, calculations, technical margins and explanations;
- ELV6 owns actual enclosure/rack layout and fit;
- ELV7 owns normative applicability and verified compliance;
- ELV8 owns commercial product selection/BOM/procurement deliverables.

No ELV5 algorithm may duplicate a canonical cable length, power flow, voltage-drop, battery or PoE calculation merely to simplify a discipline implementation. Discipline wrappers consume exact upstream immutable evidence and add only discipline context/requirements.

## 2. One calculation lifecycle for all processes

Every ELV5 process executes the same semantic stages:

```text
1 CAPTURE
2 RESOLVE_APPLICABILITY
3 RESOLVE_INPUTS
4 NORMALIZE_ENGINEERING_STATE
5 BUILD_OPERATING_CASES
6 RUN_PROCESS_KERNEL
7 COMPOSE_REQUIREMENTS
8 CONSERVATIVE_COMPARE
9 DERIVE_MARGINS_AND_GOVERNING_CASE
10 DERIVE_DIMENSION_STATUSES
11 BUILD_CALCULATION_TRACE
12 BUILD_FINDINGS_AND_RECOMMENDATIONS
13 GUARDED_PUBLISH
```

A process may have a trivial implementation of a stage, but it may not silently skip its semantics.

### 2.1 CAPTURE

Capture exact immutable inputs, policy refs/hashes, set/selector markers, upstream evaluation IDs/hashes/pointer generations, measurement evidence and temporal/frame evidence. Capture creates the canonical input fingerprint.

### 2.2 RESOLVE_APPLICABILITY

Before arithmetic, decide whether the selected algorithm/model is valid for the captured topology/equipment/operating case.

Output is one of:

```dart
sealed class Elv5ModelApplicability {}
final class Elv5Applicable extends Elv5ModelApplicability {}
final class Elv5PartiallyApplicable extends Elv5ModelApplicability {
  final Set<String> unsupportedDimensions;
}
final class Elv5UnsupportedModel extends Elv5ModelApplicability {
  final String modelCode;
  final String findingCode;
}
```

Arithmetic from an inapplicable model MUST NOT be used to manufacture PASS.

### 2.3 RESOLVE_INPUTS

Convert wire/storage values into typed engineering fields using the explicit known/missing/not-applicable/unsupported/unresolved algebra. No semantic `null` reaches a kernel.

### 2.4 NORMALIZE_ENGINEERING_STATE

Normalize only representations, never engineering meaning:

- canonical SI/byte/radian units;
- exact rational/decimal representation;
- canonical IDs/order/set semantics;
- explicit coordinate frame;
- explicit operating-case identity;
- explicit evidence basis and uncertainty interval.

Normalization never guesses absent values and never turns typical into guaranteed evidence.

### 2.5 BUILD_OPERATING_CASES

A process must identify the states that can govern its result. Cases are code-owned/versioned and selected from captured facts/policies.

Examples:

```text
CCTV: expected stream, peak stream, continuous/event recording
LAN: normal traffic capacity basis, optical TxMin/lossMax, TxMax/lossMin
ACS: holding, active, startup/inrush, fire release, power failure
FIRE: standby, alarm, notification active/inrush, supervision fault states
```

The solver evaluates all required cases independently before deriving the governing case.

### 2.6 RUN_PROCESS_KERNEL

The kernel is pure, typed and deterministic. It may call accepted pure ELV3/ELV4 kernels only through explicit adapters and exact scoped input/evidence.

Forbidden inside kernels:

```text
DateTime.now()
random values
locale-dependent parsing/formatting
host timezone lookups
latest catalog/profile lookup
mutable database reads
UI selection state
untyped executable formula content from project data
```

## 3. Calculation families

All 27 processes belong to one or more code-owned solver families.

### 3.1 `GEOMETRY_BOUNDED`

Used for geometry with exact inputs and conservative bounded non-rational operations.

Required behavior:

- explicit coordinate frames and transforms;
- degeneracy checks before intersection/angle operations;
- conservative interval result when transcendental/derived geometry cannot be represented exactly;
- no midpoint-only PASS;
- explicit model applicability boundary.

Primary process: CCTV-01.

### 3.2 `FLOW_ACCOUNTING`

Used when unique origins create copies/flows over a directed physical/logical graph.

Required behavior:

- stable origin identity;
- explicit copy/subscription identity;
- path-edge accounting;
- deduplication only through a selected supported model;
- per-edge and aggregate totals;
- expected and peak kept separate.

Primary process: CCTV-02.

### 3.3 `TIME_INTEGRATION`

Used for storage/energy-like integration across a horizon.

Required behavior:

```text
integral = Σ(value(case,t) × uniqueDuration(case,t))
```

- expand recurrence from captured timezone-rule evidence;
- union overlapping half-open intervals before integration where identity means one physical recording/state;
- preserve deliberate multiple copies/pools;
- apply reserve/redundancy in named stages exactly once;
- final discrete capacity rounding only at the declared boundary.

Primary process: CCTV-03; sequence semantics are reused conceptually by ACS-05/FA-05 through ELV4 evidence.

### 3.4 `RESOURCE_CAPACITY`

Used for ports, channels, addresses, RU and similar finite resources.

Required behavior:

```text
used = cardinality(unique canonical claims)
required = used + explicit required spare/reserve
margin = available - required
utilization = required / available  // only when available > 0
```

Each resource dimension is independent. Passing one dimension does not imply another.

Processes: CCTV-05, LAN-02, LAN-06, LAN-07, ACS-02, FA-01, FA-06 where device/output cardinality applies.

### 3.5 `ORDERED_PATH`

Used where the weakest/limiting section of an ordered realized path governs.

Required behavior:

- consume ELV3 realized ordered sections;
- preserve section role and traversal identity;
- aggregate additive quantities exactly once;
- reduce capability through an explicit code-owned limiting operator;
- return the limiting section(s) as provenance.

Processes: CCTV-06, LAN-01, LAN-04, FA-08.

### 3.6 `OPTICAL_INTERVAL_BUDGET`

Used for bidirectional fiber power budget.

For each direction:

```text
lossMin = Σ minimum physical losses
lossMax = Σ maximum physical losses
rxWorstSensitivity = txMin - lossMax
rxWorstOverload = txMax - lossMin
sensitivityMargin = rxWorstSensitivity - (receiverSensitivity + requiredSensitivityMargin)
overloadMargin = receiverOverload - rxWorstOverload
```

PASS requires both margins `>= 0` for every required direction. Engineering reserve is not hidden inside physical `lossMin/lossMax`. Reach/dispersion is a separate claim unless an exact registered model exists.

Process: LAN-05.

### 3.7 `PHYSICAL_EVIDENCE_WRAPPER`

Used when ELV5 contextualizes an ELV4 physical result.

Required behavior:

- exact immutable upstream evaluation identity;
- exact scope/scenario/segment/sequence match;
- full shared physical membership retained;
- selected discipline contribution is a projection of the same global evidence;
- no reapplication of physical losses/reserves already owned upstream.

Processes: CCTV-04, LAN-03, ACS-03, ACS-04, ACS-05, FA-03, FA-04, FA-05, FA-06.

### 3.8 `TOPOLOGY_CONSTRAINT`

Used for role/reachability/path/fault-state truth on typed graphs.

Required behavior:

- graph layer/type is explicit;
- control, data, supply, supervision and release edges are not interchangeable;
- alternatives/multiplicities are explicit constraints;
- a topological PASS cannot imply electrical capacity PASS;
- required fault/release cases are evaluated independently.

Processes: ACS-01, ACS-06, FA-07.

### 3.9 `POLICY_EVIDENCE_BASIS`

Used where ELV5 proves technical matching to a selected project/manufacturer profile without claiming verified jurisdictional compliance.

Required behavior:

- selected immutable policy edition/hash;
- explicit applicability evidence;
- per-requirement match/missing/conflict;
- source status retained;
- verified-compliance status remains outside ELV5 unless exact ELV7 evidence is later consumed by a downstream stage.

Processes include CCTV-06, LAN-04, LAN-06, ACS-01/06, FA-08 and requirement-composition stages across physical wrappers.

## 4. Requirement composition algebra

Requirements are never combined by human intuition such as “take the stricter one” without a registered merge operator.

Each dimension selects exactly one merge kind from `Elv5RequirementMergeKind`:

```text
maximumLowerBound
minimumUpperBound
setIntersection
setUnion
exactAgreement
orderedSequenceComposition
nonComposable
```

The effective requirement stores all participating policy refs and normalized operands. A conflict produces `UNRESOLVED/BLOCKED`, not an arbitrary winner.

For source/bank capabilities the solver MUST distinguish:

```text
physical demand
measurement/model uncertainty
policy reserve
component derating
redundancy architecture
commercial spare
```

These are distinct transforms and cannot be collapsed into one unnamed safety factor.

## 5. Conservative comparison protocol

Every threshold comparison is expressed as a typed comparison object:

```dart
final class Elv5EngineeringComparison<Q> {
  final String dimensionCode;
  final Elv5ComparisonKind kind;
  final Elv5ResolvedField<Q> actual;
  final Elv5ResolvedField<Q> requirement;
  final Elv5ResolvedField<Q> margin;
  final Elv5ResolvedField<Elv5Ratio> utilization;
  final Elv5EvidenceBasis actualBasis;
  final Elv5Applicability applicability;
  final Elv5OperatingCaseRef governingCase;
  final List<Elv5ProvenanceRef> provenance;
}
```

For bounded/uncertain values, PASS uses the conservative edge required by the comparison. Examples:

```text
minimum required voltage: actual.lower >= requirement.upper
maximum allowed loss: actual.upper <= requirement.lower
minimum receiver level: worst received lower bound >= required lower bound
maximum capacity: required upper bound <= available lower bound
```

If interval ordering overlaps a threshold and the selected policy does not permit probabilistic reasoning, assessment is `UNRESOLVED`, not guessed PASS/FAIL.

## 6. Governing case and limiting factor

Every process with more than one operating case/direction/resource dimension MUST return its governing case(s) and limiting factor(s).

Examples:

```text
LAN-05: direction B->A overload margin is smallest
ACS-03: startup event at t=0…250 ms governs source current
FA-05: alarm segment governs peak current while standby dominates energy
CCTV-05: storage capacity governs although channel count has spare
LAN-04: patch cord section P-17 is limiting capability
```

A deterministic tie returns all tied limiting identities in canonical order.

## 7. Margin, utilization and headroom

Where mathematically meaningful, every capacity/threshold dimension exposes:

```text
actual
required/limit
absolute margin
normalized utilization/headroom
basis/applicability
governing case
```

Rules:

- margin sign convention is always **positive = acceptable headroom**, negative = deficit;
- utilization is never used as the verdict when interval/evidence semantics require a stronger comparison;
- division by zero/undefined normalization produces explicit N/A, not infinity;
- UI rounding never changes margin or verdict.

This enables engineers to distinguish “PASS with 40% headroom” from “PASS exactly at boundary”.

## 8. Deterministic calculation trace

Every completed or partially completed kernel emits a bounded semantic trace. The trace is explanatory evidence, not executable user-defined code.

```dart
final class Elv5CalculationStep {
  final String stepCode;
  final String algorithmVersion;
  final String equationCode;
  final List<Elv5TraceOperand> operands;
  final Elv5ResolvedField<Object> result;
  final Set<String> affectedDimensions;
  final List<Elv5ProvenanceRef> provenance;
}
```

`equationCode` is a stable code-owned identifier such as:

```text
OPTICAL_RX_WORST_SENSITIVITY_V1
RESOURCE_REQUIRED_WITH_SPARE_V1
RECORDING_BITS_INTEGRAL_V1
DC_TERMINAL_MARGIN_FROM_PWR03_V1
```

The UI may render a human equation from this code, but hashes and tests use typed operands/results, not localized text.

## 9. Sensitivity and what-if analysis

ELV5 MAY provide deterministic sensitivity analysis to help engineering decisions, but it is separate from the authoritative verdict.

Supported approach:

- vary one explicitly selected design variable within a bounded engineer-specified interval/set;
- reuse the same pure kernel;
- compute monotonic breakpoints where possible;
- return the first limiting threshold/bottleneck;
- never persist a what-if result as CURRENT authoritative evidence unless the corresponding project input is actually committed.

Examples:

```text
maximum additional cameras before recorder ingress FAIL
maximum additional PoE load before shared PSE margin reaches zero
maximum fiber physical loss before sensitivity margin reaches zero
minimum required usable storage for selected retention
minimum source rating for captured operating envelope
```

Monte Carlo/random simulation is NOT part of ELV5 pass/fail logic. If probabilistic models are ever added, they require a separate versioned process/model and explicit claim semantics.

## 10. Process result contract

Every process output MUST be representable by one common envelope plus typed process payload:

```dart
final class Elv5CalculationResult<O> {
  final Elv5EngineeringNodeKeyV3 nodeKey;
  final String algorithmVersion;
  final String numericPolicyVersion;
  final Elv5ModelApplicability modelApplicability;
  final List<Elv5OperatingCaseResult> cases;
  final List<Elv5EngineeringComparison<Object>> comparisons;
  final Set<String> governingCaseCodes;
  final List<Elv5LimitingFactor> limitingFactors;
  final List<Elv5CalculationStep> steps;
  final List<Elv5Finding> findings;
  final O typedOutput;
  final Elv5Completion completion;
  final Elv5Assessment assessment;
  final Elv5Execution execution;
  final String inputFingerprint;
  final String outputHash;
}
```

The process-specific `O` remains strongly typed. The common envelope exists to make workspace, qualification and cross-discipline reasoning consistent.

## 11. Verdict derivation

Verdict derivation is centralized and code-owned.

Required logic:

```text
execution FAILED
  -> execution=FAILED; no technical PASS
unsupported mandatory model/input
  -> completion=BLOCKED/PARTIAL; assessment=UNRESOLVED
all required dimensions resolved and >= acceptance boundary
  -> completion=COMPLETE; assessment=PASS
all required dimensions resolved and any required comparison violates boundary
  -> completion=COMPLETE; assessment=FAIL
some required dimensions unresolved
  -> completion=PARTIAL/BLOCKED; assessment=UNRESOLVED
later-stage dimension
  -> NOT_ASSESSED and excluded from ELV5 overall required set
```

A stale pointer never becomes current PASS merely because its immutable evaluation was once PASS.

## 12. Discipline-specific algorithm hardening

### 12.1 CCTV

- CCTV-01: evaluate geometry degeneracy before FOV/footprint; store bounded FOV and footprint, frame provenance and limiting zone/edge.
- CCTV-02: evaluate directed copies per edge; separate payload bitrate from optional wire-rate capacity model; identify governing edge by peak utilization.
- CCTV-03: integrate each unique recording identity exactly over captured UTC intervals; expose raw bits, exact bytes before rounding, usable bytes, raw/redundant basis and retention claim scope.
- CCTV-04: report same global PSE result as ELV4 plus CCTV contribution; governing source/segment remains upstream evidence.
- CCTV-05: evaluate channel/license, ingress, codec/profile and storage independently; overall result governed by smallest normalized headroom among required dimensions.
- CCTV-06: ordered link composition and physical-path proof precede policy match; powered path consumes exact applicable PWR-06 evidence.

### 12.2 LAN

- LAN-01: permanent and patch subsets are disjoint typed roles; channel is set union; limiting length dimension is explicit.
- LAN-02: physical-port compatibility is resolved before spare arithmetic; incompatible assignment is not merely a capacity deficit.
- LAN-03: same shared-source discipline-wrapper rules as CCTV-04.
- LAN-04: capability reduction walks every ordered section and returns exact limiting section/property.
- LAN-05: evaluate both directions, sensitivity and overload separately; the smallest signed margin is governing. Optional reach/dispersion model is independent.
- LAN-06: produce RU/weight/depth demand envelope and available margins only; actual placement remains ELV6 NOT_ASSESSED.
- LAN-07: physical port occupancy, spare and mapping completeness are independent comparisons.

### 12.3 ACS

- ACS-01: role alternatives compile into a typed constraint set; report the minimum unsatisfied alternative rather than a generic missing-role message.
- ACS-02: reader/relay/input resource pools are independent; each returns used/required/available/margin.
- ACS-03: evaluate holding/active/startup events using the selected simultaneity rule and exact PWR evidence; startup can govern even when steady state passes.
- ACS-04: merge source requirements with registered merge kinds; report physical demand separately from required capability and available derated capability.
- ACS-05: sequence energy/current and global bank applicability are evaluated from the same protected sequence; expose the governing time segment/state.
- ACS-06: execute the five canonical release causes as a truth-table solver over control/feed/release/supervision paths; each cause has its own technical outcome.

### 12.4 Fire alarm

- FA-01: expand address/resource claims first, then run uniqueness/cardinality; base-address uniqueness alone is insufficient.
- FA-02: produce separate standby/alarm/startup/inrush cases where profiles expose them; missing one case does not erase known subtotals but prevents a complete claim.
- FA-03: only supported electrical topology delegates to PWR-03; signal-loop closure never changes electrical-model applicability.
- FA-04: source capability composition uses full fire + shared non-fire demand and deterministic requirement merge.
- FA-05: evaluate ordered standby/alarm sequence using exact duration policies and PWR-04 bank evidence; report both energy and peak/current governing states where available.
- FA-06: count/output-current/terminal-voltage/transient dimensions are independent; optional supervision model adds explicit fault-state dimensions.
- FA-07: topology solver evaluates closure, branch policy, address/topology consistency and selected fault/supervision cases independently.
- FA-08: technical cable/environment/policy evidence matching only; no certified compliance claim.

## 13. Qualification requirements added by this contract

P8 must add cross-process invariants in addition to the 54 primary POS/NEG verticals:

1. every required process code is present in `algorithm-registry.json` exactly once;
2. every multi-case process emits a governing case or explicit reason why no governing case exists;
3. every capacity/limit process with resolved finite operands emits signed margin using positive=headroom convention;
4. changing UI locale/host timezone does not change input fingerprint/output hash;
5. same physical upstream ELV4 evidence used by two discipline wrappers has the same evaluation ID/output hash;
6. a typical/estimated value cannot satisfy a guaranteed-bound comparison;
7. interval overlap with a threshold cannot silently PASS;
8. what-if/sensitivity results cannot publish CURRENT without committed input mutation;
9. calculation trace equation codes and operand order are deterministic after restart/replay;
10. limiting-factor identity is stable under unrelated project mutations.

## 14. Definition of done for a calculation process

A process is not implemented merely because a formula returns a number. It is complete only when production code proves:

```text
[ ] typed input/output
[ ] applicability resolver
[ ] required operating cases
[ ] deterministic pure kernel
[ ] exact/bounded numeric semantics
[ ] requirement merge semantics where applicable
[ ] conservative comparison
[ ] margin/utilization where meaningful
[ ] governing case + limiting factor where meaningful
[ ] stable calculation trace
[ ] exact provenance/dependencies
[ ] no-false-PASS behavior
[ ] POS + NEG public-command qualification
[ ] restart/replay determinism
[ ] resource-bound/adversarial safety
```

This definition is intentionally stronger than “formula covered by unit test”. It is the minimum standard for ELV5 engineering-grade runtime acceptance.
