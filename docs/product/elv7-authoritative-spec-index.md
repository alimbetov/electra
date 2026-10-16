# Electra — ELV7 Authoritative Design Index

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv7-normative-validation-design`
Parent branch: `feat/flutter-elv6-enclosure-layout-design`
Pinned parent: `5dc25c34c1ec506ea79f0c9e7225952fa3553142`

ELV7 owns **versioned normative profiles, jurisdiction-aware applicability and deterministic compliance validation** over immutable engineering facts produced by ELV2–ELV6. It does not redesign the project, silently change upstream entities, select manufacturer products or assemble commercial deliverables.

## Entry documents

1. [ELV7 normative-validation design specification](elv7-normative-validation-design-specification.md).
2. [ELV7 P0–P9 delivery plan](elv7-p0-p9-delivery-plan.md).
3. [ELV6 authoritative index](elv6-authoritative-spec-index.md) and [ELV6 design](elv6-enclosure-layout-design-specification.md) define the immediately preceding physical-layout boundary.
4. ELV1–ELV5 authoritative contracts remain governing for identities, physical realization, power and discipline calculations.

## Authority hierarchy

1. accepted ELV1–ELV6 identity/revision/evidence contracts;
2. this index and the ELV7 normative-validation specification;
3. ELV7 P0–P9 plan;
4. architecture overview and legacy mixed-domain documents.

A rule pack may evaluate upstream facts but may not become a second source of truth for them.

## Stage boundary

```text
ELV2–ELV6 exact engineering facts and immutable evidence
    ↓
ELV7 exact adopted normative profile edition
    ↓
applicability resolution
    ↓
deterministic rule evaluation
    ↓
findings + evidence + manual-review obligations + deviations
    ↓
ELV8 selection constraints and deliverable compliance sections
```

ELV7 is the first stage allowed to make a **verified jurisdictional compliance assessment**, and only when the adopted rule pack has verified provenance and every mandatory applicable rule has sufficient evidence. A fictional/project-authored rule pack may validate project policy but must never be labeled statutory/national compliance.

## Non-negotiable decisions

- Historical validation always uses the exact adopted profile/rule-pack edition, never `latest`.
- `NOT_EVALUABLE` and `MANUAL_REVIEW` are not PASS.
- Missing mandatory evidence fails closed at the compliance-claim level.
- Rule logic is pure deterministic Dart or a constrained versioned predicate representation; never arbitrary executable expressions.
- No giant jurisdiction `switch` in widgets, repositories or controllers.
- Every rule has stable rule identity, applicability contract, consumed-facts declaration and source provenance.
- Every finding points back to exact project entities/evidence and exact normative source metadata.
- Deviations/waivers annotate a finding; they do not rewrite the original result.
- A profile change is explicit adoption and targeted invalidation, never background replacement.
- Full copyrighted standards text is not required to run the engine; store authorized excerpts only when licensing permits, otherwise keep citation/provenance and encoded machine semantics.
- ELV7 never silently edits ELV6 layout or earlier engineering stages.

## Runtime entry gate

P0 must pin the accepted ELV6 head, current database schema, upstream validation projections and exact existing revision/freeze/history/replay contracts. P1 must freeze rule/profile identity and provenance semantics before any jurisdiction-specific runtime rule is added.

All ELV7 P0–P9 runtime packages are currently `NOT_STARTED`; this branch is a design contract, not compliance certification.