import 'package:electra_mobile/application/elv5/acs/acs06_runtime.dart';
import 'package:electra_mobile/application/elv5/acs/acs06_topology_contract.dart';
import 'package:electra_mobile/application/elv5/acs/elv5_acs_persistence.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ACS-06 validates five release causes and fail-safe power failure', () async {
    final payload = _payload();
    final contract = _contract(_fingerprint(payload));
    final resolver = Acs06PersistedInputResolver(
      acsStore: _AcsStore(payload),
      contractSource: _ContractSource(contract),
      nowUtc: () => DateTime.utc(2026, 10, 17),
    );

    final captured = await resolver.capture(_request());
    final candidate = await buildAcs06Executor().execute(captured);

    expect(candidate.assessment, Elv5Assessment.pass);
    expect(candidate.output['status'], 'pass');
    final causes = Map<String, Object?>.from(candidate.output['causes']! as Map);
    expect(causes, hasLength(5));
    final powerFailure = Map<String, Object?>.from(causes['powerFailure']! as Map);
    expect(powerFailure['modeledOutcome'], 'released');
    expect(powerFailure['expectedOutcome'], 'released');
  });

  test('ACS-06 stale topology edition remains BLOCKED', () async {
    final payload = _payload();
    final resolver = Acs06PersistedInputResolver(
      acsStore: _AcsStore(payload),
      contractSource: _ContractSource(_contract(_hash('f'))),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>().having(
          (e) => e.reasonCode,
          'reasonCode',
          'ACS06_DOOR_AGGREGATE_FINGERPRINT_MISMATCH',
        ),
      ),
    );
  });
}

Map<String, Object?> _payload() => <String, Object?>{
      'doorAssemblyId': 'door-1',
      'topologyProfileRef': <String, Object?>{
        'profileCode': 'ACS-DOOR-SINGLE',
        'editionId': 'v1',
        'contentHash': _hash('a'),
      },
      'safetyMode': 'FAIL_SAFE',
      'roleAssignments': <Object?>[
        <String, Object?>{'roleCode': 'READER_ENTRY', 'slot': 0, 'componentId': 'reader'},
        <String, Object?>{'roleCode': 'REQUEST_TO_EXIT', 'slot': 0, 'componentId': 'rte'},
        <String, Object?>{'roleCode': 'FIRE_RELEASE_INPUT', 'slot': 0, 'componentId': 'fire'},
        <String, Object?>{'roleCode': 'EMERGENCY_RELEASE', 'slot': 0, 'componentId': 'breakglass'},
        <String, Object?>{'roleCode': 'DOOR_CONTACT', 'slot': 0, 'componentId': 'contact'},
        <String, Object?>{'roleCode': 'LOCK', 'slot': 0, 'componentId': 'lock'},
      ],
      'releaseTruthTable': <Object?>[
        <String, Object?>{
          'causeCode': 'NORMAL_ACCESS',
          'expectedOutcomeCode': 'UNLOCKED',
          'requiredEvidenceRoles': <String>['READER_ENTRY', 'LOCK'],
        },
        <String, Object?>{
          'causeCode': 'REQUEST_TO_EXIT',
          'expectedOutcomeCode': 'UNLOCKED',
          'requiredEvidenceRoles': <String>['REQUEST_TO_EXIT', 'LOCK'],
        },
        <String, Object?>{
          'causeCode': 'FIRE_RELEASE',
          'expectedOutcomeCode': 'UNLOCKED',
          'requiredEvidenceRoles': <String>['FIRE_RELEASE_INPUT', 'LOCK'],
        },
        <String, Object?>{
          'causeCode': 'EMERGENCY_BREAK_GLASS',
          'expectedOutcomeCode': 'UNLOCKED',
          'requiredEvidenceRoles': <String>['EMERGENCY_RELEASE', 'LOCK'],
        },
        <String, Object?>{
          'causeCode': 'POWER_FAILURE',
          'expectedOutcomeCode': 'UNLOCKED',
          'requiredEvidenceRoles': <String>['LOCK'],
        },
      ],
    };

Acs06TopologyContract _contract(String aggregateFingerprint) => Acs06TopologyContract(
      doorId: 'door-1',
      expectedDoorAggregateFingerprint: aggregateFingerprint,
      topologyProfile: Acs06TopologyProfileIdentity(
        profileCode: 'ACS-DOOR-SINGLE',
        editionId: 'v1',
        contentHash: _hash('a'),
      ),
      componentNodeIdByComponentId: const <String, String>{
        'reader': 'reader-node',
        'rte': 'rte-node',
        'fire': 'fire-node',
        'breakglass': 'breakglass-node',
        'contact': 'contact-node',
        'lock': 'lock-node',
      },
      edges: <Acs06TopologyEdgeContract>[
        Acs06TopologyEdgeContract(
          edgeId: 'reader-control',
          fromNodeId: 'reader-node',
          toNodeId: 'lock-node',
          kindCode: 'CONTROL',
        ),
        Acs06TopologyEdgeContract(
          edgeId: 'rte-control',
          fromNodeId: 'rte-node',
          toNodeId: 'lock-node',
          kindCode: 'CONTROL',
        ),
        Acs06TopologyEdgeContract(
          edgeId: 'fire-release',
          fromNodeId: 'fire-node',
          toNodeId: 'lock-node',
          kindCode: 'RELEASE',
        ),
        Acs06TopologyEdgeContract(
          edgeId: 'breakglass-release',
          fromNodeId: 'breakglass-node',
          toNodeId: 'lock-node',
          kindCode: 'RELEASE',
        ),
        Acs06TopologyEdgeContract(
          edgeId: 'contact-monitor',
          fromNodeId: 'contact-node',
          toNodeId: 'lock-node',
          kindCode: 'MONITOR',
        ),
        Acs06TopologyEdgeContract(
          edgeId: 'psu-feed',
          fromNodeId: 'psu-node',
          toNodeId: 'lock-node',
          kindCode: 'POWER_FEED',
        ),
      ],
      causeProfiles: <Acs06CauseProfileContract>[
        _cause('NORMAL_ACCESS', 'reader-node', 'CONTROL'),
        _cause('REQUEST_TO_EXIT', 'rte-node', 'CONTROL'),
        _cause('FIRE_RELEASE', 'fire-node', 'RELEASE'),
        _cause('EMERGENCY_BREAK_GLASS', 'breakglass-node', 'RELEASE'),
        Acs06CauseProfileContract(
          causeCode: 'POWER_FAILURE',
          requiredPaths: const <Acs06PathRequirementContract>[],
          outcomeWhenSatisfiedCode: 'UNLOCKED',
          requiresConductiveFeed: false,
          requiresSupervision: false,
        ),
      ],
    );

Acs06CauseProfileContract _cause(String code, String source, String kind) =>
    Acs06CauseProfileContract(
      causeCode: code,
      requiredPaths: <Acs06PathRequirementContract>[
        Acs06PathRequirementContract(
          requirementId: '$code-PATH',
          fromNodeId: source,
          toNodeId: 'lock-node',
          allowedKindCodes: <String>[kind],
        ),
      ],
      outcomeWhenSatisfiedCode: 'UNLOCKED',
      requiresConductiveFeed: false,
      requiresSupervision: false,
    );

Elv5CalculationRequest _request() => Elv5CalculationRequest(
      projectId: 'p',
      designRevisionId: 'd',
      scope: Elv5ScopeRef(
        kind: Elv5ScopeKind.design,
        scopeId: 'd',
        scenarioKey: 'NONE',
      ),
      processCode: Elv5ProcessCode.acs06,
      subject: Elv5SubjectRef(kind: 'DOOR', id: 'door-1'),
      expectedPointerGeneration: 0,
    );

final class _AcsStore implements Elv5AcsFactStore {
  const _AcsStore(this.payload);
  final Map<String, Object?> payload;

  @override
  Future<Elv5AcsAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) async => Elv5AcsAggregateSnapshot(
        aggregateKind: 'ACS_DOOR_CALCULATION',
        aggregateId: 'ELV5:ACS_DOOR_CALCULATION:door-1',
        subjectId: 'door-1',
        revision: 4,
        payload: payload,
      );
}

final class _ContractSource implements Acs06TopologyContractSource {
  const _ContractSource(this.contract);
  final Acs06TopologyContract contract;

  @override
  Future<Acs06TopologyContractSnapshot?> loadActiveForDoor({
    required String projectId,
    required String designRevisionId,
    required String doorId,
  }) async => Acs06TopologyContractSnapshot(
        bindingId: 'acs06-binding',
        bindingRevision: 2,
        evidenceRef: 'ACS06:door-1:${_hash('b')}',
        contentHash: _hash('b'),
        contract: contract,
      );
}

String _fingerprint(Map<String, Object?> payload) =>
    const Elv5CanonicalJsonV1().sha256(payload);
String _hash(String char) => List<String>.filled(64, char).join();
