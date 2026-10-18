# Electra — Equipment Configuration Platform

Status: target architecture  
Branch: `target/electra-professional-electrical-platform`

## 1. Strategic capability

Electra SHALL treat equipment cataloging and autoconfiguration as a shared engineering-platform capability, not as a feature local to one ELV stage.

The capability connects four bounded responsibilities:

```text
ELV5 — engineering demand
  ↓
ELV8 — catalog candidate generation / orchestration
  ↙                         ↘
ELV7 — normative proof      ELV6 — physical fit proof
  ↘                         ↙
ELV8 — ranked resolved configuration
  ↓
Frozen configuration → BOM / specification / deliverables
```

The platform MUST preserve the distinction between engineering truth, normative policy, physical feasibility and commercial preference.

## 2. Bounded contexts

### ELV5 — Demand

Produces vendor-neutral typed `EquipmentDemand` objects from project calculations and topology.

### ELV6 — Physical feasibility

Evaluates dimensions, mounting, clearances, terminals, thermal envelope, accessories, reserve and serviceability.

### ELV7 — Normative feasibility

Evaluates versioned jurisdiction/project rule packs against structured facts and evidence.

### ELV8 — Catalog and configuration

Owns catalog identity, product variants, compatibility graph, candidate orchestration, ranking, substitutions, commercial snapshots and frozen resolved configurations.

No stage may duplicate another stage's authority.

## 3. Canonical information model

```text
Engineering need
  EquipmentDemand
       │
       ▼
Catalog semantics
  ComponentClass
       │
       ▼
Commercial taxonomy
  ProductFamily
       │
       ▼
Orderable identity
  ProductVariant / SKU
       │
       ├── Technical facts + provenance
       ├── Physical profile
       ├── Certification claims
       └── Compatibility relations

Project evaluation
  CandidateEvaluation
       ├── demand match
       ├── normative evidence
       ├── physical evidence
       └── compatibility closure

Resolution
  ResolvedConfiguration
       ├── primary components
       ├── mandatory accessories
       ├── alternatives
       ├── decisions/rejections
       └── pinned versions
```

## 4. Non-negotiable architectural rules

1. Hard engineering/normative/physical constraints SHALL be evaluated before commercial ranking.
2. A lower price cannot compensate for a failed hard constraint.
3. Component matching SHALL be based on typed capabilities and values, not product-name strings.
4. Manufacturer facts, project requirements, normative rules, calculated values and commercial snapshots SHALL be separate data categories.
5. Project overrides SHALL form an overlay; they SHALL NOT mutate the global catalog.
6. Historical project configurations SHALL pin catalog, rule-pack and policy versions.
7. Missing technical evidence SHALL remain unknown and SHALL NOT be fabricated into a pass.
8. All automatic selection results SHALL be explainable and reproducible.
9. Manual overrides SHALL be explicit and auditable.
10. AI SHALL be advisory for ingestion/explanation, never the authoritative engineering or compliance engine.

## 5. Catalog evolution model

The platform SHALL support controlled evolution:

```text
DRAFT → ACTIVE → DEPRECATED → RETIRED
```

Existing frozen projects retain references to deprecated/retired variants. Products SHALL be superseded, not destructively replaced.

Stable IDs MUST be independent from display names and source-document wording.

## 6. Compatibility graph

Compatibility is a graph, not a flat attribute list.

Minimum relation vocabulary:

```text
REQUIRES
COMPATIBLE_WITH
INCOMPATIBLE_WITH
ACCESSORY_FOR
MOUNTABLE_ON
REQUIRES_ADAPTER
SUBSTITUTE_FOR
SUCCESSOR_OF
UPSTREAM_OF
DOWNSTREAM_OF
SAME_EQUIVALENCE_GROUP
```

Relations may carry conditions, versions and provenance.

## 7. Selection workflow

Canonical resolution sequence:

```text
1. Normalize demand
2. Generate candidates by semantic class/capabilities
3. Check mandatory technical facts
4. Apply electrical/functional hard constraints
5. Resolve mandatory accessories/dependencies
6. Qualify through ELV7
7. Validate fit through ELV6
8. Remove blocking candidates
9. Rank survivors by explicit versioned policy
10. Return recommendation + alternatives + rejection reasons
11. Engineer accepts/pins/overrides
12. Freeze configuration for outputs
```

Evaluation before acceptance SHALL be side-effect free.

## 8. Commercial data

Price, stock, supplier and lead time are temporal observations:

```text
CommercialSnapshot
  variantId
  supplierId
  observedAt
  currency
  netPrice
  availability
  quantity
  leadTime
  source
```

They MAY affect ranking but SHALL NOT affect technical identity or historical BOMs after freeze.

## 9. Reproducibility fingerprint

Every frozen selection SHALL retain:

```text
projectRevision
engineeringDemandFingerprint
catalogSnapshotId
normativeProfileId
rulePackVersion
layoutSnapshotId
selectionPolicyVersion
commercialSnapshotId (when used)
```

This is required for deterministic replay, audit and future cloud collaboration.

## 10. Multi-source energy readiness

The same model SHALL cover grid, generator, UPS, battery/ESS, PV and inverter/charger ecosystems through capabilities and compatibility relations.

No architecture branch shall introduce vendor-specific or source-specific parallel catalogs when the canonical component/capability model can express the equipment.

## 11. Persistence guidance

Do NOT implement the platform as one generic `components(parameters_json)` table.

Use a normalized canonical core for identities, typed high-value engineering attributes and relations. Extensible attributes MAY use controlled typed extension structures where domain schemas genuinely vary.

Recommended logical stores:

- component classes and attribute schemas;
- manufacturers/families/variants;
- normalized engineering facts;
- physical profiles;
- certification/evidence records;
- compatibility relations;
- catalog snapshots/releases;
- project overlays;
- commercial observations;
- resolved configuration snapshots;
- selection decisions and overrides.

The first implementation may live in one database; bounded ownership is logical and API-level, not a requirement for premature microservices.

## 12. API boundary

The platform SHOULD expose application-level ports such as:

```text
EquipmentDemandRepository
CatalogQueryService
CompatibilityResolver
NormativeCandidateEvaluator
ComponentFitEvaluator
ConfigurationResolver
CommercialSnapshotRepository
ConfigurationFreezeService
```

Callers SHALL use these contracts rather than coupling directly to catalog persistence.

## 13. Quality strategy

Required verification layers:

- schema/contract tests between ELV5/6/7/8;
- golden projects with pinned expected configurations;
- boundary-value tests for technical constraints;
- property-based tests for invariant-heavy selection logic;
- deterministic replay tests;
- compatibility-closure tests;
- missing-evidence tests;
- substitution/supersession tests;
- offline catalog snapshot tests;
- migration tests for old frozen projects.

## 14. Future extensions

The design SHALL allow, without changing the core selection model:

- cloud catalog synchronization;
- supplier integrations;
- project sharing through backend/QR workflows;
- organization-specific approved-product lists;
- regional catalogs and pricing;
- carbon/energy/lifecycle ranking dimensions;
- stock-aware procurement planning;
- assisted datasheet ingestion;
- configuration templates and reusable assemblies;
- optimization across multiple enclosures/boards/racks;
- portfolio-level standardization.

## 15. Product differentiation

The differentiator is not “a database of breakers.” It is the closed engineering loop:

> calculate → constrain → qualify → fit → configure → explain → freeze → issue.

This turns Electra from a calculator/drawing tool into an engineering configuration platform while retaining deterministic professional-grade results.
