# ELV5 — Equipment Demand Contract

Status: normative additive design contract  
Branch: `feat/flutter-elv5-power-topology-design`  
Hardening: [Equipment Demand Projection Hardening v1](../product/elv5-implementation/equipment-demand-projection-hardening-v1.md)

## 1. Purpose

ELV5 SHALL describe **what the engineered system requires** without selecting a manufacturer, product family or SKU.

This contract is the upstream boundary for the future Electra equipment catalog and autoconfiguration engine.

> ELV5 produces engineering demand. ELV8 resolves that demand to concrete products.

ELV5 MUST remain deterministic and vendor-neutral.

### Integration rule

`EquipmentDemand` is a derived projection over existing ELV5 engineering evidence. It is **not** a 28th ELV5 calculation process and does not change the fixed 27-process inventory or the fixed 16-operation ELV5 public command surface.

ELV4 remains owner of shared physical power topology, source/circuit/load identity and physical electrical truth. ELV5 consumes that evidence in discipline context and projects downstream requirements; it MUST NOT create a parallel physical power model for generator, UPS, PV, battery, inverter, ESS or ATS support.

## 2. Ownership

ELV5 owns:

- electrical and ELV load requirements;
- topology role and connectivity requirements;
- source/supply requirements derived from owned discipline calculations and accepted upstream evidence;
- protection requirements;
- interface and port requirements;
- redundancy and reserve requirements;
- environmental and service requirements known from topology;
- traceability from calculated demand to the source circuit/load/node and governing evaluations.

ELV5 MUST NOT own:

- manufacturer preference resolution;
- price/stock/lead-time data;
- concrete SKU selection;
- enclosure placement;
- jurisdiction-specific compliance verdicts;
- BOM finalization;
- duplicate ELV4 source/circuit/load/power topology entities.

## 3. Canonical demand model

```dart
final class EquipmentDemand {
  final DemandKey key;
  final String projectId;
  final String projectRevisionId;
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

All values MUST use typed quantities and canonical units. Free-form strings MUST NOT carry calculation semantics.

`DemandKey` SHALL be stable for the same engineering role inside a project revision. Random UI IDs SHALL NOT define semantic demand identity.

## 4. Protection demand

For protective devices ELV5 SHALL be able to express, where applicable:

- AC/DC system;
- phase count and pole requirement;
- nominal/system voltage;
- design current;
- required continuous current envelope;
- minimum breaking capacity derived from accepted project evidence;
- protection function (`MCB`, `MCCB`, `RCD`, `RCBO`, fuse, SPD, relay, etc.);
- trip/curve requirement when engineering logic determines it;
- residual-current type/sensitivity requirement when applicable;
- selectivity/cascade relationship requirement;
- upstream/downstream topology references;
- source type and operating mode;
- reserve policy.

A requirement is a constraint, not a product hint.

## 5. External and alternative sources

The demand contract SHALL support source-neutral engineering requirements for:

- utility/grid supply;
- generator;
- UPS;
- battery/DC source;
- photovoltaic source;
- inverter;
- energy storage system;
- automatic transfer source;
- hybrid source;
- future source types through extensible capability codes.

Source behavior SHALL be represented as engineering capabilities and operating modes rather than hard-coded vendor types.

Minimum source semantics, where applicable:

```text
sourceKind
nominalVoltage
frequencyRange
phaseModel
availableFaultCurrent / fault-current model reference
continuousPower
peakPower
islandedOperation
parallelOperation
transferMode
backupDurationRequirement
powerQualityCapabilities
governingOperatingCase
```

These are downstream requirements/evidence references, not replacement ELV4 physical topology.

## 6. Capability requirements

Matching SHALL be capability-based.

Example:

```text
EquipmentDemand
  equipmentClass = PROTECTIVE_DEVICE
  requiredCapabilities = {
    OVERCURRENT_PROTECTION,
    TWO_POLE_SWITCHING,
    DIN_RAIL_MOUNTABLE
  }
```

ELV5 MUST NOT encode `Schneider`, `ABB`, `Hager` or a catalog number as an engineering requirement.

## 7. Provenance

Every demand SHALL carry enough evidence to answer why it exists.

Minimum provenance:

- originating entity ID;
- project revision ID;
- originating ELV5 process code(s);
- evaluation ID(s);
- algorithm/calculation version(s);
- input fingerprint(s);
- governing operating case;
- assumptions;
- projection schema version.

Wall-clock refresh time may be metadata but MUST NOT affect semantic identity/hash.

## 8. Composition, unknowns and conflicts

Several ELV5 calculations MAY contribute to one demand. The projection layer SHALL compose them deterministically rather than emit accidental duplicates.

Rules:

1. compatible requirements merge by the stricter engineering constraint;
2. independent capabilities form a deterministic union;
3. reserve/derating is applied exactly once by its owning calculation/policy layer;
4. contradictory mandatory requirements produce a stable blocking diagnostic;
5. missing mandatory evidence fails closed and MUST NOT be replaced with a guessed default;
6. downstream code MUST NOT rerun discipline formulas to resolve a projection conflict.

Canonical diagnostic families include:

```text
DEMAND_INPUT_UNKNOWN
DEMAND_EVIDENCE_STALE
DEMAND_CONFLICTING_REQUIREMENTS
DEMAND_UNSUPPORTED_OPERATING_CASE
DEMAND_NO_GOVERNING_RESULT
```

## 9. Change and invalidation semantics

A demand SHALL have semantic equality independent of transient UI state.

If calculation-relevant fields or governing evidence change, affected downstream candidate evaluations and resolved configurations MUST be invalidated.

Price/stock/supplier changes MUST NOT invalidate ELV5 engineering calculations or change an ELV5 demand semantic hash.

Invalidation SHALL remain dependency-scoped: unrelated project demands must not become stale without a real dependency edge.

## 10. Projection boundary

Conceptual application API:

```dart
final class EquipmentDemandProjection {
  final String projectId;
  final String projectRevisionId;
  final String projectionSchemaVersion;
  final String engineeringFingerprint;
  final List<EquipmentDemand> demands;
  final List<DemandDiagnostic> diagnostics;
}

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

Repository-aware capture belongs to the application resolver/orchestration layer. The builder SHOULD remain pure where practical, consistent with the ELV5 pure-core/application boundary.

ELV8 SHALL consume this boundary. It MUST NOT reach into ELV5 persistence tables to infer requirements.

There SHALL be no authoritative CRUD API for individual demand fields: demand is derived engineering state. User edits must modify the owning project/profile/policy input and trigger recalculation/reprojection.

## 11. Persistence rule

Do not materialize a new database model by default.

Initial implementation MAY derive the projection from immutable/current ELV5 evaluation evidence. Dedicated persistence is justified only by measured replay, offline, query-latency, incremental-index or freeze/export requirements.

Any persisted projection SHALL be additive, versioned through the normal Drift migration authority and bound to one project revision. It MUST NOT mix evidence from incompatible revisions.

## 12. Acceptance criteria

ELV5 is ready for catalog/autoconfiguration integration when:

1. fixed ELV5 process inventory remains exactly 27 and demand projection is not registered as a process;
2. fixed public command inventory remains exactly 16 unless a future explicit authority amendment changes it;
3. every equipment-selection need is emitted as typed vendor-neutral demand;
4. no demand contains vendor/SKU/price/supplier fields;
5. protection demands contain enough information to filter technically valid protective devices;
6. generator/UPS/PV/inverter/storage/ATS/hybrid source requirements can be represented without duplicating ELV4 topology or redesigning the schema;
7. every demand is traceable to originating project entity, project revision and governing calculation evidence;
8. semantically unchanged recalculation produces the same canonical payload/hash;
9. multiple process outputs can compose one demand without duplicate reserve application;
10. missing mandatory evidence fails closed;
11. contradictory mandatory requirements produce a deterministic blocking diagnostic;
12. engineering changes invalidate only affected demand closure;
13. commercial-only changes do not alter ELV5 calculations or demand hash;
14. frozen revisions reproduce equivalent demand projections for the same projection schema;
15. ELV6 cannot infer physical fit from demand alone;
16. ELV7 cannot infer verified jurisdictional compliance from ELV5 technical findings alone;
17. ELV8 cannot rewrite historical ELV5 calculation truth while selecting products;
18. qualification includes positive, boundary, missing-evidence, conflicting-evidence and cross-discipline composition fixtures, including utility, generator, UPS and hybrid-source cases.
