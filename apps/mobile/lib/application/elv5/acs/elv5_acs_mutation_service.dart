import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../commands/elv5_replacement_command_runner.dart';
import '../cctv/elv5_cctv_mutation_service.dart' show Elv5ReviewedImpactPreview;
import '../persistence/elv5_replacement_persistence.dart';
import '../wire/elv5_wire_command.dart';
import '../wire/elv5_wire_command_registry.dart';
import 'elv5_acs_persistence.dart';

final class Elv5AcsMutationService {
  Elv5AcsMutationService({
    required this.unitOfWork,
    required String originDeviceId,
    DateTime Function()? now,
  }) : _runner = Elv5ReplacementCommandRunner<Elv5AcsWriteSession>(
         unitOfWork: unitOfWork,
         originDeviceId: originDeviceId,
         now: now,
       ),
       _now = now ?? (() => DateTime.now().toUtc());

  static const _encoder = Elv5CanonicalJsonV1();
  static const _historySchema = 'electra.elv5-internal-history.v1';
  static const _operations = {
    'REPLACE_DOOR_ROLE_ASSIGNMENTS',
    'REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS',
  };

  final Elv5AcsWriteUnitOfWork unitOfWork;
  final Elv5ReplacementCommandRunner<Elv5AcsWriteSession> _runner;
  final DateTime Function() _now;

  Future<Elv5ReviewedImpactPreview> preview({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    if (!_operations.contains(operation)) {
      throw FormatException('Unsupported ACS mutation: $operation.');
    }
    Elv5WireCommandRegistry.validatePayload(operation, payload);
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
    if (!_operations.contains(command.operation)) {
      throw FormatException('Unsupported ACS mutation: ${command.operation}.');
    }
    return _runner.run(
      command,
      prepare: (session, value) => _prepare(
        session,
        projectId: value.projectId,
        designRevisionId: value.designRevisionId,
        operation: value.operation,
        payload: value.payload,
      ),
      apply: _apply,
    );
  }

  Future<Elv5PreparedReplacement> _prepare(
    Elv5AcsWriteSession session, {
    required String projectId,
    required String designRevisionId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final subjectId = operation == 'REPLACE_DOOR_ROLE_ASSIGNMENTS'
        ? payload['doorAssemblyId']! as String
        : payload['controllerId']! as String;
    final previous = await session.acs.load(
      projectId: projectId,
      designRevisionId: designRevisionId,
      operation: operation,
      subjectId: subjectId,
    );
    final kind = operation == 'REPLACE_DOOR_ROLE_ASSIGNMENTS'
        ? 'ACS_DOOR_CALCULATION'
        : 'ACS_CONTROLLER_RESOURCES';
    final aggregateId = previous?.aggregateId ?? 'ELV5:$kind:$subjectId';
    final oldDeps = previous == null
        ? const <Map<String, Object?>>[]
        : _dependencies(operation, previous.payload);
    final newDeps = _dependencies(operation, payload);
    final hashes = <String>{
      for (final item in oldDeps) _encoder.sha256(item),
      for (final item in newDeps) _encoder.sha256(item),
    };
    final stale = await session.dependencies.loadDependentNodeHashesBulk(
      projectId: projectId,
      designRevisionId: designRevisionId,
      dependencyKeySha256s: hashes,
    );
    final oldHashes = oldDeps.map(_encoder.sha256).toList()..sort();
    final newHashes = newDeps.map(_encoder.sha256).toList()..sort();
    final staleHashes = stale.toList()..sort();
    final fingerprint = _encoder.sha256({
      'schema': 'electra.elv5-reviewed-impact.v1',
      'operation': operation,
      'subjectId': subjectId,
      'oldDependencyHashes': oldHashes,
      'newDependencyHashes': newHashes,
      'staleNodeKeySha256s': staleHashes,
    });
    final inverse = {
      'schema': _historySchema,
      'kind': 'RESTORE_AGGREGATE',
      'aggregateKind': kind,
      'aggregateId': aggregateId,
      'subjectId': subjectId,
      'state': previous == null ? 'ABSENT' : 'PRESENT',
      'payload': previous?.payload,
    };
    return Elv5PreparedReplacement(
      actualRowRevisions: previous == null
          ? const {}
          : {aggregateId: previous.revision},
      reviewedImpactFingerprint: fingerprint,
      staleNodeKeySha256s: stale,
      affectedIds: {subjectId, aggregateId},
      beforeAggregate: _evidence(
        kind,
        aggregateId,
        subjectId,
        previous?.payload,
      ),
      inverseCommandType: 'ELV5_RESTORE_ACS_AGGREGATE',
      inverseCommandSchema: _historySchema,
      inverseCanonicalPayloadJson: _canonical(inverse),
      inversePayloadSha256: _encoder.sha256(inverse),
    );
  }

  Future<Elv5AppliedReplacement> _apply(
    Elv5AcsWriteSession session,
    Elv5WireCommandEnvelope command,
    Elv5PreparedReplacement prepared,
  ) async {
    final subjectId = command.operation == 'REPLACE_DOOR_ROLE_ASSIGNMENTS'
        ? command.payload['doorAssemblyId']! as String
        : command.payload['controllerId']! as String;
    final kind = command.operation == 'REPLACE_DOOR_ROLE_ASSIGNMENTS'
        ? 'ACS_DOOR_CALCULATION'
        : 'ACS_CONTROLLER_RESOURCES';
    final bindingId = prepared.actualRowRevisions.keys.isEmpty
        ? 'ELV5:$kind:$subjectId'
        : prepared.actualRowRevisions.keys.single;
    await session.acs.replace(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      operation: command.operation,
      subjectId: subjectId,
      bindingId: bindingId,
      expectedRootRevision: prepared.actualRowRevisions[bindingId],
      payload: command.payload,
      updatedAtUtc: _now(),
    );
    final after = await session.acs.load(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      operation: command.operation,
      subjectId: subjectId,
    );
    if (after == null) throw StateError('ACS replacement disappeared.');
    return Elv5AppliedReplacement(
      logicalResultJson: _canonical({
        'operation': command.operation,
        'aggregateId': after.aggregateId,
        'subjectId': subjectId,
        'aggregateRevision': after.revision,
        'staleNodeCount': prepared.staleNodeKeySha256s.length,
      }),
      afterAggregate: _evidence(
        kind,
        after.aggregateId,
        subjectId,
        after.payload,
      ),
    );
  }

  List<Map<String, Object?>> _dependencies(
    String operation,
    Map<String, Object?> payload,
  ) {
    if (operation == 'REPLACE_DOOR_ROLE_ASSIGNMENTS') {
      final doorId = payload['doorAssemblyId']! as String;
      return [
        _dep('SET', 'ACS_DOOR_CALCULATION', doorId),
        for (final raw in payload['roleAssignments']! as List)
          _dep(
            'FACT',
            'COMPONENT_REFERENCE_BINDING',
            Map<String, Object?>.from(raw as Map)['componentId']! as String,
          ),
        for (final raw in payload['releaseTruthTable']! as List)
          _dep(
            'SET',
            'ACS_RELEASE_CAUSE',
            doorId,
            memberId:
                Map<String, Object?>.from(raw as Map)['causeCode']! as String,
          ),
      ];
    }
    final controllerId = payload['controllerId']! as String;
    return [
      _dep('SET', 'ACS_CONTROLLER_RESOURCES', controllerId),
      _dep('FACT', 'COMPONENT_REFERENCE_BINDING', controllerId),
      for (final raw in payload['resourceAssignments']! as List)
        _dep(
          'SET',
          'ACS_CONTROLLER_RESOURCE',
          controllerId,
          memberId:
              Map<String, Object?>.from(raw as Map)['resourceId']! as String,
        ),
      _dep('POLICY', 'ACS_CONTROLLER_RESERVE_POLICY', controllerId),
    ];
  }

  Map<String, Object?> _dep(
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

  Elv5AggregateEvidenceDraft _evidence(
    String kind,
    String aggregateId,
    String subjectId,
    Map<String, Object?>? payload,
  ) {
    final value = {
      'schema': 'electra.elv5-acs-aggregate.v1',
      'aggregateKind': kind,
      'aggregateId': aggregateId,
      'subjectId': subjectId,
      'state': payload == null ? 'ABSENT' : 'PRESENT',
      'payload': payload,
    };
    return Elv5AggregateEvidenceDraft(
      aggregateKind: kind,
      aggregateId: aggregateId,
      canonicalPayloadJson: _canonical(value),
      payloadSha256: _encoder.sha256(value),
    );
  }

  static String _canonical(Object? value) =>
      utf8.decode(_encoder.encode(value), allowMalformed: false);
}
