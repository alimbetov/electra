import 'package:electra_mobile/application/elv4_wire_command_dispatcher.dart';
import 'package:electra_mobile/application/elv4_wire_runtime_registry.dart';
import 'package:electra_mobile/application/elv4_wire_semantic_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fingerprint =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test(
    'production semantic registry routes every registered operation',
    () async {
      final backend = _RecordingBackend();
      final adapter = Elv4WireSemanticAdapter<String>(
        codecs: createElv4WireRuntimeCodecs(backend),
        resolveImpact:
            (_) async => Elv4ResolvedWireImpact(
              verifiedRows: const {},
              changedDependencyRefs: const ['server-reviewed-dependency'],
              reviewedImpactFingerprint: fingerprint,
            ),
      );

      for (final entry in _payloads.entries) {
        final revision = Elv4WireCommandEnvelope.revisionV2Operations.contains(
          entry.key,
        );
        final actual = await adapter.dispatchMap({
          'schema':
              revision
                  ? Elv4WireCommandEnvelope.revisionCommandSchema
                  : Elv4WireCommandEnvelope.powerCommandSchema,
          'operation': entry.key,
          'payloadSchemaVersion': revision ? 2 : 1,
          'projectId': 'project-1',
          'designRevisionId': 'revision-1',
          'commandId': 'cmd-${entry.key}',
          'expectedDesignRowRevision': 7,
          'expectedRows': <String, Object?>{},
          'reviewedImpactFingerprint': fingerprint,
          'payload': entry.value,
        });
        expect(actual, entry.key);
        expect(backend.lastOperation, entry.key);
      }

      expect(
        backend.calls,
        hasLength(
          Elv4WireCommandEnvelope.powerV1Operations.length +
              Elv4WireCommandEnvelope.revisionV2Operations.length,
        ),
      );
    },
  );

  test('operation-specific payload shape rejects before backend', () async {
    final backend = _RecordingBackend();
    final adapter = Elv4WireSemanticAdapter<String>(
      codecs: createElv4WireRuntimeCodecs(backend),
      resolveImpact:
          (_) async => Elv4ResolvedWireImpact(
            verifiedRows: const {},
            changedDependencyRefs: const [],
            reviewedImpactFingerprint: fingerprint,
          ),
    );

    await expectLater(
      adapter.dispatchMap({
        'schema': Elv4WireCommandEnvelope.powerCommandSchema,
        'operation': 'SET_POWER_LOAD_PROFILE',
        'payloadSchemaVersion': 1,
        'projectId': 'project-1',
        'designRevisionId': 'revision-1',
        'commandId': 'bad-load',
        'expectedDesignRowRevision': 7,
        'expectedRows': <String, Object?>{},
        'reviewedImpactFingerprint': fingerprint,
        'payload': <String, Object?>{
          'componentId': 'component-1',
          'loads': <Object?>[],
          'changedDependencies': <Object?>['client-controlled'],
        },
      }),
      throwsFormatException,
    );
    expect(backend.calls, isEmpty);
  });
}

const _ref = <String, Object?>{'id': 'definition'};

final Map<String, Map<String, Object?>> _payloads = {
  'BIND_POWER_PROFILE': <String, Object?>{
    'componentId': 'component-1',
    'bindingId': 'binding-1',
    'definitionRef': _ref,
    'templatePortMap': <String, Object?>{},
    'createPorts': <Object?>[],
  },
  'ADOPT_POWER_PROFILE': <String, Object?>{
    'bindingId': 'binding-1',
    'newDefinitionRef': _ref,
    'templatePortMap': <String, Object?>{},
  },
  'RELEASE_POWER_PROFILE': <String, Object?>{
    'bindingId': 'binding-1',
    'fieldReleasePolicy': 'KEEP_SHARED_CLEAR_POWER_OWNED',
  },
  'SET_POWER_LOAD_PROFILE': <String, Object?>{
    'componentId': 'component-1',
    'loads': <Object?>[],
  },
  'REPLACE_POWER_TRANSFERS': <String, Object?>{
    'componentId': 'component-1',
    'transfers': <Object?>[],
  },
  'REPLACE_POWER_CAPACITY_GROUP': <String, Object?>{
    'groupId': 'group-1',
    'componentId': 'component-1',
    'outputPortIds': <Object?>['port-1'],
    'limits': <Object?>[
      <String, Object?>{'dimension': 'WATT', 'limit': '10'},
    ],
    'derating': '1',
    'reserveMultiplier': '1',
    'policyRef': _ref,
  },
  'REPLACE_POWER_SUPPLY_REQUIREMENT': <String, Object?>{
    'requirementId': 'requirement-1',
    'componentId': 'component-1',
    'inputPortIds': <Object?>['port-1'],
    'selectionPolicy': 'SINGLE',
    'allowedSourcePortIds': <Object?>['source-1'],
    'replacementSelections': <Object?>[],
  },
  'CREATE_POWER_SCENARIO': <String, Object?>{
    'scenarioId': 'scenario-1',
    'role': 'NORMAL',
    'segments': <Object?>[
      <String, Object?>{'id': 'segment-1'},
    ],
    'peakModel': 'ALL_SIMULTANEOUS',
    'policyRefs': <Object?>[],
  },
  'REPLACE_POWER_SCENARIO': <String, Object?>{
    'scenarioId': 'scenario-1',
    'role': 'NORMAL',
    'segments': <Object?>[
      <String, Object?>{'id': 'segment-1'},
    ],
    'peakModel': 'ALL_SIMULTANEOUS',
    'policyRefs': <Object?>[],
  },
  'ARCHIVE_POWER_SCENARIO': <String, Object?>{'scenarioId': 'scenario-1'},
  'BIND_POE_DELIVERY': <String, Object?>{
    'deliveryId': 'delivery-1',
    'psePortId': 'pse-1',
    'pdPortId': 'pd-1',
    'definitionRef': _ref,
    'accountingMode': 'GUARANTEED_PD',
    'upstreamBasis': 'CONSERVATIVE_RESERVED',
    'path': <Object?>[
      <String, Object?>{'connectionId': 'connection-1'},
    ],
  },
  'REPLACE_POE_DELIVERY': <String, Object?>{
    'deliveryId': 'delivery-1',
    'psePortId': 'pse-1',
    'pdPortId': 'pd-1',
    'definitionRef': _ref,
    'accountingMode': 'GUARANTEED_PD',
    'upstreamBasis': 'CONSERVATIVE_RESERVED',
    'path': <Object?>[
      <String, Object?>{'connectionId': 'connection-1'},
    ],
  },
  'CONFIGURE_BACKUP_ASSEMBLY': <String, Object?>{
    'assemblyId': 'assembly-1',
    'upsComponentId': 'ups-1',
    'chargerComponentId': null,
    'bankComponentId': 'bank-1',
    'protectedOutputs': <Object?>[
      <String, Object?>{'portId': 'out-1', 'expectedPortRevision': 1},
    ],
    'transferIds': <Object?>['transfer-1'],
    'bank': <String, Object?>{},
    'chargeVoltageV': '24',
    'chargeCurrentA': '1',
    'policyRef': _ref,
  },
  'REPLACE_BATTERY_BANK': <String, Object?>{
    'bankId': 'bank-1',
    'configuration': <String, Object?>{},
  },
  'CALCULATE_POWER_PROCESS': <String, Object?>{
    'scenarioId': 'scenario-1',
    'scope': <String, Object?>{'kind': 'SEGMENT', 'id': 'segment-1'},
    'processCodes': <Object?>['ELV-PWR-01'],
    'subjects': <Object?>[
      <String, Object?>{'kind': 'PORT', 'id': 'port-1'},
    ],
    'expectedPointerGenerations': <String, Object?>{},
  },
  'FREEZE_DESIGN_REVISION': <String, Object?>{
    'powerSectionIntent': 'CAPTURE_CURRENT',
  },
  'CREATE_NEXT_WORKING_DESIGN_REVISION': <String, Object?>{
    'newRevisionId': 'revision-2',
    'code': 'R2',
    'basedOnRevisionId': 'revision-1',
    'initializePowerAsEmpty': false,
    'expectedAllocatorGeneration': 1,
    'canonicalRestorePlan': <Object?>[],
  },
};

final class _RecordingBackend implements Elv4WireRuntimeBackend<String> {
  final calls = <String>[];
  String? lastOperation;

  Future<String> _record(String operation) async {
    calls.add(operation);
    lastOperation = operation;
    return operation;
  }

  @override
  Future<String> bindPowerProfile(envelope, payload, impact) =>
      _record('BIND_POWER_PROFILE');
  @override
  Future<String> adoptPowerProfile(envelope, payload, impact) =>
      _record('ADOPT_POWER_PROFILE');
  @override
  Future<String> releasePowerProfile(envelope, payload, impact) =>
      _record('RELEASE_POWER_PROFILE');
  @override
  Future<String> setPowerLoadProfile(envelope, payload, impact) =>
      _record('SET_POWER_LOAD_PROFILE');
  @override
  Future<String> replacePowerTransfers(envelope, payload, impact) =>
      _record('REPLACE_POWER_TRANSFERS');
  @override
  Future<String> replacePowerCapacityGroup(envelope, payload, impact) =>
      _record('REPLACE_POWER_CAPACITY_GROUP');
  @override
  Future<String> replacePowerSupplyRequirement(envelope, payload, impact) =>
      _record('REPLACE_POWER_SUPPLY_REQUIREMENT');
  @override
  Future<String> createPowerScenario(envelope, payload, impact) =>
      _record('CREATE_POWER_SCENARIO');
  @override
  Future<String> replacePowerScenario(envelope, payload, impact) =>
      _record('REPLACE_POWER_SCENARIO');
  @override
  Future<String> archivePowerScenario(envelope, payload, impact) =>
      _record('ARCHIVE_POWER_SCENARIO');
  @override
  Future<String> bindPoeDelivery(envelope, payload, impact) =>
      _record('BIND_POE_DELIVERY');
  @override
  Future<String> replacePoeDelivery(envelope, payload, impact) =>
      _record('REPLACE_POE_DELIVERY');
  @override
  Future<String> configureBackupAssembly(envelope, payload, impact) =>
      _record('CONFIGURE_BACKUP_ASSEMBLY');
  @override
  Future<String> replaceBatteryBank(envelope, payload, impact) =>
      _record('REPLACE_BATTERY_BANK');
  @override
  Future<String> calculatePowerProcess(envelope, payload, impact) =>
      _record('CALCULATE_POWER_PROCESS');
  @override
  Future<String> freezeDesignRevision(envelope, payload, impact) =>
      _record('FREEZE_DESIGN_REVISION');
  @override
  Future<String> createNextWorkingDesignRevision(envelope, payload, impact) =>
      _record('CREATE_NEXT_WORKING_DESIGN_REVISION');
}
