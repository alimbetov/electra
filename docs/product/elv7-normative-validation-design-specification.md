# Electra — ELV7 Normative Profile and Validation Design Specification

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv7-normative-validation-design`
Pinned upstream ELV6: `5dc25c34c1ec506ea79f0c9e7225952fa3553142`
Entry: [authoritative index](elv7-authoritative-spec-index.md).

## 1. Purpose

ELV7 turns versioned engineering evidence into reproducible normative assessments. It must answer:

- which exact normative profile and editions were adopted for the project/revision;
- which rules apply to each subject and why;
- which exact upstream facts/evaluations were consumed;
- which rules are satisfied, violated, not applicable, not evaluable or require manual review;
- what source/jurisdiction/clause metadata supports each rule;
- which findings remain open, have an approved deviation or were superseded by a new validation run;
- how a profile or project change invalidates only the affected rule closure;
- whether a historical compliance statement can be reproduced byte-for-byte from the pinned snapshot.

ELV7 never mutates upstream design merely to make validation pass.

## 2. Reuse and ownership

| Owner | ELV7 consumes | ELV7 must not own |
|---|---|---|
| ELV2 | immutable definitions/editions and explicit adoption | component/catalog definition identity |
| ELV3 | physical cable/run/pathway evidence | routing, length or allocation |
| ELV4 | power/PoE/UPS/battery evidence | electrical sizing algorithms |
| ELV5 | CCTV/LAN/ACS/Fire discipline results and policy evidence | discipline calculations |
| ELV6 | rack/enclosure/layout/fit projection | layout placement or solver |
| Shared runtime | revision, freeze, history, replay, UoW, command result | competing lifecycle subsystem |

ELV7 owns rule-pack metadata, project profile adoption, applicability, validation executions, outcomes/findings, evidence links and deviation/waiver records.

## 3. Profile and source model

### 3.1 Stable identities

Conceptual value types:

```dart
typedef NormativeProfileId = String;
typedef NormativeProfileEditionId = String;
typedef NormativeSourceId = String;
typedef NormativeRulePackId = String;
typedef NormativeRuleId = String;
typedef ValidationRunId = String;
typedef ValidationOutcomeId = String;
typedef ValidationFindingId = String;
typedef DeviationId = String;
```

Stable rule identity is independent from database row identity. A semantic rule change that can alter applicability/result requires a new rule revision/version; silent in-place mutation is forbidden.

### 3.2 Normative source

`NormativeSourceRef` records provenance without requiring copyrighted body text:

```text
sourceId
authority / publisher
jurisdiction
sourceKind
canonicalTitle
edition / revision
publicationDate?
effectiveFrom?
effectiveUntil?
sourceLocator
clauseRef?
licensedExcerptRef?
sourceContentHash?          // only for legally stored source material
licenseMetadata?
verificationStatus
verifiedBy?
verifiedAt?
```

`verificationStatus` minimum:

```text
FICTIONAL
PROJECT_AUTHORED
UNVERIFIED_EXTERNAL
VERIFIED_EXTERNAL
RETIRED
```

`VERIFIED_EXTERNAL` means source provenance/edition mapping has been reviewed according to project governance. It is not a legal guarantee by itself.

### 3.3 Normative profile edition

A project adopts an immutable `NormativeProfileEdition`, which contains exact ordered references to rule-pack editions plus jurisdiction/applicability context.

```text
profileId
editionId
semanticVersion
jurisdictionContext
rulePackEditionRefs
conflictResolutionPolicyVersion
createdAt
publishedAt?
status: DRAFT | PUBLISHED | RETIRED
canonicalHash
```

Published editions are immutable. A correction creates another edition.

### 3.4 Project adoption

`ProjectNormativeProfileBinding` is revision-scoped and explicit:

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

Historical revisions never follow a newer profile automatically.

## 4. Rule model

### 4.1 Rule metadata

Every rule must declare:

```text
ruleId
ruleRevision
packEditionId
discipline / domain
sourceRef + clauseRef
shortTitle
severityDefault
applicabilitySpec
consumedFactKeys
checkerId + checkerVersion
parameterSet
manualReviewRequirement?
resultAggregationGroup?
```

The rule itself is not identified by translated display text.

### 4.2 Rule implementation strategy

Initial implementation uses typed pure-Dart checkers registered by stable `checkerId`. Data supplies thresholds, enumerations and applicability parameters. A constrained declarative predicate representation may be added for simple comparisons/set-membership only if it is versioned, total and non-executable.

Forbidden:

- arbitrary user code/eval;
- string formulas interpreted at runtime;
- jurisdiction logic inside Flutter widgets;
- one giant `switch(jurisdiction)`;
- database triggers implementing engineering rules;
- network calls from a checker.

Recommended shape:

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

Registration must reject duplicate `(checkerId, checkerVersion)` and duplicate active `(ruleId, ruleRevision)` definitions.

## 5. Applicability model

Applicability is evaluated before rule checking and is deterministic. It may depend on declared facts such as:

- discipline;
- equipment/subject kind;
- occupancy/project classification already present as project facts;
- installation environment;
- topology/layout state;
- jurisdiction context;
- effective validation date;
- exact adopted technical profile/capability;
- explicit project classification inputs.

Applicability outcome:

```text
APPLICABLE
NOT_APPLICABLE
UNRESOLVED
```

`UNRESOLVED` means required applicability evidence is missing/ambiguous; the rule cannot be silently skipped.

No rule may read undeclared ambient project state. The consumed applicability fact keys are part of its dependency contract.

## 6. Validation outcome semantics

Per applicable rule and subject, exact outcome state is one of:

```text
SATISFIED
VIOLATED
NOT_EVALUABLE
MANUAL_REVIEW
```

`NOT_APPLICABLE` is stored at applicability level, not disguised as SATISFIED.

A rule can emit one or more structured findings. Each finding contains:

```text
findingId
runId
ruleId / ruleRevision
subjectRef
severity
outcome
messageCode
measuredFacts
requiredFacts / threshold facts
consumedEvidenceRefs
sourceRef / clauseRef
stableSortKey
```

Translated prose is presentation. `messageCode` and structured arguments are canonical.

### 6.1 Overall compliance status

At a defined validation scope:

- `FAIL` if any mandatory applicable rule is `VIOLATED` and not dispositioned according to the selected reporting policy;
- `BLOCKED` if any mandatory rule has unresolved applicability, `NOT_EVALUABLE` or unresolved required `MANUAL_REVIEW`;
- `PASS_WITH_DEVIATIONS` only when all mandatory applicable rules are otherwise evaluable and every violation is covered by an active explicitly approved deviation allowed by reporting policy;
- `PASS` only when all mandatory applicable rules are satisfied and required manual reviews are accepted with evidence;
- optional/advisory findings do not upgrade a blocked mandatory scope to PASS.

The raw rule outcome never changes when a deviation is approved.

## 7. Severity and obligation

Keep severity separate from mandatory/optional obligation.

Suggested severities:

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

Aggregation policy is profile-versioned. UI must not infer project compliance merely from icon color or severity count.

## 8. Evidence projection

ELV7 uses versioned adapters from upstream stages. A validation fact is immutable and traceable:

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

Examples include installed cable length, power reserve, discipline calculation status, rack occupancy, battery service envelope and cable-entry capacity. ELV7 must use the authoritative owner projection; it must not query UI providers and rebuild facts ad hoc.

If an upstream source is stale, that stale state is part of validation evidence and can block rules requiring current evidence.

## 9. Dependency graph and incremental validation

Each rule declares consumed fact keys and applicability fact keys. Maintain reverse indexes:

```text
factKey -> rule IDs
rule ID -> target selector
subject mutation -> affected fact keys
```

An upstream change invalidates the union of old/new affected facts and rules. Historical runs remain immutable; only current validation pointers become stale.

Examples:

- moving one rack item invalidates layout-dependent rules on that enclosure, not unrelated CCTV storage rules;
- changing an adopted profile invalidates all outcomes governed by changed/added/removed rule definitions;
- changing one cable route invalidates rules consuming that cable/run/pathway facts;
- changing a product display label without a consumed technical fact does not invalidate validation.

## 10. Conflict and precedence between rules

Rule packs may overlap. Conflict handling is explicit and versioned; never silently choose the last rule loaded.

The resolution model must represent at least:

- independent simultaneous obligations;
- scoped override/supersession with explicit source relationship;
- profile-level exclusion;
- unresolved contradiction requiring engineer review.

For monotonic numeric minimum/maximum requirements, a profile may define composition semantics, but this must be encoded per requirement family. ELV7 must not apply a universal `max()` to non-monotonic or mode-dependent rules.

Every resolved relationship is visible in validation provenance.

## 11. Manual review

Some requirements are inherently qualitative or outside available project facts. They use a typed manual-review obligation rather than a fake boolean calculation.

`ManualReviewRecord` minimum:

```text
run/rule/subject
reviewStatus: OPEN | ACCEPTED | REJECTED
reviewer
reviewedAt
reasonCode / note
evidenceAttachmentRefs
expectedFindingRevision
```

Acceptance of manual review is auditable and revision-aware. It does not mutate the encoded rule.

## 12. Deviations and waivers

`DeviationRecord` is an overlay on raw outcomes:

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

Changing the underlying finding/evidence marks the deviation stale unless its exact scope contract still matches. A stale deviation cannot suppress a new violation.

No destructive “resolve finding = delete finding” workflow is allowed.

## 13. Validation run and publication

A `ValidationRun` records:

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

Recommended flow:

1. capture exact revision/profile/projection manifest;
2. resolve targets and applicability;
3. execute pure checkers outside transaction where safe;
4. revalidate expected fingerprints/generations;
5. atomically publish immutable run + outcomes + findings + reverse-index metadata + current pointer;
6. if dependencies changed, discard/retry rather than publish stale PASS.

No durable `RUNNING` current-compliance record is authoritative.

## 14. Commands

Proposed public command families:

```text
CreateNormativeProfile
CreateNormativeProfileEdition
AddRulePackToProfileEdition
PublishNormativeProfileEdition
RetireNormativeProfileEdition
AdoptProjectNormativeProfile
ReleaseProjectNormativeProfile
RunNormativeValidation
RecordManualReview
ApproveManualReview
RejectManualReview
CreateDeviation
ApproveDeviation
RejectDeviation
ExpireDeviation
```

Exact wire operation registry is frozen in P2. Profile/rule catalog maintenance may use a separate administrative boundary if later backend governance requires it; mobile project commands must remain usable offline for adopted/cached editions.

All project mutations reuse existing command ID, replay-before-precondition, history and UoW semantics.

## 15. Persistence

Proposed normalized Drift family:

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

- immutable published profile/rule editions;
- stable rule identity and explicit revision;
- canonical hashes for editions/runs;
- exact project/revision scope;
- indexes by profile edition, rule, subject and outcome;
- no finding overwrite across runs;
- exact foreign keys for ELV7-owned rows and typed cross-stage refs for upstream evidence;
- source text/excerpts stored outside relational core when large/licensed; DB stores metadata/file reference/hash;
- historical profile editions remain readable after retirement.

## 16. Pure-core and application boundaries

Expected shape:

```text
packages/engineering_core/lib/src/elv7/
  profiles/
  sources/
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

Pure rule evaluation cannot depend on Flutter, Drift, HTTP or filesystem APIs.

## 17. Workspace UX

Required engineer workflow:

- show adopted profile edition, jurisdiction context and validation-as-of date;
- explicit “adopt new edition” impact preview, never automatic upgrade;
- dashboard by scope/discipline/subject/rule/severity/outcome;
- distinguish `VIOLATED`, `NOT_EVALUABLE`, `MANUAL_REVIEW`, stale and deviation states;
- navigate from finding to exact upstream entity/evidence;
- inspect source/citation metadata and checker/version/inputs;
- before/after comparison between validation runs;
- manual-review evidence workflow;
- deviation approval/history workflow;
- frozen historical read-only mode;
- offline access to adopted profile metadata/rules required for validation.

A green summary must be impossible when mandatory evidence is unresolved.

## 18. Handoff to ELV8

ELV7 exports an immutable validation projection containing:

```text
profile edition/hash
validation run/hash
rule outcomes and obligation
open/approved/stale deviations
hard technical selection constraints derived from explicit rules
subject/evidence refs
source/clause refs
manual-review state
summary by deliverable scope
```

ELV8 may use verified hard constraints to filter products, but it cannot reinterpret a violation as acceptable. A selected product that changes technical facts triggers targeted revalidation and cannot silently retain the previous ELV7 PASS.

## 19. Acceptance requirements

Runtime closure requires at least:

1. exact profile edition adoption and restart persistence;
2. immutable published edition proof;
3. effective-date/applicability positive and unresolved fixtures;
4. deterministic pure checker results and stable ordering;
5. duplicate checker/rule registration rejection;
6. verified versus project-authored source labeling proof;
7. mandatory missing evidence => `BLOCKED`, never PASS;
8. manual-review lifecycle proof;
9. deviation does not mutate raw finding proof;
10. stale deviation after evidence change proof;
11. profile-edition upgrade requires explicit adoption;
12. incremental old/new dependency invalidation proof;
13. concurrent upstream change during validation cannot publish stale PASS;
14. command replay/idempotency/rollback/restart proof;
15. R1 freeze → R2 profile/design change → reproducible historical R1 proof;
16. conflict/supersession rule-pack fixture;
17. no jurisdiction `switch` in presentation/data layers gate;
18. offline adopted-profile validation fixture;
19. canonical run hash reproduction;
20. project-scale validation performance budget.

## 20. Security, provenance and licensing gates

- rule/profile imports are untrusted data and require schema/version/hash validation;
- no imported field may become executable code;
- source URLs/locators are metadata, not trusted fetch instructions inside the rule engine;
- large or licensed documents remain attachment/file resources with controlled access;
- exported compliance reports identify exact profile edition and validation date;
- system wording must not claim authority beyond source/provenance status;
- user-authored deviations/manual reviews preserve actor/time audit.

## 21. Explicit non-goals

ELV7 does not own:

- automatic redesign/remediation of upstream engineering;
- manufacturer/SKU ranking or commercial sourcing;
- BOM pricing or procurement;
- arbitrary legal advice;
- automatic crawling/downloading of standards;
- storage of complete copyrighted standards when licensing does not permit it;
- free-form executable rule scripting.

Future rule types are added through versioned checker/provider contracts and migration-safe profile editions.