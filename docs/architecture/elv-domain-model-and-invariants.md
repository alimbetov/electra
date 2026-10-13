# Electra — ELV Domain Model and Invariants

Status: Draft 0.1  
Branch: `docs/elv-engineering-systems-spec`  
Scope: canonical domain model for engineering systems before implementation

## 1. Purpose

This document defines the semantic boundaries and invariants of the common Electra engineering-system model.

The canonical conceptual chain is:

`EngineeringSystem → Component → Port → Connection → Cable → CableRun → Route → Enclosure`

This is **not an ownership chain**. It is a navigation path across several aggregates. Physical objects, logical topology, cable realization, routing, and containment have different lifecycles and must not be collapsed into one aggregate.

The design goal is to support electrical power, CCTV, LAN, access control, fire alarm, BMS, automation, and future disciplines without creating discipline-specific copies of geometry, routing, cable, catalog, or enclosure infrastructure.

---

## 2. Canonical domain map

```text
Project
│
├── EngineeringSystem
│    ├── SystemMembership ───────────────┐
│    └── topology / normative profile   │
│                                       │
├── EngineeringComponent ◄──────────────┘
│    ├── Placement
│    ├── Capability[]
│    ├── Port[]
│    ├── CatalogSnapshot
│    └── optional EnclosureMembership
│
├── Connection
│    ├── endpoint A -> Port
│    ├── endpoint B -> Port
│    ├── connection semantics
│    └── CableAllocation[]
│
├── Cable
│    ├── physical construction
│    ├── cores / pairs / fibers
│    └── CableRun
│
├── CableRun
│    ├── ordered RouteSegment traversal
│    ├── slack / service reserve
│    └── calculated installed length
│
├── Route
│    ├── RouteNode[]
│    ├── RouteSegment[]
│    └── capacity / routing class
│
└── Enclosure
     ├── physical EngineeringComponent identity
     ├── slots / RU / DIN / free volume model
     └── contained EngineeringComponent[]
```

A second orthogonal graph exists for dependencies:

```text
change -> affected topology -> affected cable realization -> affected route occupancy
      -> affected power/capacity calculations -> validation findings -> reports
```

---

## 3. Aggregate boundaries

### 3.1 Project

`Project` is the consistency boundary for identifiers, geometry references, engineering systems, and design revision context.

Project responsibilities:

- ensure all referenced objects belong to the same project;
- define active design/revision context;
- hold project-level normative profiles and units;
- coordinate cross-aggregate validation;
- never contain all engineering entities as one transactional object graph.

### 3.2 EngineeringComponent aggregate

Aggregate root: `EngineeringComponent`.

Owned value/entities:

- persisted `Port` instances;
- placement reference/value;
- capability assignments;
- catalog snapshot/reference metadata;
- local physical/electrical characteristics.

A component does **not** own connections, systems, cables, or routes.

Reason: deleting/replacing a component requires explicit handling of dependent topology instead of hidden cascade deletion.

### 3.3 Connection aggregate

Aggregate root: `Connection`.

Responsibilities:

- express one logical/electrical adjacency between two explicit ports;
- carry connection semantics and engineering-system context;
- validate endpoint compatibility;
- reference physical realization through cable allocations when wired.

Connection does not own ports or cables.

### 3.4 Cable aggregate

Aggregate root: `Cable`.

Responsibilities:

- represent installed physical cable identity;
- expose usable resources: conductors, pairs, fibers, screen, PE, etc.;
- retain product/type snapshot needed for deterministic calculations;
- own at most one active `CableRun` realization per design revision.

A cable may realize more than one logical connection when separate pairs/cores/fibers are allocated explicitly.

### 3.5 Route aggregate

Aggregate root: `Route`.

Responsibilities:

- represent reusable physical routing infrastructure/path topology;
- own route nodes and route segments;
- track usable capacity and routing classifications;
- provide deterministic ordered paths between route attachment points.

A route does not own cables. Many cable runs may occupy the same route segments.

### 3.6 Enclosure aggregate

`Enclosure` is a specialized containment model attached to a physical `EngineeringComponent`.

Examples:

- electrical panel;
- network rack;
- ELV cabinet;
- fire alarm cabinet;
- automation cabinet;
- junction box.

This avoids a parallel physical-object hierarchy. A rack is still an engineering component with geometry, catalog identity, capabilities, and possibly ports; the enclosure aspect adds containment rules.

---

## 4. EngineeringSystem

### Definition

An `EngineeringSystem` is a project-scoped engineering discipline/network instance, not a physical container.

Examples:

- `CCTV-01`;
- `LAN-OFFICE-01`;
- `ACS-01`;
- `FA-01`;
- `POWER-UPS-01`.

### Responsibilities

- identify discipline/family;
- select topology rules;
- select normative profile;
- select visualization/routing profile;
- classify connections and participating components;
- provide system-specific validation context.

### Membership decision

Direct `component.systemId` is prohibited as the universal model because a component can participate in multiple systems.

Use explicit `SystemMembership`:

```text
SystemMembership
- engineeringSystemId
- participantType: COMPONENT | CONNECTION | ENCLOSURE
- participantId
- role
- primary: boolean
- metadata/profile overrides
```

A connection should normally have one owning/primary engineering system. Components may have zero to many memberships.

### Invariants

- system code is unique inside a project;
- system family is stable after connections exist unless migration succeeds;
- system deletion is blocked while active memberships/connections exist, unless an explicit detach/migration operation is used;
- every system-specific validation finding must identify the system and rule profile version.

---

## 5. EngineeringComponent

### Definition

A physical or logical technical device that can be placed, connected, contained, powered, or used as infrastructure.

### Responsibilities

- stable project identity;
- placement;
- catalog/manufacturer identity;
- capabilities;
- instantiated ports;
- physical dimensions and mounting constraints where relevant;
- engineering parameters not owned by a connection or route.

### Important decision: physical object is singular

A device participating in several systems is represented once.

Example PoE switch:

```text
SW-01
memberships:
- LAN-01 / NETWORK_SWITCH
- CCTV-01 / TRANSPORT
- POWER-UPS-01 / POWER_CONSUMER
```

It must not be cloned into three components.

### Invariants

- component belongs to exactly one project;
- component identity survives movement and system-membership changes;
- component deletion is blocked if active connections terminate on its ports unless the delete command explicitly resolves them;
- catalog replacement may not silently rewrite already-instantiated ports;
- a capability required by an active connection cannot be removed while that connection depends on it;
- placement must satisfy host geometry/mounting constraints when the component is physical;
- a component cannot contain itself directly or indirectly through enclosure membership.

---

## 6. Port

### Definition

A persisted connection endpoint owned by one component.

Ports are **instances**, not live references to catalog templates.

A catalog product may provide `PortTemplate`s. When a component is created or its product is applied, templates are instantiated and persisted. Later catalog edits must not mutate existing project topology unexpectedly.

### Minimum semantics

```text
Port
- id
- componentId
- code
- kind
- direction
- interface/connector
- protocol/profile
- voltage domain
- power limits
- channel/capacity
- state
- template provenance
```

### Port kinds

Initial semantic kinds:

- POWER;
- DATA;
- SIGNAL;
- BUS;
- DATA_POWER;
- AUDIO;
- VIDEO;
- FIBER;
- RF;
- CONTACT.

These are semantic classes, not vendor protocol names.

### Invariants

- port belongs to exactly one component;
- port code is unique within its component;
- connection endpoints always reference ports, never components directly;
- occupied capacity cannot exceed port capacity;
- direction must be compatible with connection semantics;
- electrical voltage/current/power constraints must be compatible when applicable;
- interface and protocol rules are validated independently: connector compatibility alone is insufficient;
- a port used by an active connection cannot be deleted; it may be retired/deprecated after migration;
- multi-channel ports expose explicit capacity or child channels; hidden unlimited fan-out is prohibited.

---

## 7. Connection

### Definition

A semantic adjacency between exactly two ports.

### Strong invariant: binary edge

A `Connection` has exactly two endpoints.

Multi-drop, bus, radial, star, tree, loop, and ring topologies are composed from binary edges. Junctions, terminals, patch panels, controllers, splitters, and boxes are explicit components/ports where physical branching occurs.

This avoids ambiguous hyperedges and keeps tracing, fault localization, cable allocation, and graph algorithms deterministic.

### Connection semantics

Examples:

- POWER_FEED;
- DATA_LINK;
- SIGNAL_LINK;
- BUS_LINK;
- LOOP_SEGMENT;
- CONTROL_LINK;
- DRY_CONTACT;
- FIBER_LINK;
- RF_COAX_LINK;
- COMBINED_DATA_POWER.

### Wired versus non-wired

`Connection` is not synonymous with cable.

A connection may be:

- wired and physically realized by cable resources;
- wireless;
- logical/virtual where explicitly supported.

### Invariants

- endpoints are distinct ports;
- both endpoints belong to the same project;
- endpoint compatibility must pass connection-type rules;
- primary engineering system is mandatory for system-specific connections;
- duplicate connections between the same exclusive ports are prohibited unless the port explicitly allows multiple channels;
- wired connection must have a complete physical realization before installation/BOM status can be `COMPLETE`;
- wireless/logical connections must not create phantom cables;
- connection deletion releases cable-resource allocations but does not automatically delete shared cable or route infrastructure.

---

## 8. Cable and cable-resource allocation

### Definition

A `Cable` is one installed physical cable, not a logical circuit.

Examples:

- Cat6 U/UTP;
- 2x1.5 mm² fire-resistant cable;
- 4-core access-control cable;
- 12-fiber optical cable.

### Why Cable cannot be 1:1 with Connection

One cable may carry multiple independent resources:

- different copper pairs;
- different cores;
- multiple fibers;
- spare resources.

Therefore introduce an explicit allocation concept:

```text
CableAllocation
- connectionId
- cableId
- resource ids/range
- endpoint termination mapping
```

### Invariants

- cable belongs to exactly one project;
- allocated resources may not overlap unless the cable technology explicitly permits shared use;
- allocation must be compatible with cable construction and connection semantics;
- cable product/type characteristics are versioned/snapshotted sufficiently for reproducible calculations;
- cable may exist as planned/unallocated stock only if lifecycle status permits it;
- an installed wired connection cannot be marked complete without required resource allocations;
- changing cable type triggers validation of all allocations and recalculation of dependent values.

---

## 9. CableRun

### Definition

`CableRun` is the installed geometric realization of one physical cable through routing infrastructure.

It answers: **where does this cable physically go?**

It does not answer what the cable electrically means; that belongs to Connection/CableAllocation.

### Canonical structure

```text
CableRun
- cableId
- start attachment
- ordered traversals[]
- end attachment
- service loop / slack data
- installedLength
- routing status
```

Each traversal references a route segment and direction.

### Invariants

- one cable has at most one active complete cable run per design revision;
- traversals form a continuous ordered path;
- the run endpoints must resolve to the cable termination vicinity/attachment points;
- no route segment may be used if its routing class prohibits the cable/system;
- occupancy is calculated from physical cable characteristics, not from connection count;
- installed length includes configured slack/service loops and endpoint allowances;
- rerouting changes CableRun, not Connection identity;
- changing topology endpoints invalidates affected run completeness and triggers rerouting requirements.

---

## 10. Route

### Definition

A `Route` is reusable routing infrastructure/topology: tray, conduit, duct, wall/ceiling path, shaft, riser, penetration chain, or a composed engineering route.

`Route` is infrastructure. `CableRun` is usage of that infrastructure by a cable.

### Canonical structure

```text
Route
├── RouteNode
│    ├── junction
│    ├── transition
│    ├── penetration
│    ├── surface attachment
│    └── riser point
└── RouteSegment
     ├── geometry
     ├── carrier type
     ├── capacity
     ├── routing classes
     └── normative attributes
```

### Invariants

- route segments form a valid graph;
- each segment references valid project geometry;
- segment capacity cannot become negative;
- occupancy comes from active cable runs;
- shared routing between disciplines is allowed only when routing/normative rules permit it;
- removing a used route segment is blocked unless affected cable runs are rerouted or invalidated explicitly;
- surface transitions and penetrations are explicit route nodes, not implicit coordinate jumps;
- route geometry may be edited without changing connection identities.

---

## 11. Enclosure

### Definition

An `Enclosure` adds containment semantics to an engineering component.

Examples differ in capacity models:

- rack: rack units, depth, weight, power/thermal limits;
- electrical panel: DIN modules, rows, busbars, zones;
- ELV cabinet: mounting areas, DIN, backplate, volume;
- junction box: volume, terminals, ingress constraints;
- fire cabinet: certified slots/modules, batteries, PSU areas.

### Containment model

```text
EngineeringComponent (physical identity)
└── EnclosureAspect
    ├── capacity model
    ├── Slot/Position[]
    └── EnclosureMembership[]
         └── containedComponentId
```

### Invariants

- enclosure and contained component belong to the same project;
- containment graph is acyclic;
- a component has at most one physical parent enclosure at a time unless a future explicit multi-mount model is introduced;
- capacity constraints must be satisfied by the active layout;
- contained components retain their own ports and connections;
- enclosure membership does not imply engineering-system membership;
- moving a component between enclosures must not recreate its identity or connections;
- enclosure deletion is blocked while it contains active components unless an explicit relocation/delete operation is used.

---

## 12. Separation of five concerns

The following five concepts must never be conflated:

| Concern | Canonical entity | Question answered |
|---|---|---|
| discipline | EngineeringSystem | Which engineering network/rules apply? |
| device | EngineeringComponent | What physical/logical equipment exists? |
| topology | Connection | What ports communicate/feed each other? |
| physical medium | Cable + CableAllocation | What installed medium realizes the connection? |
| geometry | CableRun + Route | Where is the cable physically installed? |

`Enclosure` is orthogonal containment infrastructure.

This separation is the central architectural invariant of the ELV model.

---

## 13. Lifecycle rules

### Component replacement

Replacing a failed/catalog device should support two operations:

1. **retarget product/specification on same engineering identity** when ports remain compatible;
2. **replace component identity** with an explicit migration mapping when topology changes.

Silent recreation of ports is prohibited.

### Catalog updates

Catalog changes affect future component creation by default.

Existing project components retain instantiated/snapshotted engineering data until the user explicitly applies an upgrade/migration.

### Connection editing

Changing one endpoint:

- revalidates port compatibility;
- revalidates cable allocation;
- invalidates routing if physical endpoints move/topology changes;
- triggers affected calculations only.

### Route editing

Changing geometry:

- preserves Connection and Cable identity;
- recalculates run length and occupancy;
- revalidates routing/normative constraints;
- triggers voltage-drop/power calculations when length matters.

---

## 14. Dependency and recalculation boundaries

Expected dependency direction:

```text
CatalogSnapshot / Component parameter
        ↓
Port compatibility / load demand
        ↓
Connection
        ↓
CableAllocation + Cable properties
        ↓
CableRun
        ↓
Route occupancy / installed length
        ↓
Power, voltage-drop, PoE, capacity calculations
        ↓
Validation findings
        ↓
Schedules / BOM / reports
```

The dependency engine should invalidate by affected IDs/keys, not recalculate the entire project by default.

---

## 15. Traceability requirements

Electra must answer these queries deterministically:

- Which systems does component `X` participate in?
- Which ports of `X` are occupied and by what?
- Trace from device port to upstream/downstream equipment.
- Which cable resources realize this connection?
- Where is that cable routed?
- Which route segments contain this cable?
- Which enclosure contains this device?
- Which connections/cables become invalid if component/port/route segment is changed?
- Which system/rule produced a validation finding?

If the model cannot answer any of these without discipline-specific special cases, the model is incomplete.

---

## 16. Canonical deletion policy

Default behavior should be restrictive and explicit:

- deleting a system with active memberships: BLOCK;
- deleting a connected component: BLOCK;
- deleting an occupied port: BLOCK;
- deleting a connection: ALLOW and release its cable allocations;
- deleting an allocated cable: BLOCK;
- deleting a routed cable: BLOCK until run/allocation resolved;
- deleting a used route segment: BLOCK;
- deleting a non-empty enclosure: BLOCK.

Bulk/user-assisted commands may orchestrate safe detach, reroute, migrate, or cascade operations, but repository-level accidental cascade delete must not be the domain default.

---

## 17. Versioning and reproducibility

Calculations and reports must remain reproducible after reference/catalog changes.

Therefore project entities must retain sufficient provenance:

- catalog product/version or engineering snapshot;
- normative profile/version;
- rule code/version;
- calculation algorithm/version where relevant;
- route/cable design revision.

The implementation may optimize storage later, but semantic reproducibility is mandatory.

---

## 18. Architecture decisions fixed by this draft

Unless contradicted by later scenario validation, the following decisions are now the preferred baseline:

1. `EngineeringSystem` membership is many-to-many through `SystemMembership`; no universal `component.systemId`.
2. Physical component identity is singular across disciplines.
3. Ports are persisted instances created from optional catalog templates.
4. Connections terminate only on ports.
5. A connection is a binary graph edge; branches use explicit devices/nodes/ports.
6. Connection and Cable are not 1:1; cable resources are assigned through `CableAllocation`.
7. Cable and CableRun are separate; rerouting does not recreate cable/topology identity.
8. Route is reusable infrastructure shared by multiple CableRuns.
9. Enclosure is a containment aspect of an EngineeringComponent, not a separate competing physical-object hierarchy.
10. Destructive operations are explicit and dependency-aware, not implicit cascades.
11. Catalog and normative changes do not silently mutate existing project topology.

---

## 19. Questions intentionally left for scenario validation

The following must be tested against CCTV, LAN, access control, and fire alarm before becoming final ADRs:

- whether binary Connection is sufficient for every terminal/junction topology without awkward synthetic components;
- whether `CableAllocation` needs conductor-level endpoint/terminal mapping in the first release;
- whether fire-alarm loop identity requires an additional `Network/Loop` aggregate above connections;
- whether structured cabling needs a first-class permanent-link/channel aggregate separate from generic Connection;
- whether access-control door assemblies require a composite/assembly domain concept;
- whether enclosure slot models should share one generic capacity API or remain strategy-specific;
- exact representation of wireless links and virtual logical associations;
- whether a cable may have multiple physical run sections separated by intermediate termination components or whether that must always be multiple Cable identities.

These questions are resolved next through concrete discipline scenarios rather than abstract modeling alone.
