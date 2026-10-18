import 'package:drift/drift.dart';

import '../../../application/elv5/calculation/elv5_calculation_persistence.dart';
import '../../../application/elv5/persistence/elv5_runtime_persistence.dart';
import '../../../application/elv_write_unit_of_work.dart';
import '../../database/app_database.dart';
import 'drift_elv5_runtime_write_unit_of_work.dart';

final class DriftElv5CalculationWriteUnitOfWork
    implements Elv5CalculationWriteUnitOfWork {
  const DriftElv5CalculationWriteUnitOfWork(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<T> run<T>(
    Future<T> Function(Elv5CalculationWriteSession session) action,
  ) => DriftElv5RuntimeWriteUnitOfWork(
    database,
    originDeviceId: originDeviceId,
  ).run((runtime) async {
    return action(_Session(runtime, publicationGuards: _GuardStore(database)));
  });
}

final class _Session implements Elv5CalculationWriteSession {
  const _Session(this.runtime, {required this.publicationGuards});

  final Elv5RuntimeWriteSession runtime;

  @override
  ElvCommandLedgerStore get commandLedger => runtime.commandLedger;

  @override
  Elv5EvaluationStore get evaluations => runtime.evaluations;

  @override
  Elv5PointerStore get pointers => runtime.pointers;

  @override
  Elv5DependencyStore get dependencies => runtime.dependencies;

  @override
  final Elv5CalculationPublicationGuardStore publicationGuards;
}

final class _GuardStore implements Elv5CalculationPublicationGuardStore {
  const _GuardStore(this.database);

  final AppDatabase database;

  @override
  Future<bool> upstreamStillCurrent({
    required String projectId,
    required String designRevisionId,
    required Map<String, int> generations,
  }) async {
    // Both ELV4 and ELV5 nodes are consumed by discipline resolvers. The
    // caller owns the publication transaction, so these checks and writes
    // share one SQLite snapshot/write boundary.
    final keys = generations.keys.toList()..sort();
    for (var offset = 0; offset < keys.length; offset += 400) {
      final batch = keys.skip(offset).take(400).toList();
      final placeholders = List.filled(batch.length, '?').join(',');
      final rows =
          await database
              .customSelect(
                'SELECT logical_node_key_sha256 AS node, generation, freshness AS state FROM discipline_evaluation_pointers '
                'WHERE project_id=? AND design_revision_id=? AND logical_node_key_sha256 IN ($placeholders) '
                'UNION ALL SELECT logical_node_key_sha256 AS node, generation, state FROM power_evaluation_pointers '
                'WHERE project_id=? AND design_revision_id=? AND logical_node_key_sha256 IN ($placeholders)',
                variables: [
                  Variable.withString(projectId),
                  Variable.withString(designRevisionId),
                  ...batch.map(Variable.withString),
                  Variable.withString(projectId),
                  Variable.withString(designRevisionId),
                  ...batch.map(Variable.withString),
                ],
              )
              .get();
      if (rows.length != batch.length ||
          rows.map((r) => r.read<String>('node')).toSet().length !=
              batch.length)
        return false;
      for (final row in rows) {
        if (row.read<String>('state') != 'CURRENT' ||
            row.read<int>('generation') !=
                generations[row.read<String>('node')])
          return false;
      }
    }
    return true;
  }

  @override
  Future<Elv5CalculationRevisionGuard?> loadRevision({
    required String projectId,
    required String designRevisionId,
  }) async {
    final row =
        await database
            .customSelect(
              'SELECT project_id, id, state, revision FROM project_design_revisions '
              'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
              variables: [
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
              ],
            )
            .getSingleOrNull();
    if (row == null) return null;
    return Elv5CalculationRevisionGuard(
      projectId: row.read<String>('project_id'),
      designRevisionId: row.read<String>('id'),
      state: row.read<String>('state'),
      rowRevision: row.read<int>('revision'),
    );
  }
}
