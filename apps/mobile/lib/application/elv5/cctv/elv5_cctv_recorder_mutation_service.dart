import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../commands/elv5_replacement_command_runner.dart';
import '../persistence/elv5_replacement_persistence.dart';
import '../wire/elv5_wire_command.dart';
import '../wire/elv5_wire_command_registry.dart';
import 'elv5_cctv_mutation_service.dart' show Elv5ReviewedImpactPreview;
import 'elv5_cctv_recorder_persistence.dart';

final class Elv5CctvRecorderMutationService {
  Elv5CctvRecorderMutationService({
    required this.unitOfWork,
    required String originDeviceId,
    DateTime Function()? now,
  }) : _runner = Elv5ReplacementCommandRunner<Elv5CctvRecorderWriteSession>(
         unitOfWork: unitOfWork,
         originDeviceId: originDeviceId,
         now: now,
       ),
       _now = now ?? (() => DateTime.now().toUtc());

  static const _encoder = Elv5CanonicalJsonV1();
  static const _internalHistorySchema = 'electra.elv5-internal-history.v1';

  final Elv5CctvRecorderWriteUnitOfWork unitOfWork;
  final Elv5ReplacementCommandRunner<Elv5CctvRecorderWriteSession> _runner;
  final DateTime Function() _now;

  Future<Elv5ReviewedImpactPreview> preview({
    required String projectId,
    required String designRevisionId,
    required Map<String, Object?> payload,
  }) {
    Elv5WireCommandRegistry.validatePayload(
      'REPLACE_RECORDER_ASSIGNMENTS',
      payload,
    );
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
      final prepared = await _prepare(
        session,
        projectId: projectId,
        designRevisionId: designRevisionId,
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
    if (command.operation != 'REPLACE_RECORDER_ASSIGNMENTS') {
      throw FormatException(
        'Unsupported CCTV recorder operation: ${command.operation}.',
      );
    }
    return _runner.run(
      command,
      prepare:
          (session, value) => _prepare(
            session,
            projectId: value.projectId,
            designRevisionId: value.designRevisionId,
            payload: value.payload,
          ),
      apply: _apply,
    );
  }

  Future<Elv5PreparedReplacement> _prepare(
    Elv5CctvRecorderWriteSession session, {
    required String projectId,
    required String designRevisionId,
    required Map<String, Object?> payload,
  }) async {
    final recorderId = payload['recorderId']! as String;
    final previous = await session.recorder.loadRecorder(
      projectId: projectId,
      designRevisionId: designRevisionId,
      recorderId: recorderId,
    );
    final aggregateId = previous?.aggregateId ?? _bindingId(recorderId);
    final oldDependencies =
        previous == null
            ? const <Map<String, Object?>>[]
            : _dependencies(previous.payload);
    final newDependencies = _dependencies(payload);
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
      'operation': 'REPLACE_RECORDER_ASSIGNMENTS',
      'subjectId': recorderId,
      'oldDependencyHashes': oldHashes,
      'newDependencyHashes': newHashes,
      'staleNodeKeySha256s': staleHashes,
    });

    final before = _aggregateEvidence(
      aggregateId: aggregateId,
      recorderId: recorderId,
      payload: previous?.payload,
    );
    final inverse = {
      'schema': _internalHistorySchema,
      'kind': 'RESTORE_AGGREGATE',
      'aggregateKind': 'CCTV_RECORDER',
      'aggregateId': aggregateId,
      'subjectId': recorderId,
      'state': previous == null ? 'ABSENT' : 'PRESENT',
      'payload': previous?.payload,
    };
    return Elv5PreparedReplacement(
      actualRowRevisions:
          previous == null
              ? const {}
              : {previous.aggregateId: previous.revision},
      reviewedImpactFingerprint: impactFingerprint,
      staleNodeKeySha256s: staleNodes,
      affectedIds: {recorderId, aggregateId},
      beforeAggregate: before,
      inverseCommandType: 'ELV5_RESTORE_CCTV_AGGREGATE',
      inverseCommandSchema: _internalHistorySchema,
      inverseCanonicalPayloadJson: _canonicalJson(inverse),
      inversePayloadSha256: _encoder.sha256(inverse),
    );
  }

  Future<Elv5AppliedReplacement> _apply(
    Elv5CctvRecorderWriteSession session,
    Elv5WireCommandEnvelope command,
    Elv5PreparedReplacement prepared,
  ) async {
    final recorderId = command.payload['recorderId']! as String;
    final bindingId =
        prepared.actualRowRevisions.keys.isEmpty
            ? _bindingId(recorderId)
            : prepared.actualRowRevisions.keys.single;
    await session.recorder.replaceRecorder(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      recorderId: recorderId,
      bindingId: bindingId,
      expectedRootRevision: prepared.actualRowRevisions[bindingId],
      payload: command.payload,
      updatedAtUtc: _now(),
    );
    final after = await session.recorder.loadRecorder(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      recorderId: recorderId,
    );
    if (after == null) throw StateError('CCTV recorder replace disappeared.');
    final result = {
      'operation': command.operation,
      'aggregateId': after.aggregateId,
      'subjectId': recorderId,
      'aggregateRevision': after.revision,
      'staleNodeCount': prepared.staleNodeKeySha256s.length,
    };
    return Elv5AppliedReplacement(
      logicalResultJson: _canonicalJson(result),
      afterAggregate: _aggregateEvidence(
        aggregateId: after.aggregateId,
        recorderId: recorderId,
        payload: after.payload,
      ),
    );
  }

  List<Map<String, Object?>> _dependencies(Map<String, Object?> payload) {
    final recorderId = payload['recorderId']! as String;
    final result = <Map<String, Object?>>[
      _dependency('SET', 'CCTV_RECORDER', recorderId),
    ];
    for (final raw in payload['assignments']! as List) {
      final assignment = Map<String, Object?>.from(raw as Map);
      result
        ..add(
          _dependency(
            'FACT',
            'CCTV_STREAM',
            assignment['cameraId']! as String,
            memberId: assignment['encodedStreamId']! as String,
          ),
        )
        ..add(
          _dependency(
            'SET',
            'CCTV_RECORDING_POOL',
            assignment['storagePoolId']! as String,
          ),
        )
        ..add(
          _dependency(
            'SET',
            'CCTV_RECORDER_CHANNEL',
            recorderId,
            memberId: assignment['licenseChannelId']! as String,
          ),
        );
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
    required String aggregateId,
    required String recorderId,
    required Map<String, Object?>? payload,
  }) {
    final value = {
      'schema': 'electra.elv5-cctv-aggregate.v1',
      'aggregateKind': 'CCTV_RECORDER',
      'aggregateId': aggregateId,
      'subjectId': recorderId,
      'state': payload == null ? 'ABSENT' : 'PRESENT',
      'payload': payload,
    };
    return Elv5AggregateEvidenceDraft(
      aggregateKind: 'CCTV_RECORDER',
      aggregateId: aggregateId,
      canonicalPayloadJson: _canonicalJson(value),
      payloadSha256: _encoder.sha256(value),
    );
  }

  static String _bindingId(String recorderId) =>
      'ELV5:CCTV:RECORDER:$recorderId';

  static String _canonicalJson(Object? value) =>
      utf8.decode(_encoder.encode(value), allowMalformed: false);
}
