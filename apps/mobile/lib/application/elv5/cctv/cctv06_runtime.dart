import 'dart:convert';

import 'package:engineering_core/engineering_core.dart'
    show PowerEvaluationScopeKind, PowerProcessCode;
import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../lan/elv3_realized_link_facts.dart';
import '../lan/elv5_lan_persistence.dart';
import '../persistence/elv5_runtime_persistence.dart';
import '../power/elv4_current_evidence_source.dart';
import 'cctv06_link_contract.dart';

final class Cctv06PersistedInputResolver
    implements Elv5ProcessInputResolver<Cctv06Input> {
  Cctv06PersistedInputResolver({
    required this.lanStore,
    required this.elv3Facts,
    required this.contractSource,
    required this.powerEvidence,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5LanFactStore lanStore;
  final Elv3RealizedLinkFactSource elv3Facts;
  final Cctv06LinkContractSource contractSource;
  final Elv4CurrentEvidenceSource powerEvidence;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.cctv06;

  @override
  Future<Elv5CapturedInput<Cctv06Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('CCTV06_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'LINK') {
      throw StateError('CCTV06_SUBJECT_KIND_MUST_BE_LINK');
    }
    final linkId = request.subject.id;
    final basis = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-cctv06-basis.v1',
      'linkId': linkId,
    });
    final dependencies = <Elv5DependencyMarker>[];

    final composition = await lanStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_LINK_COMPOSITION',
      subjectId: linkId,
    );
    if (composition == null) {
      _blocked(
        request,
        'CCTV06_LINK_COMPOSITION_REQUIRED',
        basis,
        basis,
        dependencies,
        <String, Object?>{'linkId': linkId},
      );
    }
    final compositionPayload = composition!.payload;
    if (_text(compositionPayload, 'linkId') != linkId) {
      throw StateError('CCTV06_LINK_IDENTITY_MISMATCH:$linkId');
    }
    final compositionFingerprint = _encoder.sha256(compositionPayload);
    dependencies.add(
      _dependency(request, 'SET', 'LAN_LINK_COMPOSITION', linkId),
    );

    final contractSnapshot = await contractSource.loadActiveForLink(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      linkId: linkId,
    );
    if (contractSnapshot == null) {
      _blocked(
        request,
        'CCTV06_LINK_CONTRACT_REQUIRED',
        compositionFingerprint,
        compositionFingerprint,
        dependencies,
        <String, Object?>{'linkId': linkId},
      );
    }
    final contract = contractSnapshot!.contract;
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'CCTV06_LINK_CONTRACT',
        contractSnapshot.evidenceRef,
        memberId:
            '${contractSnapshot.bindingId}:${contractSnapshot.bindingRevision}:${contractSnapshot.contentHash}',
      ),
    );
    if (contract.expectedCompositionFingerprint != compositionFingerprint) {
      _blocked(
        request,
        'CCTV06_LINK_COMPOSITION_FINGERPRINT_MISMATCH',
        compositionFingerprint,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'expected': contract.expectedCompositionFingerprint,
          'actual': compositionFingerprint,
        },
      );
    }

    final rows = _objects(compositionPayload['orderedSections'], 'orderedSections')
      ..sort((a, b) => _ordinal(a).compareTo(_ordinal(b)));
    for (var i = 0; i < rows.length; i++) {
      if (_ordinal(rows[i]) != i) {
        _blocked(
          request,
          'CCTV06_SECTION_ORDINAL_CLOSURE_INVALID',
          compositionFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'expectedOrdinal': i,
            'actualOrdinal': _ordinal(rows[i]),
          },
        );
      }
    }
    final pathIds = <String>[
      for (final row in rows) _text(row, 'realizedSectionId'),
    ];
    final contractIds = <String>[for (final item in contract.sections) item.sectionId];
    if (pathIds.length != contractIds.length ||
        List<bool>.generate(pathIds.length, (i) => pathIds[i] == contractIds[i])
            .contains(false)) {
      _blocked(
        request,
        'CCTV06_SECTION_MEMBERSHIP_ORDER_MISMATCH',
        compositionFingerprint,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'pathSections': pathIds,
          'contractSections': contractIds,
        },
      );
    }

    final sections = <Cctv06Section>[];
    final lengthEvidence = <Map<String, Object?>>[];
    for (final item in contract.sections) {
      final fact = await elv3Facts.requireSectionLength(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
        realizedSectionId: item.sectionId,
      );
      sections.add(
        Cctv06Section(
          sectionId: item.sectionId,
          length: Elv5Interval<LengthDim>(
            fact.installedLength.lower,
            fact.installedLength.upper,
          ),
          medium: _medium(item.mediumCode),
          interfaceKind: item.interfaceKind,
          categoryToken: item.categoryToken,
          shieldContinuityKnown: item.shieldContinuityKnown,
          shieldContinuity: item.shieldContinuity,
        ),
      );
      lengthEvidence.add(<String, Object?>{
        'sectionId': item.sectionId,
        'sourceFingerprint': fact.sourceFingerprint,
        'cableRunId': fact.cableRunId,
        'cableRunRevision': fact.cableRunRevision,
        'lengthLowerM': fact.installedLength.lower.value.toMap(),
        'lengthUpperM': fact.installedLength.upper.value.toMap(),
      });
      dependencies
        ..add(
          _dependency(
            request,
            'FACT',
            'ELV3_REALIZED_SECTION_LENGTH',
            item.sectionId,
            memberId: fact.sourceFingerprint,
          ),
        )
        ..add(
          _dependency(
            request,
            'FACT',
            'CCTV06_SECTION_TECHNICAL_EVIDENCE',
            item.sectionId,
            memberId: '${item.evidenceRef}:${item.evidenceContentHash}',
          ),
        );
    }
    final pathFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-cctv06-realized-path.v1',
      'compositionFingerprint': compositionFingerprint,
      'lengthEvidence': lengthEvidence,
    });

    Cctv06PowerEvidence? power;
    final generations = <String, int>{};
    final upstream = <Map<String, Object?>>[];
    if (contract.powered) {
      final current = await powerEvidence.loadCurrent(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
        processCode: PowerProcessCode.pwr06,
        scenarioId: contract.scenarioId,
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: contract.segmentId,
      );
      final group = <Elv4CurrentEvaluationSnapshot>[];
      for (final value in current) {
        if (value.output['groupId'] == contract.pseId) group.add(value);
      }
      group.sort((a, b) => a.nodeKey.subjectId.compareTo(b.nodeKey.subjectId));
      final actualDeliveries = <String>{for (final value in group) value.nodeKey.subjectId};
      final expectedDeliveries =
          contract.expectedPwr06InputFingerprintByDeliveryId.keys.toSet();
      if (!_sameSet(actualDeliveries, expectedDeliveries)) {
        _blocked(
          request,
          'CCTV06_PWR06_DELIVERY_SET_MISMATCH',
          pathFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'expected': expectedDeliveries.toList()..sort(),
            'actual': actualDeliveries.toList()..sort(),
          },
        );
      }
      Elv5Rational? globalMargin;
      for (final value in group) {
        final deliveryId = value.nodeKey.subjectId;
        if (value.nodeKey.subjectKind != 'POE_DELIVERY') {
          _blocked(
            request,
            'CCTV06_PWR06_SUBJECT_KIND_MISMATCH',
            pathFingerprint,
            contractSnapshot.contentHash,
            dependencies,
            <String, Object?>{
              'deliveryId': deliveryId,
              'subjectKind': value.nodeKey.subjectKind,
            },
          );
        }
        final expected =
            contract.expectedPwr06InputFingerprintByDeliveryId[deliveryId];
        if (value.inputFingerprint != expected) {
          _blocked(
            request,
            'CCTV06_PWR06_INPUT_FINGERPRINT_MISMATCH',
            pathFingerprint,
            contractSnapshot.contentHash,
            dependencies,
            <String, Object?>{
              'deliveryId': deliveryId,
              'expected': expected,
              'actual': value.inputFingerprint,
            },
          );
        }
        final margin = _rational(value.output['groupMarginW'], 'groupMarginW');
        if (globalMargin != null && globalMargin != margin) {
          _blocked(
            request,
            'CCTV06_PWR06_GROUP_MARGIN_DIVERGED',
            pathFingerprint,
            contractSnapshot.contentHash,
            dependencies,
            <String, Object?>{'deliveryId': deliveryId},
          );
        }
        globalMargin = margin;
        generations[value.nodeKey.sha256] = value.pointerGeneration;
        dependencies.add(
          _dependency(
            request,
            'EVAL',
            'ELV4_PWR06_CURRENT',
            value.evaluationId,
            memberId:
                '${value.nodeKey.sha256}:${value.pointerGeneration}:${value.evidenceSha256}',
          ),
        );
        upstream.add(<String, Object?>{
          'evaluationId': value.evaluationId,
          'nodeKeySha256': value.nodeKey.sha256,
          'generation': value.pointerGeneration,
          'inputFingerprint': value.inputFingerprint,
          'evidenceSha256': value.evidenceSha256,
        });
      }
      if (globalMargin == null) {
        _blocked(
          request,
          'CCTV06_PWR06_EVIDENCE_REQUIRED',
          pathFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'pseId': contract.pseId},
        );
      }
      final requiredSections = contract.poweredSectionToDeliveryId.keys.toSet();
      final evidencedSections = <String>{};
      for (final entry in contract.poweredSectionToDeliveryId.entries) {
        if (actualDeliveries.contains(entry.value)) evidencedSections.add(entry.key);
      }
      power = Cctv06PowerEvidence(
        pathFingerprint: pathFingerprint,
        globalMargin: Power(globalMargin!),
        requiredSegmentIds: requiredSections,
        evidencedSegmentIds: evidencedSections,
      );
    }

    final input = Cctv06Input(
      linkId: linkId,
      pathFingerprint: pathFingerprint,
      sections: sections,
      policy: Cctv06LinkPolicy(
        allowedMedia: contract.allowedMediaCodes.map(_medium).toSet(),
        allowedInterfaceKinds: contract.allowedInterfaceKinds,
        allowedCategoryTokens: contract.allowedCategoryTokens,
        shieldingRequired: contract.shieldingRequired,
        maximumLength:
            contract.maximumLengthM == null ? null : Length(contract.maximumLengthM!),
      ),
      powered: contract.powered,
      powerEvidence: power,
    );
    upstream.sort(
      (a, b) => (a['evaluationId']! as String)
          .compareTo(b['evaluationId']! as String),
    );
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-cctv06-captured-input.v1',
      'pathFingerprint': pathFingerprint,
      'contractContentHash': contractSnapshot.contentHash,
      'upstream': upstream,
    });
    return Elv5CapturedInput<Cctv06Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: contractSnapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: generations,
      captureRevision: composition.revision,
    );
  }

  Never _blocked(
    Elv5CalculationRequest request,
    String reason,
    String input,
    String policy,
    List<Elv5DependencyMarker> deps,
    Map<String, Object?> evidence,
  ) =>
      throw Elv5CaptureBlockedException(
        request: request,
        reasonCode: reason,
        inputFingerprint: input,
        policyFingerprint: policy,
        dependencies: deps,
        evidence: evidence,
      );

  Elv5DependencyMarker _dependency(
    Elv5CalculationRequest request,
    String relation,
    String domain,
    String subjectId, {
    String? memberId,
  }) {
    final value = <String, Object?>{
      'schema': 'electra.elv5-dependency-key.v1',
      'relationKind': relation,
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
      relationKind: relation,
      updatedAtUtc: _nowUtc().toUtc(),
    );
  }
}

Elv5PureKernelExecutor<Cctv06Input, Cctv06Result> buildCctv06Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Cctv06Input, Cctv06Result>(
  processCode: Elv5ProcessCode.cctv06,
  calculate: const Cctv06LinkBasisKernel().evaluate,
  encodeOutput: (r) => <String, Object?>{
    'schema': 'electra.elv5-cctv06-output.v1',
    'status': r.status.name,
    'realizedLengthM': r.realizedLength.toMap(),
    'lengthMarginM': r.lengthMargin?.value.toMap(),
    'powerStatus': r.powerStatus.name,
    'limitingSectionId': r.limitingSectionId,
    'limitingProperty': r.limitingProperty?.name,
    'blockingReason': r.blockingReason,
    'sections': <Object?>[
      for (final section in r.sectionResults)
        <String, Object?>{
          'sectionId': section.sectionId,
          'status': section.status.name,
          'properties': <String, Object?>{
            for (final entry in section.properties.entries)
              entry.key.name: entry.value.name,
          },
        },
    ],
  },
  encodeEvidence: (c, _) => <String, Object?>{
    'schema': 'electra.elv5-cctv06-evidence.v1',
    'source': 'ELV3_REALIZED_PATH_PLUS_IMMUTABLE_SECTION_EVIDENCE_PLUS_CURRENT_PWR06_WHEN_POWERED',
    'upstreamPointerGenerations': c.upstreamPointerGenerations,
    'captureRevision': c.captureRevision,
  },
  executionOf: (r) => r.status == Cctv06AssessmentStatus.blocked
      ? Elv5Execution.blocked
      : Elv5Execution.succeeded,
  completionOf: (r) =>
      r.status == Cctv06AssessmentStatus.blocked ||
              r.status == Cctv06AssessmentStatus.unresolved
          ? Elv5Completion.incomplete
          : Elv5Completion.complete,
  assessmentOf: (r) => switch (r.status) {
    Cctv06AssessmentStatus.pass => Elv5Assessment.pass,
    Cctv06AssessmentStatus.fail => Elv5Assessment.fail,
    Cctv06AssessmentStatus.unresolved => Elv5Assessment.unresolved,
    Cctv06AssessmentStatus.blocked => Elv5Assessment.unresolved,
    Cctv06AssessmentStatus.notApplicable => Elv5Assessment.notAssessed,
  },
  nowUtc: nowUtc,
);

Cctv06Medium _medium(String code) => switch (code.trim().toUpperCase()) {
  'COPPER' => Cctv06Medium.copper,
  'FIBER' => Cctv06Medium.fiber,
  'OTHER' => Cctv06Medium.other,
  _ => throw StateError('CCTV06_UNSUPPORTED_MEDIUM:$code'),
};
Elv5Rational _rational(Object? value, String field) =>
    Elv5Rational.fromMap(_map(value, field));
Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}
List<Map<String, Object?>> _objects(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be list.');
  return <Map<String, Object?>>[for (final raw in value) _map(raw, field)];
}
String _text(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be text.');
  }
  return value.trim();
}
int _ordinal(Map<String, Object?> value) {
  final raw = value['ordinal'];
  if (raw is! int || raw < 0) {
    throw const FormatException('ordinal must be nonnegative integer.');
  }
  return raw;
}
bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
