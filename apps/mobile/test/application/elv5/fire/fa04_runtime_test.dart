import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/fire/fa04_runtime.dart';
import 'package:electra_mobile/application/elv5/fire/fa04_source_requirement_contract.dart';
import 'package:electra_mobile/application/elv5/power/elv4_current_evidence_source.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captures exact shared demand and source capability for Fire', () async {
    final fingerprint = _hash('a');
    final resolver = Fa04PersistedInputResolver(
      contractSource: _ContractSource(_contract(fingerprint)),
      powerEvidence: _PowerEvidence(fingerprint),
    );

    final captured = await resolver.capture(_request());
    final result = const Fa04SourceRequirementKernel().evaluate(captured.value);
    expect(result.status, Fa04AssessmentStatus.pass);
    expect(
      result.powerCases.single.globalDemand.value,
      Elv5Rational.integer(30),
    );
    expect(result.powerCases.single.margin.value, Elv5Rational.integer(4));
  });

  test(
    'blocks Fire projection when PWR-02 input belongs to another requirement set',
    () async {
      final resolver = Fa04PersistedInputResolver(
        contractSource: _ContractSource(_contract(_hash('a'))),
        powerEvidence: _PowerEvidence(_hash('e')),
      );

      await expectLater(
        resolver.capture(_request()),
        throwsA(
          isA<Elv5CaptureBlockedException>().having(
            (value) => value.reasonCode,
            'reasonCode',
            'FA04_PWR02_REQUIREMENT_SET_INPUT_MISMATCH',
          ),
        ),
      );
    },
  );
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'p',
  designRevisionId: 'd',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'd',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.fa04,
  subject: Elv5SubjectRef(kind: 'POWER_SOURCE', id: 'psu-1'),
  expectedPointerGeneration: 0,
);

Fa04SourceRequirementContract _contract(String fingerprint) =>
    Fa04SourceRequirementContract(
      sourceId: 'psu-1',
      sourceDefinitionContentHash: _hash('b'),
      contributors: [
        Fa04RequirementContributorRef(
          contributorId: 'acs',
          disciplineCode: 'ACS',
          policyCode: 'ACS-PSU',
          editionId: 'acs-v1',
          contentHash: _hash('c'),
        ),
        Fa04RequirementContributorRef(
          contributorId: 'fire',
          disciplineCode: 'FIRE',
          policyCode: 'FIRE-PSU',
          editionId: 'fire-v1',
          contentHash: _hash('d'),
        ),
      ],
      cases: [
        Fa04SourceCaseContract(
          caseId: 'normal-w',
          scenarioId: 'NORMAL',
          segmentId: 'S1',
          dimension: Fa04SourceDimension.watt,
          pwr01SubjectKind: 'SOURCE_AGGREGATE',
          pwr01SubjectId: 'psu-1',
          pwr02SubjectKind: 'CAPACITY_GROUP',
          pwr02SubjectId: 'psu-1',
          expectedPwr02InputFingerprint: fingerprint,
        ),
      ],
    );

final class _ContractSource implements Fa04SourceRequirementContractSource {
  const _ContractSource(this.contract);
  final Fa04SourceRequirementContract contract;

  @override
  Future<Fa04SourceRequirementContractSnapshot?> loadActiveForSource({
    required String projectId,
    required String designRevisionId,
    required String sourceId,
  }) async => Fa04SourceRequirementContractSnapshot(
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
    if (processCode == PowerProcessCode.pwr01) return [_pwr01()];
    if (processCode == PowerProcessCode.pwr02)
      return [_pwr02(pwr02Fingerprint)];
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
        },
        'output': <String, Object?>{
          'required': PowerRational.integer(36).toMap(),
          'available': PowerRational.integer(40).toMap(),
          'margin': PowerRational.integer(4).toMap(),
          'dimensionStatus': 'PASS',
        },
      },
    );

String _hash(String char) => List<String>.filled(64, char).join();
