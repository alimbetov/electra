import 'dart:convert';

import 'package:engineering_core/engineering_core.dart'
    show PowerEvaluationScopeKind, PowerProcessCode, PowerRational;
import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import '../power/elv4_current_evidence_source.dart';
import 'fa04_source_requirement_contract.dart';

final class Fa04PersistedInputResolver
    implements Elv5ProcessInputResolver<Fa04Input> {
  Fa04PersistedInputResolver({
    required this.contractSource,
    required this.powerEvidence,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Fa04SourceRequirementContractSource contractSource;
  final Elv4CurrentEvidenceSource powerEvidence;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.fa04;

  @override
  Future<Elv5CapturedInput<Fa04Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('FA04_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'POWER_SOURCE') {
      throw StateError('FA04_SUBJECT_KIND_MUST_BE_POWER_SOURCE');
    }

    final sourceId = request.subject.id;
    final dependencies = <Elv5DependencyMarker>[];
    final basisFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-fa04-source-basis.v1',
      'sourceId': sourceId,
    });
    final snapshot = await contractSource.loadActiveForSource(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      sourceId: sourceId,
    );
    if (snapshot == null) {
      _blocked(
        request,
        'FA04_SOURCE_REQUIREMENT_CONTRACT_REQUIRED',
        basisFingerprint,
        basisFingerprint,
        dependencies,
        <String, Object?>{'sourceId': sourceId},
      );
    }
    final contract = snapshot!.contract;
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'FA04_SOURCE_REQUIREMENT_SET',
        snapshot.evidenceRef,
        memberId:
            '${snapshot.bindingId}:${snapshot.bindingRevision}:${snapshot.contentHash}',
      ),
    );

    final powerCases = <Fa04PowerCaseEvidence>[];
    final currentCases = <Fa04CurrentCaseEvidence>[];
    final pwr01DemandBasis = <Map<String, Object?>>[];
    final pwr02DemandBasis = <Map<String, Object?>>[];
    final upstream = <Map<String, Object?>>[];
    final generations = <String, int>{};

    for (final sourceCase in contract.cases) {
      final pwr01 = await _requireSingleCurrent(
        request: request,
        processCode: PowerProcessCode.pwr01,
        sourceCase: sourceCase,
        subjectKind: sourceCase.pwr01SubjectKind,
        subjectId: sourceCase.pwr01SubjectId,
        reasonCode: 'FA04_PWR01_GLOBAL_DEMAND_MISSING',
        dependencies: dependencies,
        basisFingerprint: basisFingerprint,
        policyFingerprint: snapshot.contentHash,
      );
      final pwr02 = await _requireSingleCurrent(
        request: request,
        processCode: PowerProcessCode.pwr02,
        sourceCase: sourceCase,
        subjectKind: sourceCase.pwr02SubjectKind,
        subjectId: sourceCase.pwr02SubjectId,
        reasonCode: 'FA04_PWR02_CAPABILITY_MISSING',
        dependencies: dependencies,
        basisFingerprint: basisFingerprint,
        policyFingerprint: snapshot.contentHash,
      );

      if (pwr02.inputFingerprint != sourceCase.expectedPwr02InputFingerprint) {
        _blocked(
          request,
          'FA04_PWR02_REQUIREMENT_SET_INPUT_MISMATCH',
          basisFingerprint,
          snapshot.contentHash,
          dependencies,
          <String, Object?>{
            'caseId': sourceCase.caseId,
            'expectedInputFingerprint':
                sourceCase.expectedPwr02InputFingerprint,
            'actualInputFingerprint': pwr02.inputFingerprint,
          },
        );
      }

      final pwr01Output = pwr01.output;
      final pwr02Inputs = _map(pwr02.evidence['inputs'], 'PWR02 inputs');
      final pwr02Output = pwr02.output;
      final expectedDimension =
          sourceCase.dimension == Fa04SourceDimension.watt ? 'WATT' : 'AMPERE';
      if (_text(pwr02Inputs, 'dimension') != expectedDimension) {
        _blocked(
          request,
          'FA04_PWR02_DIMENSION_MISMATCH',
          basisFingerprint,
          snapshot.contentHash,
          dependencies,
          <String, Object?>{'caseId': sourceCase.caseId},
        );
      }

      final complete =
          sourceCase.dimension == Fa04SourceDimension.watt
              ? pwr01Output['completeW'] == true
              : pwr01Output['completeA'] == true;
      if (!complete) {
        _blocked(
          request,
          'FA04_GLOBAL_DEMAND_INCOMPLETE',
          basisFingerprint,
          snapshot.contentHash,
          dependencies,
          <String, Object?>{'caseId': sourceCase.caseId},
        );
      }

      final pwr01Demand = _powerRational(
        pwr01Output[sourceCase.dimension == Fa04SourceDimension.watt
            ? 'knownW'
            : 'knownA'],
        'PWR01 demand',
      );
      final pwr02Demand = _powerRational(pwr02Inputs['demand'], 'PWR02 demand');
      if (pwr01Demand != pwr02Demand) {
        _blocked(
          request,
          'FA04_GLOBAL_DEMAND_CLOSURE_MISMATCH',
          basisFingerprint,
          snapshot.contentHash,
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
          'FA04_PWR02_CAPABILITY_UNRESOLVED',
          basisFingerprint,
          snapshot.contentHash,
          dependencies,
          <String, Object?>{'caseId': sourceCase.caseId},
        );
      }

      if (sourceCase.dimension == Fa04SourceDimension.watt) {
        powerCases.add(
          Fa04PowerCaseEvidence(
            caseId: sourceCase.caseId,
            globalDemand: Power(_elv5(pwr01Demand)),
            requiredCapability: Power(_elv5(required)),
            availableCapability: Power(_elv5(available)),
          ),
        );
      } else {
        currentCases.add(
          Fa04CurrentCaseEvidence(
            caseId: sourceCase.caseId,
            globalDemand: Current(_elv5(pwr01Demand)),
            requiredCapability: Current(_elv5(required)),
            availableCapability: Current(_elv5(available)),
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
      for (final item in <Elv4CurrentEvaluationSnapshot>[pwr01, pwr02]) {
        generations[item.nodeKey.sha256] = item.pointerGeneration;
        dependencies.add(
          _dependency(
            request,
            'UPSTREAM_EVALUATION',
            item.nodeKey.processCode == PowerProcessCode.pwr01
                ? 'ELV4_PWR01_CURRENT'
                : 'ELV4_PWR02_CURRENT',
            item.evaluationId,
            memberId:
                '${item.nodeKey.sha256}:${item.pointerGeneration}:${item.evidenceSha256}',
          ),
        );
        upstream.add(<String, Object?>{
          'evaluationId': item.evaluationId,
          'nodeKeySha256': item.nodeKey.sha256,
          'generation': item.pointerGeneration,
          'evidenceSha256': item.evidenceSha256,
        });
      }
    }

    final pwr01Fingerprint = _demandFingerprint(pwr01DemandBasis);
    final pwr02Fingerprint = _demandFingerprint(pwr02DemandBasis);
    final requirementSetFingerprint = contract.requirementSetFingerprint;
    final input = Fa04Input(
      sourceId: sourceId,
      expectedGlobalDemandFingerprint: pwr01Fingerprint,
      pwr01GlobalDemandFingerprint: pwr01Fingerprint,
      pwr02GlobalDemandFingerprint: pwr02Fingerprint,
      expectedRequirementSetFingerprint: requirementSetFingerprint,
      pwr02RequirementSetFingerprint: requirementSetFingerprint,
      requirementContributors: <String>[
        for (final contributor in contract.contributors)
          contributor.contributorId,
      ],
      powerCases: powerCases,
      currentCases: currentCases,
    );

    return Elv5CapturedInput<Fa04Input>(
      request: request,
      value: input,
      inputFingerprint: _encoder.sha256(<String, Object?>{
        'schema': 'electra.elv5-fa04-captured-input.v1',
        'contractContentHash': snapshot.contentHash,
        'requirementSetFingerprint': requirementSetFingerprint,
        'upstream':
            upstream..sort(
              (a, b) => (a['evaluationId']! as String).compareTo(
                b['evaluationId']! as String,
              ),
            ),
      }),
      policyFingerprint: snapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: generations,
      captureRevision: snapshot.bindingRevision,
    );
  }

  Future<Elv4CurrentEvaluationSnapshot> _requireSingleCurrent({
    required Elv5CalculationRequest request,
    required PowerProcessCode processCode,
    required Fa04SourceCaseContract sourceCase,
    required String subjectKind,
    required String subjectId,
    required String reasonCode,
    required List<Elv5DependencyMarker> dependencies,
    required String basisFingerprint,
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
        basisFingerprint,
        policyFingerprint,
        dependencies,
        <String, Object?>{
          'caseId': sourceCase.caseId,
          'matchCount': values.length,
        },
      );
    }
    return values.single;
  }

  String _demandFingerprint(List<Map<String, Object?>> values) {
    final canonical = [...values]..sort(
      (a, b) => (a['caseId']! as String).compareTo(b['caseId']! as String),
    );
    return _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-shared-global-demand-closure.v1',
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

Elv5PureKernelExecutor<Fa04Input, Fa04Result> buildFa04Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Fa04Input, Fa04Result>(
  processCode: Elv5ProcessCode.fa04,
  calculate: const Fa04SourceRequirementKernel().evaluate,
  encodeOutput:
      (result) => <String, Object?>{
        'schema': 'electra.elv5-fa04-output.v1',
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
  encodeEvidence:
      (captured, _) => <String, Object?>{
        'schema': 'electra.elv5-fa04-evidence.v1',
        'source': 'VERIFIED_CURRENT_PWR01_PWR02_SHARED_SOURCE_REQUIREMENT_SET',
        'captureRevision': captured.captureRevision,
        'upstreamPointerGenerations': captured.upstreamPointerGenerations,
      },
  executionOf:
      (result) =>
          result.status == Fa04AssessmentStatus.blocked
              ? Elv5Execution.blocked
              : Elv5Execution.succeeded,
  completionOf:
      (result) =>
          result.status == Fa04AssessmentStatus.blocked
              ? Elv5Completion.incomplete
              : Elv5Completion.complete,
  assessmentOf:
      (result) => switch (result.status) {
        Fa04AssessmentStatus.pass => Elv5Assessment.pass,
        Fa04AssessmentStatus.fail => Elv5Assessment.fail,
        Fa04AssessmentStatus.blocked => Elv5Assessment.unresolved,
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

String _text(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be non-empty text.');
  }
  return value.trim();
}
