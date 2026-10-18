# Electra — Modular Panel Hierarchy & Floor Distribution Target

Status: **TARGET / NORTH STAR / NOT IMPLEMENTATION / NOT ACCEPTANCE**

Parent target: `electra-professional-electrical-platform-target.md`

Related: CAP-02, CAP-04, CAP-05, CAP-06, CAP-07, CAP-08, CAP-13, CAP-17, CAP-18, CAP-19, ELV6, ELV8, K0, K2, K3, K4, K6 and the 2D Panel & Cabinet Editor.

## 1. Purpose

Electra shall support a building as a hierarchy of electrical distribution assemblies rather than one flat switchboard list.

Typical target topology:

```text
GRID / TRANSFORMER / GENERATOR
              ↓
         MDB / MAIN BOARD
          ├── FLOOR DB-01
          │      ├── LIGHTING
          │      ├── SOCKETS
          │      ├── HVAC LOADS
          │      └── LOCAL AUTOMATION
          ├── FLOOR DB-02
          │      ├── LIGHTING
          │      ├── SOCKETS
          │      └── LOCAL AUTOMATION
          ├── MCC
          └── DB-ELV
```

The hierarchy must be electrically real: each child panel is supplied by an explicit parent feeder/circuit/path. A folder/tree relation alone is not sufficient.

---

## 2. Distribution scopes

A panel may own an engineering scope such as:

```text
BUILDING
FLOOR
ZONE
ROOM
SYSTEM
MACHINE
TENANT
PROCESS
CUSTOM
```

Representative model:

```text
PanelAssembly
- id
- code
- scopeType
- scopeRef?
- distributionLevel
- parentPanelId?
- incomingSupplyRef
- revision
```

`distributionLevel` is an explicit ordering aid, not a replacement for topology traversal.

Example:

```text
L0  MDB-01
L1  FDB-01, FDB-02, MCC-01, DB-ELV
L2  AP-F01, DB-LIGHT-F01, DB-SOCK-F01
L3  machine/local panels where required
```

---

## 3. Parent-child supply is an electrical feeder

A child panel MUST be connected through a canonical feeder path:

```text
Parent bus
  ↓
Parent protective device
  ↓
Feeder circuit
  ↓
Cable / busduct
  ↓
Child incomer
  ↓
Child bus
```

Representative relation:

```text
PanelFeederLink
- parentPanelId
- parentOutgoingDeviceId
- feederCircuitId
- feederPathRef
- childPanelId
- childIncomingDeviceId?
- sourceModeRef?
```

This relation must be derivable from canonical topology; it must not become a second independent topology database.

---

## 4. Bottom-up load roll-up

Electra shall calculate upstream panel demand from downstream accepted facts.

```text
Loads
  ↓
Local circuits
  ↓
Floor/zone panel demand
  ↓
Feeder demand
  ↓
Main board demand
  ↓
Source demand
```

The roll-up must distinguish:

- connected load;
- demand load;
- diversity/simultaneity;
- operating scenario;
- phase allocation;
- critical/emergency load subset;
- normal versus alternate-source demand.

### 4.1 No double diversity

A diversity factor applied at one aggregation boundary must not be silently applied again upstream.

Each aggregation result shall preserve provenance:

```text
LoadAggregationResult
- scopeRef
- inputSetFingerprint
- connectedPower
- demandPower
- phaseTotals
- diversityPolicyRef
- scenarioRef
- governingCase
- resultVersion
```

---

## 5. Modular/repeated floor design

Repeated floors shall be able to reuse a versioned panel template without cloning untraceable free-form data.

Representative target:

```text
PanelModuleTemplate
- templateId
- version
- panelClass
- namingPolicy
- defaultSections[]
- defaultReservePolicy
- defaultDeviceRequirements[]
- defaultTerminalStrategy
- defaultCableEntryStrategy
- companyRuleProfileRef?

PanelModuleInstance
- templateRef
- projectId
- scopeRef
- instanceCode
- parameterBindings
- localOverrides[]
- revision
```

Examples:

```text
TEMPLATE: STANDARD_FLOOR_DB_V3
  ↓
FDB-01
FDB-02
FDB-03
FDB-04
```

A template update creates a candidate change set for instances. It MUST NOT silently rewrite accepted/frozen panels.

---

## 6. Top-down constraints

Main-board/source constraints can flow downstream as design constraints:

- maximum feeder rating;
- source capacity;
- available short-circuit level;
- permitted voltage-drop budget;
- emergency/normal source assignment;
- phase policy;
- reserve policy;
- cable/pathway constraints;
- company/normative rules.

Therefore synthesis requires two directions:

```text
BOTTOM-UP
loads → local panel → feeder demand → main board/source

TOP-DOWN
source/main-board limits → feeder constraints → local panel constraints
```

K0 may iterate until a deterministic feasible set is found or explicit blockers are returned.

---

## 7. K0 hierarchical synthesis

K0 shall eventually support hierarchical synthesis, not only one isolated board.

Target orchestration:

```text
1. group loads by floor/zone/function/criticality
2. propose local panels
3. synthesize each local panel
4. derive feeder requirements
5. aggregate upstream demand
6. synthesize MDB/main distribution
7. validate source capacity and fault/protection chain
8. propagate upstream constraints back to affected local candidates
9. produce a consistent candidate hierarchy
```

Required candidate result:

```text
PanelHierarchyCandidate
- hierarchyRoot
- panelCandidates[]
- feederCandidates[]
- sourceLoading
- objectiveVector
- blockers[]
- synthesisTrace
```

The result is a candidate until the engineer reviews/accepts it.

---

## 8. 2D editor integration

The 2D Panel & Cabinet Editor shall include a hierarchy navigator.

Example:

```text
PROJECT
└── MDB-01
    ├── FDB-01
    │   ├── AP-F01
    │   └── DB-LIGHT-F01
    ├── FDB-02
    │   ├── AP-F02
    │   └── DB-LIGHT-F02
    ├── MCC-01
    └── DB-ELV
```

Selecting a node opens the same canonical panel in the 2D editor.

The editor may provide:

- parent feeder breadcrumb;
- upstream/downstream navigation;
- current panel load/reserve summary;
- child-panel feeder summary;
- source path trace;
- compare repeated floor instances;
- template versus local-override visualization.

No navigation tree node exists without a valid project object; the tree is a projection, not canonical topology.

---

## 9. Feeder and riser coordination

Floor panels commonly share vertical distribution routes. Electra shall support coordination with canonical cable/busduct/riser/pathway facts.

Typical building flow:

```text
MDB
 ↓
vertical riser / busduct / feeder cables
 ├── FDB-01
 ├── FDB-02
 ├── FDB-03
 └── FDB-04
```

Required checks where modeled:

- feeder ampacity;
- voltage drop;
- short-circuit min/max at each downstream panel;
- breaking capacity;
- protection trip/selectivity;
- riser/pathway capacity;
- phase loading;
- fire/segregation constraints via applicable normative layer;
- cable/busduct identification and labeling.

---

## 10. Normal, emergency and alternate supply hierarchy

A child panel may have one or more explicitly modeled source paths when the topology supports them.

Examples:

```text
MDB-NORMAL → FDB-01
MDB-EMERGENCY → ATS-F01 → FDB-CRITICAL-F01
```

or:

```text
GRID
  ↓
MDB
  ↓
ATS
 ├── normal path
 └── generator path
  ↓
CRITICAL FLOOR DB
```

The hierarchy must distinguish:

- physical parent relation;
- active source path in a scenario;
- alternate source path;
- tie/bus-coupler state;
- maintenance/isolation state.

A tree UI must not simplify a multi-source electrical graph into false single-parent electrical truth. The hierarchy view may show a primary ownership parent while topology remains a graph.

---

## 11. Protection and fault propagation

A hierarchical panel structure shall support end-to-end protection analysis:

```text
SOURCE
 ↓
MDB INCOMER
 ↓
MDB OUTGOING QF
 ↓
FDB INCOMER
 ↓
FDB OUTGOING QF
 ↓
LOAD
```

Fault studies and K3 Failure X-Ray can traverse this chain to determine:

- available fault current by level;
- expected protection response;
- upstream/downstream outage scope;
- selectivity status where qualified;
- critical functions lost;
- alternate supply availability.

---

## 12. Revision and template semantics

- every panel instance belongs to a project revision;
- frozen panel instances are immutable;
- template versions are immutable;
- changing a template produces proposed instance diffs;
- local overrides remain explicit and traceable;
- changing a child-panel demand invalidates affected feeder and upstream roll-up results;
- changing an upstream source/protection constraint invalidates dependent child-panel checks;
- create-next materialization preserves exact hierarchy and template provenance.

---

## 13. Deliverables

The hierarchy shall drive consistent project outputs:

- main distribution schedule;
- per-floor panel schedules;
- feeder schedule;
- cable/busduct schedule;
- panel hierarchy/riser diagram;
- SLD pages or hierarchy navigation;
- 2D panel layouts for every cabinet;
- terminal plans;
- labels/QR;
- BOM grouped by building/floor/panel/system;
- load summary by level;
- commissioning checklist by panel.

---

## 14. Initial P0 scope

First professional implementation should support:

```text
MDB / MAIN BOARD
      ↓
FLOOR / ZONE PANELS
      ↓
OUTGOING CIRCUITS / LOADS
```

with:

- explicit parent feeder;
- bottom-up load roll-up;
- phase totals;
- reserve/capacity status;
- voltage-drop and fault/protection chain;
- hierarchy navigator;
- per-panel 2D layout;
- deterministic schedules.

### P1

- reusable floor-panel templates;
- template diff/update workflow;
- emergency/normal dual-path visualization;
- building riser visualization;
- multi-panel K0 synthesis.

### P2

- advanced bus-tie/reconfigurable distribution;
- complex redundant 2N/N+1 board hierarchies;
- optimization across multiple panel locations and feeder routes.

---

## 15. Core invariant

> **A building is not one giant switchboard and not a flat list of cabinets. Electra models a hierarchy of modular distribution assemblies linked by real electrical feeders, while preserving the underlying topology as a graph.**

This allows a practical workflow from repeated floor boards to the main board without losing electrical truth, revision provenance or constructible 2D layouts.