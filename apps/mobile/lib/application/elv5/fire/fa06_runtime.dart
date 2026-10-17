import 'dart:convert';

import 'package:engineering_core/engineering_core.dart'
    show PowerEvaluationScopeKind, PowerProcessCode, PowerRational;
import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import '../power/elv4_current_evidence_source.dart';
import 'elv5_fire_persistence.dart';
import 'fa06_notification_contract.dart';

final class Fa06PersistedInputResolver
    implements Elv5ProcessInputResolver<Fa06Input> {
  Fa06PersistedInputResolver({
    required this.fireStore,
    required this.contractSource,
    required this.powerEvidence,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5FireFactStore fireStore;
  final Fa06NotificationContractSource contractSource;
  final Elv4CurrentEvidenceSource powerEvidence;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.fa06;

  @override
  Future<Elv5CapturedInput<Fa06Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('FA06_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'FIRE_NOTIFICATION_CIRCUIT') {
      throw StateError('FA06_SUBJECT_KIND_MUST_BE_FIRE_NOTIFICATION_CIRCUIT');
    }

    final circuit = await fireStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_NOTIFICATION_CIRCUIT_ASSIGNMENTS',
      subjectId: request.subject.id,
    );
    if (circuit == null) {
      throw StateError('FA06_NOTIFICATION_CIRCUIT_FACTS_MISSING:${request.subject.id}');
    }
    final circuitId = _text(circuit.payload, 'circuitId');
    if (circuitId != request.subject.id) {
      throw StateError('FA06_CIRCUIT_ID_MISMATCH:$circuitId:${request.subject.id}');
    }

    final assignments = _objects(
      circuit.payload['deviceAssignments'],
      'deviceAssignments',
    );
    if (assignments.isEmpty) {
      _blocked(
        request,
        'FA06_NOTIFICATION_MEMBERSHIP_EMPTY',
        _aggregateFingerprint(circuit),
        _aggregateFingerprint(circuit),
        const <Elv5DependencyMarker>[],
        <String, Object?>{'circuitId': circuitId},
      );
    }
    final deviceIds = <String>[
      for (final row in assignments) _text(row, 'deviceId'),
    ]..sort();
    if (deviceIds.toSet().length != deviceIds.length) {
      throw StateError('FA06_DUPLICATE_PERSISTED_DEVICE_ID:$circuitId');
    }

    final dependencies = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'FIRE_NOTIFICATION_CIRCUIT', circuitId),
      for (final deviceId in deviceIds)
        _dependency(request, 'FACT', 'COMPONENT_REFERENCE_BINDING', deviceId),
    ];
    final aggregateFingerprint = _aggregateFingerprint(circuit);

    final contractSnapshot = await contractSource.loadActiveForCircuit(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      circuitId: circuitId,
    );
    if (contractSnapshot == null) {
      _blocked(
        request,
        'FA06_NOTIFICATION_CONTRACT_REQUIRED',
        aggregateFingerprint,
        aggregateFingerprint,
        dependencies,
        <String, Object?>{'circuitId': circuitId},
      );
    }
    final contract = contractSnapshot!.contract;
    if (contract.circuitId != circuitId) {
      throw StateError('FA06_CONTRACT_CIRCUIT_IDENTITY_MISMATCH:$circuitId');
    }
    if (contract.terminalLoadIdByDeviceId.keys.toSet().length != deviceIds.length ||
        !contract.terminalLoadIdByDeviceId.keys.toSet().containsAll(deviceIds)) {
      _blocked(
        request,
        'FA06_TERMINAL_MEMBERSHIP_MAPPING_MISMATCH',
        aggregateFingerprint,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'deviceIds': deviceIds,
          'mappedDeviceIds': contract.terminalLoadIdByDeviceId.keys.toList()..sort(),
        },
      );
    }
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'FA06_NOTIFICATION_CONTRACT',
        contractSnapshot.evidenceRef,
        memberId:
            '${contractSnapshot.bindingId}:${contractSnapshot.bindingRevision}:${contractSnapshot.contentHash}',
      ),
    );

    final membershipFingerprint = contract.membershipFingerprint(deviceIds);
    final cases = <Fa06ElectricalCaseEvidence>[];
    final upstreamGenerations = <String, int>{};
    final upstreamBasis = <Map<String, Object?>>[];

    for (final caseContract in contract.cases) {
      var expectedMilliamp = Elv5Rational.zero;
      final missingState = <String>[];
      for (final assignment in assignments) {
        final deviceId = _text(assignment, 'deviceId');
        final currents = _map(assignment['stateCurrentMa'], 'stateCurrentMa');
        final raw = currents[caseContract.stateCode];
        if (raw == null) {
          missingState.add(deviceId);
          continue;
        }
        if (raw is! String) {
          throw StateError('FA06_STATE_CURRENT_NOT_DECIMAL:$deviceId:${caseContract.stateCode}');
        }
        expectedMilliamp += Elv5Rational.parseDecimal(raw);
      }
      if (missingState.isNotEmpty) {
        _blocked(
          request,
          caseContract.operatingCase == Fa06ContractCase.startupInrush
              ? 'FA06_STARTUP_CURRENT_EVIDENCE_MISSING'
              : 'FA06_ACTIVE_CURRENT_EVIDENCE_MISSING',
          aggregateFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'stateCode': caseContract.stateCode,
            'missingDeviceIds': missingState..sort(),
          },
        );
      }
      final expectedA = expectedMilliamp / Elv5Rational.integer(1000);

      final pwr01 = await _requireSingle(
        request: request,
        processCode: PowerProcessCode.pwr01,
        scenarioId: caseContract.scenarioId,
        segmentId: caseContract.segmentId,
        subjectKind: caseContract.pwr01SubjectKind,
        subjectId: caseContract.pwr01SubjectId,
        reasonCode: 'FA06_PWR01_OUTPUT_CURRENT_MISSING',
        dependencies: dependencies,
        inputFingerprint: aggregateFingerprint,
        policyFingerprint: contractSnapshot.contentHash,
      );
      if (pwr01.output['completeA'] != true) {
        _blocked(
          request,
          'FA06_PWR01_OUTPUT_CURRENT_INCOMPLETE',
          aggregateFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'evaluationId': pwr01.evaluationId},
        );
      }
      final pwr01A = _powerRational(pwr01.output['knownA'], 'knownA');
      if (_elv5(pwr01A) != expectedA) {
        _blocked(
          request,
          'FA06_OUTPUT_CURRENT_CLOSURE_MISMATCH',
          aggregateFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'stateCode': caseContract.stateCode,
            'assignmentCurrentA': expectedA.toMap(),
            'pwr01CurrentA': pwr01A.toMap(),
            'evaluationId': pwr01.evaluationId,
          },
        );
      }

      final pwr03 = await _requireSingle(
        request: request,
        processCode: PowerProcessCode.pwr03,
        scenarioId: caseContract.scenarioId,
        segmentId: caseContract.segmentId,
        subjectKind: caseContract.pwr03SubjectKind,
        subjectId: caseContract.pwr03SubjectId,
        reasonCode: 'FA06_PWR03_TERMINAL_EVIDENCE_MISSING',
        dependencies: dependencies,
        inputFingerprint: aggregateFingerprint,
        policyFingerprint: contractSnapshot.contentHash,
      );
      if (pwr03.output['physicalComplete'] != true) {
        _blocked(
          request,
          'FA06_PWR03_PHYSICAL_CLOSURE_INCOMPLETE',
          aggregateFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'evaluationId': pwr03.evaluationId},
        );
      }

      PowerRational? minimumV;
      PowerRational? maximumV;
      for (final deviceId in deviceIds) {
        final terminalId = contract.terminalLoadIdByDeviceId[deviceId]!;
        final terminal = _singleById(
          pwr03.output['terminals'],
          'loadId',
          terminalId,
          'FA06_PWR03_DEVICE_TERMINAL_MISSING',
        );
        final low = _powerRational(terminal['minimumV'], 'minimumV');
        final high = _powerRational(terminal['maximumV'], 'maximumV');
        minimumV = minimumV == null || low < minimumV ? low : minimumV;
        maximumV = maximumV == null || high > maximumV ? high : maximumV;
      }

      final current = Current(expectedA);
      cases.add(
        Fa06ElectricalCaseEvidence(
          operatingCase: switch (caseContract.operatingCase) {
            Fa06ContractCase.activeNotification =>
              Fa06OperatingCase.activeNotification,
            Fa06ContractCase.startupInrush => Fa06OperatingCase.startupInrush,
          },
          membershipFingerprint: membershipFingerprint,
          outputCurrent: Elv5Interval<CurrentDim>(current, current),
          terminalVoltage: Elv5Interval<VoltageDim>(
            Voltage(_elv5(minimumV!)),
            Voltage(_elv5(maximumV!)),
          ),
          outputCurrentLimit: Current(contract.outputCurrentLimitA),
          minimumTerminalVoltage: Voltage(contract.minimumTerminalVoltageV),
          maximumTerminalVoltage: Voltage(contract.maximumTerminalVoltageV),
        ),
      );

      for (final snapshot in <Elv4CurrentEvaluationSnapshot>[pwr01, pwr03]) {
        upstreamGenerations[snapshot.nodeKey.sha256] = snapshot.pointerGeneration;
        dependencies.add(
          _dependency(
            request,
            'UPSTREAM_EVALUATION',
            snapshot.nodeKey.processCode == PowerProcessCode.pwr01
                ? 'ELV4_PWR01_CURRENT'
                : 'ELV4_PWR03_CURRENT',
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

    if (contract.supervision.required && contract.supervision.evidenceRef != null) {
      dependencies.add(
        _dependency(
          request,
          'FACT',
          'FIRE_SUPERVISION_EVIDENCE',
          contract.supervision.evidenceRef!,
          memberId: contract.supervision.evidenceContentHash,
        ),
      );
    }

    final input = Fa06Input(
      circuitId: circuitId,
      deviceIds: deviceIds,
      expectedMembershipFingerprint: membershipFingerprint,
      deviceLimit: contract.deviceLimit,
      cases: cases,
      supervision: Fa06SupervisionEvidence(
        required: contract.supervision.required,
        modelSupported: contract.supervision.modelSupported,
        passed: contract.supervision.passed,
      ),
    );
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-fa06-captured-input.v1',
      'aggregateFingerprint': aggregateFingerprint,
      'contractEvidenceRef': contractSnapshot.evidenceRef,
      'contractContentHash': contractSnapshot.contentHash,
      'membershipFingerprint': membershipFingerprint,
      'upstream': upstreamBasis
        ..sort((a, b) => (a['evaluationId']! as String)
            .compareTo(b['evaluationId']! as String)),
    });
    return Elv5CapturedInput<Fa06Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: contractSnapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: upstreamGenerations,
      captureRevision: circuit.revision,
    );
  }

  Future<Elv4CurrentEvaluationSnapshot> _requireSingle({
    required Elv5CalculationRequest request,
    required PowerProcessCode processCode,
    required String scenarioId,
    required String segmentId,
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
      scenarioId: scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: segmentId,
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
          'processCode': processCode.name,
          'scenarioId': scenarioId,
          'segmentId': segmentId,
          'subjectKind': subjectKind,
          'subjectId': subjectId,
          'matchCount': values.length,
        },
      );
    }
    return values.single;
  }

  String _aggregateFingerprint(Elv5FireAggregateSnapshot snapshot) =>
      _encoder.sha256(<String, Object?>{
        'schema': 'electra.elv5-fa06-notification-basis.v1',
        'aggregateId': snapshot.aggregateId,
        'aggregateRevision': snapshot.revision,
        'payload': snapshot.payload,
      });

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

Elv5PureKernelExecutor<Fa06Input, Fa06Result> buildFa06Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Fa06Input, Fa06Result>(
  processCode: Elv5ProcessCode.fa06,
  calculate: const Fa06NotificationCapacityKernel().evaluate,
  encodeOutput: (result) => <String, Object?>{
    'schema': 'electra.elv5-fa06-output.v1',
    'status': result.status.name,
    'activeDeviceCount': result.activeDeviceCount,
    'deviceCountMargin': result.deviceCountMargin,
    'governingCase': result.governingCase?.name,
    'governingDimension': result.governingDimension?.name,
    'blockingReason': result.blockingReason,
    'acousticCoverageAssessed': result.acousticCoverageAssessed,
    'cases': <String, Object?>{
      for (final entry in result.cases.entries)
        entry.key.name: <String, Object?>{
          'outputCurrentLowerA': entry.value.outputCurrent.lower.value.toMap(),
          'outputCurrentUpperA': entry.value.outputCurrent.upper.value.toMap(),
          'currentMarginA': entry.value.currentMargin.value.toMap(),
          'terminalVoltageLowerV': entry.value.terminalVoltage.lower.value.toMap(),
          'terminalVoltageUpperV': entry.value.terminalVoltage.upper.value.toMap(),
          'lowVoltageMarginV': entry.value.lowVoltageMargin.value.toMap(),
          'highVoltageMarginV': entry.value.highVoltageMargin.value.toMap(),
          'status': entry.value.status.name,
          'governingDimension': entry.value.governingDimension?.name,
        },
    },
  },
  encodeEvidence: (captured, _) => <String, Object?>{
    'schema': 'electra.elv5-fa06-evidence.v1',
    'source': 'PERSISTED_NOTIFICATION_ASSIGNMENTS_PLUS_VERIFIED_CURRENT_PWR01_PWR03',
    'captureRevision': captured.captureRevision,
    'upstreamPointerGenerations': captured.upstreamPointerGenerations,
    'membershipFingerprint': captured.value.expectedMembershipFingerprint,
  },
  executionOf: (result) => result.status == Fa06AssessmentStatus.blocked
      ? Elv5Execution.blocked
      : Elv5Execution.succeeded,
  completionOf: (result) => result.status == Fa06AssessmentStatus.blocked
      ? Elv5Completion.incomplete
      : Elv5Completion.complete,
  assessmentOf: (result) => switch (result.status) {
    Fa06AssessmentStatus.pass => Elv5Assessment.pass,
    Fa06AssessmentStatus.fail => Elv5Assessment.fail,
    Fa06AssessmentStatus.blocked => Elv5Assessment.unresolved,
  },
  nowUtc: nowUtc,
);

List<Map<String, Object?>> _objects(Object? raw, String field) {
  if (raw is! List) throw FormatException('$field must be an array.');
  return <Map<String, Object?>>[
    for (final value in raw) _map(value, field),
  ];
}

Map<String, Object?> _map(Object? raw, String field) {
  if (raw is! Map) throw FormatException('$field must be an object.');
  return Map<String, Object?>.from(raw);
}

String _text(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return raw.trim();
}

PowerRational _powerRational(Object? raw, String field) {
  if (raw is! Map) throw FormatException('$field must be a rational map.');
  return PowerRational.fromMap(Map<String, Object?>.from(raw));
}

Elv5Rational _elv5(PowerRational value) =>
    Elv5Rational(value.numerator, value.denominator);

Map<String, Object?> _singleById(
  Object? raw,
  String key,
  String id,
  String errorCode,
) {
  final matches = _objects(raw, key).where((value) => value[key] == id).toList();
  if (matches.length != 1) {
    throw StateError('$errorCode:$id:${matches.length}');
  }
  return matches.single;
}
