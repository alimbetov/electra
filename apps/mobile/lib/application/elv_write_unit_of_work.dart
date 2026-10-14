import 'package:engineering_core/engineering_core.dart';

import 'elv_cable_dependency_inspector.dart';

abstract interface class ElvCommandLedgerStore {
  Future<ElvCommandLedgerEntry?> find(String projectId, String commandId);
  Future<void> save(ElvCommandLedgerEntry entry);
}

final class ElvCommandLedgerEntry {
  const ElvCommandLedgerEntry({
    required this.projectId,
    required this.commandId,
    required this.commandType,
    required this.payloadSchemaVersion,
    required this.normalizedPayloadSha256,
    required this.outcomeKind,
    required this.logicalResultJson,
    required this.createdAt,
    required this.committedAt,
    required this.originDeviceId,
  });

  final String projectId;
  final String commandId;
  final String commandType;
  final int payloadSchemaVersion;
  final String normalizedPayloadSha256;
  final String outcomeKind;
  final String logicalResultJson;
  final DateTime createdAt;
  final DateTime committedAt;
  final String originDeviceId;
}

abstract interface class ElvWriteSession {
  ElvCommandLedgerStore get commandLedger;
}

abstract interface class ElvCableWriteStore {
  Future<bool> projectExists(String projectId);
  Future<Cable?> findCable(String projectId, String cableId);
  Future<bool> activeLabelExists(String projectId, String normalizedLabel);
  Future<bool> insertCable(Cable cable);
  Future<bool> updateDefinition({
    required String projectId,
    required String cableId,
    required int expectedRevision,
    required CableDefinitionRef definitionRef,
  });
  Future<bool> archiveCable({
    required String projectId,
    required String cableId,
    required int expectedRevision,
  });
}

abstract interface class ElvReferenceReadStore {
  Future<CableDefinition> resolveCableDefinition(
    String projectId,
    CableDefinitionRef ref,
  );
}

abstract interface class ElvCableDependencyStore
    implements ElvCableDependencyInspector {}

abstract interface class ElvCableWriteSession extends ElvWriteSession {
  ElvCableWriteStore get cables;
  ElvReferenceReadStore get references;
  ElvCableDependencyStore get cableDependencies;
}

abstract interface class ElvWriteUnitOfWork<S extends ElvWriteSession> {
  Future<T> run<T>(Future<T> Function(S session) action);
}
