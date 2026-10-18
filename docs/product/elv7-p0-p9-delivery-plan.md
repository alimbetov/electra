# ELV7 — P0–P9 delivery plan

Status: DESIGN HARDENED / ALL ELV7 RUNTIME PACKAGES OPEN
Branch: `feat/flutter-elv7-normative-validation-design`
ELV6 provisional design inspected for this contract: `4778dae76a0315ab8bc04c9d63a3ac666aa9674d`
Specification: [design](elv7-normative-validation-design-specification.md).
Normative architecture baseline: [ELV Normative Standards Matrix](elv-normative-standards-matrix.md).

| Package | Scope | Mandatory outputs | Depends on |
|---|---|---|---|
| P0 | Baseline/provenance audit | actual upstream acceptance/schema/API inventory; standards-matrix field/enum reconciliation; upstream fact projection; official-source verification governance | Exact main + pinned provisional ELV6 contract + standards matrix |
| P1 | Canonical profile/rule identity | one `NormativeProfile` model; StandardReference/source lifecycle; existing rule classes; precedence; immutable editions; checker/provider registry | P0 |
| P2 | Persistence and command lifecycle | additive/reuse schema map; exact command registry; replay/UoW/history; explicit profile adoption; freeze/create-next hooks | P1 + shared runtime |
| P3 | Applicability, precedence and pure validation | applicability resolver; typed checkers; declared facts; rule composition/precedence; deterministic aggregate semantics | P1/P2 |
| P4 | Upstream adapters and verified rule packs | versioned ELV2–ELV6 facts; first rule families; exact official-source evidence; dependencies and fixtures | P1–P3 |
| P5 | Findings/evidence/invalidation | immutable outcomes/findings; evidence refs; reverse dependency index; targeted old/new invalidation; guarded current pointers | P2–P4 |
| P6 | Manual review, profile overrides and deviations | typed qualitative review; precedence-safe project/profile override; finding deviation/waiver audit; stale disposition rules | P2/P5 |
| P7 | Validation workspace | adoption impact; rule-class/precedence visibility; dashboard/navigation/provenance; run compare; review/deviation UX | P2–P6 |
| P8 | Integrated qualification | source governance, precedence, determinism, fail-closed, replay/rollback/race/restart/freeze/offline/performance evidence | P0–P7 |
| P9 | Closure and ELV8 handoff | exact-head reconciliation; verified coverage matrix; immutable compliance/selection-constraint projection; limitations/evidence manifest | P8 |

## P0 — baseline and provenance boundary

P0 must produce source-reality evidence before any production rule pack starts:

- exact ELV6/current schema and revision/freeze/history/replay APIs;
- every ELV2–ELV6 fact ELV7 may consume, including owner, identity, unit, projection version and stale semantics;
- exact mapping from existing `NormativeProfile`, `StandardReference`, precedence, lifecycle and rule-class concepts in `elv-normative-standards-matrix.md` to executable types;
- proof that no second competing normative profile taxonomy exists;
- governance for existing `FICTIONAL`, `PROJECT_AUTHORED`, `UNVERIFIED_EXTERNAL`, `VERIFIED_EXTERNAL` provenance/verification values; separate retirement/revocation lifecycle and an explicit decoder for legacy `RETIRED` records;
- official-source verification procedure for production rule packs, including edition/status/effective-date/applicability evidence;
- licensing/file-storage boundary for standards material.

The standards matrix is an architecture/inventory baseline. Its listed publications are not automatically production-verified merely because they appear in documentation.

P0 rejects widget-state rules, `latest` fallback and network scraping during validation.

## P1 — one canonical profile, source and rule registry

Freeze:

- stable profile/source/rule/rule-pack IDs and immutable edition semantics;
- `StandardReference`-compatible issuer/code/title/edition/status/jurisdiction/effective-date/lifecycle fields;
- existing rule classes:
  `LEGAL_MANDATORY`, `NATIONAL_STANDARD`, `ADOPTED_INTERNATIONAL`, `CONTRACTUAL`, `MANUFACTURER_MANDATORY`, `ENGINEERING_RECOMMENDATION`, `PROJECT_POLICY`;
- precedence and per-requirement-family composition semantics;
- explicit project adoption and `validationAsOfDate`;
- source verification/provenance and copyright boundary;
- rule obligation/severity/outcome as separate dimensions;
- checker/provider ID/version registry and duplicate rejection;
- semantic-change rules requiring new edition/revision and canonical hash.

No production jurisdiction rule implementation starts before this contract is accepted.

## P2 — persistence and project commands

P0/P1 first determine whether any existing exact profile/reference persistence can be reused. New Drift schema is additive and must not create duplicate normative identity.

Persist immutable published profile/rule editions, project profile binding, validation runs/outcomes/findings/evidence/dependencies, manual review and deviations. Historical retired/superseded editions remain readable.

Freeze the exact command registry/codecs. All project mutation uses `commandId`, replay-before-precondition, project/revision/aggregate expected generations, history/UoW and atomic publication semantics. Profile upgrade is explicit and impact-reviewed.

## P3 — applicability, precedence and engine

Implement:

- `APPLICABLE / NOT_APPLICABLE / UNRESOLVED` applicability;
- pure checker registry with declared fact access only;
- `SATISFIED / VIOLATED / NOT_EVALUABLE / MANUAL_REVIEW` raw outcomes;
- precedence that prevents lower-priority/project/manufacturer rules from silently weakening higher-priority mandatory requirements;
- explicit independent, superseding, excluded and contradictory rule relationships;
- per-family monotonic/non-monotonic composition policy rather than universal `max()`;
- raw `PASS / FAIL / BLOCKED / NOT_APPLICABLE` semantics with separate deviation disposition;
- stable finding/result order and canonical hashes.

Arbitrary executable formula/rule scripting is out of scope.

## P4 — upstream projections and verified rule packs

Build versioned adapters from ELV2–ELV6 projections. Every production rule family publishes:

- exact rule ID/revision and rule class;
- exact verified source/edition/status/effective date/jurisdiction and clause metadata;
- applicability and consumed fact keys;
- precedence/composition relationship where overlapping requirements exist;
- checker/parameter versions;
- positive, violation, not-applicable, unresolved/missing-evidence fixtures;
- manual-review scope for qualitative requirements;
- source-verification evidence showing why `VERIFIED_EXTERNAL` is justified.

Project-authored/fictional fixtures may qualify engine mechanics but never verified statutory/national compliance.

## P5 — immutable findings and targeted invalidation

Persist raw outcomes/findings/evidence and reverse dependencies. Mutations invalidate the union of old/new closures; unrelated facts do not trigger global revalidation.

Validation publication follows capture → pure resolve/evaluate → aggregate → CAS revalidate → atomic immutable publication/current pointer. Any changed consumed fingerprint/profile generation rejects a stale PASS.

## P6 — review and disposition

Keep three concepts separate:

1. manual review for qualitative/not-machine-evaluable obligations;
2. project/profile override during profile composition, constrained by precedence and unable to weaken higher-priority mandatory rules;
3. post-evaluation deviation/waiver overlay on a concrete finding.

Required gates:

- raw finding immutable;
- actor/time/reason/evidence recorded according to policy;
- changed finding/evidence can stale disposition;
- expired/rejected/superseded/stale deviation cannot suppress a new result;
- reporting status remains distinct from raw outcome.

## P7 — engineer workspace

Minimum UX:

- exact adopted profile edition, jurisdiction and validation-as-of date visible;
- impact preview before profile upgrade;
- rule class/precedence/source status visible in finding inspector;
- filters by scope/discipline/subject/rule/outcome/severity/class;
- finding → exact upstream entity/evidence/source navigation;
- checker/parameters/consumed facts/precedence decision inspector;
- missing evidence/manual review/deviation states clearly distinct;
- validation-run comparison;
- frozen historical mode;
- offline validation using cached adopted profile/rules.

A green summary is impossible when a mandatory applicable obligation is unresolved.

## P8 — integrated qualification

At one exact SHA capture code/migration/test/CI evidence for:

- standards-matrix → executable-model field/enum reconciliation;
- production source-verification gate and source-status claim boundaries;
- immutable edition and explicit adoption;
- effective-date/applicability cases;
- mandatory precedence cannot be weakened by project/manufacturer/lower-priority rule;
- conflict/supersession/composition cases;
- deterministic checker/finding order/hash;
- duplicate registry rejection;
- mandatory missing evidence fail-closed;
- manual-review lifecycle;
- deviation leaves raw finding unchanged and stales when evidence changes;
- targeted invalidation;
- concurrent upstream/profile mutation cannot publish stale PASS;
- replay, rollback, restart and duplicate command IDs;
- R1/R2 frozen historical reproduction;
- malformed/untrusted rule metadata rejection;
- no jurisdiction switch in presentation/data layers;
- offline execution;
- project-scale performance.

Planned fixture IDs are not evidence until executed.

## P9 — closure and ELV8 contract

Reconcile requirement ↔ source/rule ↔ code ↔ migration ↔ test ↔ exact-head CI and publish:

- exact accepted profile/rule/checker engine versions;
- verified/project-authored/fictional coverage matrix;
- unsupported/manual-only rule matrix;
- precedence/composition coverage and known jurisdiction gaps;
- ELV8 immutable compliance projection schema/hash;
- mapping from eligible ELV7 rules/findings to hard equipment-selection constraints;
- non-certification/legal limitation statement grounded in actual source coverage;
- exact accepted source SHA and evidence manifest.

## Current ledger

| Package | Design | Runtime | Evidence |
|---|---|---|---|
| P0 | CONTRACT_DEFINED | NOT_STARTED | standards matrix is design baseline only |
| P1 | CONTRACT_DEFINED | NOT_STARTED | existing profile/rule-class concepts require runtime reconciliation |
| P2 | CONTRACT_DEFINED | NOT_STARTED | — |
| P3 | CONTRACT_DEFINED | NOT_STARTED | — |
| P4 | CONTRACT_DEFINED | NOT_STARTED | — |
| P5 | CONTRACT_DEFINED | NOT_STARTED | — |
| P6 | CONTRACT_DEFINED | NOT_STARTED | — |
| P7 | CONTRACT_DEFINED | NOT_STARTED | — |
| P8 | CONTRACT_DEFINED | NOT_STARTED | — |
| P9 | CONTRACT_DEFINED | NOT_STARTED | — |

Default runtime sequence: P0 → P1 → P2 → P3 → P4/P5 → P6 → P7 → P8 → P9. Rule-fixture/source-verification design and UX contracts should start earlier, but runtime qualification remains dependency-gated.

## Code-contract work breakdown

| Package | Concrete implementation inputs and exit proof |
|---|---|
| P0 | baseline-and-handoff manifest, existing normative/protection owners, exact national applicability and ELV6 projection-gap audit; allocate actual migration version |
| P1 | classification namespaces, typed rational intervals and TCC domain, immutable profile/source/rule/checker identities, coverage and disposition axes |
| P2 | 12-operation wire registry, separate catalogue governance, scoped FKs, immutable records, replay/durable rejection/history and append-only freeze/create-next |
| P3 | all 45 family checker contracts, finite applicability grammar, interval/uncertainty semantics and precedence DAG; independent numerical oracles |
| P4 | real owner adapters for 27 ELV5 processes, ELV6 LAY/safety projections and AC protection studies; no fabricated producer facts |
| P5 | empty/missing/member selector dependencies, all upstream generation CAS, batch closure and immutable result publication |
| P6 | reviews/deviations with authority/expiry/fingerprint checks; mandatory violations never become green through disposition |
| P7 | separate B/C/D and RCD selectors, minimum/maximum Ik and limiting-time inspector, what-if, coverage and profile impact UX |
| P8 | expand and execute 364 planned scenarios, Q0–Q9 including unchanged upstream acceptance and freeze regressions |
| P9 | exact-SHA non-skipped witness matrix, verified-source coverage, actual unsupported/manual-only limits, ELV8 contract |

The [implementation package](elv7-implementation/README.md) is mandatory for these
packages. Planned-case cardinality and structural design CI are not qualification.

## Shared interface delivery obligations

Use [the integration agreement](elv-integration/README.md) in P0–P9. P1/P3 freeze
separate normative-requirement/assessment adapters; P2 separates public wire from
ledger names; P4/P5 qualify scoped producer generations and trust invalidation;
P8 executes the shared cross-stage oracles; P9 supplies immutable assessment and
coverage evidence to ELV8. Shared design alignment is not runtime acceptance.


## Generator / PV / storage / transfer source gates

Apply [the source-system contract](elv-integration/source-systems-contract.md)
and [readiness ledger](elv-integration/design-readiness.json): P0 binds exact
canonical electrical producer/commands/schema/domains and legacy compatibility;
P1/P2 freeze typed source/settings/scenario projections and scoped adoption;
P3–P5 implement only owner-appropriate rule/adaptor/invalidation behavior;
P8 executes the 32 source-specific oracles plus inherited/shared regressions;
P9 requires exact-SHA actual owner evidence before source-mode runtime acceptance.
Normative source metadata, planned tests and design CI do not satisfy those gates.
