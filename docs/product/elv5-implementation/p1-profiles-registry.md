# P1 — Typed discipline profiles and process registry

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P0 ownership/scope map.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [code-level runtime contract](code-level-runtime-contract.md); [engineering primitives](engineering-primitives-contract.md); [typed process API](typed-process-api.md); [unified calculation engine](calculation-engine-contract.md); [algorithm registry](algorithm-registry.json); [27-process code-level specification](process-code-level-specification.md); [Flutter performance contract](flutter-performance-contract.md).

Inherited implementation and mandatory new extensions: [baseline contract P1](implemented-baseline.md#p1); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P1-001 | Register exactly 27 stable discipline process codes and exactly 27 algorithm mappings with algorithm/input/output/numeric versions | P1-T01 |
| ELV5-P1-002 | Define typed immutable policy editions with exact applicability, units, source/evidence basis and hashes | P1-T02 |
| ELV5-P1-003 | Define DESIGN/SEGMENT/SEQUENCE key and process input/output scope + operating-case compatibility | P1-T03 |
| ELV5-P1-004 | Model stream/subscription/recording, link/port, door/channel and fire/address assignments without duplicate canonical identities | P1-T04 |
| ELV5-P1-005 | Implement dimension-safe exact quantities, signed coordinate/dBm rules and versioned bounded geometry | P1-T05 |
| ELV5-P1-006 | Define shared-source requirement composition without repeated reserves/losses or reduced membership totals | P1-T06 |
| ELV5-P1-007 | Implement canonical serialization/hash primitives and strict 16-operation wire registry/examples | P1-T07 |
| ELV5-P1-008 | Implement common solver protocol: applicability, operating cases, conservative comparison, margin, governing/limiting factor, deterministic trace and status derivation | P1-T08 |

## Concrete contract

The machine-readable process registry is the design source for process membership, modes and planned oracles. [algorithm-registry.json](algorithm-registry.json) is the corresponding machine source for common solver-family mapping, operating-case inventory, governing rule, margin convention and limiting-factor semantics. Runtime registries are compiled/code-owned, not arbitrary expressions imported from profiles. Policy definitions are data, versioned and validated before adoption. Imported executable formula/script content is not supported.

The runtime implementation MUST expose one closed `Elv5ProcessRegistry` containing exactly CCTV-01…06, LAN-01…07, ACS-01…06 and FA-01…08 and one closed calculation-engine registry mapping the same 27 process codes exactly once. Each definition pins `algorithmVersion`, `inputSchemaVersion`, `outputSchemaVersion`, `numericBackendVersion`, required dimension codes, discipline, legal scope kinds, typed upstream bindings, legal solver family and pure workload metadata. Startup/test construction fails on missing/duplicate code, missing algorithm mapping, unknown solver family, unknown upstream process, unknown binder, invalid scope compatibility or cycle.

The four process-dossier files are now mandatory implementation input. For every runtime definition, its physical meaning, applicability, exact typed inputs, evidence, operating cases, mathematical model, equations, exact/bounded arithmetic, worst-case, requirement composition, comparisons, margins, governing/limiting logic, missing behavior, dependencies, trace, complexity, pseudocode/API intent and five vector classes MUST agree with the matching 25-section dossier. A developer may refactor code shape but may not reinterpret those semantics.

`Elv5EngineeringNodeKeyV3` is owner-isolated from `PowerNodeKeyV2` and serializes `[engineering-node-v3, ELV5, revision, scenarioKey, scopeKind, scopeId, processCode, subjectKind, subjectId]`. DESIGN uses scenarioKey `NONE`; SEGMENT/SEQUENCE require actual scenario context when registered. UI scenario selection never silently rewrites calculation identity.

Freshness, completion, assessment and execution are separate types. `CURRENT` is pointer freshness, not a verdict. A completed technical violation is SUCCEEDED/COMPLETE/FAIL; missing model/input may be BLOCKED/UNRESOLVED; ELV6/7/8-owned dimensions remain explicitly NOT_ASSESSED where the process contract says so.

## Unified calculation-engine runtime obligation

Every process definition participates in the common lifecycle from [calculation-engine-contract.md](calculation-engine-contract.md):

```text
CAPTURE
RESOLVE_APPLICABILITY
RESOLVE_INPUTS
NORMALIZE_ENGINEERING_STATE
BUILD_OPERATING_CASES
RUN_PROCESS_KERNEL
COMPOSE_REQUIREMENTS
CONSERVATIVE_COMPARE
DERIVE_MARGINS_AND_GOVERNING_CASE
DERIVE_DIMENSION_STATUSES
BUILD_CALCULATION_TRACE
BUILD_FINDINGS_AND_RECOMMENDATIONS
GUARDED_PUBLISH
```

P1 owns the reusable types/contracts for this lifecycle; P3–P6 provide discipline-specific kernels. A process may have a trivial stage, but it may not invent a different verdict/margin convention.

At minimum P1 provides equivalents of:

- `Elv5ModelApplicability`;
- typed operating-case result;
- `Elv5EngineeringComparison<Q>`;
- signed margin with **positive = acceptable headroom** convention;
- `Elv5LimitingFactor` and governing-case projection;
- `Elv5CalculationStep` with stable code-owned equation code and typed operands;
- shared `Elv5CalculationResult<O>` envelope plus strongly typed process output `O`;
- centralized verdict derivation from required dimension statuses;
- non-authoritative sensitivity/what-if result type that cannot publish CURRENT without committed input mutation.

### Dimension-safe engineering primitives

P1 MUST implement shared primitives equivalent to the [engineering primitives contract](engineering-primitives-contract.md):

- exact normalized `Elv5Decimal` / `Elv5Rational`;
- `Elv5Quantity<D>` or equivalent code-owned dimension-safe wrappers;
- distinct dB attenuation and dBm optical-level types;
- conservative exact/bounded intervals;
- evidence basis (`manufacturerGuaranteed`, `manufacturerTypical`, `measured`, `estimated`, fixture, etc.);
- applicability/environment envelope;
- `Elv5OperatingCaseRef` and state selection;
- deterministic temporal policy with IANA zone + captured rules evidence + DST policy;
- explicit coordinate-frame/transform identity;
- stable finding/comparison model;
- canonical encoder `electra.canonical-json.v1`.

A plain exact number does not satisfy P1 if its engineering dimension/evidence basis can be confused with another quantity.

### Pure workload metadata

P1 MUST expose code-owned pure metadata sufficient for the application layer to schedule kernels without importing Flutter into `engineering_core`:

```dart
enum Elv5WorkloadClass { tiny, small, medium, large }

final class Elv5ProcessWorkloadProfile {
  final Elv5WorkloadClass baseClass;
  final String complexityCode;
  final Elv5ResourceLimitProfile resourceLimits;
}
```

The runtime may refine workload class from captured cardinalities using code-owned thresholds, but project payloads cannot request “run inline” or select a worker count. Scheduling remains application responsibility under [flutter-performance-contract.md](flutter-performance-contract.md).

The complexity code/profile for each process MUST agree with its section 18 dossier contract and the 27-process performance matrix. A process implementation that accidentally becomes O(N²) where its dossier requires keyed O(N) behavior is a defect even if small unit tests pass.

### Canonical hashes

P1-T07 includes exact canonical projections for:

```text
command request hash
process input fingerprint
process deterministic output hash
frozen discipline snapshot hash
```

Raw JSON textual ordering is not a hash contract. Unordered map/set order must not affect the hash; path/sequence order must. `evaluationId` and `completedAtUtc` are excluded from deterministic output hash while all engineering dimensions/findings/provenance remain included.

### Typed process surface

The generic interface shape alone is insufficient. P1 MUST provide process-specific input/output types equivalent to [typed-process-api.md](typed-process-api.md) and each process dossier’s section 20 for all 27 codes.

Dynamic maps are limited to strict codec/storage/projection boundaries and may not flow through calculation kernels as semantic property bags.

At minimum P1 proves:

- all 27 typed definitions are registered exactly once;
- all 27 algorithm mappings are registered exactly once and match process-registry membership;
- all 27 process definitions have one matching 25-section dossier and workload/complexity profile;
- process registry legal scope and required dimensions match definition metadata;
- every multi-case process can expose a governing case or an explicit reason why none is defined;
- every capacity/threshold process uses the common signed margin convention when operands are resolved;
- every required engineering value declares acceptable evidence basis;
- every output field affecting assessment participates in deterministic output hashing;
- every trace step uses code-owned equation code/version and stable operand refs;
- generic executable formula/expression fields are absent.

### Shared physical evidence rule

DESIGN consumers of power evidence, such as CCTV-06, declare the complete required scenario/segment applicability set in their policy and consume those exact evidence refs. They do not use whichever UI scenario happens to be selected. Source-owned requirement sets consider every participating discipline using registered merger semantics. Discipline wrappers expose contribution from the same immutable ELV4 evidence; they do not run a reduced physical calculation.

### Mandatory codec examples before implementation entry

P1-T07 is not satisfied by naming the schema. The specification/fixture set includes one canonical valid JSON payload and at least one rejection mutation for each of the 16 registered operations. The three hardened payloads for camera streams/subscriptions, recording time/reserve/redundancy and ACS release truth table are governed by [code-level hardening amendments](code-level-hardening-amendments.md) and the machine registry.

## Exit

P1 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

P1 implementation entry is blocked until:

1. 27 process registry rows, 27 typed definitions and 27 algorithm mappings are mutually consistent;
2. all 27 process dossiers pass the exact 25-section CI guard and runtime definition tests prove dossier/registry parity;
3. primitives/canonical-hash contracts are frozen and have L0 tests;
4. exact 16-operation registry/examples are mutually consistent;
5. common applicability/comparison/margin/governing/limiting/trace/verdict contracts are code-owned rather than reimplemented inconsistently per discipline;
6. process workload/complexity/resource metadata is code-owned and independent of Flutter/project payload control;
7. no dimension/evidence/time/frame behavior depends on locale, host timezone, map iteration order or UI formatting.

## Audit refinements

Initial audit resolutions remain mandatory: exact pool/copy/sizing/channel basis types; integer-capacity rounding separate from UI formatting; signed optical physical-loss interval separate from design reserve; full expanded fire address sets; gross/net rack capacity tag; typed acyclic dependencies.

Second/third-pass hardening remains authoritative for type-safe identities/dimensions, explicit field resolution, evidence/applicability, deterministic timezone/frame behavior, bounded arithmetic, requirement merging and transient models. The unified engine adds the shared engineering behavior expected of all 27 implementations. The fourth pass adds implementation-complete per-process dossiers and workload/complexity metadata; it does not add a new public process or command.