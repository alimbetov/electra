# Electra — ELV8 Equipment Selection and Deliverables Design Specification

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv8-deliverables-design`
Pinned upstream ELV7: `6d7aef8349dc04526a3beba16b2e2483bec0009e`
Entry: [authoritative index](elv8-authoritative-spec-index.md).

## 1. Purpose

ELV8 closes the engineering chain from requirements to exact equipment choices and reproducible project deliverables. It must answer:

- which exact manufacturer catalog edition was used;
- which hard requirements were applied to a selection request;
- why each candidate passed or failed hard filtering;
- how surviving candidates were ranked and why one was selected;
- what accessories/configuration items are mandatory for a valid candidate;
- whether the selected product changes any upstream physical/power/normative facts;
- whether revalidation has completed after selection;
- which exact selection, validation and template versions produced a BOM/schedule/report;
- whether the same frozen revision can reproduce the same canonical deliverable bundle and hashes.

ELV8 is not procurement, dynamic distributor pricing or a hidden auto-redesign engine.

## 2. Ownership and upstream reuse

| Owner | ELV8 consumes | ELV8 must not duplicate |
|---|---|---|
| ELV2 | canonical component/definition identity and edition semantics | mutable copies of definitions or latest-edition fallback |
| ELV3 | realized cable/run/pathway quantities and identities | route/length/allocation calculation |
| ELV4 | exact power/PoE/UPS/battery requirements/evidence | power sizing algorithms |
| ELV5 | exact discipline requirements/evaluations | CCTV/LAN/ACS/Fire calculations |
| ELV6 | enclosure/rack/layout capacity/fit projection | placement solver/layout source of truth |
| ELV7 | normative profile, outcomes, hard constraints, deviations | compliance reinterpretation |
| Shared runtime | revision/freeze, command replay/history/UoW, immutable snapshots, file metadata | parallel project lifecycle |

ELV8 owns manufacturer catalog metadata/cache, selection requests/candidates/decisions, selection revalidation state and canonical deliverable snapshots/manifests.

## 3. Manufacturer catalog model

### 3.1 Stable identities

Conceptual IDs:

```dart
typedef ManufacturerCatalogId = String;
typedef CatalogEditionId = String;
typedef CatalogProductId = String;
typedef CatalogProductRevisionId = String;
typedef ProductConfigurationId = String;
typedef SelectionRequestId = String;
typedef SelectionDecisionId = String;
typedef DeliverableBundleId = String;
typedef DeliverableTemplateEditionId = String;
```

A product code/SKU string is data, not the stable database identity. A corrected technical record creates a new catalog/product revision when semantic selection behavior can change.

### 3.2 Catalog edition

`CatalogEdition` is immutable after publication:

```text
catalogId
editionId
manufacturerId
editionName/version
publishedAt?
effectiveFrom?
effectiveUntil?
sourceRef
sourceHash?
importSchemaVersion
verificationStatus
canonicalHash
status: DRAFT | PUBLISHED | RETIRED
```

Historical selections retain their edition even after retirement.

### 3.3 Product technical record

`CatalogProduct`/revision contains typed technical capabilities needed by selection and upstream impact analysis. Typical dimensions are domain-dependent and may include:

```text
manufacturerPartNumber
productFamily
productKind
technicalCapabilitySet
physicalEnvelopeMm / mass / mounting capabilities
power input/output capabilities
PoE capabilities
ports/interfaces/media categories
capacity/channel/address limits
environmental ratings
battery/accessory compatibility
rack/DIN/shelf mounting data
required accessory rules
incompatible configuration rules
vendor-document refs/hashes
lifecycle status
```

No selection-critical number may exist only inside a PDF description string. If a required fact is not structured, the candidate is `UNKNOWN` for that hard constraint.

Large datasheets/images remain file/blob resources. The DB keeps metadata and hashes.

### 3.4 Product configuration

A selectable solution may contain a primary product plus mandatory modules, power supplies, transceivers, batteries, mounting kits or licenses. Represent this as `ProductConfigurationCandidate`, not by pretending one SKU has every capability.

A configuration records:

```text
primaryProductRevisionRef
component/accessory refs with quantities
compatibility-edge evidence
resolved technical capability projection
configuration fingerprint/hash
```

Configuration building is deterministic and bounded. Cyclic accessory requirements are rejected.

## 4. Requirement projection and selection request

`SelectionRequest` is an immutable capture of exact upstream requirements for one logical selection subject.

```text
requestId
projectId
revisionId
subjectRef
requirementProjectionVersion
upstreamEvidenceManifest/hash
hardConstraints
softPreferences
eligibleCatalogEditionRefs
selectionPolicyEditionId
createdAt
```

### 4.1 Constraint classes

`SelectionConstraint` minimum:

```text
constraintId
sourceOwnerStage
sourceEvidenceRef / ruleRef
field/path
operator
requiredValue/range/set
unit?
obligation: HARD | SOFT
missingCandidateFactPolicy
```

Hard constraints originate from engineering minima, exact compatibility requirements and applicable normative requirements. Soft preferences may encode preferred manufacturer/family, spare capacity, footprint preference or standardized project choices.

Hard versus soft is not inferred from UI wording.

### 4.2 Missing candidate fact

For a hard constraint, missing candidate data cannot be treated as pass. Outcome is `UNKNOWN_HARD_FACT` and the candidate is excluded from compliant candidate set unless an explicit policy allows manual noncompliant review. Such candidate can never be reported compliant without resolving evidence.

## 5. Candidate evaluation

Each candidate/configuration gets a structured result:

```text
candidateId
configurationHash
hardConstraintResults
hardEligibility: ELIGIBLE | INELIGIBLE | UNKNOWN
softScoreBreakdown
impactPreview
explanations
stableSortKey
```

Hard filter executes before soft scoring.

### 5.1 Hard result

Per hard constraint:

```text
SATISFIED
VIOLATED
UNKNOWN
NOT_APPLICABLE
```

All required applicable hard constraints must be `SATISFIED` for `ELIGIBLE`.

### 5.2 Soft ranking

Ranking uses a versioned `SelectionPolicyEdition` with named criteria, normalization and weights. The engine must expose each score contribution. Tie-breaking uses stable product/configuration IDs, never load order.

Identical request + exact catalog editions + exact policy edition + engine version must produce identical ordered candidates.

No machine-learning black-box ranker is authoritative for initial ELV8 qualification. A future advisory model may propose candidates, but final eligibility/ranking must remain reproducible and explainable.

## 6. Selection decision state machine

A selected candidate is not immediately “closed”. Required lifecycle:

```text
DRAFT
SELECTED_PENDING_IMPACT
PENDING_REVALIDATION
VALIDATED
NONCOMPLIANT_OVERRIDE
FROZEN
STALE
SUPERSEDED
```

Suggested flow:

1. capture requirements/catalog/policy;
2. evaluate candidates;
3. engineer selects one eligible configuration;
4. generate exact technical impact projection;
5. if selected technical facts differ from assumptions used upstream, mark `PENDING_REVALIDATION` and schedule/require explicit affected-stage recalculation/validation through owner commands;
6. after exact ELV4/ELV5/ELV6/ELV7 evidence closes against the selected configuration, mark `VALIDATED`;
7. only validated selection can become normal `FROZEN` deliverable input;
8. later upstream/catalog change marks current selection stale without deleting its history.

This breaks cyclic dependencies deliberately. ELV8 does not call itself recursively through upstream recalculation.

## 7. Candidate impact projection

`SelectionImpactProjection` identifies candidate technical facts that can change earlier conclusions:

```text
subjectRef
selectedConfigurationHash
physical envelope/mounting delta
power/load/source capability delta
port/interface/capacity delta
battery/accessory delta
environmental/rating delta
normative fact delta
affected owner stages/processes/rules
```

Before acceptance UI shows impact. Accepting a candidate may create/update only the ELV8 selection binding. Any upstream canonical binding/adoption needed for exact product technical facts is executed through the authoritative owner command surface with reviewed impact.

No direct database writes into ELV2–ELV7 tables from an ELV8 repository are allowed.

## 8. Noncompliant/manual override

An engineer may need to record a product choice that does not satisfy current hard requirements. This is modeled explicitly:

```text
selection status = NONCOMPLIANT_OVERRIDE
reason
actor/time
violated/unknown hard constraint refs
required ELV7 deviation/manual-review refs
```

The product may appear in a draft deliverable marked noncompliant if project policy permits, but a normal compliant/final publication cannot hide this state.

Soft ranking can be overridden freely with reason/history because all hard constraints are still satisfied. Hard-constraint override requires the noncompliant path.

## 9. Catalog import and governance

Catalog imports are untrusted input. Import pipeline:

1. validate schema/version;
2. normalize units/enums;
3. validate stable manufacturer/product keys;
4. reject malformed numbers, duplicate conflicting product identities and cyclic configuration rules;
5. generate canonical hashes;
6. produce import diagnostics;
7. publish immutable edition only after required review.

Importer cannot execute vendor scripts/macros. External URLs are metadata. Remote fetching, if added, occurs outside engineering core and yields a validated local artifact before import.

## 10. Canonical deliverable model

All output formats consume one immutable `DeliverableBundle` assembled from a frozen project snapshot.

Minimum bundle metadata:

```text
bundleId
projectId
revisionId
bundleSchemaVersion
sourceSnapshotHash
ELV2–ELV7 evidence manifest/hashes
selected catalog edition hashes
selection snapshot hash
normative profile + validation run hash
template edition/hash
locale/unit presentation settings
generatedAt
canonicalBundleHash
```

### 10.1 Canonical sections

Initial bundle supports at least:

- project/revision metadata;
- equipment schedule;
- engineering BOM quantities;
- cable schedule;
- enclosure/rack layout schedule and references;
- power/capacity calculation summary references;
- CCTV/LAN/ACS/Fire calculation summary references;
- normative validation/compliance matrix;
- open/manual/deviation summary;
- selected product/configuration rationale;
- source/catalog/template manifest;
- document/revision issue metadata.

The canonical bundle contains data, not renderer-specific widget objects.

## 11. BOM semantics

Engineering BOM and commercial estimate are separate.

`BomLine` conceptually:

```text
lineId
productRevisionRef
configuration/component role
quantity
unit
sourceSubjectRefs
selectionDecisionRefs
spare/reserve classification?
notesCode?
traceabilityRefs
stableSortKey
```

Quantities are derived from exact selected configurations and project demand. Unit price, currency, vendor quote, tax and procurement status are outside core ELV8 BOM unless a separate estimate/procurement module is explicitly introduced.

Same product/configuration may aggregate into one BOM line only if traceability to contributing subjects remains recoverable.

## 12. Equipment and cable schedules

Each row is canonical, deterministic and traceable.

`EquipmentScheduleRow` includes logical project equipment identity, selected manufacturer/product revision, technical summary fields, location/enclosure refs and selection state.

`CableScheduleRow` references ELV3 cable/run identity and may include route length, cable definition, endpoints, enclosure entries and derived technical metadata. ELV8 never recomputes route length.

Stable sorting is defined in the bundle schema; exporters cannot choose arbitrary row order that changes hashes/review diffs.

## 13. Layout and validation sections

Enclosure/rack deliverable rows reference ELV6 frozen layout projection/hash. Renderer may generate front/rear diagrams from canonical coordinates, but must not mutate layout.

Compliance matrix references ELV7 exact profile edition, validation run, rule/finding identities, source refs and disposition state. If ELV7 is stale/blocked, the deliverable status must expose that condition.

## 14. Template model

`DeliverableTemplateEdition` is immutable after publication and contains declarative presentation/layout configuration:

```text
templateId / editionId
templateSchemaVersion
supported bundle schema range
branding metadata
page/section definitions
field mappings
formatting rules
canonicalHash
```

Templates cannot execute arbitrary Dart/JavaScript/shell code. Unsupported/missing field mapping is a renderer error, not permission to read live DB state.

## 15. Snapshot and publication

Deliverable generation follows:

1. verify project revision/freeze state required by publication policy;
2. verify required selection decisions and ELV7 state;
3. capture exact upstream/selection/template manifest;
4. assemble canonical bundle through repository/query ports;
5. validate bundle schema and traceability completeness;
6. compute canonical hash;
7. persist immutable bundle snapshot + manifest;
8. render one or more export formats from that snapshot;
9. persist generated-file metadata/hash linked to bundle;
10. never re-open mutable project state during renderer execution.

A renderer retry must use the same bundle snapshot.

## 16. Exporter boundary

Pure application/core boundary:

```dart
abstract interface class DeliverableExporter {
  String get exporterId;
  String get exporterVersion;
  Future<ExportArtifact> export(DeliverableBundle bundle, ExportOptions options);
}
```

Initial target adapters:

- canonical JSON for machine exchange/debug/reproducibility;
- CSV for BOM and tabular schedules;
- PDF project report/sheets using an approved rendering adapter;
- future XLSX/DXF/other adapters without changing canonical engineering truth.

PDF implementation may be local or backend-assisted, but the export contract and bundle are identical. Offline-capable export remains a product requirement for supported local formats.

## 17. Persistence

Proposed normalized Drift family:

```text
manufacturer_catalog
manufacturer_catalog_edition
catalog_product
catalog_product_revision
catalog_product_capability
catalog_product_compatibility
catalog_configuration_rule
project_catalog_binding
selection_policy_edition
selection_request
selection_constraint
selection_candidate_snapshot
selection_candidate_result
selection_decision
selection_decision_component
selection_impact_ref
selection_revalidation_ref
deliverable_template
deliverable_template_edition
deliverable_bundle_snapshot
deliverable_bundle_manifest_ref
deliverable_export_artifact
```

Requirements:

- immutable published catalog/template editions;
- exact project/revision and catalog/profile hashes;
- candidate snapshots may be immutable large derived records; current pointers are guarded;
- selected decisions/history never overwritten;
- generated large files stored outside DB with path/object key/hash/size/MIME metadata;
- indexes by product part number, family/kind, capability keys needed for filtering, project/revision/subject, selection state and bundle;
- no live price columns inside engineering BOM source of truth.

## 18. Commands

Proposed public command families:

```text
ImportCatalogEdition
PublishCatalogEdition
RetireCatalogEdition
BindProjectCatalogEdition
ReleaseProjectCatalogEdition
CreateSelectionRequest
EvaluateSelectionRequest
SelectEquipmentCandidate
OverrideSoftSelection
RecordNoncompliantSelection
RecordSelectionRevalidation
FreezeSelectionDecision
SupersedeSelectionDecision
CreateDeliverableTemplateEdition
PublishDeliverableTemplateEdition
AssembleDeliverableBundle
ExportDeliverableBundle
```

Administrative catalog/template publication may later move to backend governance; project use of already available editions remains offline-capable.

Every project mutation uses existing command replay/history/UoW semantics. Long-running rendering is not held inside one database write transaction; immutable bundle publication precedes rendering.

## 19. Code boundaries

Expected shape:

```text
packages/engineering_core/lib/src/elv8/
  catalog/
  requirements/
  selection/
  configuration/
  bom/
  deliverables/

apps/mobile/lib/application/
  elv8_catalog_repository.dart
  elv8_selection_repository.dart
  elv8_selection_command_service.dart
  elv8_deliverable_repository.dart
  elv8_deliverable_assembler.dart
  elv8_export_service.dart
  elv8_workspace_controller.dart

apps/mobile/lib/data/repositories/
  drift_elv8_catalog_repository.dart
  drift_elv8_selection_repository.dart
  drift_elv8_deliverable_repository.dart
```

Candidate hard filtering/scoring/configuration resolution belongs in pure Dart. Export adapters may depend on platform/file/PDF packages outside engineering core.

## 20. Selection workspace UX

Required UX:

- exact subject requirements and their ELV2–ELV7 source refs;
- exact catalog editions in scope;
- candidate table with hard eligibility before score;
- per-constraint pass/fail/unknown diagnostics;
- explainable soft score breakdown;
- configuration/accessory tree and resolved capabilities;
- compare candidates;
- exact impact preview on power/layout/normative evidence;
- explicit select/override/revalidate/freeze actions;
- stale/pending-revalidation/noncompliant states clearly separated;
- read-only historical/frozen decision view.

A candidate with unknown/violated hard constraints cannot be visually presented as a normal recommended compliant choice.

## 21. Deliverables workspace UX

Required capabilities:

- bundle readiness gate showing blocking stale/noncompliant/manual states;
- select published template edition;
- preview canonical section data before render;
- trace any row back to selection/upstream source;
- deterministic diff between bundle snapshots;
- export format/options selection;
- generated artifact metadata/hash/history;
- regenerate renderer output from the same immutable bundle;
- clear distinction between draft and final/frozen publication.

## 22. Stale and dependency semantics

Targeted invalidation:

- catalog edition replacement does not alter historical selection; an explicit project binding/adoption can mark affected current selection requests stale;
- upstream requirement change invalidates requests/decisions consuming it;
- selected product technical correction/new revision never rewrites old selection, but may require a new decision;
- ELV7 finding/profile change invalidates dependent selection constraints and deliverable compliance sections;
- ELV6 layout change invalidates relevant location/layout rows and possibly candidate fit;
- template-only change invalidates rendered deliverables, not engineering selection;
- price/quote changes, if future commercial module exists, must not invalidate engineering calculations unless technical product identity changes.

## 23. Freeze and historical reproduction

A frozen project revision captures:

- exact selection decisions/configuration hashes;
- exact catalog editions/product revisions;
- ELV7 profile/run refs;
- ELV6 layout hash;
- ELV4/ELV5 calculation refs required by report;
- template edition for each published bundle;
- canonical bundle hash and artifact hashes.

Historical reading never resolves current/latest product or template data.

Pre-ELV8 revisions return `ELV8_NOT_CAPTURED`, not an empty BOM interpreted as complete.

## 24. Acceptance requirements

Runtime closure requires at least:

1. catalog import normalization and malformed-data rejection;
2. immutable published catalog edition and historical read proof;
3. hard filter `SATISFIED/VIOLATED/UNKNOWN` fixtures;
4. missing hard candidate fact cannot pass;
5. deterministic candidate ordering/hash for identical input;
6. stable tie-break proof independent of DB insertion/load order;
7. accessory/configuration resolution positive and cycle rejection fixtures;
8. no-candidate diagnostic fixture;
9. soft override remains hard-compliant and audited;
10. noncompliant override is visibly noncompliant and requires disposition;
11. selection impact triggers `PENDING_REVALIDATION` when required;
12. upstream revalidation closure before normal freeze;
13. stale selection after upstream fact mutation;
14. command replay/idempotency/rollback/restart proof;
15. R1 frozen selection remains reproducible after R2 catalog/project changes;
16. canonical BOM quantity/traceability proof;
17. engineering BOM has no mandatory price dependency;
18. canonical bundle assembly deterministic hash proof;
19. exporter renders only from immutable bundle snapshot;
20. renderer retry produces artifact from same bundle without live DB read;
21. JSON/CSV export fixtures; PDF adapter golden/structural qualification when implemented;
22. stale/blocked ELV7 state visible in deliverable readiness;
23. template edition upgrade is explicit and historical bundle unchanged;
24. large-file metadata/hash persistence and missing-artifact handling;
25. project-scale candidate filtering/bundle/export performance budget.

## 25. Security and trust boundaries

- catalog/template imports are untrusted structured data;
- no imported scripts/macros are executed;
- file names/paths from external data are sanitized by adapters;
- output paths cannot escape project/export sandbox;
- vendor documents retain provenance/hash and are not authoritative structured capability data unless imported/verified;
- exporter input is canonical bundle only;
- generated artifacts record exporter/version/options/hash;
- selection explanations cannot conceal failed/unknown hard constraints.

## 26. Explicit non-goals

ELV8 does not own:

- live distributor inventory/price scraping;
- purchase orders, payment, tax or procurement workflow;
- automatic substitution without engineer review;
- hidden weakening of normative/engineering requirements;
- direct mutation of ELV2–ELV7 database tables;
- arbitrary executable document templates;
- full BIM/CAD authoring;
- legal certification beyond exactly recorded ELV7 evidence.

Future procurement/estimate integrations must remain downstream of the engineering BOM and preserve its quantity/source provenance.