import '../../../application/elv5/cctv/elv5_cctv_recorder_persistence.dart';
import '../../database/app_database.dart';
import 'drift_elv5_cctv_recorder_write_unit_of_work.dart';

final class DriftElv5CctvRecorderFactStore
    implements Elv5CctvRecorderFactStore {
  DriftElv5CctvRecorderFactStore(
    AppDatabase database, {
    required String originDeviceId,
  }) : _uow = DriftElv5CctvRecorderWriteUnitOfWork(
         database,
         originDeviceId: originDeviceId,
       );

  final DriftElv5CctvRecorderWriteUnitOfWork _uow;

  @override
  Future<Elv5CctvRecorderSnapshot?> loadRecorder({
    required String projectId,
    required String designRevisionId,
    required String recorderId,
  }) => _uow.run(
    (session) => session.recorder.loadRecorder(
      projectId: projectId,
      designRevisionId: designRevisionId,
      recorderId: recorderId,
    ),
  );
}
