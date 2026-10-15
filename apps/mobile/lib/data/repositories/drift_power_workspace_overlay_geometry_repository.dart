import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/power_workspace_overlay_geometry.dart';
import '../database/app_database.dart';

final class DriftPowerWorkspaceOverlayGeometryRepository
    implements PowerWorkspaceOverlayGeometryRepository {
  const DriftPowerWorkspaceOverlayGeometryRepository(this.database);

  final AppDatabase database;

  @override
  Future<List<PowerWorkspaceOverlaySegment>> load({
    required String projectId,
    required String designRevisionId,
    required Iterable<String> cableRunIds,
  }) async {
    final runIds =
        cableRunIds
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (runIds.isEmpty) return const [];

    final placeholders = List.filled(runIds.length, '?').join(',');
    final rows =
        await database
            .customSelect(
              'SELECT t.route_segment_id AS segment_id, '
              's.surface_patch_id AS patch_id, '
              'CASE WHEN fn.patch_id = s.surface_patch_id THEN fn.local_xmm ELSE fn.other_local_xmm END AS from_x, '
              'CASE WHEN fn.patch_id = s.surface_patch_id THEN fn.local_ymm ELSE fn.other_local_ymm END AS from_y, '
              'CASE WHEN tn.patch_id = s.surface_patch_id THEN tn.local_xmm ELSE tn.other_local_xmm END AS to_x, '
              'CASE WHEN tn.patch_id = s.surface_patch_id THEN tn.local_ymm ELSE tn.other_local_ymm END AS to_y, '
              't.sequence AS traversal_sequence '
              'FROM cable_run_traversals t '
              'JOIN canonical_cable_runs r ON r.id = t.cable_run_id '
              'JOIN cable_route_segments s ON s.id = t.route_segment_id '
              'JOIN cable_route_nodes fn ON fn.id = s.from_node_id '
              'JOIN cable_route_nodes tn ON tn.id = s.to_node_id '
              'WHERE r.project_id = ? AND r.design_revision_id = ? '
              'AND r.deleted_at IS NULL AND t.deleted_at IS NULL '
              'AND s.deleted_at IS NULL AND t.cable_run_id IN ($placeholders) '
              'ORDER BY t.cable_run_id, t.sequence, t.route_segment_id',
              variables: [
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
                for (final runId in runIds) Variable.withString(runId),
              ],
            )
            .get();

    final result = <PowerWorkspaceOverlaySegment>[];
    final seen = <String>{};
    for (final row in rows) {
      final segmentId = row.read<String>('segment_id');
      if (!seen.add(segmentId)) continue;
      final fromX = row.readNullable<int>('from_x');
      final fromY = row.readNullable<int>('from_y');
      final toX = row.readNullable<int>('to_x');
      final toY = row.readNullable<int>('to_y');
      if (fromX == null || fromY == null || toX == null || toY == null) {
        throw StateError(
          'ELV4_POWER_OVERLAY_ROUTE_GEOMETRY_MISSING:$segmentId',
        );
      }
      result.add(
        PowerWorkspaceOverlaySegment(
          segmentId: segmentId,
          surfacePatchId: row.read<String>('patch_id'),
          from: Point2Mm(fromX, fromY),
          to: Point2Mm(toX, toY),
        ),
      );
    }
    return List.unmodifiable(result);
  }
}
