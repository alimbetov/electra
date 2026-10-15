import 'engineering_hash.dart';
import 'power_definition_ref.dart';
import 'power_numeric.dart';
import 'power_profiles.dart';

const powerRootCatalogSchemaV1 = 'electra.elv4-power-catalog.v1';
const powerDefinitionsSchemaV1 = 'electra.elv4-power-definitions.v1';

enum PowerCatalogPortKind { power, dataPower }
enum PowerCatalogDirection { input, output, bidirectional }
enum PowerCatalogCapability {
  source,
  consumer,
  converter,
  store,
  charger,
  distributor,
  pse,
  pd,
}
enum PowerSupplyOrigin { externalDeclared, localTransfer, notSource }
enum PowerCatalogTransferKind {
  acDc,
  dcDc,
  transformer,
  ups,
  charger,
  distributor,
  poePse,
  selector,
}
enum BatteryCapacityModel { explicitFlatVoltageWh, constantCurrentAh }
enum PowerPolicyPurpose { supplyReserve, backupSequence, peak }
enum PowerExtensionPolicy { none, continueLast, repeatSequence }
enum PowerCompatibilityLayer { power, dataPower }
enum PowerCompatibilityFlow { directed, bidirectional }

final class PowerConnectorDefinition {
  PowerConnectorDefinition({
    required String code,
    required this.contactCount,
    required String sourceRef,
  })  : code = _code(code),
        sourceRef = _text(sourceRef, 'sourceRef') {
    if (contactCount < 1) throw ArgumentError('contactCount must be positive.');
  }
  final String code;
  final int contactCount;
  final String sourceRef;
  Map<String, Object?> toMap() => {
        'code': code,
        'contactCount': contactCount,
        'sourceRef': sourceRef,
      };
  factory PowerConnectorDefinition.fromMap(Map<String, Object?> map) {
    _keys(map, {'code', 'contactCount', 'sourceRef'});
    return PowerConnectorDefinition(
      code: map['code'] as String,
      contactCount: map['contactCount'] as int,
      sourceRef: map['sourceRef'] as String,
    );
  }
}

final class PowerProtocolDefinition {
  PowerProtocolDefinition({
    required String code,
    required Iterable<PowerCatalogPortKind> portKinds,
    required String sourceRef,
  })  : code = _code(code),
        portKinds = List.unmodifiable(_uniqueEnums(portKinds, 'portKinds')),
        sourceRef = _text(sourceRef, 'sourceRef') {
    if (this.portKinds.isEmpty) throw ArgumentError('Protocol needs port kinds.');
  }
  final String code;
  final List<PowerCatalogPortKind> portKinds;
  final String sourceRef;
  Map<String, Object?> toMap() => {
        'code': code,
        'portKinds': portKinds.map(_portKindWire).toList(growable: false),
        'sourceRef': sourceRef,
      };
  factory PowerProtocolDefinition.fromMap(Map<String, Object?> map) {
    _keys(map, {'code', 'portKinds', 'sourceRef'});
    return PowerProtocolDefinition(
      code: map['code'] as String,
      portKinds: (map['portKinds'] as List<Object?>).map(
        (value) => _portKindFromWire(value as String),
      ),
      sourceRef: map['sourceRef'] as String,
    );
  }
}

final class PowerInterfaceDefinition {
  PowerInterfaceDefinition({
    required String code,
    required String portCode,
    required String sourceRef,
  })  : code = _code(code),
        portCode = _code(portCode),
        sourceRef = _text(sourceRef, 'sourceRef');
  final String code;
  final String portCode;
  final String sourceRef;
  Map<String, Object?> toMap() => {
        'code': code,
        'portCode': portCode,
        'sourceRef': sourceRef,
      };
  factory PowerInterfaceDefinition.fromMap(Map<String, Object?> map) {
    _keys(map, {'code', 'portCode', 'sourceRef'});
    return PowerInterfaceDefinition(
      code: map['code'] as String,
      portCode: map['portCode'] as String,
      sourceRef: map['sourceRef'] as String,
    );
  }
}

final class PowerPortDefinition {
  PowerPortDefinition({
    required String code,
    required String sourceRef,
    required this.kind,
    required this.direction,
    required this.capacity,
    required String connectorCode,
    required String protocolCode,
    required String interfaceCode,
    required this.powerDirection,
    required this.voltage,
    this.nameplateDemandW,
    this.nameplateLimitW,
  })  : code = _code(code),
        sourceRef = _text(sourceRef, 'sourceRef'),
        connectorCode = _code(connectorCode),
        protocolCode = _code(protocolCode),
        interfaceCode = _code(interfaceCode) {
    if (capacity < 1) throw ArgumentError('Port capacity must be positive.');
    if (direction != powerDirection) {
      throw ArgumentError('Port and power direction must agree in v1.');
    }
    if (nameplateDemandW != null && nameplateDemandW! <= PowerRational.zero) {
      throw ArgumentError('Static nameplate demand must be positive when set.');
    }
    if (nameplateLimitW != null && nameplateLimitW! <= PowerRational.zero) {
      throw ArgumentError('Static nameplate limit must be positive when set.');
    }
  }
  final String code;
  final String sourceRef;
  final PowerCatalogPortKind kind;
  final PowerCatalogDirection direction;
  final int capacity;
  final String connectorCode;
  final String protocolCode;
  final String interfaceCode;
  final PowerCatalogDirection powerDirection;
  final PowerVoltageEnvelope voltage;
  final PowerRational? nameplateDemandW;
  final PowerRational? nameplateLimitW;
  Map<String, Object?> toMap() => {
        'code': code,
        'sourceRef': sourceRef,
        'kind': _portKindWire(kind),
        'direction': _directionWire(direction),
        'capacity': capacity,
        'connectorCode': connectorCode,
        'protocolCode': protocolCode,
        'interfaceCode': interfaceCode,
        'powerDirection': _directionWire(powerDirection),
        'voltage': voltage.toMap(),
        'nameplateDemandW': nameplateDemandW?.toWireDecimal(),
        'nameplateLimitW': nameplateLimitW?.toWireDecimal(),
      };
  factory PowerPortDefinition.fromMap(Map<String, Object?> map) {
    _keys(map, {
      'code',
      'sourceRef',
      'kind',
      'direction',
      'capacity',
      'connectorCode',
      'protocolCode',
      'interfaceCode',
      'powerDirection',
      'voltage',
      'nameplateDemandW',
      'nameplateLimitW',
    });
    return PowerPortDefinition(
      code: map['code'] as String,
      sourceRef: map['sourceRef'] as String,
      kind: _portKindFromWire(map['kind'] as String),
      direction: _directionFromWire(map['direction'] as String),
      capacity: map['capacity'] as int,
      connectorCode: map['connectorCode'] as String,
      protocolCode: map['protocolCode'] as String,
      interfaceCode: map['interfaceCode'] as String,
      powerDirection: _directionFromWire(map['powerDirection'] as String),
      voltage: PowerVoltageEnvelope.fromMap(
        (map['voltage'] as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      nameplateDemandW: map['nameplateDemandW'] == null
          ? null
          : PowerRational.fromWireDecimal(map['nameplateDemandW']),
      nameplateLimitW: map['nameplateLimitW'] == null
          ? null
          : PowerRational.fromWireDecimal(map['nameplateLimitW']),
    );
  }
}

final class PowerComponentDefinition {
  PowerComponentDefinition({
    required String code,
    required String sourceRef,
    required Iterable<String> portCodes,
    required Iterable<String> transferCodes,
    required Iterable<PowerCatalogCapability> capabilities,
    required this.supplyOrigin,
  })  : code = _code(code),
        sourceRef = _text(sourceRef, 'sourceRef'),
        portCodes = List.unmodifiable(_codes(portCodes, 'portCodes')),
        transferCodes = List.unmodifiable(_codes(transferCodes, 'transferCodes')),
        capabilities = List.unmodifiable(_uniqueEnums(capabilities, 'capabilities')) {
    if (this.portCodes.isEmpty || this.capabilities.isEmpty) {
      throw ArgumentError('Power component requires ports and capabilities.');
    }
  }
  final String code;
  final String sourceRef;
  final List<String> portCodes;
  final List<String> transferCodes;
  final List<PowerCatalogCapability> capabilities;
  final PowerSupplyOrigin supplyOrigin;
  Map<String, Object?> toMap() => {
        'code': code,
        'sourceRef': sourceRef,
        'portCodes': portCodes,
        'transferCodes': transferCodes,
        'capabilities': capabilities.map(_capabilityWire).toList(growable: false),
        'supplyOrigin': _supplyOriginWire(supplyOrigin),
      };
  factory PowerComponentDefinition.fromMap(Map<String, Object?> map) {
    _keys(map, {
      'code',
      'sourceRef',
      'portCodes',
      'transferCodes',
      'capabilities',
      'supplyOrigin',
    });
    return PowerComponentDefinition(
      code: map['code'] as String,
      sourceRef: map['sourceRef'] as String,
      portCodes: (map['portCodes'] as List<Object?>).cast<String>(),
      transferCodes: (map['transferCodes'] as List<Object?>).cast<String>(),
      capabilities: (map['capabilities'] as List<Object?>).map(
        (value) => _capabilityFromWire(value as String),
      ),
      supplyOrigin: _supplyOriginFromWire(map['supplyOrigin'] as String),
    );
  }
}

final class PowerCatalogTransferDefinition {
  PowerCatalogTransferDefinition({
    required String code,
    required String sourceRef,
    required String inputPortCode,
    required Iterable<String> outputPortCodes,
    required this.kind,
    required this.loss,
    required Iterable<String> activeStates,
  })  : code = _code(code),
        sourceRef = _text(sourceRef, 'sourceRef'),
        inputPortCode = _code(inputPortCode),
        outputPortCodes = List.unmodifiable(_codes(outputPortCodes, 'outputPortCodes')),
        activeStates = List.unmodifiable(_codes(activeStates, 'activeStates')) {
    if (this.outputPortCodes.isEmpty || this.activeStates.isEmpty) {
      throw ArgumentError('Transfer requires outputs and active states.');
    }
    if (this.outputPortCodes.contains(this.inputPortCode)) {
      throw ArgumentError('Transfer input and output templates must differ.');
    }
  }
  final String code;
  final String sourceRef;
  final String inputPortCode;
  final List<String> outputPortCodes;
  final PowerCatalogTransferKind kind;
  final PowerLossDefinition loss;
  final List<String> activeStates;
  Map<String, Object?> toMap() => {
        'code': code,
        'sourceRef': sourceRef,
        'inputPortCode': inputPortCode,
        'outputPortCodes': outputPortCodes,
        'kind': _transferKindWire(kind),
        'loss': loss.toMap(),
        'activeStates': activeStates,
      };
  factory PowerCatalogTransferDefinition.fromMap(Map<String, Object?> map) {
    _keys(map, {
      'code',
      'sourceRef',
      'inputPortCode',
      'outputPortCodes',
      'kind',
      'loss',
      'activeStates',
    });
    return PowerCatalogTransferDefinition(
      code: map['code'] as String,
      sourceRef: map['sourceRef'] as String,
      inputPortCode: map['inputPortCode'] as String,
      outputPortCodes: (map['outputPortCodes'] as List<Object?>).cast<String>(),
      kind: _transferKindFromWire(map['kind'] as String),
      loss: PowerLossDefinition.fromMap(
        (map['loss'] as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      activeStates: (map['activeStates'] as List<Object?>).cast<String>(),
    );
  }
}

final class PoeCatalogDefinition {
  PoeCatalogDefinition({
    required String code,
    required String sourceRef,
    required String psePortCode,
    required String pdPortCode,
    required this.guaranteedPdW,
    required this.reservedPseW,
    required this.maximumPathM,
    required this.maximumPatchStages,
    required String pairModelCode,
  })  : code = _code(code),
        sourceRef = _text(sourceRef, 'sourceRef'),
        psePortCode = _code(psePortCode),
        pdPortCode = _code(pdPortCode),
        pairModelCode = _code(pairModelCode) {
    _positive(guaranteedPdW, 'guaranteedPdW');
    _positive(reservedPseW, 'reservedPseW');
    _positive(maximumPathM, 'maximumPathM');
    if (reservedPseW < guaranteedPdW) {
      throw ArgumentError('Reserved PSE power cannot be below guaranteed PD power.');
    }
    if (maximumPatchStages < 0) {
      throw ArgumentError('maximumPatchStages cannot be negative.');
    }
  }
  final String code;
  final String sourceRef;
  final String psePortCode;
  final String pdPortCode;
  final PowerRational guaranteedPdW;
  final PowerRational reservedPseW;
  final PowerRational maximumPathM;
  final int maximumPatchStages;
  final String pairModelCode;
  Map<String, Object?> toMap() => {
        'code': code,
        'sourceRef': sourceRef,
        'role': 'PSE_PD_DELIVERY',
        'psePortCode': psePortCode,
        'pdPortCode': pdPortCode,
        'guaranteedPdW': guaranteedPdW.toWireDecimal(),
        'reservedPseW': reservedPseW.toWireDecimal(),
        'maximumPathM': maximumPathM.toWireDecimal(),
        'maximumPatchStages': maximumPatchStages,
        'pairModelCode': pairModelCode,
        'accountingMode': 'GUARANTEED_PD',
      };
  factory PoeCatalogDefinition.fromMap(Map<String, Object?> map) {
    _keys(map, {
      'code',
      'sourceRef',
      'role',
      'psePortCode',
      'pdPortCode',
      'guaranteedPdW',
      'reservedPseW',
      'maximumPathM',
      'maximumPatchStages',
      'pairModelCode',
      'accountingMode',
    });
    if (map['role'] != 'PSE_PD_DELIVERY' ||
        map['accountingMode'] != 'GUARANTEED_PD') {
      throw const FormatException('Unsupported PoE v1 role/accounting mode.');
    }
    return PoeCatalogDefinition(
      code: map['code'] as String,
      sourceRef: map['sourceRef'] as String,
      psePortCode: map['psePortCode'] as String,
      pdPortCode: map['pdPortCode'] as String,
      guaranteedPdW: PowerRational.fromWireDecimal(map['guaranteedPdW']),
      reservedPseW: PowerRational.fromWireDecimal(map['reservedPseW']),
      maximumPathM: PowerRational.fromWireDecimal(map['maximumPathM']),
      maximumPatchStages: map['maximumPatchStages'] as int,
      pairModelCode: map['pairModelCode'] as String,
    );
  }
}

final class BatteryCatalogDefinition {
  BatteryCatalogDefinition({
    required String code,
    required String sourceRef,
    required this.unitV,
    required this.unitAh,
    required String technology,
    required Iterable<int> allowedSeriesCounts,
    required Iterable<int> allowedParallelCounts,
    required String ratingConditions,
    required this.capacityModel,
  })  : code = _code(code),
        sourceRef = _text(sourceRef, 'sourceRef'),
        technology = _code(technology),
        allowedSeriesCounts = List.unmodifiable(_positiveInts(
          allowedSeriesCounts,
          'allowedSeriesCounts',
        )),
        allowedParallelCounts = List.unmodifiable(_positiveInts(
          allowedParallelCounts,
          'allowedParallelCounts',
        )),
        ratingConditions = _text(ratingConditions, 'ratingConditions') {
    _positive(unitV, 'unitV');
    _positive(unitAh, 'unitAh');
    if (this.allowedSeriesCounts.isEmpty || this.allowedParallelCounts.isEmpty) {
      throw ArgumentError('Battery arrangement sets cannot be empty.');
    }
  }
  final String code;
  final String sourceRef;
  final PowerRational unitV;
  final PowerRational unitAh;
  final String technology;
  final List<int> allowedSeriesCounts;
  final List<int> allowedParallelCounts;
  final String ratingConditions;
  final BatteryCapacityModel capacityModel;
  Map<String, Object?> toMap() => {
        'code': code,
        'sourceRef': sourceRef,
        'unitV': unitV.toWireDecimal(),
        'unitAh': unitAh.toWireDecimal(),
        'technology': technology,
        'allowedSeriesCounts': allowedSeriesCounts,
        'allowedParallelCounts': allowedParallelCounts,
        'ratingConditions': ratingConditions,
        'capacityModel': _batteryModelWire(capacityModel),
      };
  factory BatteryCatalogDefinition.fromMap(Map<String, Object?> map) {
    _keys(map, {
      'code',
      'sourceRef',
      'unitV',
      'unitAh',
      'technology',
      'allowedSeriesCounts',
      'allowedParallelCounts',
      'ratingConditions',
      'capacityModel',
    });
    return BatteryCatalogDefinition(
      code: map['code'] as String,
      sourceRef: map['sourceRef'] as String,
      unitV: PowerRational.fromWireDecimal(map['unitV']),
      unitAh: PowerRational.fromWireDecimal(map['unitAh']),
      technology: map['technology'] as String,
      allowedSeriesCounts:
          (map['allowedSeriesCounts'] as List<Object?>).cast<int>(),
      allowedParallelCounts:
          (map['allowedParallelCounts'] as List<Object?>).cast<int>(),
      ratingConditions: map['ratingConditions'] as String,
      capacityModel: _batteryModelFromWire(map['capacityModel'] as String),
    );
  }
}

final class PowerPolicyDefinition {
  PowerPolicyDefinition({
    required String code,
    required String sourceRef,
    required this.purpose,
    this.reserveMultiplier,
    required this.extensionPolicy,
  })  : code = _code(code),
        sourceRef = _text(sourceRef, 'sourceRef') {
    if (reserveMultiplier != null && reserveMultiplier! <= PowerRational.zero) {
      throw ArgumentError('reserveMultiplier must be positive when present.');
    }
  }
  final String code;
  final String sourceRef;
  final PowerPolicyPurpose purpose;
  final PowerRational? reserveMultiplier;
  final PowerExtensionPolicy extensionPolicy;
  Map<String, Object?> toMap() => {
        'code': code,
        'sourceRef': sourceRef,
        'purpose': _policyPurposeWire(purpose),
        'reserveMultiplier': reserveMultiplier?.toWireDecimal(),
        'extensionPolicy': _extensionPolicyWire(extensionPolicy),
      };
  factory PowerPolicyDefinition.fromMap(Map<String, Object?> map) {
    _keys(map, {
      'code',
      'sourceRef',
      'purpose',
      'reserveMultiplier',
      'extensionPolicy',
    });
    return PowerPolicyDefinition(
      code: map['code'] as String,
      sourceRef: map['sourceRef'] as String,
      purpose: _policyPurposeFromWire(map['purpose'] as String),
      reserveMultiplier: map['reserveMultiplier'] == null
          ? null
          : PowerRational.fromWireDecimal(map['reserveMultiplier']),
      extensionPolicy: _extensionPolicyFromWire(
        map['extensionPolicy'] as String,
      ),
    );
  }
}

final class PowerCompatibilityDefinition {
  PowerCompatibilityDefinition({
    required String code,
    required String sourceRef,
    required Iterable<String> familyCodes,
    required this.layer,
    required this.flow,
    required String portCodeA,
    required String portCodeB,
    required String protocolCodeA,
    required String protocolCodeB,
    required String interfaceCodeA,
    required String interfaceCodeB,
  })  : code = _code(code),
        sourceRef = _text(sourceRef, 'sourceRef'),
        familyCodes = List.unmodifiable(_codes(familyCodes, 'familyCodes')),
        portCodeA = _code(portCodeA),
        portCodeB = _code(portCodeB),
        protocolCodeA = _code(protocolCodeA),
        protocolCodeB = _code(protocolCodeB),
        interfaceCodeA = _code(interfaceCodeA),
        interfaceCodeB = _code(interfaceCodeB) {
    if (this.familyCodes.isEmpty) {
      throw ArgumentError('Compatibility requires family codes.');
    }
  }
  final String code;
  final String sourceRef;
  final List<String> familyCodes;
  final PowerCompatibilityLayer layer;
  final PowerCompatibilityFlow flow;
  final String portCodeA;
  final String portCodeB;
  final String protocolCodeA;
  final String protocolCodeB;
  final String interfaceCodeA;
  final String interfaceCodeB;
  Map<String, Object?> toMap() => {
        'code': code,
        'sourceRef': sourceRef,
        'familyCodes': familyCodes,
        'media': const ['wired'],
        'layer': _layerWire(layer),
        'flow': _flowWire(flow),
        'portCodeA': portCodeA,
        'portCodeB': portCodeB,
        'protocolCodeA': protocolCodeA,
        'protocolCodeB': protocolCodeB,
        'interfaceCodeA': interfaceCodeA,
        'interfaceCodeB': interfaceCodeB,
      };
  factory PowerCompatibilityDefinition.fromMap(Map<String, Object?> map) {
    _keys(map, {
      'code',
      'sourceRef',
      'familyCodes',
      'media',
      'layer',
      'flow',
      'portCodeA',
      'portCodeB',
      'protocolCodeA',
      'protocolCodeB',
      'interfaceCodeA',
      'interfaceCodeB',
    });
    final media = (map['media'] as List<Object?>).cast<String>();
    if (media.length != 1 || media.single != 'wired') {
      throw const FormatException('Power catalog v1 supports wired media only.');
    }
    return PowerCompatibilityDefinition(
      code: map['code'] as String,
      sourceRef: map['sourceRef'] as String,
      familyCodes: (map['familyCodes'] as List<Object?>).cast<String>(),
      layer: _layerFromWire(map['layer'] as String),
      flow: _flowFromWire(map['flow'] as String),
      portCodeA: map['portCodeA'] as String,
      portCodeB: map['portCodeB'] as String,
      protocolCodeA: map['protocolCodeA'] as String,
      protocolCodeB: map['protocolCodeB'] as String,
      interfaceCodeA: map['interfaceCodeA'] as String,
      interfaceCodeB: map['interfaceCodeB'] as String,
    );
  }
}

final class PowerCatalogExtension {
  PowerCatalogExtension({
    required Iterable<PowerConnectorDefinition> connectors,
    required Iterable<PowerProtocolDefinition> protocols,
    required Iterable<PowerInterfaceDefinition> interfaces,
    required Iterable<PowerPortDefinition> portDefinitions,
    required Iterable<PowerComponentDefinition> componentDefinitions,
    Iterable<PowerCatalogTransferDefinition> transferDefinitions = const [],
    Iterable<PoeCatalogDefinition> poeDefinitions = const [],
    Iterable<BatteryCatalogDefinition> batteryDefinitions = const [],
    Iterable<PowerPolicyDefinition> policyDefinitions = const [],
    required Iterable<PowerCompatibilityDefinition> compatibilityDefinitions,
  })  : connectors = List.unmodifiable(_sortByCode(connectors, (value) => value.code)),
        protocols = List.unmodifiable(_sortByCode(protocols, (value) => value.code)),
        interfaces = List.unmodifiable(_sortByCode(interfaces, (value) => value.code)),
        portDefinitions = List.unmodifiable(_sortByCode(portDefinitions, (value) => value.code)),
        componentDefinitions = List.unmodifiable(_sortByCode(componentDefinitions, (value) => value.code)),
        transferDefinitions = List.unmodifiable(_sortByCode(transferDefinitions, (value) => value.code)),
        poeDefinitions = List.unmodifiable(_sortByCode(poeDefinitions, (value) => value.code)),
        batteryDefinitions = List.unmodifiable(_sortByCode(batteryDefinitions, (value) => value.code)),
        policyDefinitions = List.unmodifiable(_sortByCode(policyDefinitions, (value) => value.code)),
        compatibilityDefinitions = List.unmodifiable(_sortByCode(compatibilityDefinitions, (value) => value.code)) {
    _validate();
  }

  final List<PowerConnectorDefinition> connectors;
  final List<PowerProtocolDefinition> protocols;
  final List<PowerInterfaceDefinition> interfaces;
  final List<PowerPortDefinition> portDefinitions;
  final List<PowerComponentDefinition> componentDefinitions;
  final List<PowerCatalogTransferDefinition> transferDefinitions;
  final List<PoeCatalogDefinition> poeDefinitions;
  final List<BatteryCatalogDefinition> batteryDefinitions;
  final List<PowerPolicyDefinition> policyDefinitions;
  final List<PowerCompatibilityDefinition> compatibilityDefinitions;

  void _validate() {
    if (connectors.isEmpty ||
        protocols.isEmpty ||
        interfaces.isEmpty ||
        portDefinitions.isEmpty ||
        componentDefinitions.isEmpty ||
        compatibilityDefinitions.isEmpty) {
      throw ArgumentError('Power extension requires complete v1 core sections.');
    }
    _uniqueCodes(connectors.map((value) => value.code), 'connectors');
    _uniqueCodes(protocols.map((value) => value.code), 'protocols');
    _uniqueCodes(interfaces.map((value) => value.code), 'interfaces');
    _uniqueCodes(portDefinitions.map((value) => value.code), 'ports');
    _uniqueCodes(componentDefinitions.map((value) => value.code), 'components');
    _uniqueCodes(transferDefinitions.map((value) => value.code), 'transfers');
    _uniqueCodes(poeDefinitions.map((value) => value.code), 'poe');
    _uniqueCodes(batteryDefinitions.map((value) => value.code), 'batteries');
    _uniqueCodes(policyDefinitions.map((value) => value.code), 'policies');
    _uniqueCodes(compatibilityDefinitions.map((value) => value.code), 'compatibility');

    final connectorCodes = connectors.map((value) => value.code).toSet();
    final protocolByCode = {for (final value in protocols) value.code: value};
    final interfaceByCode = {for (final value in interfaces) value.code: value};
    final portByCode = {for (final value in portDefinitions) value.code: value};
    final transferCodes = transferDefinitions.map((value) => value.code).toSet();

    for (final interface in interfaces) {
      if (!portByCode.containsKey(interface.portCode)) {
        throw ArgumentError('Interface ${interface.code} references unknown port.');
      }
    }
    for (final port in portDefinitions) {
      if (!connectorCodes.contains(port.connectorCode) ||
          !protocolByCode.containsKey(port.protocolCode) ||
          !interfaceByCode.containsKey(port.interfaceCode)) {
        throw ArgumentError('Port ${port.code} has unresolved vocabulary refs.');
      }
      if (!protocolByCode[port.protocolCode]!.portKinds.contains(port.kind)) {
        throw ArgumentError('Port ${port.code} kind is not supported by protocol.');
      }
      if (interfaceByCode[port.interfaceCode]!.portCode != port.code) {
        throw ArgumentError('Port ${port.code} interface points to another port.');
      }
    }
    for (final component in componentDefinitions) {
      if (component.portCodes.any((code) => !portByCode.containsKey(code)) ||
          component.transferCodes.any((code) => !transferCodes.contains(code))) {
        throw ArgumentError('Component ${component.code} has unresolved refs.');
      }
    }
    for (final transfer in transferDefinitions) {
      if (!portByCode.containsKey(transfer.inputPortCode) ||
          transfer.outputPortCodes.any((code) => !portByCode.containsKey(code))) {
        throw ArgumentError('Transfer ${transfer.code} has unresolved ports.');
      }
    }
    for (final poe in poeDefinitions) {
      if (!portByCode.containsKey(poe.psePortCode) ||
          !portByCode.containsKey(poe.pdPortCode)) {
        throw ArgumentError('PoE ${poe.code} has unresolved ports.');
      }
    }
    for (final compatibility in compatibilityDefinitions) {
      if (!portByCode.containsKey(compatibility.portCodeA) ||
          !portByCode.containsKey(compatibility.portCodeB) ||
          !protocolByCode.containsKey(compatibility.protocolCodeA) ||
          !protocolByCode.containsKey(compatibility.protocolCodeB) ||
          !interfaceByCode.containsKey(compatibility.interfaceCodeA) ||
          !interfaceByCode.containsKey(compatibility.interfaceCodeB)) {
        throw ArgumentError(
          'Compatibility ${compatibility.code} has unresolved refs.',
        );
      }
    }
  }

  Map<String, Object?> toMap() => {
        'schema': powerDefinitionsSchemaV1,
        'connectors': connectors.map((value) => value.toMap()).toList(growable: false),
        'protocols': protocols.map((value) => value.toMap()).toList(growable: false),
        'interfaces': interfaces.map((value) => value.toMap()).toList(growable: false),
        'portDefinitions': portDefinitions.map((value) => value.toMap()).toList(growable: false),
        'componentDefinitions': componentDefinitions.map((value) => value.toMap()).toList(growable: false),
        'transferDefinitions': transferDefinitions.map((value) => value.toMap()).toList(growable: false),
        'poeDefinitions': poeDefinitions.map((value) => value.toMap()).toList(growable: false),
        'batteryDefinitions': batteryDefinitions.map((value) => value.toMap()).toList(growable: false),
        'policyDefinitions': policyDefinitions.map((value) => value.toMap()).toList(growable: false),
        'compatibilityDefinitions': compatibilityDefinitions.map((value) => value.toMap()).toList(growable: false),
      };

  factory PowerCatalogExtension.fromMap(Map<String, Object?> map) {
    _keys(map, {
      'schema',
      'connectors',
      'protocols',
      'interfaces',
      'portDefinitions',
      'componentDefinitions',
      'transferDefinitions',
      'poeDefinitions',
      'batteryDefinitions',
      'policyDefinitions',
      'compatibilityDefinitions',
    });
    if (map['schema'] != powerDefinitionsSchemaV1) {
      throw const FormatException('Unsupported power definitions schema.');
    }
    T decode<T>(Object? value, T Function(Map<String, Object?>) factory) =>
        factory((value as Map<Object?, Object?>).cast<String, Object?>());
    return PowerCatalogExtension(
      connectors: (map['connectors'] as List<Object?>)
          .map((value) => decode(value, PowerConnectorDefinition.fromMap)),
      protocols: (map['protocols'] as List<Object?>)
          .map((value) => decode(value, PowerProtocolDefinition.fromMap)),
      interfaces: (map['interfaces'] as List<Object?>)
          .map((value) => decode(value, PowerInterfaceDefinition.fromMap)),
      portDefinitions: (map['portDefinitions'] as List<Object?>)
          .map((value) => decode(value, PowerPortDefinition.fromMap)),
      componentDefinitions: (map['componentDefinitions'] as List<Object?>)
          .map((value) => decode(value, PowerComponentDefinition.fromMap)),
      transferDefinitions: (map['transferDefinitions'] as List<Object?>)
          .map((value) => decode(value, PowerCatalogTransferDefinition.fromMap)),
      poeDefinitions: (map['poeDefinitions'] as List<Object?>)
          .map((value) => decode(value, PoeCatalogDefinition.fromMap)),
      batteryDefinitions: (map['batteryDefinitions'] as List<Object?>)
          .map((value) => decode(value, BatteryCatalogDefinition.fromMap)),
      policyDefinitions: (map['policyDefinitions'] as List<Object?>)
          .map((value) => decode(value, PowerPolicyDefinition.fromMap)),
      compatibilityDefinitions: (map['compatibilityDefinitions'] as List<Object?>)
          .map((value) => decode(value, PowerCompatibilityDefinition.fromMap)),
    );
  }

  PowerDefinitionRef definitionRef({
    required String catalogId,
    required String catalogVersion,
    required PowerDefinitionKind kind,
    required String code,
  }) {
    final normalized = _code(code);
    final Map<String, Object?> definition = switch (kind) {
      PowerDefinitionKind.port =>
        portDefinitions.singleWhere((value) => value.code == normalized).toMap(),
      PowerDefinitionKind.component => componentDefinitions
          .singleWhere((value) => value.code == normalized)
          .toMap(),
      PowerDefinitionKind.transfer => transferDefinitions
          .singleWhere((value) => value.code == normalized)
          .toMap(),
      PowerDefinitionKind.poe =>
        poeDefinitions.singleWhere((value) => value.code == normalized).toMap(),
      PowerDefinitionKind.battery => batteryDefinitions
          .singleWhere((value) => value.code == normalized)
          .toMap(),
      PowerDefinitionKind.policy => policyDefinitions
          .singleWhere((value) => value.code == normalized)
          .toMap(),
      PowerDefinitionKind.interface =>
        interfaces.singleWhere((value) => value.code == normalized).toMap(),
      PowerDefinitionKind.protocol =>
        protocols.singleWhere((value) => value.code == normalized).toMap(),
      PowerDefinitionKind.compatibility => compatibilityDefinitions
          .singleWhere((value) => value.code == normalized)
          .toMap(),
    };
    final sourceRef = definition['sourceRef'] as String;
    final hash = sha256HexUtf8(
      canonicalEngineeringJsonV1({
        'schema': 'electra.elv4-power-definition.v1',
        'definitionKind': kind.name.toUpperCase(),
        'definition': definition,
      }),
    );
    return PowerDefinitionRef(
      catalogId: catalogId,
      catalogVersion: catalogVersion,
      definitionKind: kind,
      definitionCode: normalized,
      definitionVersion: catalogVersion,
      definitionSchema: powerDefinitionsSchemaV1,
      contentSha256: hash,
      sourceRef: sourceRef,
    );
  }
}

final class PowerRootCatalog {
  PowerRootCatalog({
    required String id,
    required String code,
    required String version,
    required String source,
    required this.power,
    Map<String, String> metadata = const {},
  })  : id = _text(id, 'id'),
        code = _code(code),
        version = _text(version, 'version'),
        source = _text(source, 'source'),
        metadata = Map.unmodifiable(_sortedMetadata(metadata));

  final String id;
  final String code;
  final String version;
  final String source;
  final PowerCatalogExtension power;
  final Map<String, String> metadata;

  Map<String, Object?> toMap() => {
        'schema': powerRootCatalogSchemaV1,
        'id': id,
        'code': code,
        'version': version,
        'source': source,
        'power': power.toMap(),
        'metadata': metadata,
      };

  String get contentSha256 => sha256HexUtf8(canonicalEngineeringJsonV1(toMap()));

  factory PowerRootCatalog.fromMap(Map<String, Object?> map) {
    _keys(map, {'schema', 'id', 'code', 'version', 'source', 'power', 'metadata'});
    if (map['schema'] != powerRootCatalogSchemaV1) {
      throw const FormatException('Unsupported ELV4 power root catalog schema.');
    }
    return PowerRootCatalog(
      id: map['id'] as String,
      code: map['code'] as String,
      version: map['version'] as String,
      source: map['source'] as String,
      power: PowerCatalogExtension.fromMap(
        (map['power'] as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      metadata:
          (map['metadata'] as Map<Object?, Object?>).cast<String, String>(),
    );
  }
}

List<T> _sortByCode<T>(Iterable<T> input, String Function(T) codeOf) {
  final result = input.toList()..sort((a, b) => codeOf(a).compareTo(codeOf(b)));
  return result;
}

List<T> _uniqueEnums<T extends Enum>(Iterable<T> input, String field) {
  final result = input.toList()..sort((a, b) => a.name.compareTo(b.name));
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must be unique.');
  }
  return result;
}

List<String> _codes(Iterable<String> input, String field) {
  final result = input.map(_code).toList()..sort();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must be unique.');
  }
  return result;
}

List<int> _positiveInts(Iterable<int> input, String field) {
  final result = input.toList()..sort();
  if (result.any((value) => value < 1) || result.toSet().length != result.length) {
    throw ArgumentError('$field must contain unique positive integers.');
  }
  return result;
}

Map<String, String> _sortedMetadata(Map<String, String> input) {
  final entries = input.entries
      .map((entry) => MapEntry(_text(entry.key, 'metadata key'), entry.value))
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return Map.fromEntries(entries);
}

void _uniqueCodes(Iterable<String> codes, String field) {
  final list = codes.toList();
  if (list.toSet().length != list.length) {
    throw ArgumentError('$field definition codes must be unique.');
  }
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 512) {
    throw ArgumentError.value(value, field, 'Requires 1-512 characters.');
  }
  return normalized;
}

String _code(String value) {
  final normalized = value.trim().toUpperCase();
  if (!RegExp(r'^[A-Z][A-Z0-9_-]{0,63}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, 'code', 'Invalid canonical code.');
  }
  return normalized;
}

void _positive(PowerRational value, String field) {
  if (value <= PowerRational.zero) {
    throw ArgumentError.value(value, field, 'Must be positive.');
  }
}

void _keys(Map<String, Object?> map, Set<String> expected) {
  if (map.length != expected.length || !expected.every(map.containsKey)) {
    throw FormatException('Expected exactly: ${expected.join(', ')}.');
  }
}

String _portKindWire(PowerCatalogPortKind value) => switch (value) {
      PowerCatalogPortKind.power => 'power',
      PowerCatalogPortKind.dataPower => 'dataPower',
    };
PowerCatalogPortKind _portKindFromWire(String value) => switch (value) {
      'power' => PowerCatalogPortKind.power,
      'dataPower' => PowerCatalogPortKind.dataPower,
      _ => throw const FormatException('Unknown power port kind.'),
    };
String _directionWire(PowerCatalogDirection value) => value.name;
PowerCatalogDirection _directionFromWire(String value) =>
    PowerCatalogDirection.values.byName(value);
String _capabilityWire(PowerCatalogCapability value) => value.name.toUpperCase();
PowerCatalogCapability _capabilityFromWire(String value) => switch (value) {
      'SOURCE' => PowerCatalogCapability.source,
      'CONSUMER' => PowerCatalogCapability.consumer,
      'CONVERTER' => PowerCatalogCapability.converter,
      'STORE' => PowerCatalogCapability.store,
      'CHARGER' => PowerCatalogCapability.charger,
      'DISTRIBUTOR' => PowerCatalogCapability.distributor,
      'PSE' => PowerCatalogCapability.pse,
      'PD' => PowerCatalogCapability.pd,
      _ => throw const FormatException('Unknown power component capability.'),
    };
String _supplyOriginWire(PowerSupplyOrigin value) => switch (value) {
      PowerSupplyOrigin.externalDeclared => 'EXTERNAL_DECLARED',
      PowerSupplyOrigin.localTransfer => 'LOCAL_TRANSFER',
      PowerSupplyOrigin.notSource => 'NOT_SOURCE',
    };
PowerSupplyOrigin _supplyOriginFromWire(String value) => switch (value) {
      'EXTERNAL_DECLARED' => PowerSupplyOrigin.externalDeclared,
      'LOCAL_TRANSFER' => PowerSupplyOrigin.localTransfer,
      'NOT_SOURCE' => PowerSupplyOrigin.notSource,
      _ => throw const FormatException('Unknown supply origin.'),
    };
String _transferKindWire(PowerCatalogTransferKind value) => switch (value) {
      PowerCatalogTransferKind.acDc => 'AC_DC',
      PowerCatalogTransferKind.dcDc => 'DC_DC',
      PowerCatalogTransferKind.transformer => 'TRANSFORMER',
      PowerCatalogTransferKind.ups => 'UPS',
      PowerCatalogTransferKind.charger => 'CHARGER',
      PowerCatalogTransferKind.distributor => 'DISTRIBUTOR',
      PowerCatalogTransferKind.poePse => 'POE_PSE',
      PowerCatalogTransferKind.selector => 'SELECTOR',
    };
PowerCatalogTransferKind _transferKindFromWire(String value) => switch (value) {
      'AC_DC' => PowerCatalogTransferKind.acDc,
      'DC_DC' => PowerCatalogTransferKind.dcDc,
      'TRANSFORMER' => PowerCatalogTransferKind.transformer,
      'UPS' => PowerCatalogTransferKind.ups,
      'CHARGER' => PowerCatalogTransferKind.charger,
      'DISTRIBUTOR' => PowerCatalogTransferKind.distributor,
      'POE_PSE' => PowerCatalogTransferKind.poePse,
      'SELECTOR' => PowerCatalogTransferKind.selector,
      _ => throw const FormatException('Unknown power transfer kind.'),
    };
String _batteryModelWire(BatteryCapacityModel value) => switch (value) {
      BatteryCapacityModel.explicitFlatVoltageWh => 'EXPLICIT_FLAT_VOLTAGE_WH',
      BatteryCapacityModel.constantCurrentAh => 'CONSTANT_CURRENT_AH',
    };
BatteryCapacityModel _batteryModelFromWire(String value) => switch (value) {
      'EXPLICIT_FLAT_VOLTAGE_WH' => BatteryCapacityModel.explicitFlatVoltageWh,
      'CONSTANT_CURRENT_AH' => BatteryCapacityModel.constantCurrentAh,
      _ => throw const FormatException('Unknown battery capacity model.'),
    };
String _policyPurposeWire(PowerPolicyPurpose value) => switch (value) {
      PowerPolicyPurpose.supplyReserve => 'SUPPLY_RESERVE',
      PowerPolicyPurpose.backupSequence => 'BACKUP_SEQUENCE',
      PowerPolicyPurpose.peak => 'PEAK',
    };
PowerPolicyPurpose _policyPurposeFromWire(String value) => switch (value) {
      'SUPPLY_RESERVE' => PowerPolicyPurpose.supplyReserve,
      'BACKUP_SEQUENCE' => PowerPolicyPurpose.backupSequence,
      'PEAK' => PowerPolicyPurpose.peak,
      _ => throw const FormatException('Unknown power policy purpose.'),
    };
String _extensionPolicyWire(PowerExtensionPolicy value) => switch (value) {
      PowerExtensionPolicy.none => 'NONE',
      PowerExtensionPolicy.continueLast => 'CONTINUE_LAST',
      PowerExtensionPolicy.repeatSequence => 'REPEAT_SEQUENCE',
    };
PowerExtensionPolicy _extensionPolicyFromWire(String value) => switch (value) {
      'NONE' => PowerExtensionPolicy.none,
      'CONTINUE_LAST' => PowerExtensionPolicy.continueLast,
      'REPEAT_SEQUENCE' => PowerExtensionPolicy.repeatSequence,
      _ => throw const FormatException('Unknown extension policy.'),
    };
String _layerWire(PowerCompatibilityLayer value) => switch (value) {
      PowerCompatibilityLayer.power => 'power',
      PowerCompatibilityLayer.dataPower => 'dataPower',
    };
PowerCompatibilityLayer _layerFromWire(String value) => switch (value) {
      'power' => PowerCompatibilityLayer.power,
      'dataPower' => PowerCompatibilityLayer.dataPower,
      _ => throw const FormatException('Unknown compatibility layer.'),
    };
String _flowWire(PowerCompatibilityFlow value) => value.name;
PowerCompatibilityFlow _flowFromWire(String value) =>
    PowerCompatibilityFlow.values.byName(value);
