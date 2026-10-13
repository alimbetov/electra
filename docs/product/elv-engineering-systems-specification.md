# Electra — ELV / Engineering Systems Specification

Status: Draft 0.1  
Branch: `docs/elv-engineering-systems-spec`  
Scope: product and domain requirements before implementation

## 1. Purpose

Extend Electra from an electrical-design application into a common engineering-network platform that supports low-voltage (ELV) systems without duplicating geometry, routing, cable, catalog, enclosure, calculation, and reporting capabilities.

The core principle is: **electrical power and ELV systems use a shared physical model, while each engineering system keeps its own topology, connection rules, calculation rules, and normative constraints.**

This specification deliberately describes requirements first. Concrete persistence classes, Flutter widgets, database schemas, and service APIs must be derived later through ADRs and implementation plans.

## 2. Architectural principles

1. Do not build a separate “ELV application” inside Electra.
2. Reuse common geometry, surfaces, placement, routes, cable runs, junction nodes, manufacturer catalogs, undo/redo, project hierarchy, and reporting infrastructure.
3. Model **physical placement**, **logical connectivity**, and **power connectivity** as related but distinct concerns.
4. A device may simultaneously participate in several networks.
5. Connections must terminate on explicit ports, not directly on devices.
6. Power conversion must be represented explicitly: transformer, AC/DC PSU, DC/DC converter, PoE source, UPS, charger, battery.
7. System-specific behavior must be driven by capabilities, catalogs, reference data, and normative rules rather than large hard-coded type checks.
8. Cable and route are different concepts: a cable describes a connection; a cable run describes how it is physically routed.
9. Electrical panels, ELV cabinets, network racks, automation cabinets, fire panels, and junction boxes share enclosure concepts but keep type-specific constraints.
10. Normative checks must be explainable: every warning/error should reference the violated rule and affected objects.

## 3. Supported engineering-system families

The system catalog must support at least:

- Electrical power
- CCTV
- Structured cabling / LAN
- Wi-Fi infrastructure
- Access control
- Fire alarm
- Intrusion/security alarm
- Intercom
- Public address / voice alarm
- Telephony
- TV / RF
- BMS
- Building automation
- Industrial automation
- IoT / sensor networks
- Custom engineering systems

The list must be extensible through reference data. A fixed enum may exist only for stable core categories, not as the only source of truth.

## 4. EngineeringSystem

An engineering system represents a logical discipline/network within a project.

Minimum conceptual attributes:

- id
- code
- name
- category
- system family
- default voltage class where applicable
- routing class
- normative profile
- visualization profile
- active flag

Examples:

- `POWER-L1` — Lighting power
- `CCTV-01` — Video surveillance
- `LAN-01` — Structured cabling
- `FA-01` — Fire alarm
- `ACS-01` — Access control

A project may contain multiple systems of the same family.

## 5. Universal engineering component

Any placed technical object should be representable as an engineering component.

Examples:

- socket
- luminaire
- camera
- detector
- reader
- controller
- switch
- access point
- speaker
- intercom panel
- transformer
- PSU
- UPS
- battery
- junction box
- rack
- patch panel
- PLC
- sensor

A component has:

- placement on project geometry
- manufacturer/catalog identity if applicable
- capabilities
- zero or more ports
- optional enclosure membership
- optional power characteristics
- optional system membership

## 6. Component capabilities

Electra must support capability-driven behavior.

Initial capabilities should include concepts such as:

- `POWER_SOURCE`
- `POWER_CONSUMER`
- `POWER_CONVERTER`
- `POE_SOURCE`
- `POE_CONSUMER`
- `DATA_ENDPOINT`
- `NETWORK_SWITCH`
- `VIDEO_SOURCE`
- `VIDEO_RECORDER`
- `FIRE_DETECTOR`
- `LOOP_DEVICE`
- `ACCESS_READER`
- `ACCESS_CONTROLLER`
- `CONTROL_DEVICE`
- `BUS_DEVICE`
- `BATTERY_BACKUP`

A component may expose multiple capabilities simultaneously.

Example: a PoE IP camera is both `VIDEO_SOURCE`, `DATA_ENDPOINT`, and `POE_CONSUMER`.

## 7. Ports

Explicit ports are mandatory for the connectivity model.

A port conceptually includes:

- id
- component reference
- port type
- direction
- connector/interface type
- voltage class if relevant
- protocol if relevant
- maximum power/current if relevant
- capacity / channel count where relevant
- compatibility metadata

Initial port types:

- POWER
- DATA
- SIGNAL
- BUS
- DATA_POWER
- AUDIO
- VIDEO
- FIBER
- RF
- CONTACT

Example:

Camera:

- `ETH1`: DATA_POWER, RJ45, Ethernet, PoE+
- optional `PWR1`: POWER, 12 VDC

Access controller:

- POWER IN
- RS-485
- Wiegand/OSDP reader ports
- relay outputs
- digital inputs
- Ethernet

Connections must be validated against port compatibility.

## 8. Connectivity model

Electra must distinguish several connection semantics while using one common graph foundation.

Required connection classes include:

- electrical circuit connection
- data link
- signal link
- fire/security loop
- field bus segment
- control circuit
- dry-contact connection
- fiber link
- combined data + power connection

General graph:

`Component -> Port -> Connection -> Port -> Component`

The topology engine must support:

- point-to-point
- star
- tree
- bus
- loop
- ring
- radial
- daisy chain

Topology validity is system-specific.

## 9. Cable versus CableRun

Electra must preserve a strict distinction:

### Cable
Describes what physically/electrically connects ports.

Properties may include:

- cable type
- conductors / pairs / fibers
- category
- shielding
- fire-resistance class
- conductor cross-section
- outer diameter
- voltage rating
- manufacturer product

### CableRun
Describes where a cable or cable group is physically routed.

A CableRun may pass through:

- wall surface
- ceiling surface
- floor surface
- tray
- conduit
- duct
- shaft/riser
- junction box
- penetration
- transition between surfaces

Multiple cables may share the same physical route.

The existing Electra routing foundation should be reused rather than duplicated for ELV.

## 10. Power topology for ELV devices

ELV power must be modeled independently from signal/data topology.

Examples:

### Conventional DC supply

`Panel -> MCB -> PSU 230VAC/24VDC -> controller/camera/sensor`

### PoE

`Panel -> UPS -> PoE Switch -> Ethernet/PoE -> Camera`

### Fire alarm

`Panel -> PSU/charger -> batteries -> fire control panel -> loop devices`

A single device may therefore participate in at least two graphs:

- functional/data/signal graph
- power graph

Electra must not assume that every ELV component is connected to a transformer.

## 11. Power conversion and backup

Power conversion devices must be first-class engineering components.

Initial device classes:

- transformer
- AC/DC PSU
- DC/DC converter
- PoE injector
- PoE switch
- UPS
- charger
- battery

Required calculation parameters may include:

- input voltage
- output voltage
- rated current
- rated power
- efficiency
- derating
- reserve factor
- battery capacity
- autonomy target
- PoE standard and per-port budget

The calculation engine must support future automatic selection based on connected loads.

## 12. Equipment enclosures

Introduce a common enclosure concept.

Initial enclosure types:

- electrical panel
- ELV cabinet
- network rack
- fire alarm cabinet
- access-control cabinet
- automation cabinet
- junction box

Shared behavior:

- physical dimensions
- mounting location
- internal capacity
- installed components
- thermal/power metadata where relevant
- free capacity

Type-specific behavior remains possible.

Examples:

Network rack:

- patch panels
- switches
- PoE switches
- router
- UPS
- fiber panel

Fire cabinet:

- control panel
- PSU
- batteries
- loop modules

## 13. Manufacturer catalog extension

The manufacturer catalog must cover electrical and ELV products using a common product foundation.

Categories should include:

- breakers / RCD / contactors
- transformers / PSU / UPS / batteries
- cameras
- NVR/DVR
- switches
- PoE switches
- access points
- detectors
- access readers
- access controllers
- intercom devices
- speakers
- racks
- patch panels
- enclosures
- trays / ducts / conduits
- cables
- automation equipment

A product definition may provide reusable port templates and capability templates.

Example: selecting a specific PoE camera product can automatically instantiate its Ethernet/PoE port, power demand, mounting constraints, and supported protocols.

## 14. Normative and compatibility rules

Rules must be reference-data driven where practical.

Future rules include:

- separation between power and data cabling
- required barriers/dividers
- fire-rated cable requirements
- permitted tray/conduit fill
- minimum bend radius
- maximum cable/link length
- maximum bus segment length
- PoE voltage/power limits
- voltage-drop limits
- PSU reserve requirements
- UPS/autonomy requirements
- loop/device capacity
- rack capacity
- port capacity
- environmental/IP-rating requirements

Every validation finding should carry:

- severity
- rule id/code
- human-readable explanation
- affected objects
- measured/current value
- allowed value
- remediation hint where possible

## 15. Routing requirements

ELV must reuse the same floor/surface routing engine used by electrical systems.

The router must consider:

- system routing class
- route compatibility
- shared tray/conduit occupancy
- prohibited adjacency
- transitions between surfaces
- penetrations
- risers
- junction points
- cable length
- reserve/service loops where configured

Routing should later support automatic optimization by distance, normative compliance, congestion, and installation cost.

## 16. Calculation requirements

Planned calculations include:

- cable length
- route occupancy
- number of cables per segment
- power demand
- PSU load and reserve
- PoE budget
- UPS load
- battery autonomy
- voltage drop for powered ELV devices where relevant
- switch port utilization
- patch-panel utilization
- controller channel utilization
- loop capacity
- rack-unit utilization
- cabinet free capacity

Calculations must be dependency-driven so changes to a device, cable, route, or catalog item can trigger only affected recalculations.

## 17. Editor UX requirements

The engineering workspace must preserve the existing “dry engineering drawing” approach.

System filtering is mandatory.

Example system selector:

- Electrical
- CCTV
- LAN
- Fire Alarm
- Access Control
- BMS

When CCTV is active, the palette should prioritize only relevant components such as cameras, switches, NVRs, racks, boxes, and applicable power sources.

Passive disciplines/components should be hidden or visually de-emphasized to avoid information overload.

The editor should expose context-sensitive side panels instead of permanently showing all properties.

Primary interaction flow:

1. choose engineering system
2. place device
3. connect compatible ports
4. create/assign cable
5. route CableRun
6. validate
7. calculate
8. generate schedules/BOM

## 18. Visualization requirements

Each engineering system must have a distinct but configurable visualization profile.

The UI should support:

- system visibility toggle
- connection overlay
- power topology overlay
- signal/data topology overlay
- route overlay
- enclosure contents
- validation markers
- utilization markers

A device connected to multiple systems must remain one physical object, not duplicated geometry.

## 19. Reporting and deliverables

Future reports must include:

- equipment schedule
- cable schedule
- connection table
- port schedule
- route schedule
- rack/cabinet layout
- panel/cabinet equipment list
- PSU power budget
- PoE budget
- UPS/battery autonomy report
- switch/controller port utilization
- BOM
- validation report

Reports must be derived from the same model used by the editor and calculations.

## 20. Proposed delivery sequence

The exact numbering must be reconciled with the current Flutter delivery plan before implementation.

Candidate feature sequence after the existing electrical foundation:

- Engineering Systems Foundation
- Component Ports & Connectivity
- ELV Component Model
- Power Conversion & Backup
- ELV Cabinets & Racks
- ELV Network Topologies
- Cable & Route Constraints
- ELV Calculation Engine
- Automatic Equipment Selection
- ELV Reports and BOM

This sequence is intentionally capability-oriented, not CCTV-first or LAN-first, so later disciplines reuse the same core.

## 21. Initial acceptance criteria

The ELV foundation is considered correctly designed when Electra can represent the following scenario without special-case hacks:

1. Place an IP PoE camera on a ceiling/wall surface.
2. Instantiate its Ethernet/PoE port from catalog metadata.
3. Place a PoE switch inside a network rack.
4. Connect camera to a switch port using Cat6.
5. Route the cable through existing floor/surface routing infrastructure.
6. Associate the same camera with CCTV functional topology.
7. Model the switch power chain through UPS to an electrical panel.
8. Calculate cable length, PoE power utilization, switch port utilization, UPS load, and route occupancy.
9. Detect an intentionally violated routing/normative rule.
10. Produce equipment, cable, connection, and power-budget schedules from the same project model.

A second acceptance scenario must cover a non-IP topology, for example fire alarm or access control, to prove the model is not accidentally optimized only for Ethernet/PoE.

## 22. Explicit non-goals for the first ELV foundation iteration

Do not initially attempt to implement:

- every vendor protocol
- complete manufacturer libraries
- full national/international standards database
- simulation of packet traffic
- detailed RF propagation
- complete fire-alarm certification logic
- complete BMS control logic
- automatic commissioning

The first goal is a stable universal model that these capabilities can build upon.

## 23. Open design decisions to resolve before coding

1. Whether EngineeringSystem membership belongs directly to components, connections, or both.
2. Exact separation between `Connection`, `Cable`, and `CableRun` persistence models.
3. Whether ports are persisted instances, catalog-derived immutable templates, or instantiated copies.
4. Capability storage model: reference table, typed values, or hybrid model.
5. Generic enclosure model versus specialized panel/rack aggregates.
6. Rule engine format and rule-versioning strategy.
7. How shared routes allocate physical capacity between different engineering systems.
8. How topology graphs integrate with the existing dependency-recalculation engine.
9. Which normative catalogs are packaged by default and which are project/user supplied.
10. How project migration will preserve compatibility with already created electrical objects.

## 24. Next specification work

Before implementation, this document should be expanded with:

- domain glossary
- aggregate boundaries
- canonical diagrams
- data invariants
- lifecycle rules
- compatibility matrix for ports and cables
- topology rules by system family
- power-calculation formulas
- normative-rule model
- migration strategy
- UI workflows
- acceptance scenarios for CCTV, LAN, access control, fire alarm, and BMS

Only after these points are stable should implementation branches be opened.
