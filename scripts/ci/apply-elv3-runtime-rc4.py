from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, got {count}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1))

def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)

db = ROOT / 'apps/mobile/lib/data/database/app_database.dart'

p5_tables = r'''@DataClassName('PhysicalProfileSetRow')
class PhysicalProfileSets extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get state => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PhysicalProfileSetEntryRow')
class PhysicalProfileSetEntries extends Table {
  TextColumn get profileSetId => text().references(PhysicalProfileSets, #id)();
  IntColumn get sequence => integer()();
  TextColumn get catalogId => text()();
  TextColumn get catalogVersion => text()();
  TextColumn get profileCode => text()();
  TextColumn get profileContentHash => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {profileSetId, sequence};
}

@DataClassName('PhysicalCompatibilityFindingRow')
class PhysicalCompatibilityFindings extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId => text().references(ProjectDesignRevisions, #id)();
  TextColumn get profileSetId => text().references(PhysicalProfileSets, #id)();
  TextColumn get subjectKey => text()();
  TextColumn get status => text()();
  TextColumn get code => text()();
  TextColumn get inputFingerprint => text()();
  TextColumn get findingJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

'''
replace_once(db, "@DriftDatabase(\n", p5_tables + "@DriftDatabase(\n")
replace_once(db, "    TraversalCarrierAssignments,\n", "    TraversalCarrierAssignments,\n    PhysicalProfileSets,\n    PhysicalProfileSetEntries,\n    PhysicalCompatibilityFindings,\n")
replace_once(db, "  int get schemaVersion => 21;", "  int get schemaVersion => 22;")
replace_once(db,
    "        if (from < 21) {\n          await migrator.createTable(pathwayContexts);\n          await migrator.createTable(physicalCarriers);\n          await migrator.createTable(physicalCarrierCompartments);\n          await migrator.createTable(traversalCarrierAssignments);\n        }\n",
    "        if (from < 21) {\n          await migrator.createTable(pathwayContexts);\n          await migrator.createTable(physicalCarriers);\n          await migrator.createTable(physicalCarrierCompartments);\n          await migrator.createTable(traversalCarrierAssignments);\n        }\n        if (from < 22) {\n          await migrator.createTable(physicalProfileSets);\n          await migrator.createTable(physicalProfileSetEntries);\n          await migrator.createTable(physicalCompatibilityFindings);\n        }\n")
replace_once(db,
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_traversal_carrier_assignment_run ON traversal_carrier_assignments(cable_run_id)');\n",
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_traversal_carrier_assignment_run ON traversal_carrier_assignments(cable_run_id)');\n"
    "    await customStatement(\"CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_active_physical_profile_set ON physical_profile_sets(project_id) WHERE state = 'ACTIVE' AND deleted_at IS NULL\");\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_profile_set_entry ON physical_profile_set_entries(profile_set_id, sequence)');\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_physical_finding_revision ON physical_compatibility_findings(project_id, design_revision_id, subject_key)');\n")

write('apps/mobile/lib/data/repositories/drift_elv_physical_compatibility_repository.dart', r'''import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_command_result.dart';
import '../../application/elv_physical_compatibility_repository.dart';
import '../../application/elv_physical_profile_set_command.dart';
import '../database/app_database.dart';
import 'drift_elv_runtime_support.dart';

abstract interface class ElvPhysicalProfileResolver {
  Future<PhysicalCompatibilityProfile?> resolve(PhysicalCompatibilityProfileRef ref);
}

final class DriftElvPhysicalCompatibilityRepository
    implements ElvPhysicalCompatibilityRepository {
  DriftElvPhysicalCompatibilityRepository(
    this.database, {
    required this.originDeviceId,
    required this.profileResolver,
  });

  final AppDatabase database;
  final String originDeviceId;
  final ElvPhysicalProfileResolver profileResolver;

  @override
  Future<ProjectPhysicalCompatibilityProfileSet?> activeProfileSet(String projectId) async {
    final row = await (database.select(database.physicalProfileSets)
          ..where((candidate) => candidate.projectId.equals(projectId) & candidate.state.equals('ACTIVE') & candidate.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _setFromRow(row, await _refs(row.id));
  }

  @override
  Future<ElvCommandResult<ProjectPhysicalCompatibilityProfileSet>> createProfileSet(CreatePhysicalCompatibilityProfileSetCommand command) =>
      database.transaction(() async {
        final active = await activeProfileSet(command.projectId);
        if (active != null) {
          return elvRuntimeFailure('ELV_PHYSICAL_PROFILE_SET_ACTIVE_EXISTS', ElvFailureCategory.lifecycle);
        }
        return _insertSet(commandId: command.commandId, projectId: command.projectId, profileSetId: command.profileSetId, refs: command.refs);
      });

  @override
  Future<ElvCommandResult<ProjectPhysicalCompatibilityProfileSet>> replaceActiveProfileSet(ReplaceActivePhysicalCompatibilityProfileSetCommand command) =>
      database.transaction(() async {
        final current = await activeProfileSet(command.projectId);
        if (current != null) {
          await (database.update(database.physicalProfileSets)..where((row) => row.id.equals(current.id))).write(
            PhysicalProfileSetsCompanion(state: const Value('ARCHIVED'), revision: Value(current.revision + 1), updatedAt: Value(DateTime.now().toUtc()), originDeviceId: Value(originDeviceId)),
          );
        }
        return _insertSet(commandId: command.commandId, projectId: command.projectId, profileSetId: command.profileSetId, refs: command.refs);
      });

  Future<ElvCommandResult<ProjectPhysicalCompatibilityProfileSet>> _insertSet({
    required String commandId,
    required String projectId,
    required String profileSetId,
    required List<PhysicalCompatibilityProfileRef> refs,
  }) async {
    if (refs.isEmpty) return elvRuntimeFailure('ELV_PHYSICAL_PROFILE_SET_EMPTY', ElvFailureCategory.validation);
    final unique = refs.map(_refIdentity).toSet();
    if (unique.length != refs.length) return elvRuntimeFailure('ELV_PHYSICAL_PROFILE_SET_DUPLICATE_REF', ElvFailureCategory.validation);
    final profiles = await resolveProfiles(projectId, refs);
    if (profiles.length != refs.length) return elvRuntimeFailure('ELV_PHYSICAL_PROFILE_REF_UNRESOLVED', ElvFailureCategory.referenceIntegrity);
    final now = DateTime.now().toUtc();
    await database.into(database.physicalProfileSets).insert(PhysicalProfileSetsCompanion.insert(
      id: profileSetId,
      projectId: projectId,
      state: 'ACTIVE',
      revision: const Value(1),
      createdAt: now,
      updatedAt: now,
      originDeviceId: originDeviceId,
    ));
    for (var i = 0; i < refs.length; i++) {
      final ref = refs[i];
      await database.into(database.physicalProfileSetEntries).insert(PhysicalProfileSetEntriesCompanion.insert(
        profileSetId: profileSetId,
        sequence: i + 1,
        catalogId: ref.catalogId,
        catalogVersion: ref.catalogVersion,
        profileCode: ref.profileCode,
        profileContentHash: ref.profileContentHash,
        createdAt: now,
        originDeviceId: originDeviceId,
      ));
    }
    return ElvCommandSuccess(ProjectPhysicalCompatibilityProfileSet(id: profileSetId, projectId: projectId, refs: refs, state: PhysicalCompatibilityProfileSetState.active, revision: 1));
  }

  @override
  Future<ElvCommandResult<void>> archiveProfileSet(ArchivePhysicalCompatibilityProfileSetCommand command) => database.transaction(() async {
    final row = await (database.select(database.physicalProfileSets)..where((candidate) => candidate.id.equals(command.profileSetId) & candidate.projectId.equals(command.projectId) & candidate.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return elvRuntimeFailure('ELV_PHYSICAL_PROFILE_SET_NOT_FOUND', ElvFailureCategory.notFound);
    if (row.revision != command.expectedRevision) return elvRuntimeFailure('ELV_PHYSICAL_PROFILE_SET_REVISION_CONFLICT', ElvFailureCategory.revisionConflict, expectedRevision: command.expectedRevision, actualRevision: row.revision);
    await (database.update(database.physicalProfileSets)..where((candidate) => candidate.id.equals(command.profileSetId))).write(PhysicalProfileSetsCompanion(state: const Value('ARCHIVED'), revision: Value(row.revision + 1), updatedAt: Value(DateTime.now().toUtc()), originDeviceId: Value(originDeviceId)));
    return const ElvCommandSuccess<void>(null);
  });

  @override
  Future<List<PhysicalCompatibilityProfile>> resolveProfiles(String projectId, Iterable<PhysicalCompatibilityProfileRef> refs) async {
    final result = <PhysicalCompatibilityProfile>[];
    for (final ref in refs) {
      final profile = await profileResolver.resolve(ref);
      if (profile == null) continue;
      if (profile.code != ref.profileCode.trim().toUpperCase()) continue;
      if (physicalCompatibilityProfileContentHashV1(profile) != ref.profileContentHash) continue;
      result.add(profile);
    }
    return List.unmodifiable(result);
  }

  Future<List<PhysicalCompatibilityProfileRef>> _refs(String setId) async {
    final rows = await (database.select(database.physicalProfileSetEntries)
          ..where((row) => row.profileSetId.equals(setId))
          ..orderBy([(row) => OrderingTerm.asc(row.sequence)]))
        .get();
    return rows.map((row) => PhysicalCompatibilityProfileRef(catalogId: row.catalogId, catalogVersion: row.catalogVersion, profileCode: row.profileCode, profileContentHash: row.profileContentHash)).toList(growable: false);
  }

  ProjectPhysicalCompatibilityProfileSet _setFromRow(PhysicalProfileSetRow row, List<PhysicalCompatibilityProfileRef> refs) => ProjectPhysicalCompatibilityProfileSet(
    id: row.id,
    projectId: row.projectId,
    refs: refs,
    state: PhysicalCompatibilityProfileSetState.values.byName(row.state.toLowerCase()),
    revision: row.revision,
  );

  Future<void> replaceFindings({
    required String projectId,
    required String designRevisionId,
    required String profileSetId,
    required String subjectKey,
    required List<PhysicalCompatibilityFinding> findings,
  }) => database.transaction(() async {
    await (database.delete(database.physicalCompatibilityFindings)..where((row) => row.projectId.equals(projectId) & row.designRevisionId.equals(designRevisionId) & row.subjectKey.equals(subjectKey))).go();
    final now = DateTime.now().toUtc();
    for (var i = 0; i < findings.length; i++) {
      final finding = findings[i];
      final payload = _findingMap(finding);
      final id = elvRuntimeFingerprint('electra.physical-finding-id.v1', {'projectId': projectId, 'designRevisionId': designRevisionId, 'subjectKey': subjectKey, 'index': i, 'code': finding.code, 'fingerprint': finding.inputFingerprint});
      await database.into(database.physicalCompatibilityFindings).insert(PhysicalCompatibilityFindingsCompanion.insert(
        id: id,
        projectId: projectId,
        designRevisionId: designRevisionId,
        profileSetId: profileSetId,
        subjectKey: subjectKey,
        status: finding.status.name.toUpperCase(),
        code: finding.code,
        inputFingerprint: finding.inputFingerprint,
        findingJson: jsonEncode(payload),
        revision: const Value(1),
        createdAt: now,
        updatedAt: now,
        originDeviceId: originDeviceId,
      ));
    }
  });

  Future<List<PhysicalCompatibilityFinding>> loadFindings({required String projectId, required String designRevisionId, required String subjectKey}) async {
    final rows = await (database.select(database.physicalCompatibilityFindings)
          ..where((row) => row.projectId.equals(projectId) & row.designRevisionId.equals(designRevisionId) & row.subjectKey.equals(subjectKey) & row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.asc(row.id)]))
        .get();
    return rows.map((row) => _findingFromMap((jsonDecode(row.findingJson) as Map).cast<String, dynamic>())).toList(growable: false);
  }
}

String _refIdentity(PhysicalCompatibilityProfileRef ref) => '${ref.catalogId}|${ref.catalogVersion}|${ref.profileCode}|${ref.profileContentHash}';

Map<String, Object?> _refMap(PhysicalCompatibilityProfileRef ref) => {'catalogId': ref.catalogId, 'catalogVersion': ref.catalogVersion, 'profileCode': ref.profileCode, 'profileContentHash': ref.profileContentHash};

Map<String, Object?> _findingMap(PhysicalCompatibilityFinding finding) => {
  'status': finding.status.name,
  'code': finding.code,
  'affectedEntityIds': finding.affectedEntityIds,
  'inputFingerprint': finding.inputFingerprint,
  'explanation': finding.explanation,
  'sourceProfileRefs': finding.sourceProfileRefs.map(_refMap).toList(growable: false),
};

PhysicalCompatibilityFinding _findingFromMap(Map<String, dynamic> map) => PhysicalCompatibilityFinding(
  status: PhysicalCompatibilityStatus.values.byName(map['status'] as String),
  code: map['code'] as String,
  affectedEntityIds: (map['affectedEntityIds'] as List).cast<String>(),
  inputFingerprint: map['inputFingerprint'] as String,
  explanation: map['explanation'] as String,
  sourceProfileRefs: (map['sourceProfileRefs'] as List).map((item) {
    final ref = (item as Map).cast<String, dynamic>();
    return PhysicalCompatibilityProfileRef(catalogId: ref['catalogId'] as String, catalogVersion: ref['catalogVersion'] as String, profileCode: ref['profileCode'] as String, profileContentHash: ref['profileContentHash'] as String);
  }).toList(growable: false),
);
''')

write('apps/mobile/test/data/elv_p5_runtime_closure_test.dart', r'''import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_physical_compatibility_service.dart';
import 'package:electra_mobile/application/elv_physical_profile_set_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_physical_compatibility_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Resolver implements ElvPhysicalProfileResolver {
  _Resolver(this.profile);
  final PhysicalCompatibilityProfile profile;
  @override
  Future<PhysicalCompatibilityProfile?> resolve(PhysicalCompatibilityProfileRef ref) async => ref.profileCode == profile.code ? profile : null;
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 14);
  await db.into(db.projects).insert(ProjectsCompanion.insert(id: 'p', name: 'P5', measurementSystem: 'metric', defaultStructuralHeightMm: 3000, defaultFinishedCeilingHeightMm: 2700, createdAt: now, updatedAt: now, originDeviceId: 'test'));
  await db.into(db.projectDesignRevisions).insert(ProjectDesignRevisionsCompanion.insert(id: 'rev', projectId: 'p', code: 'R1', sequence: 1, state: 'WORKING', revision: const Value(1), createdAt: now, updatedAt: now, originDeviceId: 'test'));
}

void main() {
  final profile = PhysicalCompatibilityProfile(code: 'LAN-TRAY', label: 'LAN tray', rules: [AllowedCarrierKindRule(PhysicalCompatibilitySelector(mediaCodes: ['COPPER']), ['TRAY'])]);
  final ref = PhysicalCompatibilityProfileRef(catalogId: 'physical', catalogVersion: '1', profileCode: 'LAN-TRAY', profileContentHash: physicalCompatibilityProfileContentHashV1(profile));

  test('schema 22 exposes exact profile-set and finding roots', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 22);
    final names = (await db.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get()).map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll({'physical_profile_sets', 'physical_profile_set_entries', 'physical_compatibility_findings'}));
  });

  test('active profile set preserves immutable refs and resolves exact content hash', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    final repo = DriftElvPhysicalCompatibilityRepository(db, originDeviceId: 'test', profileResolver: _Resolver(profile));
    final created = await repo.createProfileSet(CreatePhysicalCompatibilityProfileSetCommand(commandId: 'set', projectId: 'p', profileSetId: 'ps-1', refs: [ref]));
    expect(created, isA<ElvCommandSuccess<ProjectPhysicalCompatibilityProfileSet>>());
    final active = await repo.activeProfileSet('p');
    expect(active!.refs.single.profileContentHash, ref.profileContentHash);
    expect((await repo.resolveProfiles('p', active.refs)).single.code, 'LAN-TRAY');
  });

  test('compatibility findings are persisted revision-scoped and reload deterministically', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    final repo = DriftElvPhysicalCompatibilityRepository(db, originDeviceId: 'test', profileResolver: _Resolver(profile));
    await repo.createProfileSet(CreatePhysicalCompatibilityProfileSetCommand(commandId: 'set', projectId: 'p', profileSetId: 'ps-1', refs: [ref]));
    final service = ElvPhysicalCompatibilityService(repo);
    final findings = await service.evaluate(projectId: 'p', input: PhysicalCompatibilityInput(subjectIds: const ['run-1'], mediaCode: 'COPPER', cableTechnicalClassCodes: const [], carrierKind: 'CONDUIT', carrierUsableAreaMm2: 100, environmentCodes: const {}, pathwayKind: 'PROJECT_SHARED', profileRefs: const [], rules: const [], inputFingerprint: 'fp-1'));
    expect(findings, isNotEmpty);
    await repo.replaceFindings(projectId: 'p', designRevisionId: 'rev', profileSetId: 'ps-1', subjectKey: 'run-1', findings: findings);
    final reloaded = await repo.loadFindings(projectId: 'p', designRevisionId: 'rev', subjectKey: 'run-1');
    expect(reloaded.map((e) => e.code), findings.map((e) => e.code));
    expect(reloaded.every((e) => e.inputFingerprint == 'fp-1'), isTrue);
  });
}
''')
