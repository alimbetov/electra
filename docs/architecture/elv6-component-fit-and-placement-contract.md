# ELV6 — Component Fit and Placement Contract

Status: normative design contract  
Branch: `feat/flutter-elv6-enclosure-layout-design`

## 1. Purpose

ELV6 SHALL answer one question for a concrete or abstract component candidate:

> Can this equipment be physically installed, wired, cooled, serviced and reserved inside the selected enclosure/rack under the project constraints?

ELV6 owns **physical evidence**, not product selection policy and not normative law.

## 2. Inputs from the catalog boundary

ELV6 SHALL consume a normalized physical profile, not manufacturer-specific JSON.

```dart
final class ComponentPhysicalProfile {
  final String componentRef;
  final MountingProfile mounting;
  final Dimensions dimensions;
  final ClearanceEnvelope clearance;
  final ThermalProfile thermal;
  final TerminalProfile terminals;
  final Set<MechanicalCapability> capabilities;
  final Provenance provenance;
}
```

Required concepts include:

- DIN width/modules;
- rack units;
- width/height/depth and orientation;
- mounting family and adapter requirements;
- mass/load where relevant;
- heat dissipation and derating inputs;
- terminal location/direction;
- conductor/cable entry envelope;
- minimum bend/working clearance;
- ventilation zone;
- forbidden adjacency or required accessory relations;
- service/removal clearance.

## 3. Physical constraints are hard constraints

The following MUST NOT be converted into soft ranking penalties:

- component exceeds enclosure/rack dimensions;
- unsupported mounting interface;
- clearance collision;
- cable bend/entry impossibility;
- terminal access impossibility;
- thermal envelope outside supported limit;
- mass/load limit exceeded;
- mandatory accessory cannot be placed;
- reserved expansion space violated when project policy marks it mandatory.

A cheaper product MUST never win by violating a hard physical constraint.

## 4. Placement result

```dart
sealed class PlacementAssessment {
  const PlacementAssessment();
}

final class PlacementAccepted extends PlacementAssessment {
  final PlacementPlan plan;
  final List<PlacementEvidence> evidence;
}

final class PlacementRejected extends PlacementAssessment {
  final List<PlacementViolation> violations;
}
```

Every violation SHALL expose a stable code, affected entities, measured value, allowed envelope and remediation hint.

## 5. Abstract-before-concrete workflow

ELV6 SHALL support two phases:

1. **capacity planning** with abstract component classes/envelopes before SKU selection;
2. **candidate validation** after ELV8 proposes a concrete product variant.

This prevents the layout engine from depending on one vendor catalog and allows early enclosure sizing.

## 6. Compatibility with autoconfiguration

ELV6 SHALL expose a pure evaluation boundary conceptually equivalent to:

```dart
abstract interface class ComponentFitEvaluator {
  FitAssessment evaluate({
    required EnclosureLayoutSnapshot layout,
    required ComponentPhysicalProfile candidate,
    required PlacementIntent intent,
  });
}
```

The evaluator MUST be deterministic for the same layout/profile/policy versions.

ELV8 MAY call this evaluator while filtering candidates, but ELV6 SHALL NOT rank by price, stock or brand preference.

## 7. Reserve and growth

Reserve SHALL be explicit, typed and policy-driven:

- spare DIN modules;
- spare rack units;
- spare power/thermal capacity;
- spare terminal capacity;
- routing reserve;
- service clearance.

`freeSpace > 0` is not equivalent to required engineering reserve.

## 8. Accessories and assemblies

A product may require physical dependencies such as:

- mounting adapter;
- busbar/comb;
- auxiliary contact;
- terminal block;
- fan/filter;
- gland/entry accessory;
- rail/support;
- rack shelf;
- blanking panel.

ELV6 evaluates the complete resolved assembly envelope. It MUST NOT validate only the primary SKU while ignoring mandatory accessories.

## 9. Thermal and derating boundary

ELV6 owns the physical inputs/evidence for enclosure thermal feasibility. Calculation coefficients and normative thresholds SHALL be versioned outside ad-hoc UI code.

ELV6 SHALL produce facts such as occupancy, dissipation aggregation, ventilation assumptions and temperature envelope so ELV7 can issue the normative compliance verdict where required.

## 10. Acceptance criteria

1. both abstract envelopes and concrete product variants can be evaluated;
2. DIN, rack and free-form enclosure equipment share one typed fit contract;
3. mandatory accessories participate in collision/capacity evaluation;
4. physical rejection returns stable machine-readable reasons;
5. reserve is first-class and cannot be silently consumed;
6. the same inputs and versions produce the same placement assessment;
7. ELV8 can evaluate multiple candidates without mutating project layout;
8. successful resolution can be frozen as a placement snapshot for deliverables;
9. generator/UPS/inverter/battery/PV-related cabinet equipment can use the same physical-profile model without dedicated schema branches.
