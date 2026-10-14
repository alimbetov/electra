# ELV2 Profile Constraints — Pre-P1 Technical Audit

Date: 2026-10-13  
Branch: `feat/flutter-elv2-profile-constraints`  
PR: #7  
Purpose: establish the exact remediation gate before `ELV2-P1` embeds `EngineeringProfileConstraints` into `ComponentEngineeringProfile`.

## Executive resolution

The branch has the correct architectural direction but is **not ready for a mechanical P1 embedding**. The typed constraint layer is useful, the revision-diff direction is sound, and immutable catalog/binding persistence from the previous ELV2 slice is a strong base. However, the constraint contract currently has several weaknesses that would become long-lived compatibility liabilities if serialized into immutable catalog editions unchanged.

Decision: **P1 may proceed only as a contract-hardening + embedding slice**, not as a one-field model change.

## Audit findings

### A0 — CI baseline is red — BLOCKER

Exact head `8761fb319192216a2d4b00becd3116784a822eea` fails GitHub Actions at `Verify mobile formatting`.

Unformatted files:
- `apps/mobile/lib/application/engineering_reference_revision_preview.dart`
- `apps/mobile/test/application/engineering_reference_revision_preview_test.dart`

Because formatting fails first, mobile analysis/tests and all engineering-core format/analyze/test steps are skipped. P1 must start by restoring a green baseline or include formatting as the first commit and immediately rerun the full gate.

### A1 — Legacy constraints state is missing — BLOCKER

The technical specification requires old ELV2 snapshots that have no `constraints` field to remain readable without being interpreted as a newly authored unrestricted profile. The current `EngineeringProfileConstraints` contract requires mounting/environment/topology and has no explicit legacy/unspecified state.

Required P1 correction:
- introduce an explicit typed state such as `ProfileConstraintsState.defined` / `legacyUnspecified`, or an equivalent sealed representation;
- old JSON without `constraints` decodes to `legacyUnspecified`;
- new catalog imports reject `legacyUnspecified` for newly authored active canonical profiles;
- old bindings/catalogs remain readable and deterministic.

### A2 — `discipline` is duplicated inside constraints — HIGH

`ComponentEngineeringProfile.discipline` is already derived from `DisciplineCharacteristics`. `EngineeringProfileConstraints` currently stores another independent `discipline` field. After embedding, those two values can diverge unless every constructor/decoder validates the cross-field invariant.

The technical specification's target `EngineeringProfileConstraints` structure contains mounting/environment/topology only.

Preferred correction:
- remove `discipline` from `EngineeringProfileConstraints` and treat the owning profile as authoritative;
- if retained for wire compatibility, validate exact equality and do not expose it as a second source of truth.

### A3 — Mounting contract cannot express valid surface/method combinations — HIGH

The current model stores independent `allowedSurfaces[]` and `allowedMethods[]`. This creates a Cartesian interpretation. Example: if wall+ceiling and surface+suspended are allowed, the model cannot express `wall+surface` and `ceiling+suspended` while forbidding `wall+suspended`.

The technical specification explicitly requires incompatible surface/method combinations to be representable without parsing labels.

Required P1 correction: add an explicit typed compatibility form, for example:

```text
MountingOption
- surface
- method
```

with unique `(surface, method)` pairs, while optionally retaining derived surface/method sets for UI filtering.

### A4 — Environment model mixes orthogonal dimensions into one enum set — HIGH

`EnvironmentClass` currently combines concepts such as `indoor/outdoor`, `damp/dusty/corrosive`, and `conditioned/unconditioned` in one list. These are not mutually exclusive alternatives; a room may be indoor + damp + unconditioned.

If `allowedClasses[]` is later interpreted as OR semantics, valid combinations become ambiguous. If interpreted as AND semantics, alternatives become impossible.

P1 should define explicit semantics before freezing JSON. Minimum acceptable choices:
- split dimensions into typed fields (exposure, moisture, contamination, climate control), or
- model environment requirements as typed predicates/features with explicit `allOf/anyOf` semantics.

Do not rely on labels or undocumented list semantics.

### A5 — IP rating remains a free-form string — MEDIUM

`minimumIpRating` only checks nonblank text. Values such as `IPXX`, `66`, `ip66`, or arbitrary text can be persisted. ELV2 does not need a full normative IP engine, but immutable reference data should not freeze malformed protection values.

P1 should introduce either:
- a small canonical `IpProtectionClass` value object/parser with normalized persisted representation, or
- a typed canonical protection-reference code.

### A6 — Comparison still accepts external constraint maps — HIGH

`compareEngineeringProfileRevisions()` currently receives `previousConstraints` and `candidateConstraints` separately from the profiles. `previewCatalogRevision()` therefore carries external maps keyed by `catalogId::profileCode`.

This is an intentional transitional seam, but it directly contradicts the target aggregate once P1 is implemented. After P1:
- comparison must read constraints from `previous.constraints` / `candidate.constraints`;
- external maps and `_constraintKey()` must disappear;
- snapshot comparison becomes self-contained and deterministic.

### A7 — Removed profile does not produce a binding impact — HIGH, P5 follow-up

Current preview records a missing profile only in `removedProfileCodes` and then skips the binding. The test explicitly expects `affectedBindingCount == 0` for a removed bound profile.

That conflicts with the intended project-impact semantics: a bound component whose profile disappeared is necessarily affected and must be visible to adoption planning.

Not required to finish P1, but must be corrected in P5:
- removed profile produces a binding-level impact;
- its persisted ports/connections/topology groups remain discoverable;
- adoption is blocked until an explicit replacement or keep-pinned action is chosen.

### A8 — Preview contract is incomplete relative to the specification — MEDIUM, P5 follow-up

The current `CatalogRevisionPreview` lacks several specified fields:
- previous catalog id/version;
- added profile codes;
- directly aggregated affected port IDs;
- placement violations;
- unresolved legacy bindings.

This is acceptable for the current early slice but must not be mistaken for final P5 completeness.

### A9 — Port-template comparison is order-sensitive — MEDIUM

`_sameMaps()` compares port templates by list index. If port template order is presentation-only, reordering an otherwise identical set will be classified as a semantic connection change.

P1 should explicitly decide the invariant:
- if order is semantic, document it and test it;
- otherwise compare by normalized port code/identity.

Do not leave this accidental.

### A10 — Catalog validation currently has no constraint publication gate — BLOCKER for P1 completion

`EngineeringReferenceCatalog.validate()` delegates to `ComponentEngineeringProfile.validate()`, but profiles currently do not contain constraints. Once embedded, publication rules must distinguish:
- historical decoded legacy profile: readable;
- new active profile: valid defined constraints required;
- deprecated historical profile: readable under its pinned edition.

This logic belongs in pure domain validation, not repository/UI code.

### A11 — Binding snapshot path is structurally ready — POSITIVE

`ComponentReferenceBinding` stores the entire `ComponentEngineeringProfile` snapshot. Therefore once constraints are embedded in the profile codec, binding payloads naturally preserve exact constraints without a new binding table or mutable lookup. This supports the desired immutable/restart behavior.

### A12 — Existing JSON snapshot persistence can carry P1 without schema migration — POSITIVE

`DriftEngineeringReferenceRepository` persists canonical catalog/profile payload JSON and reconstructs via `EngineeringReferenceCatalog.fromMap()`. The P1 change can therefore remain an additive codec/domain change if backward decoding is correct. A new SQLite schema migration is not justified merely to add the embedded constraint field.

## Required P1 execution scope

### P1.0 — Restore gate

1. Run `dart format` on the two failing mobile files.
2. Require full mobile + engineering-core format/analyze/test green before claiming a P1 baseline.

### P1.1 — Harden the constraint wire contract

Before embedding:

1. Define explicit legacy state.
2. Remove duplicated discipline from constraints or enforce owner equality.
3. Replace Cartesian mounting lists with explicit valid surface/method combinations.
4. Define unambiguous environment semantics.
5. Normalize IP/protection identity.
6. Decide whether port-template order is semantic.

### P1.2 — Embed in `ComponentEngineeringProfile`

Target conceptual shape:

```text
ComponentEngineeringProfile
- code
- label
- engineeringClass
- characteristics
- capabilities[]
- portTemplates[]
- portInterfaceCodes{}
- constraintsState
- constraints?          // present when state == defined
- deprecated
```

`discipline` remains derived from the canonical discipline characteristics unless the broader model is intentionally refactored.

### P1.3 — Backward-compatible codec

Decoder rules:

```text
old profile JSON without constraints
    -> legacyUnspecified

new profile JSON with valid constraints
    -> defined(constraints)

new malformed constraints payload
    -> decode/validation failure
```

Encoder rules:
- new defined profiles always emit the constraints contract;
- legacy snapshots preserve explicit legacy semantics and are not silently normalized to unrestricted constraints.

### P1.4 — Move revision comparison onto the aggregate

After embedding:

```text
compareEngineeringProfileRevisions(previous, candidate)
```

must compare embedded constraint state/data directly. Delete the external `previousConstraints` / `candidateConstraints` maps from comparison and preview call sites.

### P1.5 — Domain tests required before P1 closure

At minimum:

1. new profile constraints full JSON round-trip;
2. old fixture without constraints decodes as legacy unspecified;
3. legacy profile is readable but cannot pass publication as a newly authored active edition;
4. invalid mounting option rejected;
5. duplicate mounting option rejected;
6. environment semantics round-trip deterministically;
7. malformed IP/protection reference rejected;
8. profile/constraints ownership invariant cannot diverge;
9. catalog validation rejects new profile with missing constraints;
10. `ComponentReferenceBinding` profile snapshot round-trips embedded constraints;
11. revision comparison detects mounting/environment/topology changes without external maps;
12. unchanged embedded constraints produce no revision impact;
13. all existing four-discipline legacy fixture tests remain green.

## Gate to P2

P1 is complete only when:

- no external mutable constraint lookup exists;
- historical snapshots remain readable;
- newly authored profiles require valid typed constraints;
- catalog and binding serialization reconstruct exact semantics after JSON round-trip;
- revision comparison is self-contained on profile snapshots;
- full Flutter/mobile and engineering-core format/analyze/test workflow is green on exact head.

## Final assessment

Current readiness for ELV2-P1: **AMBER / proceed with contract hardening first**.

The architecture does not require rollback. The main recommendation is to correct the wire model now, before constraints become part of immutable catalog snapshots. Once A0–A6 and A10 are closed, the existing repository/binding architecture is well positioned for P1 without a database schema migration.
