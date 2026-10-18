# ELV5 — Engineering primitives, provenance and canonical evidence contract

Status: DESIGN DRAFT / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`  
Authority: [ELV5 design](../elv5-discipline-calculations-design-specification.md), [code-level runtime contract](code-level-runtime-contract.md), [27 process contracts](process-contracts.md).

This contract defines the code-level primitives used by every ELV5 process. It exists to prevent a class of engineering defects that cannot be solved by formula correctness alone: dimension mix-ups, hidden unit conversion, nominal values used as guaranteed limits, non-reproducible time expansion, ambiguous operating cases and unstable evidence hashes.

The names below are normative semantic names. File boundaries may differ, but production code must preserve the same type separation and serialization rules.

## 1. Engineering scalar rule

Persisted/process inputs MUST NOT use untyped `num`, `double`, `dynamic` or free-form strings as engineering quantities. UI adapters may parse text, but a process kernel receives dimension-safe exact values.

```dart
sealed class Elv5Dimension {
  const Elv5Dimension();
}

final class LengthDim extends Elv5Dimension { const LengthDim(); }
final class DurationDim extends Elv5Dimension { const DurationDim(); }
final class VoltageDim extends Elv5Dimension { const VoltageDim(); }
final class CurrentDim extends Elv5Dimension { const CurrentDim(); }
final class ResistanceDim extends Elv5Dimension { const ResistanceDim(); }
final class PowerDim extends Elv5Dimension { const PowerDim(); }
final class EnergyDim extends Elv5Dimension { const EnergyDim(); }
final class BitRateDim extends Elv5Dimension { const BitRateDim(); }
final class ByteCapacityDim extends Elv5Dimension { const ByteCapacityDim(); }
final class RatioDim extends Elv5Dimension { const RatioDim(); }
final class AttenuationDbDim extends Elv5Dimension { const AttenuationDbDim(); }
final class OpticalLevelDbmDim extends Elv5Dimension { const OpticalLevelDbmDim(); }
final class AngleRadDim extends Elv5Dimension { const AngleRadDim(); }
final class TemperatureDim extends Elv5Dimension { const TemperatureDim(); }
final class CountDim extends Elv5Dimension { const CountDim(); }

final class Elv5Quantity<D extends Elv5Dimension> {
  const Elv5Quantity(this.value);
  final Elv5Rational value;
}
```

Canonical storage units are:

| Dimension | Canonical unit | Rule |
|---|---|---|
| length | metre | millimetres/kilometres convert exactly before kernel |
| duration | second | no floating milliseconds |
| voltage | volt | signed only where a process explicitly permits it |
| current | ampere | nonnegative physical demand/capacity |
| resistance | ohm | nonnegative |
| power | watt | nonnegative physical demand/capacity |
| energy | joule | Wh is exact `* 3600` conversion |
| bitrate | bit/second | bytes/s must be explicitly converted |
| storage | byte | bit→byte division remains rational until process-defined ceil |
| ratio | dimensionless rational | reserve/derating/fractions are not percentages in kernels |
| attenuation | dB | nonnegative physical loss unless a specific gain term type exists |
| optical level | dBm | signed; MUST NOT be represented by the dB type |
| angle | radian | degree conversion is presentation-only unless exact rational degrees are an input codec |
| temperature | kelvin or exact °C offset codec | one canonical internal representation per backend version |
| count | integer | `BigInt`/bounded integer, never rounded from arbitrary decimal |

Compile-time wrappers SHOULD prevent `dBm + dBm`, `W + A`, `bit/s + byte/s` and similar illegal arithmetic. Where Dart generic typing is insufficient, process-local value objects and exhaustive unit tests are mandatory.

## 2. Exact decimal and rational canonical form

`Elv5Decimal` and `Elv5Rational` from the runtime contract are extended by canonical normalization rules.

```dart
final class Elv5Decimal {
  final BigInt unscaled;
  final int scale; // >= 0
}

final class Elv5Rational {
  final BigInt numerator;
  final BigInt denominator; // > 0
}
```

Canonical invariants:

1. Rational denominator is always positive.
2. `gcd(abs(numerator), denominator) == 1`.
3. zero is exactly `0/1`.
4. Decimal input forbids exponent notation unless the codec version explicitly supports and canonicalizes it.
5. Decimal `1.2300` normalizes to one agreed representation before hashing; persisted source text may be retained separately for display/audit.
6. NaN, infinity and IEEE negative zero never cross the engineering boundary.
7. UI formatting never participates in engineering equality or hashing.

## 3. Engineering value basis and uncertainty

A scalar value without its engineering basis is incomplete evidence.

```dart
enum Elv5EvidenceBasis {
  manufacturerGuaranteed,
  manufacturerTypical,
  measured,
  commissionedMeasured,
  projectSpecified,
  derivedExact,
  derivedBounded,
  estimated,
  fictionalFixture,
}

final class Elv5EngineeringValue<Q> {
  final Q nominal;
  final Elv5Interval<Q>? guaranteedInterval;
  final Elv5EvidenceBasis basis;
  final Elv5SourceRef source;
  final Elv5Applicability applicability;
  final String valueFingerprint;
}
```

Rules:

- `manufacturerTypical` and `estimated` MUST NOT satisfy a process dimension that explicitly requires a guaranteed bound.
- if a threshold is checked against an interval, the verdict uses the contract-defined conservative edge, never the midpoint;
- uncertainty is distinct from design reserve. Adding reserve does not turn an unguaranteed value into a guaranteed one;
- an interval may be exact (`min == max`);
- measured evidence includes method/reference and timestamp; a policy may reject stale commissioning measurements without deleting them;
- fictional fixtures may qualify arithmetic and code paths only; they never create a real-world compliance or performance claim.

## 4. Source and provenance model

Every value that can affect a verdict carries a traceable source.

```dart
enum Elv5SourceKind {
  catalogEdition,
  projectFact,
  physicalRoute,
  elv4Evaluation,
  policyEdition,
  engineerInput,
  measuredRecord,
  derivedEvaluation,
  fixture,
}

final class Elv5SourceRef {
  final Elv5SourceKind kind;
  final String owner;
  final String sourceId;
  final String sourceVersion;
  final String contentHash;
  final String? fieldPath;
}

final class Elv5ConsumedEvidenceRef {
  final Elv5SourceRef source;
  final String semanticRole;
  final String dependencyKey;
  final String capturedFingerprint;
}
```

`fieldPath` identifies the exact consumed parameter when one immutable source contains several values. Process steps and findings SHOULD reference the consumed evidence IDs that caused them.

## 5. Applicability and environmental envelope

Catalog/policy values are valid only inside their declared applicability.

```dart
final class Elv5EnvironmentEnvelope {
  final Elv5Interval<Elv5Quantity<TemperatureDim>>? ambientTemperature;
  final String? installationEnvironmentCode;
  final String? altitudeBandCode;
  final String? enclosureEnvironmentCode;
  final Map<String, String> exactTags;
}

final class Elv5Applicability {
  final Set<String> supportedMedia;
  final Set<String> supportedModes;
  final Elv5EnvironmentEnvelope? environment;
  final String applicabilityVersion;
}
```

If a process needs temperature/medium/mode-dependent data and the captured operating envelope is outside or not provably inside the source applicability, the affected dimension is `BLOCKED` or `UNRESOLVED` according to the process contract. A default room-temperature value is never silently substituted.

ELV5 does not invent environmental derating already owned by ELV4. When power evidence is consumed, the exact ELV4 derating/evidence identity is referenced.

## 6. Operating cases and simultaneity

Engineering results must identify the operating case that produced them.

```dart
enum Elv5OperatingCaseKind {
  normal,
  expected,
  peak,
  startup,
  standby,
  alarm,
  emergencyRelease,
  backup,
  maintenance,
  customProjectCase,
}

final class Elv5OperatingCaseRef {
  final String caseId;
  final Elv5OperatingCaseKind kind;
  final String editionId;
  final String contentHash;
}

final class Elv5StateSelection {
  final String subjectId;
  final String stateCode;
  final Elv5OperatingCaseRef operatingCase;
}
```

A process MUST NOT combine values from different operating cases unless a code-owned composition rule explicitly says so. Examples:

- CCTV expected storage bitrate and peak network bitrate remain separate dimensions;
- lock holding/startup states are not arithmetically merged without the selected simultaneity rule;
- fire standby and alarm durations are an ordered sequence, not one anonymous average current;
- global shared-source wrappers consume the same physical ELV4 scenario/segment evidence for every discipline contribution shown in that result.

## 7. Deterministic time contract

Any process that expands schedules/recurrences uses a captured temporal policy.

```dart
enum Elv5DstGapRule { reject, shiftForwardByGap }
enum Elv5DstOverlapRule { firstOccurrence, secondOccurrence, both, reject }

final class Elv5TemporalPolicy {
  final String timeZoneId;       // IANA name, e.g. Asia/Almaty
  final String tzdbVersion;      // exact rules version
  final Elv5DstGapRule gapRule;
  final Elv5DstOverlapRule overlapRule;
}

final class Elv5UtcWindow {
  final DateTime startUtc; // inclusive
  final DateTime endUtc;   // exclusive
}
```

Rules:

1. Engineering intervals are half-open `[start, end)`.
2. Persisted recurrence intent includes local rule + exact `Elv5TemporalPolicy`.
3. Expansion produces UTC intervals and records the tzdb version in consumed evidence.
4. DST gaps/overlaps never use host-platform defaults.
5. Overlaps are unioned only after expansion and identity validation.
6. `endUtc <= startUtc` is invalid.
7. Retention horizon and recurrence expansion are separate concepts; retention duration is never multiplied twice.
8. Kernel tests MUST include a DST transition fixture even when the primary deployment timezone currently has no DST, because reproducibility is a product property.

## 8. Coordinate-frame contract

Geometry inputs use explicit frame identity and handedness.

```dart
enum Elv5Handedness { rightHanded }

enum Elv5AxisConvention { xEastYNorthZUp, projectLocal }

final class Elv5FrameRef {
  final String frameId;
  final Elv5Handedness handedness;
  final Elv5AxisConvention axisConvention;
  final String transformChainHash;
}

final class Elv5Point3 {
  final Elv5Quantity<LengthDim> x;
  final Elv5Quantity<LengthDim> y;
  final Elv5Quantity<LengthDim> z;
  final Elv5FrameRef frame;
}
```

CCTV geometry rejects mixed frames unless an exact captured transform chain is supplied. Matrix validity checks include finite exact/bounded coefficients, orthogonality tolerance/back-end contract and determinant/handedness rule. A camera pose fingerprint includes the transform-chain fingerprint.

## 9. Canonical serialization and hashing

All replay, input, policy, output and evidence hashes use one canonical byte representation. `jsonEncode(map)` output is not a hashing contract.

Canonical format code: `electra.canonical-json.v1`.

Rules:

1. UTF-8 encoding without BOM.
2. Object keys sorted by Unicode scalar value after NFC normalization.
3. Duplicate keys rejected before canonicalization.
4. Strings normalized to NFC; control characters use JSON escapes.
5. Engineering numbers serialize as canonical tagged strings/objects, never host `double` formatting.
6. Rational is `{"n":"<canonical integer>","d":"<positive canonical integer>"}`.
7. Decimal is `{"unscaled":"<integer>","scale":<nonnegative int>}` after canonical decimal normalization.
8. Sets are sorted by their member canonical bytes; ordered engineering sequences preserve order.
9. Maps whose semantics are identity maps sort by canonical key; no DB row order leaks into hashes.
10. UTC timestamps use canonical RFC3339 UTC with fixed microsecond policy selected by schema; local times never enter hashes without zone policy.
11. Unknown fields are rejected at the schema boundary; they are not silently omitted from a hash.
12. Hash algorithm for v1 is SHA-256 over canonical bytes.

```dart
abstract interface class Elv5CanonicalEncoder {
  String get version; // electra.canonical-json.v1
  Uint8List encode(Object value);
  String sha256(Object value);
}
```

## 10. Hash projections

Each hash has a fixed projection. Volatile runtime metadata must not destroy reproducibility.

### 10.1 Request hash

Includes complete decoded public command semantics:

```text
schema, operation, payloadSchemaVersion,
projectId, designRevisionId, commandId,
expectedDesignRowRevision, expectedRows,
reviewedImpactFingerprint, payload
```

`commandId` is included because replay identity is command-specific. Two differently encoded JSON texts that decode to the same strict semantic command produce the same normalized request hash.

### 10.2 Input fingerprint

Includes only engineering semantics captured for the node:

```text
nodeKey,
process algorithm/input schema/numeric backend versions,
exact scope and subject,
operating case,
policy refs + hashes,
canonical fact values + versions,
set membership markers,
upstream immutable evidence refs + hashes,
missing-identity markers,
temporal/environment/frame policies when applicable
```

It excludes capture wall-clock time, DB query order, evaluationId and UI state.

### 10.3 Output hash

Includes deterministic engineering output:

```text
nodeKey,
algorithm/input/output/numeric versions,
inputFingerprint,
policyFingerprint,
execution/completion/assessment,
dimensions,
steps,
findings,
consumed evidence identities + hashes
```

It excludes `evaluationId`, `completedAtUtc`, command ledger timestamps and row insertion order. Therefore two executions of the same deterministic input can have different immutable record IDs but MUST have the same output hash.

### 10.4 Snapshot discipline hash

The discipline snapshot hash includes canonical frozen mutable ELV5 roots/children, policy references, selected evaluation references/output hashes and manifest version. It excludes non-semantic storage row order.

## 11. Finding model

```dart
enum Elv5FindingSeverity { info, warning, error, blocker }

enum Elv5FindingKind {
  thresholdViolation,
  missingInput,
  unsupportedModel,
  applicabilityMismatch,
  evidenceNotGuaranteed,
  conflictingPolicy,
  duplicateAssignment,
  capacityExceeded,
  topologyViolation,
  staleEvidence,
  claimScopeLimit,
}

final class Elv5Finding {
  final String code;
  final Elv5FindingSeverity severity;
  final Elv5FindingKind kind;
  final String dimensionCode;
  final List<Elv5SourceRef> evidence;
  final Map<String, Object?> parameters;
}
```

User-facing prose is rendered from stable finding code + parameters. Business logic MUST NOT parse localized text.

## 12. Comparison semantics

A threshold comparison records both operands and the comparison basis.

```dart
enum Elv5ComparisonOperator { lt, lte, gt, gte, equal, contains }

enum Elv5BoundUse { nominal, lowerBound, upperBound, fullInterval }

final class Elv5Comparison<Q> {
  final Q actual;
  final Q required;
  final Elv5ComparisonOperator op;
  final Elv5BoundUse actualBoundUse;
  final Elv5BoundUse requiredBoundUse;
}
```

A PASS is prohibited if the contract requires a guaranteed upper/lower bound but the evidence basis supplies only a typical/estimated nominal. In that case the affected dimension is `UNRESOLVED` or `NOT_ASSESSED` as defined by the process.

## 13. Identity normalization

Project/revision/entity IDs are opaque case-sensitive identifiers. Engineering code MUST NOT trim, lowercase, Unicode-normalize or parse semantic meaning from IDs after the strict wire codec has accepted them. Human labels are not identities.

`processCode`, `dimensionCode`, `finding.code`, policy codes and schema codes are code-owned ASCII tokens and validated against closed registries.

## 14. Deterministic kernel contract

For identical canonical input and implementation versions a pure process kernel MUST produce byte-identical canonical output projection.

Prohibited kernel inputs include:

- current wall-clock time;
- random number generation;
- locale;
- host timezone;
- unordered iteration whose order is later serialized;
- implicit latest catalog/policy lookup;
- mutable UI selection;
- database-generated IDs used as arithmetic inputs.

Time/evaluation IDs are attached after pure evaluation and are excluded from the engineering output hash.

## 15. Required primitive-level tests

Before any of the 27 process verticals can claim runtime readiness, tests MUST prove:

1. `dB` and `dBm` cannot be interchanged by a legal typed process call.
2. bit/s and byte capacity conversion is exact and process-defined ceil occurs only at the declared boundary.
3. decimal/rational normalization is stable (`0/7 -> 0/1`, `2/4 -> 1/2`).
4. nominal-only evidence cannot satisfy a guaranteed-bound requirement.
5. reserve does not convert `estimated` evidence into `manufacturerGuaranteed` evidence.
6. identical semantic maps with different insertion order produce the same canonical hash.
7. equivalent normalized decimal input encodings produce the same engineering hash where the codec version declares them equivalent.
8. output hash is unchanged when only `evaluationId`/`completedAtUtc` changes.
9. changing any consumed set marker/policy hash/upstream output hash changes the input fingerprint.
10. missing dependency identity participates in fingerprint and later creation invalidates it.
11. DST gap/overlap recurrence expansion follows the pinned policy, not host defaults.
12. mixed coordinate frames fail closed without a captured transform.
13. stable finding codes do not depend on localized UI text.
14. set ordering does not alter hashes; ordered path/sequence ordering does alter hashes.
15. all 27 process definitions declare which engineering value bases are sufficient for each required dimension.

## 16. Implementation boundary

Recommended placement:

```text
packages/engineering_core/lib/src/elv5/
  numeric/
    decimal.dart
    rational.dart
    quantity.dart
    interval.dart
  evidence/
    source_ref.dart
    engineering_value.dart
    applicability.dart
    operating_case.dart
  canonical/
    canonical_json_v1.dart
    fingerprints.dart
  time/
    temporal_policy.dart
  geometry/
    frame_ref.dart
```

The exact package layout may differ, but these primitives are shared process infrastructure. No discipline package may create a private competing numeric, hashing, provenance or temporal convention.

## 17. Closure rule

This contract is specification evidence only. It is satisfied at runtime only when production types/codecs use these semantics and P8 executes the primitive-level regressions together with all 27 process oracles on the same accepted SHA.
