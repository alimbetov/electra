import 'package:drift/drift.dart';

import '../../database/app_database.dart';
import 'drift_elv5_dependency_invalidator.dart';

final class DriftFa08InvalidationCoordinator {
  const DriftFa08InvalidationCoordinator(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc;

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function()? _nowUtc;

  DriftElv5DependencyInvalidator get _invalidator =>
      DriftElv5DependencyInvalidator(
        database,
        originDeviceId: originDeviceId,
        nowUtc: _nowUtc,
      );

  Future<int> environmentEditionChanged({
    required String projectId,
    required String designRevisionId,
    required String oldEvidenceRef,
  }) => _invalidator.invalidateSubject(
    projectId: projectId,
    designRevisionId: designRevisionId,
    relationKind: 'POLICY',
    domain: 'ELV5_ENVIRONMENT_PROFILE',
    subjectId: oldEvidenceRef,
  );

  Future<int> groupingEvidenceChanged({
    required String projectId,
    required String designRevisionId,
    required String oldEvidenceRef,
  }) => _invalidator.invalidateSubject(
    projectId: projectId,
    designRevisionId: designRevisionId,
    relationKind: 'POLICY',
    domain: 'AMPACITY_GROUPING_CORRECTION',
    subjectId: oldEvidenceRef,
  );

  /// A newly selected ROOM/ROUTE_SECTION profile also affects nodes that
  /// previously inherited another profile or captured missing evidence.
  Future<int> environmentScopeChanged({
    required String projectId,
    required String designRevisionId,
    required String scopeKind,
    required String scopeId,
  }) async {
    if (scopeKind != 'ROOM' && scopeKind != 'ROUTE_SECTION') {
      throw ArgumentError.value(scopeKind, 'scopeKind');
    }
    final condition = scopeKind == 'ROOM' ? 'cr.room_id' : 's.id';
    final rows =
        await database
            .customSelect(
              'SELECT DISTINCT r.id FROM canonical_cable_runs r '
              'JOIN cable_run_traversals t ON t.cable_run_id = r.id '
              'JOIN cable_route_segments s ON s.id = t.route_segment_id '
              'JOIN cable_routes cr ON cr.id = s.route_id '
              'WHERE r.project_id = ? AND r.design_revision_id = ? '
              "AND r.lifecycle_state = 'ACTIVE' AND r.deleted_at IS NULL "
              'AND t.deleted_at IS NULL AND s.deleted_at IS NULL '
              'AND cr.deleted_at IS NULL AND $condition = ?',
              variables: <Variable>[
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
                Variable.withString(scopeId),
              ],
            )
            .get();
    return _invalidator.invalidate(
      projectId: projectId,
      designRevisionId: designRevisionId,
      dependencies: [
        for (final row in rows)
          Elv5InvalidationDependency(
            relationKind: 'SET',
            domain: 'CABLE_RUN_ROUTE',
            subjectId: row.read<String>('id'),
          ),
      ],
    );
  }

  Future<int> routeChanged({
    required String projectId,
    required String designRevisionId,
    required String cableRunId,
  }) => _invalidator.invalidate(
    projectId: projectId,
    designRevisionId: designRevisionId,
    dependencies: <Elv5InvalidationDependency>[
      Elv5InvalidationDependency(
        relationKind: 'SET',
        domain: 'CABLE_RUN_ROUTE',
        subjectId: cableRunId,
      ),
    ],
  );

  Future<int> cableDefinitionChanged({
    required String projectId,
    required String designRevisionId,
    required String cableId,
  }) async {
    final rows =
        await database
            .customSelect(
              'SELECT id FROM canonical_cable_runs '
              'WHERE project_id = ? AND design_revision_id = ? AND cable_id = ? '
              "AND lifecycle_state = 'ACTIVE' AND deleted_at IS NULL ORDER BY id",
              variables: <Variable>[
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
                Variable.withString(cableId),
              ],
            )
            .get();
    if (rows.isEmpty) return 0;
    return _invalidator.invalidate(
      projectId: projectId,
      designRevisionId: designRevisionId,
      dependencies: <Elv5InvalidationDependency>[
        for (final row in rows)
          Elv5InvalidationDependency(
            relationKind: 'SET',
            domain: 'CABLE_RUN_ROUTE',
            subjectId: row.read<String>('id'),
          ),
      ],
    );
  }
}
