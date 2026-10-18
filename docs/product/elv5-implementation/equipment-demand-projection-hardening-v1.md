# ELV5 — Equipment Demand Projection Hardening v1

Status: **NORMATIVE ADDITIVE DESIGN CONTRACT / NO NEW ELV5 PROCESS**  
Branch: `feat/flutter-elv5-power-topology-design`

## 1. Decision

ELV5 SHALL expose a vendor-neutral equipment-demand projection for ELV6/ELV7/ELV8, but this projection SHALL NOT become a 28th calculation process, a second power-topology model, a second revision model or a new public command family.

The existing ELV5 authority remains:

```text
ELV3/ELV4 source facts
        ↓
application InputResolver
        ↓
27 typed ELV5 calculations
        ↓
immutable calculation evaluations/findings
        ↓
EquipmentDemandProjectionBuilder
        ↓
EquipmentDemandProjection
        ↓
ELV6 / ELV7 / ELV8
```

The projection is derived engineering state. It translates accepted/current ELV5 engineering evidence into downstream requirements without selecting products.

## 2. Non-negotiable boundaries

### ELV4 remains owner of common physical power truth

ELV5 MAY consume source, circuit, load, battery and power evidence from ELV4. ELV5 MUST NOT redefine physical source/circuit identity, physical power flow, revision lifecycle or accepted ELV4 calculations.

Generator, UPS, battery, PV, inverter, ESS and ATS support in ELV5 means that discipline calculations and demand projection understand their capabilities and operating cases. It does not create parallel power-topology entities when ELV4 already owns them.

### ELV5 owns engineering demand, not product selection

ELV5 SHALL express constraints such as:

- required electrical envelope;
- protection function;
- source/supply operating requirement;
- interface and media requirement;
- capacity and reserve requirement;
- redundancy/availability requirement;
- environmental requirement known from engineering context;
- required quantity or capacity;
- traceability to governing calculations.

ELV5 MUST NOT express:

- manufacturer preference;
- manufacturer part number or SKU;
- price, supplier or stock;
- final cabinet/rack placement;
- jurisdictional compliance verdict;
- final BOM identity.

### ELV6 / ELV7 / ELV8 authority remains separate

- ELV6 proves physical fit, placement, service/clearance and constructability.
- ELV7 owns verified normative qualification and jurisdictional applicability.
- ELV8 resolves valid demands against catalog candidates, compatibility, commercial policy and deliverables.

No downstream stage may rewrite historical ELV5 evaluation truth.

## 3. Projection is not a calculation process

The fixed ELV5 process inventory remains exactly 27.

`EquipmentDemandProjectionBuilder` SHALL be an application/domain projection component over process outputs and upstream evidence. It SHALL NOT be registered in the calculation process registry and SHALL NOT have a new process code.

The fixed ELV5 public command surface remains exactly 16 operations unless a future authority amendment explicitly changes it. Demand projection MUST be refreshed as part of existing guarded publication/rebuild flows, not by inventing an independent command protocol.

## 4. Canonical projection model

Conceptual model:

```dart
final class EquipmentDemandProjection {
  final String projectId;
  final String projectRevisionId;
  final String projectionSchemaVersion;
  final String engineeringFingerprint;
  final List<EquipmentDemand> demands;
  final List<DemandDiagnostic> diagnostics;
}

final class EquipmentDemand {
  final DemandKey key;
  final String sourceEntityId;
  final EquipmentClassCode equipmentClass;
  final Set<CapabilityRequirement> requiredCapabilities;
  final ElectricalRequirement? electrical;
  final ProtectionRequirement? protection;
  final ConnectivityRequirement? connectivity;
  final ReliabilityRequirement? reliability;
  final EnvironmentRequirement? environment;
  final QuantityRequirement quantity;
  final DemandProvenance provenance;
  final String semanticHash;
}

final class DemandKey {
  final String sourceEntityId;
  final String roleCode;
  final String ordinalOrSlot;
}
```

`DemandKey` identifies the engineering role stably within one project revision. Random UI-generated IDs MUST NOT define semantic identity.

## 5. Determinism and hashing

Two executions over the same frozen engineering evidence MUST produce the same canonical demand payload and `semanticHash`.

The semantic hash SHALL include engineering-significant values only, including:

- equipment class;
- required capabilities;
- electrical/protection/connectivity/reliability/environment requirements;
- quantity/capacity requirement;
- governing source entity and calculation evidence references;
- projection schema version.

It SHALL exclude:

- UI selection state;
- wall-clock refresh timestamp;
- list insertion order when order is not semantic;
- price and inventory observations;
- transient cache identifiers.

Collections used in hashing SHALL have deterministic canonical ordering.

## 6. Evidence and unknown semantics

Every demand MUST identify why it exists.

Minimum provenance:

```text
sourceEntityId
projectRevisionId
originatingProcessCodes[]
evaluationIds[]
algorithmVersions[]
inputFingerprints[]
governingOperatingCase
assumptions[]
```

Missing mandatory engineering evidence MUST fail closed. The projection MUST NOT silently fabricate defaults to make a catalog candidate selectable.

When a requirement cannot be established safely, the projection SHALL emit a stable diagnostic such as:

```text
DEMAND_INPUT_UNKNOWN
DEMAND_EVIDENCE_STALE
DEMAND_CONFLICTING_REQUIREMENTS
DEMAND_UNSUPPORTED_OPERATING_CASE
DEMAND_NO_GOVERNING_RESULT
```

A downstream system may display or explain such a demand, but it MUST NOT treat incomplete mandatory evidence as technically satisfied.

## 7. Demand composition

Several ELV5 calculations may contribute to one equipment demand. The projection builder SHALL compose them deterministically rather than emit accidental duplicates.

Example:

```text
CCTV-02 bandwidth
CCTV-04 PoE budget
LAN-02 port capacity
LAN-03 PoE budget
        ↓
NETWORK_SWITCH demand
```

Composition rules:

1. compatible requirements merge by the stricter engineering constraint;
2. independent capabilities form a deterministic union;
3. contradictory mandatory requirements produce a blocking diagnostic;
4. reserve factors are applied exactly once at their owning calculation/policy layer;
5. a downstream projection MUST NOT re-run discipline formulas to resolve a conflict.

## 8. Discipline projection matrix

The following matrix is the minimum intent; it does not add process codes.

### CCTV

- CCTV-01 may contribute camera/lens/coverage capability requirements where equipment selection depends on them.
- CCTV-02 contributes network throughput/interface demand.
- CCTV-03 contributes recorder/storage usable/raw capacity and retention demand.
- CCTV-04 contributes PoE source/switch power demand.
- CCTV-05 contributes recorder/VMS channel, codec, ingress and storage capability demand.
- CCTV-06 contributes media/interface/link compatibility requirements.

### LAN

- LAN-01 contributes media/path class constraints, not physical route ownership.
- LAN-02 contributes switch port/media/speed/reserve demand.
- LAN-03 contributes PoE capability/power demand.
- LAN-04 contributes copper category/shielding/connector compatibility demand.
- LAN-05 contributes optical transceiver/fiber budget capability requirements.
- LAN-06 contributes rack-capacity basis only; ELV6 still owns physical rack fit.
- LAN-07 contributes patch-panel port/capacity demand.

### ACS

- ACS-01 contributes required door-role components/capabilities.
- ACS-02 contributes controller I/O/channel capacity demand.
- ACS-03 contributes lock/source electrical envelope and voltage-drop-related requirements.
- ACS-04 contributes PSU/source capacity demand.
- ACS-05 contributes battery/autonomy capacity demand.
- ACS-06 contributes required interface/topology capability relationships.

### Fire alarm

- FA processes contribute panel/loop/device/source/battery/notification/interface capacity requirements only when backed by their governing technical calculation evidence.
- Safety-critical unknown or unsupported cases remain blocking/indeterminate; catalog selection MUST NOT turn them into PASS.

## 9. Alternative and hybrid source handling

ELV5 SHALL be source-kind aware without embedding vendor products.

Supported engineering source roles include at minimum:

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

Source requirements SHALL be expressed using typed capabilities and operating cases such as:

- nominal voltage/frequency/phase model;
- continuous and peak demand;
- fault-current evidence reference where relevant;
- transfer/islanding/parallel-operation capability;
- autonomy/backup requirement;
- power-quality capability;
- governing normal/emergency/alarm operating case.

A new source technology SHOULD normally enter through capability/profile extension. A schema redesign is justified only when the engineering semantics cannot be represented by the existing typed model.

## 10. Freshness and invalidation

Demand projection freshness depends only on engineering inputs and governing evidence.

Engineering changes SHALL invalidate affected demands, for example:

```text
camera count
  -> CCTV bandwidth/PoE/storage changes
  -> affected network/recorder/power demands stale
  -> downstream ELV6/ELV7/ELV8 evaluations stale
```

Commercial changes such as price, availability or supplier lead time MUST NOT invalidate ELV5 calculations or demand semantic hashes.

Invalidation SHALL be selector-aware and scoped. A change to one door, camera group or loop MUST NOT force unrelated project demands to change when dependencies do not intersect.

## 11. Publication semantics

Projection publication SHALL follow the existing ELV5 guarded-publication discipline:

1. capture one coherent project/revision evidence basis;
2. resolve affected current ELV5 evaluations;
3. build the projection deterministically;
4. validate no mandatory evidence is stale/mixed-revision;
5. compute canonical hashes;
6. atomically publish the current projection pointer/snapshot where persisted;
7. retain frozen/historical revision evidence unchanged.

The projection MUST NOT mix evaluations from incompatible project revisions.

## 12. Persistence decision

Do not add persistence merely because a projection type exists.

Initial implementation MAY derive `EquipmentDemandProjection` from existing immutable ELV5 evaluations if performance and replay requirements are met.

Persist a dedicated projection only when one of these is demonstrated:

- downstream query latency requires it;
- offline ELV8 consumption requires a stable snapshot;
- incremental invalidation needs a materialized reverse index;
- project freeze/export requires explicit snapshot identity.

If persistence is added, it SHALL be additive to the accepted Drift schema and versioned through the normal migration authority. No ad-hoc table may bypass schema/version registries.

## 13. Minimal API boundary

Keep the first implementation small:

```dart
abstract interface class EquipmentDemandProjectionReader {
  Future<EquipmentDemandProjection> readCurrent(String projectId);
  Future<EquipmentDemandProjection> readRevision(
    String projectId,
    String projectRevisionId,
  );
}

abstract interface class EquipmentDemandProjectionBuilder {
  EquipmentDemandProjection build(EquipmentDemandBuildInput input);
}
```

The builder SHOULD remain pure where practical. Repository access belongs to the application resolver/orchestration layer, consistent with ADR-031.

Do not create CRUD for individual demands. A demand is derived engineering state, not user-authored catalog data.

## 14. UI rule

UI MAY show:

- demand origin;
- required capabilities;
- governing calculation;
- margins/reserves;
- stale/unknown/conflict diagnostics;
- downstream selection state.

UI MUST NOT mutate calculated demand fields directly. User changes SHALL modify an owning project/profile/policy input and trigger deterministic recalculation/projection rebuild.

## 15. Acceptance gates

The integration is ready when all are true:

1. process inventory remains exactly 27;
2. command operation inventory remains exactly 16;
3. ELV4 remains sole owner of shared physical power topology;
4. every downstream equipment-selection need is representable as typed vendor-neutral demand;
5. each demand has stable semantic identity and deterministic hash;
6. one demand can compose evidence from multiple processes without duplicate reserve application;
7. conflicting mandatory requirements fail closed with stable diagnostics;
8. unknown mandatory evidence cannot become a technically valid candidate downstream;
9. generator/UPS/PV/inverter/ESS/ATS/hybrid operating cases require no vendor-specific schema;
10. ELV6 cannot infer fit PASS from demand alone;
11. ELV7 cannot infer jurisdictional compliance from ELV5 technical findings alone;
12. ELV8 cannot rewrite ELV5 calculations while resolving a product;
13. commercial-only changes do not change ELV5 demand hash;
14. project engineering changes invalidate only affected demand closure;
15. frozen project revisions reproduce byte/canonical-equivalent demand projections under the same projection schema;
16. no individual-demand CRUD is exposed as authoritative user input;
17. qualification includes positive, boundary, missing-evidence, conflicting-evidence and cross-discipline composition cases;
18. downstream handoff records the projection schema/version alongside accepted ELV5 runtime evidence.

## 16. Implementation order

Use the smallest sequence that proves the architecture:

```text
D0  freeze projection types + semantic hash rules
D1  map 27 process outputs to demand roles
D2  implement pure projection builder
D3  add cross-process composition/conflict diagnostics
D4  add targeted invalidation/freshness integration
D5  expose read-only downstream reader
D6  qualify utility + generator + UPS + hybrid source fixtures
D7  materialize/persist only if measured downstream needs justify it
```

This order deliberately avoids premature catalog persistence, microservices, generic rule engines and extra command protocols.
