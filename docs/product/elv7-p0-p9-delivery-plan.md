# ELV7 — P0–P9 delivery plan

Status: DESIGN DRAFT / ALL RUNTIME PACKAGES OPEN
Branch: `feat/flutter-elv7-normative-validation-design`
Pinned upstream ELV6: `5dc25c34c1ec506ea79f0c9e7225952fa3553142`
Specification: [design](elv7-normative-validation-design-specification.md).

| Package | Scope | Mandatory outputs | Depends on |
|---|---|---|---|
| P0 | Baseline/provenance audit | accepted ELV6 head/schema; upstream fact-projection matrix; rule/source governance boundary | Accepted ELV1–ELV6 |
| P1 | Profiles, editions and rule registry | stable IDs; source provenance; immutable editions; checker/provider registry; adoption model | P0 |
| P2 | Persistence and command lifecycle | Drift schema; exact command registry; replay/UoW/history; profile adoption; freeze/create-next hooks | P1 + shared runtime |
| P3 | Applicability and pure validation engine | applicability resolver; typed checkers; constrained predicates; deterministic aggregation; conflict/precedence model | P1/P2 |
| P4 | Upstream adapters and rule packs | versioned ELV2–ELV6 fact projections; first discipline/layout rule families; dependency declarations | P1–P3 |
| P5 | Findings, evidence and incremental invalidation | structured outcomes/findings; reverse dependency index; targeted old/new invalidation; current pointers | P2–P4 |
| P6 | Manual review and deviations | manual-review workflow; deviation/waiver audit; stale/disposition semantics | P2/P5 |
| P7 | Validation workspace | profile adoption impact, dashboard, navigation, source/provenance, compare runs, deviation/review UX | P2–P6 |
| P8 | Integrated qualification | determinism, provenance, profile versioning, fail-closed, replay/rollback/race/restart/freeze/performance fixtures | P0–P7 |
| P9 | Closure and ELV8 handoff | exact-head reconciliation; compliance projection; selection-constraint handoff; limitations/evidence manifest | P8 |

## P0 — baseline and provenance boundary

Prove the exact upstream source/schema and enumerate every fact ELV7 is allowed to consume. For each fact define authoritative owner, projection version, identity, unit and stale semantics. Also freeze governance for `FICTIONAL`, `PROJECT_AUTHORED`, `UNVERIFIED_EXTERNAL`, `VERIFIED_EXTERNAL` and `RETIRED` sources.

P0 explicitly rejects any design that depends on widget state, `latest` profile lookup or scraping external standards during validation.

## P1 — immutable profile and rule identity

Freeze:

- normative source identity/citation fields;
- profile/rule-pack/rule edition semantics;
- canonical hashes;
- project adoption and `validationAsOfDate`;
- rule obligation/severity/outcome enums;
- checker/provider registration and duplicate rejection;
- exact semantic-change policy requiring a new edition/revision;
- source licensing/file-reference boundary.

No jurisdiction-specific rule runtime implementation starts before these contracts are accepted.

## P2 — storage and commands

Implement normalized profile/source/rule metadata, project bindings, validation run/outcome/finding records, evidence refs, manual review and deviations. Published editions and completed runs are immutable.

Freeze the command registry and codecs. All project mutation reuses command replay/history/UoW and project revision semantics. Profile adoption and validation publication are CAS/revision guarded.

## P3 — applicability and engine

Implement:

- deterministic applicability `APPLICABLE/NOT_APPLICABLE/UNRESOLVED`;
- pure checker registry by versioned ID;
- strict declared consumed-fact access;
- `SATISFIED/VIOLATED/NOT_EVALUABLE/MANUAL_REVIEW`;
- profile-defined aggregation;
- overlap/supersession/conflict handling;
- stable result/finding ordering and canonical hashing.

A generic arbitrary formula evaluator is explicitly out of scope.

## P4 — projections and initial rule families

Build typed adapters from ELV2–ELV6 projections. Each rule family must publish:

- exact rule IDs/revisions;
- source provenance/classification;
- applicability facts;
- consumed facts;
- checker and parameter versions;
- positive, violation, not-applicable and missing-evidence fixtures where applicable;
- manual-review scope if not machine-evaluable.

Project-authored/fictional fixtures may prove engine arithmetic but cannot qualify verified jurisdictional compliance.

## P5 — findings and incremental validation

Persist immutable outcomes/findings/evidence and maintain reverse dependencies. Mutations invalidate union(old,new) closures. Prove that unrelated design changes do not invalidate unrelated rule results.

Validation capture → pure run → CAS publication must reject a stale PASS if any consumed upstream fingerprint or adopted profile generation changes before publication.

## P6 — disposition workflow

Implement manual review and deviations as overlays. Required gates:

- raw finding remains immutable;
- actor/time/reason/evidence are mandatory according to policy;
- underlying evidence change can stale the disposition;
- expired/rejected/superseded deviations cannot suppress findings;
- aggregate status distinguishes PASS, PASS_WITH_DEVIATIONS, FAIL and BLOCKED.

## P7 — engineer workspace

Minimum UX:

- exact adopted profile/version and validation date always visible;
- impact preview before adopting a new edition;
- filters by scope/discipline/subject/rule/outcome/severity;
- direct navigation to upstream subject/evidence;
- source/clause/checker/inputs inspector;
- clear missing-evidence/manual-review states;
- validation-run comparison;
- deviation/manual-review history;
- stale and frozen read-only modes;
- offline validation from cached adopted profile.

## P8 — integrated qualification

At one exact SHA, capture code/migration/test/CI evidence for:

- immutable edition and explicit adoption;
- effective-date/applicability cases;
- checker deterministic output/hash;
- missing mandatory evidence fail-closed;
- source-status claim boundaries;
- rule conflict/supersession;
- manual review and deviation lifecycle;
- targeted invalidation;
- concurrent upstream/profile mutation during run;
- replay, rollback, restart and duplicate command IDs;
- R1/R2 frozen historical reproduction;
- imported malformed/untrusted rule metadata rejection;
- offline execution;
- project-scale performance.

No planned test ID counts as evidence before execution.

## P9 — closure and ELV8 contract

Reconcile requirement ↔ source/rule ↔ code ↔ migration ↔ test ↔ CI and publish:

- exact accepted profile/rule engine versions;
- verified versus project-authored rule-pack coverage;
- unsupported/manual-only rule matrix;
- ELV8 immutable compliance projection schema/hash;
- hard selection-constraint mapping rules;
- known limitations and explicit non-certification boundaries;
- exact accepted source SHA.

## Current ledger

| Package | Design | Runtime | Evidence |
|---|---|---|---|
| P0 | DRAFT | NOT_STARTED | — |
| P1 | DRAFT | NOT_STARTED | — |
| P2 | DRAFT | NOT_STARTED | — |
| P3 | DRAFT | NOT_STARTED | — |
| P4 | DRAFT | NOT_STARTED | — |
| P5 | DRAFT | NOT_STARTED | — |
| P6 | DRAFT | NOT_STARTED | — |
| P7 | DRAFT | NOT_STARTED | — |
| P8 | DRAFT | NOT_STARTED | — |
| P9 | DRAFT | NOT_STARTED | — |

Default runtime sequence: P0 → P1 → P2 → P3 → P4/P5 → P6 → P7 → P8 → P9. Rule-fixture and UI contract design should begin earlier, but qualification remains dependency-gated.