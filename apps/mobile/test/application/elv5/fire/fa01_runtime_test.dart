import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/fire/elv5_fire_persistence.dart';
import 'package:electra_mobile/application/elv5/fire/fa01_address_capacity_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa01_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'projects exact expanded addresses and profile resource contributions',
    () async {
      final resolver = Fa01PersistedInputResolver(
        fireStore: _FireStore(reserved: const <int>[]),
        contractSource: _ContractSource(_contract()),
        nowUtc: () => DateTime.utc(2026, 10, 17),
      );
      final captured = await resolver.capture(_request());
      final candidate = await buildFa01Executor().execute(captured);
      expect(candidate.assessment, Elv5Assessment.pass);
      expect(candidate.output['deviceCount'], 3);
      expect(candidate.output['addressCount'], 4);
      expect(candidate.output['deviceHeadroom'], 1);
      expect(candidate.output['addressHeadroom'], 1);
    },
  );

  test('reserved address collision is an engineering FAIL', () async {
    final resolver = Fa01PersistedInputResolver(
      fireStore: _FireStore(reserved: const <int>[11]),
      contractSource: _ContractSource(_contract()),
    );
    final captured = await resolver.capture(_request());
    final candidate = await buildFa01Executor().execute(captured);
    expect(candidate.assessment, Elv5Assessment.fail);
    final collisions = candidate.output['collisions']! as List<Object?>;
    expect(collisions, isNotEmpty);
  });

  test('missing immutable profile resource evidence becomes BLOCKED', () async {
    final contract = Fa01AddressCapacityContract(
      loopId: 'loop-1',
      deviceLimit: 4,
      addressLimit: 5,
      requiredDeviceSpare: 0,
      requiredAddressSpare: 0,
      profileAddressConsumption: const <String, int>{'single': 1},
      profileDeviceCountContribution: const <String, int>{'single': 1},
    );
    final resolver = Fa01PersistedInputResolver(
      fireStore: _FireStore(reserved: const <int>[]),
      contractSource: _ContractSource(contract),
    );
    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>().having(
          (value) => value.reasonCode,
          'reasonCode',
          'FA01_PROFILE_RESOURCE_EVIDENCE_MISSING',
        ),
      ),
    );
  });
}

Fa01AddressCapacityContract _contract() => Fa01AddressCapacityContract(
  loopId: 'loop-1',
  deviceLimit: 4,
  addressLimit: 5,
  requiredDeviceSpare: 0,
  requiredAddressSpare: 0,
  profileAddressConsumption: const <String, int>{'single': 1, 'dual': 2},
  profileDeviceCountContribution: const <String, int>{'single': 1, 'dual': 1},
);

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'p',
  designRevisionId: 'd',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'd',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.fa01,
  subject: Elv5SubjectRef(kind: 'FIRE_LOOP', id: 'loop-1'),
  expectedPointerGeneration: 0,
);

final class _FireStore implements Elv5FireFactStore {
  const _FireStore({required this.reserved});
  final List<int> reserved;
  @override
  Future<Elv5FireAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) async => Elv5FireAggregateSnapshot(
    aggregateKind: 'FIRE_LOOP',
    aggregateId: 'ELV5:FIRE_LOOP:loop-1',
    subjectId: 'loop-1',
    revision: 2,
    payload: <String, Object?>{
      'loopId': 'loop-1',
      'topologyProfileRef': <String, Object?>{
        'profileCode': 'CLASS-A',
        'editionId': 'v1',
        'contentHash': _hash('a'),
      },
      'addressDomain': <String, Object?>{
        'panelId': 'panel-1',
        'loopId': 'loop-1',
        'minAddress': 10,
        'maxAddress': 14,
        'reservedAddresses': reserved,
      },
      'deviceAssignments': <Object?>[
        <String, Object?>{
          'deviceId': 'd1',
          'profileRef': 'single',
          'expandedAddresses': <int>[10],
        },
        <String, Object?>{
          'deviceId': 'd2',
          'profileRef': 'single',
          'expandedAddresses': <int>[11],
        },
        <String, Object?>{
          'deviceId': 'd3',
          'profileRef': 'dual',
          'expandedAddresses': <int>[12, 13],
        },
      ],
    },
  );
}

final class _ContractSource implements Fa01AddressCapacityContractSource {
  const _ContractSource(this.contract);
  final Fa01AddressCapacityContract contract;
  @override
  Future<Fa01AddressCapacityContractSnapshot?> loadActiveForLoop({
    required String projectId,
    required String designRevisionId,
    required String loopId,
  }) async => Fa01AddressCapacityContractSnapshot(
    bindingId: 'fa01-binding',
    bindingRevision: 1,
    evidenceRef: 'FA01:loop-1:${_hash('b')}',
    contentHash: _hash('b'),
    contract: contract,
  );
}

String _hash(String char) => List<String>.filled(64, char).join();
