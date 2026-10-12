# ADR-013: Industrial electrical loads and routing constraints

## Status
Accepted

## Context

Industrial equipment cannot be represented adequately by only a nominal power value and a generic cable connection. Motors, pumps, compressors, CNC machines, process equipment, VFD-driven loads, PLC/control panels and instrumentation may use three-phase supplies, dedicated circuits, different starting methods and different routing/separation constraints.

The platform must preserve these semantics without coupling the generic routing core to electrical-specific physics.

## Decision

Industrial component definitions may carry a structured electrical load profile and a structured routing profile. The placed equipment instance references the component definition and may provide project-specific overrides where explicitly allowed.

### Supply systems

The electrical model distinguishes at least:

```text
SINGLE_PHASE_AC
THREE_PHASE_AC
DIRECT_CURRENT
CONTROL_VOLTAGE
CUSTOM
```

A three-phase load may declare phase configuration, nominal voltage, frequency, rated power/current, power factor, efficiency and neutral/protective-earth requirements.

Representative example:

```text
Motor 15 kW
supplySystem = THREE_PHASE_AC
nominalVoltageV = 400
phases = 3
frequencyHz = 50
powerFactor = 0.86
efficiency = 0.91
startingMethod = VFD
requiresDedicatedCircuit = true
requiresProtectiveEarth = true
```

### Starting methods

Initial starting-method vocabulary:

```text
NONE
DIRECT_ON_LINE
STAR_DELTA
SOFT_STARTER
VFD
CUSTOM
```

Starting method is part of the engineering definition because it may affect starting current, protection, cable selection, EMC requirements and routing rules.

### Phase configuration

Circuits and loads may distinguish:

```text
L1_N
L2_N
L3_N
L1_L2
L2_L3
L3_L1
L1_L2_L3
L1_L2_L3_N
DC_POS_NEG
CUSTOM
```

Future panel planning may use these contracts for phase balancing. Automatic balancing is not implemented in the foundation branch.

## Routing profile

Electrical component definitions may carry a `RoutingProfile` describing constraints and preferences for connected runs.

Representative attributes:

```text
allowedMethods[]
preferredMethods[]
forbiddenMethods[]
separationClass
minimumBendRadiusMm?
maximumRunLengthMm?
requiresDedicatedConduit
requiresShielding
requiresMechanicalProtection
```

The generic route remains geometry/topology. Electrical routing rules validate whether a particular `CableRun` and its route comply with the component/ruleset constraints.

## Route separation

Initial separation classes include:

```text
GENERAL
POWER
HIGH_POWER
CONTROL
DATA
INSTRUMENTATION
SAFETY
EMC_SENSITIVE
```

Compatibility between classes is ruleset-driven. For example, a VFD-to-motor cable and sensitive instrumentation cable may require separation or shielding depending on the applicable project/ruleset.

The foundation must not hardcode regulatory clearances as universal constants.

## Multi-port industrial equipment

An industrial component may expose several independent ports, for example:

```text
CNC_MACHINE
├── POWER 400 V 3~
├── CONTROL
├── ETHERNET
├── SAFETY
├── COMPRESSED_AIR
├── COOLING_WATER
└── DRAIN
```

Each port may participate in a different engineering network and may create a different physical run type.

## VFD example

A VFD-fed motor is modeled as two distinct cable runs:

```text
Panel
  -> power CableRun
  -> VFD
  -> motor CableRun
  -> Motor
```

This preserves separate cable types, lengths, protection/routing requirements and BOM quantities.

## Cable trays and conduits

Shared physical carrying systems such as conduit and cable tray are first-class physical route resources. Multiple cable runs may share them when rules permit.

Future validation may consider:

- tray/conduit fill;
- reserve capacity;
- cable grouping;
- mechanical protection;
- segregation/separation;
- weight/loading where applicable.

These calculations are deferred until the relevant rulesets and material catalogs are implemented.

## Rule boundaries

The architecture keeps three concerns separate:

```text
ElectricalRules
  -> sizing, protection, voltage drop, phase balance, starting behavior

RoutingRules
  -> laying methods, bend radius, separation, tray/conduit constraints, EMC

EquipmentRules
  -> dedicated circuit, required ports, disconnect/drive requirements, maintenance constraints
```

These may cooperate, but they must not collapse into one untyped generic rule engine.

## Safety and standards

Electra must treat automatic cable sizing, protection selection, separation distances and related engineering decisions as ruleset-dependent recommendations/validation results. Country-, standard- and manufacturer-specific values must be versioned and traceable.

The foundation branch defines contracts only; it does not claim regulatory correctness or perform final engineering calculations yet.
