import 'dart:convert';

import 'package:engineering_core/engineering_core.dart'
    show
        AcPowerDemand,
        DcConstantCurrentDemand,
        DcConstantPowerDemand,
        PowerDemand,
        PowerEvaluationScopeKind,
        PowerNodeKeyV2,
        PowerProcessCode,
        PowerRational;
import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import '../power/elv4_current_evidence_source.dart';
import 'fa05_autonomy_contract.dart';

final class Fa05PersistedInputResolver
    implements Elv5ProcessInputResolver<Fa05Input> {
  Fa05PersistedInputResolver({
    required this.contractSource,
    required this.powerEvidence,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Fa05AutonomyContractSource contractSource;
  final Elv4CurrentEvidenceSource powerEvidence;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.fa05;

  @override
  Future<Elv5CapturedInput<Fa05Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('FA05_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'POWER_BANK') {
      throw StateError('FA05_SUBJECT_KIND_MUST_BE_POWER_BANK');
    }

    final dependencies = <Elv5DependencyMarker>[];
    final snapshot = await contractSource.loadActiveForBank(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      bankId: request.subject.id,
    );
    if (snapshot == null) {
      _blocked(
        request,
        'FA05_EXACT_AUTONOMY_CONTRACT_REQUIRED',
        _encoder.sha256(<String, Object?>{
          'schema': 'electra.elv5-fa05-missing-contract.v1',
          'bankId': request.subject.id,
        }),
        _encoder.sha256(<String, Object?>{
          'schema': 'electra.elv5-fa05-policy-missing.v1',
          'bankId': request.subject.id,
        }),
        dependencies,
        <String, Object?>{'bankId': request.subject.id},
      );
    }
    final contract = snapshot!.contract;
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'FA05_AUTONOMY_CONTRACT',
        snapshot.evidenceRef,
        memberId:
            '${snapshot.bindingId}:${snapshot.bindingRevision}:${snapshot.contentHash}',
      ),
    );

    if (contract.requirePeakCurrentEvidence ||
        contract.requireEndOfDischargeEvidence) {
      _blocked(
        request,
        'FA05_PWR04_REQUIRED_DIMENSION_UNSUPPORTED',
        snapshot.contentHash,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{
          'bankId': contract.bankId,
          'requirePeakCurrentEvidence': contract.requirePeakCurrentEvidence,
          'requireEndOfDischargeEvidence':
              contract.requireEndOfDischargeEvidence,
          'supportedPwr04Model': 'ELV4_SIMPLE_WH_ENERGY_ONLY',
        },
      );
    }

    final pwr04Values = await powerEvidence.loadCurrent(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      processCode: PowerProcessCode.pwr04,
      scenarioId: contract.scenarioId,
      scopeKind: PowerEvaluationScopeKind.sequence,
      scopeId: contract.scenarioId,
      subjectKind: 'BATTERY_BANK',
      subjectId: contract.bankId,
    );
    if (pwr04Values.length != 1) {
      _blocked(
        request,
        pwr04Values.isEmpty
            ? 'FA05_PWR04_SEQUENCE_EVIDENCE_MISSING'
            : 'FA05_PWR04_SEQUENCE_EVIDENCE_AMBIGUOUS',
        snapshot.contentHash,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{'matchCount': pwr04Values.length},
      );
    }
    final pwr04 = pwr04Values.single;
    if (pwr04.inputFingerprint != contract.expectedPwr04InputFingerprint) {
      _blocked(
        request,
        'FA05_PWR04_INPUT_FINGERPRINT_MISMATCH',
        snapshot.contentHash,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{
          'expected': contract.expectedPwr04InputFingerprint,
          'actual': pwr04.inputFingerprint,
        },
      );
    }

    final pwr04Inputs = _map(pwr04.evidence['inputs'], 'PWR04 inputs');
    if (_text(pwr04Inputs, 'sequenceId') != contract.sequenceId ||
        _text(pwr04Inputs, 'bankId') != contract.bankId) {
      throw StateError('FA05_PWR04_CONTRACT_IDENTITY_MISMATCH');
    }
    _verifyConsumedSequence(
      request,
      contract,
      pwr04,
      snapshot.contentHash,
      dependencies,
    );

    final pwr04Output = pwr04.output;
    final requiredWh = _powerRational(pwr04Output['requiredWh'], 'requiredWh');
    final availableWh = _powerRational(
      pwr04Output['availableWh'],
      'availableWh',
    );
    dependencies.add(
      _dependency(
        request,
        'UPSTREAM_EVALUATION',
        'ELV4_PWR04_CURRENT',
        pwr04.evaluationId,
        memberId:
            '${pwr04.nodeKey.sha256}:${pwr04.pointerGeneration}:${pwr04.evidenceSha256}',
      ),
    );
    final generations = <String, int>{
      pwr04.nodeKey.sha256: pwr04.pointerGeneration,
    };

    final rawRefs = pwr04.evidence['consumedEvaluations'];
    if (rawRefs is! List) {
      throw StateError('FA05_PWR04_CONSUMED_EVALUATIONS_MISSING');
    }
    final consumedRefs = <_ConsumedEvaluationRef>[
      for (final raw in rawRefs)
        _ConsumedEvaluationRef.fromMap(_map(raw, 'PWR04 consumed evaluation')),
    ];

    final actualGlobalLoads = <String>{};
    final fireEnergyByLoad = <String, PowerRational>{
      for (final id in contract.fireProtectedLoadIds) id: PowerRational.zero,
    };
    final coveredSegments = <String>{};
    final segmentBasis = <Map<String, Object?>>[];

    for (final segment in contract.segments) {
      final matches =
          consumedRefs.where((ref) {
            final key = ref.nodeKey;
            return key.processCode == PowerProcessCode.pwr01 &&
                key.scenarioId == contract.scenarioId &&
                key.scopeKind == PowerEvaluationScopeKind.segment &&
                key.scopeId == segment.segmentId;
          }).toList();
      if (matches.length != 1) {
        _blocked(
          request,
          matches.isEmpty
              ? 'FA05_PWR01_SEGMENT_DEPENDENCY_MISSING'
              : 'FA05_PWR01_SEGMENT_DEPENDENCY_AMBIGUOUS',
          snapshot.contentHash,
          snapshot.contentHash,
          dependencies,
          <String, Object?>{
            'segmentId': segment.segmentId,
            'matchCount': matches.length,
          },
        );
      }
      final consumed = matches.single;
      final key = consumed.nodeKey;
      final values = await powerEvidence.loadCurrent(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
        processCode: PowerProcessCode.pwr01,
        scenarioId: key.scenarioId,
        scopeKind: key.scopeKind,
        scopeId: key.scopeId,
        subjectKind: key.subjectKind,
        subjectId: key.subjectId,
      );
      if (values.length != 1) {
        _blocked(
          request,
          values.isEmpty
              ? 'FA05_PWR01_CURRENT_EVIDENCE_MISSING'
              : 'FA05_PWR01_CURRENT_EVIDENCE_AMBIGUOUS',
          snapshot.contentHash,
          snapshot.contentHash,
          dependencies,
          <String, Object?>{
            'segmentId': segment.segmentId,
            'matchCount': values.length,
          },
        );
      }
      final pwr01 = values.single;
      if (pwr01.evaluationId != consumed.evaluationId ||
          pwr01.inputFingerprint != consumed.inputFingerprint) {
        _blocked(
          request,
          'FA05_PWR04_CONSUMED_PWR01_IDENTITY_STALE',
          snapshot.contentHash,
          snapshot.contentHash,
          dependencies,
          <String, Object?>{'segmentId': segment.segmentId},
        );
      }
      if (pwr01.output['completeW'] != true) {
        _blocked(
          request,
          'FA05_PWR01_SEGMENT_WATT_INCOMPLETE',
          snapshot.contentHash,
          snapshot.contentHash,
          dependencies,
          <String, Object?>{'segmentId': segment.segmentId},
        );
      }

      final inputs = _map(pwr01.evidence['inputs'], 'PWR01 inputs');
      final rawContributions = inputs['contributions'];
      if (rawContributions is! List) {
        throw StateError(
          'FA05_PWR01_CONTRIBUTIONS_MISSING:${pwr01.evaluationId}',
        );
      }
      final durationSeconds = PowerRational(
        segment.durationMicroseconds,
        BigInt.from(1000000),
      );
      final segmentLoads = <String>{};
      var segmentKnownW = PowerRational.zero;
      for (final raw in rawContributions) {
        final contribution = _map(raw, 'PWR01 contribution');
        final originId = _text(contribution, 'originId');
        segmentLoads.add(originId);
        actualGlobalLoads.add(originId);
        final watt = _resolvedContributionW(contribution);
        segmentKnownW += watt;
        if (contract.fireProtectedLoadIds.contains(originId)) {
          final energyWh = watt * durationSeconds / PowerRational.integer(3600);
          fireEnergyByLoad[originId] = fireEnergyByLoad[originId]! + energyWh;
        }
      }
      if (!_sameSet(segmentLoads, contract.globalProtectedLoadIds)) {
        _blocked(
          request,
          'FA05_SEGMENT_PROTECTED_LOAD_SET_MISMATCH',
          snapshot.contentHash,
          snapshot.contentHash,
          dependencies,
          <String, Object?>{
            'segmentId': segment.segmentId,
            'expectedLoadIds': contract.globalProtectedLoadIds.toList()..sort(),
            'actualLoadIds': segmentLoads.toList()..sort(),
          },
        );
      }
      if (segmentKnownW !=
          _powerRational(pwr01.output['knownW'], 'PWR01 knownW')) {
        _blocked(
          request,
          'FA05_PWR01_CONTRIBUTION_SUM_MISMATCH',
          snapshot.contentHash,
          snapshot.contentHash,
          dependencies,
          <String, Object?>{'segmentId': segment.segmentId},
        );
      }

      coveredSegments.add(segment.segmentId);
      generations[pwr01.nodeKey.sha256] = pwr01.pointerGeneration;
      dependencies.add(
        _dependency(
          request,
          'UPSTREAM_EVALUATION',
          'ELV4_PWR01_CURRENT',
          pwr01.evaluationId,
          memberId:
              '${pwr01.nodeKey.sha256}:${pwr01.pointerGeneration}:${pwr01.evidenceSha256}',
        ),
      );
      segmentBasis.add(<String, Object?>{
        'segmentId': segment.segmentId,
        'durationMicroseconds': segment.durationMicroseconds.toString(),
        'pwr01EvaluationId': pwr01.evaluationId,
        'pwr01InputFingerprint': pwr01.inputFingerprint,
      });
    }

    if (!_sameSet(actualGlobalLoads, contract.globalProtectedLoadIds)) {
      _blocked(
        request,
        'FA05_PROTECTED_LOAD_SET_MISMATCH',
        snapshot.contentHash,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{
          'expectedLoadIds': contract.globalProtectedLoadIds.toList()..sort(),
          'actualLoadIds': actualGlobalLoads.toList()..sort(),
        },
      );
    }

    final actualProtectedLoadFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-protected-load-set-fingerprint.v1',
      'loadIds': actualGlobalLoads.toList()..sort(),
    });
    final contributors = <Fa05ContributorEnergy>[
      for (final id in (contract.fireProtectedLoadIds.toList()..sort()))
        Fa05ContributorEnergy(
          loadId: id,
          energy: Energy(_elv5(fireEnergyByLoad[id]!)),
        ),
    ];
    final evidence = Fa05Pwr04Evidence(
      sequenceFingerprint: contract.sequenceFingerprint,
      protectedLoadSetFingerprint: actualProtectedLoadFingerprint,
      coveredSegmentIds: coveredSegments,
      globalRequiredEnergy: Energy(_elv5(requiredWh)),
      availableEnergy: Energy(_elv5(availableWh)),
      contributors: contributors,
      governingDimension: Fa05GoverningDimension.energy,
      governingSegmentId: null,
      peakCurrentMargin: null,
      endOfDischargePass: true,
    );
    final input = Fa05Input(
      bankId: contract.bankId,
      expectedSequenceFingerprint: contract.sequenceFingerprint,
      expectedProtectedLoadSetFingerprint: contract.protectedLoadSetFingerprint,
      sequence: <Fa05SequenceSegment>[
        for (final segment in contract.segments)
          Fa05SequenceSegment(
            segmentId: segment.segmentId,
            durationMicroseconds: segment.durationMicroseconds,
          ),
      ],
      fireProtectedLoadIds: contract.fireProtectedLoadIds,
      evidence: evidence,
    );

    return Elv5CapturedInput<Fa05Input>(
      request: request,
      value: input,
      inputFingerprint: _encoder.sha256(<String, Object?>{
        'schema': 'electra.elv5-fa05-captured-input.v1',
        'contractContentHash': snapshot.contentHash,
        'pwr04EvaluationId': pwr04.evaluationId,
        'pwr04InputFingerprint': pwr04.inputFingerprint,
        'segments': segmentBasis,
        'protectedLoadSetFingerprint': actualProtectedLoadFingerprint,
      }),
      policyFingerprint: snapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: generations,
      captureRevision: snapshot.bindingRevision,
    );
  }

  void _verifyConsumedSequence(
    Elv5CalculationRequest request,
    Fa05AutonomyContract contract,
    Elv4CurrentEvaluationSnapshot pwr04,
    String policyFingerprint,
    List<Elv5DependencyMarker> dependencies,
  ) {
    final rawFacts = pwr04.evidence['consumedFacts'];
    if (rawFacts is! List) {
      throw StateError('FA05_PWR04_CONSUMED_FACTS_MISSING');
    }
    final sequenceFacts = <Map<String, Object?>>[];
    for (final raw in rawFacts) {
      final fact = _map(raw, 'PWR04 consumed fact');
      if (fact['valueSchema'] == 'electra.elv4.backup-sequence.v1') {
        sequenceFacts.add(fact);
      }
    }
    if (sequenceFacts.length != 1) {
      _blocked(
        request,
        'FA05_PWR04_SEQUENCE_FACT_AMBIGUOUS',
        policyFingerprint,
        policyFingerprint,
        dependencies,
        <String, Object?>{'matchCount': sequenceFacts.length},
      );
    }
    final canonical = sequenceFacts.single['canonicalValueJson'];
    if (canonical is! String) {
      throw StateError('FA05_PWR04_SEQUENCE_FACT_VALUE_MISSING');
    }
    final decoded = jsonDecode(canonical);
    final value = _map(decoded, 'PWR04 sequence value');
    final rawSegments = value['segments'];
    if (rawSegments is! List) {
      throw StateError('FA05_PWR04_SEQUENCE_SEGMENTS_MISSING');
    }
    final persisted = <String, PowerRational>{};
    for (final raw in rawSegments) {
      final row = _map(raw, 'PWR04 sequence segment');
      persisted[_text(row, 'segmentId')] = _powerRational(
        row['durationSeconds'],
        'durationSeconds',
      );
    }
    if (persisted.length != contract.segments.length ||
        !contract.segments.every(
          (segment) => persisted.containsKey(segment.segmentId),
        )) {
      _blocked(
        request,
        'FA05_SEQUENCE_SEGMENT_SET_MISMATCH',
        policyFingerprint,
        policyFingerprint,
        dependencies,
        <String, Object?>{},
      );
    }
    for (final segment in contract.segments) {
      final expected = PowerRational(
        segment.durationMicroseconds,
        BigInt.from(1000000),
      );
      if (persisted[segment.segmentId] != expected) {
        _blocked(
          request,
          'FA05_SEQUENCE_DURATION_MISMATCH',
          policyFingerprint,
          policyFingerprint,
          dependencies,
          <String, Object?>{'segmentId': segment.segmentId},
        );
      }
    }
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

Elv5PureKernelExecutor<Fa05Input, Fa05Result> buildFa05Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Fa05Input, Fa05Result>(
  processCode: Elv5ProcessCode.fa05,
  calculate: const Fa05AutonomyProjectionKernel().evaluate,
  encodeOutput:
      (result) => <String, Object?>{
        'schema': 'electra.elv5-fa05-output.v1',
        'status': result.status.name,
        'globalRequiredEnergyWh': result.globalRequiredEnergy.value.toMap(),
        'availableEnergyWh': result.availableEnergy.value.toMap(),
        'energyMarginWh': result.energyMargin.value.toMap(),
        'fireContributionEnergyWh': result.fireContributionEnergy.value.toMap(),
        'governingDimension': result.governingDimension.name,
        'governingSegmentId': result.governingSegmentId,
        'blockingReason': result.blockingReason,
      },
  encodeEvidence:
      (captured, _) => <String, Object?>{
        'schema': 'electra.elv5-fa05-evidence.v1',
        'source': 'VERIFIED_CURRENT_PWR04_PLUS_CONSUMED_CURRENT_PWR01',
        'captureRevision': captured.captureRevision,
        'upstreamPointerGenerations': captured.upstreamPointerGenerations,
        'sequenceFingerprint': captured.value.expectedSequenceFingerprint,
        'protectedLoadSetFingerprint':
            captured.value.expectedProtectedLoadSetFingerprint,
      },
  executionOf:
      (result) =>
          result.status == Fa05AssessmentStatus.blocked
              ? Elv5Execution.blocked
              : Elv5Execution.succeeded,
  completionOf:
      (result) =>
          result.status == Fa05AssessmentStatus.blocked
              ? Elv5Completion.incomplete
              : Elv5Completion.complete,
  assessmentOf:
      (result) => switch (result.status) {
        Fa05AssessmentStatus.pass => Elv5Assessment.pass,
        Fa05AssessmentStatus.fail => Elv5Assessment.fail,
        Fa05AssessmentStatus.blocked => Elv5Assessment.unresolved,
      },
  nowUtc: nowUtc,
);

final class _ConsumedEvaluationRef {
  _ConsumedEvaluationRef({
    required this.nodeKey,
    required this.evaluationId,
    required this.inputFingerprint,
  });

  final PowerNodeKeyV2 nodeKey;
  final String evaluationId;
  final String inputFingerprint;

  factory _ConsumedEvaluationRef.fromMap(Map<String, Object?> map) =>
      _ConsumedEvaluationRef(
        nodeKey: PowerNodeKeyV2.decode(_text(map, 'logicalNodeKey')),
        evaluationId: _text(map, 'evaluationId'),
        inputFingerprint: _text(map, 'inputFingerprint'),
      );
}

PowerRational _resolvedContributionW(Map<String, Object?> contribution) {
  final rawDemand = contribution['demand'];
  if (rawDemand is! Map) {
    throw StateError('FA05_PWR01_CONTRIBUTOR_DEMAND_MISSING');
  }
  final demand = PowerDemand.fromMap(Map<String, Object?>.from(rawDemand));
  return switch (demand) {
    DcConstantPowerDemand(:final powerW) => powerW,
    AcPowerDemand(:final powerW) => powerW,
    DcConstantCurrentDemand(:final currentA) =>
      currentA *
          _powerRational(
            contribution['solvedTerminalVoltageV'],
            'solvedTerminalVoltageV',
          ),
  };
}

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

bool _sameSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);
