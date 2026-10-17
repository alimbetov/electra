import 'dart:convert';

import 'package:engineering_core/engineering_core.dart'
    show PowerEvaluationScopeKind, PowerProcessCode, PowerRational;
import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import '../power/elv4_current_evidence_source.dart';
import 'fa03_terminal_voltage_contract.dart';

final class Fa03PersistedInputResolver
    implements Elv5ProcessInputResolver<Fa03Input> {
  Fa03PersistedInputResolver({
    required this.contractSource,
    required this.powerEvidence,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Fa03TerminalVoltageContractSource contractSource;
  final Elv4CurrentEvidenceSource powerEvidence;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.fa03;

  @override
  Future<Elv5CapturedInput<Fa03Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('FA03_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'FIRE_CIRCUIT') {
      throw StateError('FA03_SUBJECT_KIND_MUST_BE_FIRE_CIRCUIT');
    }

    final contractSnapshot = await contractSource.loadActiveForCircuit(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      circuitId: request.subject.id,
    );
    if (contractSnapshot == null) {
      _blocked(
        request,
        'FA03_TERMINAL_VOLTAGE_CONTRACT_REQUIRED',
        _encoder.sha256(<String, Object?>{
          'schema': 'electra.elv5-fa03-missing-contract.v1',
          'circuitId': request.subject.id,
        }),
        _encoder.sha256(<String, Object?>{
          'schema': 'electra.elv5-fa03-policy-missing.v1',
          'circuitId': request.subject.id,
        }),
        const <Elv5DependencyMarker>[],
        <String, Object?>{'circuitId': request.subject.id},
      );
    }
    final contract = contractSnapshot!.contract;
    if (contract.circuitId != request.subject.id) {
      throw StateError(
        'FA03_CONTRACT_CIRCUIT_IDENTITY_MISMATCH:'
        '${request.subject.id}:${contract.circuitId}',
      );
    }

    final dependencies = <Elv5DependencyMarker>[
      _dependency(
        request,
        'POLICY',
        'FA03_TERMINAL_VOLTAGE_CONTRACT',
        contractSnapshot.evidenceRef,
        memberId:
            '${contractSnapshot.bindingId}:${contractSnapshot.bindingRevision}:${contractSnapshot.contentHash}',
      ),
    ];

    if (contract.model == Fa03ContractModel.unsupported) {
      _blocked(
        request,
        'FA03_UNSUPPORTED_ELECTRICAL_MODEL',
        contractSnapshot.contentHash,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'circuitId': contract.circuitId,
          'model': contract.model.name,
        },
      );
    }

    final terminals = <Fa03TerminalEvidence>[];
    final upstreamGenerations = <String, int>{};
    final upstreamBasis = <Map<String, Object?>>[];
    String? physicalScopeFingerprint;

    for (final caseContract in contract.cases) {
      final values = await powerEvidence.loadCurrent(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
        processCode: PowerProcessCode.pwr03,
        scenarioId: caseContract.scenarioId,
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: caseContract.segmentId,
        subjectKind: caseContract.pwr03SubjectKind,
        subjectId: caseContract.pwr03SubjectId,
      );
      if (values.length != 1) {
        _blocked(
          request,
          values.isEmpty
              ? 'FA03_PWR03_CASE_EVIDENCE_MISSING'
              : 'FA03_PWR03_CASE_EVIDENCE_AMBIGUOUS',
          contractSnapshot.contentHash,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'caseId': caseContract.caseId,
            'scenarioId': caseContract.scenarioId,
            'segmentId': caseContract.segmentId,
            'matchCount': values.length,
          },
        );
      }
      final pwr03 = values.single;

      // Register the exact upstream identity before any check that can produce
      // a durable BLOCKED result. A later PWR-03 publication can therefore
      // invalidate/recalculate an FA-03 result that was blocked by its content.
      dependencies.add(
        _dependency(
          request,
          'UPSTREAM_EVALUATION',
          'ELV4_PWR03_CURRENT',
          pwr03.evaluationId,
          memberId:
              '${pwr03.nodeKey.sha256}:${pwr03.pointerGeneration}:${pwr03.evidenceSha256}',
        ),
      );
      upstreamGenerations[pwr03.nodeKey.sha256] = pwr03.pointerGeneration;
      upstreamBasis.add(<String, Object?>{
        'caseId': caseContract.caseId,
        'evaluationId': pwr03.evaluationId,
        'nodeKeySha256': pwr03.nodeKey.sha256,
        'generation': pwr03.pointerGeneration,
        'evidenceSha256': pwr03.evidenceSha256,
        'inputFingerprint': pwr03.inputFingerprint,
      });

      if (pwr03.inputFingerprint !=
          caseContract.expectedPwr03InputFingerprint) {
        _blocked(
          request,
          'FA03_PWR03_INPUT_FINGERPRINT_MISMATCH',
          contractSnapshot.contentHash,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'caseId': caseContract.caseId,
            'expectedInputFingerprint':
                caseContract.expectedPwr03InputFingerprint,
            'actualInputFingerprint': pwr03.inputFingerprint,
            'evaluationId': pwr03.evaluationId,
          },
        );
      }
      if (pwr03.output['physicalComplete'] != true) {
        _blocked(
          request,
          'FA03_PWR03_PHYSICAL_CLOSURE_INCOMPLETE',
          contractSnapshot.contentHash,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'caseId': caseContract.caseId,
            'evaluationId': pwr03.evaluationId,
          },
        );
      }

      String membership;
      try {
        membership = pwr03.physicalMembershipFingerprint;
      } on Object catch (error) {
        _blocked(
          request,
          'FA03_PWR03_PHYSICAL_SCOPE_UNAVAILABLE',
          contractSnapshot.contentHash,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'caseId': caseContract.caseId,
            'evaluationId': pwr03.evaluationId,
            'upstreamError': error.toString(),
          },
        );
      }
      physicalScopeFingerprint ??= membership;
      if (physicalScopeFingerprint != membership) {
        _blocked(
          request,
          'FA03_PWR03_SCOPE_MISMATCH',
          contractSnapshot.contentHash,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'caseId': caseContract.caseId,
            'expectedScopeFingerprint': physicalScopeFingerprint,
            'actualScopeFingerprint': membership,
          },
        );
      }

      final rawTerminals = _objects(pwr03.output['terminals'], 'terminals');
      for (final mapping in caseContract.terminalLoadIdByTerminalId.entries) {
        final matching =
            rawTerminals
                .where((row) => row['loadId'] == mapping.value)
                .toList();
        if (matching.length != 1) {
          _blocked(
            request,
            matching.isEmpty
                ? 'FA03_PWR03_TERMINAL_MISSING'
                : 'FA03_PWR03_TERMINAL_AMBIGUOUS',
            contractSnapshot.contentHash,
            contractSnapshot.contentHash,
            dependencies,
            <String, Object?>{
              'caseId': caseContract.caseId,
              'terminalId': mapping.key,
              'loadId': mapping.value,
              'matchCount': matching.length,
              'evaluationId': pwr03.evaluationId,
              'nodeKeySha256': pwr03.nodeKey.sha256,
              'pointerGeneration': pwr03.pointerGeneration,
              'evidenceSha256': pwr03.evidenceSha256,
            },
          );
        }
        final row = matching.single;
        final minimum = _powerRational(row['minimumV'], 'minimumV');
        final maximum = _powerRational(row['maximumV'], 'maximumV');
        terminals.add(
          Fa03TerminalEvidence(
            terminalId: mapping.key,
            caseId: caseContract.caseId,
            scopeFingerprint: membership,
            voltage: Elv5Interval<VoltageDim>(
              Voltage(_elv5(minimum)),
              Voltage(_elv5(maximum)),
            ),
          ),
        );
      }
    }

    final input = Fa03Input(
      circuitId: contract.circuitId,
      model: switch (contract.model) {
        Fa03ContractModel.radialDc => Fa03ElectricalModel.radialDc,
        Fa03ContractModel.declaredOneControlPointDc =>
          Fa03ElectricalModel.declaredOneControlPointDc,
        Fa03ContractModel.unsupported => Fa03ElectricalModel.unsupported,
      },
      expectedScopeFingerprint: physicalScopeFingerprint!,
      terminals: terminals,
      policy: Fa03VoltagePolicy(
        minimum: Voltage(contract.minimumTerminalVoltageV),
        maximum: Voltage(contract.maximumTerminalVoltageV),
      ),
    );
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-fa03-captured-input.v1',
      'contractEvidenceRef': contractSnapshot.evidenceRef,
      'contractContentHash': contractSnapshot.contentHash,
      'contractScopeFingerprint': contract.scopeFingerprint,
      'physicalScopeFingerprint': physicalScopeFingerprint,
      'upstream':
          upstreamBasis..sort(
            (a, b) =>
                (a['caseId']! as String).compareTo(b['caseId']! as String),
          ),
    });
    return Elv5CapturedInput<Fa03Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: contractSnapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: upstreamGenerations,
      captureRevision: contractSnapshot.bindingRevision,
    );
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

Elv5PureKernelExecutor<Fa03Input, Fa03Result> buildFa03Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Fa03Input, Fa03Result>(
  processCode: Elv5ProcessCode.fa03,
  calculate: const Fa03TerminalVoltageKernel().evaluate,
  encodeOutput:
      (result) => <String, Object?>{
        'schema': 'electra.elv5-fa03-output.v1',
        'status': result.status.name,
        'governingTerminalId': result.governingTerminalId,
        'governingCaseId': result.governingCaseId,
        'blockingReason': result.blockingReason,
        'terminals': <Object?>[
          for (final item in result.terminals)
            <String, Object?>{
              'terminalId': item.terminalId,
              'caseId': item.caseId,
              'voltageLowerV': item.voltage.lower.value.toMap(),
              'voltageUpperV': item.voltage.upper.value.toMap(),
              'lowMarginV': item.lowMargin.value.toMap(),
              'highMarginV': item.highMargin.value.toMap(),
              'status': item.status.name,
            },
        ],
      },
  encodeEvidence:
      (captured, _) => <String, Object?>{
        'schema': 'electra.elv5-fa03-evidence.v1',
        'source': 'IMMUTABLE_FA03_CONTRACT_PLUS_VERIFIED_CURRENT_PWR03',
        'captureRevision': captured.captureRevision,
        'upstreamPointerGenerations': captured.upstreamPointerGenerations,
        'physicalScopeFingerprint': captured.value.expectedScopeFingerprint,
      },
  executionOf:
      (result) =>
          result.status == Fa03AssessmentStatus.blocked
              ? Elv5Execution.blocked
              : Elv5Execution.succeeded,
  completionOf:
      (result) =>
          result.status == Fa03AssessmentStatus.blocked
              ? Elv5Completion.incomplete
              : Elv5Completion.complete,
  assessmentOf:
      (result) => switch (result.status) {
        Fa03AssessmentStatus.pass => Elv5Assessment.pass,
        Fa03AssessmentStatus.fail => Elv5Assessment.fail,
        Fa03AssessmentStatus.blocked => Elv5Assessment.unresolved,
      },
  nowUtc: nowUtc,
);

List<Map<String, Object?>> _objects(Object? raw, String field) {
  if (raw is! List) throw FormatException('$field must be an array.');
  return <Map<String, Object?>>[for (final value in raw) _object(value, field)];
}

Map<String, Object?> _object(Object? raw, String field) {
  if (raw is! Map) throw FormatException('$field must be an object.');
  return Map<String, Object?>.from(raw);
}

PowerRational _powerRational(Object? raw, String field) {
  if (raw is! Map) throw FormatException('$field must be a rational map.');
  return PowerRational.fromMap(Map<String, Object?>.from(raw));
}

Elv5Rational _elv5(PowerRational value) =>
    Elv5Rational(value.numerator, value.denominator);
