import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../commands/elv5_replacement_command_runner.dart';
import '../cctv/elv5_cctv_mutation_service.dart' show Elv5ReviewedImpactPreview;
import '../persistence/elv5_replacement_persistence.dart';
import '../wire/elv5_wire_command.dart';
import '../wire/elv5_wire_command_registry.dart';
import 'elv5_lan_rack_persistence.dart';

final class Elv5LanRackMutationService {
  Elv5LanRackMutationService({
    required this.unitOfWork,
    required String originDeviceId,
    DateTime Function()? now,
  }) : _runner = Elv5ReplacementCommandRunner<Elv5LanRackWriteSession>(
         unitOfWork: unitOfWork,
         originDeviceId: originDeviceId,
         now: now,
       ),
       _now = now ?? (() => DateTime.now().toUtc());

  static const _encoder = Elv5CanonicalJsonV1();
  static const _historySchema = 'electra.elv5-internal-history.v1';

  final Elv5LanRackWriteUnitOfWork unitOfWork;
  final Elv5ReplacementCommandRunner<Elv5LanRackWriteSession> _runner;
  final DateTime Function() _now;

  Future<Elv5ReviewedImpactPreview> preview({
    required String projectId,
    required String designRevisionId,
    required Map<String, Object?> payload,
  }) {
    Elv5WireCommandRegistry.validatePayload(
      'REPLACE_RACK_CAPACITY_BASIS',
      payload,
    );
    return unitOfWork.run((session) async {
      final revision = await session.revisions.load(
        projectId: projectId,
        designRevisionId: designRevisionId,
      );
      if (revision == null || !revision.working) {
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
    if (command.operation != 'REPLACE_RACK_CAPACITY_BASIS') {
      throw FormatException(
        'Unsupported LAN rack operation: ${command.operation}.',
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
    Elv5LanRackWriteSession session, {
    required String projectId,
    required String designRevisionId,
    required Map<String, Object?> payload,
  }) async {
    final rackId = payload['rackId']! as String;
    final previous = await session.racks.loadRack(
      projectId: projectId,
      designRevisionId: designRevisionId,
      rackId: rackId,
    );
    final aggregateId =
        previous?.aggregateId ?? 'ELV5:LAN_RACK_CAPACITY:$rackId';
    final oldDeps =
        previous == null
            ? const <Map<String, Object?>>[]
            : _dependencies(previous.payload);
    final newDeps = _dependencies(payload);
    final keyHashes = <String>{
      for (final value in oldDeps) _encoder.sha256(value),
      for (final value in newDeps) _encoder.sha256(value),
    };
    final stale = await session.dependencies.loadDependentNodeHashesBulk(
      projectId: projectId,
      designRevisionId: designRevisionId,
      dependencyKeySha256s: keyHashes,
    );
    final oldHashes = oldDeps.map(_encoder.sha256).toList()..sort();
    final newHashes = newDeps.map(_encoder.sha256).toList()..sort();
    final staleHashes = stale.toList()..sort();
    final fingerprint = _encoder.sha256({
      'schema': 'electra.elv5-reviewed-impact.v1',
      'operation': 'REPLACE_RACK_CAPACITY_BASIS',
      'subjectId': rackId,
      'oldDependencyHashes': oldHashes,
      'newDependencyHashes': newHashes,
      'staleNodeKeySha256s': staleHashes,
    });
    final before = _evidence(
      aggregateId: aggregateId,
      rackId: rackId,
      payload: previous?.payload,
      capturedRackProfile: previous?.capturedRackProfile,
    );
    final inverse = {
      'schema': _historySchema,
      'kind': 'RESTORE_AGGREGATE',
      'aggregateKind': 'LAN_RACK_CAPACITY',
      'aggregateId': aggregateId,
      'subjectId': rackId,
      'state': previous == null ? 'ABSENT' : 'PRESENT',
      'payload': previous?.payload,
      'capturedRackProfile': previous?.capturedRackProfile,
    };
    return Elv5PreparedReplacement(
      actualRowRevisions:
          previous == null ? const {} : {aggregateId: previous.revision},
      reviewedImpactFingerprint: fingerprint,
      staleNodeKeySha256s: stale,
      affectedIds: {
        rackId,
        aggregateId,
        ...(payload['equipmentIds']! as List).cast<String>(),
      },
      beforeAggregate: before,
      inverseCommandType: 'ELV5_RESTORE_LAN_AGGREGATE',
      inverseCommandSchema: _historySchema,
      inverseCanonicalPayloadJson: _canonical(inverse),
      inversePayloadSha256: _encoder.sha256(inverse),
    );
  }

  Future<Elv5AppliedReplacement> _apply(
    Elv5LanRackWriteSession session,
    Elv5WireCommandEnvelope command,
    Elv5PreparedReplacement prepared,
  ) async {
    final rackId = command.payload['rackId']! as String;
    final bindingId =
        prepared.actualRowRevisions.keys.isEmpty
            ? 'ELV5:LAN_RACK_CAPACITY:$rackId'
            : prepared.actualRowRevisions.keys.single;
    await session.racks.replaceRack(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      rackId: rackId,
      bindingId: bindingId,
      expectedRootRevision: prepared.actualRowRevisions[bindingId],
      payload: command.payload,
      updatedAtUtc: _now(),
    );
    final after = await session.racks.loadRack(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      rackId: rackId,
    );
    if (after == null) throw StateError('LAN rack replacement disappeared.');
    return Elv5AppliedReplacement(
      logicalResultJson: _canonical({
        'operation': command.operation,
        'aggregateId': after.aggregateId,
        'subjectId': rackId,
        'aggregateRevision': after.revision,
        'rackProfileSha256': _encoder.sha256(after.capturedRackProfile),
        'staleNodeCount': prepared.staleNodeKeySha256s.length,
      }),
      afterAggregate: _evidence(
        aggregateId: after.aggregateId,
        rackId: rackId,
        payload: after.payload,
        capturedRackProfile: after.capturedRackProfile,
      ),
    );
  }

  List<Map<String, Object?>> _dependencies(Map<String, Object?> payload) => [
    _dep('SET', 'LAN_RACK_CAPACITY', payload['rackId']! as String),
    _dep('FACT', 'COMPONENT_REFERENCE_BINDING', payload['rackId']! as String),
    for (final id in (payload['equipmentIds']! as List).cast<String>())
      _dep('FACT', 'COMPONENT_REFERENCE_BINDING', id),
    _dep('POLICY', 'LAN_RACK_POLICY', payload['rackId']! as String),
  ];

  Map<String, Object?> _dep(
    String relationKind,
    String domain,
    String subjectId,
  ) => {
    'schema': 'electra.elv5-dependency-key.v1',
    'relationKind': relationKind,
    'domain': domain,
    'subjectId': subjectId,
  };

  Elv5AggregateEvidenceDraft _evidence({
    required String aggregateId,
    required String rackId,
    required Map<String, Object?>? payload,
    required Map<String, Object?>? capturedRackProfile,
  }) {
    final value = {
      'schema': 'electra.elv5-lan-rack-aggregate.v1',
      'aggregateKind': 'LAN_RACK_CAPACITY',
      'aggregateId': aggregateId,
      'subjectId': rackId,
      'state': payload == null ? 'ABSENT' : 'PRESENT',
      'payload': payload,
      'capturedRackProfile': capturedRackProfile,
    };
    return Elv5AggregateEvidenceDraft(
      aggregateKind: 'LAN_RACK_CAPACITY',
      aggregateId: aggregateId,
      canonicalPayloadJson: _canonical(value),
      payloadSha256: _encoder.sha256(value),
    );
  }

  static String _canonical(Object? value) =>
      utf8.decode(_encoder.encode(value), allowMalformed: false);
}
