import '../../elv_write_unit_of_work.dart';
import '../persistence/elv5_replacement_persistence.dart';

final class Elv5PolicyBindingSnapshot {
  Elv5PolicyBindingSnapshot({
    required this.bindingId,
    required this.revision,
    required Map<String, Object?> payload,
  }) : payload = Map.unmodifiable(payload);

  final String bindingId;
  final int revision;
  final Map<String, Object?> payload;
}

abstract interface class Elv5PolicyMutationStore {
  Future<Elv5PolicyBindingSnapshot?> loadByBindingId({
    required String projectId,
    required String designRevisionId,
    required String bindingId,
  });

  Future<Elv5PolicyBindingSnapshot?> loadActiveBySubject({
    required String projectId,
    required String designRevisionId,
    required String subjectKind,
    required String subjectId,
  });

  Future<void> bind({
    required String projectId,
    required String designRevisionId,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  });

  Future<void> adopt({
    required String projectId,
    required String designRevisionId,
    required String bindingId,
    required int expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  });

  Future<void> release({
    required String projectId,
    required String designRevisionId,
    required String bindingId,
    required int expectedRootRevision,
    required DateTime updatedAtUtc,
  });
}

abstract interface class Elv5PolicyWriteSession
    implements Elv5ReplacementWriteSession {
  Elv5PolicyMutationStore get policies;
}

typedef Elv5PolicyWriteUnitOfWork = ElvWriteUnitOfWork<Elv5PolicyWriteSession>;
