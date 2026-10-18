# ELV7 — Code-level runtime contract

Status: DESIGN HARDENED / RUNTIME NOT STARTED. All APIs below are proposed.
Authority: index → design specification → this contract and protection dossier
→ machine registries → P0–P9 plan. A JSON registry is not executed evidence.

## 1. Existing owners and migration

P0 inventories existing `NormativeDocument`, `ElectricalRulesetRef`,
`ProtectionRuleset`, `CircuitProtectionInputs`, manufacturer definitions,
`EngineeringDecision`, `NormativeDocuments`/`ProtectionRulesets` tables and all
accepted ELV revision/history APIs. Retain IDs and historical decoders. Existing
project-authored protection proposals remain proposals; `validated` is not
equivalent to verified statutory compliance.

Schema baseline is 24 on merged main. Do not reserve schema 25: ELV6 proceeds
in parallel and the implementation migration number must be allocated against
the actual accepted main then. New tables use composite project/revision scope;
published source/profile/pack editions use immutable content identities with
explicit ownership. Never repeat the ELV5 globally-addressed, revision-filtered
evidence mismatch. Existing frozen manifests remain immutable.

## 2. Canonical types and dimensions

Reuse ELV5 rational/canonical encoder versions where their public contract fits;
explicit adapters verify representation and units. No second decimal engine.
Electrical scalars have current semantics (continuous rms/fault rms/peak),
voltage, time, impedance, length, temperature or energy dimensions. Scalars
never travel as untyped `double`. Dimensional operations reject incompatible
operands before rule execution. Cross multiplication preserves exact order;
bounded rational bit-length prevents hostile imports exhausting workers.

```dart
final class NormativeSubjectRef {
  final String owner, kind, id; // existing owner identity, not a new component
}
final class NormativeFactRef {
  final String owner, schema, subjectKey, scenarioKey, factKey;
  final String evaluationId, payloadHash, definitionHash;
  final int pointerGeneration;
  final String freshness, completion, assessment;
}
final class NormativeEvaluationKey {
  final String designRevisionId, scopeKey, scenarioKey;
  final String profileEditionHash, ruleEditionHash, subjectKey;
}
```

Every consumed field declares its dimensional type, meaning, uncertainty,
projection schema and source status. A fact may be unknown; numeric zero is an
explicit value. A null, empty collection or missing enum cannot stand for a
successful zero requirement.

## 3. Rule/checker contract

The [45-family registry](rule-family-registry.json) closes the initial design
inventory. These are rule families, not 45 replacement engineering kernels.
Each pack instantiates stable source-specific rule editions with typed checkers.

```dart
abstract interface class NormativeChecker {
  String get id;
  String get version;
  RuleOutcome evaluate(DeclaredRuleInput input);
}
abstract interface class NormativeFactReader {
  FactValue require(DeclaredFactKey key);
}
```

Undeclared reads are execution errors, not normative violations. Missing declared
facts produce structured missing-evidence outcomes. Checker registry entries
state accepted input schema, parameter schema, dimensions and canonical version.
Unknown checker/version blocks the affected rule; it cannot disappear from the
coverage denominator. No network, SQL, clock, filesystem or user executable code
inside checkers. Declarative applicability supports a finite total expression
grammar: typed comparisons, membership, `all/any/not`, explicit unknown values;
depth ≤ 32 and node count ≤ 1024 in the initial schema. These are product
resource limits, not normative thresholds; version changes are explicit.

## 4. Applicability and completeness

Context includes jurisdiction, adopted national implementation, building/use
and fire categories, system type, earthing, rated voltage, waveform, service
date, permit/transition basis and declared validation purpose.

Applicability is three-valued: APPLICABLE / NOT_APPLICABLE / UNRESOLVED.
Unknown under `not`, `all`, `any` remains unknown unless the expression can be
decided without it. Every negative applicability decision stores its proof.

Target selection stores a selector and membership fingerprint including missing
and empty sets. A later new circuit, protective device, cabinet opening, rule,
room classification or previously absent upstream evidence invalidates its
selector closure. Union(old,new) invalidation is server-derived, not a list
trusted from the UI. Empty target selection is not an automatic green project.

Coverage contains required families/rules/subjects/scenarios, discovered,
evaluated, missing, excluded-with-proof and manual-only counts. Scope-level
formal PASS requires a verified, exhaustive scope declaration and complete
mandatory coverage. A completed subset is displayed as subset coverage only.

## 5. Authority, dates and conflicts

Separate publication date, national effective interval, project transition/
grandfathering basis, assessment-as-of date and knowledge/source-review date.
Use half-open effective intervals `[from, until)` with an explicit civil-date
timezone/calendar. Do not silently use today's date during historical replay.

Rule class is not proof that a national standard is legally mandatory. Store
the incorporation/contract relation, jurisdiction, product/installation scope
and authority. Resolve a precedence DAG; reject cycles and unresolved same-rank
conflicts. Numeric intersection may expose an impossible requirement; it does
not automatically select whichever source is convenient. A source may tighten
an independent product limit without overriding mandatory law. Apply each
independent obligation; never discard it using a blanket priority integer.

Metadata discovery, normative interpretation review, national applicability
review, checker qualification and production pack approval are separate gates.
`VERIFIED_EXTERNAL` requires all declared release proofs, immutable hashes,
reviewer authority and validity dates. A URL or official catalogue listing
alone is `METADATA_REVIEWED`, not a verified executable rule.

## 6. Outcomes and claims

Execution, completeness, raw normative outcome, freshness, claim scope and
disposition are independent axes. Per-rule raw outcomes remain
SATISFIED / VIOLATED / NOT_EVALUABLE / MANUAL_REVIEW; applicability has its own axis.

Aggregate raw compliance is FAIL if a mandatory applicable violation is proven;
otherwise BLOCKED if required applicability/evidence/source review/manual
proof or coverage is incomplete; otherwise PASS only for a proved complete
scope. A proven wholly inapplicable scope is NOT_APPLICABLE, never PASS.
Persist blocker counts even when FAIL dominates the display badge.

Raw findings never change after review or waiver. A waiver is a disposition
overlay tied to exact rule, evidence, profile, scope, actor authority and dates.
It never converts a legal violation to compliance. Legacy draft
`PASS_WITH_DEVIATIONS` is deprecated as a compliance verdict: expose
`reportDisposition=HAS_APPROVED_DEVIATIONS` separately. Only an actual legal
alternative/exemption encoded in applicability with verified authority can
change the set of applicable obligations. Project policy exceptions cannot
manufacture such authority.

For manual-only rules, approval needs a qualified evidence/reviewer record for
that exact obligation; an automated violation cannot be signed into SATISFIED.
Expired/stale/rejected/untrusted approvals cannot unblock the scope. Different
reviews can be required by product policy; offline actor IDs are opaque
credentials, not invented authenticated roles or personal-data requirements.

## 7. Identity and hashes

Run identity includes project/revision/scope/scenarios, profile and rule-set
hashes, coverage/applicability/selector manifest, exact facts and generations,
source approvals/revocations as adopted, checker/encoder/numeric versions and
explicit assessment context. Exclude locale, translated labels, UI order,
wall-clock start/end and transport IDs. Sort sets by canonical identity. Domain
payload hashes do not remove immutable revision ownership from record keys.

Finding identity includes run hash, rule edition, subject/scenario and stable
reason code. Review/deviation uses a separate immutable event stream and
pointer; edits do not rewrite findings. Validate both payload/evidence hashes
and pointer identity when consuming persisted upstream CURRENT evidence.

## 8. Atomic publication protocol

1. Replay command outcome before WORKING/expected-revision preconditions.
2. Capture an immutable consistent fact/selector/profile snapshot with all owner
   generations and source status. Retry boundedly if capture changes mid-read.
3. Resolve applicability, precedence and coverage, then evaluate pure checkers
   outside the DB write transaction.
4. Start one shared publication transaction; recheck replay and WORKING state.
5. Compare design, adopted-profile, target-membership, every consumed ELV3/4/5/6
   pointer, missing selector, review/deviation and current-result generations.
   Same evaluation ID with a changed generation is still a stale capture.
6. Append run/outcomes/findings/evidence, replace dependency index, CAS current
   pointer and save command outcome in the same transaction.
7. Any failure rolls back every publication write. Freeze wins over late results.
   Same command ID/payload replays exactly; different envelope conflicts.

Persist deterministic REJECTED outcomes through the existing durable rejection
boundary after rolling back domain writes. A storage/worker/cancellation fault
is not a deterministic engineering rejection and cannot leave a false SUCCESS.
Define retryable SQLite busy versus domain CAS conflict explicitly.

Profile/rule changes atomically invalidate dependent pointers, including new
and removed rules and empty/missing selectors. A new upstream CURRENT result
must invalidate consumers of its previous generation even when bytes match.
Batch publication computes its final dependency closure before committing; no
half-updated mixture of old/new rules or pointers is observable.

## 9. Storage and shared lifecycle extension

Extend/reuse source identity; proposed additive storage groups:

- immutable `normative_source_editions`, `normative_rule_pack_editions`,
  `normative_rule_editions`, `normative_profile_editions` and typed membership;
- revision-owned `project_normative_bindings`, assessment contexts and roots;
- immutable `normative_validation_runs`, rule outcomes, findings and evidence;
- current pointers and selector/member dependency index;
- review/deviation events, authority evidence and disposition pointers.

Enforce project/revision scope in composite FK/guards; append-only records have
UPDATE/DELETE guards; pointer generations cannot reset or decrease. Published
editions are never edited to retire or revoke them: append lifecycle events.
Unknown legacy metadata is preserved as unverified, never backfilled as approved.

Freeze adds `electra.elv7-normative-freeze-section.v1` to the existing shared
revision transaction, independently bound to physical/power/discipline/layout
section hashes and the adopted normative manifest. Do not UPDATE the ELV4 v1
manifest or retrofit historical snapshots. Legacy missing ELV7 section returns
`ELV7_NOT_CAPTURED`; a new deliberately empty section is distinguishable.

Create-next restores mutable profile/context configuration with typed owner
remapping, including tombstoned roots/children under the shared atomic protocol.
It does not copy CURRENT compliance, immutable findings, receipts, reviews or
waivers into the new revision as valid results. Immutable referenced catalogue
editions may be reused; revision-owned evidence receives consistent new ownership.
R1 remains readable without R2/live sources/network.

## 10. Commands and public surface

The [command registry](command-registry.json) fixes the proposed project wire
surface; catalogue administration is a distinct governance surface. Both use
stable operation/schema versions. No second public freeze/create-next command.

Project envelope contains schema/operation/command ID, project/revision,
expected design/adoption/aggregate/pointer generations, normalized payload hash,
reviewed impact fingerprint and opaque actor evidence where policy requires it.
Server recomputes closures, authority and payload hashes. Client-supplied
`verified`, `compliant`, checker code or an arbitrary SQL/expression is rejected.

Initial typed errors: `ELV7_SCOPE_MISMATCH`, `PROFILE_EDITION_HASH_MISMATCH`,
`SOURCE_APPROVAL_REQUIRED`, `UNSUPPORTED_CHECKER_VERSION`,
`APPLICABILITY_UNRESOLVED`, `PRECEDENCE_CONFLICT`, `CAPTURE_STALE`,
`POINTER_GENERATION_CONFLICT`, `DESIGN_REVISION_READ_ONLY`,
`IMPACT_REVIEW_STALE`, `ACTOR_AUTHORITY_UNPROVEN`, `ENVELOPE_CONFLICT`.
Missing engineering facts normally become NOT_EVALUABLE findings rather than
transport exceptions. Corrupt identity/hash remains a storage/integrity error.

## 11. Performance and UX contract

Bulk capture and pointer verification chunk at ≤400 keys per SQLite query;
query complexity is O(chunks + owner projections), not O(rules × subjects).
Indexed pagination for findings, immutable DTOs and lazy provenance detail.
Bounded deterministic worker tasks run medium/large work off the Flutter UI
isolate (including a web-capable worker boundary), with cancellation, memory
limits and no partial publication. Initial qualification target: 10,000 subjects,
100,000 rule-target pairs, 1,000,000 dependency edges. Record hardware/OS/build,
peak memory, UI frame and capture/evaluate/publish percentiles; acceptance budgets
are approved in P0, not invented PASS numbers in a static registry.

Workspace separates B/C/D curve, RCD type, trip-time proof, normative applicability,
raw finding and review disposition. Show exact profile/date/source, missing facts,
worst-case limiting condition and affected circuit/host. Source/profile upgrade
has a read-only impact preview; review requires the current preview fingerprint.
Bulk reports include coverage gaps and every unresolved mandatory obligation.

## 12. Qualification and acceptance

Each rule family must pass Q0–Q9: source/domain authority, numerical dimensions,
applicability, precedence, negative/missing/boundary, metamorphic/fault cases,
real production persistence, CAS/replay/restart, freeze/create-next/historical,
and exact-SHA automated witness/provenance. Every witness binds exact path/name,
executed non-skipped result, checker/ruleset/source authority and persisted IDs.
Planned fixtures, source URLs, generated cardinality and design guard PASS do
not qualify runtime. Acceptance requires complete selected-scope coverage and
an exact-head CI evidence manifest; partial support stays explicit.
