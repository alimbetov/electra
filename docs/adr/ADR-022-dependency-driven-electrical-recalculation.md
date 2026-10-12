# ADR-022: Dependency-driven electrical recalculation

## Status
Accepted

## Context
Electra generates normative circuit and panel proposals from loads, consumption groups, cable/routing context and a versioned electrical ruleset.

When the engineer adds or changes a consumer, changes a consumption group, reassigns a load to another circuit, changes cable/routing parameters, edits a panel feeder or changes the active ruleset, previously generated electrical decisions may become invalid.

Recalculating the entire project after every edit is unnecessary, while silently keeping stale protection/cable/panel decisions is unsafe and misleading.

## Decision
Electra uses dependency-driven recalculation.

```text
Consumer / Equipment
  -> ElectricalLoadProfile
  -> ConsumptionGroup
  -> Circuit proposal / Circuit
  -> Cable sizing
  -> Protection requirement
  -> Phase assignment
  -> Panel generation proposal
  -> Manufacturer product match
  -> Panel layout / BOM / documentation
```

Each derived engineering result records its upstream dependencies and the ruleset revision that produced it.

A material upstream edit marks only downstream dependent results as `STALE` and schedules/requires recalculation of the affected subgraph.

## Recalculation triggers
Initial trigger categories include:

- consumer added, removed or materially edited;
- rated power/current/voltage/phases changed;
- load type or duty/start method changed;
- consumption-group membership changed;
- dedicated-circuit requirement changed;
- circuit membership changed;
- simultaneity/demand assumptions changed;
- route length or laying method changed;
- cable properties changed;
- protection selection changed;
- panel feeder or panel rating changed;
- phase assignment changed;
- project ruleset or ruleset version changed;
- manufacturer policy/catalog changed when concrete product matching depends on it.

## Recalculation scope
The engine recalculates the smallest safe dependency subgraph.

Example:

```text
Add oven to Kitchen
  -> Kitchen consumption group stale
  -> affected circuit proposal stale
  -> design current stale
  -> cable sizing stale
  -> protection requirement stale
  -> panel phase/load summary stale
  -> manufacturer match stale
  -> panel layout may become stale if module width changes
  -> BOM/report stale
```

An unrelated bedroom lighting circuit must remain unchanged.

## Derived-state lifecycle
Derived engineering artifacts use at least:

```text
CURRENT
STALE
RECALCULATING
REVIEW_REQUIRED
VALIDATED
ERROR
```

`STALE` means the stored result may no longer be relied on as current engineering advice.

## Manual overrides
Manual engineer decisions are not silently overwritten.

A manual override stores:

- overridden field/value;
- engineer rationale/notes;
- source generated proposal;
- ruleset version;
- upstream dependency fingerprint;
- validation status.

After an upstream change, Electra recalculates the normative proposal and compares it with the manual override.

Possible outcomes:

```text
override remains compliant -> keep override, mark reviewed/current
normative result changed but override remains acceptable -> REVIEW_REQUIRED
new result conflicts with override -> validation warning/error
```

The application must never silently replace an engineer-confirmed manual choice.

## Explainability
Every recalculation result must preserve a reason chain.

Example:

```text
Q7 protection changed
16 A -> 20 A

Reason:
- design current increased after adding consumer OVEN-01
- consumption group Kitchen increased from ... to ...
- ruleset requirement ...
- cable/protection coordination re-evaluated
```

The UI must provide a `What changed?` view for affected engineering decisions.

## Manufacturer catalogs
Normative recalculation and manufacturer matching are separate phases.

```text
Ruleset
  -> FunctionalDeviceRequirement
  -> ManufacturerProductMatcher
  -> Schneider / ABB / Siemens / Legrand / ... product
```

A load change may change the functional requirement, which invalidates the current manufacturer match. A catalog refresh alone may change available product matches without changing the underlying normative requirement.

## Panel impact
Panel recalculation may affect:

- circuit count;
- breaker/RCD/RCBO requirements;
- main device requirement;
- phase balance;
- connected/design load;
- DIN module occupancy;
- number of rows required;
- enclosure size recommendation;
- terminal count;
- reserve capacity;
- BOM and documentation.

Electra should provide warnings before applying layout-destructive changes.

## UX
Normal workflow:

```text
Engineer edits consumers
  -> affected items show recalculation indicator
  -> normative proposal refreshes
  -> changed recommendations are highlighted
  -> engineer reviews material changes
  -> confirmed panel/layout is updated
```

Minor deterministic derived values may update immediately. Safety-relevant or engineer-confirmed decisions require visible review when materially changed.

## Persistence
Persist dependency/revision metadata sufficient to determine whether a derived result is current after restart/offline use.

Suggested concepts:

```text
EngineeringDependencyRef
EngineeringInputFingerprint
EngineeringDerivedState
RecalculationImpact
RecalculationEvent
```

The exact storage representation is deferred to the persistence implementation.

## Acceptance criteria

1. Adding a consumer only invalidates affected groups/circuits/panels and downstream reports.
2. Removing a consumer recomputes affected normative recommendations.
3. Changing route length can invalidate voltage-drop/cable-sizing decisions without rebuilding unrelated circuits.
4. Changing ruleset version invalidates all results derived from that ruleset.
5. Manual overrides are never silently replaced.
6. Every material change exposes before/after values and reasons.
7. Manufacturer matching is rerun when a functional device requirement changes.
8. Panel capacity/layout warnings are produced when recalculation changes physical occupancy.
