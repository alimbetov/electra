import 'package:electra_mobile/application/elv5/acs/acs03_electrical_contract.dart';
import 'package:electra_mobile/application/elv5/acs/acs03_runtime.dart';
import 'package:electra_mobile/application/elv5/acs/elv5_acs_persistence.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/power/elv4_current_evidence_source.dart';
import 'package:engineering_core/engineering_core.dart'
    show PowerEvaluationScopeKind, PowerProcessCode;
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blocks when exact ACS-03 event/feed/control contract is not persisted', () async {
    final resolver = Acs03PersistedInputResolver(
      acsStore: _AcsStore(),
      contractSource: const _NoContractSource(),
      powerEvidence: const _NoPowerEvidence(),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>()
            .having(
              (value) => value.reasonCode,
              'reasonCode',
              'ACS03_EXACT_ELECTRICAL_EVENT_CONTRACT_REQUIRED',
            )
            .having(
              (value) => value.evidence['lockId'],
              'lockId',
              'lock-1',
            ),
      ),
    );
  });

  test('kernel blocks a resolved feed when control path evidence is absent', () {
    final result = const Acs03ElectricalKernel().evaluate(
      Acs03Input(
        doorId: 'door-1',
        lockId: 'lock-1',
        conductiveFeedPathId: 'feed-1',
        controlPathId: null,
        requiredMembershipFingerprint: 'membership-1',
        events: <Acs03OperatingEvent>[
          Acs03OperatingEvent(
            eventId: 'holding',
            state: Acs03StateCode.holding,
            durationMicroseconds: BigInt.from(1000000),
          ),
        ],
        evidence: const <Acs03PwrEvidence>[],
      ),
    );

    expect(result.status, Acs03AssessmentStatus.blocked);
    expect(result.limitingReason, 'ACS03_REQUIRED_CONTROL_PATH_MISSING');
  });
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'p',
  designRevisionId: 'd',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'd',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.acs03,
  subject: Elv5SubjectRef(kind: 'DOOR', id: 'door-1'),
  expectedPointerGeneration: 0,
);

final class _AcsStore implements Elv5AcsMutationStore {
  @override
  Future<Elv5AcsAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) async => Elv5AcsAggregateSnapshot(
    aggregateKind: 'ACS_DOOR_CALCULATION',
    aggregateId: 'door-binding-1',
    subjectId: 'door-1',
    revision: 2,
    payload: <String, Object?>{
      'doorAssemblyId': 'door-1',
      'topologyProfileRef': <String, Object?>{'id': 'profile-1'},
      'safetyMode': 'FAIL_SAFE',
      'roleAssignments': <Object?>[
        <String, Object?>{
          'assignmentId': 'a1',
          'componentId': 'lock-1',
          'roleCode': 'LOCK',
        },
      ],
      'releaseTruthTable': <Object?>[],
    },
  );

  @override
  Future<void> replace({required String projectId, required String designRevisionId, required String operation, required String subjectId, required String bindingId, required int? expectedRootRevision, required Map<String, Object?> payload, required DateTime updatedAtUtc}) => throw UnimplementedError();
}

final class _NoContractSource implements Acs03ElectricalContractSource {
  const _NoContractSource();

  @override
  Future<Acs03ElectricalContractSnapshot?> loadActiveForDoor({
    required String projectId,
    required String designRevisionId,
    required String doorId,
  }) async => null;
}

final class _NoPowerEvidence implements Elv4CurrentEvidenceSource {
  const _NoPowerEvidence();

  @override
  Future<List<Elv4CurrentEvaluationSnapshot>> loadCurrent({
    required String projectId,
    required String designRevisionId,
    required PowerProcessCode processCode,
    String? scenarioId,
    PowerEvaluationScopeKind? scopeKind,
    String? scopeId,
    String? subjectKind,
    String? subjectId,
  }) async => const <Elv4CurrentEvaluationSnapshot>[];
}
