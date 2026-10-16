import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'elv3_realized_link_facts.dart';
import 'elv5_lan_persistence.dart';

final class Lan01PersistedInputResolver
    implements Elv5ProcessInputResolver<Lan01Input> {
  Lan01PersistedInputResolver({
    required this.lanStore,
    required this.elv3Facts,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5LanMutationStore lanStore;
  final Elv3RealizedLinkFactSource elv3Facts;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.lan01;

  @override
  Future<Elv5CapturedInput<Lan01Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('LAN01_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'LINK') {
      throw StateError('LAN01_SUBJECT_KIND_MUST_BE_LINK');
    }

    final composition = await lanStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_LINK_COMPOSITION',
      subjectId: request.subject.id,
    );
    if (composition == null) {
      throw StateError('LAN01_LINK_COMPOSITION_MISSING:${request.subject.id}');
    }
    final linkId = _text(composition.payload, 'linkId');
    if (linkId != request.subject.id) {
      throw StateError('LAN01_LINK_ID_MISMATCH:$linkId:${request.subject.id}');
    }
    final policyBindingId = _text(composition.payload, 'policyBindingId');
    final baseInputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-lan01-composition-capture.v1',
      'aggregateId': composition.aggregateId,
      'aggregateRevision': composition.revision,
      'payload': composition.payload,
    });
    final policyFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-lan01-policy-basis.v1',
      'policyBindingId': policyBindingId,
      'resolvedNumericPolicy': null,
    });

    final sections = <Lan01RealizedSection>[];
    final factFingerprints = <String>[];
    final dependencies = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'LAN_LINK_COMPOSITION', linkId),
      _dependency(request, 'POLICY', 'DISCIPLINE_POLICY', policyBindingId),
    ];
    final seen = <String>{};
    for (final raw in _objectList(composition.payload['orderedSections'])) {
      final id = _text(raw, 'realizedSectionId');
      if (!seen.add(id)) throw StateError('LAN01_DUPLICATE_SECTION:$id');
      Elv3RealizedSectionLengthFact fact;
      try {
        fact = await elv3Facts.requireSectionLength(
          projectId: request.projectId,
          designRevisionId: request.designRevisionId,
          realizedSectionId: id,
        );
      } on StateError catch (error) {
        final message = error.message.toString();
        if (message.startsWith('ELV3_REALIZED_SECTION_EXACT_RESERVE_REQUIRED') ||
            message.startsWith(
              'ELV3_REALIZED_SECTION_ALLOWANCE_PROVENANCE_REQUIRED',
            )) {
          final reasonCode = message.split(':').first;
          final sectionDependency = _dependency(
            request,
            'FACT',
            'ELV3_REALIZED_LINK_SECTION',
            id,
          );
          throw Elv5CaptureBlockedException(
            request: request,
            reasonCode: reasonCode,
            inputFingerprint: baseInputFingerprint,
            policyFingerprint: policyFingerprint,
            dependencies: <Elv5DependencyMarker>[
              ...dependencies,
              sectionDependency,
            ],
            evidence: <String, Object?>{
              'source': 'ELV5_LINK_COMPOSITION_PLUS_ELV3_INTEGER_GEOMETRY',
              'compositionAggregateId': composition.aggregateId,
              'compositionRevision': composition.revision,
              'realizedSectionId': id,
              'requiredCapability': reasonCode ==
                      'ELV3_REALIZED_SECTION_EXACT_RESERVE_REQUIRED'
                  ? 'EXACT_RESERVE_EVIDENCE'
                  : 'SECTION_ALLOWANCE_PROVENANCE',
            },
          );
        }
        rethrow;
      }
      factFingerprints.add(fact.sourceFingerprint);
      final sectionClass = switch (_text(raw, 'classification')) {
        'PERMANENT' => Lan01SectionClass.permanent,
        'PATCH' => Lan01SectionClass.patch,
        'OTHER_EXPLICIT' => Lan01SectionClass.otherExplicit,
        final value => throw StateError('LAN01_SECTION_CLASS_UNSUPPORTED:$value'),
      };
      sections.add(
        Lan01RealizedSection(
          sectionId: id,
          sectionClass: sectionClass,
          installedLength: fact.installedLength,
        ),
      );
      dependencies.add(
        _dependency(
          request,
          'FACT',
          'ELV3_REALIZED_LINK_SECTION',
          id,
          memberId: fact.sourceFingerprint,
        ),
      );
    }

    // The link binding currently stores a policy binding identity but not the
    // resolved numeric policy definition. Reporting the exact installed value
    // is valid; inventing 90/100 m limits is not. Policy thresholds therefore
    // remain absent until the immutable definition resolver is wired.
    final fingerprintBasis = <String, Object?>{
      'schema': 'electra.elv5-lan01-captured-input.v1',
      'compositionAggregateId': composition.aggregateId,
      'compositionRevision': composition.revision,
      'linkId': linkId,
      'orderedSections': [
        for (var i = 0; i < sections.length; i++)
          <String, Object?>{
            'id': sections[i].sectionId,
            'class': sections[i].sectionClass.name,
            'lengthLowerM': sections[i].installedLength.lower.value.toMap(),
            'lengthUpperM': sections[i].installedLength.upper.value.toMap(),
            'elv3Fingerprint': factFingerprints[i],
          },
      ],
    };

    return Elv5CapturedInput<Lan01Input>(
      request: request,
      value: Lan01Input(
        linkId: linkId,
        orderedSections: List.unmodifiable(sections),
        policy: const Lan01Policy(),
      ),
      inputFingerprint: _encoder.sha256(fingerprintBasis),
      policyFingerprint: policyFingerprint,
      dependencies: dependencies,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: composition.revision,
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

Elv5PureKernelExecutor<Lan01Input, Lan01Result> buildLan01Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Lan01Input, Lan01Result>(
  processCode: Elv5ProcessCode.lan01,
  calculate: const Lan01PathLengthKernel().evaluate,
  encodeOutput: (result) => <String, Object?>{
    'schema': 'electra.elv5-lan01-output.v1',
    'linkId': result.linkId,
    'permanent': _lengthAssessment(result.permanent),
    'channel': _lengthAssessment(result.channel),
    'governingDimension': result.governingDimension?.name,
  },
  encodeEvidence: (captured, _) => <String, Object?>{
    'schema': 'electra.elv5-lan01-evidence.v1',
    'source': 'ELV5_LINK_COMPOSITION_PLUS_ELV3_INTEGER_GEOMETRY',
    'captureRevision': captured.captureRevision,
    'numericPolicy': 'CONSERVATIVE_INTEGER_MM_SQRT_INTERVAL_V1',
    'numericThresholdPolicy': 'NOT_RESOLVED_V1',
  },
  executionOf: (_) => Elv5Execution.succeeded,
  completionOf: (_) => Elv5Completion.complete,
  assessmentOf: (result) {
    final statuses = <bool?>[result.permanent.passes, result.channel.passes];
    if (statuses.any((value) => value == false)) return Elv5Assessment.fail;
    if (statuses.any((value) => value == null)) return Elv5Assessment.notAssessed;
    return Elv5Assessment.pass;
  },
  nowUtc: nowUtc,
);

Map<String, Object?> _lengthAssessment(Lan01LengthAssessment value) =>
    <String, Object?>{
      'lengthLowerM': value.length.lower.value.toMap(),
      'lengthUpperM': value.length.upper.value.toMap(),
      'marginM': value.margin?.value.toMap(),
      'passes': value.passes,
    };

String _text(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return raw.trim();
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List) throw const FormatException('Expected object list.');
  return [
    for (final item in value)
      if (item is Map)
        Map<String, Object?>.from(item)
      else
        throw const FormatException('Expected object list entry.'),
  ];
}
