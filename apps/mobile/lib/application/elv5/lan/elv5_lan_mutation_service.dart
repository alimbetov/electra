import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../commands/elv5_replacement_command_runner.dart';
import '../cctv/elv5_cctv_mutation_service.dart' show Elv5ReviewedImpactPreview;
import '../persistence/elv5_replacement_persistence.dart';
import '../wire/elv5_wire_command.dart';
import '../wire/elv5_wire_command_registry.dart';
import 'elv5_lan_persistence.dart';

final class Elv5LanMutationService {
  Elv5LanMutationService({
    required this.unitOfWork,
    required String originDeviceId,
    DateTime Function()? now,
  }) : _runner = Elv5ReplacementCommandRunner<Elv5LanWriteSession>(
         unitOfWork: unitOfWork,
         originDeviceId: originDeviceId,
         now: now,
       ),
       _now = now ?? (() => DateTime.now().toUtc());

  static const _encoder = Elv5CanonicalJsonV1();
  static const _historySchema = 'electra.elv5-internal-history.v1';
  static const _operations = {
    'REPLACE_LINK_COMPOSITION',
    'REPLACE_PORT_CAPACITY_ASSIGNMENTS',
    'REPLACE_OPTICAL_LINK_ASSIGNMENTS',
    'REPLACE_PATCH_PANEL_ASSIGNMENTS',
  };

  final Elv5LanWriteUnitOfWork unitOfWork;
  final Elv5ReplacementCommandRunner<Elv5LanWriteSession> _runner;
  final DateTime Function() _now;

  Future<Elv5ReviewedImpactPreview> preview({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    if (!_operations.contains(operation)) {
      throw FormatException('Unsupported LAN mutation: $operation.');
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
      throw FormatException('Unsupported LAN mutation: ${command.operation}.');
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
    Elv5LanWriteSession session, {
    required String projectId,
    required String designRevisionId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final subjectId = _subject(operation, payload);
    final previous = await session.lan.load(
      projectId: projectId,
      designRevisionId: designRevisionId,
      operation: operation,
      subjectId: subjectId,
    );
    final aggregateId = previous?.aggregateId ?? _bindingId(operation, subjectId);
    final oldDependencies = previous == null
        ? const <Map<String, Object?>>[]
        : _dependencies(operation, previous.payload);
    final newDependencies = _dependencies(operation, payload);
    final keys = <String>{
      for (final item in oldDependencies) _encoder.sha256(item),
      for (final item in newDependencies) _encoder.sha256(item),
    };
    final stale = await session.dependencies.loadDependentNodeHashesBulk(
      projectId: projectId,
      designRevisionId: designRevisionId,
      dependencyKeySha256s: keys,
    );
    final oldHashes = oldDependencies.map(_encoder.sha256).toList()..sort();
    final newHashes = newDependencies.map(_encoder.sha256).toList()..sort();
    final staleHashes = stale.toList()..sort();
    final fingerprint = _encoder.sha256({
      'schema': 'electra.elv5-reviewed-impact.v1',
      'operation': operation,
      'subjectId': subjectId,
      'oldDependencyHashes': oldHashes,
      'newDependencyHashes': newHashes,
      'staleNodeKeySha256s': staleHashes,
    });
    final kind = _aggregateKind(operation);
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
      beforeAggregate: _evidence(kind, aggregateId, subjectId, previous?.payload),
      inverseCommandType: 'ELV5_RESTORE_LAN_AGGREGATE',
      inverseCommandSchema: _historySchema,
      inverseCanonicalPayloadJson: _canonicalJson(inverse),
      inversePayloadSha256: _encoder.sha256(inverse),
    );
  }

  Future<Elv5AppliedReplacement> _apply(
    Elv5LanWriteSession session,
    Elv5WireCommandEnvelope command,
    Elv5PreparedReplacement prepared,
  ) async {
    final subjectId = _subject(command.operation, command.payload);
    final bindingId = prepared.actualRowRevisions.keys.isEmpty
        ? _bindingId(command.operation, subjectId)
        : prepared.actualRowRevisions.keys.single;
    await session.lan.replace(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      operation: command.operation,
      subjectId: subjectId,
      bindingId: bindingId,
      expectedRootRevision: prepared.actualRowRevisions[bindingId],
      payload: command.payload,
      updatedAtUtc: _now(),
    );
    final after = await session.lan.load(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      operation: command.operation,
      subjectId: subjectId,
    );
    if (after == null) throw StateError('LAN replacement disappeared.');
    return Elv5AppliedReplacement(
      logicalResultJson: _canonicalJson({
        'operation': command.operation,
        'aggregateId': after.aggregateId,
        'subjectId': subjectId,
        'aggregateRevision': after.revision,
        'staleNodeCount': prepared.staleNodeKeySha256s.length,
      }),
      afterAggregate: _evidence(
        after.aggregateKind,
        after.aggregateId,
        subjectId,
        after.payload,
      ),
    );
  }

  String _subject(String operation, Map<String, Object?> payload) => switch (operation) {
    'REPLACE_LINK_COMPOSITION' || 'REPLACE_OPTICAL_LINK_ASSIGNMENTS' =>
      payload['linkId']! as String,
    'REPLACE_PORT_CAPACITY_ASSIGNMENTS' => payload['switchId']! as String,
    'REPLACE_PATCH_PANEL_ASSIGNMENTS' => payload['panelId']! as String,
    _ => throw FormatException('Unsupported LAN mutation: $operation.'),
  };

  String _aggregateKind(String operation) => switch (operation) {
    'REPLACE_LINK_COMPOSITION' => 'LAN_LINK_COMPOSITION',
    'REPLACE_PORT_CAPACITY_ASSIGNMENTS' => 'LAN_PORT_CAPACITY',
    'REPLACE_OPTICAL_LINK_ASSIGNMENTS' => 'LAN_OPTICAL_LINK',
    'REPLACE_PATCH_PANEL_ASSIGNMENTS' => 'LAN_PATCH_PANEL',
    _ => throw FormatException('Unsupported LAN mutation: $operation.'),
  };

  String _bindingId(String operation, String subjectId) =>
      'ELV5:${_aggregateKind(operation)}:$subjectId';

  List<Map<String, Object?>> _dependencies(
    String operation,
    Map<String, Object?> payload,
  ) {
    final subjectId = _subject(operation, payload);
    final result = <Map<String, Object?>>[
      _dep('SET', _aggregateKind(operation), subjectId),
    ];
    switch (operation) {
      case 'REPLACE_LINK_COMPOSITION':
        for (final raw in payload['orderedSections']! as List) {
          final row = Map<String, Object?>.from(raw as Map);
          result.add(
            _dep('FACT', 'ELV3_REALIZED_LINK_SECTION', row['realizedSectionId']! as String),
          );
        }
        result.add(_dep('POLICY', 'LAN_LINK_POLICY', payload['policyBindingId']! as String));
      case 'REPLACE_PORT_CAPACITY_ASSIGNMENTS':
        for (final raw in payload['assignments']! as List) {
          final row = Map<String, Object?>.from(raw as Map);
          result.add(_dep('FACT', 'ENGINEERING_PORT', row['portId']! as String));
        }
        result.add(_dep('POLICY', 'LAN_PORT_SPARE_POLICY', subjectId));
      case 'REPLACE_OPTICAL_LINK_ASSIGNMENTS':
        for (final field in const ['forwardOptics', 'reverseOptics']) {
          final optics = Map<String, Object?>.from(payload[field]! as Map);
          result
            ..add(_dep('FACT', 'ENGINEERING_PORT', optics['txPortId']! as String))
            ..add(_dep('FACT', 'ENGINEERING_PORT', optics['rxPortId']! as String));
        }
        for (final field in const ['connectorEvents', 'spliceEvents']) {
          for (final raw in payload[field]! as List) {
            final row = Map<String, Object?>.from(raw as Map);
            result.add(_dep('SET', 'LAN_OPTICAL_LOSS_EVENT', subjectId, memberId: row['eventId']! as String));
          }
        }
      case 'REPLACE_PATCH_PANEL_ASSIGNMENTS':
        for (final raw in payload['assignments']! as List) {
          final row = Map<String, Object?>.from(raw as Map);
          result
            ..add(_dep('FACT', 'ENGINEERING_PORT', row['panelPortId']! as String))
            ..add(_dep('SET', 'LAN_LINK_COMPOSITION', row['linkId']! as String));
        }
        result.add(_dep('POLICY', 'LAN_PATCH_SPARE_POLICY', subjectId));
    }
    return result;
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
      'schema': 'electra.elv5-lan-aggregate.v1',
      'aggregateKind': kind,
      'aggregateId': aggregateId,
      'subjectId': subjectId,
      'state': payload == null ? 'ABSENT' : 'PRESENT',
      'payload': payload,
    };
    return Elv5AggregateEvidenceDraft(
      aggregateKind: kind,
      aggregateId: aggregateId,
      canonicalPayloadJson: _canonicalJson(value),
      payloadSha256: _encoder.sha256(value),
    );
  }

  static String _canonicalJson(Object? value) => utf8.decode(
    _encoder.encode(value),
    allowMalformed: false,
  );
}
