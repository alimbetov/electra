import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/fire/fa03_runtime.dart';
import 'package:electra_mobile/application/elv5/fire/fa03_terminal_voltage_contract.dart';
import 'package:electra_mobile/application/elv5/power/elv4_current_evidence_source.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'projects exact CURRENT PWR-03 terminal range without local voltage solve',
    () async {
      final fingerprint = _hash('a');
      final resolver = Fa03PersistedInputResolver(
        contractSource: _ContractSource(_contract(fingerprint)),
        powerEvidence: _EvidenceSource(_pwr03(fingerprint)),
        nowUtc: () => DateTime.utc(2026, 10, 17),
      );

      final captured = await resolver.capture(_request());
      final candidate = await buildFa03Executor(
        nowUtc: () => DateTime.utc(2026, 10, 17),
      ).execute(captured);

      expect(candidate.assessment, Elv5Assessment.pass);
      final terminals = candidate.output['terminals']! as List<Object?>;
      final terminal = terminals.single as Map<String, Object?>;
      expect(terminal['terminalId'], 'last-device');
      expect(
        terminal['voltageLowerV'],
        Elv5Rational.parseDecimal('23.9').toMap(),
      );
      expect(terminal['lowMarginV'], Elv5Rational.parseDecimal('1.9').toMap());
      expect(terminal['highMarginV'], Elv5Rational.parseDecimal('2.1').toMap());
    },
  );

  test(
    'F2 Q6 captures exact upstream generation and changes identity after republish',
    () async {
      final fingerprint = _hash('a');
      final contractSource = _ContractSource(_contract(fingerprint));
      final firstResolver = Fa03PersistedInputResolver(
        contractSource: contractSource,
        powerEvidence: _EvidenceSource(
          _pwr03(fingerprint, evaluationId: 'pwr03-eval-g4', generation: 4),
        ),
        nowUtc: () => DateTime.utc(2026, 10, 17),
      );
      final secondResolver = Fa03PersistedInputResolver(
        contractSource: contractSource,
        powerEvidence: _EvidenceSource(
          _pwr03(fingerprint, evaluationId: 'pwr03-eval-g5', generation: 5),
        ),
        nowUtc: () => DateTime.utc(2026, 10, 17),
      );

      final first = await firstResolver.capture(_request());
      final replay = await firstResolver.capture(_request());
      final republished = await secondResolver.capture(_request());
      final upstreamNode = _pwr03(fingerprint).nodeKey.sha256;

      expect(first.upstreamPointerGenerations[upstreamNode], 4);
      expect(replay.upstreamPointerGenerations[upstreamNode], 4);
      expect(republished.upstreamPointerGenerations[upstreamNode], 5);
      expect(replay.inputFingerprint, first.inputFingerprint);
      expect(republished.inputFingerprint, isNot(first.inputFingerprint));
      expect(
        first.dependencies.any(
          (value) =>
              value.relationKind == 'UPSTREAM_EVALUATION' &&
              value.dependencyKey.contains('ELV4_PWR03_CURRENT'),
        ),
        isTrue,
      );
    },
  );

  test(
    'F2 Q8 identical capture replay produces deterministic candidate hashes',
    () async {
      final fingerprint = _hash('a');
      final resolver = Fa03PersistedInputResolver(
        contractSource: _ContractSource(_contract(fingerprint)),
        powerEvidence: _EvidenceSource(_pwr03(fingerprint)),
        nowUtc: () => DateTime.utc(2026, 10, 17),
      );
      final executor = buildFa03Executor(
        nowUtc: () => DateTime.utc(2026, 10, 17),
      );

      final left = await executor.execute(await resolver.capture(_request()));
      final right = await executor.execute(await resolver.capture(_request()));

      expect(right.inputFingerprint, left.inputFingerprint);
      expect(right.outputSha256, left.outputSha256);
      expect(right.evidenceSha256, left.evidenceSha256);
      expect(right.evaluationId, left.evaluationId);
    },
  );

  test('blocks stale PWR-03 input identity', () async {
    final resolver = Fa03PersistedInputResolver(
      contractSource: _ContractSource(_contract(_hash('a'))),
      powerEvidence: _EvidenceSource(_pwr03(_hash('b'))),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>().having(
          (value) => value.reasonCode,
          'reasonCode',
          'FA03_PWR03_INPUT_FINGERPRINT_MISMATCH',
        ),
      ),
    );
  });

  test('blocks missing mapped terminal as engineering evidence gap', () async {
    final fingerprint = _hash('a');
    final resolver = Fa03PersistedInputResolver(
      contractSource: _ContractSource(
        _contract(fingerprint, loadId: 'missing-load'),
      ),
      powerEvidence: _EvidenceSource(_pwr03(fingerprint)),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>().having(
          (value) => value.reasonCode,
          'reasonCode',
          'FA03_PWR03_TERMINAL_MISSING',
        ),
      ),
    );
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
  processCode: Elv5ProcessCode.fa03,
  subject: Elv5SubjectRef(kind: 'FIRE_CIRCUIT', id: 'fire-circuit-1'),
  expectedPointerGeneration: 0,
);

Fa03TerminalVoltageContract _contract(
  String fingerprint, {
  String loadId = 'load-3',
}) => Fa03TerminalVoltageContract(
  circuitId: 'fire-circuit-1',
  model: Fa03ContractModel.radialDc,
  minimumTerminalVoltageV: Elv5Rational.integer(22),
  maximumTerminalVoltageV: Elv5Rational.integer(26),
  cases: <Fa03CaseContract>[
    Fa03CaseContract(
      caseId: 'alarm',
      scenarioId: 'FIRE_ALARM',
      segmentId: 'FIRE_SEGMENT',
      pwr03SubjectKind: 'DC_DOMAIN',
      pwr03SubjectId: 'fire-domain-1',
      expectedPwr03InputFingerprint: fingerprint,
      terminalLoadIdByTerminalId: <String, String>{'last-device': loadId},
    ),
  ],
);

final class _ContractSource implements Fa03TerminalVoltageContractSource {
  const _ContractSource(this.contract);
  final Fa03TerminalVoltageContract contract;

  @override
  Future<Fa03TerminalVoltageContractSnapshot?> loadActiveForCircuit({
    required String projectId,
    required String designRevisionId,
    required String circuitId,
  }) async => Fa03TerminalVoltageContractSnapshot(
    bindingId: 'fa03-binding-1',
    bindingRevision: 2,
    evidenceRef: 'FA03:fire-circuit-1:${_hash('c')}',
    contentHash: _hash('c'),
    contract: contract,
  );
}

final class _EvidenceSource implements Elv4CurrentEvidenceSource {
  const _EvidenceSource(this.value);
  final Elv4CurrentEvaluationSnapshot value;

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
  }) async =>
      processCode == PowerProcessCode.pwr03
          ? <Elv4CurrentEvaluationSnapshot>[value]
          : const [];
}

Elv4CurrentEvaluationSnapshot _pwr03(
  String inputFingerprint, {
  String evaluationId = 'pwr03-eval',
  int generation = 4,
}) {
  final dependency =
      PowerDependencyKey(
        projectId: 'p',
        revisionId: 'd',
        kind: PowerDependencyKind.dcSection,
        entityId: 'fire-section-1',
        purpose: 'CONDUCTOR_PATH',
      ).encode();
  return Elv4CurrentEvaluationSnapshot(
    nodeKey: PowerNodeKeyV2(
      revisionId: 'd',
      scenarioId: 'FIRE_ALARM',
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: 'FIRE_SEGMENT',
      processCode: PowerProcessCode.pwr03,
      subjectKind: 'DC_DOMAIN',
      subjectId: 'fire-domain-1',
    ),
    evaluationId: evaluationId,
    inputFingerprint: inputFingerprint,
    evidenceSha256: _hash('d'),
    pointerGeneration: generation,
    evidence: <String, Object?>{
      'dependencyKeys': <String>[dependency],
      'output': <String, Object?>{
        'physicalComplete': true,
        'terminals': <Object?>[
          <String, Object?>{
            'loadId': 'load-3',
            'minimumV': PowerRational.parseDecimal('23.9').toMap(),
            'nominalV': PowerRational.parseDecimal('24').toMap(),
            'maximumV': PowerRational.parseDecimal('23.9').toMap(),
          },
        ],
        'sections': <Object?>[],
      },
    },
  );
}

String _hash(String char) => List<String>.filled(64, char).join();
