# Electra Professional Electrical Platform — Target Architecture

Status: TARGET / NORTH STAR / NOT IMPLEMENTATION / NOT ACCEPTANCE

## 1. Purpose

This document defines the target product and architecture boundary for Electra.

Electra is not intended to become a generic MEP/BIM replacement. The target is a modern electrical + ELV engineering platform for building engineers that can design, calculate, validate, audit, document, share and later verify electrical systems in the field.

The target branch exists as a reference point for implementation branches. It must not be interpreted as proof that any capability is implemented, qualified or accepted.

## 2. Product thesis

Electra shall model a building electrical system as one engineering project where changes propagate through dependent calculations and deliverables.

Target workflow:

```text
FIELD / PROJECT INPUT
        ↓
UNIFIED PROJECT MODEL
        ↓
ELECTRICAL TOPOLOGY
        ↓
POWER + ELV CALCULATIONS
        ↓
AUTOMATIC RECALCULATION
        ↓
ENGINEERING VALIDATION
        ↓
PROJECT AUDIT
        ↓
SLD / SCHEDULES / BOM
        ↓
ENGINEERING DOSSIER
        ↓
SHARE / FIELD VERIFICATION
```

Primary differentiators:

1. Power + ELV in one model.
2. Deterministic, reproducible and traceable engineering calculations.
3. Offline-first mobile workflow.
4. Automatic engineering audit rather than isolated calculators.
5. Professional project deliverables generated from the same source model.

## 3. Product boundary

### 3.1 In scope

Electra owns electrical engineering for building and facility systems:

- electrical sources and distribution;
- switchboards, panelboards and MCCs;
- protective devices;
- cables, conductors, busduct and containment interfaces;
- electrical loads;
- motors and drives;
- normal and emergency power;
- earthing, bonding and SPD;
- lighting and small power electrical circuits;
- CCTV, LAN, ACS and FIRE electrical/discipline engineering;
- engineering calculations and normative validation;
- electrical operating/failure scenarios;
- equipment selection and project deliverables;
- project audit, revision and field verification.

### 3.2 Explicitly not core scope

Electra shall not become a full generic MEP solver in its core.

The following may be represented as external engineering inputs or future integrations but are not part of the mandatory electrical core:

- full hydraulic network design;
- full thermal building calculation;
- CFD;
- structural design;
- architectural BIM authoring;
- gas-network process design;
- full HVAC duct sizing engine;
- generic mechanical plant simulation.

Mechanical equipment such as pumps, boilers, chillers and fans are in scope as typed electrical consumers and functional assets.

## 4. Mandatory professional capability map

A market-ready professional Electra shall cover the following capability domains.

### CAP-01 Project model

Required:

- project identity;
- design revision;
- immutable/frozen revisions;
- current vs historical state;
- deterministic project snapshot;
- project-level dependency graph;
- offline persistence;
- import/export boundary.

### CAP-02 Electrical topology

Canonical target path:

```text
GRID
 ↓
TRANSFORMER
 ↓
MDB
 ↓
BUS
 ↓
BREAKER
 ↓
FEEDER
 ↓
CABLE / BUSDUCT
 ↓
DB / MCC
 ↓
BREAKER / STARTER / VFD
 ↓
LOAD
```

Required primitives:

- ElectricalAsset;
- ElectricalNode;
- ElectricalConnection;
- ElectricalPath;
- source-to-load traversal;
- load-to-source traversal;
- disconnected/island detection;
- deterministic topology fingerprint.

### CAP-03 Sources and transformation

Required asset families:

- utility/grid;
- transformer;
- generator;
- UPS;
- battery;
- BESS;
- PV/inverter integration boundary;
- ATS/source-transfer device.

Required semantics:

- normal source;
- emergency source;
- source priority;
- transfer sequence;
- source availability;
- source operating mode.

### CAP-04 Loads and demand

Required:

- connected load;
- demand load;
- diversity/simultaneity;
- active/apparent/reactive power where applicable;
- power factor;
- efficiency;
- phase configuration;
- criticality;
- load priority;
- operating state;
- demand profile;
- phase allocation;
- phase-balance analysis.

### CAP-05 Switchboards / panelboards / MCC

Required:

- incomer;
- bus rating;
- outgoing ways;
- poles/phases;
- spare/reserved ways;
- circuit assignment;
- per-phase load summary;
- panel schedule;
- MCC motor feeder representation;
- board capacity checks.

### CAP-06 Cables, conductors and containment

Required:

- conductor material;
- insulation system;
- number of loaded conductors;
- installation method;
- ambient temperature;
- grouping;
- correction factors;
- parallel conductors;
- N/PE/PEN semantics;
- route sections;
- route governing section;
- cable tray/conduit/ladder/trunking integration boundary;
- containment fill/capacity model;
- cable schedule.

### CAP-07 Core electrical calculations

Mandatory calculation chain:

```text
LOAD / DEMAND
     ↓
Ib
     ↓
Iz
     ↓
CABLE SIZE
     ↓
VOLTAGE DROP
     ↓
PROTECTION In
     ↓
Ib ≤ In ≤ Iz
     ↓
SHORT CIRCUIT
     ↓
BREAKING CAPACITY
     ↓
TRIP / PROTECTION CHECK
```

Required calculation families:

- AC single phase;
- AC three phase;
- DC;
- ampacity;
- voltage drop;
- short-circuit current min/max;
- conductor thermal withstand;
- protection breaking-capacity validation.

### CAP-08 Protection and coordination

Required progression:

1. breaker/fuse identity and ratings;
2. Ib/In/Iz validation;
3. breaking capacity;
4. trip-condition validation;
5. earth-fault related protection where applicable;
6. TCC model;
7. selectivity;
8. coordination;
9. I²t / thermal energy checks.

Protection findings shall distinguish calculation failure from engineering non-compliance.

### CAP-09 Motors and drives

Required:

- motor electrical load;
- DOL;
- star-delta;
- soft starter;
- VFD;
- rated current;
- starting current;
- starting voltage-drop impact;
- feeder/cable/protection;
- normal/start/fault states.

Future advanced extension:

- acceleration/transient motor-start analysis.

### CAP-10 Earthing, bonding and SPD

Required architecture:

- N;
- PE;
- PEN;
- TN-S;
- TN-C;
- TN-C-S;
- TT;
- IT;
- equipotential bonding;
- earth-fault loop concepts;
- automatic-disconnection validation boundary;
- earth electrode boundary;
- SPD Type 1/2/3;
- SPD placement and coordination;
- lightning-protection integration boundary.

### CAP-11 Lighting and small power

Required:

- lighting fixture as electrical load;
- lighting circuit;
- sockets/small-power circuit;
- switches/controls relationship;
- emergency-lighting supply;
- circuit/cable/protection integration.

Future extension:

- illuminance/lux calculation.

### CAP-12 ELV

Electra shall integrate the existing ELV contour rather than isolate it.

Required disciplines:

- CCTV;
- LAN;
- ACS;
- FIRE.

Target integration example:

```text
CAMERA
  ↓ PoE
SWITCH
  ↓
UPS
  ↓
DB-ELV
  ↓
BREAKER
  ↓
MDB
```

ELV discipline calculations shall consume shared electrical facts where appropriate and preserve discipline ownership.

### CAP-13 Operating scenarios

Required scenarios:

- NORMAL;
- GRID_FAILURE;
- GENERATOR_OPERATION;
- GENERATOR_FAILURE;
- UPS_OPERATION;
- MAINTENANCE;
- EMERGENCY;
- SOURCE_TRANSFER;
- LOAD_SHEDDING.

Scenario execution shall be deterministic and versioned.

### CAP-14 Reliability and failure analysis

Target capabilities:

- N;
- N+1;
- 2N;
- SPOF detection;
- dependency closure;
- failure propagation;
- lost/retained critical functions;
- maintenance-state analysis.

### CAP-15 Normative validation

Physical engineering calculations and normative compliance are separate concerns.

Required:

- jurisdiction/profile selection;
- standard family;
- edition/version;
- ruleset fingerprint;
- applicable/not-applicable decision;
- PASS / FAIL / UNRESOLVED;
- evidence trace;
- no hard-coded generic compliance claims without applicable profile.

ELV7 remains the normative-compliance authority for the ELV program and may evolve into the shared compliance layer without rewriting calculation ownership.

### CAP-16 Equipment selection

Required architecture:

```text
EngineeringRequirement
        ↓
CandidateEquipment[]
        ↓
SelectedEquipment
```

Required:

- generic engineering requirement first;
- manufacturer/SKU candidates second;
- manual override;
- reason code AUTO_SELECTED / USER_SELECTED / USER_OVERRIDE;
- catalog version/provenance;
- no calculation semantics hidden inside vendor SKU selection.

### CAP-17 Single-line diagram

SLD shall be a view of the project model, not an independent drawing database.

Required:

- source/distribution/load topology;
- equipment labels/ratings;
- cable data;
- protection data;
- engineering-result overlays;
- live update after model change;
- deterministic export.

### CAP-18 Automatic project audit

Target primary user action:

```text
AUDIT PROJECT
```

Audit shall evaluate at least:

- topology completeness;
- disconnected/islanded loads;
- source availability;
- board capacity;
- phase balance;
- cable ampacity;
- voltage drop;
- short circuit;
- protection;
- emergency supply;
- ELV discipline findings;
- missing required evidence;
- stale calculations;
- normative unresolved/fail findings.

Findings severity:

- CRITICAL;
- WARNING;
- INFORMATIONAL.

Each finding shall identify subject, cause, evidence and remediation context.

### CAP-19 Professional deliverables

Minimum deliverables:

- Single Line Diagram;
- Load Schedule;
- Panel Schedule;
- Cable Schedule;
- Protection Schedule;
- Equipment Schedule;
- ELV Schedule;
- BOM;
- Calculation Report;
- Findings Report;
- project engineering dossier.

Minimum export formats:

- PDF;
- XLSX/CSV.

Future interoperability:

- DXF/DWG boundary;
- IFC;
- Revit/AutoCAD exchange.

### CAP-20 Collaboration and sharing

Target:

- immutable shared project snapshot;
- read-only share;
- QR/link access;
- revision identity;
- no silent mutation of shared historical revision.

### CAP-21 Field verification and commissioning

Target lifecycle states:

```text
DESIGNED
  ↓
INSTALLED
  ↓
VERIFIED
  ↓
COMMISSIONED
```

Target field evidence:

- installed equipment/cable;
- measured voltage/current;
- insulation measurement;
- breaker/device identity;
- note;
- photo/file reference;
- timestamp;
- project revision;
- verification status.

## 5. Engineering calculation quality contract

All new or materially changed production engineering calculations shall converge on the shared Engineering Calculation & Simulation Foundation principles.

Required qualities:

- deterministic;
- reproducible;
- dimension-safe where practical;
- traceable to project facts and external evidence;
- versioned;
- explicit UNKNOWN handling;
- independent oracle where required;
- BELOW / EXACT / ABOVE boundary qualification;
- governing case/section identification;
- stale-result prevention;
- replay semantics;
- historical result preservation.

No UI rounding may feed engineering decisions.

No required input may silently fall back to an engineering assumption unless the assumption is explicit, identified and permitted by the applicable contract.

## 6. Target architecture layers

```text
apps/mobile
    ↓
application
    ├── resolvers
    ├── commands
    ├── publication
    ├── audit orchestration
    └── report orchestration
    ↓
engineering_core
    ├── foundation
    ├── electrical
    ├── topology
    ├── protection
    ├── scenarios
    ├── reliability
    ├── elv
    └── deliverable contracts
    ↓
persistence/adapters
    ├── Drift
    ├── catalogs
    ├── evidence
    ├── import/export
    └── future cloud sync
```

Rule: pure engineering kernels must not depend on Drift, UI, wall-clock time, locale or mutable global state.

## 7. Suggested target package decomposition

This is a target coordinate system, not a mandatory immediate refactor.

```text
packages/engineering_core/lib/src/
├── foundation/
│   ├── quantities/
│   ├── evidence/
│   ├── provenance/
│   ├── calculation/
│   ├── qualification/
│   └── scenarios/
├── electrical/
│   ├── topology/
│   ├── sources/
│   ├── loads/
│   ├── distribution/
│   ├── panels/
│   ├── conductors/
│   ├── ampacity/
│   ├── voltage_drop/
│   ├── short_circuit/
│   ├── protection/
│   ├── motors/
│   ├── earthing/
│   ├── spd/
│   └── energy/
├── elv/
│   ├── cctv/
│   ├── lan/
│   ├── acs/
│   └── fire/
├── simulation/
│   ├── operating_states/
│   ├── failure/
│   └── reliability/
└── deliverables/
```

Existing accepted ELV4/ELV5 code must not be moved only to satisfy this directory picture. Shared extraction is justified only when ownership is clear and at least two stable consumers exist, unless a correctness defect requires earlier action.

## 8. Product readiness levels

A capability uses the following maturity model:

```text
DESIGNED
  ↓
KERNEL_IMPLEMENTED
  ↓
RUNTIME_INTEGRATED
  ↓
QUALIFIED
  ↓
ACCEPTED
  ↓
MARKET_VALIDATED
```

Definitions:

- DESIGNED — authoritative contract exists.
- KERNEL_IMPLEMENTED — production calculation/domain kernel exists.
- RUNTIME_INTEGRATED — persistence/application/UI path is connected.
- QUALIFIED — required oracle/boundary/scenario/replay gates pass.
- ACCEPTED — frozen acceptance evidence binds exact source and versions.
- MARKET_VALIDATED — real engineers use the capability on real projects and evidence shows repeated value.

No stage may be inferred only from file existence.

## 9. Minimum marketable professional release

A serious first commercial Electra does not need every advanced power-system feature.

Required minimum:

1. unified project/revision model;
2. electrical topology;
3. switchboards/panel schedules;
4. loads/demand/phase balance;
5. cable ampacity and sizing;
6. voltage drop;
7. short circuit min/max;
8. protection rating/breaking-capacity checks;
9. intelligent SLD;
10. integrated CCTV/LAN/ACS/FIRE workflow;
11. explainable/traceable calculation results;
12. automatic project audit;
13. PDF engineering dossier;
14. schedules/BOM export;
15. offline-first operation.

The following may ship later without invalidating the first professional release:

- advanced harmonics;
- arc flash;
- electromagnetic transients;
- full MV/HV studies;
- advanced relay engineering;
- full BIM authoring;
- CFD;
- generic MEP solvers.

## 10. Reference end-to-end acceptance project

Target reference project shall include at least:

```text
GRID
 ↓
TR-01
 ↓
MDB-01
 ├── DB-LIGHT
 ├── DB-SMALL-POWER
 ├── MCC-01
 └── DB-ELV

MCC-01
 ├── PUMP-01 via VFD
 └── FAN-01 via starter

DB-ELV
 ├── CCTV
 ├── LAN
 ├── ACS
 └── FIRE

Emergency supply:
GRID + GEN-01 + ATS-01

Selected critical loads:
FIRE
ACS
CCTV
PUMP-01
```

Acceptance scenarios:

- NORMAL;
- GRID_FAILURE;
- GENERATOR_OPERATION;
- GENERATOR_FAILURE;
- MAINTENANCE_MCC;
- PROTECTION_DEVICE_OPEN;
- CABLE_OVERLOAD;
- PHASE_IMBALANCE;
- ELV_BACKUP_DEPLETION;
- MISSING_NORMATIVE_EVIDENCE.

Required outputs:

- SLD;
- panel schedules;
- cable/protection schedules;
- electrical calculations;
- ELV calculations;
- audit findings;
- BOM;
- engineering dossier;
- immutable revision snapshot.

## 11. Roadmap convergence

Existing program:

```text
ELV1–ELV3  foundation / geometry / routing
ELV4       power topology and electrical ownership
ELV5       CCTV/LAN/ACS/FIRE calculations
ELV6       enclosure/rack/physical constructability
ELV7       normative profiles and validation
ELV8       equipment selection and deliverables
```

Target electrical continuation after the current ELV program should be treated as a parallel ELEC program rather than ELV9+:

```text
ELEC1 — Electrical Domain Foundation
ELEC2 — Sources / Transformer / Generator / ATS
ELEC3 — Switchboards / Panelboards / MCC
ELEC4 — Short Circuit / Protection / Selectivity
ELEC5 — Motors / Drives / Operating States
ELEC6 — Earthing / Bonding / SPD
ELEC7 — Lighting / Small Power / Emergency Lighting
ELEC8 — Electrical Scenarios / Reliability / SPOF
ELEC9 — SLD / Audit / Professional Dossier integration
```

This numbering is a target planning proposal, not an implementation claim.

## 12. Scope guardrails

A proposed feature belongs to Electra core if it materially answers at least one of the following questions:

1. What is electrically connected to what?
2. What powers this asset and through which path?
3. What is the electrical load/current/power state?
4. Is the conductor/distribution path adequate?
5. Is protection adequate and coordinated?
6. What happens electrically under a defined operating/failure scenario?
7. Is the design compliant with the selected normative profile?
8. Which electrical/ELV equipment satisfies the engineering requirement?
9. What shall appear in professional electrical deliverables?
10. What was actually installed/verified in the field?

If a feature does not belong to this set, it should normally be an integration or separate domain rather than new Electra core scope.

## 13. North-star product statement

Electra target:

> One engineering model for building electrical power and ELV: design, calculate, validate, audit, document and verify.

The target is reached not when every possible electrical feature exists, but when an engineer can complete a real building electrical + ELV project without relying on spreadsheets for the core engineering chain and can independently trace every critical result back to its inputs, algorithm version and evidence.
