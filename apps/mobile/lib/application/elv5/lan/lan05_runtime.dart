import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'elv3_realized_link_facts.dart';
import 'elv5_lan_persistence.dart';
import 'lan05_optical_section_evidence.dart';

final class Lan05PersistedInputResolver
    implements Elv5ProcessInputResolver<Lan05Input> {
  Lan05PersistedInputResolver({
    required this.lanStore,
    required this.elv3Facts,
    required this.opticalEvidence,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5LanMutationStore lanStore;
  final Elv3RealizedLinkFactSource elv3Facts;
  final Lan05OpticalSectionEvidenceSource opticalEvidence;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.lan05;

  @override
  Future<Elv5CapturedInput<Lan05Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('LAN05_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'LINK') {
      throw StateError('LAN05_SUBJECT_KIND_MUST_BE_LINK');
    }

    final optical = await lanStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_OPTICAL_LINK_ASSIGNMENTS',
      subjectId: request.subject.id,
    );
    final composition = await lanStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_LINK_COMPOSITION',
      subjectId: request.subject.id,
    );
    if (optical == null || composition == null) {
      throw StateError('LAN05_REQUIRED_LINK_FACTS_MISSING:${request.subject.id}');
    }
    final linkId = _text(optical.payload, 'linkId');
    if (linkId != request.subject.id ||
        _text(composition.payload, 'linkId') != request.subject.id) {
      throw StateError('LAN05_LINK_ID_MISMATCH:${request.subject.id}');
    }

    final forward = _map(optical.payload['forwardOptics'], 'forwardOptics');
    final reverse = _map(optical.payload['reverseOptics'], 'reverseOptics');
    final forwardWave = _decimal(forward, 'wavelengthNm');
    final reverseWave = _decimal(reverse, 'wavelengthNm');
    final orderedSections = _objects(
      composition.payload['orderedSections'],
      'orderedSections',
    );
    final baseDependencies = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'LAN_OPTICAL_LINK', linkId),
      _dependency(request, 'SET', 'LAN_LINK_COMPOSITION', linkId),
    ];
    final baseInputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-lan05-capture-basis.v1',
      'opticalAggregateId': optical.aggregateId,
      'opticalRevision': optical.revision,
      'opticalPayload': optical.payload,
      'compositionAggregateId': composition.aggregateId,
      'compositionRevision': composition.revision,
      'compositionPayload': composition.payload,
    });
    final policyFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-lan05-policy-basis.v1',
      'forwardRequiredSensitivityMarginDb':
          forward['requiredSensitivityMarginDb'],
      'reverseRequiredSensitivityMarginDb':
          reverse['requiredSensitivityMarginDb'],
    });

    final forwardSections = <Lan05FiberSection>[];
    final reverseSections = <Lan05FiberSection>[];
    final sectionEvidence = <Map<String, Object?>>[];
    final dependencies = <Elv5DependencyMarker>[...baseDependencies];
    final seen = <String>{};
    for (final row in orderedSections) {
      final sectionId = _text(row, 'realizedSectionId');
      if (!seen.add(sectionId)) {
        throw StateError('LAN05_DUPLICATE_REALIZED_SECTION:$sectionId');
      }
      Elv3RealizedSectionLengthFact lengthFact;
      try {
        lengthFact = await elv3Facts.requireSectionLength(
          projectId: request.projectId,
          designRevisionId: request.designRevisionId,
          realizedSectionId: sectionId,
        );
      } on StateError catch (error) {
        final message = error.message.toString();
        if (message.startsWith('ELV3_REALIZED_SECTION_EXACT_RESERVE_REQUIRED') ||
            message.startsWith(
              'ELV3_REALIZED_SECTION_ALLOWANCE_PROVENANCE_REQUIRED',
            )) {
          throw _blocked(
            request: request,
            reasonCode: message.split(':').first,
            inputFingerprint: baseInputFingerprint,
            policyFingerprint: policyFingerprint,
            dependencies: <Elv5DependencyMarker>[
              ...dependencies,
              _dependency(
                request,
                'FACT',
                'ELV3_REALIZED_LINK_SECTION',
                sectionId,
              ),
            ],
            evidence: <String, Object?>{
              'linkId': linkId,
              'realizedSectionId': sectionId,
              'requiredCapability': 'EXACT_INSTALLED_LENGTH_EVIDENCE',
            },
          );
        }
        rethrow;
      }

      final forwardAttenuation = await opticalEvidence.findAttenuation(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
        realizedSectionId: sectionId,
        wavelengthNm: forwardWave,
      );
      final reverseAttenuation = forwardWave == reverseWave
          ? forwardAttenuation
          : await opticalEvidence.findAttenuation(
              projectId: request.projectId,
              designRevisionId: request.designRevisionId,
              realizedSectionId: sectionId,
              wavelengthNm: reverseWave,
            );
      if (forwardAttenuation == null || reverseAttenuation == null) {
        final missingWaves = <String>[
          if (forwardAttenuation == null) forwardWave.toString(),
          if (reverseAttenuation == null) reverseWave.toString(),
        ]..sort();
        throw _blocked(
          request: request,
          reasonCode: 'LAN05_SECTION_ATTENUATION_EVIDENCE_MISSING',
          inputFingerprint: baseInputFingerprint,
          policyFingerprint: policyFingerprint,
          dependencies: <Elv5DependencyMarker>[
            ...dependencies,
            _dependency(
              request,
              'FACT',
              'LAN_OPTICAL_SECTION_EVIDENCE',
              sectionId,
            ),
          ],
          evidence: <String, Object?>{
            'linkId': linkId,
            'realizedSectionId': sectionId,
            'missingWavelengthNm': missingWaves,
            'requiredEvidenceSchema': 'electra.elv5-optical-fiber-evidence.v1',
          },
        );
      }

      final length = Lan05LengthInterval(
        lower: lengthFact.installedLength.lower,
        upper: lengthFact.installedLength.upper,
      );
      forwardSections.add(
        Lan05FiberSection(
          sectionId: sectionId,
          wavelengthNm: forwardWave,
          lengthMeters: length,
          attenuationDbPerKm: forwardAttenuation.attenuationDbPerKm,
        ),
      );
      reverseSections.add(
        Lan05FiberSection(
          sectionId: sectionId,
          wavelengthNm: reverseWave,
          lengthMeters: length,
          attenuationDbPerKm: reverseAttenuation.attenuationDbPerKm,
        ),
      );
      sectionEvidence.add(<String, Object?>{
        'sectionId': sectionId,
        'lengthFingerprint': lengthFact.sourceFingerprint,
        'forwardAttenuationFingerprint':
            forwardAttenuation.evidenceFingerprint,
        'reverseAttenuationFingerprint':
            reverseAttenuation.evidenceFingerprint,
      });
      dependencies.addAll(<Elv5DependencyMarker>[
        _dependency(
          request,
          'FACT',
          'ELV3_REALIZED_LINK_SECTION',
          sectionId,
          memberId: lengthFact.sourceFingerprint,
        ),
        _dependency(
          request,
          'FACT',
          'LAN_OPTICAL_SECTION_EVIDENCE',
          sectionId,
          memberId: forwardAttenuation.evidenceFingerprint,
        ),
        if (reverseAttenuation.evidenceFingerprint !=
            forwardAttenuation.evidenceFingerprint)
          _dependency(
            request,
            'FACT',
            'LAN_OPTICAL_SECTION_EVIDENCE',
            sectionId,
            memberId: reverseAttenuation.evidenceFingerprint,
          ),
      ]);
    }

    final events = <Lan05LossEvent>[
      for (final event in _objects(
        optical.payload['connectorEvents'],
        'connectorEvents',
      ))
        _lossEvent(event, Lan05LossEventKind.connectorPair),
      for (final event in _objects(
        optical.payload['spliceEvents'],
        'spliceEvents',
      ))
        _lossEvent(event, Lan05LossEventKind.splice),
    ];

    final input = Lan05Input(
      aToB: _direction(forward, forwardWave, forwardSections, events),
      bToA: _direction(reverse, reverseWave, reverseSections, events),
    );
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-lan05-captured-input.v1',
      'baseFingerprint': baseInputFingerprint,
      'sectionEvidence': sectionEvidence,
    });

    return Elv5CapturedInput<Lan05Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: policyFingerprint,
      dependencies: dependencies,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: optical.revision > composition.revision
          ? optical.revision
          : composition.revision,
    );
  }

  Lan05DirectionInput _direction(
    Map<String, Object?> optics,
    Elv5Rational wavelength,
    List<Lan05FiberSection> sections,
    List<Lan05LossEvent> events,
  ) => Lan05DirectionInput(
    wavelengthNm: wavelength,
    sections: List.unmodifiable(sections),
    events: List.unmodifiable(events),
    txMin: LevelDbm(_decimal(optics, 'txMinDbm')),
    txMax: LevelDbm(_decimal(optics, 'txMaxDbm')),
    rxSensitivity: LevelDbm(_decimal(optics, 'receiverSensitivityDbm')),
    rxOverloadMax: LevelDbm(_decimal(optics, 'receiverOverloadDbm')),
    requiredSensitivityMargin: LossDb(
      _decimal(optics, 'requiredSensitivityMarginDb'),
    ),
  );

  Lan05LossEvent _lossEvent(
    Map<String, Object?> value,
    Lan05LossEventKind kind,
  ) => Lan05LossEvent(
    eventId: _text(value, 'eventId'),
    kind: kind,
    loss: Lan05LossInterval(
      lower: LossDb(_decimal(value, 'lossMinDb')),
      upper: LossDb(_decimal(value, 'lossMaxDb')),
    ),
  );

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

Elv5PureKernelExecutor<Lan05Input, Lan05Result> buildLan05Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Lan05Input, Lan05Result>(
  processCode: Elv5ProcessCode.lan05,
  calculate: const Lan05OpticalBudgetKernel().evaluate,
  encodeOutput: (result) => <String, Object?>{
    'schema': 'electra.elv5-lan05-output.v1',
    'aToB': _directionResult(result.aToB),
    'bToA': _directionResult(result.bToA),
    'governingCase': result.governingCase?.name,
    'governingMarginDb': result.governingMargin?.value.toMap(),
    'passes': result.passes,
  },
  encodeEvidence: (captured, _) => <String, Object?>{
    'schema': 'electra.elv5-lan05-evidence.v1',
    'source': 'ELV5_OPTICAL_LINK_PLUS_ELV3_PATH_PLUS_SECTION_EVIDENCE',
    'captureRevision': captured.captureRevision,
    'sectionEvidenceSchema': 'electra.elv5-optical-fiber-evidence.v1',
  },
  executionOf: (_) => Elv5Execution.succeeded,
  completionOf: (result) =>
      result.passes == null ? Elv5Completion.incomplete : Elv5Completion.complete,
  assessmentOf: (result) => switch (result.passes) {
    true => Elv5Assessment.pass,
    false => Elv5Assessment.fail,
    null => Elv5Assessment.unresolved,
  },
  nowUtc: nowUtc,
);

Map<String, Object?> _directionResult(Lan05DirectionResult result) =>
    <String, Object?>{
      'physicalLossMinDb': result.physicalLoss.lower.value.toMap(),
      'physicalLossMaxDb': result.physicalLoss.upper.value.toMap(),
      'rxLowDbm': result.rxLow?.value.toMap(),
      'rxHighDbm': result.rxHigh?.value.toMap(),
      'sensitivityMarginDb': result.sensitivity.margin?.value.toMap(),
      'sensitivityPasses': result.sensitivity.passes,
      'overloadMarginDb': result.overload.margin?.value.toMap(),
      'overloadPasses': result.overload.passes,
    };

Elv5CaptureBlockedException _blocked({
  required Elv5CalculationRequest request,
  required String reasonCode,
  required String inputFingerprint,
  required String policyFingerprint,
  required List<Elv5DependencyMarker> dependencies,
  required Map<String, Object?> evidence,
}) => Elv5CaptureBlockedException(
  request: request,
  reasonCode: reasonCode,
  inputFingerprint: inputFingerprint,
  policyFingerprint: policyFingerprint,
  dependencies: dependencies,
  evidence: evidence,
);

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

List<Map<String, Object?>> _objects(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be list.');
  return [for (final item in value) _map(item, field)];
}

String _text(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return raw.trim();
}

Elv5Rational _decimal(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String) throw FormatException('$key must be exact decimal text.');
  return Elv5Rational.parseDecimal(raw);
}
