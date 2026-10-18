# ELV8 — Client-Oriented Autoconfiguration Workflow

Status: normative product/design contract  
Branch: `feat/flutter-elv8-deliverables-design`

## 1. Product intent

ELV8 SHALL make automatic equipment configuration understandable and controllable for the engineer.

The user-facing workflow SHALL be centered on the project object (`DistributionNode`, circuit, subsystem or assembly), not on catalog tables.

```text
open MAIN/NODE
  -> see what equipment/functions are required
  -> ask Electra to propose configuration
  -> review recommendation + alternatives
  -> understand why candidates were accepted/rejected
  -> explicitly apply
  -> freeze for BOM/specification/deliverables
```

Automatic configuration SHALL never silently mutate the accepted project.

## 2. From node demand to equipment proposal

ELV8 SHALL consume typed `EquipmentDemand` projected by ELV5 for the selected node/project scope.

Example:

```text
NODE-F2
  requires >= 28 Ethernet ports
  requires >= 14 PoE ports
  requires PoE budget >= X W
  requires uplink capability >= Y
  requires ACS controller channels >= Z
  requires backup/autonomy capability
        ↓
ELV8 candidate resolution
        ↓
recommended equipment assembly
```

ELV8 SHALL NOT infer requirements directly from UI labels or reverse-engineer raw ELV5 persistence.

## 3. Recommendation model

The primary user result SHALL distinguish:

```text
RECOMMENDED
ALTERNATIVE
REJECTED
NO_SOLUTION
```

For every recommendation the UI SHOULD be able to explain:

- which requirements it satisfies;
- remaining reserve;
- physical-fit state from ELV6;
- normative state from ELV7;
- mandatory accessories;
- major ranking reasons;
- commercial snapshot age when used;
- trade-offs against alternatives.

## 4. Actionable alternatives

ELV8 SHOULD prefer engineering actions over opaque scoring.

Example:

```text
Problem: NODE-F2 requires 28 ports; current assembly provides 24.

Options:
1. replace with a 48-port switch;
2. add a second smaller switch;
3. change reserve policy if project policy permits.

Recommended: option 1
Reason:
- fewer devices;
- preserves required reserve;
- PoE budget remains valid;
- fits the enclosure;
- passes current normative profile.
```

A recommendation SHALL NOT imply that a project policy change is automatically acceptable. Policy changes require explicit engineer action and downstream recalculation/qualification.

## 5. Explicit apply boundary

Candidate evaluation is side-effect free.

Only an explicit user action SHALL create or replace a resolved configuration.

```text
Evaluate -> Proposal -> Review -> Apply -> Freeze
```

Refresh, navigation, recalculation or catalog synchronization MUST NOT implicitly apply a different SKU.

## 6. Main vs node configuration

MAIN and NODE use the same configuration engine.

A MAIN node may aggregate or host equipment for downstream nodes where upstream engineering demand permits it. A NODE may host local distribution/equipment.

The resolver SHALL use actual demand and topology rather than a hard-coded assumption that MAIN means one equipment family and NODE another.

## 7. Progressive configuration

The product SHALL support partial project maturity.

Before all exact catalog data is available, the user may work with:

```text
required capability/envelope
  -> abstract configuration need
  -> ELV6 capacity planning
```

Later:

```text
exact catalog snapshot
  -> concrete candidates
  -> ELV7 qualification
  -> ELV6 exact fit
  -> resolved assembly
```

Missing mandatory engineering evidence SHALL yield `NEEDS_DATA`/`NO_SOLUTION`, not a guessed product.

## 8. No-solution UX

`NO_SOLUTION` SHALL be actionable.

Instead of an empty result, the user SHALL receive structured causes such as:

- no candidate meets required breaking capacity;
- no switch meets port + PoE + uplink constraints;
- candidates fail enclosure depth;
- mandatory accessory closure cannot fit;
- normative evidence is missing;
- required operating mode is unsupported.

Where possible ELV8 SHALL show closest candidates and the exact blocking dimensions without recommending an unsafe relaxation.

## 9. Commercial transparency

Price/availability MAY influence ranking only after technical acceptance.

If commercial data affected recommendation, the UI SHALL expose:

```text
supplier
price/currency
observedAt
availability
lead time
staleness
```

Stale or missing commercial information SHALL NOT invalidate technical suitability, but it SHALL affect the confidence of commercial ranking shown to the user.

## 10. Manual pinning and substitution

The engineer MAY pin a technically valid candidate or choose a valid alternative.

The UI SHALL explain differences such as:

- cost;
- reserve;
- space;
- energy/loss efficiency;
- standardization with existing equipment;
- availability;
- lifecycle state.

Manual choice SHALL still respect non-overridable ELV7 blockers and mandatory ELV6 physical constraints.

## 11. Freeze and deliverables

When the engineer freezes a configuration, ELV8 SHALL freeze all identities necessary for reproduction:

- project revision;
- demand fingerprint;
- catalog snapshot;
- selected variants/accessories;
- ELV6 layout/fit snapshot;
- ELV7 normative profile/result references;
- selection policy;
- commercial snapshot when used;
- explicit user decisions/overrides.

BOM, schedules and specifications SHALL derive from this frozen configuration, not from live catalog state.

## 12. Client-oriented acceptance

1. a user can request configuration from a MAIN/NODE view without browsing catalog tables;
2. recommendation and alternatives are explainable in engineering terms;
3. no candidate is applied without an explicit user action;
4. ELV6 physical rejection and ELV7 blocking rejection always eliminate a candidate;
5. no-solution state returns actionable causes;
6. commercial ranking is visibly separate from technical suitability;
7. partial/abstract configuration is supported before exact SKU resolution;
8. node/project changes invalidate only affected proposals/resolutions;
9. manual substitutions remain auditable and technically constrained;
10. frozen deliverables reproduce the exact accepted configuration later.
