import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_write_unit_of_work.dart';
import '../database/app_database.dart';

final class DriftElvCableWriteUnitOfWork
    implements ElvWriteUnitOfWork<ElvCableWriteSession> {
  const DriftElvCableWriteUnitOfWork(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<T> run<T>(Future<T> Function(ElvCableWriteSession session) action) =>
      database.transaction(() async {
        final session = _DriftElvCableWriteSession(
          database,
          originDeviceId: originDeviceId,
        );
        return action(session);
      });
}

final class _DriftElvCableWriteSession implements ElvCableWriteSession {
  _DriftElvCableWriteSession(
    this.database, {
    required String originDeviceId,
  })  : commandLedger = _DriftElvCommandLedgerStore(database),
        cables = _DriftElvCableWriteStore(
          database,
          originDeviceId: originDeviceId,
        ),
        cableDependencies = const _P1CableDependencyStore();

  final AppDatabase database;

  @override
  final ElvCommandLedgerStore commandLedger;

  @override
  final ElvCableWriteStore cables;

  @override
  final ElvCableDependencyStore cableDependencies;
}

final class _DriftElvCommandLedgerStore implements ElvCommandLedgerStore {
  const _DriftElvCommandLedgerStore(this.database);
  final AppDatabase database;

  @override
  Future<ElvCommandLedgerEntry?> find(String projectId, String commandId) async {
    final row = await (database.select(database.commandExecutionRecords)
          ..where(
            (candidate) =>
                candidate.projectId.equals(projectId) &
                candidate.commandId.equals(commandId),
          ))
        .getSingleOrNull();
    if (row == null) return null;
    return _entry(row);
  }

  @override
  Future<void> save(ElvCommandLedgerEntry entry) async {
    await database.into(database.commandExecutionRecords).insert(
          CommandExecutionRecordsCompanion.insert(
            projectId: entry.projectId,
            commandId: entry.commandId,
            commandType: entry.commandType,
            payloadSchemaVersion: entry.payloadSchemaVersion,
            normalizedPayloadSha256: entry.normalizedPayloadSha256,
            outcomeKind: entry.outcomeKind,
            logicalResultJson: entry.logicalResultJson,
            createdAt: entry.createdAt,
            committedAt: entry.committedAt,
            originDeviceId: entry.originDeviceId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final persisted = await find(entry.projectId, entry.commandId);
    if (persisted == null || !_sameLedgerEntry(persisted, entry)) {
      throw StateError('ELV command ledger conflict.');
    }
  }

  ElvCommandLedgerEntry _entry(CommandExecutionRecordRow row) =>
      ElvCommandLedgerEntry(
        projectId: row.projectId,
        commandId: row.commandId,
        commandType: row.commandType,
        payloadSchemaVersion: row.payloadSchemaVersion,
        normalizedPayloadSha256: row.normalizedPayloadSha256,
        outcomeKind: row.outcomeKind,
        logicalResultJson: row.logicalResultJson,
        createdAt: row.createdAt,
        committedAt: row.committedAt,
        originDeviceId: row.originDeviceId,
      );

  bool _sameLedgerEntry(
    ElvCommandLedgerEntry left,
    ElvCommandLedgerEntry right,
  ) =>
      left.projectId == right.projectId &&
      left.commandId == right.commandId &&
      left.commandType == right.commandType &&
      left.payloadSchemaVersion == right.payloadSchemaVersion &&
      left.normalizedPayloadSha256 == right.normalizedPayloadSha256 &&
      left.outcomeKind == right.outcomeKind &&
      left.logicalResultJson == right.logicalResultJson;
}

final class _DriftElvCableWriteStore implements ElvCableWriteStore {
  const _DriftElvCableWriteStore(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<bool> projectExists(String projectId) async =>
      await (database.select(database.projects)
            ..where((row) => row.id.equals(projectId) & row.deletedAt.isNull()))
          .getSingleOrNull() !=
      null;

  @override
  Future<Cable?> findCable(String projectId, String cableId) async {
    final row = await (database.select(database.elvCables)
          ..where(
            (candidate) =>
                candidate.projectId.equals(projectId) &
                candidate.id.equals(cableId) &
                candidate.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<CableDefinition> resolveDefinition(
    String projectId,
    CableDefinitionRef ref,
  ) async {
    final normalized = ref.normalized();
    final row = await (database.select(database.engineeringReferenceCatalogs)
          ..where(
            (candidate) =>
                candidate.projectId.equals(projectId) &
                candidate.id.equals(normalized.catalogId) &
                candidate.catalogVersion.equals(normalized.catalogVersion) &
                candidate.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    if (row == null) throw StateError('Catalog edition not found.');
    final catalog = EngineeringReferenceCatalog.fromMap(
      jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );
    final definition = catalog.cableDefinition(normalized.definitionCode);
    if (cableDefinitionContentHashV1(definition) !=
        normalized.definitionContentHash) {
      throw StateError('Cable definition hash mismatch.');
    }
    return definition;
  }

  @override
  Future<bool> activeLabelExists(
    String projectId,
    String normalizedLabel,
  ) async =>
      await (database.select(database.elvCables)
            ..where(
              (row) =>
                  row.projectId.equals(projectId) &
                  row.normalizedLabel.equals(normalizedLabel) &
                  row.lifecycleState.equals('ACTIVE') &
                  row.deletedAt.isNull(),
            ))
          .getSingleOrNull() !=
      null;

  @override
  Future<bool> insertCable(Cable cable) async {
    final now = DateTime.now().toUtc();
    final inserted = await database.into(database.elvCables).insert(
          ElvCablesCompanion.insert(
            id: cable.id,
            projectId: cable.projectId,
            label: cable.label,
            normalizedLabel: cable.normalizedLabel,
            name: cable.name,
            definitionCatalogId: cable.definitionRef.catalogId,
            definitionCatalogVersion: cable.definitionRef.catalogVersion,
            definitionCode: cable.definitionRef.definitionCode,
            definitionContentHash: cable.definitionRef.definitionContentHash,
            lifecycleState: 'ACTIVE',
            revision: Value(cable.revision),
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return inserted > 0;
  }

  @override
  Future<bool> updateDefinition({
    required String projectId,
    required String cableId,
    required int expectedRevision,
    required CableDefinitionRef definitionRef,
  }) async {
    final affected = await (database.update(database.elvCables)
          ..where(
            (row) =>
                row.id.equals(cableId) &
                row.projectId.equals(projectId) &
                row.revision.equals(expectedRevision) &
                row.lifecycleState.equals('ACTIVE') &
                row.deletedAt.isNull(),
          ))
        .write(
      ElvCablesCompanion(
        definitionCatalogId: Value(definitionRef.catalogId),
        definitionCatalogVersion: Value(definitionRef.catalogVersion),
        definitionCode: Value(definitionRef.definitionCode),
        definitionContentHash: Value(definitionRef.definitionContentHash),
        revision: Value(expectedRevision + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    return affected == 1;
  }

  @override
  Future<bool> archiveCable({
    required String projectId,
    required String cableId,
    required int expectedRevision,
  }) async {
    final affected = await (database.update(database.elvCables)
          ..where(
            (row) =>
                row.id.equals(cableId) &
                row.projectId.equals(projectId) &
                row.revision.equals(expectedRevision) &
                row.lifecycleState.equals('ACTIVE') &
                row.deletedAt.isNull(),
          ))
        .write(
      ElvCablesCompanion(
        lifecycleState: const Value('ARCHIVED'),
        revision: Value(expectedRevision + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    return affected == 1;
  }

  Cable _fromRow(ElvCableRow row) => Cable(
    id: row.id,
    projectId: row.projectId,
    label: row.label,
    name: row.name,
    definitionRef: CableDefinitionRef(
      catalogId: row.definitionCatalogId,
      catalogVersion: row.definitionCatalogVersion,
      definitionCode: row.definitionCode,
      definitionContentHash: row.definitionContentHash,
    ),
    lifecycleState: CableLifecycleState.values.byName(
      row.lifecycleState.toLowerCase(),
    ),
    revision: row.revision,
  );
}

final class _P1CableDependencyStore implements ElvCableDependencyStore {
  const _P1CableDependencyStore();

  @override
  Future<List<String>> blockingDependencyIds(String projectId, String cableId) async =>
      const [];

  @override
  Future<bool> hasCanonicalRunHistory(String projectId, String cableId) async => false;

  @override
  Future<bool> hasConsumingAllocation(String projectId, String cableId) async => false;

  @override
  Future<bool> hasResourceSelectionHistory(String projectId, String cableId) async => false;
}
