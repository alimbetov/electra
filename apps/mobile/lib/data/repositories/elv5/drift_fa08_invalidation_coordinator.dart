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
  }) => _invalidator.invalidate(
    projectId: projectId,
    designRevisionId: designRevisionId,
    dependencies: <Elv5InvalidationDependency>[
      Elv5InvalidationDependency(
        relationKind: 'POLICY',
        domain: 'ELV5_ENVIRONMENT_PROFILE',
        subjectId: oldEvidenceRef,
      ),
    ],
  );

  Future<int> groupingEvidenceChanged({
    required String projectId,
    required String designRevisionId,
    required String oldEvidenceRef,
  }) => _invalidator.invalidate(
    projectId: projectId,
    designRevisionId: designRevisionId,
    dependencies: <Elv5InvalidationDependency>[
      Elv5InvalidationDependency(
        relationKind: 'POLICY',
        domain: 'AMPACITY_GROUPING_CORRECTION',
        subjectId: oldEvidenceRef,
      ),
    ],
  );

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
