# Electra — Canonical ELV Discipline Model

Status: ACCEPTED ARCHITECTURE — ELV1/ELV2 baseline
Accepted baseline: `main@f05b1e558a93b40928429ca86d91f4daa0cf4ef0`
Next stage: `ELV3-P0` physical-routing design/audit

## 1. Decision

ELV in Electra is a **first-class engineering discipline family**.

It is not modeled as:

- a generic bag of component properties;
- a single `ELV` enum value;
- a collection of vendor-specific products;
- a rule-engine configuration without domain semantics;
- a clone of the electrical-power module.

Electra uses a two-level architecture:

```text
COMMON ENGINEERING KERNEL
geometry / placement / ports / connections / cables / cable runs /
routes / enclosures / dependency graph / result provenance / reporting
                         │
                         ▼
ELV DISCIPLINE LAYER
reference catalogs / topology profiles / engineering rules /
calculation processes / discipline validators / selection policies
                         │
       ┌─────────────────┼──────────────────┐
       ▼                 ▼                  ▼
     CCTV              LAN/СКС            СКУД ...
                                             │
                                             ▼
                                     FIRE ALARM / others
```

## 2. Mandatory discipline ownership

Each ELV discipline must own its domain semantics.

### CCTV owns

- camera engineering classes;
- optical/coverage profiles;
- stream/codec profiles;
- recording/storage profiles;
- recorder capacity profiles;
- CCTV-specific topology/validation;
- CCTV bandwidth and storage calculations.

### LAN / structured cabling owns

- copper/fiber categories;
- permanent-link/channel profiles;
- switch-port classes;
- patching semantics;
- fiber-loss profiles;
- LAN link, port, rack and optical-budget calculations.

### Access control owns

- door/access-point topology profiles;
- reader/credential/interface classes;
- lock behavior/current profiles;
- controller I/O profiles;
- ACS completeness, capacity, PSU and autonomy calculations.

### Fire alarm owns

- fire loop architecture;
- detector/module/device classes;
- loop capacity profiles;
- standby/alarm consumption profiles;
- fire cable requirements;
- fire PSU/battery/topology calculations;
- safety-critical validation policies.

## 3. What remains shared

The following must not be reimplemented per discipline:

- project/building/floor/room geometry;
- placement and surface anchors;
- `EngineeringComponent` identity;
- persisted `Port` instances;
- `Connection` graph foundation;
- `Cable`, `CableAllocation`, `CableRun`, `Route`;
- physical enclosure foundation;
- manufacturer identity foundation;
- units and physical quantities;
- dependency/recalculation orchestration;
- calculation run/provenance infrastructure;
- validation finding envelope;
- undo/redo;
- BOM/report pipeline.

## 4. Reference-data rule

Electra must use **typed reference catalogs**.

Prohibited design:

```text
reference_value(
  type,
  key,
  value
)
```

as the sole model for all engineering data.

A generic property mechanism may exist for extension metadata, but canonical calculations and validators must depend on typed contracts and versioned profiles.

Detailed requirements are defined in:

- `docs/product/elv-reference-data-catalogs.md`

## 5. Calculation rule

A discipline-specific engineering calculation must have:

- stable process code;
- algorithm version;
- typed input contract;
- typed result contract;
- explicit reference/profile dependencies;
- deterministic units and rounding;
- dependency invalidation rules;
- reproducible calculation trace.

Detailed requirements are defined in:

- `docs/architecture/elv-calculation-processes.md`

## 6. Canonicality test

A new ELV feature is architecturally acceptable only if the following questions have explicit answers:

1. Is this concept physical/common or discipline-specific?
2. Which canonical catalog owns its classification?
3. Which calculation process consumes it?
4. Which profile/version supplies thresholds and coefficients?
5. Which domain object becomes stale when it changes?
6. Can the result be reproduced later?
7. Can the engineer see how the result was calculated?
8. Is manufacturer data mapped to canonical engineering semantics?
9. Is the concept reusable without introducing a vendor-specific branch in the domain model?
10. Does the implementation avoid duplicating the common route/connectivity kernel?

## 7. Boundary examples

### PoE

PoE has both shared and discipline-specific aspects.

Shared:

- electrical power quantity;
- port compatibility;
- cable length;
- cable resistance;
- connection path.

Discipline/profile-specific:

- applicable PoE standard/profile;
- reserve policy;
- switch port/budget policy;
- endpoint acceptance rules.

### Battery

Shared:

- battery product;
- voltage;
- nominal capacity;
- physical dimensions;
- enclosure placement.

Discipline-specific:

- required standby duration;
- alarm duration;
- reserve factor;
- aging/temperature policy;
- accepted sizing rule.

Therefore fire alarm and ACS may use the same physical battery model but different autonomy calculation profiles.

## 8. Reference architecture

```text
Project
│
├── EngineeringSystem
│   ├── SystemMembership
│   └── TopologyGroup
│
├── EngineeringComponent
│   ├── Port
│   ├── Capability
│   └── InternalConnectivity
│
├── ComponentAssembly
├── Connection
├── Cable / CableAllocation
├── CableRun / Route
├── Enclosure
│
├── ReferenceSnapshot
│   ├── CommonEngineeringCatalogs
│   ├── ElvCommonCatalogs
│   ├── CctvCatalogs
│   ├── LanCatalogs
│   ├── AcsCatalogs
│   └── FireAlarmCatalogs
│
└── CalculationWorkspace
    ├── common physical calculations
    ├── CCTV calculations
    ├── LAN calculations
    ├── ACS calculations
    └── Fire alarm calculations
```

## 9. Product implication

The engineer should see discipline-native terminology in UI and reports.

Examples:

- CCTV: camera, stream, coverage, recorder, retention;
- LAN: permanent link, channel, patch panel, port, fiber budget;
- ACS: access point, lock, reader, controller channel, autonomy;
- Fire: loop, address, detector, isolator, standby/alarm current.

The application may share implementation infrastructure internally, but it must not expose a lowest-common-denominator generic model to the engineer.

## 10. Decision status

This is a foundational constraint for subsequent ELV design.

Future implementation plans must conform to all three documents:

1. `elv-domain-model-and-invariants.md`
2. `elv-reference-data-catalogs.md`
3. `elv-calculation-processes.md`

Any intentional deviation requires an ADR before implementation.
