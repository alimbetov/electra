# Electra — Identification, Cabinet Cable Entry & Electrical Disturbance Simulation Target Addendum

Status: **TARGET / NORTH STAR / NOT IMPLEMENTATION / NOT ACCEPTANCE**

Parent target: `electra-professional-electrical-platform-target.md`

Related target capabilities: CAP-05, CAP-06, CAP-07, CAP-08, CAP-13, CAP-17, CAP-19, CAP-21, K0, K3, K6, K7.

## 1. Purpose

This addendum freezes three cross-cutting professional capabilities that must not be lost between enclosure/layout, deliverables, commissioning and electrical-simulation work:

1. canonical engineering identification, cable/core/terminal/device marking and printable labels;
2. explicit cabinet cable-entry zones and internal cable routing from entry to terminals/devices;
3. deterministic short-circuit, voltage-disturbance and discrete electrical scenario simulation.

These capabilities extend the existing Electra engineering model. They do not create a second source of truth for cables, panels, circuits, protection or topology.

Canonical principle:

```text
ONE ENGINEERING MODEL
       │
       ├── drawing labels
       ├── panel labels
       ├── cable/core markers
       ├── terminal markers
       ├── QR / field identity
       ├── cabinet routing
       └── simulation inputs/results
```

---

## 2. Engineering identification and marking

### 2.1 Canonical identity versus printed representation

Every physical engineering object that requires field identification shall retain one canonical object identity and one canonical engineering code/label. Printed labels, schedule strings, SLD annotations and QR payloads are views derived from the same source model.

The system MUST NOT allow independent conflicting identities such as:

```text
Database cable     = C-017
SLD cable          = W-14
Panel cable        = Cable 12
Physical marker    = LGT-04
```

The intended rule is:

```text
Canonical cable label
        │
        ├── plan / route drawing
        ├── SLD
        ├── panel / terminal plan
        ├── cable schedule
        ├── physical marker
        └── QR / commissioning lookup
```

### 2.2 Initial target marker subjects

The target identification subsystem shall support at least:

- Cable;
- CableCore / conductor / pair / fiber where the media model exposes an atomic resource;
- Circuit;
- ProtectiveDevice;
- Panel / switchboard / MCC;
- TerminalBlock;
- Terminal;
- Device / load / field component;
- Port / patch-panel port;
- PLC/remote-I/O channel;
- automation actuator/sensor/channel where K13 applies.

### 2.3 Marker types

Initial target marker classes:

```text
CABLE_END_SOURCE
CABLE_END_DESTINATION
CABLE_INTERMEDIATE
CABLE_CORE
TERMINAL
TERMINAL_BLOCK
DEVICE
PANEL
PORT
IO_CHANNEL
QR_ASSET
```

A marker is a generated representation. It is not the canonical engineering object itself.

### 2.4 Target contracts

Representative target model:

```text
IdentificationPolicy
- policyId
- version
- normalizationRules
- objectCodePatterns
- duplicatePolicy
- reservedPrefixes

MarkerTemplate
- templateId
- version
- markerType
- physicalMedia
- widthMm?
- heightMm?
- lineDefinitions[]
- qrEnabled

MarkerProjection
- subjectRef
- markerType
- end?
- renderedLines[]
- qrPayload?
- templateRef
- sourceRevisionId
- projectionFingerprint
```

`MarkerProjection` MUST be reproducible from a frozen project revision plus exact policy/template versions.

### 2.5 Cable end marking

A cable-end marker may include, subject to project policy:

```text
CABLE: DB01-LGT-017
FROM:  DB-01 / QF17 / X1:24
TO:    ROOM-204 / L-204-01
```

Source and destination end markers may reverse `FROM/TO` presentation while preserving the same canonical cable identity.

### 2.6 Printable output

The core shall remain printer-neutral. Minimum target outputs:

- PDF label sheet;
- CSV/XLSX marker schedule;
- deterministic printer-neutral marker dataset;
- QR payload dataset.

Manufacturer/printer adapters such as Brady, Phoenix Contact, Weidmüller, Brother, DYMO or others are later adapters and MUST NOT become the canonical data model.

### 2.7 Revision and commissioning semantics

A frozen revision freezes the marker projection source facts. If a cable identity, termination, panel, terminal assignment or device endpoint changes in a new revision, affected marker projections become stale and must be regenerated.

K7 field workflow shall be able to scan a QR/label and resolve the exact asset/revision context without silently mutating historical evidence.

---

## 3. Cabinet cable-entry and internal routing model

### 3.1 No universal top-versus-bottom rule

Electra MUST NOT encode `TOP` or `BOTTOM` as universally correct. Entry direction is a design fact constrained by the enclosure, route, installation method, cable geometry, field accessibility and project/normative rules.

Initial target entry sides:

```text
TOP
BOTTOM
LEFT
RIGHT
MIXED
CUSTOM
UNSPECIFIED
```

`MIXED` is first-class because power, control and ELV frequently use different entry zones.

### 3.2 Cable entry zones

Representative target model:

```text
CableEntryZone
- id
- panelId
- side
- localGeometry
- purpose
- allowedCableClasses[]
- allowedServiceClasses[]
- usableWidthMm
- usableHeightMm?
- glandPlateRef?
- maxCableCount?
- reservedCapacity?
- environmentalConstraints[]

CableEntryAssignment
- cableId
- panelId
- entryZoneId
- preferredSide?
- assignmentMode
- revisionId
```

Example:

```text
TOP-LEFT      CONTROL
TOP-RIGHT     ELV / DATA
BOTTOM-LEFT   POWER
BOTTOM-RIGHT  RESERVED
```

### 3.3 Gland and entry hardware

The target model shall permit explicit gland/gland-plate/interface information where available:

- gland plate;
- cable gland size/family;
- sealing/IP requirement;
- cable diameter range;
- EMC/shield termination requirement;
- spare/opening reservation.

Exact SKU selection belongs to the equipment/catalog layer; physical feasibility belongs to the enclosure/layout owner.

### 3.4 Internal cable path

Entry assignment is not enough. Electra shall be able to represent the internal route from enclosure entry to the final termination.

```text
External CableRun
      ↓
CableEntryZone
      ↓
Gland / entry interface
      ↓
InternalCablePath
      ↓
Terminal / device
```

Representative target object:

```text
CabinetInternalCablePath
- cableId
- panelId
- entryZoneId
- orderedSegments[]
- targetTerminationRef
- calculatedLengthMm
- governingBendRadiusMm
- serviceLoopMm?
- segregationClass
- validationState
```

### 3.5 Mandatory physical checks

Where sufficient geometry/evidence exists, layout validation shall evaluate:

- minimum bend radius;
- entry/gland compatibility;
- cable diameter and entry capacity;
- internal duct/tray fill;
- power/control/ELV segregation rules where applicable;
- terminal/device reachability;
- maintainability/accessibility constraints;
- required service loop where policy requires it;
- shield/PE termination path where applicable;
- reserve entry capacity;
- route collisions or impossible transitions where modeled.

Missing mandatory evidence produces `UNRESOLVED/BLOCKED`, not an invented PASS.

### 3.6 K0 synthesis impact

K0 Automatic Switchboard Synthesis shall be allowed to consider cabinet entry and internal routing as hard constraints and optimization objectives.

Candidate objective dimensions may include:

- minimum added internal cable length;
- minimum crossing/route complexity;
- minimum congestion;
- minimum thermal concentration where supported;
- maximum accessibility;
- maximum reserve capacity.

An enclosure layout that is electrically valid but cannot route its required cables to legal/physical terminations is not a valid final candidate.

### 3.7 Graphical editor target

The professional panel editor shall expose at least:

```text
PHYSICAL VIEW
- enclosure sections
- DIN rails
- devices
- terminals
- N / PE bars
- ducts / routing zones
- cable entry zones

ELECTRICAL VIEW
- incomer
- bus
- protection
- circuits

WIRING VIEW
- terminals
- cable cores
- internal wires / channels
```

Device movement remains model-driven. Drag/drop changes structured placement facts, then re-runs validation; it must not become freehand CAD detached from the engineering model.

---

## 4. Electrical disturbance and fault simulation

### 4.1 Simulation levels

Electra shall explicitly distinguish model fidelity.

```text
LEVEL 1 — STEADY STATE
load/demand, voltage drop, phase balance, source loading

LEVEL 2 — FAULT STUDIES
short circuit, earth fault, neutral-loss where supported, protection response

LEVEL 3 — DISCRETE DYNAMIC SCENARIOS
source loss, ATS transfer, generator start, UPS ride-through, load shedding,
motor starting and voltage-dip consequences where qualified

LEVEL 4 — ELECTROMAGNETIC TRANSIENTS
waveform-level switching/lightning/inverter EMT
```

Target professional release shall support Levels 1–3 incrementally. Level 4 is deferred unless a separately qualified EMT engine is introduced.

### 4.2 Short-circuit simulation — mandatory professional scope

Target fault classes, subject to network/system applicability:

```text
THREE_PHASE
PHASE_PHASE
PHASE_NEUTRAL
PHASE_PE_EARTH
```

Required outputs where the selected method/profile supports them:

- fault location;
- `Ik max`;
- `Ik min`;
- source contribution breakdown where modeled;
- protective-device breaking-capacity check;
- expected protection operation/trip evaluation;
- conductor thermal-withstand evaluation;
- upstream/downstream affected topology;
- governing assumptions/evidence/method version.

A short-circuit result MUST NOT imply selectivity or successful clearing unless the relevant protection model actually proves it.

### 4.3 Voltage disturbance simulation

Target disturbance classes:

```text
UNDERVOLTAGE
OVERVOLTAGE
VOLTAGE_DIP
SOURCE_LOSS
SOURCE_TRANSFER
LOAD_REJECTION
NEUTRAL_LOSS
MOTOR_START
```

Where model fidelity permits, outputs include:

- affected bus/load;
- pre-event voltage;
- minimum/maximum event voltage;
- event duration or bounded duration if the scenario engine owns timing;
- affected equipment/control availability;
- governing source/path;
- related protection/transfer action.

### 4.4 Motor-start analysis

Motor-start study shall support the starting-method ownership already present in the electrical model:

- DOL;
- star-delta;
- soft starter;
- VFD.

Target output may include:

- starting current;
- source/transformer/generator loading impact;
- bus voltage dip;
- upstream protection interaction;
- affected critical loads;
- comparison of qualified alternative starting methods.

Detailed electromechanical acceleration/transient claims remain outside scope until separately qualified.

### 4.5 Source-transfer and critical-power scenarios

K6 Critical Power Simulator shall orchestrate discrete events such as:

```text
t = 0       GRID LOST
t = ...     UPS CARRIES CRITICAL LOAD
t = ...     ATS FAILURE DETECTED
t = ...     GENERATOR START
t = ...     GENERATOR READY
t = ...     ATS TRANSFER
t = ...     EMERGENCY BUS AVAILABLE
```

Target source/load states include:

```text
AVAILABLE
UNAVAILABLE
DEGRADED
UNDERVOLTAGE
OVERVOLTAGE
FREQUENCY_LOW
FREQUENCY_HIGH
FAULTED
STARTING
READY
TRANSFER_IN_PROGRESS
```

Only states supported by the actual source/scenario contracts may be asserted.

### 4.6 Failure X-Ray integration

K3 shall be able to consume qualified simulation results.

Example:

```text
FAULT: DB-03 BUS / THREE_PHASE
Ik = 12.8 kA
QF-03 breaking capacity = 10 kA
RESULT = CRITICAL

Affected:
- FIRE PANEL
- CCTV UPS input
- PUMP-01
```

Failure propagation must distinguish:

- electrical power unavailable;
- control unavailable;
- degraded operation;
- alternate source available;
- protection successfully isolated;
- unresolved due to missing evidence.

### 4.7 Project scenario matrix

Target project audit may expose a deterministic scenario matrix such as:

```text
GRID_FAILURE              PASS
GENERATOR_FAILURE         WARNING
DB01_THREE_PHASE_FAULT    PASS
DB03_THREE_PHASE_FAULT    FAIL
PUMP01_DOL_START          FAIL
NEUTRAL_LOSS              WARNING
UPS_DEPLETED              FAIL
```

A scenario status is derived from explicit calculation/validation results, not manually painted green/red UI state.

### 4.8 SPD and transient boundary

Electra shall support engineering selection/coordination checks for SPD Type 1/2/3 and their declared characteristics where applicable.

Waveform propagation for 8/20 µs, 10/350 µs or other electromagnetic transient studies is **not** implied by SPD selection support. Such waveform-level simulation belongs to deferred Level 4 EMT scope.

Arc-flash, detailed harmonics and full EMT studies are separate future capability families and MUST NOT be claimed from the Level 1–3 scenario engine.

---

## 5. Ownership map

```text
Cable canonical identity / route        → CAP-06 / existing cable owners
Panel physical layout                   → ELV6 / CAP-05 physical-layout owner
Cable entry + internal cabinet route    → ELV6 physical evidence specialization
Normative entry/segregation rules       → ELV7 / CAP-15
Exact gland/device/catalog SKU          → ELV8 / CAP-16
Printable schedules / labels / QR       → CAP-19 + CAP-21 deliverable/field projection
Auto panel synthesis                    → K0
Failure propagation                     → K3
Critical-source timeline                → K6
As-built / scan / commissioning         → K7
Short-circuit/protection physics        → CAP-07 / CAP-08
```

No downstream layer may redefine canonical cable identity, electrical physics or normative authority.

---

## 6. Required deterministic invariants

1. Same frozen revision + identification policy + template version => identical marker projection/fingerprint.
2. Same frozen topology + engineering input + algorithm/ruleset versions => identical simulation results.
3. A label change invalidates all dependent marker/drawing/schedule projections.
4. A termination or cable-entry change invalidates affected cabinet routes and downstream deliverables.
5. A topology/source/protection change invalidates dependent fault/disturbance results.
6. Unknown mandatory physical or simulation inputs fail visibly.
7. Manual graphical edits never bypass engineering validation.
8. Historical frozen revisions remain reproducible.

---

## 7. Delivery priority

Recommended sequence:

```text
A1 Canonical Identification & Label Projection
A2 Cable/Core/Terminal Schedule + PDF/CSV labels
A3 QR field identity integration with K7
A4 Cabinet CableEntryZone + entry assignment
A5 Internal cabinet route + bend/segregation/capacity validation
A6 Panel editor entry/routing visualization
A7 ShortCircuitEngine min/max + breaking-capacity integration
A8 ProtectionResponse integration
A9 VoltageDisturbance / MotorStart studies
A10 K3/K6 project scenario matrix
A11 advanced SPD/transient boundary checks
A12 future EMT / arc-flash / harmonics only as separate qualified programs
```

This order is dependency guidance, not an acceptance claim.

---

## 8. Reference acceptance examples

### 8.1 Label continuity

For cable `DB01-LGT-017`, the same canonical identity must appear consistently in:

- cable object;
- route/plan annotation;
- SLD annotation;
- panel/terminal plan;
- cable schedule;
- source and destination physical markers;
- QR lookup;
- commissioning record.

### 8.2 Mixed cabinet entry

```text
TOP-LEFT      CONTROL
TOP-RIGHT     ELV
BOTTOM-LEFT   POWER
BOTTOM-RIGHT  SPARE
```

A power cable assigned to `BOTTOM-LEFT` shall route to its target terminal/device while satisfying available entry geometry, bend and segregation constraints or return an explicit blocker.

### 8.3 Fault study

A three-phase fault at a selected board bus shall produce a reproducible result containing fault current, method/version, applicable source contributions, protection breaking-capacity assessment and affected topology. If clearing/selectivity cannot be proven, the result must remain unresolved rather than infer PASS.

---

## 9. Non-goals for the first implementation

The addendum does not require initially:

- photorealistic cabinet rendering;
- 3D cabinet CAD;
- direct dependency on a specific label-printer vendor;
- automatic normative PASS without verified rule authority;
- waveform-level EMT;
- arc-flash qualification;
- full harmonic studies;
- generic SCADA/runtime control.

The first implementation should maximize engineering traceability and constructibility before visual realism.