import 'package:electra_mobile/application/elv5/acs/acs04_runtime.dart';
import 'package:electra_mobile/application/elv5/acs/acs04_source_requirement_contract.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/power/elv4_current_evidence_source.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'captures exact global demand and PWR-02 capability without local sizing',
    () async {
      final pwr02Fingerprint = _hash('a');
      final resolver = Acs04PersistedInputResolver(
        contractSource: _ContractSource(_contract(pwr02Fingerprint)),
        powerEvidence: _PowerEvidence(pwr02Fingerprint),
      );

      final captured = await resolver.capture(_request());
      final input = captured.value;
      expect(input.powerCases, hasLength(1));
      expect(
        input.powerCases.single.globalDemand.value,
        Elv5Rational.integer(30),
      );
      expect(
        input.powerCases.single.requiredCapability.value,
        Elv5Rational.integer(36),
      );
      expect(
        input.powerCases.single.availableCapability.value,
        Elv5Rational.integer(40),
      );
      final result = const Acs04SourceRequirementKernel().evaluate(input);
      expect(result.status, Acs04AssessmentStatus.pass);
      expect(result.powerCases.single.margin.value, Elv5Rational.integer(4));
    },
  );

  test('blocks when CURRENT PWR-02 was produced from another requirement set input', () async {
    final resolver = Acs04PersistedInputResolver(
      contractSource: _ContractSource(_contract(_hash('a'))),
      powerEvidence: _PowerEvidence(_hash('e')),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>().having(
          (value) => value.reasonCode,
          'reasonCode',
          'ACS04_PWR02_REQUIREMENT_SET_INPUT_MISMATCH',
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
  processCode: Elv5ProcessCode.acs04,
  subject: Elv5SubjectRef(kind: 'POWER_SOURCE', id: 'psu-1'),
  expectedPointerGeneration: 0,
);

Acs04SourceRequirementContract _contract(String fingerprint) =>
    Acs04SourceRequirementContract(
      sourceId: 'psu-1',
      sourceDefinitionContentHash: _hash('b'),
      contributors: [
        Acs04RequirementContributorRef(
          contributorId: 'acs',
          disciplineCode: 'ACS',
          policyCode: 'ACS-PSU',
          editionId: 'acs-v1',
          contentHash: _hash('c'),
        ),
      ],
      cases: [
        Acs04SourceCaseContract(
          caseId: 'normal-w',
          scenarioId: 'NORMAL',
          segmentId: 'S1',
          dimension: Acs04SourceDimension.watt,
          pwr01SubjectKind: 'SOURCE_AGGREGATE',
          pwr01SubjectId: 'psu-1',
          pwr02SubjectKind: 'CAPACITY_GROUP',
          pwr02SubjectId: 'psu-1',
          expectedPwr02InputFingerprint: fingerprint,
        ),
      ],
    );

final class _ContractSource implements Acs04SourceRequirementContractSource {
  const _ContractSource(this.contract);
  final Acs04SourceRequirementContract contract;

  @override
  Future<Acs04SourceRequirementContractSnapshot?> loadActiveForSource({
    required String projectId,
    required String designRevisionId,
    required String sourceId,
  }) async => Acs04SourceRequirementContractSnapshot(
    bindingId: 'binding-1',
    bindingRevision: 2,
    evidenceRef: 'evidence-1',
    contentHash: _hash('f'),
    contract: contract,
  );
}

final class _PowerEvidence implements Elv4CurrentEvidenceSource {
  const _PowerEvidence(this.pwr02Fingerprint);
  final String pwr02Fingerprint;

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
  }) async {
    if (processCode == PowerProcessCode.pwr01) {
      return [_pwr01()];
    }
    if (processCode == PowerProcessCode.pwr02) {
      return [_pwr02(pwr02Fingerprint)];
    }
    return const [];
  }
}

Elv4CurrentEvaluationSnapshot _pwr01() => Elv4CurrentEvaluationSnapshot(
  nodeKey: PowerNodeKeyV2(
    revisionId: 'd',
    scenarioId: 'NORMAL',
    scopeKind: PowerEvaluationScopeKind.segment,
    scopeId: 'S1',
    processCode: PowerProcessCode.pwr01,
    subjectKind: 'SOURCE_AGGREGATE',
    subjectId: 'psu-1',
  ),
  evaluationId: 'pwr01-eval',
  inputFingerprint: _hash('1'),
  evidenceSha256: _hash('2'),
  pointerGeneration: 3,
  evidence: <String, Object?>{
    'output': <String, Object?>{
      'knownW': PowerRational.integer(30).toMap(),
      'knownA': PowerRational.zero.toMap(),
      'knownVa': PowerRational.zero.toMap(),
      'completeW': true,
      'completeA': false,
      'completeVa': false,
    },
  },
);

Elv4CurrentEvaluationSnapshot _pwr02(String fingerprint) =>
    Elv4CurrentEvaluationSnapshot(
      nodeKey: PowerNodeKeyV2(
        revisionId: 'd',
        scenarioId: 'NORMAL',
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: 'S1',
        processCode: PowerProcessCode.pwr02,
        subjectKind: 'CAPACITY_GROUP',
        subjectId: 'psu-1',
      ),
      evaluationId: 'pwr02-eval',
      inputFingerprint: fingerprint,
      evidenceSha256: _hash('3'),
      pointerGeneration: 5,
      evidence: <String, Object?>{
        'inputs': <String, Object?>{
          'dimension': 'WATT',
          'demand': PowerRational.integer(30).toMap(),
          'nameplate': PowerRational.integer(50).toMap(),
          'reserveMultiplier': PowerRational(
            BigInt.from(6),
            BigInt.from(5),
          ).toMap(),
          'deratingFactor': PowerRational(
            BigInt.from(4),
            BigInt.from(5),
          ).toMap(),
        },
        'output': <String, Object?>{
          'required': PowerRational.integer(36).toMap(),
          'available': PowerRational.integer(40).toMap(),
          'margin': PowerRational.integer(4).toMap(),
          'utilization': null,
          'zeroCapacity': false,
          'dimensionStatus': 'PASS',
        },
      },
    );

String _hash(String char) => List<String>.filled(64, char).join();
