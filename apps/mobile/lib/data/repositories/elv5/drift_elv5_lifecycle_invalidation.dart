import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import '../../database/app_database.dart';

/// One transactional closure for direct fact invalidation and ELV5 CURRENT
/// consumers. A changed upstream generation invalidates consumers even when its
/// immutable evaluation content is unchanged. Cycles advance each pointer once.
final class DriftElv5LifecycleInvalidation {
  const DriftElv5LifecycleInvalidation(
    this.database, {
    required this.originDeviceId,
  });
  final AppDatabase database;
  final String originDeviceId;
  static const _encoder = Elv5CanonicalJsonV1();
  static const _domains = ['CCTV02_CURRENT', 'CCTV03_CURRENT'];

  Future<void> requireWorking(String projectId, String designRevisionId) async {
    final row =
        await database
            .customSelect(
              'SELECT state FROM project_design_revisions WHERE project_id=? AND id=? AND deleted_at IS NULL',
              variables: [
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
              ],
            )
            .getSingleOrNull();
    if (row == null) throw StateError('ELV5_DESIGN_REVISION_NOT_FOUND');
    if (row.read<String>('state') != 'WORKING')
      throw StateError('ELV5_DESIGN_REVISION_READ_ONLY');
  }

  Future<Set<String>> _consumers(
    String projectId,
    String designRevisionId,
    Set<String> evaluations,
  ) async {
    final result = <String>{};
    final ids = evaluations.toList()..sort();
    for (var i = 0; i < ids.length; i += 400) {
      final batch = ids.skip(i).take(400).toList();
      final rows =
          await database
              .customSelect(
                'SELECT dependency_key,dependency_key_sha256,logical_node_key_sha256 FROM discipline_dependency_index WHERE project_id=? AND design_revision_id=? AND relation_kind=\'EVAL\' '
                'AND json_extract(dependency_key,\'\$.domain\') IN (${List.filled(_domains.length, '?').join(',')}) '
                'AND json_extract(dependency_key,\'\$.subjectId\') IN (${List.filled(batch.length, '?').join(',')})',
                variables: [
                  Variable.withString(projectId),
                  Variable.withString(designRevisionId),
                  ..._domains.map(Variable.withString),
                  ...batch.map(Variable.withString),
                ],
              )
              .get();
      for (final row in rows) {
        final value = jsonDecode(row.read<String>('dependency_key'));
        if (value is! Map ||
            value['schema'] != 'electra.elv5-dependency-key.v1' ||
            value['relationKind'] != 'EVAL' ||
            _encoder.sha256(value) !=
                row.read<String>('dependency_key_sha256')) {
          throw StateError('ELV5_DEPENDENCY_INDEX_HASH_MISMATCH');
        }
        result.add(row.read<String>('logical_node_key_sha256'));
      }
    }
    return result;
  }

  Future<int> invalidateConsumers({
    required String projectId,
    required String designRevisionId,
    required String evaluationId,
    required String producerNodeHash,
    required DateTime updatedAtUtc,
  }) => database.transaction(() async {
    await requireWorking(projectId, designRevisionId);
    return invalidateNodes(
      projectId: projectId,
      designRevisionId: designRevisionId,
      nodeHashes: await _consumers(projectId, designRevisionId, {evaluationId}),
      updatedAtUtc: updatedAtUtc,
      excludedNodes: {producerNodeHash},
    );
  });

  Future<int> invalidateNodes({
    required String projectId,
    required String designRevisionId,
    required Set<String> nodeHashes,
    required DateTime updatedAtUtc,
    Set<String> excludedNodes = const {},
  }) => database.transaction(() async {
    await requireWorking(projectId, designRevisionId);
    final seen = <String>{...excludedNodes};
    var frontier = nodeHashes.difference(seen);
    final affected = <String>{};
    while (frontier.isNotEmpty) {
      seen.addAll(frontier);
      affected.addAll(frontier);
      final ids = frontier.toList()..sort();
      final evaluations = <String>{};
      for (var i = 0; i < ids.length; i += 400) {
        final batch = ids.skip(i).take(400).toList();
        final rows =
            await database
                .customSelect(
                  'SELECT evaluation_id FROM discipline_evaluation_pointers WHERE project_id=? AND design_revision_id=? AND logical_node_key_sha256 IN (${List.filled(batch.length, '?').join(',')})',
                  variables: [
                    Variable.withString(projectId),
                    Variable.withString(designRevisionId),
                    ...batch.map(Variable.withString),
                  ],
                )
                .get();
        evaluations.addAll(
          rows
              .map((r) => r.readNullable<String>('evaluation_id'))
              .whereType<String>(),
        );
      }
      frontier = (await _consumers(
        projectId,
        designRevisionId,
        evaluations,
      )).difference(seen);
    }
    final ids = affected.toList()..sort();
    var changed = 0;
    for (var i = 0; i < ids.length; i += 400) {
      final batch = ids.skip(i).take(400).toList();
      changed += await database.customUpdate(
        "UPDATE discipline_evaluation_pointers SET freshness = 'STALE', generation = generation + 1, "
        'updated_at=?,origin_device_id=? WHERE project_id=? AND design_revision_id=? '
        'AND logical_node_key_sha256 IN (${List.filled(batch.length, '?').join(',')}) '
        "AND freshness <> 'STALE'",
        variables: [
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          ...batch.map(Variable.withString),
        ],
      );
    }
    return changed;
  });
}
