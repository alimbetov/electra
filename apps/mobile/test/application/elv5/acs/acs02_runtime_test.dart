import 'package:electra_mobile/application/elv5/acs/acs02_resource_contract.dart';
import 'package:electra_mobile/application/elv5/acs/acs02_runtime.dart';
import 'package:electra_mobile/application/elv5/acs/elv5_acs_persistence.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ACS02 evaluates independent resource pools with exact spare rules',
    () async {
      final payload = _payload();
      final resolver = Acs02PersistedInputResolver(
        acsStore: _Store(payload),
        contractSource: _Contracts(_contract(payload)),
        nowUtc: () => DateTime.utc(2026, 10, 17),
      );

      final captured = await resolver.capture(_request());
      final result = await buildAcs02Executor().execute(captured);

      expect(result.assessment, Elv5Assessment.pass);
      expect(result.output['status'], 'pass');
      final pools = <Map<String, Object?>>[
        for (final raw in result.output['pools']! as List)
          Map<String, Object?>.from(raw as Map),
      ];
      final byKind = <String, Map<String, Object?>>{
        for (final row in pools) row['resourceKind']! as String: row,
      };
      expect(byKind['reader']!['headroom'], 0);
      expect(byKind['relay']!['headroom'], 0);
      expect(byKind['supervisedInput']!['headroom'], 0);
      expect(byKind['other']!['headroom'], 1);
    },
  );

  test(
    'ACS02 duplicate physical relay assignment fails without borrowing reader capacity',
    () async {
      final payload = _payload(duplicateRelay: true);
      final resolver = Acs02PersistedInputResolver(
        acsStore: _Store(payload),
        contractSource: _Contracts(_contract(payload)),
      );

      final result = await buildAcs02Executor().execute(
        await resolver.capture(_request()),
      );

      expect(result.assessment, Elv5Assessment.fail);
      expect(result.output['conflictingAssignmentIds'], isNotEmpty);
    },
  );

  test('ACS02 stale reserve policy identity is capture BLOCKED', () async {
    final payload = _payload();
    final contract = _contract(payload, policyEdition: 'spare-v2');
    final resolver = Acs02PersistedInputResolver(
      acsStore: _Store(payload),
      contractSource: _Contracts(contract),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>().having(
          (e) => e.reasonCode,
          'reasonCode',
          'ACS02_RESERVE_POLICY_IDENTITY_MISMATCH',
        ),
      ),
    );
  });
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'project',
  designRevisionId: 'revision',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'revision',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.acs02,
  subject: Elv5SubjectRef(kind: 'CONTROLLER', id: 'controller-1'),
  expectedPointerGeneration: 0,
);

Map<String, Object?> _payload({bool duplicateRelay = false}) =>
    <String, Object?>{
      'controllerId': 'controller-1',
      'resourceAssignments': <Object?>[
        <String, Object?>{
          'resourceId': 'reader-1',
          'resourceKind': 'READER_CHANNEL',
          'assignmentRole': 'READER_ENTRY',
          'subjectId': 'door-1',
        },
        <String, Object?>{
          'resourceId': 'reader-2',
          'resourceKind': 'READER_CHANNEL',
          'assignmentRole': 'READER_ENTRY',
          'subjectId': 'door-2',
        },
        <String, Object?>{
          'resourceId': 'reader-3',
          'resourceKind': 'READER_CHANNEL',
          'assignmentRole': 'READER_ENTRY',
          'subjectId': 'door-3',
        },
        <String, Object?>{
          'resourceId': 'relay-1',
          'resourceKind': 'RELAY_OUTPUT',
          'assignmentRole': 'LOCK',
          'subjectId': 'door-1',
        },
        <String, Object?>{
          'resourceId': 'relay-2',
          'resourceKind': 'RELAY_OUTPUT',
          'assignmentRole': 'LOCK',
          'subjectId': 'door-2',
        },
        if (duplicateRelay)
          <String, Object?>{
            'resourceId': 'relay-1',
            'resourceKind': 'RELAY_OUTPUT',
            'assignmentRole': 'LOCK',
            'subjectId': 'door-3',
          },
        <String, Object?>{
          'resourceId': 'input-1',
          'resourceKind': 'SUPERVISED_INPUT',
          'assignmentRole': 'DOOR_CONTACT',
          'subjectId': 'door-1',
        },
      ],
      'reservePolicyRef': <String, Object?>{
        'policyCode': 'ACS-CONTROLLER-SPARE',
        'editionId': 'spare-v1',
        'contentHash': _hash('b'),
      },
    };

Acs02ResourceContract _contract(
  Map<String, Object?> payload, {
  String policyEdition = 'spare-v1',
}) => Acs02ResourceContract(
  controllerId: 'controller-1',
  expectedControllerAggregateFingerprint: const Elv5CanonicalJsonV1().sha256(
    payload,
  ),
  reservePolicy: Acs02PolicyIdentity(
    policyCode: 'ACS-CONTROLLER-SPARE',
    editionId: policyEdition,
    contentHash: _hash('b'),
  ),
  resources: <Acs02ResourceContractItem>[
    for (final id in const ['reader-1', 'reader-2', 'reader-3', 'reader-4'])
      Acs02ResourceContractItem(
        resourceId: id,
        resourceKindCode: 'READER_CHANNEL',
      ),
    for (final id in const ['relay-1', 'relay-2'])
      Acs02ResourceContractItem(
        resourceId: id,
        resourceKindCode: 'RELAY_OUTPUT',
      ),
    for (final id in const ['input-1', 'input-2'])
      Acs02ResourceContractItem(
        resourceId: id,
        resourceKindCode: 'SUPERVISED_INPUT',
      ),
    Acs02ResourceContractItem(resourceId: 'other-1', resourceKindCode: 'OTHER'),
  ],
  spareRules: <Acs02SpareRuleContract>[
    Acs02SpareRuleContract(
      resourceKindCode: 'READER_CHANNEL',
      absoluteMinimum: 1,
      ratio: Elv5Rational.zero,
    ),
    Acs02SpareRuleContract(
      resourceKindCode: 'RELAY_OUTPUT',
      absoluteMinimum: 0,
      ratio: Elv5Rational.zero,
    ),
    Acs02SpareRuleContract(
      resourceKindCode: 'SUPERVISED_INPUT',
      absoluteMinimum: 1,
      ratio: Elv5Rational.zero,
    ),
    Acs02SpareRuleContract(
      resourceKindCode: 'OTHER',
      absoluteMinimum: 0,
      ratio: Elv5Rational.zero,
    ),
  ],
);

final class _Store implements Elv5AcsFactStore {
  const _Store(this.payload);
  final Map<String, Object?> payload;

  @override
  Future<Elv5AcsAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) async => Elv5AcsAggregateSnapshot(
    aggregateKind: 'ACS_CONTROLLER_RESOURCES',
    aggregateId: 'ELV5:ACS_CONTROLLER_RESOURCES:controller-1',
    subjectId: 'controller-1',
    revision: 7,
    payload: payload,
  );
}

final class _Contracts implements Acs02ResourceContractSource {
  const _Contracts(this.contract);
  final Acs02ResourceContract contract;

  @override
  Future<Acs02ResourceContractSnapshot?> loadActiveForController({
    required String projectId,
    required String designRevisionId,
    required String controllerId,
  }) async => Acs02ResourceContractSnapshot(
    bindingId: 'acs02-binding',
    bindingRevision: 2,
    evidenceRef: 'ACS02:controller-1:${_hash('c')}',
    contentHash: _hash('c'),
    contract: contract,
  );
}

String _hash(String char) => List<String>.filled(64, char).join();
