# Electra — ELV Domain Scenario Validation

Status: Draft 0.1  
Branch: `docs/elv-engineering-systems-spec`  
Depends on: `docs/architecture/elv-domain-model-and-invariants.md`

## 1. Purpose

Validate the proposed universal model against four materially different engineering disciplines:

1. CCTV;
2. structured cabling / LAN;
3. access control (ACS);
4. fire alarm.

The objective is not to describe every vendor protocol. The objective is to prove that the same domain primitives can represent each discipline without creating parallel discipline-specific copies of Component, Port, Connection, Cable, CableRun, Route, or Enclosure.

Pass condition: the scenario is representable through generic primitives plus reference-data/topology rules. If a scenario requires a recurring concept that cannot be expressed cleanly, that concept should be promoted into the common domain model.

---

## 2. Baseline primitives under test

```text
EngineeringSystem
SystemMembership
EngineeringComponent
Capability
Port
Connection
Cable
CableAllocation
CableRun
Route
Enclosure
```

Separation under test:

```text
discipline  != device
device      != topology
topology    != cable
cable       != route
route       != enclosure
```

---

# 3. Scenario A — CCTV with PoE cameras

## 3.1 Physical design

```text
                    RACK-CCTV-01
             ┌─────────────────────┐
230 VAC ---> │ UPS-01              │
             │   │                 │
             │   v                 │
             │ POE-SW-01           │
             │  ├─ P01             │
             │  ├─ P02             │
             │  └─ P03             │
             │ NVR-01              │
             └─────────────────────┘
                 │       │
             Cat6       Cat6
                 │       │
              CAM-01   CAM-02
```

## 3.2 Systems

- `CCTV-01` — video-surveillance functional system;
- `LAN-CCTV-01` — optional dedicated network/transport system;
- `POWER-UPS-01` — upstream power context.

The same physical PoE switch may participate in all three through `SystemMembership`.

## 3.3 Components and capabilities

`CAM-01`:

- `VIDEO_SOURCE`;
- `DATA_ENDPOINT`;
- `POE_CONSUMER`.

Ports:

- `ETH1`: `DATA_POWER`, RJ45/Ethernet/PoE profile.

`POE-SW-01`:

- `NETWORK_SWITCH`;
- `POE_SOURCE`;
- `POWER_CONSUMER`.

Ports:

- `P01..Pn`: `DATA_POWER`;
- `PWR-IN`: `POWER`.

`NVR-01`:

- `VIDEO_RECORDER`;
- `DATA_ENDPOINT`;
- `POWER_CONSUMER`.

## 3.4 Connections

Camera to switch:

```text
CAM-01.ETH1
    ↕ COMBINED_DATA_POWER
POE-SW-01.P01
```

This is one semantic connection capable of carrying both Ethernet and PoE because the port/interface profile explicitly supports it.

Switch to NVR may be another `DATA_LINK` connection or may traverse intermediate switching infrastructure.

## 3.5 Cable and routing

`CABLE-CCTV-001`:

- Cat6 product/type;
- one allocation to camera/switch connection;
- one `CableRun` through shared tray/wall/ceiling route segments.

Route occupancy is calculated from cable geometry, not from Ethernet semantics.

## 3.6 Power calculation

Power graph remains independently traceable:

```text
Electrical panel
  -> UPS-01
  -> POE-SW-01
  -> CAM-01
```

Camera load contributes to:

- switch per-port power;
- total PoE budget;
- switch input demand;
- UPS load;
- upstream panel load.

## 3.7 Invariant checks

Expected validation examples:

- incompatible non-PoE port assigned to PoE camera;
- switch PoE budget exceeded;
- port capacity exceeded;
- cable category/profile incompatible;
- cable length/routing rule violated;
- route capacity exceeded;
- UPS demand exceeds configured capability.

## 3.8 Result

**PASS.**

The generic model represents CCTV without CCTV-specific persistence entities.

No new core abstraction is required by this scenario.

---

# 4. Scenario B — Structured cabling / LAN

## 4.1 Physical design

```text
WORK AREA                       TELECOM RACK

DATA-OUTLET-01                  RACK-LAN-01
┌─────────────┐                 ┌────────────────────┐
│ JACK-A      │--- horizontal --│ PP-01.PORT-01      │
└─────────────┘     Cat6        │       │ patch cord │
                                │ SW-01.PORT-01      │
                                └────────────────────┘
```

This scenario is intentionally different from CCTV because structured cabling distinguishes installed permanent cabling from active network connectivity.

## 4.2 Components

- data outlet / faceplate;
- jack/keystone component or port depending chosen granularity;
- patch panel;
- network switch;
- rack;
- optional consolidation point.

## 4.3 Important distinction

The permanent horizontal cable from work-area jack to patch-panel port must exist even before a switch is installed or patched.

Therefore Electra must not equate `Connection` with “active Ethernet session”.

Represent the permanent link as physical connectivity between termination ports:

```text
OUTLET-01.JACK-A
     ↕ DATA_LINK / STRUCTURED_CABLING
PP-01.PORT-01
```

Cable allocation realizes that connection.

A patch cord is a second cable/connection:

```text
PP-01.FRONT-01
     ↕ DATA_LINK
SW-01.PORT-01
```

This keeps documentation faithful to the installation.

## 4.4 Patch-panel modeling

Patch panel is a component with paired/internal termination semantics.

Example:

```text
PP-01
PORT-01-REAR  <internal mapping>  PORT-01-FRONT
```

The mapping is not external installed cable. It is device-internal connectivity.

This reveals a reusable need for **internal port mapping** inside components.

Recommended common concept:

```text
InternalConnectivity
- componentId
- portA
- portB
- mapping/profile
```

It should be usable by:

- patch panels;
- terminal blocks;
- relays;
- isolators;
- splitters;
- adapters;
- some controller modules.

It must not create BOM cable or CableRun.

## 4.5 Cable resources

For Cat6, one physical cable usually realizes one permanent link.

For fiber backbone:

```text
12-fiber cable
├── fibers 1-2 -> link A
├── fibers 3-4 -> link B
├── fibers 5-6 -> link C
└── spare fibers
```

This directly validates the need for `CableAllocation`.

## 4.6 Rack/enclosure

The rack contains:

- patch panels;
- switches;
- fiber panels;
- cable management;
- UPS.

Capacity strategies include:

- rack units;
- depth;
- weight;
- power;
- thermal budget.

They belong to enclosure strategy/profile, not to generic Component itself.

## 4.7 Invariant checks

- duplicate use of same patch-panel port;
- allocated fiber/pair already occupied;
- cable category/interface mismatch;
- permanent-link maximum-length rule violated;
- rack U capacity exceeded;
- unsupported cable sharing with incompatible discipline on route;
- route occupancy exceeded.

## 4.8 Result

**PASS WITH ONE GENERIC EXTENSION.**

Add common `InternalConnectivity` inside EngineeringComponent.

This is preferable to introducing LAN-specific patch-panel logic.

---

# 5. Scenario C — Access Control System (ACS)

## 5.1 Door assembly

A typical controlled door includes multiple physical devices:

```text
                 DOOR D-101

Reader --------> Controller input
Exit button ----> Controller input
Door contact ---> Controller input
Controller relay -> Electric lock

Controller
   ^
   │ 24 VDC
   │
PSU/charger ---- Battery
   ^
   │ 230 VAC
Electrical panel
```

The controller may additionally connect to LAN.

## 5.2 Components

- reader;
- door contact;
- request-to-exit button;
- electric strike/maglock;
- controller;
- PSU/charger;
- battery;
- cabinet;
- door from building geometry/domain.

## 5.3 Ports and connections

Reader may expose:

- OSDP/RS-485 bus port;
- or legacy signal ports depending product.

Lock connection:

```text
CTRL-01.RELAY-NO/COM
    -> terminal/intermediate wiring
    -> LOCK-01.PWR/CTRL
```

Door contact:

```text
CONTACT-01.OUT
    -> CTRL-01.INPUT-01
```

Power:

```text
PSU-01.OUT-24V
    -> CTRL-01.PWR-IN
```

All are generic Ports + Connections with different semantic profiles.

## 5.4 Door as a functional assembly

A recurring requirement appears: engineer wants to treat “Door D-101 access-control set” as one functional unit while its physical components remain independently placed and connected.

Using Enclosure would be incorrect because a door does not physically contain the controller cabinet or PSU.

Therefore introduce an orthogonal generic concept:

```text
ComponentAssembly
- id
- projectId
- type/profile
- anchor/reference (optional building element)
- member components with roles
```

Example:

```text
Assembly ACS-DOOR-D101
├── READER-01 role=ENTRY_READER
├── CONTACT-01 role=DOOR_CONTACT
├── LOCK-01 role=LOCK
├── REX-01 role=EXIT_BUTTON
└── CTRL-01 role=CONTROLLER_CHANNEL
```

`ComponentAssembly` is not ownership and must not control member lifecycle by cascade.

This abstraction is reusable for:

- access-control door sets;
- CCTV pole assemblies;
- equipment skids;
- luminaire/emergency-control groups;
- automation functional units.

## 5.5 Controller channel capacity

A controller may support N doors/readers/inputs/outputs.

Capacity can be expressed through explicit ports/channels plus component capability parameters.

No ACS-specific aggregate is required for port utilization.

## 5.6 Invariant checks

- lock voltage incompatible with PSU;
- controller reader port incompatible with reader protocol;
- controller channel already allocated;
- battery/PSU capacity insufficient;
- assembly missing mandatory role (e.g. lock) according to selected profile;
- cable conductor resource collision;
- route/rule violation.

## 5.7 Result

**PASS WITH ONE GENERIC EXTENSION.**

Add `ComponentAssembly` for functional grouping that is neither physical containment nor engineering-system membership.

Do not misuse Enclosure or EngineeringSystem for this purpose.

---

# 6. Scenario D — Fire Alarm

## 6.1 Physical design

Example addressable loop:

```text
                     LOOP L1
              ┌────────────────────┐
              │                    │
FACP.L1-OUT -> DET-01 -> DET-02 -> MCP-01 -> ISO-01
              │                    │
              └──────── return ----┘
                      -> FACP.L1-IN
```

Separate sounder/power/control circuits may coexist.

## 6.2 Components

- fire alarm control panel (FACP);
- detector;
- manual call point;
- isolator;
- sounder;
- I/O module;
- PSU/charger;
- batteries;
- junction/termination components where physically present.

## 6.3 Binary connection test

The loop can be represented by binary edges:

```text
FACP.L1-OUT -> DET-01.IN
DET-01.OUT  -> DET-02.IN
DET-02.OUT  -> MCP-01.IN
...
ISO-01.OUT  -> FACP.L1-IN
```

No hyperedge is required.

Branching is represented only where the actual system/device permits it, using explicit ports/modules/junction components.

Therefore the binary `Connection` decision survives this scenario.

## 6.4 Need for loop identity

Although binary edges are sufficient for connectivity, engineering calculations and reports need to answer:

- which connections belong to Loop L1;
- number of devices on Loop L1;
- loop length;
- loop load;
- topology closure;
- isolator segmentation;
- fault-domain information;
- controller capacity.

`EngineeringSystem = FA-01` is too broad: one fire alarm system may have many loops, sounder circuits, communication buses, and auxiliary circuits.

Therefore introduce a generic intermediate topology concept:

```text
TopologyGroup
- id
- engineeringSystemId
- type/profile
- code
- ordered/topology metadata
- member connection ids
- optional source/controller port
```

Generic types/profiles can represent:

- FIRE_LOOP;
- POWER_CIRCUIT;
- DATA_SEGMENT;
- BUS_SEGMENT;
- CONTROL_CIRCUIT;
- SPEAKER_LINE;
- ZONE_GROUP;
- vendor/custom profiles.

The type list should be extensible reference data, not a hard-coded fire-alarm entity hierarchy.

## 6.5 Topology validation

For fire loop profile, rules may require:

- valid start port;
- valid return port when loop topology requires closure;
- no illegal branch;
- device count/capacity constraints;
- compatible devices/interfaces;
- allowed cable profile;
- continuity/order;
- required isolation rules.

These rules belong to the `TopologyGroup` profile/rule set.

## 6.6 Cable behavior

A fire loop may use separate cable sections between successive devices.

Each physical section is a cable with its own run.

If a multicore physical cable carries several fire/control circuits, `CableAllocation` handles resource assignment.

## 6.7 Power and battery topology

Panel power remains a separate graph:

```text
Electrical panel
 -> FACP PSU/charger
 -> batteries
 -> panel electronics / powered outputs
```

This validates separation between functional loop and power topology.

## 6.8 Invariant checks

- loop not closed when required by selected profile;
- device attached to incompatible loop protocol;
- loop device/capacity limit exceeded;
- illegal branch;
- cable profile incompatible with normative requirement;
- missing required isolator according to rule profile;
- battery/autonomy target not met;
- route incompatibility or fire-rating requirement violated.

## 6.9 Result

**PASS WITH ONE IMPORTANT GENERIC EXTENSION.**

Add `TopologyGroup` between EngineeringSystem and Connection for engineering circuits/loops/buses that require identity, aggregate calculations, and topology rules.

Do not create a fire-specific `FireLoop` persistence root as the universal foundation.

---

# 7. Cross-scenario findings

The original primitive model is fundamentally sound, but four scenarios reveal three reusable abstractions that should be added before implementation.

## 7.1 TopologyGroup — required

Purpose: name and validate a subset of connections as one engineering circuit/network segment.

```text
EngineeringSystem
└── TopologyGroup
    └── Connection[]
```

Examples:

- fire loop;
- RS-485 bus;
- access-control bus;
- speaker line;
- lighting/control circuit;
- network backbone segment;
- automation bus.

Invariants:

- group belongs to exactly one EngineeringSystem;
- Connection has zero or one primary TopologyGroup for a given semantic layer unless the profile explicitly supports multiple classification groups;
- all grouped connections must be compatible with the group's topology profile;
- group topology and capacity rules are profile-driven;
- deletion is blocked while connections remain assigned unless explicitly detached.

## 7.2 InternalConnectivity — required

Purpose: describe connectivity inside a component without creating external cable/BOM/routing artifacts.

Examples:

- patch-panel rear-to-front mapping;
- terminal block internal bridge;
- relay common/NO/NC behavior representation where static mapping is appropriate;
- adapter/converter internal mapping;
- splitter/passive module mapping.

Invariants:

- both ports belong to the same component;
- internal connectivity cannot have Cable or CableRun;
- it participates in trace algorithms;
- dynamic behavior must not be falsely modeled as permanent internal connectivity; switching/control semantics may need a later behavior model.

## 7.3 ComponentAssembly — recommended for first ELV foundation

Purpose: functional grouping across physical objects without implying containment or system ownership.

Examples:

- controlled door set;
- CCTV pole set;
- workstation outlet group;
- automation field assembly.

Invariants:

- assembly membership is non-owning;
- member components remain independently placed/connected;
- role constraints are profile-driven;
- a component may belong to multiple assemblies only when profiles permit it.

---

# 8. Revised canonical domain model

After scenario validation, the preferred model becomes:

```text
Project
│
├── EngineeringSystem
│    ├── SystemMembership
│    └── TopologyGroup[]
│          └── Connection[]
│
├── EngineeringComponent
│    ├── Capability[]
│    ├── Port[]
│    ├── InternalConnectivity[]
│    ├── Placement
│    └── optional EnclosureAspect
│
├── ComponentAssembly[]
│    └── member roles -> EngineeringComponent
│
├── Connection
│    └── endpoints -> Port x2
│
├── Cable
│    ├── physical resources
│    ├── CableAllocation[] -> Connection
│    └── CableRun
│
├── Route
│    ├── RouteNode[]
│    └── RouteSegment[]
│
└── EnclosureAspect
     └── contains EngineeringComponent[]
```

Trace path:

```text
EngineeringSystem
 -> TopologyGroup
 -> Connection
 -> Port
 -> Component
 -> CableAllocation
 -> Cable
 -> CableRun
 -> RouteSegment
 -> Route
```

Physical containment remains orthogonal:

```text
Component -> EnclosureMembership -> EnclosureComponent
```

Functional grouping remains orthogonal:

```text
Component -> AssemblyMembership -> ComponentAssembly
```

---

# 9. Model fitness matrix

| Capability | CCTV | LAN | ACS | Fire Alarm |
|---|---:|---:|---:|---:|
| shared Component | PASS | PASS | PASS | PASS |
| persisted Ports | PASS | PASS | PASS | PASS |
| binary Connection | PASS | PASS | PASS | PASS |
| separate Cable | PASS | PASS | PASS | PASS |
| CableAllocation | useful | required for fiber/multicore | required for multicore | useful/required |
| CableRun / Route separation | PASS | PASS | PASS | PASS |
| multi-system membership | required | useful | required | required |
| Enclosure model | PASS | PASS | PASS | PASS |
| TopologyGroup | optional | useful | useful | **required** |
| InternalConnectivity | optional | **required** | useful | useful |
| ComponentAssembly | optional | optional | **required/useful** | optional |
| independent power graph | **required** | useful | **required** | **required** |

No discipline requires a separate duplicate core domain.

---

# 10. Design decisions confirmed by scenario validation

The following are now considered validated baseline requirements for the specification:

1. Components are project physical/logical identities independent of system membership.
2. Multi-system membership is mandatory.
3. Ports are persisted instances.
4. External Connections are binary and terminate on Ports.
5. Branches are explicit topology, not implicit hyperedges.
6. Cable is a physical asset distinct from Connection.
7. Cable resources require explicit allocation where relevant.
8. CableRun is physical realization and Route is reusable routing infrastructure.
9. Enclosure is physical containment, not functional grouping.
10. `TopologyGroup` is required as a generic circuit/loop/bus identity.
11. `InternalConnectivity` is required for component-internal traceability.
12. `ComponentAssembly` is needed for functional equipment sets such as controlled doors.
13. Functional/signal/data topology and power topology remain independent but traceable.
14. All discipline-specific restrictions should enter through profiles/rules/reference data unless they represent a genuinely new universal concept.

---

# 11. What should NOT be added yet

Scenario validation does **not** justify introducing the following as core aggregates now:

- CCTVNetwork;
- LanNetwork;
- FireLoop as a dedicated persistence type;
- AccessDoor as an ACS-specific root;
- PoECircuit;
- vendor-specific protocol entities;
- packet/network simulation model;
- fire-certification engine;
- BMS point database.

These should initially be profiles, capabilities, system types, topology-group types, assemblies, or later bounded capabilities built on the common model.

---

# 12. Next specification gate

Before implementation begins, the next design pass should specify:

1. exact entity/value-object contracts for `TopologyGroup`, `InternalConnectivity`, and `ComponentAssembly`;
2. port compatibility matrix and validation algorithm;
3. cable resource model: conductor/pair/fiber/channel allocation;
4. topology profiles and validation rules for the four validated disciplines;
5. power-source/converter/load model and calculation graph;
6. reference-data versioning and project snapshot strategy;
7. migration mapping from existing electrical Circuit/CableRun/Panel concepts into the common model;
8. acceptance tests expressed as domain-level Given/When/Then scenarios.

Implementation should remain blocked until these contracts are stable enough that CCTV, LAN, ACS, and fire-alarm acceptance scenarios can be expressed without schema changes.
