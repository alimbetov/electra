import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../commands/elv5_replacement_command_runner.dart';
import '../persistence/elv5_replacement_persistence.dart';
import '../wire/elv5_wire_command.dart';
import '../wire/elv5_wire_command_registry.dart';
import 'elv5_cctv_persistence.dart';

final class Elv5ReviewedImpactPreview {
  Elv5ReviewedImpactPreview({
    required this.designRowRevision,
    required Map<String, int> expectedRows,
    required this.reviewedImpactFingerprint,
    required Set<String> staleNodeKeySha256s,
  }) : expectedRows = Map.unmodifiable(expectedRows),
       staleNodeKeySha256s = Set.unmodifiable(staleNodeKeySha256s);

  final int designRowRevision;
  final Map<String, int> expectedRows;
  final String reviewedImpactFingerprint;
  final Set<String> staleNodeKeySha256s;
}

/// P2 CCTV command runtime for stream/subscription and recording-pool aspects.
/// The same preparation function is used by preview and execute, so reviewed
/// impact is always recomputed from server-side old/new state.
final class Elv5CctvMutationService {
  Elv5CctvMutationService({
    required this.unitOfWork,
    required String originDeviceId,
    DateTime Function()? now,
  }) : _runner = Elv5ReplacementCommandRunner<Elv5CctvWriteSession>(
         unitOfWork: unitOfWork,
         originDeviceId: originDeviceId,
         now: now,
       ),
       _now = now ?? (() => DateTime.now().toUtc());

  static const _internalHistorySchema = 'electra.elv5-internal-history.v1';
  static const _encoder = Elv5CanonicalJsonV1();

  final Elv5CctvWriteUnitOfWork unitOfWork;
  final Elv5ReplacementCommandRunner<Elv5CctvWriteSession> _runner;
  final DateTime Function() _now;

  Future<Elv5ReviewedImpactPreview> preview({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    if (operation != 'REPLACE_CAMERA_STREAMS' &&
        operation != 'REPLACE_RECORDING_ASSIGNMENTS') {
      throw FormatException('Unsupported CCTV mutation operation: $operation.');
    }
    Elv5WireCommandRegistry.validatePayload(operation, payload);
    return unitOfWork.run((session) async {
      final revision = await session.revisions.load(
        projectId: projectId,
        designRevisionId: designRevisionId,
      );
      if (revision == null) {
        throw const Elv5ReplacementCommandException(
          'ELV5_DESIGN_REVISION_NOT_FOUND',
        );
      }
      if (!revision.working) {
        throw const Elv5ReplacementCommandException(
          'ELV5_DESIGN_REVISION_READ_ONLY',
        );
      }
      final prepared = await _prepareCandidate(
        session,
        projectId: projectId,
        designRevisionId: designRevisionId,
        operation: operation,
        payload: payload,
      );
      return Elv5ReviewedImpactPreview(
        designRowRevision: revision.rowRevision,
        expectedRows: prepared.actualRowRevisions,
        reviewedImpactFingerprint: prepared.reviewedImpactFingerprint,
        staleNodeKeySha256s: prepared.staleNodeKeySha256s,
      );
    });
  }

  Future<Elv5ReplacementRunResult> execute(Elv5WireCommandEnvelope command) {
    switch (command.operation) {
      case 'REPLACE_CAMERA_STREAMS':
        return _runner.run(
          command,
          prepare: _prepareFromCommand,
          apply: _applyCameraStreams,
        );
      case 'REPLACE_RECORDING_ASSIGNMENTS':
        return _runner.run(
          command,
          prepare: _prepareFromCommand,
          apply: _applyRecordingPool,
        );
      default:
        throw FormatException(
          'Unsupported CCTV mutation operation: ${command.operation}.',
        );
    }
  }

  Future<Elv5PreparedReplacement> _prepareFromCommand(
    Elv5CctvWriteSession session,
    Elv5WireCommandEnvelope command,
  ) => _prepareCandidate(
    session,
    projectId: command.projectId,
    designRevisionId: command.designRevisionId,
    operation: command.operation,
    payload: command.payload,
  );

  Future<Elv5PreparedReplacement> _prepareCandidate(
    Elv5CctvWriteSession session, {
    required String projectId,
    required String designRevisionId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final Elv5CctvAggregateSnapshot? previous;
    final String aggregateKind;
    final String subjectId;
    final String aggregateId;
    if (operation == 'REPLACE_CAMERA_STREAMS') {
      subjectId = payload['cameraId']! as String;
      aggregateKind = 'CCTV_CAMERA_STREAMS';
      previous = await session.cctv.loadCameraStreams(
        projectId: projectId,
        designRevisionId: designRevisionId,
        cameraId: subjectId,
      );
      aggregateId = previous?.aggregateId ?? _cameraBindingId(subjectId);
    } else if (operation == 'REPLACE_RECORDING_ASSIGNMENTS') {
      subjectId = payload['poolId']! as String;
      aggregateKind = 'CCTV_RECORDING_POOL';
      previous = await session.cctv.loadRecordingPool(
        projectId: projectId,
        designRevisionId: designRevisionId,
        poolId: subjectId,
      );
      aggregateId = previous?.aggregateId ?? _recordingBindingId(subjectId);
    } else {
      throw FormatException('Unsupported CCTV operation: $operation.');
    }

    final oldDependencies = previous == null
        ? const <Map<String, Object?>>[]
        : _dependencies(operation, previous.payload);
    final newDependencies = _dependencies(operation, payload);
    final dependencyHashes = <String>{
      for (final dependency in oldDependencies) _encoder.sha256(dependency),
      for (final dependency in newDependencies) _encoder.sha256(dependency),
    };
    final staleNodes = await session.dependencies.loadDependentNodeHashesBulk(
      projectId: projectId,
      designRevisionId: designRevisionId,
      dependencyKeySha256s: dependencyHashes,
    );
    final oldHashes = oldDependencies.map(_encoder.sha256).toList()..sort();
    final newHashes = newDependencies.map(_encoder.sha256).toList()..sort();
    final staleHashes = staleNodes.toList()..sort();
    final impactFingerprint = _encoder.sha256({
      'schema': 'electra.elv5-reviewed-impact.v1',
      'operation': operation,
      'subjectId': subjectId,
      'oldDependencyHashes': oldHashes,
      'newDependencyHashes': newHashes,
      'staleNodeKeySha256s': staleHashes,
    });

    final before = _aggregateEvidence(
      aggregateKind: aggregateKind,
      aggregateId: aggregateId,
      subjectId: subjectId,
      payload: previous?.payload,
    );
    final inverse = {
      'schema': _internalHistorySchema,
      'kind': 'RESTORE_AGGREGATE',
      'aggregateKind': aggregateKind,
      'aggregateId': aggregateId,
      'subjectId': subjectId,
      'state': previous == null ? 'ABSENT' : 'PRESENT',
      'payload': previous?.payload,
    };
    final inverseJson = _canonicalJson(inverse);
    return Elv5PreparedReplacement(
      actualRowRevisions: previous == null
          ? const {}
          : {previous.aggregateId: previous.revision},
      reviewedImpactFingerprint: impactFingerprint,
      staleNodeKeySha256s: staleNodes,
      affectedIds: {subjectId, aggregateId},
      beforeAggregate: before,
      inverseCommandType: 'ELV5_RESTORE_CCTV_AGGREGATE',
      inverseCommandSchema: _internalHistorySchema,
      inverseCanonicalPayloadJson: inverseJson,
      inversePayloadSha256: _encoder.sha256(inverse),
    );
  }

  Future<Elv5AppliedReplacement> _applyCameraStreams(
    Elv5CctvWriteSession session,
    Elv5WireCommandEnvelope command,
    Elv5PreparedReplacement prepared,
  ) async {
    final cameraId = command.payload['cameraId']! as String;
    final bindingId = prepared.actualRowRevisions.keys.isEmpty
        ? _cameraBindingId(cameraId)
        : prepared.actualRowRevisions.keys.single;
    await session.cctv.replaceCameraStreams(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      cameraId: cameraId,
      bindingId: bindingId,
      expectedRootRevision: prepared.actualRowRevisions[bindingId],
      payload: command.payload,
      updatedAtUtc: _now(),
    );
    final after = await session.cctv.loadCameraStreams(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      cameraId: cameraId,
    );
    if (after == null) throw StateError('CCTV camera stream replace disappeared.');
    return _applied(command.operation, after, prepared);
  }

  Future<Elv5AppliedReplacement> _applyRecordingPool(
    Elv5CctvWriteSession session,
    Elv5WireCommandEnvelope command,
    Elv5PreparedReplacement prepared,
  ) async {
    final poolId = command.payload['poolId']! as String;
    final bindingId = prepared.actualRowRevisions.keys.isEmpty
        ? _recordingBindingId(poolId)
        : prepared.actualRowRevisions.keys.single;
    await session.cctv.replaceRecordingPool(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      poolId: poolId,
      bindingId: bindingId,
      expectedRootRevision: prepared.actualRowRevisions[bindingId],
      payload: command.payload,
      updatedAtUtc: _now(),
    );
    final after = await session.cctv.loadRecordingPool(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      poolId: poolId,
    );
    if (after == null) throw StateError('CCTV recording replace disappeared.');
    return _applied(command.operation, after, prepared);
  }

  Elv5AppliedReplacement _applied(
    String operation,
    Elv5CctvAggregateSnapshot after,
    Elv5PreparedReplacement prepared,
  ) {
    final result = {
      'operation': operation,
      'aggregateId': after.aggregateId,
      'subjectId': after.subjectId,
      'aggregateRevision': after.revision,
      'staleNodeCount': prepared.staleNodeKeySha256s.length,
    };
    return Elv5AppliedReplacement(
      logicalResultJson: _canonicalJson(result),
      afterAggregate: _aggregateEvidence(
        aggregateKind: after.aggregateKind,
        aggregateId: after.aggregateId,
        subjectId: after.subjectId,
        payload: after.payload,
      ),
    );
  }

  List<Map<String, Object?>> _dependencies(
    String operation,
    Map<String, Object?> payload,
  ) {
    if (operation == 'REPLACE_CAMERA_STREAMS') {
      final cameraId = payload['cameraId']! as String;
      final result = <Map<String, Object?>>[
        _dependency('SET', 'CCTV_CAMERA_STREAMS', cameraId),
      ];
      for (final raw in payload['streams']! as List) {
        final stream = Map<String, Object?>.from(raw as Map);
        result.add(
          _dependency(
            'FACT',
            'CCTV_STREAM',
            cameraId,
            memberId: stream['encodedStreamId']! as String,
          ),
        );
      }
      for (final raw in payload['subscriptions']! as List) {
        final subscription = Map<String, Object?>.from(raw as Map);
        result.add(
          _dependency(
            'SET',
            'CCTV_SUBSCRIPTION',
            cameraId,
            memberId: subscription['subscriptionId']! as String,
          ),
        );
        final group = subscription['multicastGroupId'];
        if (group is String) {
          result.add(
            _dependency(
              'SET',
              'CCTV_MULTICAST_TREE',
              subscription['encodedStreamId']! as String,
              memberId: group,
            ),
          );
        }
      }
      return result;
    }

    final poolId = payload['poolId']! as String;
    final result = <Map<String, Object?>>[
      _dependency('SET', 'CCTV_RECORDING_POOL', poolId),
    ];
    for (final raw in payload['assignments']! as List) {
      final assignment = Map<String, Object?>.from(raw as Map);
      result.add(
        _dependency(
          'FACT',
          'CCTV_RECORDING_STREAM',
          assignment['encodedStreamId']! as String,
          memberId: assignment['copyRole']! as String,
        ),
      );
    }
    for (final raw in payload['scheduleSegments']! as List) {
      final segment = Map<String, Object?>.from(raw as Map);
      result.add(
        _dependency(
          'SET',
          'CCTV_RECORDING_SCHEDULE',
          poolId,
          memberId: segment['scheduleProfileId']! as String,
        ),
      );
    }
    if (payload['policyRef'] != null) {
      result.add(_dependency('POLICY', 'CCTV_RECORDING_POLICY', poolId));
    }
    return result;
  }

  Map<String, Object?> _dependency(
    String relationKind,
    String domain,
    String subjectId, {
    String? memberId,
  }) => {
    'schema': 'electra.elv5-dependency-key.v1',
    'relationKind': relationKind,
    'domain': domain,
    'subjectId': subjectId,
    if (memberId != null) 'memberId': memberId,
  };

  Elv5AggregateEvidenceDraft _aggregateEvidence({
    required String aggregateKind,
    required String aggregateId,
    required String subjectId,
    required Map<String, Object?>? payload,
  }) {
    final value = {
      'schema': 'electra.elv5-cctv-aggregate.v1',
      'aggregateKind': aggregateKind,
      'aggregateId': aggregateId,
      'subjectId': subjectId,
      'state': payload == null ? 'ABSENT' : 'PRESENT',
      'payload': payload,
    };
    return Elv5AggregateEvidenceDraft(
      aggregateKind: aggregateKind,
      aggregateId: aggregateId,
      canonicalPayloadJson: _canonicalJson(value),
      payloadSha256: _encoder.sha256(value),
    );
  }

  static String _cameraBindingId(String cameraId) =>
      'ELV5:CCTV:CAMERA_STREAMS:$cameraId';

  static String _recordingBindingId(String poolId) =>
      'ELV5:CCTV:RECORDING_POOL:$poolId';

  static String _canonicalJson(Object? value) => utf8.decode(
    _encoder.encode(value),
    allowMalformed: false,
  );
}
