# Electra — ELV7 Authoritative Design Index

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Branch: `feat/flutter-elv7-normative-validation-design`
Parent branch: `feat/flutter-elv6-enclosure-layout-design`
Pinned parent at branch creation: `5dc25c34c1ec506ea79f0c9e7225952fa3553142`

ELV7 owns **versioned normative profiles, jurisdiction-aware applicability and deterministic compliance validation** over immutable engineering facts produced by ELV2–ELV6. It does not redesign the project, silently change upstream entities, select manufacturer products or assemble commercial deliverables.

The repository already contains the accepted architecture inventory [ELV Normative Standards Matrix](elv-normative-standards-matrix.md). Its `NormativeProfile`, precedence, rule classes, standards lifecycle, copyright boundary and explicit-adoption principles are the ELV7 baseline. ELV7 operationalizes and hardens that model; it must not create a second incompatible standards/profile taxonomy.

## Entry documents

1. [ELV7 normative-validation design specification](elv7-normative-validation-design-specification.md).
2. [ELV7 P0–P9 delivery plan](elv7-p0-p9-delivery-plan.md).
3. [Implementation design package](elv7-implementation/README.md) — code contracts, B/C/D, 45 rule families, commands, exact baseline and qualification plan.
4. [ELV Normative Standards Matrix](elv-normative-standards-matrix.md) — baseline profile/precedence/rule-class inventory; production applicability still requires verified official sources.
5. [ELV6 authoritative index](elv6-authoritative-spec-index.md) and [ELV6 design](elv6-enclosure-layout-design-specification.md) define the immediately preceding physical-layout boundary.
6. ELV1–ELV5 authoritative contracts remain governing for identities, physical realization, power and discipline calculations.

## Authority hierarchy

1. actually accepted upstream identity/revision/evidence contracts (ELV6 design is provisional until implemented and accepted) and the non-conflicting accepted standards/profile principles from `elv-normative-standards-matrix.md`;
2. this index and the ELV7 normative-validation specification, which refine the executable/runtime contract;
3. ELV7 implementation dossiers and registries, which resolve numerical/publication/claim details;
4. ELV7 P0–P9 plan;
5. architecture overview and legacy mixed-domain documents.

The standards matrix is an architecture/inventory baseline, not evidence that every listed publication is currently applicable. P0/P4 must verify each production source/edition against authoritative official material before marking a rule pack `VERIFIED_EXTERNAL`.

## Stage boundary

```text
ELV2–ELV6 exact engineering facts and immutable evidence
    +
accepted NormativeProfile/precedence/rule-class architecture baseline
    ↓
ELV7 exact adopted normative profile edition
    ↓
applicability + precedence/conflict resolution
    ↓
deterministic rule evaluation
    ↓
findings + evidence + manual-review obligations + deviations
    ↓
ELV8 selection constraints and deliverable compliance sections
```

ELV7 is the first stage allowed to make a **verified jurisdictional compliance assessment**, and only when the adopted rule pack has verified provenance and every mandatory applicable rule has sufficient evidence. A fictional/project-authored rule pack may validate project policy but must never be labeled statutory/national compliance.

## Non-negotiable decisions

- One canonical `NormativeProfile` model evolves from the existing standards matrix; no parallel profile aggregate.
- Existing rule classes remain explicit: `LEGAL_MANDATORY`, `NATIONAL_STANDARD`, `ADOPTED_INTERNATIONAL`, `CONTRACTUAL`, `MANUFACTURER_MANDATORY`, `ENGINEERING_RECOMMENDATION`, `PROJECT_POLICY` unless P1 performs a separately justified migration.
- Higher-priority mandatory rules cannot be silently weakened by lower-priority or manufacturer/project rules.
- Historical validation always uses the exact adopted profile/rule-pack edition, never `latest`.
- `NOT_EVALUABLE` and `MANUAL_REVIEW` are not PASS.
- Missing mandatory evidence fails closed at the compliance-claim level.
- Rule logic is pure deterministic Dart or a constrained versioned predicate representation; never arbitrary executable expressions.
- No giant jurisdiction `switch` in widgets, repositories or controllers.
- Every rule has stable identity, applicability, consumed-facts declaration, rule class/precedence and source provenance.
- Every finding points back to exact project entities/evidence and exact normative source metadata.
- Deviations/waivers annotate a finding; they do not rewrite the raw result.
- A profile change is explicit adoption and targeted invalidation, never background replacement.
- Full copyrighted standards text is stored only when licensing permits; otherwise keep citation/provenance plus encoded engineering interpretation/parameters.
- ELV7 never silently edits ELV6 layout or earlier engineering stages.

## Runtime entry gate

P0 must pin the accepted ELV6 head, current database schema, upstream validation projections and exact existing revision/freeze/history/replay contracts, then reconcile every field/enum in the existing standards matrix with the executable ELV7 model. P1 freezes rule/profile identity and provenance semantics before any jurisdiction-specific runtime rule is added.

All ELV7 P0–P9 runtime packages are currently `NOT_STARTED`; this branch is a design contract, not compliance certification.

## Current reconciliation checkpoint

ELV7 has incorporated merged main/ELV5 (`29957ba9` / runtime `b3dc15fe`).
Merge and technical CI PASS do not manufacture full upstream acceptance;
[baseline pins](elv7-implementation/baseline-and-handoff.json) retain that distinction.
The inspected external ELV6 design is `4778dae7`; its current safety projections
are a pinned candidate, while inherited ELV6 files here are historical snapshots.
Do not mistake them for the concurrently updated ELV6 branch authority.

B/C/D denote breaker trip characteristics; RCD Type B and other classification
schemes are distinct typed namespaces. Raw legal violations cannot become PASS
through a project waiver. Empty/unresolved mandatory coverage cannot become PASS.
Source metadata discovery is distinct from a verified executable rule pack.

Design consistency is checked by `scripts/ci/check-elv7-design-contract.py`.
Every runtime package remains NOT_STARTED; 362 scenarios are planned, not executed.
