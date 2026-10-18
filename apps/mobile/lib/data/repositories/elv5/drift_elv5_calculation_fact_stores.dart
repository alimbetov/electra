import '../../../application/elv5/acs/elv5_acs_persistence.dart';
import '../../../application/elv5/cctv/elv5_cctv_persistence.dart';
import '../../../application/elv5/fire/elv5_fire_persistence.dart';
import '../../../application/elv5/lan/elv5_lan_persistence.dart';
import '../../database/app_database.dart';
import 'drift_elv5_acs_write_unit_of_work.dart';
import 'drift_elv5_cctv_write_unit_of_work.dart';
import 'drift_elv5_fire_write_unit_of_work.dart';
import 'drift_elv5_lan_write_unit_of_work.dart';
import 'drift_elv5_lan_rack_write_unit_of_work.dart';

/// Read façade used by ELV5 calculation capture.
///
/// The existing discipline stores already own the canonical SQL projection.
/// Reusing them avoids a second persistence mapping. Each read executes in its
/// own short transaction; [Elv5RevisionGuardedInputResolver] captures the
/// design-revision token after all reads, so any concurrent mutation makes the
/// later publication stale instead of publishing a mixed snapshot.
final class DriftElv5CctvCalculationFactStore implements Elv5CctvMutationStore {
  DriftElv5CctvCalculationFactStore(
    AppDatabase database, {
    required String originDeviceId,
  }) : _uow = DriftElv5CctvWriteUnitOfWork(
         database,
         originDeviceId: originDeviceId,
       );

  final DriftElv5CctvWriteUnitOfWork _uow;

  @override
  Future<Elv5CctvAggregateSnapshot?> loadCameraStreams({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
  }) => _uow.run(
    (session) => session.cctv.loadCameraStreams(
      projectId: projectId,
      designRevisionId: designRevisionId,
      cameraId: cameraId,
    ),
  );

  @override
  Future<Elv5CctvAggregateSnapshot?> loadRecordingPool({
    required String projectId,
    required String designRevisionId,
    required String poolId,
  }) => _uow.run(
    (session) => session.cctv.loadRecordingPool(
      projectId: projectId,
      designRevisionId: designRevisionId,
      poolId: poolId,
    ),
  );

  @override
  Future<void> replaceCameraStreams({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) => throw UnsupportedError('Calculation fact store is read-only.');

  @override
  Future<void> replaceRecordingPool({
    required String projectId,
    required String designRevisionId,
    required String poolId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) => throw UnsupportedError('Calculation fact store is read-only.');
}

final class DriftElv5LanCalculationFactStore implements Elv5LanMutationStore {
  DriftElv5LanCalculationFactStore(
    AppDatabase database, {
    required String originDeviceId,
  }) : _uow = DriftElv5LanWriteUnitOfWork(
         database,
         originDeviceId: originDeviceId,
       ),
       _rackUow = DriftElv5LanRackWriteUnitOfWork(
         database,
         originDeviceId: originDeviceId,
       );

  final DriftElv5LanWriteUnitOfWork _uow;
  final DriftElv5LanRackWriteUnitOfWork _rackUow;

  @override
  Future<Elv5LanAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) async {
    if (operation == 'REPLACE_RACK_CAPACITY_BASIS') {
      final rack = await _rackUow.run(
        (session) => session.racks.loadRack(
          projectId: projectId,
          designRevisionId: designRevisionId,
          rackId: subjectId,
        ),
      );
      if (rack == null) return null;
      return Elv5LanAggregateSnapshot(
        aggregateKind: 'LAN_RACK_CAPACITY_BASIS',
        aggregateId: rack.aggregateId,
        subjectId: rack.rackId,
        revision: rack.revision,
        payload: rack.payload,
      );
    }
    return _uow.run(
      (session) => session.lan.load(
        projectId: projectId,
        designRevisionId: designRevisionId,
        operation: operation,
        subjectId: subjectId,
      ),
    );
  }

  @override
  Future<void> replace({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) => throw UnsupportedError('Calculation fact store is read-only.');
}

final class DriftElv5AcsCalculationFactStore implements Elv5AcsMutationStore {
  DriftElv5AcsCalculationFactStore(
    AppDatabase database, {
    required String originDeviceId,
  }) : _uow = DriftElv5AcsWriteUnitOfWork(
         database,
         originDeviceId: originDeviceId,
       );

  final DriftElv5AcsWriteUnitOfWork _uow;

  @override
  Future<Elv5AcsAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) => _uow.run(
    (session) => session.acs.load(
      projectId: projectId,
      designRevisionId: designRevisionId,
      operation: operation,
      subjectId: subjectId,
    ),
  );

  @override
  Future<void> replace({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) => throw UnsupportedError('Calculation fact store is read-only.');
}

final class DriftElv5FireCalculationFactStore implements Elv5FireMutationStore {
  DriftElv5FireCalculationFactStore(
    AppDatabase database, {
    required String originDeviceId,
  }) : _uow = DriftElv5FireWriteUnitOfWork(
         database,
         originDeviceId: originDeviceId,
       );

  final DriftElv5FireWriteUnitOfWork _uow;

  @override
  Future<Elv5FireAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) => _uow.run(
    (session) => session.fire.load(
      projectId: projectId,
      designRevisionId: designRevisionId,
      operation: operation,
      subjectId: subjectId,
    ),
  );

  @override
  Future<void> replace({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) => throw UnsupportedError('Calculation fact store is read-only.');
}
