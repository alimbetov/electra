# Electra — K13 Smart Building & Home Automation Designer

Status: **TARGET / NORTH STAR / NOT IMPLEMENTATION / NOT ACCEPTANCE**

Parent target: `electra-professional-electrical-platform-target.md`  
Killer layer: `electra-killer-capability-layer.md`

## 1. Product intent

K13 extends Electra from electrical design into the engineering design of building/home automation **without turning Electra into a runtime smart-home platform**.

Electra owns:

```text
DESIGN
CALCULATE
PLACE
CONNECT
VALIDATE
SIMULATE
DOCUMENT
COMMISSION
```

External runtime ecosystems own:

```text
RUN
CONTROL
AUTOMATE
MONITOR
```

Electra shall therefore design and validate the electrical/control infrastructure that may later be commissioned into KNX, DALI, Matter, Zigbee, Z-Wave, Wi-Fi, PLC-IoT, Modbus, BACnet or vendor ecosystems.

Canonical value proposition:

> One engineering model links the physical room, electrical load, circuit, protective path, automation controller, sensor/actuator binding, control scene, power source and failure consequence.

## 2. Core architecture principle

The domain model MUST be protocol-agnostic at its primary level.

Do not make protocol classes the root of the model.

Preferred abstraction:

```text
SmartDevice
 ├── electricalSupply
 ├── capabilities
 ├── sensors
 ├── actuators
 ├── controlPoints
 └── communicationBindings[]
```

with transport/protocol bindings such as:

```text
CommunicationBinding
 ├── protocol
 ├── transport
 ├── address
 ├── segment/network
 ├── security profile
 ├── gateway dependency
 └── commissioning state
```

Supported target protocol families:

- KNX Classic / KNX IP / KNX Secure / KNX IoT;
- DALI-2 / D4i / DALI+;
- Matter;
- Thread;
- Zigbee;
- Z-Wave / Z-Wave Long Range;
- Wi-Fi;
- PLC-IoT abstraction;
- Modbus RTU/TCP;
- BACnet/IP;
- vendor-specific integrations through adapters, not core-domain coupling.

Matter and Thread MUST remain separate concepts: Matter is an application/interoperability layer and Thread is a network transport.

## 3. K13 capability decomposition

### SH-01 — Automation topology

Electra shall model automation infrastructure independently from electrical topology while allowing explicit bindings between them.

Target topology primitives:

```text
AutomationNetwork
AutomationSegment
AutomationController
Gateway
BusPowerSupply
Sensor
Actuator
ControlPoint
CommunicationBinding
AutomationDependency
```

Typical professional topology:

```text
KNX IP Router
     ↓
KNX Line
 ├── Power Supply
 ├── Wall Sensor
 ├── Presence Sensor
 ├── Actuator
 └── DALI Gateway
          ↓
       DALI Bus
       ├── Driver
       ├── Driver
       └── Sensor
```

Required checks include, where applicable:

- topology validity;
- network/segment capacity;
- address uniqueness;
- device/channel occupancy;
- required bus power;
- gateway dependency;
- unsupported topology combinations;
- missing evidence.

### SH-02 — Electrical-load binding

Every controlled electrical consumer shall remain a real electrical asset/load in Electra.

Canonical chain:

```text
Sensor / Switch
      ↓
Automation Controller
      ↓
Actuator Channel
      ↓
Electrical Load
      ↓
Circuit
      ↓
Cable
      ↓
Protection
      ↓
Switchboard
      ↓
Source / UPS / Generator
```

Example:

```text
KNX-ACT-01 / channel 1
        ↓ controls
LIGHT-101
        ↓ supplied by
LGT-CIRCUIT-01
        ↓
QF-17
        ↓
DB-01
```

Electra shall be able to answer both:

- which protective path supplies the load;
- which control path commands the load.

Electrical availability and control availability MUST be separate state axes.

### SH-03 — Lighting automation / DALI

K13 shall support lighting-control engineering as a first-class automation domain.

Target concepts:

- DALI subnet/bus;
- control gear;
- control devices;
- application controller;
- bus power supply;
- groups;
- scenes;
- sensor/input bindings;
- emergency-lighting integration boundary;
- KNX↔DALI gateway binding;
- Matter/other gateway boundary where applicable.

The DALI model shall integrate with K12 room placement and CAP-11 lighting circuits.

### SH-04 — KNX engineering

Target model:

```text
KNX Area
  ↓
KNX Line
  ↓
Line / IP Coupling
  ↓
Bus Power Supply
  ↓
Sensors / Actuators / Gateways
  ↓
Controlled Electrical Assets
```

Target checks:

- line/segment membership;
- individual/group address consistency;
- device count/capacity constraints according to the selected profile;
- bus-power requirements;
- channel occupancy;
- secure/insecure boundary visibility;
- gateway and router SPOF dependencies;
- commissioning completeness.

Electra SHALL NOT replace ETS. It shall model, validate, document and prepare engineering data for commissioning/export boundaries.

### SH-05 — Matter / Thread / Zigbee / Z-Wave / Wi-Fi / PLC-IoT

Electra shall represent consumer and hybrid smart-building devices without collapsing protocol and transport semantics.

Examples:

```text
Matter over Thread
Matter over Wi-Fi
Zigbee mesh
Z-Wave LR
Wi-Fi/IP
PLC communication domain
```

PLC-IoT is strategically relevant because Electra already owns electrical circuits and cable paths; where supported by a product profile, the same physical electrical network may also form part of a communication domain.

### SH-06 — Scenes and control logic

Control behavior shall be modelled as structured engineering data, not only free-form scripts.

Canonical model:

```text
AutomationScene
 ├── trigger
 ├── conditions[]
 ├── commands[]
 ├── targets[]
 ├── priority
 ├── timeout
 ├── fallback
 ├── overridePolicy
 └── safetyClass
```

Example scenes:

- ENTER;
- LEAVE_HOME;
- NIGHT;
- READING;
- CLEANING;
- AWAY;
- GRID_FAILURE;
- FIRE;
- EMERGENCY;
- MAINTENANCE.

Life-safety or emergency actions MUST NOT be silently overridden by comfort automation.

### SH-07 — Automation failure simulation

K13 shall integrate with K3 Failure X-Ray and K6 Critical Power Simulator.

Example:

```text
KNX-PS-01 FAILED

Electrical power to luminaires: AVAILABLE
Lighting control: UNAVAILABLE
Affected switches: 42
Affected actuators: 18
Affected rooms: 11
```

Another example:

```text
DALI-GW-01 FAILED

Electrical power: AVAILABLE
DALI control: LOST
Emergency lighting: UNAFFECTED / DEGRADED / UNKNOWN
```

Required simulation axes:

- electrical supply availability;
- communication availability;
- controller availability;
- actuator availability;
- local manual control availability;
- scene execution availability;
- degraded vs unavailable behavior;
- alternate/gateway path;
- SPOF impact.

### SH-08 — Smart Room Wizard

K13 shall extend K12 Smart Room Electrical Layout.

K12 may generate room electrical assets such as:

```text
luminaire
LED strip
wall light
socket
switch
```

K13 may then propose compatible automation assets and bindings:

```text
presence sensor
temperature sensor
lux sensor
wall control
blind actuator
lighting actuator
DALI gateway/device
smart socket control
thermostat/control point
```

Canonical workflow:

```text
ROOM GEOMETRY
     ↓
K12 ELECTRICAL PLACEMENT
     ↓
ELECTRICAL CIRCUITS
     ↓
K13 AUTOMATION CANDIDATES
     ↓
CONTROL BINDINGS
     ↓
SCENES
     ↓
VALIDATION
     ↓
USER ACCEPT / EDIT / REJECT
```

Suggested room strategies may include STANDARD, COMFORT, SMART and PREMIUM, but these are policy presets, not normative claims.

### SH-09 — Control / I-O matrices

Electra shall generate structured deliverables that explain automation behavior.

Target outputs:

- Control Matrix;
- I/O Schedule;
- Sensor Schedule;
- Actuator Schedule;
- KNX Schedule;
- DALI Schedule;
- Scene Schedule;
- gateway/dependency schedule;
- commissioning checklist.

Example matrix:

| Input | Event | Output | Action |
|---|---|---|---|
| SW-101 | short press | LIGHT-101 | toggle |
| SW-101 | long press | LIGHT-101 | dim |
| PIR-101 | presence | LIGHT-GRP-1 | scene 70% |
| LUX-101 | below threshold | LIGHT-GRP-1 | enable |
| SW-BED | press | SCENE-NIGHT | execute |

### SH-10 — Automation Audit

K13 shall extend CAP-18/K2 audit semantics.

Target findings include:

- automation network SPOF;
- missing bus/network power supply;
- overloaded/overcommitted actuator channels;
- duplicate/conflicting addresses;
- gateway dependency without fallback;
- critical controlled load without local/manual fallback where policy requires it;
- control path available but electrical path unavailable;
- electrical path available but control path unavailable;
- unbound sensors/actuators;
- unreachable scene target;
- unsupported or unresolved protocol/profile evidence;
- stale commissioning data;
- security-profile mismatch;
- missing backup power for critical automation assets.

## 4. Regional technology profiles

Electra shall support technology profiles without hard-coding one region into the domain model.

### USA-oriented profile

Primary ecosystem emphasis:

- Matter;
- Thread;
- Z-Wave / Z-Wave LR;
- Zigbee;
- Wi-Fi/IP;
- home-energy integration.

### Europe-oriented profile

Primary ecosystem emphasis:

- KNX / KNX Secure / KNX IoT;
- DALI-2 / D4i / DALI+;
- Matter / Thread;
- BACnet/Modbus integration boundaries;
- PV / battery / EV / heat-pump energy orchestration.

### CIS-oriented profile

Primary ecosystem emphasis:

- Zigbee;
- Wi-Fi/IP;
- Matter;
- local/offline hubs;
- vendor ecosystems through adapters;
- KNX for professional/high-end installations.

### China-oriented profile

Primary ecosystem emphasis:

- whole-home intelligence;
- PLC-IoT abstraction;
- Zigbee/Wi-Fi/Bluetooth/Matter bridges;
- energy-management integration;
- vendor whole-home ecosystems through adapters.

These profiles guide default catalogs/templates only. Engineering truth remains protocol/profile/evidence based.

## 5. Smart energy convergence

K13 shall be compatible with the broader Electra energy model.

Target chain:

```text
GRID
PV
BESS
EVSE
GENERATOR
UPS
HVAC / HEAT PUMP LOADS
SMART LOADS
      ↓
ENERGY / LOAD ORCHESTRATION
      ↓
AUTOMATION SCENES / LOAD SHEDDING
```

Potential future capabilities:

- tariff-aware scheduling;
- self-consumption optimization;
- EV charging coordination;
- battery dispatch policy;
- controllable-load prioritization;
- comfort-vs-energy policy;
- emergency energy mode.

Energy optimization MUST remain constrained by electrical capacity, criticality, normative and user policy rules.

## 6. Security and trust boundaries

K13 design models shall explicitly represent, where evidence is available:

- secure vs non-secure communication mode;
- gateway/trust boundary;
- remote-access boundary;
- commissioning ownership;
- credential/reference identifier without storing secrets in engineering artifacts;
- firmware/version evidence where relevant;
- local-vs-cloud operational dependency.

Electra shall never require storing user passwords, cloud tokens or private smart-home credentials in the engineering model.

## 7. Integration with killer capabilities

K13 SHALL compose with:

```text
K12 Smart Room Electrical Layout
   ↓
K13 Smart Building & Home Automation
   ↓
K0 Automatic Switchboard Synthesis
   ↓
K2 Engineering Audit + Auto-Fix
   ↓
K3 Failure X-Ray
   ↓
K6 Critical Power Simulator
   ↓
K7 As-Built / Commissioning Twin
```

Additional synergies:

- K1 Project Autopilot may propose automation backbone candidates;
- K4 Revision Impact Intelligence shall report affected automation bindings/scenes;
- K5 Design Optimizer may compare automation architectures;
- K8 Vendor-Neutral Equipment Optimizer may rank compatible automation devices;
- K9 Company Engineering Rules may encode approved protocols/vendors/patterns;
- K10 Brownfield Reconstruction may capture existing automation infrastructure;
- K11 Copilot may explain scenes, dependencies and failures but not invent engineering truth.

## 8. Candidate-first rule

K13 generation is always candidate-first:

```text
GENERATE
  ↓
PREVIEW
  ↓
VALIDATE
  ↓
SIMULATE
  ↓
EDIT
  ↓
ACCEPT
```

No automation candidate shall silently mutate an accepted project revision.

## 9. Acceptance target

K13 is considered technically mature only when a reference project demonstrates end-to-end:

```text
room geometry
  ↓
K12 electrical placement
  ↓
lighting / sockets / blinds / sensors
  ↓
electrical circuits
  ↓
KNX and/or Matter/DALI automation topology
  ↓
control bindings
  ↓
scenes
  ↓
failure simulation
  ↓
automation audit
  ↓
I/O + control schedules
  ↓
commissioning evidence
```

Reference acceptance shall include at least:

1. normal operation;
2. automation bus/power-supply failure;
3. gateway failure;
4. loss of electrical source;
5. local/manual fallback case;
6. emergency/life-safety override case;
7. revision change invalidating bindings;
8. design-vs-installed deviation;
9. deterministic replay;
10. no false-PASS sentinel cases.

## 10. Explicit non-goals

K13 SHALL NOT make Electra a replacement for:

- Home Assistant runtime;
- Apple Home / Google Home / Alexa / Alice runtime;
- KNX ETS commissioning software;
- vendor cloud;
- MQTT broker;
- camera/NVR platform;
- consumer voice assistant;
- generic IoT backend;
- SCADA runtime.

Electra's role is the **engineering source of truth for electrical + automation design, validation, simulation, documentation and commissioning evidence**.