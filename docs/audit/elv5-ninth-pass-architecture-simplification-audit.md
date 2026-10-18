# ELV5 — Ninth-pass architecture and simplification audit

Status: **ACTIONED / OPEN IMPLEMENTATION EVIDENCE REMAINS**  
Branch: `feat/flutter-elv5-power-topology-design`

## 1. Objective

Audit ELV5 as an implementation-grade engineering stage after the initial Equipment Demand contract was introduced.

The goal is not to add frameworks. The goal is to preserve the hardened 27-process design while making ELV5 a clean upstream provider for ELV6/ELV7/ELV8 and future autoconfiguration.

Audit principle:

> Add a concept only when it removes ambiguity, prevents an unsafe inference, enables deterministic replay or creates a required downstream contract.

## 2. Current strengths retained

The audit deliberately preserves:

- exactly 27 discipline processes;
- exactly 16 public ELV5 command operations;
- pure `engineering_core` calculation boundary;
- application-owned resolver/repository access;
- immutable calculation evidence and canonical hashing;
- explicit UNKNOWN/BLOCKED/fail-closed behavior;
- selector-aware dependency invalidation;
- schema-24 migration authority;
- ELV4 ownership of shared physical power truth;
- ELV6 physical-fit ownership;
- ELV7 verified normative-compliance ownership;
- ELV8 catalog/selection/BOM ownership;
- evidence-backed lifecycle rather than document-label lifecycle.

No new generic formula engine, rules engine, event bus, microservice split or arbitrary JSON component model is introduced by this pass.

## 3. Findings and resolutions

### ELV5-R9-01 — EquipmentDemand was not bound to the fixed process/runtime architecture

Severity: HIGH  
State: RESOLVED IN DESIGN

Risk:

A developer could interpret `EquipmentDemand` as:

- a 28th process;
- a new command family;
- mutable user-authored data;
- a second equipment/project database;
- a place to repeat ELV4 electrical calculations.

Resolution:

`EquipmentDemand` is now defined as a derived projection over immutable/current ELV5 and accepted upstream evidence. The fixed 27 process codes and 16 public operations remain unchanged.

Authority:

- `docs/architecture/elv5-equipment-demand-contract.md`
- `docs/product/elv5-implementation/equipment-demand-projection-hardening-v1.md`

### ELV5-R9-02 — Alternative-energy support could accidentally duplicate ELV4 topology

Severity: HIGH  
State: RESOLVED IN DESIGN

Risk:

Adding generator/PV/UPS/battery/ESS/ATS fields directly into ELV5 domain ownership would create two physical power models and inconsistent source identity.

Resolution:

ELV4 remains owner of physical source/circuit/load/power topology and physical electrical truth. ELV5 becomes source-kind/operating-case aware only through accepted upstream evidence plus typed discipline requirements.

External source support is capability-based:

```text
UTILITY
GENERATOR
UPS
BATTERY_DC
PV
INVERTER
ESS
ATS
HYBRID_SOURCE
```

This list is a role vocabulary, not a parallel hierarchy of physical source entities.

### ELV5-R9-03 — Demand identity and invalidation were underspecified

Severity: HIGH  
State: RESOLVED IN DESIGN

Risk:

Random IDs or timestamps could make identical calculations produce different downstream configurations or invalidate the whole project after trivial UI/commercial changes.

Resolution:

Demand identity is semantic:

```text
DemandKey = sourceEntityId + roleCode + ordinalOrSlot
```

`semanticHash` includes engineering-significant requirement/evidence fields and excludes UI state, refresh time, cache identity, price and stock.

Invalidation follows real dependency closure only.

### ELV5-R9-04 — Cross-process demand composition could double-count reserve or emit duplicates

Severity: HIGH  
State: RESOLVED IN DESIGN

Example risk:

CCTV-04 and LAN-03 may both describe the same shared PSE engineering context. A naive projection could add power reserve twice or emit two competing switch demands.

Resolution:

Projection composition rules are explicit:

1. merge compatible constraints by the stricter requirement;
2. union independent capabilities;
3. apply reserve/derating exactly once at its owning calculation/policy layer;
4. surface contradictory mandatory requirements as blocking diagnostics;
5. never rerun discipline formulas inside projection conflict resolution.

### ELV5-R9-05 — Missing evidence could be hidden by catalog selection

Severity: HIGH  
State: RESOLVED IN DESIGN

Risk:

A broad ELV8 product could appear to satisfy an incomplete ELV5 requirement and produce a false engineering success.

Resolution:

Mandatory unknown/stale/conflicting evidence fails closed before candidate selection.

Stable diagnostic families introduced:

```text
DEMAND_INPUT_UNKNOWN
DEMAND_EVIDENCE_STALE
DEMAND_CONFLICTING_REQUIREMENTS
DEMAND_UNSUPPORTED_OPERATING_CASE
DEMAND_NO_GOVERNING_RESULT
```

ELV8 may explain these diagnostics but cannot convert them into technical PASS.

### ELV5-R9-06 — Persistence was at risk of premature expansion

Severity: MEDIUM  
State: RESOLVED IN DESIGN

Risk:

Creating tables for every demand/capability before proving query/offline/replay needs would expand schema and migration cost without adding engineering value.

Resolution:

First implementation derives demand projection from current immutable ELV5 evidence. Materialization is optional and justified only by measured latency, offline snapshot, incremental reverse-index or freeze/export requirements.

If materialized, it is additive and versioned through normal Drift migration authority.

### ELV5-R9-07 — Mutable demand CRUD would break engineering provenance

Severity: HIGH  
State: RESOLVED IN DESIGN

Risk:

Editing a calculated requirement directly would disconnect the value from the process/policy that owns it.

Resolution:

No authoritative CRUD for individual demands. User action changes the owning project/profile/policy input and triggers recalculation/reprojection.

### ELV5-R9-08 — Runtime documentation status is internally inconsistent

Severity: MEDIUM  
State: OPEN DOCUMENT RECONCILIATION

Observed:

- authoritative index says runtime implementation is in progress and foundation adoption started;
- implementation index and several package documents still state runtime not started;
- branch source already exports ELV5 process implementations and contains process/foundation tests.

Required correction:

Use evidence-backed lifecycle per process/layer:

```text
DESIGNED
KERNEL_IMPLEMENTED
RUNTIME_INTEGRATED
QUALIFIED
ACCEPTED
```

Do not mass-promote all processes merely because source files exist. Do not report implemented kernels as NOT_STARTED either.

A generated status projection SHOULD derive current lifecycle from source/test/runtime evidence rather than hand-maintained prose labels.

### ELV5-R9-09 — Downstream handoff vocabulary is too generic for autoconfiguration

Severity: MEDIUM  
State: DESIGN RESOLUTION DEFINED / MACHINE REGISTRY UPDATE PENDING

Current handoff already states ELV8 consumes engineered technical requirements, but the exact projection identity is not yet machine-bound.

Required downstream reconciliation fields:

```text
equipmentDemandProjectionSchemaVersion
engineeringFingerprint
projectRevisionId
demandSemanticHashes[]
sourceEvaluationIds[]
```

The existing accepted-source-SHA and authority-fingerprint gates remain mandatory.

### ELV5-R9-10 — Need to avoid one universal generic component schema in ELV5

Severity: MEDIUM  
State: RESOLVED IN DESIGN

ELV5 is not the product catalog. It should define compact typed requirement families only where engineering semantics justify them:

```text
ElectricalRequirement
ProtectionRequirement
ConnectivityRequirement
ReliabilityRequirement
EnvironmentRequirement
QuantityRequirement
CapabilityRequirement
```

Manufacturer-specific attributes and commercial data belong downstream in ELV8.

## 4. 27-process projection responsibility

All 27 processes remain calculation authority. Their downstream role falls into one of three simple categories:

```text
DIRECT_CONTRIBUTOR
  emits one or more concrete requirement dimensions

COMPOSITE_CONTRIBUTOR
  contributes evidence to a demand composed with other processes/upstream facts

BASIS_ONLY
  supplies technical basis/provenance but cannot itself establish downstream fit/compliance/selection
```

No fourth generic plugin model is required.

### CCTV

| Process | Projection responsibility |
|---|---|
| CCTV-01 | camera/coverage-related capability basis where selection depends on calculated geometry |
| CCTV-02 | network throughput/recorder ingress requirements |
| CCTV-03 | usable/raw storage and retention claim requirements |
| CCTV-04 | shared PSE/PoE demand contribution; no duplicate global power budget |
| CCTV-05 | recorder/VMS channel/codec/ingress/storage capabilities |
| CCTV-06 | media/link/interface requirements and technical path basis |

### LAN

| Process | Projection responsibility |
|---|---|
| LAN-01 | installed-link/channel requirement basis |
| LAN-02 | switch port/media/speed/reserve requirements |
| LAN-03 | shared PoE/PSE demand contribution |
| LAN-04 | copper category/shielding/connector compatibility requirements |
| LAN-05 | optical link/transceiver budget requirements |
| LAN-06 | rack capacity basis only; physical fit stays ELV6 |
| LAN-07 | patch-panel port/capacity requirements |

### ACS

| Process | Projection responsibility |
|---|---|
| ACS-01 | required door equipment roles/capabilities |
| ACS-02 | controller reader/relay/input capacity requirements |
| ACS-03 | lock/source electrical envelope and terminal-voltage basis |
| ACS-04 | source/PSU requirement composition |
| ACS-05 | battery/autonomy requirement composition |
| ACS-06 | topology/interface relationship capabilities |

### Fire

| Process | Projection responsibility |
|---|---|
| FA-01 | panel/loop/address resource capacity requirements |
| FA-02 | standby/alarm/startup current requirement basis |
| FA-03 | supported terminal-voltage/electrical envelope basis |
| FA-04 | shared fire source/PSU requirement composition |
| FA-05 | standby/alarm backup sequence and battery/autonomy requirements |
| FA-06 | notification output count/current/terminal requirements |
| FA-07 | signal topology/interface capability basis |
| FA-08 | cable/environment technical project-policy basis only; never verified compliance |

## 5. Minimal implementation architecture

Keep implementation narrow:

```text
Existing InputResolver
       ↓
Existing 27 kernels/evaluations
       ↓
EquipmentDemandProjectionBuilder   ← new pure component
       ↓
EquipmentDemandProjectionReader    ← thin read boundary
       ↓
ELV6 / ELV7 / ELV8
```

Not required for v1:

- separate backend service;
- message broker;
- generic workflow engine;
- generic scripting DSL;
- graph database;
- one table per requirement subtype;
- mutable demand editor;
- duplicate calculation scheduler;
- new ELV5 command protocol.

## 6. Implementation sequence

### R9-D0 — status truth

Reconcile documentation/runtime status from actual source and qualification evidence. Do not claim acceptance.

### R9-D1 — projection contracts

Implement immutable Dart types:

- `DemandKey`;
- `EquipmentDemand`;
- typed requirement families;
- `DemandProvenance`;
- `DemandDiagnostic`;
- `EquipmentDemandProjection`.

### R9-D2 — deterministic builder

Implement pure `EquipmentDemandProjectionBuilder` with canonical ordering/hashing and explicit conflict handling.

### R9-D3 — 27-process mapping

Bind all 27 process outputs/evidence to projection roles. Assert exact inventory coverage in tests.

### R9-D4 — invalidation

Integrate projection fingerprint with existing selector-aware dependency closure; prove unrelated edits are negative controls.

### R9-D5 — downstream read boundary

Expose read-only current/revision projection access. No direct ELV8 table reads.

### R9-D6 — qualification

Minimum new qualification families:

1. deterministic same-input/same-hash;
2. cross-process composition;
3. duplicate-reserve prevention;
4. missing mandatory evidence fail-closed;
5. contradictory evidence diagnostic;
6. revision isolation;
7. unrelated-edit negative control;
8. utility source;
9. generator source;
10. UPS source;
11. hybrid source;
12. commercial-only changes do not affect ELV5 projection.

### R9-D7 — persistence only if justified

Materialize projection after evidence shows a need. Until then, avoid schema churn.

## 7. Exit criteria for this hardening pass

Design closure requires:

- EquipmentDemand is unambiguously a derived projection;
- no new process/command ownership is introduced;
- ELV4/ELV6/ELV7/ELV8 boundaries remain explicit;
- all 27 ELV5 processes have a documented downstream projection responsibility;
- unknown/conflict behavior fails closed;
- stable identity/hash/invalidation rules exist;
- external/hybrid energy sources fit through capability/operating-case semantics;
- implementation path is small enough to build/test incrementally;
- runtime status drift is tracked as an explicit reconciliation item rather than hidden.

## 8. Verdict

ELV5 does not need a larger architecture. It needs a cleaner contract between its already strong calculation/evidence foundation and downstream configuration.

The selected design is therefore:

> **27 deterministic engineering processes + one derived, read-only, vendor-neutral demand projection.**

This is sufficient to support future autoconfiguration without turning ELV5 into a catalog, rules platform or duplicate power-topology subsystem.
