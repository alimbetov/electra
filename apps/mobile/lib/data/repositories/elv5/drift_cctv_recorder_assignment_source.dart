import 'package:drift/drift.dart';

import '../../../application/elv5/cctv/cctv_recorder_assignment_source.dart';
import '../../database/app_database.dart';

final class DriftCctvRecorderAssignmentSource
    implements CctvRecorderAssignmentSource {
  const DriftCctvRecorderAssignmentSource(this.database);

  final AppDatabase database;

  @override
  Future<List<CctvRecorderAssignmentRef>> loadForCamera({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
  }) async {
    final rows = await database.customSelect(
      'SELECT r.id AS binding_id, r.revision AS binding_revision, r.recorder_id, '
      'a.assignment_id, a.camera_id, a.encoded_stream_id, a.license_channel_id, a.storage_pool_id '
      'FROM recorder_capacity_bindings r JOIN recorder_assignments a '
      'ON a.project_id = r.project_id AND a.design_revision_id = r.design_revision_id '
      'AND a.binding_id = r.id WHERE r.project_id = ? AND r.design_revision_id = ? '
      'AND r.deleted_at IS NULL AND a.camera_id = ? '
      'ORDER BY r.recorder_id, a.encoded_stream_id, a.assignment_id',
      variables:<Variable>[
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(cameraId),
      ],
    ).get();
    return List.unmodifiable(<CctvRecorderAssignmentRef>[
      for(final row in rows)
        CctvRecorderAssignmentRef(
          bindingId:row.read<String>('binding_id'),
          bindingRevision:row.read<int>('binding_revision'),
          recorderId:row.read<String>('recorder_id'),
          assignmentId:row.read<String>('assignment_id'),
          cameraId:row.read<String>('camera_id'),
          encodedStreamId:row.read<String>('encoded_stream_id'),
          licenseChannelId:row.read<String>('license_channel_id'),
          storagePoolId:row.read<String>('storage_pool_id'),
        ),
    ]);
  }
}
