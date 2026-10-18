# Shared handoff contract: physical facts, norms, products and selection

Status: DESIGN AGREEMENT. Schemas are proposed until producer/consumer runtime
qualification proves them. [Registry](interface-registry.json) is the wire-design
inventory, not a replacement for existing stage command schemas or domain models.

## 1. Ownership and acyclic publication

ELV6 owns canonical physical arrangement and measured LAY/safety evidence.
ELV7 owns applicable normative requirements, source authority and assessments.
The Equipment Catalogue owns reusable immutable product/definition/compatibility
editions and separate commercial offer books. ELV8 owns selection requests,
candidates/decisions, adoption orchestration, BOM/report composition and exports.
The project runtime owns accepted revision/command/history/freeze semantics.

Catalogue technical data extends existing ELV2/FL14 identities; it is not a second
physical, normative or selection model. ELV6 does not select a SKU, ELV7 does not
rewrite layout, and ELV8 repositories do not directly write their tables.

Two distinct exports prevent a dependency deadlock:

- **Requirements** describe known host/interface/space constraints and applicable
  typed normative obligations before the specific product is selected. Normative
  requirement derivation binds a profile/applicability/source proof, but does not
  require a PASS assessment of a not-yet-selected product. Unresolved applicability
  or an unknown mandatory requirement remains a blocker, not a missing filter.
- **Evidence** describes actual adopted facts and evaluated results. Only exact,
  current, complete, qualified evidence can satisfy the relevant validation gate.
  An ELV6 measurement is not normative PASS; a catalogue rating is not a layout
  result; a prior-product compliance run is not proof for its replacement.

The committed-data chain is requirements + exact product snapshot → explicit
adoption/application → owner facts/evaluations → ELV7 assessment → validated ELV8
selection closure → frozen project → report. There is no synchronous CURRENT
cycle in which ELV6 needs a validated ELV8 selection that itself needs ELV6 PASS.

A pure candidate sandbox may evaluate proposed definitions/arrangements through
versioned ELV6/ELV7 kernels before apply. It has `evaluationSpace=CANDIDATE`, an
immutable candidate hash and hypothetical subject mapping. Committed owner outputs
have `evaluationSpace=COMMITTED`. Candidate evidence never aliases an actual
CURRENT pointer and is never promoted merely by copying its PASS badge.

## 2. Common projection envelope

Every project-scoped handoff carries:

```text
schema / canonicalVersion
projectId / designRevisionId
scopeKey / scenarioKeys / typed subject refs
producerOwner / producerVersion / evaluationSpace
payloadHash / dependencyManifestHash
consumedRefs[] / generationTokens[] / selectorMembershipHash
freshness / completion / execution / assessment
```

`assessment` is typed by the specific projection, never one shared boolean.
Catalogue snapshots are project-neutral and instead carry publisher/namespace,
release/edition IDs, manifest hash, schema/codec versions and source/trust snapshot.
When adopted, the project capsule adds project/revision ownership and the exact
binding hash; global immutable catalogue identity is retained.

A consumed reference includes owner/schema, project/revision where applicable,
subject/scenario, evaluation/edition ID, payload/definition hash and pointer or
membership generation. An immutable catalogue edition uses a release membership
and lifecycle/trust token rather than a fictitious project CURRENT pointer.
Schemas declare mandatory/optional facts and units. Null/missing/unknown/zero,
empty-with-proof and not-applicable remain distinct. Unknown schema/codec/checker
fails closed for the dependent obligation; it cannot disappear from coverage.

No name/SKU matching for project identity; no `latest`, cross-revision fallback
or client-supplied trusted dependency closure. A generation change can invalidate
a result even when the semantic payload hash stays equal.

## 3. Stage result adapters

Preserve existing raw vocabularies and record a versioned adapter:

- ELV6 exports freshness/completion/execution/intrinsic assessment plus typed
  measurements and missing dimensions. Geometric success proves only its scope.
- ELV7 exports APPLICABLE / NOT_APPLICABLE / UNRESOLVED applicability; raw
  SATISFIED / VIOLATED / NOT_EVALUABLE / MANUAL_REVIEW; scope PASS / FAIL /
  BLOCKED / NOT_APPLICABLE and separate review/deviation disposition.
- ELV8 draft `UNKNOWN` candidate eligibility maps to shared `UNRESOLVED`;
  ELIGIBLE and INELIGIBLE retain meaning. All required hard constraints must be
  proven satisfied; a not-applicable constraint requires an exclusion proof.
- Commercial state PRICED / UNPRICED / EXPIRED / INCOMPARABLE is independent of
  technical eligibility. Missing price is never zero.

FAIL dominates a mandatory scope summary if any violation is proven; preserve
blocker counts as well. Waivers, USER_OVERRIDE and approved deviations never
turn mandatory legal/physical violations into compliant/VALIDATED results.
A source-authorized alternative/exemption must change applicability explicitly
with its own verified authority; it is not a badge override. Draft noncompliant
selection/report capture is possible only with visible blockers and project
policy; it cannot pass normal final publication gates.

## 4. Product adoption, configuration and multi-owner apply

Technical and commercial snapshots are independent. `electra-catalog.db` owns
publication/import; the existing project DB owns adoption copies and decisions.
No cross-file FK/ATTACH transaction is assumed atomic. Preserve legacy IDs,
selection snapshots and project FK anchors until a qualified migration replaces
them. Never enable two writable catalogue authorities after cutover.

Capture and verify complete product/definition/accessory/compatibility/offer
closure outside the project write UoW. Inside one shared project transaction:
replay first → WORKING/CAS/impact checks → copy immutable closure → invoke canonical
owner mutation participants → invalidate old/new closures → append history and
receipt/outbox → commit. A public owner dispatcher cannot start an independent
nested commit. P0 must provide same-UoW internal participants for ELV8 orchestration;
if any writer lacks that integration, full configuration apply is blocked.
Public owner commands remain valid independent use cases with the same semantics.

Trial results do not validate the applied design. Changed technical facts move
selection to PENDING_REVALIDATION, then real owner capture/evaluation and exact
ELV7 assessment establish a CURRENT closure. Unchanged technical selection may
retain qualified evidence only after proving matching ownership, identity,
scenario and every consumed hash/generation. A new price changes economic
proposals/reports only; it never silently replaces approved equipment.

Apply and catalogue publication use separate durable command boundaries. Report/
export jobs operate on immutable snapshots and may run after project freeze;
project WORKING mutation preconditions must not block read-only report generation.
Artifact jobs have idempotent job manifests and their own retryable publication
boundary; storage/cancellation faults cannot produce a false SUCCESS receipt.

## 5. Command namespaces: wire is not ledger

The shared public revision wire is exactly:

```text
schema: electra.elv4-revision-command.v2
FREEZE_DESIGN_REVISION
CREATE_NEXT_WORKING_DESIGN_REVISION
```

The freeze repository internally records ledger type
`FREEZE_PROJECT_DESIGN_REVISION`. This is **not** a public wire operation.
Each stage keeps its versioned envelope (for example ELV6
`expectedDesignRowRevision` versus ELV7 draft `expectedDesignRevision`) and
adapts to common revision/owner/generation preconditions internally. Do not rename
proven wire fields to make prose look uniform. Codec version changes require a
separate qualified migration, including history/replay.

ELV8 has no independent FreezeSelectionDecision command. Shared freeze captures
selection state through the existing coordinated revision boundary. Catalogue
import/publish/retire and normative source governance are distinct administrative
surfaces; neither can masquerade as an untrusted project mutation. Templates,
artifact generation and project selection are distinct command/job classes.

Do not add ELV6/7/8 section-intent fields to the strict v2 wire payload by stealth.
Owner sections are coordinated from server state and the established freeze
policy; if a new public intent is necessary, qualify a new codec version.

## 6. Invalidation agreement

Registry events define mandatory old/new selector closure behavior:

- technical definition, settings, physical geometry or accessory changes stale
  every actual consumer, including layout/thermal/normative and economic result;
- placement/opening/barrier/bonding/context changes stale affected physical or
  normative consumers, not unrelated price books;
- profile/rule/source-trust/review lifecycle changes stale corresponding normative
  constraints/assessments and dependent eligibility. A known source revocation or
  expiry applies without waiting for adoption of a newer edition;
- offer/stock/FX/rounding changes stale only consumed economic proposals/estimates;
- display-only labels do not change technical hashes; rendered label content may
  require a new report but never mutates its previously frozen model;
- additions/removals and previously empty/missing selectors participate, as do
  same-hash republish with changed generation and scoped trust validity.

P0 captures actual generation owners and source/current trust policy. No consumer
invents a freshness token for an unsupported producer.

## 7. Freeze, sections and report order

The existing ELV4 physical snapshot, power snapshot and v1 manifest are immutable.
ELV5 discipline, proposed ELV6 layout, ELV7 normative and ELV8 selection sections
are append-only independent extensions under the shared revision transaction.
They cross-bind the exact upstream section hashes required by their evidence.
The ELV8 section includes project-adopted product/offer/definition/compatibility
closure and selection state. The catalogue store owns no project freeze writer.

Section identity/status distinguishes NOT_CAPTURED (legacy), CAPTURED_EMPTY
(explicit scope proof), CAPTURED_PARTIAL and CAPTURED_COMPLETE. Capture of partial
engineering truth does not itself grant final-publication permission. Required
section absence, stale mandatory evidence or a noncompliant selection blocks
normal final dossier/compliance publication. Old revisions are never retrofitted.

Avoid a hash cycle: freeze the validated project/selection state first; then
assemble `ReportModel` and report-bundle manifest from that immutable snapshot.
The report manifest references the frozen root and section hashes; the frozen
root does not reference a not-yet-created report hash. Rendered artifact metadata
is appended in its own immutable artifact store and never edits frozen sections.
A renderer retry uses the same model/template/options and source snapshot.

Keep engineering model hash, canonical report hash, bundle hash and exact artifact
byte hash separate. Local/server PDF canonical content may agree while byte hashes
differ. Audience-redacted shares have their own manifest/hash and completeness
flags; they cannot claim to reproduce withheld commercial or licensed evidence.

Create-next remaps mutable project bindings/placements/selected configuration via
canonical typed owners. It retains immutable catalogue/source identities and
history, not CURRENT validation, expired quote freshness, receipts or approvals
as new valid results. Historical reads need no live catalogue/network.

## 8. Qualification and coordinated delivery

Cross-stage runtime entry requires accepted producer contracts for each consumed
schema, exact adapters, supported migrations, same-UoW mutation participants,
working source/trust invalidation, frozen-section readers and actual public
wire/codecs. Independent design and pure kernels may proceed earlier; missing
producer evidence remains an explicit runtime blocker for dependent rules.

The [qualification plan](qualification-plan.json) is PLANNED only. Acceptance
needs non-skipped production persistence/command witnesses on exact source SHAs,
including old ELV4/FL14 regressions, all affected ELV5/6/7/8 owners, rollback/CAS/
restart/freeze/historical/fault suites and scope/source provenance. Same shared
agreement hash on three design branches proves alignment, not runtime acceptance.


## 9. Source-system specialization

[Generator/PV/storage/transfer](source-systems-contract.md) supplies a versioned
source-domain specialization of this agreement. Its four electrical producer
projections do not replace the nine stage interfaces, add LAY processes or grant
AC simulation capability to existing ELV4 DC/PoE models. Per-mode source/site
proofs enter the same dependency/CAS/freeze protocol. Missing required electrical
producer, scenario or authority blocks only its dependent scope; full-source
configuration acceptance cannot ignore that gap.
