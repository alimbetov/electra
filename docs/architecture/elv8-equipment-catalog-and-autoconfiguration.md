# ELV8 — Equipment Catalog and Autoconfiguration Engine

Status: normative design contract  
Branch: `feat/flutter-elv8-deliverables-design`

## 1. Product intent

ELV8 SHALL turn engineering demand into a reproducible, explainable and commercially useful equipment configuration.

This is not a lookup table and not an SKU picker. It is a constrained configuration engine:

```text
ELV5 engineering demand
        ↓
Catalog capability filter
        ↓
ELV7 normative hard constraints
        ↓
ELV6 physical fit / assembly constraints
        ↓
Compatibility closure + mandatory accessories
        ↓
Ranking policy
        ↓
Resolved configuration + alternatives
        ↓
Frozen BOM / specification / deliverables
```

The core product rule is:

> Hard engineering constraints are never traded for price, brand preference or availability.

## 2. Catalog model

The catalog SHALL separate semantic class, commercial family and concrete sellable variant.

```text
ComponentClass
  └── ProductFamily
       └── ProductVariant / SKU
            └── Accessories / related variants
```

### 2.1 ComponentClass

Canonical engineering identity such as:

- MCB, MCCB, RCD, RCBO, fuse, SPD;
- contactor, relay, power supply;
- UPS, inverter, ATS, battery, energy-storage module;
- PV protection/interface equipment;
- terminal block, busbar, DIN accessory;
- enclosure/rack;
- network switch, patch panel, controller, detector, camera, PSU, battery;
- cable and connector families.

It defines required typed attribute schema and capability vocabulary, not a vendor.

### 2.2 ProductFamily

Manufacturer product line sharing common commercial/technical semantics.

### 2.3 ProductVariant

Concrete orderable item:

```dart
final class ProductVariant {
  final String variantId;
  final String familyId;
  final String manufacturerId;
  final String manufacturerPartNumber;
  final Map<AttributeCode, EngineeringValue> facts;
  final Set<CapabilityCode> capabilities;
  final PhysicalProfileRef? physicalProfile;
  final List<CertificationClaim> certifications;
  final LifecycleState lifecycle;
  final CatalogProvenance provenance;
}
```

Core engineering fields SHALL NOT be stored as an untyped generic key/value dump.

## 3. Strong typing and units

Calculation-relevant values SHALL use typed quantities and normalized units.

Examples:

- voltage;
- current;
- breaking capacity;
- power;
- energy;
- frequency;
- dimensions;
- temperature;
- conductor cross-section;
- resistance;
- time/autonomy.

Display units may vary; canonical comparison must not.

## 4. Facts, derived values and volatile commercial data

The data model SHALL separate:

1. **catalog facts** — manufacturer-declared stable technical attributes;
2. **derived engineering values** — normalized/calculated from facts;
3. **normative verdicts** — ELV7 output, never persisted as timeless catalog truth;
4. **physical-fit verdicts** — ELV6 output for a project/layout snapshot;
5. **commercial snapshots** — price, currency, seller, stock, lead time and timestamp.

Price and stock MUST NOT be fields that change the semantic identity of a product variant.

## 5. Provenance

Every imported engineering fact SHALL be traceable where practical to:

```text
sourceType
sourceId / document reference
manufacturer
sourceRevision
page/section or field mapping
sourceHash
importedAt
verifiedAt
verificationState
confidence
```

Unknown data MUST remain unknown. Importers MUST NOT invent defaults to make a candidate pass.

## 6. Compatibility graph

Compatibility SHALL be first-class and directional where required.

Supported relation semantics include:

- `REQUIRES`;
- `COMPATIBLE_WITH`;
- `INCOMPATIBLE_WITH`;
- `ACCESSORY_FOR`;
- `MOUNTABLE_ON`;
- `REQUIRES_ADAPTER`;
- `UPSTREAM_OF` / `DOWNSTREAM_OF`;
- `SUBSTITUTE_FOR`;
- `SUCCESSOR_OF`;
- `SAME_EQUIVALENCE_GROUP`.

Relations SHALL carry applicability conditions and provenance. A bare many-to-many table with no relation semantics is insufficient.

## 7. Configuration bundle

Selection SHALL resolve assemblies, not only primary products.

```dart
final class ConfigurationBundle {
  final String bundleId;
  final List<ResolvedComponent> components;
  final List<ResolvedRelation> relations;
  final List<CandidateDecision> decisions;
  final ConfigurationFingerprint fingerprint;
}
```

Example: a protective device may require an auxiliary contact, busbar adapter or terminal accessory; an inverter may require protection/interface equipment; a rack device may require a shelf or mounting kit.

Mandatory dependencies MUST be included before physical and normative acceptance is final.

## 8. Candidate pipeline

The resolver SHALL execute stages in this order:

1. normalize `EquipmentDemand` from ELV5;
2. fetch variants by semantic component class and required capabilities;
3. reject candidates missing required engineering facts;
4. apply electrical/functional hard constraints;
5. build mandatory compatibility/accessory closure;
6. ask ELV7 for normative candidate qualification;
7. ask ELV6 for physical fit/placement feasibility where applicable;
8. reject all blocking violations;
9. rank remaining candidates by explicit policy;
10. return best candidate plus explainable alternatives;
11. commit only on an explicit resolve/apply command;
12. freeze selected configuration for deliverables.

Candidate evaluation MUST be side-effect free until step 11.

## 9. Ranking policy

Only technically accepted candidates may be ranked.

Suggested ranking dimensions:

- project manufacturer preference;
- total installed cost;
- current availability;
- lead time;
- space utilization;
- energy/loss efficiency where relevant;
- standardization/reuse of already selected families;
- spare capacity;
- lifecycle state;
- evidence completeness.

```dart
final class SelectionPolicy {
  final String policyId;
  final int version;
  final List<RankingCriterion> criteria;
  final TieBreakPolicy tieBreak;
}
```

Scores SHALL be explainable. Hidden ML ranking MUST NOT be the authoritative selector.

## 10. No-solution and conflict diagnostics

If no product qualifies, the resolver SHALL return structured reasons, not an empty list.

```text
NO_CANDIDATE
  demandId
  blockingDimensions[]
  closestCandidates[]
  rejectedByRule[]
  rejectedByPhysicalConstraint[]
  missingFacts[]
  remediationOptions[]
```

The UI should be able to say, for example, that all candidates fail breaking capacity, enclosure depth or missing certification evidence.

## 11. Alternatives and substitutions

ELV8 SHALL support:

- preferred product;
- technically equivalent alternatives;
- approved project substitutions;
- manufacturer successor products;
- temporary commercial substitution.

Equivalence MUST be computed/validated from required capabilities and constraints. Matching only by description or category name is prohibited.

## 12. Manual engineer override

The engineer MAY pin or override a resolved item when policy allows it.

Override SHALL record:

```text
selectedVariantId
replacedRecommendationId
reason
actor
createdAt
projectRevision
remainingWarnings[]
```

A manual choice SHALL still pass non-overridable ELV7 blocking rules and required ELV6 physical constraints.

## 13. Deterministic replay and freeze

Every resolved configuration SHALL retain at least:

```text
projectRevision
engineeringDemandFingerprint
catalogSnapshot/version
normativeProfile + rulePackVersion
layoutSnapshot/version
selectionPolicyVersion
commercialSnapshotId (when price/availability affected ranking)
resolvedAt
```

The configuration fingerprint SHALL allow the same inputs to reproduce the same technical result.

Historical BOMs MUST NOT silently change when catalog, prices or rules are updated.

## 14. Catalog lifecycle

Catalog entities SHALL support:

- `DRAFT`;
- `ACTIVE`;
- `DEPRECATED`;
- `RETIRED`.

Deletion of variants referenced by frozen projects is prohibited. Supersession SHALL be modeled explicitly.

## 15. Project overlays

Project policy MAY define:

- preferred/forbidden manufacturers;
- approved equivalents;
- minimum evidence quality;
- reserve policy;
- commercial ranking weights;
- restricted product families;
- approved supplier list.

Project overlays SHALL NOT mutate the global catalog.

## 16. Offline/local-first behavior

For mobile/field engineering ELV8 SHOULD support a pinned local catalog snapshot and delta synchronization.

A project SHALL know exactly which catalog snapshot it uses. Offline selection may use cached commercial data only if the UI exposes its timestamp/staleness.

## 17. AI boundary

AI MAY assist with:

- extracting manufacturer datasheets;
- mapping source attributes to canonical schema;
- detecting probable duplicates;
- suggesting missing compatibility links;
- explaining resolver output in natural language.

AI MUST NOT silently create authoritative technical facts, normative passes or final product selections. Human verification and deterministic validation remain authoritative.

## 18. External/hybrid power systems

The catalog and resolver SHALL support utility-independent equipment and assemblies without redesign:

- generators;
- ATS/source transfer equipment;
- UPS;
- batteries and energy storage;
- photovoltaic modules/interfaces relevant to project scope;
- inverters/chargers;
- DC distribution/protection;
- source monitoring/control interfaces.

These products participate through the same capability, compatibility, normative and physical contracts.

## 19. Suggested application interfaces

```dart
abstract interface class CatalogQueryService {
  Future<List<ProductVariant>> findCandidates(EquipmentDemand demand);
}

abstract interface class ConfigurationResolver {
  Future<ResolutionResult> evaluate(ResolutionRequest request);
  Future<ResolvedConfiguration> apply(ResolutionProposal proposal);
}

abstract interface class CommercialSnapshotRepository {
  Future<CommercialSnapshot?> latestFor(String variantId);
}

abstract interface class ConfigurationFreezeService {
  Future<FrozenConfiguration> freeze(String projectId);
}
```

## 20. Acceptance criteria

ELV8 is ready when:

1. catalog class/family/variant identities are separate and versioned;
2. technical facts have typed units and provenance;
3. price/stock/lead time are timestamped snapshots, not engineering truth;
4. resolver consumes ELV5 demands rather than reverse-engineering requirements;
5. ELV7 blocking failures and ELV6 physical failures always eliminate candidates;
6. mandatory accessories are resolved as part of an assembly;
7. selection ranking is explicit, versioned and explainable;
8. no-solution results expose actionable structured causes;
9. manual overrides are audited and cannot bypass non-overridable safety constraints;
10. substitutions and successor products preserve traceability;
11. a frozen project can reproduce the selected technical configuration later;
12. generator/UPS/PV/inverter/storage equipment uses the same generic model;
13. BOM/specification generation uses frozen resolved configuration, not live catalog state;
14. contract tests cover ELV5 → ELV8 demand, ELV7 qualification and ELV6 fit boundaries;
15. golden tests prove deterministic selection for the same pinned inputs.
