import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_current_evaluation_source.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'cctv05_capability_contract.dart';
import 'elv5_cctv_persistence.dart';
import 'elv5_cctv_recorder_persistence.dart';

final class Cctv05PersistedInputResolver
    implements Elv5ProcessInputResolver<Cctv05Input> {
  Cctv05PersistedInputResolver({
    required this.recorderStore,
    required this.cctvStore,
    required this.contractSource,
    required this.currentEvaluations,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5CctvRecorderFactStore recorderStore;
  final Elv5CctvFactStore cctvStore;
  final Cctv05CapabilityContractSource contractSource;
  final Elv5CurrentEvaluationSource currentEvaluations;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.cctv05;

  @override
  Future<Elv5CapturedInput<Cctv05Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode)
      throw StateError('CCTV05_RESOLVER_PROCESS_CODE_MISMATCH');
    if (request.subject.kind != 'RECORDER')
      throw StateError('CCTV05_SUBJECT_KIND_MUST_BE_RECORDER');
    final recorderId = request.subject.id;
    final basis = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-cctv05-basis.v1',
      'recorderId': recorderId,
    });
    final dependencies = <Elv5DependencyMarker>[];
    final recorder = await recorderStore.loadRecorder(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      recorderId: recorderId,
    );
    if (recorder == null)
      _blocked(
        request,
        'CCTV05_RECORDER_ASSIGNMENTS_REQUIRED',
        basis,
        basis,
        dependencies,
        <String, Object?>{'recorderId': recorderId},
      );
    final contractSnapshot = await contractSource.loadActiveForRecorder(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      recorderId: recorderId,
    );
    if (contractSnapshot == null)
      _blocked(
        request,
        'CCTV05_CAPABILITY_CONTRACT_REQUIRED',
        basis,
        basis,
        dependencies,
        <String, Object?>{'recorderId': recorderId},
      );
    final contract = contractSnapshot!.contract;
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'CCTV05_CAPABILITY_CONTRACT',
        contractSnapshot.evidenceRef,
        memberId:
            '${contractSnapshot.bindingId}:${contractSnapshot.bindingRevision}:${contractSnapshot.contentHash}',
      ),
    );

    final payload = recorder!.payload;
    final definitionRef = _map(
      payload['recorderDefinitionRef'],
      'recorderDefinitionRef',
    );
    final actualDefinitionId = _text(definitionRef, 'definitionId');
    final actualDefinitionVersion = _int(definitionRef, 'definitionVersion');
    if (actualDefinitionId != contract.expectedDefinitionId ||
        actualDefinitionVersion != contract.expectedDefinitionVersion) {
      _blocked(
        request,
        'CCTV05_RECORDER_DEFINITION_MISMATCH',
        basis,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'expectedDefinitionId': contract.expectedDefinitionId,
          'expectedDefinitionVersion': contract.expectedDefinitionVersion,
          'actualDefinitionId': actualDefinitionId,
          'actualDefinitionVersion': actualDefinitionVersion,
        },
      );
    }
    final rawAssignments = _objects(payload['assignments'], 'assignments')
      ..sort(_compareAssignments);
    if (rawAssignments.isEmpty)
      _blocked(
        request,
        'CCTV05_ASSIGNMENTS_REQUIRED',
        basis,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{'recorderId': recorderId},
      );
    final assignmentIds = <String>{};
    final cameraIds = <String>{};
    final poolIds = <String>{};
    for (final a in rawAssignments) {
      final assignmentId = _text(a, 'assignmentId');
      if (!assignmentIds.add(assignmentId)) {
        _blocked(
          request,
          'CCTV05_DUPLICATE_ASSIGNMENT_ID',
          basis,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'assignmentId': assignmentId},
        );
      }
      cameraIds.add(_text(a, 'cameraId'));
      poolIds.add(_text(a, 'storagePoolId'));
    }
    if (!_sameSet(
      cameraIds,
      contract.expectedCctv02InputFingerprintByCamera.keys.toSet(),
    )) {
      _blocked(
        request,
        'CCTV05_CAMERA_SCOPE_MISMATCH',
        basis,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'actual': cameraIds.toList()..sort(),
          'expected':
              contract.expectedCctv02InputFingerprintByCamera.keys.toList()
                ..sort(),
        },
      );
    }
    if (!_sameSet(
      poolIds,
      contract.expectedCctv03InputFingerprintByPool.keys.toSet(),
    )) {
      _blocked(
        request,
        'CCTV05_STORAGE_POOL_SCOPE_MISMATCH',
        basis,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'actual': poolIds.toList()..sort(),
          'expected':
              contract.expectedCctv03InputFingerprintByPool.keys.toList()
                ..sort(),
        },
      );
    }

    final codecByCameraStream = <String, String?>{};
    for (final cameraId in cameraIds.toList()..sort()) {
      final streams = await cctvStore.loadCameraStreams(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
        cameraId: cameraId,
      );
      if (streams == null)
        _blocked(
          request,
          'CCTV05_CAMERA_STREAM_FACTS_REQUIRED',
          basis,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'cameraId': cameraId},
        );
      final members = _objects(streams!.payload['streams'], 'streams');
      for (final stream in members) {
        final streamId = _text(stream, 'encodedStreamId');
        final raw = stream['codecProfileRef'];
        codecByCameraStream['$cameraId\u0000$streamId'] =
            raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
      }
      dependencies.add(
        _dependency(
          request,
          'SET',
          'CCTV_CAMERA_STREAMS',
          cameraId,
          memberId: '${streams.aggregateId}:${streams.revision}',
        ),
      );
    }

    var peakIngress = Elv5Rational.zero;
    final generations = <String, int>{};
    final upstream = <Map<String, Object?>>[];
    for (final cameraId in cameraIds.toList()..sort()) {
      final values = await currentEvaluations.loadCurrent(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
        processCode: Elv5ProcessCode.cctv02,
        subjectKind: 'CAMERA',
        subjectId: cameraId,
      );
      if (values.length != 1)
        _blocked(
          request,
          'CCTV05_CURRENT_CCTV02_REQUIRED',
          basis,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'cameraId': cameraId, 'matches': values.length},
        );
      final current = values.single;
      final expected =
          contract.expectedCctv02InputFingerprintByCamera[cameraId]!;
      if (current.inputFingerprint != expected)
        _blocked(
          request,
          'CCTV05_CCTV02_INPUT_FINGERPRINT_MISMATCH',
          basis,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'cameraId': cameraId,
            'expected': expected,
            'actual': current.inputFingerprint,
          },
        );
      final ingressRoot = _map(
        current.output['recorderIngress'],
        'recorderIngress',
      );
      final recorderIngress = ingressRoot[recorderId];
      if (recorderIngress is! Map)
        _blocked(
          request,
          'CCTV05_RECORDER_INGRESS_EVIDENCE_MISSING',
          basis,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'cameraId': cameraId, 'recorderId': recorderId},
        );
      final peak = _map(
        Map<String, Object?>.from(recorderIngress)['peak'],
        'peak',
      );
      if (peak['complete'] != true)
        _blocked(
          request,
          'CCTV05_PEAK_INGRESS_INCOMPLETE',
          basis,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'cameraId': cameraId},
        );
      peakIngress += Elv5Rational.fromMap(_map(peak['loadBps'], 'loadBps'));
      generations[current.logicalNodeKeySha256] = current.pointerGeneration;
      dependencies.add(_evalDependency(request, 'CCTV02_CURRENT', current));
      upstream.add(_upstream(current));
    }

    var requiredUsable = Elv5Rational.zero;
    Cctv05StorageClaimBasis? storageBasis;
    for (final poolId in poolIds.toList()..sort()) {
      final values = await currentEvaluations.loadCurrent(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
        processCode: Elv5ProcessCode.cctv03,
        subjectKind: 'RECORDING_POOL',
        subjectId: poolId,
      );
      if (values.length != 1)
        _blocked(
          request,
          'CCTV05_CURRENT_CCTV03_REQUIRED',
          basis,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'poolId': poolId, 'matches': values.length},
        );
      final current = values.single;
      final expected = contract.expectedCctv03InputFingerprintByPool[poolId]!;
      if (current.inputFingerprint != expected)
        _blocked(
          request,
          'CCTV05_CCTV03_INPUT_FINGERPRINT_MISMATCH',
          basis,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'poolId': poolId,
            'expected': expected,
            'actual': current.inputFingerprint,
          },
        );
      final currentBasis = switch (current.output['sizingBasis']) {
        'expectedEstimate' => Cctv05StorageClaimBasis.expectedEstimate,
        'guaranteedUpperBound' => Cctv05StorageClaimBasis.guaranteedUpperBound,
        final value => throw FormatException(
          'Unsupported CCTV03 sizingBasis for CCTV05: $value',
        ),
      };
      storageBasis ??= currentBasis;
      if (storageBasis != currentBasis)
        _blocked(
          request,
          'CCTV05_STORAGE_CLAIM_BASIS_DIVERGED',
          basis,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'poolId': poolId},
        );
      final usable = _map(current.output['usable'], 'usable');
      requiredUsable += Elv5Rational.fromMap(
        _map(usable['requiredBytes'], 'requiredBytes'),
      );
      generations[current.logicalNodeKeySha256] = current.pointerGeneration;
      dependencies.add(_evalDependency(request, 'CCTV03_CURRENT', current));
      upstream.add(_upstream(current));
    }

    final assignments = <Cctv05RecorderAssignment>[];
    for (final raw in rawAssignments) {
      final cameraId = _text(raw, 'cameraId');
      final streamId = _text(raw, 'encodedStreamId');
      assignments.add(
        Cctv05RecorderAssignment(
          assignmentId: _text(raw, 'assignmentId'),
          deviceId: cameraId,
          encodedStreamId: streamId,
          licenseChannelId: _text(raw, 'licenseChannelId'),
          codecProfile: codecByCameraStream['$cameraId\u0000$streamId'],
        ),
      );
    }
    final accounting = switch (_text(payload, 'accountingBasis')) {
      'DEVICE' => Cctv05ChannelAccountingBasis.device,
      'ENCODED_STREAM' => Cctv05ChannelAccountingBasis.encodedStream,
      'LICENSE_CHANNEL' => Cctv05ChannelAccountingBasis.licenseChannel,
      final value => throw FormatException(
        'Unsupported CCTV05 accountingBasis: $value',
      ),
    };
    upstream.sort(
      (a, b) => (a['evaluationId']! as String).compareTo(
        b['evaluationId']! as String,
      ),
    );
    final canonicalAssignments = <Object?>[
      for (final a in rawAssignments)
        <String, Object?>{
          'assignmentId': _text(a, 'assignmentId'),
          'cameraId': _text(a, 'cameraId'),
          'encodedStreamId': _text(a, 'encodedStreamId'),
          'licenseChannelId': _text(a, 'licenseChannelId'),
          'storagePoolId': _text(a, 'storagePoolId'),
        },
    ];
    final assignmentScope = <String, Object?>{
      'schema': 'electra.elv5-cctv05-assignment-scope.v1',
      'recorderId': recorderId,
      'assignments': canonicalAssignments,
    };
    final ingressScope = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-cctv05-ingress-scope.v1',
      'assignmentScope': assignmentScope,
      'cameras': cameraIds.toList()..sort(),
    });
    final storageScope = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-cctv05-storage-scope.v1',
      'assignmentScope': assignmentScope,
      'pools': poolIds.toList()..sort(),
    });
    final input = Cctv05Input(
      recorderId: recorderId,
      capability: Cctv05RecorderCapability(
        channelLimit: contract.channelLimit,
        peakIngressCapacity: BitRate(contract.peakIngressCapacityBps),
        usableStorageCapacity: ByteCapacity(
          contract.usableStorageCapacityBytes,
        ),
        supportedCodecProfiles: contract.supportedCodecProfiles,
      ),
      accountingBasis: accounting,
      assignments: assignments,
      expectedIngressScopeFingerprint: ingressScope,
      expectedStorageScopeFingerprint: storageScope,
      ingressEvidence: Cctv05IngressEvidence(
        scopeFingerprint: ingressScope,
        peakIngress: BitRate(peakIngress),
      ),
      storageEvidence: Cctv05StorageEvidence(
        scopeFingerprint: storageScope,
        basis: storageBasis!,
        requiredUsable: ByteCapacity(requiredUsable),
      ),
      requireGuaranteedStorage: contract.requireGuaranteedStorage,
    );
    final canonicalRecorderPayload = <String, Object?>{
      ...payload,
      'assignments': canonicalAssignments,
    };
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-cctv05-captured-input.v2',
      'recorderAggregateId': recorder.aggregateId,
      'recorderRevision': recorder.revision,
      'recorderPayload': canonicalRecorderPayload,
      'contractContentHash': contractSnapshot.contentHash,
      'upstream': upstream,
    });
    dependencies.add(
      _dependency(
        request,
        'SET',
        'CCTV_RECORDER',
        recorderId,
        memberId: '${recorder.aggregateId}:${recorder.revision}',
      ),
    );
    return Elv5CapturedInput<Cctv05Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: contractSnapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: generations,
      captureRevision: recorder.revision,
    );
  }

  Never _blocked(
    Elv5CalculationRequest request,
    String reason,
    String input,
    String policy,
    List<Elv5DependencyMarker> deps,
    Map<String, Object?> evidence,
  ) => throw Elv5CaptureBlockedException(
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

  Elv5DependencyMarker _evalDependency(
    Elv5CalculationRequest request,
    String domain,
    Elv5CurrentEvaluationSnapshot current,
  ) => _dependency(
    request,
    'EVAL',
    domain,
    current.evaluationId,
    memberId:
        '${current.logicalNodeKeySha256}:${current.pointerGeneration}:${current.outputSha256}:${current.evidenceSha256}',
  );
  Map<String, Object?> _upstream(Elv5CurrentEvaluationSnapshot c) =>
      <String, Object?>{
        'evaluationId': c.evaluationId,
        'nodeKeySha256': c.logicalNodeKeySha256,
        'generation': c.pointerGeneration,
        'inputFingerprint': c.inputFingerprint,
        'outputSha256': c.outputSha256,
        'evidenceSha256': c.evidenceSha256,
      };
}

Elv5PureKernelExecutor<Cctv05Input, Cctv05Result> buildCctv05Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Cctv05Input, Cctv05Result>(
  processCode: Elv5ProcessCode.cctv05,
  calculate: const Cctv05RecorderCapacityKernel().evaluate,
  encodeOutput: (r) => <String, Object?>{
    'schema': 'electra.elv5-cctv05-output.v1',
    'status': r.status.name,
    'consumedChannels': r.consumedChannels,
    'channelMargin': r.channelMargin,
    'peakIngressBps': r.peakIngress.value.toMap(),
    'ingressMarginBps': r.ingressMargin.value.toMap(),
    'requiredUsableBytes': r.requiredUsable.value.toMap(),
    'storageMarginBytes': r.storageMargin.value.toMap(),
    'codecResults': <Object?>[
      for (final v in r.codecResults)
        <String, Object?>{'streamId': v.streamId, 'status': v.status.name},
    ],
    'governingDimension': r.governingDimension?.name,
    'blockingReason': r.blockingReason,
  },
  encodeEvidence: (c, _) => <String, Object?>{
    'schema': 'electra.elv5-cctv05-evidence.v1',
    'source': 'CURRENT_CCTV02_RECORDER_INGRESS_PLUS_CURRENT_CCTV03_STORAGE',
    'upstreamPointerGenerations': c.upstreamPointerGenerations,
  },
  executionOf: (r) => r.status == Cctv05AssessmentStatus.blocked
      ? Elv5Execution.blocked
      : Elv5Execution.succeeded,
  completionOf: (r) => r.status == Cctv05AssessmentStatus.blocked
      ? Elv5Completion.incomplete
      : Elv5Completion.complete,
  assessmentOf: (r) => switch (r.status) {
    Cctv05AssessmentStatus.pass => Elv5Assessment.pass,
    Cctv05AssessmentStatus.fail => Elv5Assessment.fail,
    Cctv05AssessmentStatus.unresolved => Elv5Assessment.unresolved,
    Cctv05AssessmentStatus.blocked => Elv5Assessment.unresolved,
  },
  nowUtc: nowUtc,
);

int _compareAssignments(Map<String, Object?> a, Map<String, Object?> b) {
  for (final key in const <String>[
    'assignmentId',
    'cameraId',
    'encodedStreamId',
    'licenseChannelId',
    'storagePoolId',
  ]) {
    final comparison = _text(a, key).compareTo(_text(b, key));
    if (comparison != 0) return comparison;
  }
  return 0;
}

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
  if (value is! String || value.trim().isEmpty)
    throw FormatException('$key must be text.');
  return value.trim();
}

int _int(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('$key must be integer.');
  return value;
}

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
