# ELV8 — P0–P9 delivery plan

Status: DESIGN DRAFT / INHERITED FL14 BASELINE PRESENT / ELV8 CLOSURE OPEN
Branch: `feat/flutter-elv8-deliverables-design`
Specification: [design](elv8-deliverables-design-specification.md).
Manufacturer baseline: [ADR-021](../adr/ADR-021-manufacturer-catalog-mapping.md).
Reporting baseline: [ADR-025](../adr/ADR-025-report-bom-estimate-generation.md).

| Package | Scope | Mandatory outputs | Depends on |
|---|---|---|---|
| P0 | Source-reality and final-stage boundary | exact ELV7/source/schema pin; FL14 domain/repository/Drift/UI/test inventory; current report/file baseline; no-duplication matrix | Accepted ELV1–ELV7 + FL14/ADR-021/ADR-025 |
| P1 | Catalog/configuration/template extension | compatibility-safe extension of `ManufacturerCatalog`/`ManufacturerProductVariant`; typed ELV facets; configuration graph; template editions | P0 |
| P2 | Generic selection persistence and commands | reuse/migration map for current tables/APIs; generic request/constraint/decision schema; exact command registry; replay/UoW/history/freeze | P1 + shared runtime |
| P3 | Generic filtering/ranking | preserve `fl14-strict-product-match-v1`; hard/unknown semantics; legacy adapters; accessory/configuration resolver; explainable deterministic ranking | P1/P2 |
| P4 | Selection impact and revalidation | decision lifecycle; owner-specific impact/disposition; ELV4–ELV7 handoff; pending/stale/noncompliant/validated closure | P2/P3 + upstream owner APIs |
| P5 | Quantity takeoff and canonical `ReportModel` sections | equipment/cable/layout/compliance schedules; engineering BOM; source traceability; stable ordering | P2–P4 + ADR-025 |
| P6 | Immutable report bundle and exporters | `PublishedProjectSnapshot`; `ReportAssembler`; canonical `ReportModel` hash/manifest; templates; JSON/CSV/PDF adapters; artifact metadata | P5 + file/export adapters |
| P7 | Unified selection/reports workspace | extend current manufacturer UX; candidate diagnostics/compare/impact/freeze; report readiness/preview/trace/export/history | P2–P6 |
| P8 | Integrated qualification | inherited FL14 regression + generic selection + revalidation + report/export replay/rollback/race/restart/freeze/performance evidence | P0–P7 |
| P9 | Final ELV-chain closure | exact-head requirement/code/test matrix; supported-selection/export matrix; full provenance chain; limitations/publication manifest | P8 |

## P0 — source-reality baseline

P0 must pin the exact current ELV7/source head and database migration origin, then inventory—not infer—the inherited ELV8-adjacent runtime:

- `FunctionalDeviceRequirement`;
- `ManufacturerProductVariant`;
- `ManufacturerCatalog`;
- `ProjectManufacturerPolicy`;
- `ManufacturerProductMatcher` and exact `fl14-strict-product-match-v1` semantics;
- `ManufacturerRepository` and current candidate/selection status behavior;
- `DriftManufacturerRepository`, including current catalog/product/policy/circuit-selection tables and immutable snapshot behavior;
- current manufacturer UI and executed matching/persistence tests;
- dependency recalculation path invoked by policy/selection changes;
- ADR-025 `PublishedProjectSnapshot → ReportAssembler → ReportModel` contract;
- existing report/file/blob/export infrastructure actually present in code/schema.

P0 publishes a reuse/extend/migrate matrix. It must explicitly prove that ELV8 will not create parallel manufacturer catalog/product or canonical report truth.

## P1 — compatibility-safe catalog and template extension

Preserve existing names/IDs/codecs and extend them only where new ELV disciplines require additional typed capability facets.

Freeze:

- current catalog ID/version/region/source and product snapshot compatibility;
- typed ELV product capability facets and codec versions;
- selection-critical structured-field requirements; legacy free-form `metadata` is not automatically hard evidence;
- product configuration/accessory graph semantics and cycle rejection;
- immutable catalog/version lifecycle extensions, if added, without rewriting legacy selected snapshots;
- report template edition/schema/version/hash;
- untrusted import and vendor-document storage boundary.

Do not introduce `CatalogProduct`/`CatalogEdition` roots that merely duplicate `ManufacturerProductVariant`/`ManufacturerCatalog`.

## P2 — generic selection persistence and command hardening

First map existing APIs/tables to their future role:

```text
ManufacturerRepository.importCatalog/archiveCatalog/savePolicy/selectProduct/clearSelection
manufacturerCatalogs
manufacturerProducts
manufacturerPolicies
circuitProductSelections
```

Keep them canonical for current electrical scope or migrate through an explicit compatibility contract. New generic tables are limited to missing cross-discipline concepts such as immutable `SelectionRequest`, structured constraints/candidate evidence, generic decision components, impact refs and revalidation refs.

New project mutations converge on existing ELV command semantics: `commandId`, replay-before-preconditions, expected project/revision/aggregate generations, atomic state/history/ledger/outbox publication where applicable.

Legacy circuit selection snapshots remain readable and historically authoritative.

## P3 — deterministic selection engine without breaking FL14

Regression-protect `fl14-strict-product-match-v1`; incompatible semantics require a new engine/version, not silent modification.

Implement generic selection around exact structured constraints:

- `SATISFIED / VIOLATED / UNKNOWN / NOT_APPLICABLE` hard results;
- all applicable hard constraints must be satisfied for normal eligibility;
- missing mandatory candidate data cannot pass;
- existing electrical `FunctionalDeviceRequirement` can be adapted into the generic request;
- current allowlist/region hard policy and preferred manufacturer/series soft ranking remain semantically preserved;
- deterministic accessory/configuration closure and cycle rejection;
- explicit no-eligible-candidate diagnostics;
- versioned explainable soft scoring/contributions;
- stable-ID tie-break independent of DB insertion/load order;
- canonical request/evaluation hashes.

Black-box ML ranking is not authoritative for ELV8 closure.

## P4 — controlled selection feedback and revalidation

Implement lifecycle:

`DRAFT → SELECTED_PENDING_IMPACT → [PENDING_REVALIDATION] → VALIDATED → FROZEN`, plus `NONCOMPLIANT_OVERRIDE`, `STALE`, `SUPERSEDED`.

Capture exact product/configuration technical snapshot and impact on physical envelope, mounting, power, interfaces/capacity, battery/accessories and normative facts.

Earlier stages are changed/recalculated only through their authoritative application/command boundaries. ELV8 repositories never directly write ELV2–ELV7 tables.

Disposition is owner-specific:

- ELV7 normative violation may reference an approved ELV7 deviation where policy/law allows;
- ELV4/5/6 engineering requirement needs the authoritative engineering override/change path, if one exists;
- unresolved hard technical evidence with no valid disposition remains blocking.

An ELV7 deviation is not a universal hard-constraint override.

## P5 — quantity takeoff, BOM and `ReportModel`

Preserve ADR-025 rather than invent a second deliverable content model.

Build deterministic `ReportModel` sections for:

- equipment schedule with exact selected product snapshots;
- engineering BOM via `QuantityTakeoff` with contributor drill-down;
- cable schedule using authoritative ELV3 lengths/endpoints;
- panel/rack/layout schedules using ELV6 projections;
- ELV4/ELV5 calculation references/summaries;
- ELV7 compliance/validation matrix and disposition state;
- selection rationale;
- source/catalog/profile/template manifest references.

Stable row identities/order and source traceability are mandatory.

Engineering BOM quantity is independent from PriceBook/currency/vendor quote/tax. The estimate is a separate layer and may appear in a report only when supplied through its own versioned source.

## P6 — immutable report snapshot and exporters

Implement the accepted chain:

```text
PublishedProjectSnapshot
    ↓
ReportAssembler
    ↓
ReportModel
    + immutable DeliverableManifest / ReportBundleSnapshot
    ↓
export adapters
```

The manifest/envelope stores source snapshot hash, selection/catalog/profile/template versions, `ReportModel` content hash, exporter metadata and artifact hashes. It does not duplicate report section truth.

Initial qualification path:

1. canonical JSON for model/provenance reproducibility;
2. CSV BOM/tabular schedules;
3. local PDF per ADR-025 with structural/golden/content tests;
4. optional server PDF from the same immutable published snapshot/model contract;
5. future XLSX/DXF/etc. without changing canonical engineering truth.

Renderer retry uses the same immutable `ReportModel`/manifest and does not re-read mutable project state.

## P7 — extend existing UX

Selection UX extends the existing manufacturer workflow rather than creating an unrelated selector. It must show:

- exact subject requirements and upstream evidence;
- exact catalog versions;
- hard eligibility and per-constraint diagnostics;
- legacy/generic matcher evidence;
- explainable ranking;
- configuration/accessory tree;
- candidate comparison;
- impact preview;
- explicit select/override/revalidate/freeze;
- selected/review-required/stale/pending/noncompliant states;
- historical product snapshot.

Reports UX shows publication blockers, `PublishedProjectSnapshot`, template edition, canonical `ReportModel` preview, row/source traceability, bundle history/diff, export artifacts/hashes and frozen view.

No final/compliant publication hides blocked ELV7 validation or pending required selection revalidation.

## P8 — integrated qualification

At one exact SHA record code/migration/test/CI evidence for:

- complete FL14 source-reality inventory and all inherited matching/persistence tests green;
- `fl14-strict-product-match-v1` semantic regression;
- current catalog immutability, identity, archive and preserved-selection behavior;
- legacy circuit selection fingerprint/policy/review-required semantics;
- generic hard filter including unknown mandatory data;
- deterministic generic candidate order/hash;
- configuration/accessory positive and cycle-rejection cases;
- no-candidate diagnostics;
- soft override remains hard-eligible and audited;
- hard noncompliant override remains visibly noncompliant with valid owner disposition;
- impact → pending revalidation → validated closure;
- no direct ELV8 writes into ELV2–ELV7 owner tables;
- targeted stale propagation;
- new-command replay/duplicate ID/rollback/restart;
- concurrent selection/upstream mutation CAS rejection;
- R1 frozen selection after R2 catalog/project changes;
- deterministic `PublishedProjectSnapshot → ReportAssembler → ReportModel` content/hash;
- BOM aggregation with source drill-down and independence from PriceBook-only changes;
- exporter reads immutable model/manifest only;
- JSON/CSV and implemented PDF qualification;
- local/server canonical-content equivalence when server rendering exists;
- template upgrade leaves historical report snapshot unchanged;
- artifact metadata/hash/missing-file handling;
- project-scale catalog/configuration/report/export performance.

Planned tests are not evidence until executed.

## P9 — final ELV chain closure

Reconcile ELV8 requirements ↔ inherited/new source ↔ migrations ↔ tests ↔ exact-head CI and publish:

- protected inherited FL14 capability/evidence matrix;
- supported generic catalog capability/constraint/configuration matrix;
- unsupported/unknown/manual/noncompliant selection matrix;
- exporter/template support matrix;
- final ELV2–ELV8 provenance chain;
- accepted `ReportModel` schema/version and manifest schema/hash contract;
- PriceBook/estimate/procurement boundary;
- known limitations;
- exact accepted source SHA and evidence manifest.

## Current ledger

| Package | Design | Runtime | Evidence |
|---|---|---|---|
| P0 | DRAFT | BASELINE_AUDIT_OPEN | inherited code/ADRs identified; exact package evidence not yet frozen |
| P1 | DRAFT | PARTIAL_BASELINE | `ManufacturerCatalog`, `ManufacturerProductVariant`, policy/domain baseline exists |
| P2 | DRAFT | PARTIAL_BASELINE | Drift catalogs/products/policies/circuit selections exist; generic command hardening open |
| P3 | DRAFT | PARTIAL_BASELINE | `fl14-strict-product-match-v1` and deterministic legacy ranking exist |
| P4 | DRAFT | NOT_STARTED | — |
| P5 | DRAFT | NOT_STARTED | ADR-025 is architecture baseline, not runtime proof |
| P6 | DRAFT | NOT_STARTED | ADR-025 local/server rendering is design authority; runtime evidence open |
| P7 | DRAFT | PARTIAL_BASELINE | current manufacturer UI exists; generic/reports UX open |
| P8 | DRAFT | NOT_STARTED | — |
| P9 | DRAFT | NOT_STARTED | — |

Default ELV8 closure sequence: P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9. Inherited FL14 capabilities are regression gates from P0 onward and are never counted as new ELV8 proof without exact-SHA evidence.