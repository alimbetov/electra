# Electra — ELV Delivery Plan

Status: ELV1 CLOSED; ELV2 CLOSED; ELV3 READY FOR DESIGN / ANALYSIS
Accepted baseline: `main@f05b1e558a93b40928429ca86d91f4daa0cf4ef0`
Pre-ELV3 hardening: `feat/flutter-elv12-pre-elv3-hardening`
Scope: implementation roadmap after accepted ELV1/ELV2 baseline

## 1. Purpose

This document converts the canonical ELV specification into executable work packages `ELV2` through `ELV8`.

The plan assumes the ELV1 foundation has already defined the shared connectivity grammar:

```text
EngineeringSystem
→ EngineeringComponent
→ Port
→ Connection
→ Cable
→ CableRun
→ Route
→ Enclosure
```

and proved that the same graph foundation can represent CCTV, LAN/structured cabling, access control and fire alarm without discipline-specific hacks.

The next stages must add engineering semantics progressively without breaking the common kernel.

The guiding rule is:

> **Physical infrastructure is shared; engineering semantics, calculations and normative rules remain discipline-owned.**

## 2. Delivery rules

Every ELV work package must satisfy all of the following before the next package starts:

1. Canonical domain contracts are explicit and independent from Flutter/Drift.
2. Persisted state is versioned and reconstructs exactly after application restart.
3. Reference data is immutable by version and project snapshots keep exact references.
4. Derived results are reproducible from canonical inputs plus frozen reference/profile versions.
5. No manufacturer SKU is allowed to become the source of engineering truth.
6. No rule threshold is hidden as a UI constant or anonymous magic number.
7. Every non-trivial validation/calculation exposes inputs, result, source profile/rule and explanation.
8. CCTV, LAN, access control and fire alarm fixtures are maintained as cross-discipline regression scenarios.
9. Changes invalidate only the affected dependency subgraph.
10. UI uses discipline-native terminology while sharing common editor infrastructure.

## 3. Overall sequence

```text
ELV1  Ports / Connections / Topology
  ↓
ELV2  Canonical system profiles and reference catalogs
  ↓
ELV3  Cables, routes, pathways and physical compatibility
  ↓
ELV4  ELV power conversion, PoE, PSU, UPS and battery backup
  ↓
ELV5  Discipline-specific calculation processes
  ↓
ELV6  Cabinets, racks, patching and enclosure capacity/layout
  ↓
ELV7  Versioned normative profiles and explainable validation
  ↓
ELV8  Equipment selection, BOM, schedules and engineering deliverables
```

The stages are intentionally capability-oriented. There is no separate CCTV engine, separate LAN router or separate fire-alarm persistence layer.

---

# ELV2 — Canonical system profiles and reference catalogs

## 4. Objective

Turn the generic ELV1 graph into an engineering model that understands what a camera, switch, detector, reader, controller, loop device, cable category and interface class mean without hard-coding vendor products.

ELV2 establishes the canonical reference vocabulary consumed by all later calculations and validators.

## 5. Scope

### 5.1 Common ELV reference catalogs

Introduce typed/versioned catalogs for:

- engineering-system families;
- component engineering classes;
- component capabilities;
- port/interface classes;
- connector classes;
- protocol families;
- voltage classes;
- signal/media classes;
- topology profiles;
- mounting/environment classes;
- cable-medium classes;
- enclosure function classes.

### 5.2 Discipline-owned catalogs

#### CCTV

- camera engineering classes;
- sensor/lens profiles;
- stream/codec profiles;
- recorder capability profiles;
- camera power profiles;
- coverage-quality profiles.

#### LAN / structured cabling

- copper categories;
- fiber classes;
- connector/interface profiles;
- Ethernet speed profiles;
- PoE capability profiles;
- permanent-link/channel profiles;
- switch port classes;
- patching profiles.

#### Access control

- reader interface classes;
- lock types and electrical behavior;
- door topology profiles;
- controller input/output channel classes;
- request-to-exit/emergency-release roles;
- supervised input profiles.

#### Fire alarm

- detector/module classes;
- loop-device classes;
- address-consumption profiles;
- loop architecture profiles;
- isolator profiles;
- notification-device classes;
- standby/alarm consumption profiles.

## 6. Canonical domain model

Minimum conceptual contracts:

```text
ReferenceCatalog
- id
- code
- discipline
- version
- source
- jurisdiction?
- effectiveFrom?
- effectiveTo?
- immutable
```

```text
ComponentEngineeringProfile
- code
- discipline
- engineeringClass
- capabilities[]
- portTemplates[]
- mountingConstraints
- environmentConstraints
- electricalCharacteristics?
- disciplineCharacteristics
```

```text
TopologyProfile
- code
- discipline
- topologyKind
- allowedNodeRoles[]
- requiredRoles[]
- branchingPolicy
- closurePolicy
- capacityPolicy
```

A manufacturer product may map to these profiles later, but cannot redefine them.

## 7. ELV2 invariants

- catalog versions are immutable after use by a project;
- a project stores the exact catalog/profile version used;
- a component instance references a canonical engineering profile or an explicitly declared custom profile;
- port templates create persisted port instances; editing a later catalog version must not mutate existing project ports;
- discipline-specific calculation fields are typed, not stored only as free-form metadata;
- no canonical calculation may depend on display labels;
- deprecated profiles remain readable for reproducibility;
- custom project profiles require explicit provenance and version identity.

## 8. Persistence

Recommended new persistent concepts:

```text
reference_catalog_snapshots
component_engineering_profiles
port_profile_definitions
topology_profile_definitions
project_reference_bindings
component_profile_bindings
```

Project bindings must support explicit profile migration rather than silent latest-version adoption.

## 9. UI

Add a discipline-aware catalog experience:

```text
System
→ Category
→ Engineering class
→ Product-neutral definition
→ optional manufacturer product
```

The engineer should see domain-native terms:

- CCTV: Dome camera, Bullet camera, NVR, PoE switch;
- LAN: Data outlet, Patch panel, Access switch, Fiber panel;
- ACS: Reader, Door controller, Lock, Exit button;
- Fire: Detector, Manual call point, Isolator, Loop module.

## 10. ELV2 tests

Required pure-domain tests:

- profile immutability;
- template-to-port instantiation;
- profile-version preservation;
- topology-profile compatibility;
- discipline type safety;
- manufacturer-independent canonical mapping.

Required restart test:

```text
create project
→ bind reference snapshot
→ place components from four disciplines
→ instantiate typed ports
→ close database
→ reopen
→ reconstruct identical profile/port bindings
```

## 11. ELV2 acceptance

ELV2 is complete when one project can contain:

- PoE IP camera;
- Cat6 LAN outlet;
- OSDP reader + electric lock;
- addressable fire detector;

and each object is represented through typed canonical profiles with exact versioned reference provenance, without vendor-specific branching.

---

# ELV3 — Cables, routes, pathways and physical compatibility

## 12. Objective

Extend the existing Electra routing foundation so ELV connectivity becomes physically installable and checkable.

ELV3 answers:

> Which cable carries this connection, where is it routed, what physical carrier contains it, and is that physical arrangement technically compatible?

## 13. Scope

### 13.1 Cable model

Add typed cable definitions for:

- balanced copper;
- optical fiber;
- multi-core signal/control cable;
- fire-resistant cable;
- coax/RF;
- DC power cable;
- hybrid/data-power cable;
- custom engineering cable.

Relevant attributes may include:

- conductor count/pairs/fibers;
- conductor cross-section;
- conductor material;
- category/class;
- shielding;
- impedance where relevant;
- voltage rating;
- resistance/attenuation basis;
- outer diameter;
- minimum bend radius;
- fire performance class;
- environmental rating;
- manufacturer identity later.

### 13.2 Connection-to-cable allocation

Introduce explicit allocation rather than assuming `Connection == Cable`.

```text
Connection
  ↓
CableAllocation
  ↓
Cable
  ↓
CableRun
  ↓
Route
```

One physical cable may carry multiple compatible logical connections where the cable profile permits it.

### 13.3 Physical channels

Reuse/extend:

- cable tray;
- ladder;
- conduit;
- trunking/duct;
- shaft/riser;
- floor/ceiling/wall route;
- penetration;
- firestop;
- junction/transition node.

### 13.4 Route compatibility

Create explicit physical compatibility policies for:

- power/data segregation;
- safety/fire circuits;
- EMC-sensitive circuits;
- shared containment;
- barrier/divider requirements;
- environment/IP constraints;
- minimum bend radius;
- permitted installation method;
- service-loop/reserve requirements.

## 14. ELV3 domain contracts

```text
CableDefinition
- medium
- construction
- electrical/optical characteristics
- geometry
- fire/environment class
- routing constraints
```

```text
CableAllocation
- cableId
- connectionIds[]
- conductor/pair/fiber allocation
- allocationRole
```

```text
RouteCompatibilityResult
- status: OK/WARNING/FORBIDDEN
- rule/profile code
- affected runs
- explanation
```

## 15. ELV3 invariants

- every cabled connection must be allocated to a compatible cable or explicitly marked wireless/no-cable;
- one pair/fiber/conductor cannot be double allocated unless the profile explicitly permits shared signaling;
- cable endpoints must resolve to compatible ports;
- CableRun physical length is derived from route geometry plus explicit allowances;
- crossing geometry never creates an electrical/logical connection;
- route transitions must use valid spatial topology;
- a cable must not silently change engineering type when manufacturer product changes;
- channel occupancy must derive from physical cable dimensions, not cable count alone;
- route incompatibility is explicit and explainable.

## 16. ELV3 calculations

First common processes:

- `ELV-ROUTE-01` cable length;
- `ELV-ROUTE-02` physical channel fill;
- `ELV-ROUTE-03` segregation/separation;
- `ELV-ROUTE-04` bend-radius compliance;
- `ELV-ROUTE-05` congestion;
- `ELV-ROUTE-06` service-loop allowance.

These are common physical calculations. Discipline-specific electrical/link calculations remain ELV5.

## 17. ELV3 UI

Routing workspace must support:

- select connection;
- assign cable definition;
- show compatible/incompatible choices;
- create/edit CableRun using existing route editor;
- visualize shared containment;
- show fill and segregation findings;
- trace cable from endpoint to endpoint;
- show service loop/reserve explicitly;
- distinguish signal topology from physical route.

## 18. ELV3 acceptance scenarios

### CCTV

Camera → PoE switch using Cat6 routed through tray and wall transition.

### LAN

Outlet → patch panel using Cat6 permanent-link cable.

### ACS

Reader and lock cables share an ACS route but use independent allocations.

### Fire alarm

Loop cable uses a fire-alarm routing class and produces a finding when routed through an incompatible physical channel/profile.

ELV3 is complete when all four scenarios survive restart with exact routes, allocations and cable identities and route edits invalidate only dependent calculations.

---

# ELV4 — Power conversion, PoE, UPS and battery backup

## 19. Objective

ELV4 design entry: [authoritative index](elv4-authoritative-spec-index.md), [power specification](elv4-power-topology-design-specification.md), [expanded P0–P9 plan](elv4-p0-p9-delivery-plan.md), [coordinated package contracts](elv4-coordinated-p0-p9-contract.md), [detailed P0–P9 implementation specifications](elv4-implementation/README.md).

Design audit remediation: [resolved RM01–RM15 contracts](elv4-implementation/remediation-contract.md), strict wire schemas and qualification manifest now supplement all P0–P9 packages; specification resolution is separate from source/runtime acceptance.

Status: DESIGN DRAFT. ELV4 runtime entry requires P0 reconciliation of merged ELV3 code and final closure evidence; see [baseline alignment audit](../audit/elv4-baseline-alignment-audit.md). Historical stage status labels elsewhere in this roadmap do not establish runtime acceptance.

Make ELV power topology a first-class graph separate from signal/data topology.

A device can simultaneously participate in several graphs:

```text
functional topology
signal/data topology
power topology
physical cable/route topology
```

ELV4 must make these relations explicit rather than inferring them from component type.

## 20. Scope

First-class power components:

- transformer;
- AC/DC PSU;
- DC/DC converter;
- PoE switch;
- PoE injector;
- UPS;
- charger;
- battery;
- power distribution module;
- fused output module.

Model operating states where relevant:

- normal;
- standby;
- alarm/active;
- startup/inrush;
- backup operation.

## 21. Domain contracts

```text
PowerPortProfile
- nominalVoltage
- voltageRange
- acDc
- maxCurrent
- maxPower
- sourceConsumerRole
```

```text
PowerConversionProfile
- input profile
- output profile
- efficiency profile
- derating profile
- reserve policy
```

```text
BackupSourceProfile
- battery technology
- nominal voltage
- nominal capacity
- usable-capacity policy
- aging/temperature factors
```

```text
PoeProfile
- standard/profile
- PSE/PD role
- per-port capability
- total budget
```

## 22. ELV4 invariants

- signal/data connectivity never automatically implies a valid power path;
- PoE must be represented as combined data/power semantics on compatible ports;
- a powered device must have exactly the required upstream source topology or an explicit unresolved-power finding;
- voltage classes must be compatible through every connection/conversion stage;
- converters may change voltage class only through explicit conversion components;
- a battery does not directly become a normative autonomy result; calculation policy belongs to the calling discipline/profile;
- source output capacity cannot be duplicated across branches;
- project power topology must be cycle-safe except where a specifically modeled redundant topology allows it.

## 23. ELV4 calculations

Implement shared physical power processes:

- `ELV-PWR-01` connected load;
- `ELV-PWR-02` PSU sizing basis;
- `ELV-PWR-03` DC voltage-drop basis;
- `ELV-PWR-04` battery-autonomy basis;
- `ELV-PWR-05` UPS loading;
- `ELV-PWR-06` PoE budget.

Important boundary:

ELV4 supplies common physical formula capability. Discipline-specific reserve/autonomy policy belongs to ELV5/ELV7 profiles.

## 24. ELV4 UI

Provide a Power Topology overlay:

```text
Electrical panel
→ UPS
→ PoE switch
→ Camera
```

or:

```text
230 VAC
→ 24 VDC PSU
→ ACS controller
→ Lock / Reader
```

or:

```text
Mains
→ fire PSU/charger
→ battery
→ fire panel
→ loop/notification loads
```

The engineer must be able to trace `power upstream` and `power downstream` independently from signal tracing.

## 25. ELV4 acceptance

Required vertical scenarios:

1. CCTV PoE camera receives power through a PoE switch behind a UPS.
2. ACS controller/lock receives 24 VDC from a PSU and battery-backed source.
3. Fire panel uses PSU/charger + battery and exposes standby/alarm load inputs.
4. Removing a PSU or incompatible voltage source invalidates the affected power chain only.

---

# ELV5 — Discipline-specific engineering calculations

Design branch: `feat/flutter-elv5-power-topology-design`, based on ELV4 `4c35840`. Enter through the [ELV5 authoritative index](elv5-authoritative-spec-index.md), [design specification](elv5-discipline-calculations-design-specification.md) and [P0–P9 detailed plan](elv5-p0-p9-delivery-plan.md). Status: DESIGN DRAFT; parent runtime prerequisites remain open.

## 26. Objective

Introduce the first complete calculation layer on top of ELV1–ELV4.

ELV5 is deliberately not a generic formula engine. It registers stable, versioned calculation processes with typed inputs/results as specified by `docs/architecture/elv-calculation-processes.md`.

## 27. Shared calculation platform

Implement:

- calculation process registry;
- algorithm versioning;
- input/output contract versioning;
- dependency binding;
- immutable calculation run/result;
- project/reference snapshot identity;
- deterministic rounding/unit policy;
- structured calculation trace;
- finding generation;
- stale/current/blocked/failed state;
- affected-subgraph incremental recalculation.

## 28. ELV5 CCTV processes

Minimum vertical slice:

- `CCTV-01` camera coverage geometry;
- `CCTV-02` stream bandwidth;
- `CCTV-03` recording storage;
- `CCTV-04` PoE budget;
- `CCTV-05` recorder/VMS capacity;
- `CCTV-06` cable/link validation.

The first release may keep advanced analytics/DORI grading out of scope, but coverage geometry and bandwidth/storage must be reproducible and traceable.

## 29. ELV5 LAN processes

- `LAN-01` permanent-link/channel length;
- `LAN-02` switch port capacity;
- `LAN-03` PoE budget;
- `LAN-04` copper compatibility;
- `LAN-05` fiber loss budget;
- `LAN-06` rack utilization basis;
- `LAN-07` patch-panel utilization.

## 30. ELV5 ACS processes

- `ACS-01` door equipment completeness;
- `ACS-02` controller capacity;
- `ACS-03` lock power demand / voltage drop;
- `ACS-04` PSU sizing;
- `ACS-05` battery autonomy;
- `ACS-06` door topology validation.

## 31. ELV5 fire-alarm processes

- `FA-01` loop device/address capacity;
- `FA-02` standby/alarm loop current;
- `FA-03` loop electrical limits;
- `FA-04` PSU sizing;
- `FA-05` battery autonomy;
- `FA-06` notification circuit capacity;
- `FA-07` topology integrity;
- `FA-08` fire cable compliance basis.

Safety-critical fire processes must never silently substitute missing reference/normative inputs.

## 32. Calculation result contract

Every material result must store:

```text
processCode
algorithmVersion
inputSchemaVersion
outputSchemaVersion
projectRevision/reference snapshot
inputFingerprint
referenceProfileVersions[]
result state
calculated quantities
structured calculation steps
findings[]
calculatedAt
```

## 33. Dependency examples

```text
Camera bitrate
→ CCTV-02 bandwidth
→ CCTV-03 storage
→ CCTV-05 recorder capacity
```

```text
Cable route
→ ELV-ROUTE-01 length
→ ACS-03 voltage drop
→ ACS-04 PSU basis
→ ACS-05 autonomy
```

```text
Fire detector added
→ FA-01 loop capacity
→ FA-02 current
→ FA-04 PSU
→ FA-05 battery
```

## 34. ELV5 UI

Every discipline workspace gains a Calculations panel with:

- status per process;
- stale/blocking reason;
- result summary;
- findings;
- `How calculated` drill-down;
- exact profile/version provenance;
- recalculation command;
- comparison after input change.

## 35. ELV5 acceptance

ELV5 is complete when the same project can calculate:

- CCTV bandwidth + storage + PoE budget;
- LAN channel length + switch-port capacity;
- ACS door completeness + PSU/autonomy;
- fire loop capacity + standby/alarm current + battery autonomy;

and a single changed input invalidates only the relevant downstream processes.

---

# ELV6 — Cabinets, racks, patching and enclosure capacity/layout

## 36. Objective

Make ELV enclosures engineerable physical assemblies rather than simple containers.

ELV6 reuses the common enclosure foundation but introduces type-specific internal organization for network racks, ELV cabinets, ACS/fire cabinets and automation cabinets.

## 37. Scope

### 37.1 Common enclosure properties

- width/height/depth;
- wall/floor/rack mounting;
- usable internal zones;
- mounting rails/backplate;
- cable-entry zones;
- reserved/free zones;
- environmental/IP metadata;
- weight limit where known;
- power/thermal metadata where relevant.

### 37.2 Network rack

- rack units;
- front/rear placement;
- equipment depth;
- patch panels;
- fiber panels;
- switches;
- PoE switches;
- cable managers;
- PDU;
- UPS;
- reserved RU;
- patching map.

### 37.3 ELV/ACS/fire cabinet

- backplate/DIN rail zones;
- controller modules;
- PSU/charger;
- battery zones;
- terminal blocks;
- relay/I/O modules;
- cable ducts;
- service clearance;
- reserved capacity.

## 38. ELV6 domain contracts

```text
EnclosureAssembly
- enclosureDefinition
- mountingZones[]
- installedItems[]
- cableEntryPoints[]
- reservedZones[]
```

```text
RackMountingZone
- totalRu
- frontRearSide
- allowedDepth
```

```text
PatchPanelAssignment
- panelPort
- permanentLink
- switchPort?
- endpoint
```

## 39. ELV6 invariants

- installed products must physically fit the assigned zone;
- one mounting position cannot be occupied twice;
- rack-unit capacity and equipment depth are independent constraints;
- cabinet battery placement must use a battery-capable zone;
- patch-panel port assignments are unique;
- switch-port, patch-panel and endpoint mappings remain traceable;
- logical topology is not replaced by physical enclosure layout;
- moving equipment within a rack must not rewrite its network identity;
- selected product dimensions are snapshots used for fit validation.

## 40. ELV6 calculations/validators

- rack-unit utilization;
- patch-panel utilization;
- switch/controller channel utilization;
- free/reserved capacity;
- enclosure dimension conflicts;
- optional weight/power/thermal indicators when source data is available;
- battery fit;
- cable-entry congestion basis.

## 41. ELV6 UI

Two linked views:

1. `Logical` — ports/topology/connection map.
2. `Physical` — rack/cabinet front/layout view.

For a network rack, the engineer should navigate:

```text
Outlet
→ Permanent link
→ Patch panel port
→ Patch cord
→ Switch port
→ switch
→ uplink
```

while also seeing exact RU placement in the physical rack.

## 42. ELV6 acceptance

- 24-port patch panel + 24-port PoE switch + NVR + UPS fit a rack and expose RU/free capacity;
- two outlets map to unique patch-panel/switch ports;
- ACS cabinet contains controller + PSU + battery + terminals with capacity checks;
- fire cabinet exposes panel/PSU/battery/loop modules without losing fire topology identity;
- restart reconstructs identical physical layout and assignments.

---

# ELV7 — Versioned normative profiles and explainable validation

## 43. Objective

Convert the normative standards matrix into executable, jurisdiction-aware validation packages while preserving legal/engineering provenance.

ELV7 is where Electra begins to answer not only “does the graph work?” but “is this design compliant with the selected project profile?”

## 44. Normative architecture

```text
NormativeProfile
├── jurisdiction
├── version/edition
├── standard references[]
├── precedence rules
├── discipline bindings
├── executable rule packs[]
└── project overrides[] with rationale
```

Every executable rule must expose:

```text
ruleCode
ruleClass
standardReferenceId
clauseReference metadata
engineeringInterpretation
parameters/units
applicability predicate
severity
handler version
```

## 45. Initial profiles

Minimum supported profile architecture:

- `KZ-ELV-BASELINE`;
- `IEC-ISO-ELV-BASELINE`;
- extension capability for EU and North American profiles.

ELV7 must not claim complete jurisdictional compliance until the actual rule packs have verified source provenance.

## 46. Rule-pack scope

### Common routing/cabling

- separation/segregation;
- pathway fill;
- bend radius;
- support/installation method;
- penetration/firestop requirements where encoded;
- environment/IP constraints.

### LAN

- channel/permanent-link limits;
- copper/fiber class compatibility;
- administration/label completeness;
- test requirement profile.

### CCTV

- camera-placement requirements where verified;
- transmission/link requirements;
- recorder/system constraints tied to selected profile.

### ACS/security

- topology completeness;
- power/backup policies;
- monitored/emergency-release relationships where the selected profile requires them.

### Fire alarm

- loop topology constraints;
- device/address capacity;
- fire cable requirements;
- standby/alarm autonomy policy;
- notification circuit rules;
- mandatory safety-critical findings.

## 47. ELV7 findings

Every finding contains:

- severity;
- rule code;
- rule class/precedence;
- human-readable explanation;
- affected objects;
- measured/current value;
- allowed/required value;
- standard/profile version;
- remediation hint where possible;
- waiver/override state and rationale where legally permitted.

## 48. Profile lifecycle

- existing projects retain their original profile version;
- new profile editions do not silently migrate old projects;
- project profile upgrade runs impact analysis first;
- calculation/validation results tied to the old profile remain reproducible;
- superseded/withdrawn standards trigger visible status, not silent replacement;
- manufacturer rules may tighten but never weaken higher-precedence mandatory rules.

## 49. ELV7 UI

Normatives workspace:

- active jurisdiction/profile;
- standards/references;
- discipline rule packs;
- current findings grouped by system/object;
- `Why?` / source provenance;
- profile-upgrade impact preview;
- project override with mandatory reason and authorization state;
- filters: Error / Warning / Advisory / Passed.

## 50. ELV7 acceptance

A deliberately invalid project must produce explainable findings for at least:

- LAN link beyond allowed selected profile limit;
- route segregation violation;
- insufficient PoE/PSU/backup capacity;
- ACS incomplete door topology;
- fire loop/cable/autonomy violation.

Changing from one profile version to another must invalidate only dependent results and show an impact diff before migration.

---

# ELV8 — Equipment selection, BOM, schedules and engineering deliverables

## 51. Objective

Close the ELV vertical loop from engineering requirement to installable deliverable while preserving the separation between engineering truth and commercial products.

ELV8 consumes calculation results and normative requirements; it must not hide calculations inside manufacturer filtering.

## 52. Selection pipeline

```text
Canonical engineering requirement
        ↓
Calculated minimum/capacity requirement
        ↓
Normative constraints
        ↓
Manufacturer catalog compatibility
        ↓
Project manufacturer policy
        ↓
Ranked candidate products
        ↓
Engineer selection / confirmation
        ↓
Preserved technical snapshot
```

Selection states:

- `UNRESOLVED`;
- `CANDIDATES_AVAILABLE`;
- `SELECTED`;
- `USER_FORCED`;
- `STALE`;
- `REPLACEMENT_AVAILABLE`;
- `OBSOLETE`.

## 53. Product categories in ELV8

Support manufacturer mapping for at least:

- cameras;
- NVR/VMS appliances;
- switches/PoE switches;
- access points;
- patch panels/fiber panels;
- readers/controllers/locks;
- fire panels/detectors/modules;
- PSU/UPS/chargers/batteries;
- racks/cabinets;
- cables;
- trays/ducts/conduits where applicable.

Manufacturer selection must preserve canonical profile mapping and exact product technical snapshot.

## 54. BOM model

Every BOM line must drill down to project sources.

Required aggregation dimensions:

- project;
- building/floor;
- room/zone;
- engineering system;
- enclosure/rack;
- manufacturer/series;
- installation work package later.

BOM must distinguish:

- equipment;
- cable by type and calculated physical length;
- patch cords/accessories;
- trays/ducts/conduits;
- enclosures/racks;
- power/backup equipment;
- termination/patching components;
- reserves/spares where explicitly configured.

## 55. Engineering schedules

Minimum schedules:

- equipment schedule;
- port schedule;
- connection table;
- cable schedule;
- route schedule;
- switch-port schedule;
- patch-panel schedule;
- rack/cabinet equipment schedule;
- PSU/PoE budget schedule;
- battery/UPS autonomy schedule;
- fire loop/device schedule;
- ACS door/controller schedule;
- validation/findings report.

## 56. Drawings/deliverables

Generate from the same project model:

- floor engineering-system layouts;
- logical topology diagram;
- power topology diagram;
- route/cable drawing;
- rack elevation / cabinet layout;
- cable and port labels;
- equipment tags/QR references;
- BOM and schedules;
- calculation evidence;
- normative validation report.

PDF/export remains a presentation layer; exported numbers must come from canonical persisted/derived data.

## 57. ELV8 lifecycle behavior

- confirmed manufacturer product snapshot remains stable for the approved project revision;
- newer catalog version can propose a replacement but cannot silently rewrite selection;
- stale calculations mark dependent selections/BOM lines stale;
- BOM regeneration must expose changed quantities and source objects;
- manual product override requires reason if it falls outside preferred policy;
- a product that no longer satisfies engineering requirements must become invalid, not merely lower-ranked.

## 58. ELV8 acceptance — end-to-end project

### CCTV

```text
Camera
→ port
→ Cat6 connection/cable
→ routed CableRun
→ PoE switch in rack
→ UPS/power chain
→ bandwidth/storage/PoE calculations
→ normative validation
→ selected camera/switch/NVR/UPS
→ BOM + cable schedule + rack layout
```

### LAN

```text
Data outlet
→ permanent link
→ patch panel
→ switch port
→ route
→ link/port/rack calculations
→ validation
→ selected products
→ port/cable/BOM schedules
```

### ACS

```text
Door assembly
→ reader/lock/contact/exit device
→ controller I/O
→ power/backup topology
→ controller/PSU/autonomy calculations
→ validation
→ selected products
→ door/controller/cable/BOM schedules
```

### Fire alarm

```text
Fire panel
→ addressable loop
→ detector/modules/isolators
→ cable route
→ standby/alarm current
→ PSU/battery autonomy
→ topology/cable validation
→ selected products
→ loop/device/cable/BOM schedules
```

ELV8 is complete when all four scenarios produce coherent engineering deliverables from one canonical project model and no report requires a second hand-maintained data source.

---

# 59. Cross-stage persistence/versioning matrix

| Stage | Canonical persisted truth | Derived/versioned output |
|---|---|---|
| ELV2 | catalog/profile bindings, instantiated ports | compatibility/profile diagnostics |
| ELV3 | cable definitions, allocations, CableRuns, routes/channels | length/fill/route compatibility |
| ELV4 | power ports, converters, source/load graph, backup equipment | load/voltage/PoE/UPS/battery basis |
| ELV5 | calculation configuration/input bindings | calculation runs/results/traces |
| ELV6 | enclosure assemblies, placements, port/patch assignments | utilization/fit/capacity findings |
| ELV7 | normative profile/version/project overrides | validation findings and impact analysis |
| ELV8 | confirmed product selections/snapshots | BOM, schedules, reports/export models |

# 60. Cross-stage dependency graph

```text
Reference profile ELV2
        ↓
Component / Port / Connection ELV1
        ↓
Cable / Route ELV3
        ↓
Power topology ELV4
        ↓
Discipline calculations ELV5
        ↓
Enclosure/rack capacity ELV6
        ↓
Normative validation ELV7
        ↓
Manufacturer selection ELV8
        ↓
BOM / schedules / deliverables
```

Not every dependency is strictly linear. For example normative profiles affect ELV3–ELV6 calculations, but executable compliance gating is intentionally consolidated in ELV7 after the underlying physical and calculation models exist.

# 61. Required regression scenario matrix

Every stage from ELV2 onward must keep four fixtures alive:

| Scenario | Key proof |
|---|---|
| CCTV | IP/PoE + video topology + bandwidth/storage |
| LAN | permanent link + patching + switch/rack capacity |
| ACS | multi-port door assembly + controller I/O + DC backup |
| Fire | loop topology + safety-critical current/autonomy |

No stage is accepted if it only works for Ethernet/PoE.

# 62. Explicitly deferred after ELV8

The following remain future stages rather than hidden ELV2–ELV8 scope:

- Wi-Fi RF propagation/heatmaps;
- advanced CCTV pixel-density/DORI simulation beyond the selected baseline;
- packet-level network simulation;
- complete BMS logic programming;
- full intrusion-alarm engineering package;
- voice alarm/acoustic simulation;
- detailed cybersecurity threat modelling;
- online distributor pricing/availability;
- automatic procurement;
- automatic field commissioning;
- every national code/rule pack;
- complete vendor product libraries;
- manufacturer API synchronization;
- BIM/IFC authoring beyond interchange needed by Electra.

These capabilities may reuse the same ELV foundation without changing its canonical architecture.


## Implementation evidence and scope

ELV0 is closed: sixteen immutable family editions, project systems and non-owning participation of existing placed devices, additive SQLite v14 migration. Gate `707e18a`: 61 mobile and 103 core tests.

ELV1 adds persisted component ports, immutable compatibility/topology/assembly profile editions, binary external connections, passive internal mappings, topology groups and non-owning functional assemblies. SQLite schema 15 is additive. Planned wired connections do not create cables or routes. Template references record provenance; catalog instantiation is ELV2.

Four executable acceptance fixtures cover CCTV independent data/power tracing, LAN patch-panel continuity, ACS reader/lock connections and door membership, and a fire loop with separate source/return ports. Fixtures use explicitly fictional engineering profiles, not national normative defaults. Incomplete groups may be saved as drafts; incompatible connections and exceeded port capacity are blocked.

Retirement and hierarchy/device deletion guards prevent dangling topology. Detaching system membership with referenced ports is blocked. Restore keeps identity and creation time; profile editions cannot be modified in place. ELV1 edits preserve existing FL12 electrical fingerprints. Legacy circuits, CableRuns and generated panels retain their existing identity and persistence; ELV1 does not implicitly convert them to port connections. Physical cable/run adaptation belongs to ELV3 and enclosure integration to ELV6/FL16.

Verification includes restart, v14→v15 migration, project isolation, notifications, edition pinning, compact workspace and failed-write draft retention. ELV1 exact-head Flutter CI passed at `1ab81088ec7476d2b1cc262736cf05c8292be590`, run `38355779555`; merged to main through PR #5. Local core validation: 110 tests and analysis passed.

The current ELV2–ELV8 numbering follows the expanded specification above, replacing the earlier abbreviated implementation plan. FL16–FL20 continue alongside this track; enclosure, dependency and BOM infrastructure must be shared.

### ELV2 first implementation slice

Implementation branch: `feat/flutter-elv2-reference-catalogs`, following merged ELV0/ELV1 PR #5.

- Product-neutral component classes/capabilities and typed CCTV stream/power, LAN copper/speed/PoE, ACS electrical/lock/controller, and fire address/standby/alarm characteristics.
- Immutable project catalog snapshots and exact component-profile bindings. Every generated port records catalog/profile/template edition provenance. Catalog updates never replace project bindings.
- Atomic template instantiation into the existing ELV1 port table. Existing manually authored ports require explicit resolution; profile-owned characteristics cannot be silently edited. Retirement/release/rebinding is explicit and preserves old catalog editions.
- Catalog JSON import, discipline filtering, profile selection for existing placed equipment, provenance display and binding release. `docs/examples/elv2-reference-catalog.json` is a fictional five-profile acceptance example, not a vendor catalog or national rule pack.
- Additive schema 16, preservation of electrical/ELV1 data and legacy migration fixtures; four-discipline restart, edition immutability, project isolation and partial-write rollback tests.

This slice starts ELV2; it does not claim completion of every reference category in sections 5–11. The second slice below adds connector/protocol/media/voltage/interface catalogs and profile-derived connection compatibility. Environment/lens/coverage/PoE class catalogs, topology roles, reference upgrade impact preview and the editor creation palette remain subsequent ELV2 work. No normative engineering defaults or executable discipline calculations are introduced.

ELV2 first-slice implementation gate `ecd96a5b3a0e5bf703d733c238fa066696e55a5f`: run `38357683735` passed Drift generation, both analyzers and formatting, **66 mobile + 113 core tests**. Follow-up exact-head checks also cover explicit edition adoption with retained port IDs. PR #6 remains draft because the full ELV2 catalog scope is still open.


### ELV2 reference vocabulary and compatibility slice

The same implementation branch now adds immutable typed connector, protocol, signal-medium, voltage-domain, interface and ordered compatibility definitions. All entries belong to the root catalog edition and retain its source. Component port templates select interface codes; instantiated ELV1 ports freeze their resolved technical values plus exact interface, protocol and template provenance. Display labels never drive compatibility.

Catalog import materializes declared compatibility pairs in the existing ELV1 compatibility table in the same transaction as the catalog snapshot. A failure in any generated profile rolls back the entire import. Connections require the ordered interface editions as well as connector/protocol, family, medium, layer, direction and electrical-domain checks. Equal connectors do not imply compatible protocols; protocol conversion requires an explicit future converter model. Missing voltage stays unresolved. Deprecated definitions remain readable in old snapshots but cannot instantiate new ports or generate new compatibility choices.

`docs/examples/elv2-interface-catalog.json` is an importable fictional ten-component example covering PoE camera/switch, LAN outlet/patch/switch, ACS controller/reader/lock and fire controller/detector source/return. Quantities are illustrative. Import through the existing reference workspace, assign placed components to discipline systems, then bind the chosen component profiles. Passive patch and detector continuation mappings are explicitly authored ELV1 records; this slice does not infer internal links from a label or component class.

The reference workspace displays definitions and declared compatible pairs. Persisted catalog/port/profile JSON is extended additively; schema stays at 16, and legacy snapshots without vocabulary serialize unchanged. Tests cover four-discipline traces and SQLite restart, atomic failed import, idempotent legacy reimport, exact-edition mismatch rejection, explicit adoption guards, deprecation, malformed cross-references and compact UI.

Local validation for this slice: core analysis and **123 tests** pass. Flutter persistence/widget tests, generation, formatting and both analyzers are gated by the exact PR-head CI run. The full ELV2 stage remains open for the remaining section 5 reference categories, richer discipline profiles, topology-role derivation, upgrade impact review and editor creation palette. ELV3 has not started.
