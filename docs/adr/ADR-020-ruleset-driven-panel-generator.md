# ADR-020: Ruleset-driven panel generator from consumption groups

## Status
Accepted

## Context

Electra must not require the engineer to manually assemble every protective device and outgoing circuit from scratch. The practical workflow starts from consumption groups and equipment loads, then produces a reviewable panel proposal.

Typical inputs include:

- lighting groups;
- general socket groups;
- kitchen / appliance groups;
- HVAC equipment;
- water heaters and electric heating;
- pumps and motors;
- EV chargers;
- industrial machines;
- automation/control loads;
- dedicated or critical loads.

The generated panel must be based on an explicit, versioned electrical ruleset. Hardcoded universal assumptions are forbidden because protection, RCD/RCBO requirements, conductor minimums, diversity, grouping, phase allocation and other requirements depend on jurisdiction, standard, project policy and installation conditions.

## Decision

Introduce a ruleset-driven `PanelGenerationEngine` that converts confirmed consumption/load groups into a proposed electrical distribution topology.

```text
ConsumptionGroup[]
        +
ElectricalRuleset
        +
Project electrical context
        ↓
PanelGenerationEngine
        ↓
PanelGenerationProposal
├── incoming device proposal
├── surge / additional protection proposal
├── protection groups
├── outgoing circuits
├── RCD / RCBO grouping
├── phase assignments
├── cable recommendations
├── spare/reserve strategy
├── panel size / row estimate
├── warnings
└── EngineeringDecision[]
```

The generator proposes; the engineer confirms or modifies.

## Consumption groups

A `ConsumptionGroup` is a design-level grouping of loads that may become one or more circuits.

Representative data:

```text
id
name
loadType
loadIds[]
connectedPowerW
calculatedDemandPowerW?
voltageV
phases
criticality
requiresDedicatedCircuit?
roomIds[]
zoneId?
```

Examples:

```text
Kitchen general sockets
Lighting Floor 02
Oven
Dishwasher
HVAC AHU-02
Pump P-101
Motor M-201
Server rack SR-01
```

## Generation stages

The engine must remain decomposable and testable:

```text
Load classification
→ demand/simultaneity evaluation
→ circuit split proposal
→ design-current calculation
→ conductor sizing proposal
→ protection selection proposal
→ residual-current protection grouping
→ phase allocation/balancing
→ incoming-device sizing proposal
→ reserve/spare allocation
→ physical panel capacity estimate
→ validation / explanation
```

Each stage returns structured decisions and warnings rather than silently mutating the final design.

## Protection topology

The resulting proposal is a topology, not a flat list of breakers.

Representative structure:

```text
Incoming supply
  ↓
Main isolator / main protection
  ↓
Optional SPD
  ↓
Bus / distribution
  ├── RCD group A
  │   ├── MCB C-01
  │   ├── MCB C-02
  │   └── MCB C-03
  ├── RCBO C-04
  ├── RCBO C-05
  └── dedicated motor / equipment protection
```

The exact topology comes from the active ruleset and project policy.

## Ruleset responsibility

`ElectricalRuleset` must be versioned and must provide or reference the rule data needed for at least:

- minimum conductor sections;
- ampacity tables / correction factors;
- voltage-drop limits;
- breaker rating and curve policies;
- RCD / RCBO applicability and grouping policies;
- dedicated-circuit requirements;
- phase and neutral requirements;
- diversity / simultaneity policies;
- panel reserve targets;
- installation-method constraints;
- jurisdiction-specific exceptions.

No numeric regulatory values are embedded in the generic domain model.

## Explainability

Every automatic recommendation must be traceable.

Example:

```text
C-07 Kitchen sockets
Protection: RCBO 16 A
Cable: 3 x 2.5 mm²
Phase: L2

Because:
- load class = GENERAL_SOCKET
- calculated design current = ...
- conductor ampacity requirement = ...
- voltage-drop requirement = ...
- residual-current protection rule = ...
- selected phase reduces panel imbalance

Ruleset: <jurisdiction/standard/version>
```

The generated proposal therefore owns `EngineeringDecision[]` and `warnings[]`.

## User authority

Generation states:

```text
PROPOSED
USER_CONFIRMED
MANUALLY_MODIFIED
VALIDATED
```

The engineer may:

- accept the whole proposal;
- accept selected circuits;
- merge/split groups manually;
- replace protection devices;
- change phase assignment;
- choose a different cable;
- alter RCD grouping;
- change reserve policy.

Manual changes remain visible as overrides and trigger revalidation.

## Panel physical layout integration

After the electrical topology is confirmed:

```text
PanelGenerationProposal
→ PanelAssembly
→ physical layout editor
→ row/DIN rail placement
→ terminal allocation
→ labels/BOM/report
```

The generator may estimate required module count and enclosure size, but the physical layout editor remains the authoritative placement surface.

## Scope guardrail

Initial scope targets low-voltage residential, commercial and light-industrial distribution. Advanced studies such as full short-circuit network analysis, protection discrimination curves, arc-flash, harmonic studies and MV/HV system analysis are separate future capabilities or integrations.

## Consequences

Positive:

- engineer starts from real consumption groups rather than blank panel rows;
- panel topology is consistent with the selected ruleset;
- repetitive work is automated while engineering authority remains with the user;
- generated panel, cables, BOM and documentation remain linked to source loads;
- explanations make automatic recommendations auditable.

Trade-offs:

- ruleset quality becomes safety-critical product data;
- generation must be deterministic and heavily tested;
- jurisdiction-specific rule packages require versioning and maintenance;
- UI must distinguish proposal, confirmation, override and validation states clearly.
