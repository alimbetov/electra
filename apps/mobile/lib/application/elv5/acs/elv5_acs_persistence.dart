import '../../elv_write_unit_of_work.dart';
import '../persistence/elv5_replacement_persistence.dart';

final class Elv5AcsAggregateSnapshot {
  Elv5AcsAggregateSnapshot({
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

abstract interface class Elv5AcsFactStore {
  Future<Elv5AcsAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  });
}

abstract interface class Elv5AcsMutationStore implements Elv5AcsFactStore {
  Future<void> replace({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  });
}

abstract interface class Elv5AcsWriteSession
    implements Elv5ReplacementWriteSession {
  Elv5AcsMutationStore get acs;
}

typedef Elv5AcsWriteUnitOfWork = ElvWriteUnitOfWork<Elv5AcsWriteSession>;
