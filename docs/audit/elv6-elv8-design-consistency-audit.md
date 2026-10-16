# ELV6–ELV8 Design Consistency Audit

Date: 2026-10-16
Scope: `feat/flutter-elv6-enclosure-layout-design` → `feat/flutter-elv7-normative-validation-design` → `feat/flutter-elv8-deliverables-design`
Status: DESIGN CONSISTENCY PASS / RUNTIME QUALIFICATION NOT IMPLIED

## 1. Purpose

This audit checks the ELV6–ELV8 design specifications against existing repository reality and against each other. It focuses on ownership duplication, incompatible identity/unit models, circular dependencies, false PASS semantics, historical reproducibility and stage handoff contracts.

A design PASS means the current technical specifications no longer knowingly contradict the inspected baseline. It is not runtime acceptance; P0–P9 evidence remains required per stage.

## 2. Findings ledger

| ID | Severity | Finding | Resolution | Status |
|---|---|---|---|---|
| C1 | HIGH | Initial ELV6 draft created a parallel enclosure/DIN/placement model despite accepted `PanelAssembly`, `DinRail`, `PanelModulePlacement` and ADR-019 | Existing panel domain made canonical; ELV6 now uses owner-neutral projections/adapters and adds only non-owned rack/extension data | CLOSED |
| C2 | HIGH | Initial ELV6 draft proposed integer-mm persistence while existing geometry/panel code uses millimetre `double` values | ELV6 now reuses accepted geometry scalar/serialization/tolerance convention; P0/P1 must pin it explicitly | CLOSED |
| C3 | HIGH | ELV7 draft risked creating a second `NormativeProfile`/rule taxonomy independent of `elv-normative-standards-matrix.md` | Existing profile/StandardReference/rule-class/precedence architecture is mandatory baseline; runtime model must reconcile to it | CLOSED |
| C4 | HIGH | ELV7 could accidentally treat documented standards inventory as verified current law/standard applicability | Matrix is explicitly architecture inventory only; every production `VERIFIED_EXTERNAL` rule pack requires official source/edition/status/effective-date/applicability evidence | CLOSED |
| C5 | HIGH | Initial ELV8 design incorrectly treated manufacturer selection as greenfield/NOT_STARTED | Existing FL14 manufacturer catalog, strict matcher, repository, Drift persistence, UI and tests are protected inherited runtime baseline | CLOSED |
| C6 | HIGH | Initial ELV8 design proposed catalog/product entities that could duplicate `ManufacturerCatalog`/`ManufacturerProductVariant` | ELV8 now extends current types/codecs and permits new generic selection entities only for missing cross-discipline concepts | CLOSED |
| C7 | HIGH | Initial ELV8 deliverable model risked competing with accepted ADR-025 `PublishedProjectSnapshot → ReportAssembler → ReportModel` | ADR-025 `ReportModel` remains canonical report content; ELV8 adds only immutable manifest/bundle envelope, templates and exporters | CLOSED |
| C8 | MEDIUM | Hard noncompliant equipment selection was tied too broadly to ELV7 deviations | Disposition is now owner-specific; ELV7 deviation applies to normative findings only, while ELV4/5/6 engineering violations require authoritative owner workflows | CLOSED |
| C9 | HIGH | Product selection can change upstream power/layout/compliance facts and create a cycle | ELV8 now uses explicit impact → `PENDING_REVALIDATION` → owner-stage recalculation/validation → `VALIDATED`; no hidden recursive DB mutation | CLOSED |
| C10 | HIGH | Post-audit ELV6/ELV7 corrections made branch ancestry diverge from the intended staged chain | ELV7 merged the corrected ELV6 design baseline; ELV8 merged the corrected ELV7 design baseline and carries corrected inherited documents | CLOSED |

## 3. Accepted ownership chain

```text
ELV2 canonical definitions / editions / adoption
    ↓
ELV3 realized cable/run/pathway physical facts
    ↓
ELV4 power / PoE / PSU / UPS / battery evidence
    ↓
ELV5 CCTV / LAN / ACS / Fire discipline calculations
    ↓
ELV6 canonical panel reuse + ELV rack/layout/fit evidence
    ↓
ELV7 adopted normative profile + applicability/precedence + findings
    ↓
ELV8 manufacturer/configuration selection + controlled revalidation
    ↓
PublishedProjectSnapshot → ReportAssembler → ReportModel
    ↓
BOM / schedules / validation sections / export artifacts
```

No downstream stage may duplicate an upstream engineering source of truth merely to simplify implementation.

## 4. ELV6 consistency result

Accepted design rules:

- `PanelAssembly` remains the canonical owner for existing electrical/automation panel enclosure identity.
- `DinRail` and `PanelModulePlacement` remain the canonical existing panel DIN placement facts until a separately qualified migration replaces them.
- ELV6 can own non-panel ELV/telecom rack hosts and extension metadata where no previous canonical owner exists.
- One physical enclosure/placement has one active canonical owner per revision.
- Auto-layout is proposal-only and resolves into canonical owner commands.
- Intrinsic physical fit belongs to ELV6; jurisdiction-specific installation rules belong to ELV7.
- Existing geometry numeric conventions are reused rather than forked.

Runtime gate remains P0 inventory of existing panel storage/mutation/validation APIs plus exact unit/tolerance convention.

## 5. ELV7 consistency result

Accepted design rules:

- one canonical `NormativeProfile` architecture evolves from the standards matrix;
- existing rule classes remain explicit unless a separately justified migration changes them;
- applicability and precedence are deterministic data/engine behavior, never UI branches;
- lower-priority/project/manufacturer rules cannot silently weaken higher-priority mandatory requirements;
- missing mandatory applicability/evidence is `UNRESOLVED`/`NOT_EVALUABLE` and blocks aggregate PASS;
- raw findings are immutable; manual review, profile override and finding deviation are separate concepts;
- historical validation pins exact profile/rule/source/evidence editions;
- production verified rule packs require authoritative external provenance evidence.

Runtime gate remains source verification plus exact profile/rule schema/command implementation and qualification.

## 6. ELV8 consistency result

Accepted design rules:

- existing `fl14-strict-product-match-v1` remains a protected versioned semantic baseline;
- generic ELV8 selection adapts/extends legacy electrical requirements rather than rewriting them;
- hard constraints are evaluated before soft ranking and missing mandatory product facts cannot pass;
- exact product technical snapshots and catalog versions are historical evidence;
- selection impact never writes directly into ELV2–ELV7 owner tables;
- product-induced changes use explicit affected-stage revalidation before normal freeze/final publication;
- ADR-025 `ReportModel` remains canonical report content;
- engineering BOM quantity/source traceability is distinct from PriceBook/estimate/procurement;
- renderers consume immutable `ReportModel` + manifest, never mutable UI/database state.

Runtime gate starts with exact FL14 inventory/regression evidence, then generic selection/revalidation/report implementation.

## 7. Cross-stage fail-closed rules

The following semantics are required throughout ELV6–ELV8:

1. missing mandatory evidence never becomes PASS;
2. stale evidence never remains authoritative current evidence;
3. frozen historical evidence is immutable and never resolves `latest` records;
4. user/manual overrides are explicit audited overlays, not mutations of raw results;
5. deterministic outputs use exact algorithm/profile/catalog/template versions and stable ordering;
6. concurrent dependency changes must fail CAS/publication rather than publish a stale successful result;
7. downstream generated documents expose blocked/stale/noncompliant states instead of hiding them.

## 8. Remaining implementation risks

These are not design contradictions, but must be resolved in stage P0/P1 before implementation proceeds deeply:

- exact existing panel repository/command/revision APIs and persistence layout;
- exact canonical geometry numeric serialization/tolerance for deterministic hashes;
- actual persisted normative/profile baseline, if any, beyond documentation;
- authoritative official-source acquisition/verification workflow for production rule packs;
- compatibility-safe extension strategy for `ManufacturerProductVariant` technical capability facets;
- migration/compatibility strategy for current circuit-only product selections into generic multi-discipline selection;
- exact current report/file/rendering runtime beyond ADR-025;
- performance budgets for project-scale layout, validation, candidate filtering and report assembly.

## 9. Resolution

The ELV6–ELV8 design chain is internally coherent enough to proceed to **ELV6 P0 source-reality inventory first**. ELV7 P0 can prepare profile/source reconciliation in parallel but production rule runtime depends on accepted upstream projections. ELV8 P0 can inventory/protect FL14 immediately, while generic selection/revalidation/report closure remains downstream of accepted ELV6/ELV7 contracts.

Recommended implementation order:

```text
ELV6 P0–P2
  → ELV6 physical runtime/qualification
  → ELV7 P0–P3 + source governance
  → ELV7 verified rule packs/qualification
  → ELV8 P0 inherited-baseline audit (may start early)
  → ELV8 generic selection/revalidation
  → ReportModel/BOM/export closure
```

This ordering preserves parallel discovery work without allowing a downstream stage to manufacture missing upstream truth.