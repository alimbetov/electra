# ELV5 — Equipment Demand Contract

Status: normative design contract  
Branch: `feat/flutter-elv5-power-topology-design`

## 1. Purpose

ELV5 SHALL describe **what the engineered system requires** without selecting a manufacturer, product family or SKU.

This contract is the upstream boundary for the future Electra equipment catalog and autoconfiguration engine.

> ELV5 produces engineering demand. ELV8 resolves that demand to concrete products.

ELV5 MUST remain deterministic and vendor-neutral.

## 2. Ownership

ELV5 owns:

- electrical and ELV load requirements;
- topology role and connectivity requirements;
- source/supply requirements;
- protection requirements;
- interface and port requirements;
- redundancy and reserve requirements;
- environmental and service requirements known from topology;
- traceability from calculated demand to the source circuit/load/node.

ELV5 MUST NOT own:

- manufacturer preference resolution;
- price/stock/lead-time data;
- concrete SKU selection;
- enclosure placement;
- jurisdiction-specific compliance verdicts;
- BOM finalization.

## 3. Canonical demand model

```dart
final class EquipmentDemand {
  final String id;
  final String projectId;
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
}
```

All values MUST use typed quantities and canonical units. Free-form strings MUST NOT carry calculation semantics.

## 4. Protection demand

For protective devices ELV5 SHALL be able to express, where applicable:

- AC/DC system;
- phase count and pole requirement;
- nominal/system voltage;
- design current;
- required continuous current envelope;
- minimum breaking capacity derived from the project model;
- protection function (`MCB`, `MCCB`, `RCD`, `RCBO`, fuse, SPD, relay, etc.);
- trip/curve requirement when engineering logic determines it;
- residual-current type/sensitivity requirement when applicable;
- selectivity/cascade relationship requirement;
- upstream/downstream topology references;
- source type and operating mode;
- reserve policy.

A requirement is a constraint, not a product hint.

## 5. External and alternative sources

The demand contract SHALL support source-neutral topology for:

- utility/grid supply;
- generator;
- UPS;
- battery/DC source;
- photovoltaic source;
- inverter;
- energy storage system;
- automatic transfer source;
- future source types through extensible capability codes.

Source behavior SHALL be represented as engineering capabilities and operating modes rather than hard-coded vendor types.

Minimum source semantics:

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
```

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

Every demand SHALL carry:

- originating entity ID;
- calculation/process ID;
- calculation revision;
- input snapshot/hash where available;
- assumptions;
- timestamp/revision metadata.

This enables ELV8 to explain why a product was selected and to deterministically re-resolve after project changes.

## 8. Change and invalidation semantics

A demand SHALL have semantic equality independent of transient UI state.

If calculation-relevant fields change, downstream candidate evaluations and resolved configurations MUST be invalidated.

Price/stock changes MUST NOT invalidate ELV5 engineering calculations.

## 9. Required API boundary

Conceptual application API:

```dart
abstract interface class EquipmentDemandRepository {
  Future<List<EquipmentDemand>> listForProject(String projectId);
  Future<List<EquipmentDemand>> listForEntity(String entityId);
}

abstract interface class EquipmentDemandProjectionService {
  Future<EquipmentDemandProjection> rebuild(String projectId);
}
```

ELV8 SHALL consume this boundary. It MUST NOT reach into ELV5 persistence tables to infer requirements.

## 10. Acceptance criteria

ELV5 is ready for catalog/autoconfiguration integration when:

1. every equipment-selection need is emitted as a typed `EquipmentDemand`;
2. no demand contains vendor/SKU/price fields;
3. protection demands contain enough information to filter technically valid protective devices;
4. generator/UPS/PV/inverter/storage sources can be represented without schema redesign;
5. every demand is traceable to its originating project entity and calculation revision;
6. semantically unchanged recalculation produces the same demand payload/hash;
7. downstream invalidation is triggered only by engineering-relevant changes;
8. ELV5 tests include deterministic fixtures for utility, generator, UPS and hybrid-source topologies.
