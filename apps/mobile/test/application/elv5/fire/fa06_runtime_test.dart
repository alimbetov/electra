import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/fire/elv5_fire_persistence.dart';
import 'package:electra_mobile/application/elv5/fire/fa06_notification_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa06_runtime.dart';
import 'package:electra_mobile/application/elv5/power/elv4_current_evidence_source.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'projects persisted notification membership through PWR-01/PWR-03',
    () async {
      final resolver = Fa06PersistedInputResolver(
        fireStore: _FireStore(includeStartup: false),
        contractSource: _ContractSource(_contract(includeStartup: false)),
        powerEvidence: _EvidenceSource(<Elv4CurrentEvaluationSnapshot>[
          _pwr01(segmentId: 'NAC_ACTIVE', currentA: '0.3'),
          _pwr03(segmentId: 'NAC_ACTIVE'),
        ]),
        nowUtc: () => DateTime.utc(2026, 10, 17),
      );

      final captured = await resolver.capture(_request());
      final candidate = await buildFa06Executor(
        nowUtc: () => DateTime.utc(2026, 10, 17),
      ).execute(captured);

      expect(candidate.assessment, Elv5Assessment.pass);
      expect(candidate.output['activeDeviceCount'], 3);
      expect(candidate.output['deviceCountMargin'], 1);
      expect(candidate.output['governingDimension'], isNull);
      final cases = candidate.output['cases']! as Map<String, Object?>;
      final active = cases['activeNotification']! as Map<String, Object?>;
      expect(
        active['currentMarginA'],
        Elv5Rational.parseDecimal('0.2').toMap(),
      );
      expect(
        active['terminalVoltageLowerV'],
        Elv5Rational.parseDecimal('22.8').toMap(),
      );
      expect(
        active['terminalVoltageUpperV'],
        Elv5Rational.parseDecimal('23.5').toMap(),
      );
    },
  );

  test(
    'blocks required startup when one device has no startup current fact',
    () async {
      final resolver = Fa06PersistedInputResolver(
        fireStore: _FireStore(includeStartup: false),
        contractSource: _ContractSource(_contract(includeStartup: true)),
        powerEvidence: _EvidenceSource(<Elv4CurrentEvaluationSnapshot>[
          _pwr01(segmentId: 'NAC_ACTIVE', currentA: '0.3'),
          _pwr03(segmentId: 'NAC_ACTIVE'),
        ]),
      );

      await expectLater(
        resolver.capture(_request()),
        throwsA(
          isA<Elv5CaptureBlockedException>().having(
            (value) => value.reasonCode,
            'reasonCode',
            'FA06_STARTUP_CURRENT_EVIDENCE_MISSING',
          ),
        ),
      );
    },
  );

  test('blocks when a mapped PWR-03 terminal is missing', () async {
    final resolver = Fa06PersistedInputResolver(
      fireStore: _FireStore(includeStartup: false),
      contractSource: _ContractSource(_contract(includeStartup: false)),
      powerEvidence: _EvidenceSource(<Elv4CurrentEvaluationSnapshot>[
        _pwr01(segmentId: 'NAC_ACTIVE', currentA: '0.3'),
        _pwr03(segmentId: 'NAC_ACTIVE', omitLoadId: 'horn-3'),
      ]),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>()
            .having(
              (value) => value.reasonCode,
              'reasonCode',
              'FA06_PWR03_DEVICE_TERMINAL_MISSING',
            )
            .having(
              (value) => value.evidence['terminalLoadId'],
              'terminalLoadId',
              'horn-3',
            ),
      ),
    );
  });
}

Fa06NotificationContract _contract({required bool includeStartup}) =>
    Fa06NotificationContract(
      circuitId: 'nac-1',
      deviceLimit: 4,
      outputCurrentLimitA: Elv5Rational.parseDecimal('0.5'),
      minimumTerminalVoltageV: Elv5Rational.integer(22),
      maximumTerminalVoltageV: Elv5Rational.integer(26),
      cases: <Fa06CaseContract>[
        Fa06CaseContract(
          operatingCase: Fa06ContractCase.activeNotification,
          stateCode: 'ALARM',
          scenarioId: 'FIRE_ALARM',
          segmentId: 'NAC_ACTIVE',
          pwr01SubjectKind: 'NOTIFICATION_OUTPUT',
          pwr01SubjectId: 'nac-1',
          pwr03SubjectKind: 'DC_DOMAIN',
          pwr03SubjectId: 'nac-domain-1',
        ),
        if (includeStartup)
          Fa06CaseContract(
            operatingCase: Fa06ContractCase.startupInrush,
            stateCode: 'STARTUP',
            scenarioId: 'FIRE_ALARM',
            segmentId: 'NAC_STARTUP',
            pwr01SubjectKind: 'NOTIFICATION_OUTPUT',
            pwr01SubjectId: 'nac-1',
            pwr03SubjectKind: 'DC_DOMAIN',
            pwr03SubjectId: 'nac-domain-1',
          ),
      ],
      terminalLoadIdByDeviceId: const <String, String>{
        'horn-1': 'horn-1',
        'horn-2': 'horn-2',
        'horn-3': 'horn-3',
      },
      supervision: Fa06SupervisionContract(
        required: false,
        modelSupported: false,
      ),
    );

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'p',
  designRevisionId: 'd',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'd',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.fa06,
  subject: Elv5SubjectRef(kind: 'FIRE_NOTIFICATION_CIRCUIT', id: 'nac-1'),
  expectedPointerGeneration: 0,
);

final class _FireStore implements Elv5FireFactStore {
  const _FireStore({required this.includeStartup});
  final bool includeStartup;

  @override
  Future<Elv5FireAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) async => Elv5FireAggregateSnapshot(
    aggregateKind: 'FIRE_NOTIFICATION_CIRCUIT',
    aggregateId: 'ELV5:FIRE_NOTIFICATION_CIRCUIT:nac-1',
    subjectId: 'nac-1',
    revision: 2,
    payload: <String, Object?>{
      'circuitId': 'nac-1',
      'outputRef': <String, Object?>{
        'componentId': 'panel-1',
        'portId': 'nac-port-1',
      },
      'policyRef': <String, Object?>{
        'policyCode': 'FIRE-NAC',
        'editionId': 'v1',
        'contentHash': _hash('a'),
      },
      'deviceAssignments': <Object?>[
        for (final id in const <String>['horn-1', 'horn-2', 'horn-3'])
          <String, Object?>{
            'deviceId': id,
            'stateCurrentMa': <String, Object?>{
              'ALARM': '100',
              if (includeStartup) 'STARTUP': '150',
            },
          },
      ],
    },
  );
}

final class _ContractSource implements Fa06NotificationContractSource {
  const _ContractSource(this.contract);
  final Fa06NotificationContract contract;

  @override
  Future<Fa06NotificationContractSnapshot?> loadActiveForCircuit({
    required String projectId,
    required String designRevisionId,
    required String circuitId,
  }) async => Fa06NotificationContractSnapshot(
    bindingId: 'fa06-binding-1',
    bindingRevision: 3,
    evidenceRef: 'FA06:nac-1:${_hash('b')}',
    contentHash: _hash('b'),
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

Elv4CurrentEvaluationSnapshot _pwr01({
  required String segmentId,
  required String currentA,
}) => Elv4CurrentEvaluationSnapshot(
  nodeKey: PowerNodeKeyV2(
    revisionId: 'd',
    scenarioId: 'FIRE_ALARM',
    scopeKind: PowerEvaluationScopeKind.segment,
    scopeId: segmentId,
    processCode: PowerProcessCode.pwr01,
    subjectKind: 'NOTIFICATION_OUTPUT',
    subjectId: 'nac-1',
  ),
  evaluationId: 'pwr01-$segmentId',
  inputFingerprint: _hash('1'),
  evidenceSha256: _hash('2'),
  pointerGeneration: 2,
  evidence: <String, Object?>{
    'output': <String, Object?>{
      'knownW': PowerRational.zero.toMap(),
      'knownA': PowerRational.parseDecimal(currentA).toMap(),
      'knownVa': PowerRational.zero.toMap(),
      'completeW': false,
      'completeA': true,
      'completeVa': false,
    },
  },
);

Elv4CurrentEvaluationSnapshot _pwr03({
  required String segmentId,
  String? omitLoadId,
}) => Elv4CurrentEvaluationSnapshot(
  nodeKey: PowerNodeKeyV2(
    revisionId: 'd',
    scenarioId: 'FIRE_ALARM',
    scopeKind: PowerEvaluationScopeKind.segment,
    scopeId: segmentId,
    processCode: PowerProcessCode.pwr03,
    subjectKind: 'DC_DOMAIN',
    subjectId: 'nac-domain-1',
  ),
  evaluationId: 'pwr03-$segmentId',
  inputFingerprint: _hash('3'),
  evidenceSha256: _hash('4'),
  pointerGeneration: 4,
  evidence: <String, Object?>{
    'output': <String, Object?>{
      'physicalComplete': true,
      'terminals': <Object?>[
        if (omitLoadId != 'horn-1')
          <String, Object?>{
            'loadId': 'horn-1',
            'minimumV': PowerRational.parseDecimal('23.0').toMap(),
            'nominalV': PowerRational.parseDecimal('23.2').toMap(),
            'maximumV': PowerRational.parseDecimal('23.4').toMap(),
          },
        if (omitLoadId != 'horn-2')
          <String, Object?>{
            'loadId': 'horn-2',
            'minimumV': PowerRational.parseDecimal('22.8').toMap(),
            'nominalV': PowerRational.parseDecimal('23.0').toMap(),
            'maximumV': PowerRational.parseDecimal('23.2').toMap(),
          },
        if (omitLoadId != 'horn-3')
          <String, Object?>{
            'loadId': 'horn-3',
            'minimumV': PowerRational.parseDecimal('23.1').toMap(),
            'nominalV': PowerRational.parseDecimal('23.3').toMap(),
            'maximumV': PowerRational.parseDecimal('23.5').toMap(),
          },
      ],
      'sections': <Object?>[],
    },
  },
);

String _hash(String char) => List<String>.filled(64, char).join();
