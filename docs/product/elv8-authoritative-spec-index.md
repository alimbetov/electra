# Electra — ELV8 Authoritative Design Index

Status: DESIGN RECONCILED / INHERITED FL14 RUNTIME BASELINE PRESENT / ELV8 CLOSURE NOT STARTED
Branch: `feat/flutter-elv8-deliverables-design`
Parent branch: `feat/flutter-elv7-normative-validation-design`
Pinned parent at branch creation: `6d7aef8349dc04526a3beba16b2e2483bec0009e`

ELV8 owns **manufacturer selection hardening/generalization, exact product snapshots, engineering BOM/schedules and immutable report/deliverable assembly/export**. It consumes requirements/evidence from ELV2–ELV7 and must never silently modify those stages to make a candidate fit.

ELV8 is not greenfield. The repository already contains an implemented electrical manufacturer-selection baseline: `FunctionalDeviceRequirement`, `ManufacturerCatalog`, `ManufacturerProductVariant`, `ProjectManufacturerPolicy`, strict `ManufacturerProductMatcher` (`fl14-strict-product-match-v1`), `ManufacturerRepository`, `DriftManufacturerRepository`, UI and tests. ADR-021 is the accepted manufacturer-mapping architecture. ADR-025 is the accepted deterministic reporting architecture: `PublishedProjectSnapshot → ReportAssembler → ReportModel → PDF Renderer`, with traceable BOM and a separately layered estimate.

ELV8 must **reuse, qualify and extend** those baselines rather than create parallel catalog, selection or report models.

## Entry documents

1. [ELV8 equipment-selection and deliverables design specification](elv8-deliverables-design-specification.md).
2. [ELV8 P0–P9 delivery plan](elv8-p0-p9-delivery-plan.md).
3. [ADR-021 manufacturer catalog mapping](../adr/ADR-021-manufacturer-catalog-mapping.md) — accepted functional-requirement → manufacturer-product baseline.
4. [ADR-025 report/BOM/estimate generation](../adr/ADR-025-report-bom-estimate-generation.md) — accepted immutable snapshot/report model and quantity-vs-price boundary.
5. Existing `packages/engineering_core/lib/src/manufacturer_catalog.dart`, `apps/mobile/lib/application/manufacturer_repository.dart` and `apps/mobile/lib/data/repositories/drift_manufacturer_repository.dart` are mandatory P0 runtime inventory.
6. [ELV7 authoritative index](elv7-authoritative-spec-index.md) and [ELV7 normative design](elv7-normative-validation-design-specification.md) define the compliance boundary.
7. [ELV6 enclosure/layout design](elv6-enclosure-layout-design-specification.md) defines physical-fit evidence consumed by selection/reporting.

## Authority hierarchy

1. accepted ELV1–ELV7 identities/evidence plus non-conflicting accepted ADR-021/ADR-025 semantics and existing FL14 runtime behavior;
2. this ELV8 index and design specification, which harden/generalize that baseline;
3. ELV8 P0–P9 plan;
4. architecture overview and legacy report/BOM notes.

No new ELV8 aggregate may shadow an existing `ManufacturerCatalog`, `ManufacturerProductVariant`, current selection snapshot or canonical ADR-025 `ReportModel` without an explicit migration contract and compatibility proof.

## Stage boundary

```text
ELV2–ELV6 engineered requirements / physical evidence
    +
ELV7 exact normative outcomes / constraints
    ↓
owner-neutral ELV8 selection request
    ↓
existing ManufacturerCatalog/ProductVariant baseline + new versioned extensions
    ↓
hard-constraint filter → explainable soft ranking
    ↓
explicit selection + impact/revalidation closure
    ↓
frozen product-selection snapshot
    ↓
PublishedProjectSnapshot
    ↓
ReportAssembler → canonical ReportModel + immutable manifest
    ↓
PDF / CSV / JSON / future exporter adapters
```

## Non-negotiable decisions

- Existing FL14 catalog/product/matcher/repository behavior is inventoried and regression-protected before generalization.
- `fl14-strict-product-match-v1` is not silently changed; incompatible matching semantics require a new version/adapter.
- Exact catalog version/product technical snapshot is preserved; historical selection never follows current catalog data.
- Hard requirements are filtered before ranking. Soft score cannot compensate for a hard violation or unknown mandatory fact.
- “No candidate” is a valid diagnostic result.
- Product selection that changes dimensions/power/capacity/layout/normative facts enters explicit revalidation; no hidden recursive redesign.
- A hard noncompliant selection remains visibly noncompliant. An approved deviation/USER_OVERRIDE cannot grant normal compliant/VALIDATED publication; verified source-authorized alternatives must change applicability explicitly. Owner dispositions do not rewrite raw physical or normative results.
- Existing ADR-025 `ReportModel` remains the canonical report content model. ELV8 may add an immutable manifest/envelope around it, not a competing report truth.
- BOM engineering quantity/source traceability remains separate from PriceBook/estimate values. An estimate may be rendered if supplied by its separate layer.
- Exporters consume an immutable snapshot/report model, never mutable Flutter provider/widget state.
- Every report/BOM/schedule row is traceable to project entities, revision, upstream evidence and exact catalog/profile/template versions.
- Large generated/vendor files live outside relational DB; metadata/refs/hashes remain persisted.
- Templates are versioned declarative data, not arbitrary executable scripts.

## Runtime entry gate

P0 must pin current upstream heads and produce a source-reality inventory of the FL14 matcher/catalog/persistence/UI/tests, existing DB schema and ADR-025 report/export infrastructure. P1/P2 then freeze migration-compatible extension contracts. Existing electrical selection remains a protected inherited baseline; ELV8 runtime closure is not allowed to mark it “newly implemented” or rewrite it without evidence.

### Initial package reality

| Package | Inherited runtime reality |
|---|---|
| P0 | baseline audit not yet executed |
| P1 | PARTIAL_BASELINE — catalog/product/policy domain exists |
| P2 | PARTIAL_BASELINE — Drift catalog/product/selection persistence exists, but generic ELV8 command/lifecycle hardening is open |
| P3 | PARTIAL_BASELINE — strict electrical product matcher/ranking exists |
| P4–P9 | ELV8-specific runtime not started |

Design completion does not qualify the inherited FL14 code as a complete ELV8 vertical.

## Coordinated catalogue and upstream contract

[The shared integration agreement](elv-integration/README.md) supplies separate
ELV6/ELV7 requirements and committed evidence, exact catalogue/offer snapshots,
owner-UoW application, result adapters and freeze-before-report ordering.
The Equipment Catalogue is a separately published local store; adoption and
selection snapshots remain project-owned. Existing FL14 IDs/codecs/FK anchors
are preserved through an explicit migration, not a parallel writable catalogue.
The authoritative catalogue design is pinned to the ELV7 source in the shared
agreement. It includes the professional CAP/K/SH target mapping, not just breakers.


## External and hybrid power source contract

[Source-system amendment](elv-integration/source-systems-contract.md) is mandatory
for generator, PV/inverter, UPS/BESS/battery and transfer integration.
[Readiness ledger](elv-integration/design-readiness.json) distinguishes the defined
ELV8 contract from unqualified electrical producer and source-authority gates.
No runtime or production-compliance readiness is inferred from the design guard.
