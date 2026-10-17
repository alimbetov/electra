import 'elv4_wire_command_dispatcher.dart';
import 'elv4_wire_semantic_adapter.dart';

final class Elv4ValidatedWirePayload {
  Elv4ValidatedWirePayload._(Map<String, Object?> value)
    : value = Map.unmodifiable(value);

  final Map<String, Object?> value;

  String string(String key) {
    final result = value[key];
    if (result is! String || result.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return result;
  }

  bool boolean(String key) {
    final result = value[key];
    if (result is! bool) throw FormatException('$key must be boolean.');
    return result;
  }

  int integer(String key) {
    final result = value[key];
    if (result is! int) throw FormatException('$key must be integer.');
    return result;
  }

  List<Object?> list(String key) {
    final result = value[key];
    if (result is! List) throw FormatException('$key must be an array.');
    return List.unmodifiable(result);
  }

  Map<String, Object?> object(String key) {
    final result = value[key];
    if (result is! Map) throw FormatException('$key must be an object.');
    return Map.unmodifiable(result.cast<String, Object?>());
  }
}

abstract interface class Elv4WireRuntimeBackend<TResult> {
  Future<TResult> bindPowerProfile(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> adoptPowerProfile(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> releasePowerProfile(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> setPowerLoadProfile(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> replacePowerTransfers(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> replacePowerCapacityGroup(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> replacePowerSupplyRequirement(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> createPowerScenario(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> replacePowerScenario(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> archivePowerScenario(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> bindPoeDelivery(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> replacePoeDelivery(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> configureBackupAssembly(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> replaceBatteryBank(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> calculatePowerProcess(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> freezeDesignRevision(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );

  Future<TResult> createNextWorkingDesignRevision(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  );
}

List<Elv4WireSemanticCodec<TResult>> createElv4WireRuntimeCodecs<TResult>(
  Elv4WireRuntimeBackend<TResult> backend,
) => [
  _codec(
    operation: 'BIND_POWER_PROFILE',
    keys: const {
      'componentId',
      'bindingId',
      'definitionRef',
      'templatePortMap',
      'createPorts',
    },
    validate: (payload) {
      payload.string('componentId');
      payload.string('bindingId');
      payload.object('definitionRef');
      payload.object('templatePortMap');
      payload.list('createPorts');
    },
    handle: backend.bindPowerProfile,
  ),
  _codec(
    operation: 'ADOPT_POWER_PROFILE',
    keys: const {'bindingId', 'newDefinitionRef', 'templatePortMap'},
    validate: (payload) {
      payload.string('bindingId');
      payload.object('newDefinitionRef');
      payload.object('templatePortMap');
    },
    handle: backend.adoptPowerProfile,
  ),
  _codec(
    operation: 'RELEASE_POWER_PROFILE',
    keys: const {'bindingId', 'fieldReleasePolicy'},
    validate: (payload) {
      payload.string('bindingId');
      if (payload.string('fieldReleasePolicy') !=
          'KEEP_SHARED_CLEAR_POWER_OWNED') {
        throw const FormatException('Unsupported fieldReleasePolicy.');
      }
    },
    handle: backend.releasePowerProfile,
  ),
  _codec(
    operation: 'SET_POWER_LOAD_PROFILE',
    keys: const {'componentId', 'loads'},
    validate: (payload) {
      payload.string('componentId');
      payload.list('loads');
    },
    handle: backend.setPowerLoadProfile,
  ),
  _codec(
    operation: 'REPLACE_POWER_TRANSFERS',
    keys: const {'componentId', 'transfers'},
    validate: (payload) {
      payload.string('componentId');
      payload.list('transfers');
    },
    handle: backend.replacePowerTransfers,
  ),
  _codec(
    operation: 'REPLACE_POWER_CAPACITY_GROUP',
    keys: const {
      'groupId',
      'componentId',
      'outputPortIds',
      'limits',
      'derating',
      'reserveMultiplier',
      'policyRef',
    },
    validate: (payload) {
      payload.string('groupId');
      payload.string('componentId');
      payload.list('outputPortIds');
      payload.list('limits');
      payload.string('derating');
      payload.string('reserveMultiplier');
      payload.object('policyRef');
    },
    handle: backend.replacePowerCapacityGroup,
  ),
  _codec(
    operation: 'REPLACE_POWER_SUPPLY_REQUIREMENT',
    keys: const {
      'requirementId',
      'componentId',
      'inputPortIds',
      'selectionPolicy',
      'allowedSourcePortIds',
      'replacementSelections',
    },
    validate: (payload) {
      payload.string('requirementId');
      payload.string('componentId');
      payload.list('inputPortIds');
      final policy = payload.string('selectionPolicy');
      if (policy != 'SINGLE' && policy != 'ALTERNATIVE') {
        throw const FormatException('Unsupported selectionPolicy.');
      }
      payload.list('allowedSourcePortIds');
      payload.list('replacementSelections');
    },
    handle: backend.replacePowerSupplyRequirement,
  ),
  _codec(
    operation: 'CREATE_POWER_SCENARIO',
    keys: const {'scenarioId', 'role', 'segments', 'peakModel', 'policyRefs'},
    validate: _validateScenario,
    handle: backend.createPowerScenario,
  ),
  _codec(
    operation: 'REPLACE_POWER_SCENARIO',
    keys: const {'scenarioId', 'role', 'segments', 'peakModel', 'policyRefs'},
    validate: _validateScenario,
    handle: backend.replacePowerScenario,
  ),
  _codec(
    operation: 'ARCHIVE_POWER_SCENARIO',
    keys: const {'scenarioId'},
    validate: (payload) => payload.string('scenarioId'),
    handle: backend.archivePowerScenario,
  ),
  _codec(
    operation: 'BIND_POE_DELIVERY',
    keys: const {
      'deliveryId',
      'psePortId',
      'pdPortId',
      'definitionRef',
      'accountingMode',
      'upstreamBasis',
      'path',
    },
    validate: _validatePoe,
    handle: backend.bindPoeDelivery,
  ),
  _codec(
    operation: 'REPLACE_POE_DELIVERY',
    keys: const {
      'deliveryId',
      'psePortId',
      'pdPortId',
      'definitionRef',
      'accountingMode',
      'upstreamBasis',
      'path',
    },
    validate: _validatePoe,
    handle: backend.replacePoeDelivery,
  ),
  _codec(
    operation: 'CONFIGURE_BACKUP_ASSEMBLY',
    keys: const {
      'assemblyId',
      'upsComponentId',
      'chargerComponentId',
      'bankComponentId',
      'protectedOutputs',
      'transferIds',
      'bank',
      'chargeVoltageV',
      'chargeCurrentA',
      'policyRef',
    },
    validate: (payload) {
      payload.string('assemblyId');
      _nullableString(payload.value['upsComponentId'], 'upsComponentId');
      _nullableString(
        payload.value['chargerComponentId'],
        'chargerComponentId',
      );
      payload.string('bankComponentId');
      payload.list('protectedOutputs');
      payload.list('transferIds');
      payload.object('bank');
      payload.string('chargeVoltageV');
      payload.string('chargeCurrentA');
      payload.object('policyRef');
    },
    handle: backend.configureBackupAssembly,
  ),
  _codec(
    operation: 'REPLACE_BATTERY_BANK',
    keys: const {'bankId', 'configuration'},
    validate: (payload) {
      payload.string('bankId');
      payload.object('configuration');
    },
    handle: backend.replaceBatteryBank,
  ),
  _codec(
    operation: 'CALCULATE_POWER_PROCESS',
    keys: const {
      'scenarioId',
      'scope',
      'processCodes',
      'subjects',
      'expectedPointerGenerations',
    },
    validate: (payload) {
      payload.string('scenarioId');
      payload.object('scope');
      final processes = payload.list('processCodes');
      if (processes.isEmpty) {
        throw const FormatException('processCodes must not be empty.');
      }
      payload.list('subjects');
      payload.object('expectedPointerGenerations');
    },
    handle: backend.calculatePowerProcess,
  ),
  _revisionCodec(
    operation: 'FREEZE_DESIGN_REVISION',
    keys: const {'powerSectionIntent'},
    validate: (payload) {
      final intent = payload.string('powerSectionIntent');
      if (intent != 'CAPTURE_CURRENT' && intent != 'CAPTURE_EMPTY') {
        throw const FormatException('Unsupported powerSectionIntent.');
      }
    },
    handle: backend.freezeDesignRevision,
  ),
  _revisionCodec(
    operation: 'CREATE_NEXT_WORKING_DESIGN_REVISION',
    keys: const {
      'newRevisionId',
      'code',
      'basedOnRevisionId',
      'initializePowerAsEmpty',
      'expectedAllocatorGeneration',
      'canonicalRestorePlan',
    },
    validate: (payload) {
      payload.string('newRevisionId');
      payload.string('code');
      payload.string('basedOnRevisionId');
      payload.boolean('initializePowerAsEmpty');
      if (payload.integer('expectedAllocatorGeneration') < 1) {
        throw const FormatException(
          'expectedAllocatorGeneration must be positive.',
        );
      }
      payload.list('canonicalRestorePlan');
    },
    handle: backend.createNextWorkingDesignRevision,
  ),
];

typedef _PayloadValidator = void Function(Elv4ValidatedWirePayload payload);
typedef _RuntimeHandler<TResult> = Future<TResult> Function(
  Elv4WireCommandEnvelope envelope,
  Elv4ValidatedWirePayload payload,
  Elv4ResolvedWireImpact impact,
);

Elv4WireSemanticCodec<TResult> _codec<TResult>({
  required String operation,
  required Set<String> keys,
  required _PayloadValidator validate,
  required _RuntimeHandler<TResult> handle,
}) => _buildCodec(
  schema: Elv4WireCommandEnvelope.powerCommandSchema,
  operation: operation,
  version: 1,
  keys: keys,
  validate: validate,
  handle: handle,
);

Elv4WireSemanticCodec<TResult> _revisionCodec<TResult>({
  required String operation,
  required Set<String> keys,
  required _PayloadValidator validate,
  required _RuntimeHandler<TResult> handle,
}) => _buildCodec(
  schema: Elv4WireCommandEnvelope.revisionCommandSchema,
  operation: operation,
  version: 2,
  keys: keys,
  validate: validate,
  handle: handle,
);

Elv4WireSemanticCodec<TResult> _buildCodec<TResult>({
  required String schema,
  required String operation,
  required int version,
  required Set<String> keys,
  required _PayloadValidator validate,
  required _RuntimeHandler<TResult> handle,
}) => Elv4WireTypedSemanticCodec<Elv4ValidatedWirePayload, TResult>(
  key: Elv4WireCommandKey(
    schema: schema,
    operation: operation,
    payloadSchemaVersion: version,
  ),
  decodePayload: (value) {
    _requireExactKeys(value, keys);
    final payload = Elv4ValidatedWirePayload._(value);
    validate(payload);
    return payload;
  },
  handler: handle,
);

void _validateScenario(Elv4ValidatedWirePayload payload) {
  payload.string('scenarioId');
  const roles = {'NORMAL', 'STANDBY', 'ALARM', 'STARTUP', 'BACKUP', 'RECHARGE'};
  if (!roles.contains(payload.string('role'))) {
    throw const FormatException('Unsupported scenario role.');
  }
  if (payload.list('segments').isEmpty) {
    throw const FormatException('segments must not be empty.');
  }
  if (payload.string('peakModel') != 'ALL_SIMULTANEOUS') {
    throw const FormatException('Unsupported peakModel.');
  }
  payload.list('policyRefs');
}

void _validatePoe(Elv4ValidatedWirePayload payload) {
  payload.string('deliveryId');
  payload.string('psePortId');
  payload.string('pdPortId');
  payload.object('definitionRef');
  const modes = {'GUARANTEED_PD', 'EXPLICIT_PATH_LOSS'};
  if (!modes.contains(payload.string('accountingMode'))) {
    throw const FormatException('Unsupported accountingMode.');
  }
  if (payload.string('upstreamBasis') != 'CONSERVATIVE_RESERVED') {
    throw const FormatException('Unsupported upstreamBasis.');
  }
  if (payload.list('path').isEmpty) {
    throw const FormatException('path must not be empty.');
  }
}

void _nullableString(Object? value, String field) {
  if (value == null) return;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be null or non-empty string.');
  }
}

void _requireExactKeys(Map<String, Object?> value, Set<String> expected) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length ||
      !actual.containsAll(expected) ||
      !expected.containsAll(actual)) {
    throw FormatException(
      'ELV4 operation payload fields do not match. '
      'expected=${expected.toList()..sort()} actual=${actual.toList()..sort()}',
    );
  }
}
