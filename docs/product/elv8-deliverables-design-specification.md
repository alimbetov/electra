# Electra — ELV8 Equipment Selection and Deliverables Design Specification

Status: DESIGN DRAFT / INHERITED FL14 BASELINE PRESENT / ELV8 CLOSURE NOT STARTED
Branch: `feat/flutter-elv8-deliverables-design`
Pinned upstream ELV7 at branch creation: `6d7aef8349dc04526a3beba16b2e2483bec0009e`
Entry: [authoritative index](elv8-authoritative-spec-index.md).
Baseline ADRs: [ADR-021](../adr/ADR-021-manufacturer-catalog-mapping.md), [ADR-025](../adr/ADR-025-report-bom-estimate-generation.md).

## 1. Purpose

ELV8 closes the engineering chain from exact requirements to reviewed product selections and reproducible project documents. It must answer:

- which exact manufacturer catalog/version and product technical snapshot were used;
- which hard requirements each candidate satisfied, violated or could not evidence;
- how eligible candidates were ranked and why one was selected;
- what accessory/configuration components are required;
- whether a selected product changes upstream physical/power/capacity/normative facts;
- whether required upstream revalidation is complete;
- which exact selection/validation/template/snapshot versions produced BOM/schedules/report;
- whether a frozen revision can reproduce equivalent canonical report content and artifact hashes.

ELV8 is not procurement, live distributor pricing or a hidden auto-redesign engine.

## 2. Existing manufacturer-selection runtime is authoritative baseline

The repository already implements the FL14 electrical manufacturer-selection baseline:

```text
FunctionalDeviceRequirement
ManufacturerProductVariant
ManufacturerCatalog
ProjectManufacturerPolicy
ManufacturerMatch
ManufacturerProductMatcher
ManufacturerRepository
DriftManufacturerRepository
manufacturer_screen.dart
manufacturer matching/persistence tests
```

`ManufacturerProductMatcher.algorithmVersion == fl14-strict-product-match-v1` is an existing semantic contract. Current matching includes role/lifecycle/project policy and typed electrical requirements such as current, voltage, breaking capacity, poles, trip/residual characteristics, module width, mounting type and AC/DC kind. Current deterministic ranking uses manufacturer/series preference then manufacturer/SKU/ID ordering.

Current Drift behavior already provides important guarantees that ELV8 must preserve unless a separately qualified migration supersedes them:

- catalog ID/manufacturer/version/source/products required;
- product IDs/SKUs unique within catalog;
- product IDs cannot be reused across catalog versions;
- catalog version payload is immutable after import;
- manufacturer/version/region duplicate rejection;
- archived catalogs retain historical selection snapshots;
- project manufacturer policy is persisted/versioned;
- circuit product selection stores product snapshot, requirement fingerprint and policy JSON;
- selection is rejected when requirement changed/stale;
- dependency recalculation runs after policy/selection changes.

ELV8 is therefore a **generalization/hardening** of this baseline from electrical-protection circuit selection to all supported ELV selection subjects. It is not permission to replace the FL14 model with differently named parallel tables/classes.

## 3. Accepted reporting architecture is authoritative baseline

ADR-025 already defines:

```text
PublishedProjectSnapshot
       ↓
ReportAssembler
       ↓
ReportModel
       ├── drawings / schedules
       ├── panel/DIN/terminal/I/O data
       ├── cable schedules
       ├── BOM
       ├── estimate (when supplied by separate pricing layer)
       ├── issues / validation
       └── engineering decisions
       ↓
PDF Renderer
       ↓
Document artifact
```

It also requires traceable quantity takeoff, engineering BOM separated from prices, deterministic report version metadata, local offline rendering and optional server rendering from immutable snapshots.

ELV8 preserves `ReportAssembler` + canonical `ReportModel`. A new `DeliverableManifest`/`ReportBundleSnapshot` may wrap the model with provenance/hash/template/export metadata, but **must not become a second independent report content model**.

## 4. Ownership and nonduplication

| Owner/baseline | ELV8 consumes / extends | ELV8 must not duplicate |
|---|---|---|
| FL14 / ADR-021 | functional requirements, catalog/product/policy/matcher/selection snapshot | second manufacturer catalog/product truth |
| ADR-025 | `PublishedProjectSnapshot`, `ReportAssembler`, `ReportModel`, BOM/estimate boundary | competing canonical report model |
| ELV2 | canonical definitions/edition semantics | mutable duplicate definitions |
| ELV3 | realized cable/run/pathway quantities | route/length/allocation calculation |
| ELV4 | power/PoE/UPS/battery evidence | power sizing algorithms |
| ELV5 | discipline requirements/evaluations | CCTV/LAN/ACS/Fire algorithms |
| ELV6 | enclosure/rack/layout fit projection | layout solver/source of truth |
| ELV7 | normative profile/outcomes/hard constraints/deviations | compliance reinterpretation |
| Shared runtime | revision/freeze, command replay/history/UoW, immutable snapshots, files | parallel project lifecycle |

ELV8 owns new generic selection request/evaluation/decision state where the FL14 circuit-specific model is insufficient, selection impact/revalidation evidence, canonical report-manifest snapshots, template editions and export artifact metadata.

## 5. Manufacturer catalog evolution

### 5.1 Preserve existing names and identities

Initial ELV8 implementation reuses:

```text
ManufacturerCatalog
ManufacturerProductVariant
ProjectManufacturerPolicy
FunctionalDeviceRequirement
ManufacturerProductMatcher
```

P0/P1 define compatibility-safe extension points. Do not introduce `CatalogProduct` or `CatalogEdition` as competing roots merely for naming consistency.

A published/imported catalog version remains identified by current catalog identity/version/region/source semantics. If ELV8 requires an additional immutable edition ID/hash, add it as an extension/migration that preserves current catalog IDs and historical snapshots.

### 5.2 Product capability extension

`ManufacturerProductVariant` must become capable of representing ELV domains beyond current electrical protection while preserving current fields/codecs. Extension may include typed capability facets, for example:

```text
physical envelope / mass / mounting capabilities
power input/output / PoE capabilities
ports/interfaces/media
network/channel/address/capacity limits
CCTV/storage/controller capabilities
environmental classifications
battery/accessory compatibility
rack/DIN/shelf mounting facts
required accessory/configuration rules
vendor-document refs/hashes
```

A selection-critical value cannot exist only in display prose/PDF. Missing structured fact remains unknown for the related hard constraint.

Prefer typed domain facets/versioned capability codecs over an unbounded `metadata` map for selection-critical semantics. Existing `metadata` remains readable for backward compatibility but is not sufficient evidence for new mandatory rules unless a versioned adapter explicitly defines it.

### 5.3 Product configuration

ELV8 adds a deterministic configuration layer where one purchasable solution requires multiple products/accessories:

```text
ProductConfigurationCandidate
- primary ManufacturerProductVariant ref
- required accessory/product refs + quantities
- compatibility-edge evidence
- resolved capability projection
- configuration fingerprint/hash
```

Examples include transceivers, PSUs, batteries, rack kits, modules and licenses. Cyclic configuration requirements are rejected. Configuration does not flatten multiple SKUs into a fake single product.

## 6. Requirement projection and generic selection request

The current `FunctionalDeviceRequirement` remains valid for the existing protection vertical. ELV8 introduces an owner-neutral immutable selection request around exact upstream requirements rather than replacing it.

Conceptual request:

```text
SelectionRequest
- requestId
- projectId
- revisionId
- subjectRef
- requirementKind / schemaVersion
- upstream evidence manifest/hash
- hardConstraints[]
- softPreferences[]
- eligible ManufacturerCatalog refs/versions
- selectionPolicyVersion
- legacyRequirementRef?       // e.g. FunctionalDeviceRequirement adapter
- createdAt
```

### 6.1 Hard versus soft constraints

Hard constraints come from:

- exact engineering minima/capabilities from ELV2–ELV6;
- product/configuration compatibility;
- applicable ELV7 mandatory/contractual constraints;
- explicit project allowlists that are intentionally hard policy.

Soft preferences come from ranking policies such as preferred manufacturer/series, spare capacity, footprint or standardization goals.

The current `ProjectManufacturerPolicy.allowedManufacturers`/`requiredRegion` hard behavior and `preferredManufacturers`/`preferredSeriesByRole` ranking behavior are preserved through adapters.

### 6.2 Missing candidate fact

For an applicable hard constraint:

```text
SATISFIED
VIOLATED
UNKNOWN
NOT_APPLICABLE
```

Missing mandatory candidate data => `UNKNOWN`; it is never compatible by omission.

## 7. Existing matcher version and new selection engine

`fl14-strict-product-match-v1` must remain replayable/testable for legacy protection selection. Do not alter its comparison semantics under the same version string.

ELV8 can add a new generic engine, for example `elv8-selection-v1`, which consumes structured constraints and can adapt legacy v1 results.

Required candidate result:

```text
candidate/configuration ref
hardConstraintResults[]
hardEligibility: ELIGIBLE | INELIGIBLE | UNKNOWN
softScoreBreakdown[]
legacyMatcherEvidence?
impactPreview
stableSortKey
canonicalEvaluationHash
```

Hard filtering precedes soft ranking. A score can never compensate for hard violation/unknown.

### 7.1 Explainable ranking

A versioned selection policy exposes named criteria, normalization/weights and tie-break rules. Existing FL14 manufacturer/series preference ordering is an inherited v1 ranking basis for applicable legacy requests.

Identical request + catalog versions + policy + engine versions produces identical canonical candidate order independent of DB row/load order.

No black-box ML model is authoritative for initial ELV8 selection. A future ML assistant may suggest candidates but cannot bypass deterministic hard validation.

## 8. Selection decision lifecycle and controlled feedback loop

The current circuit selection snapshot stores product, requirement fingerprint and policy snapshot. ELV8 generalizes that to a stateful decision without rewriting historical current rows in place.

Target lifecycle:

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

Flow:

1. capture exact requirement/catalog/policy;
2. evaluate deterministic candidates;
3. engineer selects an eligible candidate/configuration;
4. capture exact product technical snapshot and impact projection;
5. if selected facts differ from assumptions consumed by ELV4/5/6/7, mark `PENDING_REVALIDATION`;
6. invoke affected stages only through their authoritative command/application boundaries;
7. collect new exact evidence refs/fingerprints;
8. when closure is current and acceptable, mark `VALIDATED`;
9. freeze only an acceptable validated selection under normal publication policy;
10. later requirement/catalog/profile changes mark current decision stale without deleting history.

This replaces hidden cycles with an explicit convergence protocol. The existing `engine.recalculate(projectId)` behavior is inventoried in P0 and adapted; ELV8 must not introduce recursive “selection → silent upstream mutation → selection” loops.

## 9. Selection impact projection

Capture candidate facts that can invalidate earlier stages:

```text
selected product/configuration fingerprint
physical envelope / mounting delta
power/load/source capability delta
port/interface/capacity delta
battery/accessory delta
environmental/rating delta
normative fact delta
affected owner stages/processes/rules
```

ELV8 repository code may not directly update ELV2–ELV7 tables. Owner changes are explicit commands/use cases with reviewed impact.

## 10. Overrides and disposition

### 10.1 Soft override

Engineer may select another **hard-eligible** candidate regardless of soft rank. Record reason/actor/time and retain candidate-evaluation evidence. It remains technically compliant.

### 10.2 Hard noncompliant selection

A violated/unknown hard requirement can be recorded only as explicit `NONCOMPLIANT_OVERRIDE` when project policy permits draft recording.

Required disposition reference is owner-specific:

```text
ConstraintDispositionRef
- sourceOwnerStage
- constraint/evidence ref
- disposition kind/ref
- status/fingerprint
```

Examples:

- ELV7 normative violation → approved ELV7 deviation where legally/project-policy permissible;
- engineering requirement from ELV4/5/6 → explicit authoritative engineering override/change workflow if such a workflow exists;
- unresolved mandatory technical fact with no valid owner disposition → remains blocking.

An ELV7 deviation is **not** a universal mechanism for non-normative engineering violations. A noncompliant selection may appear in draft documents with clear status but cannot be rendered as normal compliant/final without all required dispositions.

## 11. Catalog import/governance hardening

Current `DriftManufacturerRepository.importCatalog()` already enforces immutable version payloads, identity/SKU uniqueness, source/manufacturer consistency and product validation. P1 extends rather than replaces it.

Additional ELV8 gates for new capability/configuration data:

1. schema/version validation;
2. canonical unit/enum normalization;
3. structured capability codec validation;
4. duplicate/conflicting identity rejection;
5. compatibility/configuration cycle detection;
6. canonical content hashes;
7. import diagnostics/provenance;
8. explicit published/retired lifecycle if added.

Imported vendor scripts/macros are never executed. URLs are metadata. Remote retrieval, if added, is outside engineering core and must yield validated local input before import.

## 12. Canonical reporting and deliverable envelope

ELV8 follows ADR-025 exactly:

```text
PublishedProjectSnapshot
    ↓
ReportAssembler
    ↓
ReportModel              // canonical engineering report content
    ↓
renderer/export adapters
```

ELV8 may persist an immutable envelope:

```text
ReportBundleSnapshot
- bundleId
- projectId / revisionId
- reportModelSchemaVersion
- publishedProjectSnapshotId/hash
- ELV2–ELV7 evidence manifest/hashes
- manufacturer catalog/version hashes
- selection snapshot hash
- ELV7 profile/run hash
- report template edition/hash
- locale/unit presentation profile
- assembledAt
- canonical ReportModel hash
- bundle/manifest hash
```

The envelope does not duplicate report section content. Exporters consume `ReportModel` plus immutable manifest/options.

## 13. ReportModel content for ELV8

ADR-025 content remains valid and ELV8 adds ELV-specific sections through a versioned schema. Minimum supported engineering content includes:

- project/revision summary;
- equipment schedule;
- cable schedule;
- route/pathway schedule/drawings where available;
- panel/rack/enclosure layout schedules and drawings;
- power/capacity summary references;
- CCTV/LAN/ACS/Fire calculation summaries;
- engineering BOM;
- ELV7 validation/compliance matrix;
- manual review/deviation/open issue summary;
- selected manufacturer products/configurations and rationale;
- source/catalog/profile/template manifest;
- document/revision issue metadata;
- optional estimate section **only when supplied by the separate PriceBook/estimate layer**.

Renderer-specific widget/layout objects are not engineering truth.

## 14. BOM and quantity takeoff

Preserve ADR-025:

```text
engineering objects/selections/routes/panels/supports/terminals
    ↓
QuantityTakeoff
    ↓
BOM
```

A BOM line conceptually contains:

```text
lineId
ManufacturerProductVariant/configuration component ref
quantity
unit
source subject refs
selection decision refs
reserve/spare classification?
technical description code/data
stable sort key
```

Aggregation is allowed only while drill-down to contributing project entities remains recoverable.

Engineering quantity is independent from price. PriceBook, currency, material/labor rate, tax, vendor quote and price date belong to the estimate/commercial layer (FL18 boundary). Changing prices must not invalidate engineering selection/geometry/calculations.

## 15. Schedules and traceability

`EquipmentScheduleRow` references logical project equipment + exact selected product snapshot + location/enclosure + selection state.

`CableScheduleRow` references authoritative ELV3 cable/run facts, installed length, endpoints and definitions. ELV8 never recomputes route length.

Rack/panel rows consume ELV6 owner-neutral layout projection. Compliance rows consume ELV7 exact profile/run/rule/finding/disposition refs.

Every row has deterministic stable sorting defined by `ReportModel` schema and source drill-down refs.

## 16. Template model

A published `ReportTemplateEdition` is immutable/versioned declarative data:

```text
templateId / editionId
templateSchemaVersion
supported ReportModel schema range
branding metadata
page/section definitions
field mappings
formatting rules
canonicalHash
```

No arbitrary Dart/JavaScript/shell execution. Unsupported/missing mapping is renderer error, not permission to query live mutable DB/UI state.

## 17. Snapshot, assembly and publication

Required flow:

1. verify publication/freeze policy for project revision;
2. verify required selections and ELV7 validation/readiness state;
3. capture exact `PublishedProjectSnapshot` and selection/profile/template manifest;
4. `ReportAssembler` builds canonical `ReportModel` from repository/query ports;
5. validate schema, required sections and source traceability;
6. compute canonical content hash;
7. persist immutable report bundle/manifest snapshot;
8. render one or more artifacts from that immutable input;
9. persist artifact metadata/hash;
10. renderer never re-opens mutable project state.

Renderer retry uses the same immutable report model/bundle snapshot.

## 18. Exporter boundary

Conceptual adapter:

```dart
abstract interface class ReportExporter {
  String get exporterId;
  String get exporterVersion;
  Future<ExportArtifact> export(
    ReportModel model,
    DeliverableManifest manifest,
    ExportOptions options,
  );
}
```

Initial outputs:

- canonical JSON for report-model exchange/reproducibility;
- CSV for BOM/tabular schedules;
- local PDF per ADR-025 product requirement;
- optional server PDF from the same immutable published snapshot/model contract;
- future XLSX/DXF/etc. adapters without changing canonical engineering truth.

Local/server content-equivalence must be contract-tested at the canonical model/content level even if PDF byte streams differ by renderer metadata.

## 19. Persistence strategy: extend existing tables, do not fork

P0 inventories current tables including `manufacturerCatalogs`, `manufacturerProducts`, `manufacturerPolicies`, `circuitProductSelections` and any report/file metadata.

Existing catalog/product/selection rows remain readable/canonical for their current scope. New schema is additive or migration-backed. Potential extensions:

```text
selection_request                       // generic non-circuit subject request
selection_constraint
selection_candidate_snapshot
selection_candidate_result
selection_decision                      // generic decision if legacy table cannot generalize safely
selection_decision_component
selection_impact_ref
selection_revalidation_ref
report_template / report_template_edition
report_bundle_snapshot
report_bundle_manifest_ref
report_export_artifact
```

Do **not** add parallel `manufacturer_catalog` / `catalog_product` tables unless P0/P1 explicitly migrates existing tables with ID/snapshot/history/codec compatibility proof.

Requirements:

- preserve FL14 immutable catalog/version behavior;
- preserve old `CircuitProductSelections` snapshots and status semantics;
- migration may create generic selection rows from legacy circuit rows only if reversible/proven and source legacy IDs remain traceable;
- current pointers guarded by expected revisions/generations;
- completed selection/report snapshots immutable;
- generated large files outside DB with ref/path/object key/hash/size/MIME metadata;
- no mandatory live price columns in engineering BOM truth.

## 20. Commands and legacy API transition

Current `ManufacturerRepository` methods (`importCatalog`, `archiveCatalog`, `savePolicy`, `selectProduct`, `clearSelection`) are inherited application APIs. P0/P2 decide which stay as compatibility facades and which route through new command services.

New project mutations must converge on standard ELV command semantics: `commandId`, replay-before-preconditions, expected project/revision/aggregate generations, atomic state/history/ledger/outbox where applicable.

Conceptual ELV8 operations:

```text
Import/Publish/RetireManufacturerCatalogVersion
Bind/ReleaseProjectManufacturerCatalog
Create/EvaluateSelectionRequest
SelectEquipmentCandidate
OverrideSoftSelection
RecordNoncompliantSelection
RecordSelectionRevalidation
Freeze/SupersedeSelectionDecision
Create/PublishReportTemplateEdition
AssembleReportBundle
ExportReportBundle
```

Exact registry names/count are frozen in P2 after compatibility analysis. Long-running rendering is outside the database write transaction; immutable report snapshot publication precedes rendering.

## 21. Code boundaries

Reuse current source first:

```text
packages/engineering_core/lib/src/manufacturer_catalog.dart
apps/mobile/lib/application/manufacturer_repository.dart
apps/mobile/lib/data/repositories/drift_manufacturer_repository.dart
apps/mobile/lib/features/calculations/manufacturer_screen.dart
```

Additive ELV8 shape may include:

```text
packages/engineering_core/lib/src/elv8/
  selection_constraints/
  configuration/
  impact/
  report_model_extensions/
  bom/

apps/mobile/lib/application/
  elv8_selection_command_service.dart
  elv8_selection_query_service.dart
  report_assembler.dart
  report_export_service.dart
  elv8_workspace_controller.dart

apps/mobile/lib/data/repositories/
  drift_elv8_selection_repository.dart      // generic extensions only
  drift_report_repository.dart
```

Do not create `elv8_catalog_repository.dart` that simply duplicates `ManufacturerRepository`. Pure matching/configuration/quantity-takeoff stays Flutter/Drift/HTTP independent.

## 22. Selection workspace UX

Extend current manufacturer screen/workflow rather than introduce a disconnected second selector.

Required UX:

- exact selection subject/requirements with ELV2–ELV7 source refs;
- exact catalog versions in scope;
- legacy and generic candidate hard eligibility;
- per-constraint pass/fail/unknown diagnostics rather than only concatenated strings for new engine;
- explainable soft rank;
- configuration/accessory tree;
- candidate comparison;
- impact preview on power/layout/normative evidence;
- explicit select/override/revalidate/freeze;
- clear selected/review-required/stale/pending/noncompliant states;
- frozen historical snapshot view.

Legacy FL14 circuit behavior/tests remain regression gates.

## 23. Deliverables workspace UX

Required capabilities:

- publication readiness showing blocked/stale/noncompliant/manual states;
- exact `PublishedProjectSnapshot` and template edition;
- canonical `ReportModel` preview;
- row/item → source traceability;
- report bundle history/diff;
- export format/options;
- artifact metadata/hash/history;
- regenerate renderer output from same immutable model/bundle;
- clear draft/final/frozen status.

No final/compliant publication hides blocked ELV7 or pending selection revalidation.

## 24. Targeted stale semantics

- requirement fingerprint change → dependent current selection stale;
- manufacturer policy change → affected selection review required; preserve historical snapshot;
- catalog archive/new version → old snapshot remains historical; explicit adoption required for current migration;
- product technical correction requires new version/revision, never silent mutation of selected snapshot;
- ELV6 layout change → relevant fit/selection/report sections stale;
- ELV7 profile/finding change → dependent normative constraints/report section stale;
- report-template-only change → report artifact/bundle presentation stale, not engineering selection;
- price-only change in separate estimate layer → estimate/report estimate section stale, not engineering BOM/selection.

## 25. Freeze and historical reproduction

Frozen ELV8 evidence records:

```text
selection decisions + exact product/configuration snapshots
catalog IDs/versions/source refs/hashes
selection engine/policy versions
upstream evidence fingerprints
ELV7 profile/run refs
ELV6 layout hash
PublishedProjectSnapshot ID/hash
ReportModel schema/content hash
report template edition/hash
exporter/version/options + artifact hashes
```

Historical reading never resolves current/latest catalog/template data. Pre-ELV8 history returns `ELV8_NOT_CAPTURED` rather than interpreting empty BOM as complete.

## 26. Acceptance requirements

Runtime closure requires at least:

1. P0 inventory of FL14 domain/repository/Drift/schema/UI/tests with exact accepted source SHA;
2. all inherited manufacturer matching/persistence tests remain green;
3. `fl14-strict-product-match-v1` behavior remains unchanged/replayable;
4. current catalog immutability/identity/archive semantics regression proof;
5. legacy circuit selection snapshot/review-required semantics regression proof;
6. generic hard constraint `SATISFIED/VIOLATED/UNKNOWN` fixtures;
7. missing hard candidate fact cannot pass;
8. deterministic generic candidate ordering/hash independent of DB/load order;
9. accessory/configuration positive and cycle-rejection fixtures;
10. no-candidate diagnostics;
11. soft override remains hard-eligible/audited;
12. hard noncompliant override uses typed owner disposition and remains visibly noncompliant;
13. candidate impact enters `PENDING_REVALIDATION` when required;
14. normal freeze blocked until required revalidation closes;
15. no direct ELV8 DB writes into ELV2–ELV7 owners;
16. stale selection after upstream requirement/profile/layout change;
17. command replay/idempotency/rollback/restart for new ELV8 mutations;
18. R1 frozen selection remains reproducible after R2 catalog/project changes;
19. `PublishedProjectSnapshot → ReportAssembler → ReportModel` deterministic content/hash proof;
20. BOM quantity aggregation with source drill-down proof;
21. engineering BOM independent of PriceBook changes;
22. renderer reads only immutable report model/manifest;
23. JSON/CSV export fixtures;
24. local PDF structural/golden/content fixture when renderer implemented;
25. local/server canonical content-equivalence contract when server renderer implemented;
26. stale/blocked ELV7 state visible in publication readiness;
27. template upgrade explicit; historical bundle unchanged;
28. large-file metadata/hash/missing-artifact handling;
29. project-scale catalog filtering/configuration/report/export performance budget.

## 27. Security and trust boundaries

- catalog/template imports are untrusted structured data;
- no imported scripts/macros execute;
- external file names/paths sanitized by adapters;
- output paths cannot escape export sandbox;
- vendor PDFs are provenance documents, not structured capability evidence unless explicitly imported/verified;
- renderer input is immutable `ReportModel` + manifest only;
- generated artifacts store exporter/version/options/source model hash;
- explanations cannot conceal failed/unknown hard constraints.

## 28. Explicit non-goals

ELV8 does not own live distributor inventory/price scraping, purchase orders/payment/tax, hidden product substitution, weakening upstream engineering/normative requirements, direct ELV2–ELV7 table mutation, arbitrary executable templates, full BIM/CAD authoring or legal certification beyond ELV7 evidence.

PriceBook/estimate/procurement features remain downstream/separate from the engineering BOM and preserve quantity/source provenance.