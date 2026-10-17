import '../../elv_write_unit_of_work.dart';
import '../persistence/elv5_replacement_persistence.dart';

final class Elv5CctvRecorderSnapshot {
  Elv5CctvRecorderSnapshot({
    required this.aggregateId,
    required this.recorderId,
    required this.revision,
    required Map<String, Object?> payload,
  }) : payload = Map.unmodifiable(payload);

  final String aggregateId;
  final String recorderId;
  final int revision;
  final Map<String, Object?> payload;
}

abstract interface class Elv5CctvRecorderFactStore {
  Future<Elv5CctvRecorderSnapshot?> loadRecorder({
    required String projectId,
    required String designRevisionId,
    required String recorderId,
  });
}

abstract interface class Elv5CctvRecorderMutationStore
    implements Elv5CctvRecorderFactStore {
  Future<void> replaceRecorder({
    required String projectId,
    required String designRevisionId,
    required String recorderId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  });
}

abstract interface class Elv5CctvRecorderWriteSession
    extends Elv5ReplacementWriteSession {
  Elv5CctvRecorderMutationStore get recorder;
}

typedef Elv5CctvRecorderWriteUnitOfWork =
    ElvWriteUnitOfWork<Elv5CctvRecorderWriteSession>;
