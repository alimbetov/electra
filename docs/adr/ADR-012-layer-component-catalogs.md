# ADR-012: Per-layer component catalogs

## Status
Accepted

## Context

Electra supports multiple engineering disciplines. Each discipline needs its own vocabulary of engineering objects, presets and technical metadata while still sharing the same spatial model, routing model and equipment-port concepts.

A single flat global component list would become difficult to navigate, would mix unrelated engineering semantics and would make domain-specific validation harder.

At the same time, users and projects must be able to define custom components without modifying the built-in system catalog.

## Decision

Each engineering `Discipline` owns an independent component library.

```text
EngineeringLayer
  -> LayerComponentLibrary
       -> System definitions
       -> Project definitions
       -> User definitions
```

Representative libraries:

```text
ELECTRICAL
  sockets
  switches
  luminaires
  distribution boards
  protection devices
  cables
  conduits
  motors
  drives

PLUMBING
  sinks
  valves
  manifolds
  pumps
  fixtures
  pipe definitions

HVAC
  indoor units
  outdoor units
  fans
  diffusers
  dampers
  duct definitions

CCTV
  cameras
  recorders
  PoE switches
  cabinets

INDUSTRIAL_AUTOMATION
  motors
  VFDs
  PLC panels
  sensors
  actuators
  instruments
```

## Definition vs instance

Catalog records are definitions. Objects placed in a project are instances.

```text
ComponentDefinition
        ↓
ComponentInstance
```

A definition contains reusable engineering defaults:

```text
id
code
nameKey / displayName
category
primaryDiscipline
compatibleDisciplines[]
source
version
symbol
mounting defaults
geometry defaults
port definitions[]
engineering profile
metadata
```

A placed instance references the definition and stores only project-specific state:

```text
id
projectId
layerId
definitionId
definitionVersion
surfacePatchId?
position / orientation
instanceName
instanceOverrides
phase
installationStatus
```

Changing a system definition must not silently mutate already approved project instances. Definition versioning or explicit migration is required.

## Definition sources

```text
SYSTEM
USER
PROJECT
IMPORTED
```

### SYSTEM

Curated built-in Electra definitions. They are read-only to the user. A user may duplicate a system definition into a custom definition.

### USER

Reusable definitions owned by a user/workspace and available across projects.

### PROJECT

Definitions that exist only inside one project. Useful for one-off devices, vendor-specific equipment or project-specific assemblies.

### IMPORTED

Definitions created from a future manufacturer/library/import workflow. Imported data remains distinguishable from curated Electra system definitions.

## Custom components

A custom component is not an untyped JSON object. It uses the same typed catalog contract as a system component and may declare:

- category;
- disciplines;
- mounting defaults;
- visual symbol;
- dimensions;
- `EquipmentPort` definitions;
- electrical load profile;
- hydraulic/HVAC/network properties when supported;
- custom metadata.

Unsupported discipline-specific metadata may be stored as namespaced extension data, but core engineering fields must stay typed.

## Cross-discipline equipment

One physical device may participate in multiple layers.

Example:

```text
AirConditionerIndoorUnit
  primary discipline: HVAC

  ports:
    POWER          -> ELECTRICAL
    CONTROL        -> INDUSTRIAL_AUTOMATION / LOW_VOLTAGE
    REFRIGERANT_IN -> HVAC
    REFRIGERANT_OUT-> HVAC
    DRAIN          -> DRAINAGE
```

The definition belongs primarily to one catalog but its typed ports allow network connections from other engineering layers.

## Electrical engineering profile

Electrical-capable definitions may carry an `ElectricalLoadProfile` used later by circuit planning and cable/protection sizing.

Representative fields:

```text
ratedPowerW
ratedCurrentA?
nominalVoltageV
phases
powerFactor?
efficiency?
loadType
startingCurrentFactor?
dedicatedCircuitPolicy
protectionHints
```

The profile is input data for future calculation engines. It is not itself a regulatory conclusion.

## Library UX

When a layer/tool is active, only its relevant library is shown.

```text
Equipment
  -> Search
  -> Recent
  -> Favorites
  -> Project presets
  -> Categories
```

The user should not browse electrical, plumbing, HVAC and CCTV objects in one mixed palette.

System and custom items may be visually distinguished but participate in the same placement workflow.

## Persistence

Expected local persistence concepts:

```text
component_definitions
component_definition_ports
component_definition_profiles
project_component_overrides
equipment_items
```

Catalog definitions use stable UUIDs and explicit versions.

## Consequences

- every engineering layer can evolve independently;
- built-in and custom components use one common contract;
- catalogs remain searchable and ergonomic;
- calculation engines can consume typed component profiles;
- manufacturer/import catalogs can be added later without redesigning placed project objects;
- project instances remain stable when catalog definitions evolve.
