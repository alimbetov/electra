# Electra — Engineering Calculation & Simulation Foundation v1

Status: **FOUNDATION DESIGN v1 / ELV5 ADOPTION REQUIRED / ACCEPTANCE NOT CLAIMED**  
Branch of introduction: `feat/flutter-elv5-power-topology-design`  
Schema: `electra.engineering-calculation-simulation-foundation.v1`

## 1. Technical criterion

Electra adopts the following project-wide engineering criterion:

> Any engineering result MUST be reproducible, deterministic, traceable to project facts and normative/catalog evidence, independently oracle-checked, exercised at engineering boundaries and across realistic scenarios, and MUST never silently replace unknown required input with an assumption.

This foundation is a reusable calculation-and-simulation contract for ELV4–ELV8. It does **not** take ownership of discipline formulas, jurisdictional decisions, equipment selection, physical layout or project lifecycle. It defines how engineering inputs are captured, how kernels execute, how evidence is traced, how scenarios are generated, how correctness is qualified and how a result may progress to acceptance.

## 2. Authority and ownership

Authority precedence for this document:

1. `project-alignment-hardening-v1.md` remains higher authority for ELV ownership, source-layer boundaries, revision lifecycle and downstream handoff.
2. This foundation governs cross-cutting calculation, evidence, simulation and qualification semantics.
3. Process-specific ELV5 contracts and dossiers remain authoritative for each discipline formula, applicability rule and subject model.
4. ELV7 remains the sole owner of verified jurisdictional/normative compliance.
5. ELV8 remains the sole owner of manufacturer/SKU selection and deliverable composition.

The foundation MUST NOT:

- create a 28th ELV5 discipline process;
- duplicate ELV4 power topology or ELV3 physical routing;
- hard-code a jurisdictional table into a generic kernel;
- allow a shared calculation engine to rewrite discipline ownership;
- retroactively invalidate accepted ELV4 evidence merely because this foundation was introduced later.

New or modified engineering calculations after this amendment MUST converge on this contract. Accepted historical results remain historical evidence and are migrated only by explicit versioned policy.

## 3. Mandatory invariants

| ID | Invariant |
|---|---|
| ECF-01 | Re-running the same immutable engineering input with the same algorithm/version/ruleset MUST produce the same engineering output and output hash. |
| ECF-02 | Worker count, scheduling order, map/set insertion order and UI state MUST NOT change an unordered engineering result. Ordered engineering paths remain order-sensitive. |
| ECF-03 | Every published engineering value MUST be traceable to source facts/evidence and the algorithm/scenario that produced it. |
| ECF-04 | External/reference evidence MUST carry stable identity, edition/revision and content hash. |
| ECF-05 | Exact arithmetic or dimension-safe bounded arithmetic MUST be used until a declared rounding boundary. Binary floating approximation MUST NOT silently determine pass/fail at an engineering limit. |
| ECF-06 | Required `UNKNOWN` input MUST fail closed. An explicit assumption MAY support a provisional what-if result but MUST NOT masquerade as verified evidence. |
| ECF-07 | Every production engineering kernel MUST have an independent oracle path that does not call or copy the production kernel implementation. |
| ECF-08 | Exact-limit, one-step-below and one-step-above boundary behavior MUST be qualified for every decision threshold. |
| ECF-09 | Applicable monotonicity, conservation, decomposition and invariance properties MUST be encoded as property/metamorphic tests. |
| ECF-10 | Each accepted process MUST declare and execute realistic scenario families, including governing/worst-case scenarios relevant to its engineering claim. |
| ECF-11 | Multi-case or multi-section calculations MUST publish the deterministic governing case/section and the reason it governs. |
| ECF-12 | Dependency changes MUST invalidate exactly the affected calculation scope; stale evidence MUST never be published as current. |
| ECF-13 | Frozen/historical calculations MUST be replayable using captured input, algorithm version and authority fingerprint, or explicitly marked non-replayable. |
| ECF-14 | Physical calculation and normative compliance are separate. A physical result MAY be complete while compliance remains `UNRESOLVED`. |
| ECF-15 | Performance optimization MUST NOT change engineering precision, conservative comparison semantics or result ordering/hash. |
| ECF-16 | No magic engineering constant is allowed without source/evidence identity or an explicit versioned algorithm definition. |
| ECF-17 | Presentation rounding MUST be separated from calculation precision. |
| ECF-18 | Monte Carlo or stochastic exploration MUST NOT replace deterministic normative worst-case qualification. |
| ECF-19 | A confidence percentage MUST NOT be fabricated from test counts. Confidence is represented by explicit evidence/qualification dimensions. |
| ECF-20 | Every accepted result MUST identify exact source SHA, process/algorithm versions, input fingerprint and authority fingerprint. |

## 4. Canonical calculation pipeline

```text
persisted project facts / external evidence
                  |
                  v
        short bounded capture
                  |
                  v
      application InputResolver
                  |
          immutable input
                  |
        input fingerprint
                  |
                  v
       pure EngineeringKernel
                  |
                  v
        typed engineering output
                  |
      result + trace + findings
                  |
        qualification metadata
                  |
                  v
     guarded atomic publication
                  |
             current pointer
```

Rules:

- repository/Drift/UI/platform access is forbidden inside the pure kernel;
- the resolver MUST bulk-read declared dependencies and MUST NOT perform member-loop N+1 reads;
- the immutable input MUST contain all values needed by the kernel, including evidence references and scenario identity;
- the kernel MUST NOT read wall-clock time, random global state, locale, timezone defaults or mutable singleton configuration;
- publication MUST validate design revision, dependency fingerprint and expected optimistic revision before advancing a current pointer;
- a failed/blocked calculation MAY persist diagnostic evidence but MUST NOT replace a valid current engineering result with false PASS evidence.

## 5. Shared code-level semantics

The exact source filenames may evolve, but the semantic interfaces are mandatory.

```dart
abstract interface class EngineeringKernel<I, O> {
  O evaluate(I input);
}

abstract interface class EngineeringInputResolver<I> {
  Future<I> resolve(EngineeringCaptureContext context);
}

final class EngineeringCalculationIdentity {
  final String processCode;
  final String processVersion;
  final String algorithmVersion;
  final String inputSchemaVersion;
  final String resultSchemaVersion;
  final String rulesetVersion;
}

final class EngineeringCalculationContext {
  final String projectId;
  final String designRevisionId;
  final String subjectId;
  final String scenarioId;
  final String authorityFingerprint;
}

final class EngineeringResultEnvelope<O> {
  final EngineeringCalculationIdentity identity;
  final EngineeringCalculationContext context;
  final String inputFingerprint;
  final String outputFingerprint;
  final O output;
  final EngineeringTrace trace;
  final List<EngineeringFinding> findings;
  final EngineeringQualificationState qualification;
}
```

These names are reference coordinates. Existing ELV5 types MAY satisfy the semantics without a forced rename.

## 6. Engineering quantities and numeric policy

A generic untyped `double value` is forbidden for a public engineering contract when the physical dimension is known.

Preferred dimensions include at least:

```text
Current
Voltage
Resistance
Power
ApparentPower
Energy
Charge/Ah
Length
Area
CrossSectionArea
Temperature
Duration
DataRate
StorageCapacity
Attenuation
OpticalPower
Mass
HeatPower
Ratio
```

Equivalent units MUST normalize to the same canonical engineering quantity before hashing/comparison.

Use, in order of preference:

1. integer canonical base units when exact and practical;
2. rational arithmetic for exact ratios/conversions;
3. fixed decimal with explicit scale/rounding policy;
4. interval arithmetic when source uncertainty is material;
5. floating/transcendental arithmetic only where mathematically required.

If floating/transcendental math is required, the algorithm contract MUST freeze the implementation family, precision/tolerance, domain restrictions, comparison policy, output quantization and independent-oracle tolerance.

Rounding is legal only at a declared boundary:

```text
raw exact/bounded calculation
        -> algorithm-prescribed rounding (if required)
        -> engineering comparison
        -> persisted canonical result
        -> presentation rounding
```

UI formatting MUST NOT feed back into engineering decisions.

## 7. Input evidence and unknown-value policy

Every required engineering input carries an evidence state:

```text
VERIFIED     independently sourced/measured/catalog/normative evidence
DECLARED     explicit project fact entered/approved as a design fact
DERIVED      deterministic output of another accepted calculation
ASSUMED      explicit design assumption for what-if/provisional use
UNKNOWN      unavailable or unresolved
```

Rules:

- `UNKNOWN` on a mandatory dimension => `Completion=BLOCKED` or `PARTIAL` according to process contract;
- the resolver MUST NOT synthesize Cu, ambient temperature, installation method, coefficient `1.0`, loaded-conductor count, efficiency, reserve, diversity or any equivalent default unless the domain contract explicitly defines it as a real invariant;
- `ASSUMED` requires an assumption ID, rationale, scope and provenance;
- an assumed value MUST remain visible in trace/provenance;
- an assumed value MUST NOT satisfy a `VERIFIED_ONLY` requirement;
- a result that depends materially on an assumption may be computed for engineering exploration, but cannot silently become verified normative PASS;
- replacing `ASSUMED/UNKNOWN` with stronger evidence MUST invalidate dependent results.

## 8. Evidence and provenance graph

Every calculation MUST be explainable as a directed acyclic provenance graph.

Minimum node classes:

```text
PROJECT_FACT
EXTERNAL_EVIDENCE
DERIVED_INPUT
SCENARIO
ALGORITHM
RESULT
FINDING
NORMATIVE_RULE
EQUIPMENT_SELECTION
```

Minimum edge meanings:

```text
DEPENDS_ON
DERIVED_FROM
EVALUATED_BY
GOVERNS
VALIDATED_BY
INVALIDATES
SELECTED_FROM
```

External/reference evidence identity MUST include:

```text
evidenceId
sourceType
sourceRef
editionId/revisionId
contentHash
scope
applicability
```

Source types include `MEASUREMENT`, `MANUFACTURER_DATASHEET`, `CATALOG`, `NORMATIVE_TABLE`, `PROJECT_FACT`, `DERIVED_CALCULATION` and `ENGINEERING_ASSUMPTION`.

Volatile metadata such as display timestamps MAY be persisted, but MUST NOT make two otherwise identical engineering calculations hash differently unless time is itself an engineering input.

## 9. Result state model

The existing independent result axes remain mandatory:

```text
Freshness    CURRENT | STALE
Completion   COMPLETE | PARTIAL | BLOCKED
Assessment   PASS | FAIL | UNRESOLVED | NOT_ASSESSED
Execution    SUCCEEDED | FAILED
```

No axis may be inferred from another.

- `SUCCEEDED + COMPLETE + UNRESOLVED` is valid when physics is calculated but ELV7 compliance is not yet evaluated;
- `SUCCEEDED + BLOCKED` is valid for a persisted fail-closed diagnostic result;
- `FAILED` is an execution failure, not an engineering FAIL;
- `STALE + PASS` is historical prior assessment, never current acceptance.

## 10. Governing case and conservative evaluation

Processes with several operating cases, route sections, alternatives or bounds MUST publish:

```text
evaluated cases/sections
governingCaseId or governingSectionId
governingReasonCode
governingValue
margin/headroom if meaningful
tieBreakRule
```

Tie-breaking MUST be deterministic. The governing rule belongs to the domain process/algorithm contract, not UI code.

Examples: minimum route-section `Iz`, maximum adverse voltage drop, maximum required storage, minimum optical margin, worst credible battery/autonomy case.

## 11. Scenario and simulation foundation

Supported scenario classes:

```text
BASELINE
NOMINAL
BOUNDARY
WORST_CASE
FAILURE
COMBINATORIAL
SENSITIVITY
UNCERTAINTY
MONTE_CARLO_EXPLORATORY
```

Each scenario MUST have a stable ID and canonical input projection.

Generated scenarios MUST freeze:

```text
generatorVersion
catalogVersion
constraintVersion
seed when applicable
ordered dimension definitions
legal-combination constraints
expected coverage obligations
```

Generation order MUST NOT affect scenario identity.

Every engineering threshold requires at least below-limit, exact-limit and above-limit cases using the smallest meaningful canonical step or a declared engineering tolerance.

Large input spaces SHOULD use deterministic covering arrays rather than an infeasible full Cartesian product. ELV5 retains its existing 450 market-shaped deterministic scenarios and 1500 combinatorial scenarios with complete declared legal pair coverage and targeted 3-wise obligations. They remain design/coverage evidence until bound to executed production-runtime evidence on an exact source SHA.

For declared sensitive variables, Electra SHOULD report parameter, base value, variation, result delta, normalized sensitivity where meaningful and monotonic direction. Sensitivity output is engineering analysis, not a normative decision by itself.

When a source value is bounded rather than exact, a process SHOULD preserve minimum/nominal/maximum or an exact interval where practical. Guaranteed requirements MUST use the adverse bound.

Monte Carlo is supplemental only. If used it MUST freeze PRNG algorithm, seed, sample count, distribution family/parameters, correlation assumptions and generator version. It MUST NOT convert a deterministic violation into PASS or replace deterministic worst-case qualification.

## 12. Independent oracle contract

A production kernel is not accepted from self-consistency alone.

An oracle MUST:

- be independent of the production kernel implementation;
- not call the production kernel;
- not generate expected values by serializing production output;
- declare formula/reference/source basis;
- declare units and rounding/tolerance;
- retain human-reviewable derivation for high-risk calculations.

Allowed oracle families:

```text
HAND_DERIVATION
REFERENCE_TABLE
SECOND_SIMPLE_IMPLEMENTATION
PUBLISHED_EXAMPLE
INDEPENDENT_TOOL_RESULT
CLOSED_FORM_IDENTITY
```

For safety-relevant calculations, at least one oracle MUST use a genuinely independent derivation/reference. When valid oracles disagree beyond tolerance, acceptance is blocked until reconciled.

## 13. Property and metamorphic qualification

Every process dossier MUST declare applicable properties. Typical examples:

```text
higher nonnegative load cannot improve capacity margin
longer identical conductor cannot reduce voltage drop
lower derating factor cannot increase Iz
greater available capacity cannot worsen capacity headroom
higher path loss cannot improve optical margin
splitting an interval without changing its union cannot change integrated energy/storage
reordering an unordered set cannot change output hash
reordering an ordered route may change path fingerprint/result
adding an unrelated subject cannot change an isolated result
equivalent unit conversion cannot change canonical result
```

Properties MUST execute over bounded deterministic generated inputs. Uncontrolled fuzz/random CI is forbidden for acceptance evidence.

## 14. Failure and cause/effect simulation

A reusable failure scenario identifies:

```text
failedSubjectId
failureModeCode
activationScenario
expected impacted dependency closure
expected retained functions
expected lost functions
affected calculation nodes
```

Future domain bindings SHOULD cover PSU, switch, controller, recorder/storage, uplink/fiber, battery-string, route/cable-section and notification/sensor-circuit failures where applicable.

Cause/effect graphs MAY be evaluated as:

```text
cause
 -> required actions
 -> topology-resolved targets
 -> observed/derived effects
 -> missing/unexpected effect findings
```

Technical cause/effect topology may be owned by the discipline. ELV7 owns whether required effects satisfy a jurisdictional code.

## 15. Qualification model

The existing ELV5 L0–L6 runtime pyramid remains valid. This foundation adds cross-cutting qualification profiles that overlay it rather than renumbering it:

```text
Q0  contract/schema/inventory consistency
Q1  mathematical reference vectors
Q2  independent oracle qualification
Q3  boundary-value qualification
Q4  property/metamorphic qualification
Q5  deterministic scenario/combinatorial qualification
Q6  persistence/replay/invalidation/publication qualification
Q7  failure/concurrency/restart qualification
Q8  freeze/historical/determinism qualification
Q9  performance/bounds qualification
```

For any engineering process to become `ACCEPTED`, Q0–Q8 are mandatory where applicable. Q9 is mandatory when the process has declared workload/performance bounds.

Safety-relevant processes additionally require unsupported-model fail-closed vectors, an independent reference/derivation oracle, adverse boundary scenarios, failure/restart evidence where persisted/public and zero false-PASS sentinels in the declared qualification matrix.

Test count alone never proves confidence.

## 16. Confidence representation

Electra MUST NOT expose a fabricated scalar such as `confidence=97%` unless a statistically valid domain model explicitly defines that probability.

Use an evidence vector instead:

```text
INPUT_COMPLETENESS
SOURCE_PROVENANCE
NUMERIC_QUALIFICATION
INDEPENDENT_ORACLE
BOUNDARY_COVERAGE
PROPERTY_COVERAGE
SCENARIO_COVERAGE
RUNTIME_REPLAY
HISTORICAL_REPLAY
NORMATIVE_RESOLUTION
```

Each dimension is an explicit state/evidence reference, not a marketing score.

## 17. Algorithm and schema versioning

Every persisted accepted result MUST bind:

```text
processCode
processVersion
algorithmVersion
inputSchemaVersion
resultSchemaVersion
rulesetVersion
normativeProfileVersion when applicable
sourceSha
authorityFingerprint
inputFingerprint
outputFingerprint
```

Frozen/historical projects MUST NOT silently switch algorithms. A new algorithm version requires `REPLAY_OLD_VERSION`, `EXPLICIT_MIGRATION` or `EXPLICIT_NON_REPLAYABLE_STATUS`. Recalculation with a newer algorithm creates new evidence; it does not rewrite historical evidence.

## 18. Machine-readable process definition target

Each production process MUST eventually expose a machine-readable definition containing at least:

```text
processCode
ownerStage
criticality
inputSchema
outputSchema
algorithmId/version
dependencies
requiredEvidence
unknownInputPolicy
scenarioFamilies
governingRule
oracleIds
boundaryDimensions
propertyIds
metamorphicIds
persistenceBinding
invalidationBinding
performanceClass
qualificationState
```

This is the long-term source for generating derivative registries, documentation inventory and CI checks. Multiple hand-maintained registries SHOULD gradually become generated projections of this authoritative definition where practical.

## 19. Lifecycle/status model

Runtime state MUST NOT be represented by one stale `NOT_STARTED` flag.

Canonical lifecycle:

```text
DESIGNED
KERNEL_IMPLEMENTED
RUNTIME_INTEGRATED
QUALIFIED
ACCEPTED
```

Optional orthogonal flags MAY express `PARTIAL`, `BLOCKED` or `DEPRECATED`, but MUST NOT collapse the lifecycle.

Evidence requirements:

- `DESIGNED`: normative contract exists;
- `KERNEL_IMPLEMENTED`: production pure kernel + kernel tests exist;
- `RUNTIME_INTEGRATED`: resolver/persistence/publication path exists;
- `QUALIFIED`: mandatory Q profiles pass on an exact source SHA;
- `ACCEPTED`: P9/stage acceptance pins exact SHA + authority fingerprint + qualification evidence.

Documentation MUST derive or verify these states from evidence rather than hard-code all processes to `NOT_STARTED`.

## 20. Pilot binding: cable ampacity

The existing ELV5 ampacity work is the first foundation pilot:

```text
cross-section
material
insulation
installation method
loaded conductors
reference ambient
base reference current
    +
temperature correction
grouping correction
additional corrections
        |
        v
Iz(section)
        |
        v
minimum over route sections
        |
        v
route Iz + governing section
```

The foundation does not move domain ownership in this amendment. A later shared-electrical refactor MAY extract reusable ampacity primitives without changing ELV5 result semantics.

Future electrical coordination SHOULD compose, without duplicate ownership, `Ib` (calculated load/current), `In` (protective-device nominal current) and `Iz` (allowable continuous conductor current), with the actual engineering/normative constraints evaluated in the appropriate ELV4/ELV7 ownership layers.

## 21. Shared electrical calculation backlog

The foundation prepares, but does not add ELV5 process codes for:

```text
current/load conversion
ampacity
voltage drop
short-circuit current
conductor thermal withstand / I2t
protective-device breaking capacity
protection coordination
selectivity
battery sizing/autonomy
UPS sizing/runtime
PoE power budget
```

Reusable kernels SHOULD live in a shared electrical engineering layer once extraction is justified by real repeated consumers. Premature generic abstraction is forbidden.

## 22. Stage adoption plan

### F0 — Foundation authority

Deliver this specification, machine-readable foundation contract and authoritative-index binding.

### F1 — Shared primitives

Reconcile existing quantity/evidence/canonical/scenario/result types to foundation invariants without unnecessary renames.

### F2 — Pilot qualification

Bind at least:

```text
AMPACITY route Iz
FA-03 terminal voltage
ACS-03 electrical/lock circuit
CCTV-03 storage
LAN-05 optical budget
```

These cover route minima, electrical bounds, time integration and logarithmic/interval engineering.

### F3 — ELV5 27-process adoption

For all 27 processes add an evidence-backed process manifest, explicit input evidence states, oracle/boundary/property/scenario bindings, governing-case semantics and lifecycle. The process count remains exactly 27.

### F4 — Shared electrical hardening

Extract reusable electrical kernels only after stable duplicated consumers exist. Preserve ELV4 ownership and accepted historical evidence.

### F5 — ELV6 adoption

Apply the foundation to fit, collision, service volume, support load, center-of-gravity, airflow/thermal and governing physical constraints.

### F6 — ELV7 adoption

Bind normative profiles/rulesets as versioned evidence. ELV7 remains the only stage allowed to issue verified jurisdictional compliance decisions.

### F7 — ELV8 adoption

Bind exact equipment/catalog evidence, selection constraints, BOM and deliverable traceability to upstream accepted calculations.

## 23. Acceptance gate

A stage/process MUST NOT claim engineering acceptance unless its applicable foundation evidence proves:

```text
deterministic replay
exact source/version identity
complete required input evidence
no silent defaults
independent oracle
boundary behavior
property/metamorphic behavior
scenario coverage
governing-case trace
dependency invalidation
persistence/restart behavior
historical/freeze invariance
performance bounds where declared
```

The acceptance artifact MUST be generated from one exact tested source SHA and one exact authority fingerprint.

## 24. Definition of done for foundation adoption

Foundation v1 is considered adopted by ELV5 only when:

1. the machine-readable contract is validated;
2. pilot processes are bound to the foundation;
3. all 27 processes have evidence-backed lifecycle status rather than hard-coded `NOT_STARTED`;
4. qualification evidence references exact source SHA and authority fingerprint;
5. no required unknown input is silently defaulted;
6. scenario/oracle/boundary/property requirements are machine-checkable;
7. historical/frozen results retain replay/version semantics;
8. ELV6/ELV7/ELV8 handoff can consume accepted results without inferring stronger claims than ELV5 produced.

This is a quality contract, not permission to claim that all runtime work is already complete.
