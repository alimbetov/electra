import 'package:drift/drift.dart';
import '../../database/app_database.dart';
import 'drift_elv5_dependency_invalidator.dart';

/// Called inside the canonical writer transaction. Frozen results read their
/// captured section; only working revisions participate in invalidation/CAS.
Future<void> invalidateElv5CanonicalSource(
  AppDatabase database, {
  required String roomId,
  required String domain,
  required Iterable<String> subjectIds,
  required String originDeviceId,
  required DateTime now,
}) async {
  final revisions =
      await database
          .customSelect(
            'SELECT r.project_id,r.id FROM project_design_revisions r '
            'JOIN floors f ON f.project_id=r.project_id JOIN rooms rm ON rm.floor_id=f.id '
            "WHERE rm.id=? AND r.state='WORKING' AND r.deleted_at IS NULL "
            'AND (EXISTS (SELECT 1 FROM discipline_policy_bindings b '
            'WHERE b.design_revision_id=r.id AND b.project_id=r.project_id AND b.deleted_at IS NULL) '
            'OR EXISTS (SELECT 1 FROM discipline_dependency_index d '
            'WHERE d.design_revision_id=r.id AND d.project_id=r.project_id))',
            variables: [Variable.withString(roomId)],
          )
          .get();
  for (final revision in revisions) {
    final projectId = revision.read<String>('project_id');
    final id = revision.read<String>('id');
    // Advance the capture token even if a first calculation is in flight and
    // has not installed its dependency index yet. Empty ELV4-only revisions
    // retain their existing command/revision contract.
    await database.customUpdate(
      'UPDATE project_design_revisions SET revision=revision+1,updated_at=?,origin_device_id=? '
      "WHERE project_id=? AND id=? AND state='WORKING'",
      variables: [
        Variable<DateTime>(now),
        Variable.withString(originDeviceId),
        Variable.withString(projectId),
        Variable.withString(id),
      ],
    );
    final invalidator = DriftElv5DependencyInvalidator(
      database,
      originDeviceId: originDeviceId,
      nowUtc: () => now,
    );
    for (final subjectId in subjectIds.toSet()) {
      await invalidator.invalidateSubject(
        projectId: projectId,
        designRevisionId: id,
        relationKind: 'FACT',
        domain: domain,
        subjectId: subjectId,
      );
    }
  }
}
