# ELV5 — Third-pass code-level engineering hardening contract

Status: DESIGN HARDENED / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`

This document is a **normative amendment** to the ELV5 design package. It closes implementation-level gaps found after the first discipline audit and the second engineering/architecture hardening pass.

Where this document conflicts with older ELV5 wording, this document governs. It does not change the fixed 27 process codes, 16 public operation count, ELV4 ownership boundary or schema-24 target. It makes the already selected architecture implementable without ambiguous nulls, cross-kind identity mistakes, unbounded exact-arithmetic inputs, non-reproducible timezone behavior or life-safety topology shortcuts.

## 1. Authority simplification and contract precedence

Implementation MUST use the following precedence, highest first:

1. this third-pass hardening contract;
2. `code-level-hardening-amendments.md`;
3. machine-readable registries (`command-registry.json`, `process-registry.json`) for membership/key inventories that are not superseded here;
4. `engineering-primitives-contract.md`, `typed-process-api.md`, `persistence-schema-contract.md`, `qualification-contract.md`;
5. `process-contracts.md` formulas and process claim boundaries;
6. `code-level-runtime-contract.md`;
7. package P0–P9 prose.

A contradiction between two active normative artifacts is a **specification failure**, not a developer choice. P0 implementation entry requires a contract-consistency test that fails CI when a process code, required dimension, command operation, payload inventory or authority fingerprint disagrees across authoritative machine-readable projections.

Recommended generated artifact:

```text
docs/product/elv5-implementation/contract-manifest.json
```

Minimum fields:

```text
manifestSchema
processRegistrySha256
commandRegistrySha256
requirementsSha256
canonicalJsonVersion
schemaVersion
processCount
commandCount
requiredDimensionInventoryHash
```

Production source and P9 evidence record the exact manifest hash they implement.

## 2. Strongly typed identities — raw String is not an engineering identity

The typed API currently uses many raw `String` identifiers. Production code MUST prevent accidental substitution of a camera ID for a door ID, a source ID for a policy ID or a segment ID for a revision ID.

Use opaque value types at the domain/kernel boundary:

```dart
extension type ProjectId(String value) {}
extension type DesignRevisionId(String value) {}
extension type ComponentId(String value) {}
extension type CameraId(ComponentId value) {}
extension type DoorAssemblyId(String value) {}
extension type ControllerId(ComponentId value) {}
extension type CableId(String value) {}
extension type PortId(String value) {}
extension type SegmentId(String value) {}
extension type SequenceId(String value) {}
extension type PolicyEditionId(String value) {}
extension type EvaluationId(String value) {}
extension type DependencyKey(String value) {}
```

Equivalent sealed/value-object implementations are acceptable if equality and canonical encoding are identical.

Rules:

- ID wrappers validate only syntactic wire invariants; they MUST NOT lowercase, trim or infer semantics from IDs after decode;
- cross-kind conversion is explicit and code-owned;
- `Elv5SubjectRef.kind` becomes a closed `Elv5SubjectKind`, not arbitrary user text;
- `Elv5ScopeRef.scopeId` is a typed discriminated union matching `DESIGN`, `SEGMENT`, `SEQUENCE`;
- `scenarioKey=NONE` is represented by an explicit design-scope case, not a magic String inside kernel code;
- storage codecs may persist text, but repository adapters reconstruct the correct typed identity before a kernel is callable.

Required compile-time/static-analysis regressions must demonstrate that representative cross-kind substitutions do not compile or are rejected by an exhaustive typed decoder.

## 3. No semantic nullable values — model absence explicitly

A nullable engineering field MUST NOT simultaneously mean `not supplied`, `not applicable`, `unsupported`, `unknown`, `not resolved` or `deliberately omitted`.

Use an explicit closed resolution algebra at process boundaries:

```dart
sealed class Elv5ResolvedField<T> {
  const Elv5ResolvedField();
}

final class Elv5Known<T> extends Elv5ResolvedField<T> {
  final T value;
}

final class Elv5Missing<T> extends Elv5ResolvedField<T> {
  final String requiredFactCode;
}

final class Elv5NotApplicable<T> extends Elv5ResolvedField<T> {
  final String reasonCode;
}

final class Elv5Unsupported<T> extends Elv5ResolvedField<T> {
  final String modelCode;
}

final class Elv5Unresolved<T> extends Elv5ResolvedField<T> {
  final String findingCode;
}
```

`null` is permitted only in wire/storage fields whose schema explicitly defines one unambiguous semantic and whose adapter converts it to the closed domain form immediately.

Examples that MUST be hardened in production typed APIs:

- CCTV peak bitrate;
- optional wire-rate model/capacity;
- guaranteed interval;
- rack depth/weight comparison limit;
- optional reach profile;
- measurement field path;
- optional upstream evidence.

Verdict derivation consumes the explicit variant, not `x == null` conventions.

## 4. Exact arithmetic resource bounds and hostile-input safety

Exact rational arithmetic is required, but unbounded numerators/denominators and unbounded collection sizes can become a deterministic denial-of-service vector.

The strict codec layer MUST enforce code-owned limits before constructing expensive domain objects. Limits are product constants, versioned with the codec/algorithm, never silently inferred from device memory.

At minimum define and test limits for:

```text
max canonical JSON bytes per command
max UTF-8 bytes per identifier/code token
max decimal digits / rational numerator bits / denominator bits
max list/set/map members per nested object
max path edges per subscription/link
max schedule segments per recording root
max recurrence expansions per calculation horizon
max address claims per fire loop
max dependency edges per node and per batch
max calculation targets per public command
max geometry polygon vertices / transform-chain length
max finding/step count emitted per evaluation
```

Rejection occurs before mutation and returns a stable codec/validation code. The kernel must never catch `OutOfMemoryError` or timeout-like behavior as an engineering finding.

Exact arithmetic implementations MUST avoid accidental quadratic normalization in large folds. Aggregation uses deterministic balanced/batched reduction where necessary and canonical reduction boundaries are explicitly tested.

## 5. Quantity algebra is code-owned, not generic operator magic

`Elv5Quantity<D>` alone is insufficient if generic operators allow dimensionally meaningless arithmetic.

Production code MUST expose only legal operations through typed functions/value objects. Representative required signatures:

```dart
Voltage voltageDrop(Current i, Resistance r);
Power dcPower(Voltage v, Current i);
Energy integratePower(Power p, Duration t);
Elv5Rational bitsFor(BitRate rate, Duration t);
ByteCapacity ceilBytes(Elv5Rational bits);
LevelDbm subtractLoss(LevelDbm tx, LossDb loss);
LossDb addLoss(LossDb a, LossDb b);
```

Forbidden examples:

```text
dBm + dBm
A + W
bit/s + byte
ratio + voltage
absolute temperature multiplied by reserve unless a process explicitly defines such operation
```

If generic operators are implemented, their result dimensions must be encoded in closed code-owned overloads; `dynamic`/unchecked casts are prohibited inside engineering arithmetic.

## 6. Reproducible time requires captured zone rules, not only a tzdb label

A `tzdbVersion` string does not by itself guarantee future/offline reproducibility if that ruleset is no longer bundled by the runtime.

Any recurrence-expanded evaluation MUST capture one of:

1. an immutable application-owned timezone-rules artifact ref + SHA-256; or
2. the exact transition slice required for the evaluated horizon, canonicalized and hashed.

Normative input becomes conceptually:

```dart
final class Elv5TemporalRulesEvidence {
  final String timeZoneId;
  final String tzdbVersion;
  final String rulesArtifactHash;
  final List<Elv5UtcOffsetTransition> transitionsForHorizon;
}
```

The input fingerprint includes the exact rules evidence hash. Reopen/replay does not query the host OS for historical transitions when reproducing an immutable result.

P8 must prove identical output when the host timezone differs and when the runtime-bundled current tzdb differs from the captured fixture rules.

## 7. Measurement evidence: calibration, uncertainty and validity window

For `measured` and `commissionedMeasured` evidence, a scalar timestamp is insufficient for threshold-grade engineering use.

When a measured value affects PASS/FAIL, capture where applicable:

```text
measurement method code/version
instrument/evidence record reference
calibration reference/hash
measurement uncertainty interval or declared accuracy class
measurement timestamp
validity/retest policy ref
environmental conditions relevant to applicability
engineer/source provenance
```

A measured nominal without required uncertainty/calibration evidence cannot satisfy a process dimension whose selected policy requires a guaranteed measurement bound.

Conservative comparison uses the relevant uncertainty edge. Measurement age does not silently invalidate historical immutable results; it changes applicability for a new CURRENT evaluation according to the selected policy.

## 8. Deterministic requirement composition and conflict algebra

The phrase “strongest applicable requirement” is insufficient unless ordering is defined per dimension.

Each composable requirement dimension MUST register a merger strategy:

```dart
enum Elv5RequirementMergeKind {
  maximumLowerBound,
  minimumUpperBound,
  setIntersection,
  setUnion,
  exactAgreement,
  orderedSequenceComposition,
  nonComposable,
}
```

For every merged result store:

```text
participating policy refs/hashes
applicability proof per policy
merge kind
normalized operands
selected/derived effective requirement
conflict set, if any
```

Examples:

- minimum autonomy duration -> `maximumLowerBound`;
- maximum permitted load/loss/length -> `minimumUpperBound`;
- required supported modes -> policy-defined set rule;
- incompatible safety modes or mutually exclusive topology models -> `nonComposable`/explicit conflict;
- reserve multipliers MUST NOT be multiplied merely because two policies mention reserve. Their composition rule is code-owned and source-bound.

A conflict yields `UNRESOLVED/BLOCKED` for affected dimensions and never “pick stricter by intuition”.

## 9. Simultaneity, startup/inrush and temporal load envelopes

A single operating-case label is insufficient for pulse/inrush interactions across shared supplies.

Introduce a versioned temporal demand envelope for processes that assess peak/startup states:

```dart
final class Elv5DemandEvent {
  final String eventId;
  final Elv5OperatingCaseRef operatingCase;
  final Duration startOffset;
  final Duration duration;
  final Elv5EngineeringValue<Current> current;
  final String simultaneityGroup;
}

final class Elv5SimultaneityRule {
  final String ruleCode;
  final String version;
  final Set<String> mutuallyConcurrentGroups;
  final Set<String> mutuallyExclusiveGroups;
}
```

A source/output capacity verdict that depends on inrush/startup MUST evaluate the selected supported temporal model, not simply sum every peak forever or ignore coincident pulses.

This applies particularly to:

- ACS lock startup/release states;
- fire notification appliance inrush/active state;
- controller/module startup where the selected profile exposes it;
- any PWR wrapper that claims peak/source adequacy from ELV5 operating-case composition.

If the physical ELV4 kernel does not support the required transient model, ELV5 returns `UNSUPPORTED/BLOCKED`; it does not approximate it as steady-state PASS.

## 10. ACS-06 release truth table is part of the canonical process contract

The ACS-06 process contract MUST be interpreted as requiring, at minimum, explicit technical rows for:

```text
NORMAL_ACCESS
REQUEST_TO_EXIT
FIRE_RELEASE
EMERGENCY_BREAK_GLASS
POWER_FAILURE
```

For every applicable row the evaluator proves three separate facts:

1. expected lock outcome under selected `AcsLockSafetyMode`/project profile;
2. existence and type correctness of the required release/control/feed path;
3. required monitoring/supervision evidence where the selected technical profile calls for it.

`FAIL_SAFE`/`FAIL_SECURE` is not inferred solely from normal energized state. `POWER_FAILURE` is evaluated explicitly. A dry contact is a control relation, never a source.

A process may return technical PASS only for the captured project behavior. It still MUST NOT emit verified egress/fire-code compliance; ELV7 owns jurisdictional applicability.

## 11. Fire technical supervision and fault-state model

Fire signal topology closure alone is not sufficient to describe a technically supervised circuit/loop.

Where the selected manufacturer/project technical profile requires supervision, FA-06/FA-07 input must carry a registered fault-state model containing the applicable subset of:

```text
normal
openCircuit
shortCircuit
groundFault / earthFault where modeled
missingEndOfLine / invalidEol where modeled
isolatorOperated where modeled
returnPathLost where modeled
```

The model defines expected detectable state and supported topology behavior. No universal EOL resistance, isolator spacing or class/style rule is hardcoded in ELV5.

Required technical dimensions are extended conditionally:

```text
supervision-model-applicability
open-fault-detectability
short-fault-detectability
return/survivability-basis (only when a registered model supports it)
```

If the project/profile requests a supervision claim and the selected model/evidence is absent, the affected dimension is `UNRESOLVED/BLOCKED`, not PASS from continuity alone.

FA-07 signal-loop topology must never be reused as proof that FA-03 electrical power topology supports a mesh/dual feed.

## 12. Dependency graph and invalidation hardening

Dependency capture MUST be complete for positive and negative knowledge.

In addition to `FACT`, `SET`, `POLICY`, `EVAL`, `POINTER` and `MISSING`, production dependency keys need code-owned selectors for derived membership queries. A process that consumed “all assignments matching predicate X” must be invalidated when a newly inserted row begins to match X even if that row did not exist at capture time.

Use a deterministic selector/set marker such as:

```text
SET/<aggregate>/<owner>/<scope>/<selectorVersion>/<selectorKey>/<membershipHash>
```

Rules:

- selector semantics are versioned code, not raw SQL text;
- set marker includes complete ordered/unordered membership semantics;
- old/new mutation impact invalidates both direct identity keys and affected selector keys;
- reverse-index update and pointer publication remain atomic;
- dependency traversal uses iterative bounded algorithms; no unbounded recursive graph walk;
- registry validation rejects cycles before runtime; captured runtime cycles are treated as corruption and fail closed.

## 13. Coherent batch publication: bounded transaction contract

All-or-nothing publication remains mandatory for one requested coherent batch, but the implementation MUST bound it explicitly.

A public calculate command therefore validates `targetCount <= maxTargetsPerCommand`. Capture fixes a canonical sorted node-key list. Pure kernels may run concurrently, but publication:

1. sorts target keys deterministically;
2. revalidates shared dependencies once per unique dependency identity;
3. checks all target generations before first pointer mutation;
4. inserts immutable evaluations and replaces reverse-index edges in bounded SQL chunks that stay inside one SQLite transaction;
5. performs pointer CAS/update in deterministic key order;
6. commits once;
7. rolls back all mutable/current-state effects on any error.

Chunking MUST NOT split atomicity. SQL parameter-count limits are handled internally and tested with scale fixtures.

A larger workspace request must be decomposed into explicitly separate coherence groups before command creation; the server does not silently split one atomic command into independently committed subcommands.

## 14. Engineer review/override separation

An engineer may acknowledge, justify or accept a technical deviation, but review state MUST NOT rewrite the deterministic calculation result.

If review/waiver support is added, model it separately:

```text
evaluation/result = immutable engineering truth from captured inputs
review decision = separate signed/versioned project decision referencing evaluation/outputHash
```

A review record may change workflow presentation but cannot mutate `FAIL` into kernel `PASS`, cannot alter `outputHash`, and cannot be used as missing physical evidence.

ELV7 may later bind normative deviations/approvals; ELV8 may consume approved decisions for deliverables. ELV5 remains technically auditable.

## 15. Stable finding and step cardinality

A pathological design must not generate millions of duplicate findings.

Process contracts MUST define aggregation rules:

- one stable finding code may carry a bounded sample of offending identities plus total count;
- complete offending sets remain queryable through deterministic drill-down/projection where needed;
- calculation steps are semantic stages, not one row per arithmetic atom when that would exceed the configured bound;
- truncation itself is explicit (`detailsTruncated=true`, `totalAffectedCount`) and never changes PASS/FAIL semantics.

Finding ordering is deterministic: severity/kind/dimension/code plus canonical subject identity as declared by the process projection.

## 16. Cross-discipline engineering invariants

The following invariants are mandatory across all 27 processes:

1. **No false PASS from partial closure.** If the claim requires complete physical membership, missing members prevent PASS.
2. **No double reserve.** Demand uncertainty, policy reserve, device derating and redundancy are separate named transforms and each is applied at its declared boundary once.
3. **No hidden unit conversion.** Every conversion is typed, exact/bounded and visible in calculation steps.
4. **No label inference.** Human/product labels never determine electrical role, media compatibility, fire release, address consumption or compliance.
5. **No later-stage claim leakage.** ELV5 technical PASS is not ELV6 fit, ELV7 compliance or ELV8 SKU approval.
6. **No source narrowing.** Discipline wrappers cannot remove other loads from a shared physical source/bank/PSE to obtain a better margin.
7. **No stale success promotion.** Recalculation failure/conflict does not make an old stale PASS current.
8. **No mutable evidence aliasing.** A CURRENT evaluation points to immutable evidence hashes/versions; editing the underlying project creates invalidation/new evaluation, not retroactive history change.
9. **No hidden defaults.** Missing thresholds, durations, topology modes, timezone rules, reserve, redundancy or manufacturer limits remain explicit missing/unresolved unless an exact selected policy supplies them.
10. **No result-by-exception.** Expected engineering violation is a successful execution with FAIL assessment; execution failure is reserved for inability to evaluate.

## 17. Mandatory third-pass qualification additions

P8 must add executable tests for all findings in this amendment.

### L0 — primitives and codecs

- typed-ID cross-kind misuse tests;
- explicit field-resolution serialization/exhaustiveness;
- rational/decimal bit/digit/collection limits;
- dimension algebra legality tests;
- canonical rejection of over-limit hostile payloads;
- timezone reproduction from captured transition/rules evidence;
- measured uncertainty conservative comparison.

### L1 — process kernels

- deterministic requirement merger for every merge kind;
- policy conflict fixture with no arbitrary winner;
- startup/inrush simultaneity positive and unsupported cases;
- ACS-06 five-cause minimum truth-table matrix;
- FA supervision open/short fault cases when selected model applies;
- explicit unsupported result when transient/supervision model is outside kernel support.

### L2–L4 — command/persistence/UoW

- nullable wire field maps to one exact domain variant only;
- selector/set negative dependency invalidation on newly created matching member;
- maximum-size accepted command and one-over-limit deterministic rejection;
- atomic batch with SQL chunking under parameter limits;
- rollback after injected failure between immutable insert, reverse-index change and pointer update;
- reopen verifies captured timezone-rules and measurement evidence hashes.

### L5–L6 — vertical/concurrency

- stale prior PASS remains stale after failed/conflicted recalc;
- concurrent mutation creating a previously missing/selectable member prevents stale publication;
- batch target ordering does not affect output hashes;
- freeze wins against delayed publish even with chunked persistence;
- review/waiver record cannot alter immutable assessment/output hash if review functionality exists.

## 18. Implementation rule

No production process may be marked `IMPLEMENTED` merely because its arithmetic function exists. A process reaches implemented status only when:

```text
strict codec
+ typed resolver
+ typed kernel
+ deterministic evaluation
+ immutable persistence/current pointer
+ dependency capture/invalidation
+ restart/replay behavior
+ public-command vertical
+ negative/unsupported oracle
```

exist at the same tested source SHA.

## 19. Closure

This amendment is specification hardening only. Runtime remains `NOT_STARTED` until production Dart/Drift code and P8 evidence satisfy it.

The practical implementation objective is not “27 formulas that return numbers”. It is a deterministic engineering system in which every current conclusion can answer:

```text
what was calculated
for which exact physical subject/scope
under which operating case
from which immutable facts/policies/evidence
with which units/uncertainty/applicability
using which algorithm/numeric/time rules
which dimensions were proved, failed or unresolved
what invalidates the conclusion
and whether the same result survives replay/reopen on another host
```

Anything weaker is not ELV5 closure.