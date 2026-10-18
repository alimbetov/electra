# ELV8 — Project Workspace Autoconfiguration and Deliverables Roadmap

Status: normative implementation roadmap  
Branch: `feat/flutter-elv8-deliverables-design`

## 1. Purpose

ELV8 turns vendor-neutral engineering demand into explainable candidate configurations, explicit engineer decisions, frozen configurations and deliverables.

ELV8 owns:

- catalog identities/classes/families/variants;
- candidate generation;
- compatibility/accessory closure;
- orchestration of ELV7 normative and ELV6 physical checks;
- explainable ranking among technically valid candidates;
- recommendations/alternatives;
- explicit Apply/override/pin decisions;
- configuration freeze;
- BOM/specification/schedule generation.

ELV8 never rewrites upstream ELV5 calculations and never bypasses ELV6/ELV7 blockers.

## 2. User journey owned by ELV8

```text
open CONFIGURE for MAIN/NODE
 -> consume EquipmentDemand
 -> generate candidates
 -> close required accessories
 -> qualify via ELV7
 -> fit-check via ELV6
 -> rank survivors
 -> show recommendation + alternatives + reasons
 -> engineer explicitly Apply
 -> freeze approved configuration
 -> generate deliverables
```

## 3. Implementation packages

### W8-0 — upstream contract reconciliation

- pin accepted EquipmentDemand schema/fingerprint semantics from ELV5;
- pin ELV6 fit-evaluation contract;
- pin ELV7 normative-candidate contract;
- reject stale upstream projections for final Apply/Freeze;
- preserve historical selection snapshots.

Gate: ELV8 does not infer missing engineering requirements from catalog data.

### W8-1 — catalog canonical core

Implement normalized identities:

```text
ComponentClass
ProductFamily
ProductVariant/SKU
Manufacturer
TechnicalFact
PhysicalProfileRef
CertificationClaim
CompatibilityRelation
CatalogSnapshot
```

Rules:

- core technical attributes are typed;
- provenance is mandatory for authoritative facts where available;
- price/stock/lead time are separate temporal commercial snapshots;
- unknown facts remain unknown.

### W8-2 — candidate generation

Input: one or more `EquipmentDemand` items scoped to node/project configuration.

Pipeline start:

1. semantic class match;
2. required capability match;
3. mandatory fact completeness;
4. hard electrical/functional constraints.

Gate: no brand/name string matching as engineering authority.

### W8-3 — compatibility and accessory closure

Resolve complete assemblies using relation types such as:

```text
REQUIRES
COMPATIBLE_WITH
INCOMPATIBLE_WITH
ACCESSORY_FOR
MOUNTABLE_ON
REQUIRES_ADAPTER
SUBSTITUTE_FOR
SUCCESSOR_OF
```

Rules:

- mandatory accessory closure precedes final fit/compliance;
- circular/ambiguous required relations fail explicitly;
- primary SKU alone cannot be accepted if mandatory dependencies are unresolved.

### W8-4 — ELV7 + ELV6 orchestration

For each candidate assembly:

```text
technical hard filters
 -> ELV7 normative evaluation
 -> ELV6 physical fit evaluation
 -> reject blockers
```

Both calls are side-effect free before Apply.

Gate: no candidate with blocking ELV6/ELV7 result may enter ranking.

### W8-5 — explainable ranking

Rank only technically valid candidates by versioned policy.

Possible criteria:

- manufacturer preference;
- installed cost;
- availability;
- lead time;
- space efficiency;
- standardization/reuse;
- energy efficiency/loss;
- spare capacity;
- lifecycle state;
- evidence completeness.

Required output:

```text
recommendation
alternatives
criterion contributions
technical acceptance summary
rejection reasons for excluded near-candidates
```

Gate: deterministic tie-break and policy version pinning.

### W8-6 — client recommendation workflow

Workspace presentation:

```text
Problem
  NODE-F2 needs >=28 ports and required PoE budget

Recommendation
  Candidate A
  ✓ technical requirements
  ✓ ELV7
  ✓ ELV6
  ✓ reserve

Alternatives
  Candidate B
  Candidate C

[Apply] [Compare] [Why?]
```

No automatic mutation on recommendation generation.

### W8-7 — no-solution diagnostics

Return structured result when no candidate qualifies:

```text
NO_CANDIDATE
blocking dimensions
missing facts
closest candidates
normative blockers
physical blockers
compatibility blockers
remediation options
```

The UI must tell the engineer what must change upstream or in configuration scope.

### W8-8 — manual pin/override/substitution

Engineer may explicitly:

- pin a technically valid candidate;
- select an approved alternative;
- record a project substitution;
- choose a successor product;
- override ranking policy where allowed.

Cannot bypass non-overridable ELV7 or required ELV6 constraints.

### W8-9 — node configuration snapshot

After Apply, persist/freeze a reproducible resolved configuration with:

```text
projectRevision
node/configuration scope
engineeringDemandFingerprint
catalogSnapshotId
normative profile/rulePack
layout snapshot
selectionPolicyVersion
commercialSnapshotId when used
component/accessory identities
decisions/rejections
configuration fingerprint
```

### W8-10 — ISSUE / deliverables

Generate deliverables from frozen configuration, never live catalog state:

- BOM;
- equipment schedule;
- cable/termination schedule where owned/available;
- panel/node schedule;
- selected enclosure/rack equipment list;
- alternatives/substitution history where required;
- normative evidence references;
- configuration summary;
- export/report payloads.

### W8-11 — golden vertical

Mandatory end-to-end scenario:

```text
NODE-F2 has insufficient current switch configuration
 -> consume ELV5 demand
 -> generate valid 48-port PoE candidates
 -> reject missing-fact candidate
 -> ELV7 rejects one normative candidate
 -> ELV6 rejects one depth/space candidate
 -> rank remaining candidates
 -> show recommendation + alternative
 -> engineer Apply
 -> freeze
 -> generate node BOM/schedule
```

## 4. Testing

Required:

- demand contract tests;
- candidate hard-filter boundaries;
- compatibility/accessory closure tests;
- normative/fit orchestration tests;
- deterministic ranking/tie-break tests;
- no-solution diagnostics;
- commercial snapshot staleness;
- substitution/successor tests;
- offline catalog snapshot tests;
- frozen replay tests;
- deliverables-from-frozen-state tests.

## 5. Completion gate

ELV8 workspace implementation is complete when the engineer can request configuration for a node, receive explainable technically valid recommendations, explicitly apply one, reproduce/freeze the decision and issue BOM/specification outputs without hidden upstream recalculation or silent design mutation.
