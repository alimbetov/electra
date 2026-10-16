import '../../elv_write_unit_of_work.dart';
import '../persistence/elv5_replacement_persistence.dart';

final class Elv5CctvAggregateSnapshot {
  Elv5CctvAggregateSnapshot({
    required this.aggregateKind,
    required this.aggregateId,
    required this.subjectId,
    required this.revision,
    required Map<String, Object?> payload,
  }) : payload = Map.unmodifiable(payload);

  final String aggregateKind;
  final String aggregateId;
  final String subjectId;
  final int revision;
  final Map<String, Object?> payload;
}

abstract interface class Elv5CctvMutationStore {
  Future<Elv5CctvAggregateSnapshot?> loadCameraStreams({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
  });

  Future<void> replaceCameraStreams({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  });

  Future<Elv5CctvAggregateSnapshot?> loadRecordingPool({
    required String projectId,
    required String designRevisionId,
    required String poolId,
  });

  Future<void> replaceRecordingPool({
    required String projectId,
    required String designRevisionId,
    required String poolId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  });
}

abstract interface class Elv5CctvWriteSession
    extends Elv5ReplacementWriteSession {
  Elv5CctvMutationStore get cctv;
}

typedef Elv5CctvWriteUnitOfWork = ElvWriteUnitOfWork<Elv5CctvWriteSession>;
