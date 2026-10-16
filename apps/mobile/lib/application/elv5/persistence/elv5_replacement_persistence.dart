import 'elv5_runtime_persistence.dart';

final class Elv5RevisionSnapshot {
  const Elv5RevisionSnapshot({
    required this.projectId,
    required this.designRevisionId,
    required this.state,
    required this.rowRevision,
  });

  final String projectId;
  final String designRevisionId;
  final String state;
  final int rowRevision;

  bool get working => state == 'WORKING';
}

abstract interface class Elv5RevisionMutationStore {
  Future<Elv5RevisionSnapshot?> load({
    required String projectId,
    required String designRevisionId,
  });

  Future<bool> compareAndBump({
    required String projectId,
    required String designRevisionId,
    required int expectedRevision,
    required DateTime updatedAtUtc,
  });
}

final class Elv5AggregateEvidenceDraft {
  Elv5AggregateEvidenceDraft({
    required this.aggregateKind,
    required this.aggregateId,
    required this.canonicalPayloadJson,
    required this.payloadSha256,
  });

  final String aggregateKind;
  final String aggregateId;
  final String canonicalPayloadJson;
  final String payloadSha256;
}

final class Elv5HistoryAppend {
  Elv5HistoryAppend({
    required this.projectId,
    required this.designRevisionId,
    required this.originalCommandId,
    required this.forwardCommandType,
    required this.forwardCommandSchema,
    required this.forwardCanonicalPayloadJson,
    required this.forwardPayloadSha256,
    required this.inverseCommandType,
    required this.inverseCommandSchema,
    required this.inverseCanonicalPayloadJson,
    required this.inversePayloadSha256,
    required this.before,
    required this.after,
    required Iterable<String> affectedIds,
    required this.createdAtUtc,
  }) : affectedIds = List.unmodifiable(affectedIds.toSet()..removeWhere((e) => e.isEmpty)) {
    if (this.affectedIds.isEmpty) {
      throw ArgumentError('History append requires at least one affected id.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final String originalCommandId;
  final String forwardCommandType;
  final String forwardCommandSchema;
  final String forwardCanonicalPayloadJson;
  final String forwardPayloadSha256;
  final String inverseCommandType;
  final String inverseCommandSchema;
  final String inverseCanonicalPayloadJson;
  final String inversePayloadSha256;
  final Elv5AggregateEvidenceDraft before;
  final Elv5AggregateEvidenceDraft after;
  final List<String> affectedIds;
  final DateTime createdAtUtc;
}

abstract interface class Elv5RevisionHistoryStore {
  Future<void> appendOriginal(Elv5HistoryAppend append);
}

abstract interface class Elv5ReplacementWriteSession
    extends Elv5RuntimeWriteSession {
  Elv5RevisionMutationStore get revisions;
  Elv5RevisionHistoryStore get history;
}

typedef Elv5ReplacementWriteUnitOfWork =
    ElvWriteUnitOfWork<Elv5ReplacementWriteSession>;
