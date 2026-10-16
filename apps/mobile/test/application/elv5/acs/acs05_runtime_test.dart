import 'package:electra_mobile/application/elv5/acs/acs05_autonomy_contract.dart';
import 'package:electra_mobile/application/elv5/acs/acs05_runtime.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/power/elv4_current_evidence_source.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

String _hash(String ch) => List<String>.filled(64, ch).join();

void main() {
  test('projects global PWR-04 energy and ACS contributor energy', () async {
    final pwr01 = _pwr01();
    final pwr04 = _pwr04(pwr01: pwr01, inputFingerprint: _hash('a'));
    final resolver = Acs05PersistedInputResolver(
      contractSource: _ContractSource(_contract(_hash('a'))),
      powerEvidence: _EvidenceSource(<Elv4CurrentEvaluationSnapshot>[pwr01, pwr04]),
      nowUtc: () => DateTime.utc(2026, 10, 17),
    );

    final captured = await resolver.capture(_request());
    final result = await buildAcs05Executor(
      nowUtc: () => DateTime.utc(2026, 10, 17),
    ).execute(captured);

    expect(result.assessment, Elv5Assessment.pass);
    expect(
      result.output['globalRequiredEnergyWh'],
      Elv5Rational.parseDecimal('19.2').toMap(),
    );
    expect(
      result.output['availableEnergyWh'],
      Elv5Rational.parseDecimal('134.4').toMap(),
    );
    expect(
      result.output['energyMarginWh'],
      Elv5Rational.parseDecimal('115.2').toMap(),
    );
    expect(
      result.output['acsContributionEnergyWh'],
      Elv5Rational.parseDecimal('10').toMap(),
    );
    expect(result.output['governingSegmentId'], isNull);
  });

  test('blocks stale PWR-04 consumed-input identity', () async {
    final pwr01 = _pwr01();
    final pwr04 = _pwr04(pwr01: pwr01, inputFingerprint: _hash('b'));
    final resolver = Acs05PersistedInputResolver(
      contractSource: _ContractSource(_contract(_hash('a'))),
      powerEvidence: _EvidenceSource(<Elv4CurrentEvaluationSnapshot>[pwr01, pwr04]),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>().having(
          (value) => value.reasonCode,
          'reasonCode',
          'ACS05_PWR04_INPUT_FINGERPRINT_MISMATCH',
        ),
      ),
    );
  });

  test('blocks when policy requires unsupported peak/EOD dimensions', () async {
    final pwr01 = _pwr01();
    final pwr04 = _pwr04(pwr01: pwr01, inputFingerprint: _hash('a'));
    final base = _contract(_hash('a'));
    final strict = Acs05AutonomyContract(
      bankId: base.bankId,
      scenarioId: base.scenarioId,
      sequenceId: base.sequenceId,
      expectedPwr04InputFingerprint: base.expectedPwr04InputFingerprint,
      segments: base.segments,
      globalProtectedLoadIds: base.globalProtectedLoadIds,
      acsProtectedLoadIds: base.acsProtectedLoadIds,
      requirePeakCurrentEvidence: true,
    );
    final resolver = Acs05PersistedInputResolver(
      contractSource: _ContractSource(strict),
      powerEvidence: _EvidenceSource(<Elv4CurrentEvaluationSnapshot>[pwr01, pwr04]),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>().having(
          (value) => value.reasonCode,
          'reasonCode',
          'ACS05_PWR04_REQUIRED_DIMENSION_UNSUPPORTED',
        ),
      ),
    );
  });
}

Acs05AutonomyContract _contract(String pwr04InputFingerprint) =>
    Acs05AutonomyContract(
      bankId: 'bank-1',
      scenarioId: 'BACKUP',
      sequenceId: 'sequence-1',
      expectedPwr04InputFingerprint: pwr04InputFingerprint,
      segments: <Acs05SequenceSegmentContract>[
        Acs05SequenceSegmentContract(
          segmentId: 'standby',
          durationMicroseconds: BigInt.from(3600000000),
        ),
      ],
      globalProtectedLoadIds: const <String>{'acs-lock', 'fire-loop'},
      acsProtectedLoadIds: const <String>{'acs-lock'},
    );

Elv4CurrentEvaluationSnapshot _pwr01() {
  final key = PowerNodeKeyV2(
    revisionId: 'd',
    scenarioId: 'BACKUP',
    scopeKind: PowerEvaluationScopeKind.segment,
    scopeId: 'standby',
    processCode: PowerProcessCode.pwr01,
    subjectKind: 'BACKUP_SEGMENT',
    subjectId: 'standby-demand',
  );
  return Elv4CurrentEvaluationSnapshot(
    nodeKey: key,
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
}

Elv4CurrentEvaluationSnapshot _pwr04({
  required Elv4CurrentEvaluationSnapshot pwr01,
  required String inputFingerprint,
}) {
  final key = PowerNodeKeyV2(
    revisionId: 'd',
    scenarioId: 'BACKUP',
    scopeKind: PowerEvaluationScopeKind.sequence,
    scopeId: 'BACKUP',
    processCode: PowerProcessCode.pwr04,
    subjectKind: 'BATTERY_BANK',
    subjectId: 'bank-1',
  );
  return Elv4CurrentEvaluationSnapshot(
    nodeKey: key,
    evaluationId: 'pwr04-eval',
    inputFingerprint: inputFingerprint,
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

Elv5CalculationRequest _request() => Elv5CalculationRequest(
      projectId: 'p',
      designRevisionId: 'd',
      scope: Elv5ScopeRef(
        kind: Elv5ScopeKind.design,
        scopeId: 'd',
        scenarioKey: 'BACKUP',
      ),
      processCode: Elv5ProcessCode.acs05,
      subject: Elv5SubjectRef(kind: 'POWER_BANK', id: 'bank-1'),
      expectedPointerGeneration: 0,
    );

final class _ContractSource implements Acs05AutonomyContractSource {
  _ContractSource(this.contract);

  final Acs05AutonomyContract contract;

  @override
  Future<Acs05AutonomyContractSnapshot?> loadActiveForBank({
    required String projectId,
    required String designRevisionId,
    required String bankId,
  }) async => Acs05AutonomyContractSnapshot(
        bindingId: 'binding-1',
        bindingRevision: 2,
        evidenceRef: 'ACS05:bank-1:${_hash('9')}',
        contentHash: _hash('9'),
        contract: contract,
      );
}

final class _EvidenceSource implements Elv4CurrentEvidenceSource {
  _EvidenceSource(this.values);

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
