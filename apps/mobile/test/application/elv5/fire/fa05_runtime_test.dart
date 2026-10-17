import 'dart:convert';

import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/fire/fa05_autonomy_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa05_runtime.dart';
import 'package:electra_mobile/application/elv5/power/elv4_current_evidence_source.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

String _hash(String ch) => List<String>.filled(64, ch).join();

void main() {
  test('projects Fire contribution from the same global PWR-04/PWR-01 chain', () async {
    final pwr01 = _pwr01();
    final pwr04 = _pwr04(pwr01);
    final resolver = Fa05PersistedInputResolver(
      contractSource: _ContractSource(_contract()),
      powerEvidence: _EvidenceSource([pwr01, pwr04]),
      nowUtc: () => DateTime.utc(2026, 10, 17),
    );

    final captured = await resolver.capture(_request());
    final result = const Fa05AutonomyProjectionKernel().evaluate(captured.value);
    expect(result.status, Fa05AssessmentStatus.pass);
    expect(result.globalRequiredEnergy.value, Elv5Rational.parseDecimal('19.2'));
    expect(result.availableEnergy.value, Elv5Rational.parseDecimal('134.4'));
    expect(result.energyMargin.value, Elv5Rational.parseDecimal('115.2'));
    expect(result.fireContributionEnergy.value, Elv5Rational.parseDecimal('9.2'));
    expect(result.governingSegmentId, isNull);
  });
}

Fa05AutonomyContract _contract() => Fa05AutonomyContract(
      bankId: 'bank-1',
      scenarioId: 'BACKUP',
      sequenceId: 'sequence-1',
      expectedPwr04InputFingerprint: _hash('a'),
      segments: [
        Fa05SequenceSegmentContract(
          segmentId: 'standby',
          durationMicroseconds: BigInt.from(3600000000),
        ),
      ],
      globalProtectedLoadIds: const {'acs-lock', 'fire-loop'},
      fireProtectedLoadIds: const {'fire-loop'},
    );

Elv5CalculationRequest _request() => Elv5CalculationRequest(
      projectId: 'p',
      designRevisionId: 'd',
      scope: Elv5ScopeRef(
        kind: Elv5ScopeKind.design,
        scopeId: 'd',
        scenarioKey: 'BACKUP',
      ),
      processCode: Elv5ProcessCode.fa05,
      subject: Elv5SubjectRef(kind: 'POWER_BANK', id: 'bank-1'),
      expectedPointerGeneration: 0,
    );

final class _ContractSource implements Fa05AutonomyContractSource {
  const _ContractSource(this.contract);
  final Fa05AutonomyContract contract;

  @override
  Future<Fa05AutonomyContractSnapshot?> loadActiveForBank({
    required String projectId,
    required String designRevisionId,
    required String bankId,
  }) async => Fa05AutonomyContractSnapshot(
        bindingId: 'fa05-binding',
        bindingRevision: 1,
        evidenceRef: 'FA05:bank-1:${_hash('9')}',
        contentHash: _hash('9'),
        contract: contract,
      );
}

final class _EvidenceSource implements Elv4CurrentEvidenceSource {
  const _EvidenceSource(this.values);
  final List<Elv4CurrentEvaluationSnapshot> values;

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
  }) async => values.where((value) {
        final key = value.nodeKey;
        return key.processCode == processCode &&
            (scenarioId == null || key.scenarioId == scenarioId) &&
            (scopeKind == null || key.scopeKind == scopeKind) &&
            (scopeId == null || key.scopeId == scopeId) &&
            (subjectKind == null || key.subjectKind == subjectKind) &&
            (subjectId == null || key.subjectId == subjectId);
      }).toList();
}

Elv4CurrentEvaluationSnapshot _pwr01() => Elv4CurrentEvaluationSnapshot(
      nodeKey: PowerNodeKeyV2(
        revisionId: 'd',
        scenarioId: 'BACKUP',
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: 'standby',
        processCode: PowerProcessCode.pwr01,
        subjectKind: 'BACKUP_SEGMENT',
        subjectId: 'standby-demand',
      ),
      evaluationId: 'pwr01-eval',
      inputFingerprint: _hash('1'),
      evidenceSha256: _hash('2'),
      pointerGeneration: 3,
      evidence: <String, Object?>{
        'inputs': <String, Object?>{
          'contributions': <Object?>[
            <String, Object?>{
              'originId': 'acs-lock',
              'componentId': 'lock-1',
              'inputPortId': 'lock-in',
              'stateCode': 'STANDBY',
              'demand': <String, Object?>{
                'kind': 'DC_CONSTANT_POWER',
                'powerW': '10',
              },
              'solvedTerminalVoltageV': null,
            },
            <String, Object?>{
              'originId': 'fire-loop',
              'componentId': 'fire-1',
              'inputPortId': 'fire-in',
              'stateCode': 'STANDBY',
              'demand': <String, Object?>{
                'kind': 'DC_CONSTANT_POWER',
                'powerW': '9.2',
              },
              'solvedTerminalVoltageV': null,
            },
          ],
        },
        'output': <String, Object?>{
          'knownW': PowerRational.parseDecimal('19.2').toMap(),
          'knownA': PowerRational.zero.toMap(),
          'knownVa': PowerRational.zero.toMap(),
          'completeW': true,
          'completeA': false,
          'completeVa': false,
        },
      },
    );

Elv4CurrentEvaluationSnapshot _pwr04(Elv4CurrentEvaluationSnapshot pwr01) {
  final sequenceValue = <String, Object?>{
    'segments': <Object?>[
      <String, Object?>{
        'segmentId': 'standby',
        'durationSeconds': PowerRational.integer(3600).toMap(),
        'bankInputW': PowerRational.parseDecimal('19.2').toMap(),
      },
    ],
    'extensionPolicy': 'NONE',
  };
  return Elv4CurrentEvaluationSnapshot(
    nodeKey: PowerNodeKeyV2(
      revisionId: 'd',
      scenarioId: 'BACKUP',
      scopeKind: PowerEvaluationScopeKind.sequence,
      scopeId: 'BACKUP',
      processCode: PowerProcessCode.pwr04,
      subjectKind: 'BATTERY_BANK',
      subjectId: 'bank-1',
    ),
    evaluationId: 'pwr04-eval',
    inputFingerprint: _hash('a'),
    evidenceSha256: _hash('4'),
    pointerGeneration: 5,
    evidence: <String, Object?>{
      'inputs': <String, Object?>{
        'sequenceId': 'sequence-1',
        'bankId': 'bank-1',
      },
      'output': <String, Object?>{
        'requiredWh': PowerRational.parseDecimal('19.2').toMap(),
        'availableWh': PowerRational.parseDecimal('134.4').toMap(),
        'marginWh': PowerRational.parseDecimal('115.2').toMap(),
        'sequenceDurationSeconds': PowerRational.integer(3600).toMap(),
        'estimatedAutonomySeconds': null,
      },
      'consumedFacts': <Object?>[
        <String, Object?>{
          'key': 'unused-by-fa05-test',
          'valueSchema': 'electra.elv4.backup-sequence.v1',
          'canonicalValueJson': jsonEncode(sequenceValue),
          'presence': 'PRESENT',
        },
      ],
      'consumedEvaluations': <Object?>[
        <String, Object?>{
          'logicalNodeKey': pwr01.nodeKey.encode(),
          'evaluationId': pwr01.evaluationId,
          'inputFingerprint': pwr01.inputFingerprint,
        },
      ],
    },
  );
}
