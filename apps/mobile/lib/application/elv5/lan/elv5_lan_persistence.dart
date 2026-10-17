import '../../elv_write_unit_of_work.dart';
import '../persistence/elv5_replacement_persistence.dart';

final class Elv5LanAggregateSnapshot {
  Elv5LanAggregateSnapshot({
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

abstract interface class Elv5LanFactStore {
  Future<Elv5LanAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  });
}

abstract interface class Elv5LanMutationStore implements Elv5LanFactStore {
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

abstract interface class Elv5LanWriteSession
    implements Elv5ReplacementWriteSession {
  Elv5LanMutationStore get lan;
}

typedef Elv5LanWriteUnitOfWork = ElvWriteUnitOfWork<Elv5LanWriteSession>;
