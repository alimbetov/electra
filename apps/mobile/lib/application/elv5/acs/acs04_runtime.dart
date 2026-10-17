import 'dart:convert';

import 'package:engineering_core/engineering_core.dart'
    show PowerEvaluationScopeKind, PowerProcessCode, PowerRational;
import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import '../power/elv4_current_evidence_source.dart';
import 'acs04_source_requirement_contract.dart';

final class Acs04PersistedInputResolver
    implements Elv5ProcessInputResolver<Acs04Input> {
  Acs04PersistedInputResolver({
    required this.contractSource,
    required this.powerEvidence,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Acs04SourceRequirementContractSource contractSource;
  final Elv4CurrentEvidenceSource powerEvidence;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.acs04;

  @override
  Future<Elv5CapturedInput<Acs04Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('ACS04_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'POWER_SOURCE') {
      throw StateError('ACS04_SUBJECT_KIND_MUST_BE_POWER_SOURCE');
    }

    final sourceId = request.subject.id;
    final dependencies = <Elv5DependencyMarker>[];
    final basisFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs04-source-basis.v1',
      'sourceId': sourceId,
    });
    final contractSnapshot = await contractSource.loadActiveForSource(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      sourceId: sourceId,
    );
    if (contractSnapshot == null) {
      _blocked(
        request,
        'ACS04_SOURCE_REQUIREMENT_CONTRACT_REQUIRED',
        basisFingerprint,
        basisFingerprint,
        dependencies,
        <String, Object?>{'sourceId': sourceId},
      );
    }
    final contract = contractSnapshot!.contract;
    if (contract.sourceId != sourceId) {
      throw StateError('ACS04_CONTRACT_SOURCE_IDENTITY_MISMATCH:$sourceId');
    }
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'ACS04_SOURCE_REQUIREMENT_SET',
        contractSnapshot.evidenceRef,
        memberId:
            '${contractSnapshot.bindingId}:${contractSnapshot.bindingRevision}:${contractSnapshot.contentHash}',
      ),
    );

    final powerCases = <Acs04PowerCaseEvidence>[];
    final currentCases = <Acs04CurrentCaseEvidence>[];
    final pwr01DemandBasis = <Map<String, Object?>>[];
    final pwr02DemandBasis = <Map<String, Object?>>[];
    final upstreamBasis = <Map<String, Object?>>[];
    final upstreamGenerations = <String, int>{};

    for (final sourceCase in contract.cases) {
      final pwr01 = await _requireSingleCurrent(
        request: request,
        processCode: PowerProcessCode.pwr01,
        sourceCase: sourceCase,
        subjectKind: sourceCase.pwr01SubjectKind,
        subjectId: sourceCase.pwr01SubjectId,
        reasonCode: 'ACS04_PWR01_GLOBAL_DEMAND_MISSING',
        dependencies: dependencies,
        inputFingerprint: basisFingerprint,
        policyFingerprint: contractSnapshot.contentHash,
      );
      final pwr02 = await _requireSingleCurrent(
        request: request,
        processCode: PowerProcessCode.pwr02,
        sourceCase: sourceCase,
        subjectKind: sourceCase.pwr02SubjectKind,
        subjectId: sourceCase.pwr02SubjectId,
        reasonCode: 'ACS04_PWR02_CAPABILITY_MISSING',
        dependencies: dependencies,
        inputFingerprint: basisFingerprint,
        policyFingerprint: contractSnapshot.contentHash,
      );

      if (pwr02.inputFingerprint != sourceCase.expectedPwr02InputFingerprint) {
        _blocked(
          request,
          'ACS04_PWR02_REQUIREMENT_SET_INPUT_MISMATCH',
          basisFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'caseId': sourceCase.caseId,
            'expectedInputFingerprint':
                sourceCase.expectedPwr02InputFingerprint,
            'actualInputFingerprint': pwr02.inputFingerprint,
            'evaluationId': pwr02.evaluationId,
          },
        );
      }

      final pwr01Output = pwr01.output;
      final pwr02Inputs = _map(pwr02.evidence['inputs'], 'PWR02 inputs');
      final pwr02Output = pwr02.output;
      final dimensionWire = _text(pwr02Inputs, 'dimension');
      final expectedDimension =
          sourceCase.dimension == Acs04SourceDimension.watt ? 'WATT' : 'AMPERE';
      if (dimensionWire != expectedDimension) {
        _blocked(
          request,
          'ACS04_PWR02_DIMENSION_MISMATCH',
          basisFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'caseId': sourceCase.caseId,
            'expectedDimension': expectedDimension,
            'actualDimension': dimensionWire,
          },
        );
      }

      final pwr01Complete = sourceCase.dimension == Acs04SourceDimension.watt
          ? pwr01Output['completeW'] == true
          : pwr01Output['completeA'] == true;
      if (!pwr01Complete) {
        _blocked(
          request,
          'ACS04_GLOBAL_DEMAND_INCOMPLETE',
          basisFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'caseId': sourceCase.caseId,
            'evaluationId': pwr01.evaluationId,
          },
        );
      }

      final pwr01Demand = _powerRational(
        pwr01Output[sourceCase.dimension == Acs04SourceDimension.watt
            ? 'knownW'
            : 'knownA'],
        'PWR01 demand',
      );
      final pwr02Demand = _powerRational(pwr02Inputs['demand'], 'PWR02 demand');
      if (pwr01Demand != pwr02Demand) {
        _blocked(
          request,
          'ACS04_GLOBAL_DEMAND_CLOSURE_MISMATCH',
          basisFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'caseId': sourceCase.caseId,
            'pwr01Demand': pwr01Demand.toMap(),
            'pwr02Demand': pwr02Demand.toMap(),
          },
        );
      }

      final required = _powerRational(
        pwr02Output['required'],
        'PWR02 required',
      );
      final available = _powerRational(
        pwr02Output['available'],
        'PWR02 available',
      );
      final dimensionStatus = pwr02Output['dimensionStatus'];
      if (dimensionStatus != 'PASS' && dimensionStatus != 'FAIL') {
        _blocked(
          request,
          'ACS04_PWR02_CAPABILITY_UNRESOLVED',
          basisFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'caseId': sourceCase.caseId,
            'dimensionStatus': dimensionStatus,
            'evaluationId': pwr02.evaluationId,
          },
        );
      }

      final demand = _elv5(pwr01Demand);
      final requiredValue = _elv5(required);
      final availableValue = _elv5(available);
      if (sourceCase.dimension == Acs04SourceDimension.watt) {
        powerCases.add(
          Acs04PowerCaseEvidence(
            caseId: sourceCase.caseId,
            globalDemand: Power(demand),
            requiredCapability: Power(requiredValue),
            availableCapability: Power(availableValue),
          ),
        );
      } else {
        currentCases.add(
          Acs04CurrentCaseEvidence(
            caseId: sourceCase.caseId,
            globalDemand: Current(demand),
            requiredCapability: Current(requiredValue),
            availableCapability: Current(availableValue),
          ),
        );
      }

      pwr01DemandBasis.add(<String, Object?>{
        'caseId': sourceCase.caseId,
        'dimension': expectedDimension,
        'demand': pwr01Demand.toMap(),
      });
      pwr02DemandBasis.add(<String, Object?>{
        'caseId': sourceCase.caseId,
        'dimension': expectedDimension,
        'demand': pwr02Demand.toMap(),
      });
      for (final snapshot in <Elv4CurrentEvaluationSnapshot>[pwr01, pwr02]) {
        upstreamGenerations[snapshot.nodeKey.sha256] =
            snapshot.pointerGeneration;
        dependencies.add(
          _dependency(
            request,
            'UPSTREAM_EVALUATION',
            snapshot.nodeKey.processCode == PowerProcessCode.pwr01
                ? 'ELV4_PWR01_CURRENT'
                : 'ELV4_PWR02_CURRENT',
            snapshot.evaluationId,
            memberId:
                '${snapshot.nodeKey.sha256}:${snapshot.pointerGeneration}:${snapshot.evidenceSha256}',
          ),
        );
        upstreamBasis.add(<String, Object?>{
          'evaluationId': snapshot.evaluationId,
          'nodeKeySha256': snapshot.nodeKey.sha256,
          'generation': snapshot.pointerGeneration,
          'evidenceSha256': snapshot.evidenceSha256,
        });
      }
    }

    final pwr01DemandFingerprint = _demandFingerprint(pwr01DemandBasis);
    final pwr02DemandFingerprint = _demandFingerprint(pwr02DemandBasis);
    final requirementSetFingerprint = contract.requirementSetFingerprint;
    final input = Acs04Input(
      sourceId: sourceId,
      expectedGlobalDemandFingerprint: pwr01DemandFingerprint,
      pwr01GlobalDemandFingerprint: pwr01DemandFingerprint,
      pwr02GlobalDemandFingerprint: pwr02DemandFingerprint,
      expectedRequirementSetFingerprint: requirementSetFingerprint,
      pwr02RequirementSetFingerprint: requirementSetFingerprint,
      requirementContributors: <String>[
        for (final contributor in contract.contributors)
          contributor.contributorId,
      ],
      powerCases: powerCases,
      currentCases: currentCases,
    );
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs04-captured-input.v1',
      'contractEvidenceRef': contractSnapshot.evidenceRef,
      'contractContentHash': contractSnapshot.contentHash,
      'requirementSetFingerprint': requirementSetFingerprint,
      'upstream': upstreamBasis
        ..sort(
          (a, b) => (a['evaluationId']! as String).compareTo(
            b['evaluationId']! as String,
          ),
        ),
    });

    return Elv5CapturedInput<Acs04Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: contractSnapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: upstreamGenerations,
      captureRevision: contractSnapshot.bindingRevision,
    );
  }

  Future<Elv4CurrentEvaluationSnapshot> _requireSingleCurrent({
    required Elv5CalculationRequest request,
    required PowerProcessCode processCode,
    required Acs04SourceCaseContract sourceCase,
    required String subjectKind,
    required String subjectId,
    required String reasonCode,
    required List<Elv5DependencyMarker> dependencies,
    required String inputFingerprint,
    required String policyFingerprint,
  }) async {
    final values = await powerEvidence.loadCurrent(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      processCode: processCode,
      scenarioId: sourceCase.scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: sourceCase.segmentId,
      subjectKind: subjectKind,
      subjectId: subjectId,
    );
    if (values.length != 1) {
      _blocked(
        request,
        values.isEmpty ? reasonCode : '${reasonCode}_AMBIGUOUS',
        inputFingerprint,
        policyFingerprint,
        dependencies,
        <String, Object?>{
          'caseId': sourceCase.caseId,
          'scenarioId': sourceCase.scenarioId,
          'segmentId': sourceCase.segmentId,
          'subjectKind': subjectKind,
          'subjectId': subjectId,
          'matchCount': values.length,
        },
      );
    }
    return values.single;
  }

  String _demandFingerprint(List<Map<String, Object?>> values) {
    final canonical = [...values]
      ..sort(
        (a, b) => (a['caseId']! as String).compareTo(b['caseId']! as String),
      );
    return _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs04-global-demand-closure.v1',
      'cases': canonical,
    });
  }

  Never _blocked(
    Elv5CalculationRequest request,
    String reasonCode,
    String inputFingerprint,
    String policyFingerprint,
    List<Elv5DependencyMarker> dependencies,
    Map<String, Object?> evidence,
  ) {
    throw Elv5CaptureBlockedException(
      request: request,
      reasonCode: reasonCode,
      inputFingerprint: inputFingerprint,
      policyFingerprint: policyFingerprint,
      dependencies: dependencies,
      evidence: evidence,
    );
  }

  Elv5DependencyMarker _dependency(
    Elv5CalculationRequest request,
    String relationKind,
    String domain,
    String subjectId, {
    String? memberId,
  }) {
    final value = <String, Object?>{
      'schema': 'electra.elv5-dependency-key.v1',
      'relationKind': relationKind,
      'domain': domain,
      'subjectId': subjectId,
      if (memberId != null) 'memberId': memberId,
    };
    return Elv5DependencyMarker(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      dependencyKey: utf8.decode(_encoder.encode(value)),
      dependencyKeySha256: _encoder.sha256(value),
      logicalNodeKeySha256: _encoder.sha256(request.nodeKey.toCanonicalValue()),
      relationKind: relationKind,
      updatedAtUtc: _nowUtc().toUtc(),
    );
  }
}

Elv5PureKernelExecutor<Acs04Input, Acs04Result> buildAcs04Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Acs04Input, Acs04Result>(
  processCode: Elv5ProcessCode.acs04,
  calculate: const Acs04SourceRequirementKernel().evaluate,
  encodeOutput: (result) => <String, Object?>{
    'schema': 'electra.elv5-acs04-output.v1',
    'status': result.status.name,
    'governingCaseId': result.governingCaseId,
    'governingDimension': result.governingDimension?.name,
    'blockingReason': result.blockingReason,
    'requirementContributors': result.requirementContributors,
    'powerCases': [
      for (final item in result.powerCases)
        <String, Object?>{
          'caseId': item.caseId,
          'globalDemandW': item.globalDemand.value.toMap(),
          'requiredW': item.requiredCapability.value.toMap(),
          'availableW': item.availableCapability.value.toMap(),
          'marginW': item.margin.value.toMap(),
          'status': item.status.name,
        },
    ],
    'currentCases': [
      for (final item in result.currentCases)
        <String, Object?>{
          'caseId': item.caseId,
          'globalDemandA': item.globalDemand.value.toMap(),
          'requiredA': item.requiredCapability.value.toMap(),
          'availableA': item.availableCapability.value.toMap(),
          'marginA': item.margin.value.toMap(),
          'status': item.status.name,
        },
    ],
  },
  encodeEvidence: (captured, _) => <String, Object?>{
    'schema': 'electra.elv5-acs04-evidence.v1',
    'source':
        'VERIFIED_CURRENT_PWR01_PWR02_PLUS_EXACT_REQUIREMENT_SET_CONTRACT',
    'captureRevision': captured.captureRevision,
    'upstreamPointerGenerations': captured.upstreamPointerGenerations,
    'requirementSetFingerprint':
        captured.value.expectedRequirementSetFingerprint,
    'globalDemandFingerprint': captured.value.expectedGlobalDemandFingerprint,
  },
  executionOf: (result) => result.status == Acs04AssessmentStatus.blocked
      ? Elv5Execution.blocked
      : Elv5Execution.succeeded,
  completionOf: (result) => result.status == Acs04AssessmentStatus.blocked
      ? Elv5Completion.incomplete
      : Elv5Completion.complete,
  assessmentOf: (result) => switch (result.status) {
    Acs04AssessmentStatus.pass => Elv5Assessment.pass,
    Acs04AssessmentStatus.fail => Elv5Assessment.fail,
    Acs04AssessmentStatus.blocked => Elv5Assessment.unresolved,
  },
  nowUtc: nowUtc,
);

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return Map<String, Object?>.from(value);
}

PowerRational _powerRational(Object? raw, String field) {
  if (raw is! Map) throw FormatException('$field must be a rational map.');
  return PowerRational.fromMap(Map<String, Object?>.from(raw));
}

Elv5Rational _elv5(PowerRational value) =>
    Elv5Rational(value.numerator, value.denominator);

String _text(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return raw.trim();
}
