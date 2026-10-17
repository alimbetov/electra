# Engineering Foundation F1 — source-backed primitive inventory

Status: **IN PROGRESS / SOURCE AUDIT STARTED / ACCEPTANCE NOT CLAIMED**  
Branch: `feat/flutter-elv5-power-topology-design`

This inventory is derived from production source, not from historical `NOT_STARTED` labels. It records what can be reused, what was hardened during F1, and what remains a gate before pilot qualification.

## 1. Quantity and numeric primitives

Authoritative implementation coordinates:

- `packages/engineering_core/lib/src/elv5/numeric/rational.dart`
- `packages/engineering_core/lib/src/elv5/numeric/quantity.dart`
- `packages/engineering_core/lib/src/elv5/numeric/interval.dart`

### Reusable as foundation primitives

- exact normalized `Elv5Rational`;
- dimension-parameterized `Elv5Quantity<D>`;
- conservative closed `Elv5Interval<D>`;
- exact comparison before presentation rounding;
- dimensions for Length, Duration, Voltage, Current, Resistance, Power, Energy, DataRate, byte storage, Ratio, attenuation dB, optical level dBm and Mass.

### F1 reconciliation performed

The shared quantity inventory now also distinguishes:

- Area;
- CrossSectionArea;
- Temperature;
- ApparentPower;
- HeatPower;
- Charge;
- Frequency;
- StorageCapacity as the semantic byte-capacity alias.

`HeatPower` intentionally remains a distinct public marker from electrical active `Power`, despite both commonly using watts, so thermal and electrical public contracts cannot be substituted accidentally.

### Remaining numeric gaps

- canonical unit metadata/conversion is still process-owned rather than represented by one shared unit registry;
- the generic canonical JSON encoder accepts Dart `num`, including `double`; engineering public contracts must continue to reject floating verdict inputs at their typed boundaries. A source/CI audit for accidental engineering `double` ingress remains required;
- tolerance/quantization remains algorithm-specific and must be inventoried for the few calculations that genuinely require floating/transcendental math.

## 2. Evidence primitives

Existing source before reconciliation:

- `evidence/engineering_value.dart` models source basis (`manufacturerGuaranteed`, `measured`, `projectPolicy`, etc.), source reference and applicability;
- ampacity/environment contracts already carry immutable reference hashes and provenance.

### Gap found

Source basis is not the same concept as foundation evidence state. The required states were not represented by one shared primitive:

`VERIFIED | DECLARED | DERIVED | ASSUMED | UNKNOWN`.

### F1 reconciliation performed

Added `evidence/evidence_contract.dart` with:

- `Elv5EvidenceState`;
- `Elv5EvidenceSourceType`;
- stable evidence/source/edition/content-hash identity;
- applicability;
- optional captured/effective timestamps;
- unit code and non-percentage confidence basis;
- explicit assumption descriptor containing reason, scope, author/source and applicability;
- `ASSUMED` validation requiring assumption metadata;
- `maySatisfyVerifiedOnly == true` only for `VERIFIED`.

### Remaining evidence gap

Existing process-specific contracts have not yet all migrated to the shared descriptor. Migration must be incremental and evidence-preserving; the new primitive must not reinterpret historical evidence as `VERIFIED` by default.

## 3. Unknown / fail-closed policy

Current production application resolvers already use durable `Elv5CaptureBlockedException` in many mandatory-input gaps and several processes preserve `UNRESOLVED/NOT_ASSESSED` independently.

Status: **PARTIAL / AUDIT REQUIRED**.

First-pass critical-path review completed for ampacity reference/corrections, environment profile/route resolution and CCTV-03 storage/recurrence. No `UNKNOWN -> implicit engineering default -> PASS` path was found in those reviewed paths: temperature/grouping/material/installation evidence is mandatory; missing environment/section evidence blocks; CCTV-03 guaranteed-rate sizing does not fall back to expected bitrate; recurrence without a pinned expander blocks; reserve multiplier is explicit and validated.

Required remaining audit:

- search application/core for engineering `?? 0`, `?? 1`, implicit material/temperature/efficiency/reserve defaults;
- explicitly inspect efficiency/transfer loss, resistance/current rating, optical loss and battery inputs in addition to the already reviewed temperature/grouping/material/reserve paths;
- classify every hit as domain invariant, UI-only default, optional dimension, or false-PASS risk.

Any false-PASS risk preempts new vertical development.

## 4. Deterministic canonicalization

`Elv5CanonicalJsonV1` already provides:

- lexicographically sorted string map keys;
- canonicalized/sorted Set representation;
- stable Iterable order where order is domain-significant;
- UTC DateTime serialization;
- enum-name canonicalization;
- canonical SHA-256 helper.

Status: **IMPLEMENTED CORE / QUALIFICATION PARTIAL**.

Remaining qualification:

- explicit insertion-order metamorphic tests for shared evidence/result envelopes;
- repository-row-order and worker-order determinism on pilot paths;
- engineering-double ingress guard noted above.

## 5. Calculation identity

Current `Elv5ProcessEvaluationCandidate` content-addresses evaluation identity with:

- engineering node key;
- algorithm/input/output/numeric/canonical versions;
- input fingerprint;
- policy fingerprint;
- output hash;
- evidence hash.

This is a strong reusable base.

### F1-HIGH-01 — acceptance identity incomplete

Foundation acceptance additionally requires explicit:

- `processVersion`;
- `rulesetVersion`;
- exact `sourceSha`;
- `authorityFingerprint`.

These values are not currently first-class fields of `Elv5ProcessEvaluationCandidate` / persisted evaluation identity. Do not claim `QUALIFIED` or `ACCEPTED` until this is reconciled with runtime-version registry, authority manifest and persistence compatibility.

## 6. Result status axes

The current source keeps assessment and pointer freshness separate, but its execution/completion vocabulary does not yet match the foundation contract exactly.

Current source:

```text
Execution  = SUCCEEDED | BLOCKED | FAILED
Completion = COMPLETE | INCOMPLETE
Assessment = PASS | FAIL | UNRESOLVED | NOT_ASSESSED
Freshness  = CURRENT | STALE
```

Foundation target:

```text
Execution  = SUCCEEDED | FAILED
Completion = COMPLETE | PARTIAL | BLOCKED
Assessment = PASS | FAIL | UNRESOLVED | NOT_ASSESSED
Freshness  = CURRENT | STALE
```

### F1-HIGH-02 — result-axis vocabulary mismatch

`BLOCKED` is currently encoded as an execution state by multiple adapters, while the foundation explicitly treats a blocked engineering calculation as a completion state and permits `SUCCEEDED + BLOCKED + UNRESOLVED`. `INCOMPLETE` also conflates foundation `PARTIAL` and `BLOCKED` semantics.

This does not authorize a blind enum rename: existing adapters, persisted strings and replay semantics must be reconciled together. `QUALIFIED` promotion is blocked until migration/compatibility is defined and tests prove historical/current interpretation.

## 7. Provenance graph

Current reusable building blocks:

- immutable evidence hashes;
- dependency markers;
- upstream pointer generations;
- process evidence payload;
- canonical node/evaluation identities.

Status: **PARTIAL**.

Missing shared capability: a minimal typed provenance relation vocabulary/envelope capable of answering source fact → evidence → derived input → algorithm/scenario → result/finding without embedding whole source objects. Existing process dependency markers should be reconciled rather than replaced.

## 8. Governing result

Many kernels already publish process-specific governing case/section/dimension and deterministic tie rules.

Status: **PARTIAL / PROCESS-SPECIFIC**.

F1 must extract only the minimal common metadata shape needed by qualification and trace. It must not force physically incomparable margins into one generic numeric ranking.

## 9. Shared qualification support

Status: **TODO**.

Minimum reusable test-only support still required:

- reference-vector fixture envelope;
- independent-oracle assertion helper;
- below/exact/above boundary triplets;
- deterministic property/metamorphic generators;
- provenance assertions;
- replay/determinism assertions.

No production dependency on a test framework is allowed.

## 10. Current F1 disposition

| Work item | Status |
|---|---|
| Quantity inventory | IMPLEMENTED / qualification pending |
| Typed evidence primitive | IMPLEMENTED / process migration pending |
| Unknown/default audit | PARTIAL / critical-path first pass clean |
| Canonicalization | IMPLEMENTED CORE / qualification pending |
| Result axes | PARTIAL — F1-HIGH-02 open |
| Calculation identity | PARTIAL — F1-HIGH-01 open |
| Provenance graph | PARTIAL |
| Governing metadata | PARTIAL process-specific |
| Shared qualification support | TODO |

F1 exit gate is **not satisfied**. This inventory is evidence for reconciliation work, not a qualification claim.
