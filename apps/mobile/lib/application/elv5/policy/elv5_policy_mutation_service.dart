import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../commands/elv5_replacement_command_runner.dart';
import '../cctv/elv5_cctv_mutation_service.dart' show Elv5ReviewedImpactPreview;
import '../persistence/elv5_replacement_persistence.dart';
import '../wire/elv5_wire_command.dart';
import '../wire/elv5_wire_command_registry.dart';
import 'elv5_policy_persistence.dart';

final class Elv5PolicyMutationService {
  Elv5PolicyMutationService({
    required this.unitOfWork,
    required String originDeviceId,
    DateTime Function()? now,
  }) : _runner = Elv5ReplacementCommandRunner<Elv5PolicyWriteSession>(
         unitOfWork: unitOfWork,
         originDeviceId: originDeviceId,
         now: now,
       ),
       _now = now ?? (() => DateTime.now().toUtc());

  static const _encoder = Elv5CanonicalJsonV1();
  static const _internalHistorySchema = 'electra.elv5-internal-history.v1';
  static const _operations = {
    'BIND_DISCIPLINE_POLICY',
    'ADOPT_DISCIPLINE_POLICY',
    'RELEASE_DISCIPLINE_POLICY',
  };

  final Elv5PolicyWriteUnitOfWork unitOfWork;
  final Elv5ReplacementCommandRunner<Elv5PolicyWriteSession> _runner;
  final DateTime Function() _now;

  Future<Elv5ReviewedImpactPreview> preview({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    if (!_operations.contains(operation)) {
      throw FormatException('Unsupported policy operation: $operation.');
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
      throw FormatException(
        'Unsupported policy operation: ${command.operation}.',
      );
    }
    return _runner.run(
      command,
      prepare:
          (session, value) => _prepare(
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
    Elv5PolicyWriteSession session, {
    required String projectId,
    required String designRevisionId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final bindingId = payload['bindingId']! as String;
    final previous = await session.policies.loadByBindingId(
      projectId: projectId,
      designRevisionId: designRevisionId,
      bindingId: bindingId,
    );

    Map<String, Object?>? candidate;
    if (operation == 'BIND_DISCIPLINE_POLICY') {
      if (previous != null) {
        throw const Elv5ReplacementCommandException(
          'ELV5_POLICY_BINDING_ALREADY_EXISTS',
        );
      }
      final subject = Map<String, Object?>.from(payload['subject']! as Map);
      final subjectConflict = await session.policies.loadActiveBySubject(
        projectId: projectId,
        designRevisionId: designRevisionId,
        subjectKind: subject['kind']! as String,
        subjectId: subject['id']! as String,
      );
      if (subjectConflict != null) {
        throw Elv5ReplacementCommandException(
          'ELV5_POLICY_SUBJECT_ALREADY_BOUND',
          {'bindingId': subjectConflict.bindingId},
        );
      }
      candidate = Map.unmodifiable(payload);
    } else {
      if (previous == null) {
        throw const Elv5ReplacementCommandException(
          'ELV5_POLICY_BINDING_NOT_FOUND',
        );
      }
      if (operation == 'ADOPT_DISCIPLINE_POLICY') {
        candidate = {
          ...previous.payload,
          'definitionRef': payload['newDefinitionRef'],
          'applicability': payload['applicability'],
        };
      } else {
        if (payload['releasePolicy'] !=
            'REMOVE_ELV5_BINDING_KEEP_CANONICAL_FACTS') {
          throw const Elv5ReplacementCommandException(
            'ELV5_POLICY_RELEASE_POLICY_UNSUPPORTED',
          );
        }
        candidate = null;
      }
    }

    final oldDependencies =
        previous == null
            ? const <Map<String, Object?>>[]
            : _dependencies(previous.payload);
    final newDependencies =
        candidate == null
            ? const <Map<String, Object?>>[]
            : _dependencies(candidate);
    final hashes = <String>{
      for (final dependency in oldDependencies) _encoder.sha256(dependency),
      for (final dependency in newDependencies) _encoder.sha256(dependency),
    };
    final stale = await session.dependencies.loadDependentNodeHashesBulk(
      projectId: projectId,
      designRevisionId: designRevisionId,
      dependencyKeySha256s: hashes,
    );
    final oldHashes = oldDependencies.map(_encoder.sha256).toList()..sort();
    final newHashes = newDependencies.map(_encoder.sha256).toList()..sort();
    final staleHashes = stale.toList()..sort();
    final fingerprint = _encoder.sha256({
      'schema': 'electra.elv5-reviewed-impact.v1',
      'operation': operation,
      'bindingId': bindingId,
      'oldDependencyHashes': oldHashes,
      'newDependencyHashes': newHashes,
      'staleNodeKeySha256s': staleHashes,
    });
    final before = _evidence(bindingId, previous?.payload);
    final inverse = {
      'schema': _internalHistorySchema,
      'kind': 'RESTORE_POLICY_BINDING',
      'bindingId': bindingId,
      'state': previous == null ? 'ABSENT' : 'PRESENT',
      'payload': previous?.payload,
    };
    final affected = <String>{bindingId};
    final source = previous?.payload ?? candidate;
    if (source != null) {
      final subject = Map<String, Object?>.from(source['subject']! as Map);
      affected.add(subject['id']! as String);
    }
    return Elv5PreparedReplacement(
      actualRowRevisions:
          previous == null ? const {} : {bindingId: previous.revision},
      reviewedImpactFingerprint: fingerprint,
      staleNodeKeySha256s: stale,
      affectedIds: affected,
      beforeAggregate: before,
      inverseCommandType: 'ELV5_RESTORE_POLICY_BINDING',
      inverseCommandSchema: _internalHistorySchema,
      inverseCanonicalPayloadJson: _canonicalJson(inverse),
      inversePayloadSha256: _encoder.sha256(inverse),
    );
  }

  Future<Elv5AppliedReplacement> _apply(
    Elv5PolicyWriteSession session,
    Elv5WireCommandEnvelope command,
    Elv5PreparedReplacement prepared,
  ) async {
    final bindingId = command.payload['bindingId']! as String;
    Map<String, Object?>? afterPayload;
    switch (command.operation) {
      case 'BIND_DISCIPLINE_POLICY':
        await session.policies.bind(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          payload: command.payload,
          updatedAtUtc: _now(),
        );
        afterPayload = command.payload;
      case 'ADOPT_DISCIPLINE_POLICY':
        final previous = await session.policies.loadByBindingId(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          bindingId: bindingId,
        );
        if (previous == null)
          throw StateError('Policy disappeared before adopt.');
        await session.policies.adopt(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          bindingId: bindingId,
          expectedRootRevision: prepared.actualRowRevisions[bindingId]!,
          payload: command.payload,
          updatedAtUtc: _now(),
        );
        afterPayload = {
          ...previous.payload,
          'definitionRef': command.payload['newDefinitionRef'],
          'applicability': command.payload['applicability'],
        };
      case 'RELEASE_DISCIPLINE_POLICY':
        await session.policies.release(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          bindingId: bindingId,
          expectedRootRevision: prepared.actualRowRevisions[bindingId]!,
          updatedAtUtc: _now(),
        );
        afterPayload = null;
    }
    final afterSnapshot =
        afterPayload == null
            ? null
            : await session.policies.loadByBindingId(
              projectId: command.projectId,
              designRevisionId: command.designRevisionId,
              bindingId: bindingId,
            );
    final result = {
      'operation': command.operation,
      'bindingId': bindingId,
      'state': afterPayload == null ? 'RELEASED' : 'ACTIVE',
      'bindingRevision': afterSnapshot?.revision,
      'staleNodeCount': prepared.staleNodeKeySha256s.length,
    };
    return Elv5AppliedReplacement(
      logicalResultJson: _canonicalJson(result),
      afterAggregate: _evidence(bindingId, afterPayload),
    );
  }

  List<Map<String, Object?>> _dependencies(Map<String, Object?> payload) {
    final subject = Map<String, Object?>.from(payload['subject']! as Map);
    final processCodes = (payload['processCodes']! as List).cast<String>();
    return [
      {
        'schema': 'electra.elv5-dependency-key.v1',
        'relationKind': 'POLICY',
        'domain': 'DISCIPLINE_POLICY',
        'subjectKind': subject['kind'],
        'subjectId': subject['id'],
      },
      for (final processCode in processCodes)
        {
          'schema': 'electra.elv5-dependency-key.v1',
          'relationKind': 'POLICY',
          'domain': 'DISCIPLINE_POLICY_PROCESS',
          'subjectKind': subject['kind'],
          'subjectId': subject['id'],
          'processCode': processCode,
        },
    ];
  }

  Elv5AggregateEvidenceDraft _evidence(
    String bindingId,
    Map<String, Object?>? payload,
  ) {
    final value = {
      'schema': 'electra.elv5-policy-aggregate.v1',
      'aggregateKind': 'DISCIPLINE_POLICY',
      'aggregateId': bindingId,
      'state': payload == null ? 'ABSENT' : 'PRESENT',
      'payload': payload,
    };
    return Elv5AggregateEvidenceDraft(
      aggregateKind: 'DISCIPLINE_POLICY',
      aggregateId: bindingId,
      canonicalPayloadJson: _canonicalJson(value),
      payloadSha256: _encoder.sha256(value),
    );
  }

  static String _canonicalJson(Object? value) =>
      utf8.decode(_encoder.encode(value), allowMalformed: false);
}
