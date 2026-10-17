import 'package:drift/drift.dart';

import '../../../application/elv5/calculation/elv5_capture_guard.dart';
import '../../database/app_database.dart';

final class DriftElv5CaptureRevisionSource
    implements Elv5CaptureRevisionSource {
  const DriftElv5CaptureRevisionSource(this.database);

  final AppDatabase database;

  @override
  Future<int> requireWorkingRevision({
    required String projectId,
    required String designRevisionId,
  }) async {
    final row =
        await database
            .customSelect(
              'SELECT state, revision FROM project_design_revisions '
              'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
              variables: <Variable>[
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
              ],
            )
            .getSingleOrNull();
    if (row == null) {
      throw StateError(
        'ELV5_CAPTURE_DESIGN_REVISION_NOT_FOUND:$designRevisionId',
      );
    }
    final state = row.read<String>('state');
    if (state != 'WORKING') {
      throw StateError('ELV5_CAPTURE_DESIGN_REVISION_READ_ONLY:$state');
    }
    return row.read<int>('revision');
  }
}
