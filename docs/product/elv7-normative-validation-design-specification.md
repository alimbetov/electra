# Electra — ELV7 Normative Profile and Validation Design Specification

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Branch: `feat/flutter-elv7-normative-validation-design`
Pinned upstream ELV6 at branch creation: `5dc25c34c1ec506ea79f0c9e7225952fa3553142`
Entry: [authoritative index](elv7-authoritative-spec-index.md).
Baseline inventory: [ELV Normative Standards Matrix](elv-normative-standards-matrix.md).

## 1. Purpose

ELV7 turns versioned engineering evidence into reproducible normative assessments. It must answer:

- which exact normative profile/edition was adopted for the project revision;
- which standard/rule editions were in force for the validation-as-of date;
- which precedence/rule-class relationship made a rule applicable or dominant;
- which exact upstream facts/evaluations were consumed;
- which rules are satisfied, violated, not applicable, not evaluable or require manual review;
- what source/jurisdiction/clause metadata supports each rule;
- which findings remain open or have an approved disposition;
- how project/profile changes invalidate only affected rule closures;
- whether historical validation can be reproduced from pinned evidence.

ELV7 never mutates upstream design merely to make validation pass.

## 2. Existing normative architecture is the baseline

`docs/product/elv-normative-standards-matrix.md` already defines the architecture-level `NormativeProfile` concept, jurisdiction, edition/effective dates, standard references, precedence, discipline bindings, project overrides, rule classes, explicit profile adoption, standards lifecycle and copyright boundary.

ELV7 operationalizes that model. It must not create a second incompatible profile aggregate or silently rename semantics without a migration decision.

The existing rule classes remain canonical unless P1 explicitly proves a migration:

```text
LEGAL_MANDATORY
NATIONAL_STANDARD
ADOPTED_INTERNATIONAL
CONTRACTUAL
MANUFACTURER_MANDATORY
ENGINEERING_RECOMMENDATION
PROJECT_POLICY
```

The existing architectural priority principle also remains: lower-priority/contractual/manufacturer/project rules cannot silently weaken higher-priority mandatory jurisdictional requirements.

The standards matrix is an inventory/design baseline, **not production source verification**. Every production `VERIFIED_EXTERNAL` source/rule pack must be checked against authoritative official material for exact edition, status, applicability and effective dates before release.

## 3. Ownership and upstream reuse

| Owner/baseline | ELV7 consumes | ELV7 must not duplicate |
|---|---|---|
| Standards matrix | `NormativeProfile`, `StandardReference`, precedence, rule class, lifecycle principles | second profile/rule-class taxonomy |
| ELV2 | immutable definitions/editions and explicit adoption | component/catalog definition identity |
| ELV3 | physical cable/run/pathway evidence | routing, length or allocation |
| ELV4 | power/PoE/UPS/battery evidence | electrical sizing algorithms |
| ELV5 | CCTV/LAN/ACS/Fire discipline results/policies | discipline calculations |
| ELV6 | owner-neutral rack/enclosure/layout/fit projection | layout placement/solver |
| Shared runtime | revision, freeze, history, replay, UoW, command result | competing lifecycle subsystem |

ELV7 owns executable rule-pack metadata, project profile edition binding, applicability/precedence resolution, validation runs/outcomes/findings, evidence links, manual reviews and deviations.

## 4. Canonical profile and source model

### 4.1 Stable identities

Conceptual types:

```dart
typedef NormativeProfileId = String;
typedef NormativeProfileEditionId = String;
typedef StandardReferenceId = String;
typedef NormativeRulePackId = String;
typedef NormativeRuleId = String;
typedef ValidationRunId = String;
typedef ValidationFindingId = String;
typedef DeviationId = String;
```

A semantic change that can alter applicability/result/precedence requires a new immutable edition/revision; no silent in-place mutation.

### 4.2 Standard/normative source reference

Executable ELV7 source metadata is a hardened form of the existing `StandardReference`:

```text
sourceId
issuer / authority / publisher
standardCode?
canonicalTitle
edition / revision
status: ACTIVE | SUPERSEDED | WITHDRAWN | DRAFT | PROJECT
jurisdiction
applicabilityScope
ruleClass
publicationDate?
effectiveFrom?
effectiveUntil?
sourceLocator
clauseRef?
supersedes / supersededBy refs
licensedExcerptRef?
sourceContentHash?          // only for legally stored material
licenseMetadata?
verificationStatus
verifiedBy?
verifiedAt?
```

Existing provenance/verification vocabulary to reconcile without breaking decoders:

```text
FICTIONAL
PROJECT_AUTHORED
UNVERIFIED_EXTERNAL
VERIFIED_EXTERNAL
RETIRED
```

`RETIRED` is a legacy mixed lifecycle value, not proof of past verification.
P1 separates provenance/verification from publication, retirement and revocation
events with an explicit compatibility mapping; unknown prior approval remains
unknown. Published identities and old approval records are never rewritten.

`VERIFIED_EXTERNAL` requires source/edition, applicability, interpretation,
checker qualification and approval evidence under the declared release policy.
It is not by itself a legal guarantee. A known revocation or expired authority
invalidates a CURRENT claim independently of optional adoption of a new source
edition. Historical as-of results and later source knowledge remain separate.

### 4.3 Normative profile edition

One immutable `NormativeProfileEdition` refines the matrix model:

```text
profileId
editionId
semanticVersion
jurisdiction
profileEffectiveFrom?
profileEffectiveUntil?
standardReferenceIds[]
rulePackEditionRefs[]
precedencePolicyVersion
disciplineBindings
projectOverridePolicy
createdAt
publishedAt?
status: DRAFT | PUBLISHED | RETIRED
canonicalHash
```

Published editions are immutable. Corrections create new editions.

### 4.4 Project adoption

`ProjectNormativeProfileBinding` is explicit and revision-scoped:

```text
projectId
revisionId
profileEditionId
adoptedAt
adoptedBy
reason
expectedProfileHash
validationAsOfDate
```

Historical revisions never follow a newer profile automatically. Profile upgrade requires impact preview and explicit adoption.

## 5. Rule model

Every rule must declare:

```text
ruleId
ruleRevision
packEditionId
sourceRef + clauseRef
ruleClass
precedenceRank / precedence relation
discipline / domain
shortTitle
obligation
severityDefault
applicabilitySpec
consumedApplicabilityFactKeys
consumedFactKeys
checkerId + checkerVersion
parameterSet
manualReviewRequirement?
resultAggregationGroup?
```

Translated display text is never rule identity.

### 5.1 Rule implementation strategy

Initial implementation uses typed pure-Dart checkers registered by stable ID/version. Data supplies thresholds, enums, applicability and source metadata. A constrained declarative predicate representation may support simple comparison/set-membership only if it is versioned, total and non-executable.

Forbidden:

- arbitrary user code/eval;
- runtime string formulas;
- jurisdiction logic in Flutter widgets/controllers/repositories;
- one giant `switch(jurisdiction)`;
- database triggers implementing engineering rules;
- network calls from a checker.

Recommended core boundary:

```dart
abstract interface class NormativeRuleChecker<I extends RuleInput, O extends RuleResult> {
  String get checkerId;
  String get checkerVersion;
  O evaluate(I input);
}

abstract interface class NormativeRuleProvider {
  Iterable<NormativeRuleDefinition> definitionsFor(
    NormativeProfileEdition edition,
  );
}
```

Registration rejects duplicate `(checkerId, checkerVersion)` and active `(ruleId, ruleRevision)` conflicts.

## 6. Applicability

Applicability is deterministic and evaluated before the checker. It may use only declared facts such as discipline, subject kind, project/building classification, environment, topology/layout state, jurisdiction context, validation date and explicit project classification inputs.

Outcome:

```text
APPLICABLE
NOT_APPLICABLE
UNRESOLVED
```

`UNRESOLVED` means required applicability evidence is missing/ambiguous and the rule cannot be silently skipped.

No rule may read undeclared ambient project state.

## 7. Precedence and rule composition

ELV7 must implement the existing standards-matrix precedence principle explicitly rather than relying on load order.

The resolution model supports:

- independent simultaneous obligations;
- higher-priority mandatory dominance where rules conflict;
- scoped supersession/override with explicit source relation;
- profile-level exclusion;
- contractual/project/manufacturer additions that tighten but do not weaken mandatory rules;
- unresolved contradiction requiring engineer review.

For monotonic numeric requirement families a profile may define `max`, `min`, intersection or another composition operation. Composition is **per requirement family**. There is no universal `max()` across mode-dependent/non-monotonic obligations.

Every precedence/composition decision is recorded in validation provenance.

## 8. Validation outcome semantics

Per applicable rule/subject:

```text
SATISFIED
VIOLATED
NOT_EVALUABLE
MANUAL_REVIEW
```

`NOT_APPLICABLE` belongs to applicability, not SATISFIED.

Each structured finding contains:

```text
findingId
runId
ruleId / ruleRevision
subjectRef
ruleClass / obligation / severity
outcome
messageCode
measuredFacts
requiredFacts / threshold facts
consumedEvidenceRefs
sourceRef / clauseRef
precedence/composition evidence
stableSortKey
```

### 8.1 Severity and obligation

Severity remains separate from legal/contractual precedence and obligation.

Suggested severity:

```text
CRITICAL
ERROR
WARNING
INFO
```

Suggested obligation:

```text
MANDATORY
CONDITIONAL
ADVISORY
```

A `LEGAL_MANDATORY` rule is not represented merely as a red icon; its class/precedence remains explicit data.

### 8.2 Aggregate status and disposition

Raw compliance is FAIL when any applicable mandatory violation is proven;
otherwise BLOCKED while mandatory coverage, applicability, evidence, source
approval or required manual proof is incomplete; otherwise PASS only for an
explicit complete scope. Proven whole-scope inapplicability is NOT_APPLICABLE,
not a green PASS. Preserve unresolved counts even when a FAIL badge dominates.

An approved waiver never rewrites the raw outcome or grants statutory compliance.
The earlier draft `PASS_WITH_DEVIATIONS` is deprecated as a compliance verdict;
use a separate `reportDisposition = HAS_APPROVED_DEVIATIONS` overlay. Only a
verified applicable legal alternative/exemption can affect applicability.

Detailed precedence, claims and manual-review semantics are mandatory in
[the runtime contract](elv7-implementation/code-level-runtime-contract.md).

## 9. Evidence projection

ELV7 consumes versioned immutable projections from upstream owners:

```text
factKey
ownerStage
projectId
revisionId
subjectRef
sourceEvidenceId?
sourceEvaluationFingerprint?
value / unit / enum
capturedAt
projectionVersion
```

Examples: installed cable length, power reserve, discipline result, rack/DIN utilization, battery service envelope and cable-entry capacity.

If upstream evidence is stale, that state is part of validation evidence and can block rules requiring current facts.

## 10. Dependency graph and incremental validation

Each rule declares applicability/consumed fact keys. Maintain reverse dependencies:

```text
factKey -> rule IDs
rule ID -> target selector
subject mutation -> affected fact keys
```

An upstream change invalidates union(old,new) closures. Historical runs remain immutable; current pointers become stale.

Examples:

- one rack move invalidates rules consuming that host/layout, not unrelated CCTV retention rules;
- profile edition change invalidates changed/added/removed rule definitions and affected targets;
- cable route change invalidates only rules consuming that cable/pathway evidence;
- display-label-only change does not invalidate technical validation.

## 11. Manual review

Qualitative/out-of-model obligations use a typed manual-review record, not fake boolean PASS:

```text
run/rule/subject
reviewStatus: OPEN | ACCEPTED | REJECTED
reviewer
reviewedAt
reasonCode / note
evidenceAttachmentRefs
expectedFindingRevision
```

Manual review is auditable/revision-aware and does not mutate the encoded rule.

## 12. Profile override versus finding deviation

Two different concepts must not be conflated:

1. **profile/project override**: part of profile composition/adoption and subject to precedence rules; it cannot weaken higher-priority mandatory requirements;
2. **finding deviation/waiver**: post-evaluation disposition of a concrete finding.

`DeviationRecord` minimum:

```text
deviationId
projectId / revisionId
findingId
scope
status: DRAFT | APPROVED | REJECTED | EXPIRED | SUPERSEDED
reason
approvedBy?
approvedAt?
validFrom?
validUntil?
attachmentRefs
expectedFindingFingerprint
```

Changed underlying evidence can stale the deviation. A stale deviation cannot suppress a new finding. Findings are never destructively deleted to mean resolved.

## 13. Validation run/publication

A run records:

```text
project/revision
profileEditionId + hash
validationAsOfDate
engineVersion
upstream projection manifest/hash
startedAt/completedAt
execution status
summary status
canonical outcome hash
```

Publication flow:

1. capture exact revision/profile/source/projection manifest;
2. resolve targets, applicability and precedence;
3. execute pure checkers;
4. aggregate outcomes;
5. revalidate expected fingerprints/generations;
6. atomically publish immutable run/outcomes/findings/evidence/reverse-index + current pointer;
7. if dependencies changed, discard/retry instead of publishing stale PASS.

No durable `RUNNING` current-compliance record is authoritative.

## 14. Commands

The exact proposed wire surface is the [command registry](elv7-implementation/command-registry.json):
12 project operations plus separate catalogue-governance operations. Public
freeze/create-next remain inherited shared commands. Catalogue administration
cannot be sent as an untrusted project payload to mark a source verified.

All project mutations reuse command ID, replay-before-precondition, durable
rejection, history and UoW semantics. Assessment publication rechecks every
consumed upstream/profile/selector/review generation in the same transaction.

## 15. Persistence

Proposed normalized family, subject to P0 schema audit:

```text
normative_source
normative_profile
normative_profile_edition
normative_rule_pack
normative_rule_pack_edition
normative_rule_definition
normative_profile_rule_pack_ref
project_normative_profile_binding
normative_validation_run
normative_validation_outcome
normative_validation_finding
normative_validation_evidence_ref
normative_validation_dependency_ref
normative_manual_review
normative_deviation
normative_validation_pointer
```

Requirements:

- reuse any existing exact normative/profile identity discovered by P0; no duplicate profile truth;
- immutable published editions/runs;
- stable rule identity/revision and canonical hashes;
- exact project/revision scope;
- no finding overwrite across runs;
- typed cross-stage evidence refs;
- large/licensed source text stored as controlled attachment/file resources, with metadata/hash in DB;
- retired/superseded editions remain historically readable.

## 16. Core/application boundary

Expected additive shape after baseline inventory:

```text
packages/engineering_core/lib/src/elv7/
  profiles/
  sources/
  precedence/
  rules/
  applicability/
  validation/
  findings/
  aggregation/

apps/mobile/lib/application/
  elv7_profile_repository.dart
  elv7_validation_repository.dart
  elv7_validation_command_service.dart
  elv7_validation_query_service.dart
  elv7_validation_workspace_controller.dart

apps/mobile/lib/data/repositories/
  drift_elv7_profile_repository.dart
  drift_elv7_validation_repository.dart
```

Actual existing profile/reference filenames discovered in P0 are reused rather than wrapped unnecessarily. Pure validation cannot depend on Flutter, Drift, HTTP or filesystem APIs.

## 17. Workspace UX

Required engineer workflow:

- adopted profile edition, jurisdiction, precedence summary and validation date visible;
- explicit impact preview before profile upgrade;
- dashboard by scope/discipline/subject/rule class/outcome/severity;
- distinguish violation, not-evaluable, manual-review, stale and deviation states;
- navigate finding → exact upstream entity/evidence;
- inspect source/clause/checker/parameters/precedence resolution;
- compare validation runs;
- manual-review and deviation history;
- frozen historical read-only mode;
- offline access to adopted profile/rules required for validation.

A green summary is impossible when mandatory evidence is unresolved.

## 18. Handoff to ELV8

ELV7 exports immutable validation evidence:

```text
profile edition/hash
validation run/hash
rule class / obligation / outcome
precedence/composition evidence
open/approved/stale deviations
hard technical selection constraints derived from explicit rules
subject/evidence refs
source/clause refs
manual-review state
summary by deliverable scope
```

ELV8 may use verified hard constraints to filter products but cannot reinterpret a violation as compliant. Product selection that changes technical facts triggers targeted revalidation.

## 19. Qualification requirements

Runtime closure requires at least:

1. standards-matrix → executable-model field/enum reconciliation proof;
2. official-source verification gate for each production `VERIFIED_EXTERNAL` pack;
3. exact profile edition adoption/restart persistence;
4. immutable published edition proof;
5. effective-date/applicability positive/unresolved cases;
6. precedence: higher-priority mandatory cannot be weakened by lower-priority/project/manufacturer rule;
7. deterministic checker results/stable ordering/hash;
8. duplicate checker/rule registration rejection;
9. mandatory missing evidence => `BLOCKED`, never PASS;
10. manual-review lifecycle;
11. deviation leaves raw finding unchanged;
12. stale deviation after evidence change;
13. explicit profile upgrade only;
14. old/new targeted invalidation;
15. concurrent upstream/profile change cannot publish stale PASS;
16. command replay/idempotency/rollback/restart;
17. R1 freeze → R2 profile/design change → historical R1 reproduction;
18. conflict/supersession/composition fixtures;
19. no jurisdiction switch in UI/data layers;
20. offline adopted-profile validation;
21. project-scale validation performance budget.

## 20. Security, provenance and licensing

- rule/profile imports are untrusted data with schema/version/hash validation;
- imported data never becomes executable code;
- source URLs are metadata, not checker fetch instructions;
- licensed documents remain controlled resources;
- reports identify exact profile edition/source status/validation date;
- UI/report language cannot claim authority beyond verified provenance/applicability;
- deviations/manual reviews preserve actor/time audit;
- copyright-restricted source text is not copied unless licensing permits it.

## 21. Explicit non-goals

ELV7 does not own automatic redesign, manufacturer/SKU ranking, procurement/BOM pricing, arbitrary legal advice, automatic standards crawling, free-form executable rule scripting or unlicensed full-text standards storage.

Future rule types are added through versioned checker/provider contracts and migration-safe profile editions.

## 22. Mandatory implementation dossiers (2026-10-18)

The [implementation package](elv7-implementation/README.md) hardens this design:

- 45 normative rule families; all 27 ELV5 processes mapped explicitly;
- B/C/D and product-specific TCC envelopes, with separate RCD/fuse/SPD/fire/room classifications;
- exact scalar/interval proof contracts, minimum/maximum fault distinction,
  overload, inrush, disconnection, interruption, selectivity and cascading;
- immutable profile/source identities reconciled with existing normative/protection code;
- exact commands, coverage/negative selectors, atomic publication and append-only freeze;
- provisional ELV6 24-process/safety evidence handoff, without declaring runtime implemented;
- 364 planned qualification scenarios and Q0–Q9 source/runtime evidence gates.

Within these subjects the detailed dossiers supersede less precise language in
this design draft. No runtime, production pack approval or legal certification
is claimed by this documentation or its structural checker.
