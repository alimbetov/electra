import '../../elv_write_unit_of_work.dart';
import '../persistence/elv5_replacement_persistence.dart';

final class Elv5LanRackSnapshot {
  Elv5LanRackSnapshot({
    required this.aggregateId,
    required this.rackId,
    required this.revision,
    required Map<String, Object?> payload,
    required Map<String, Object?> capturedRackProfile,
  }) : payload = Map.unmodifiable(payload),
       capturedRackProfile = Map.unmodifiable(capturedRackProfile);

  final String aggregateId;
  final String rackId;
  final int revision;
  final Map<String, Object?> payload;
  final Map<String, Object?> capturedRackProfile;
}

abstract interface class Elv5LanRackMutationStore {
  Future<Elv5LanRackSnapshot?> loadRack({
    required String projectId,
    required String designRevisionId,
    required String rackId,
  });

  Future<void> replaceRack({
    required String projectId,
    required String designRevisionId,
    required String rackId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  });
}

abstract interface class Elv5LanRackWriteSession
    implements Elv5ReplacementWriteSession {
  Elv5LanRackMutationStore get racks;
}

typedef Elv5LanRackWriteUnitOfWork =
    ElvWriteUnitOfWork<Elv5LanRackWriteSession>;
