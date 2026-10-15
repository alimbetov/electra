import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/protection_repository.dart';
import '../database/app_database.dart';
import 'drift_dependency_recalculation_repository.dart';
import 'drift_project_hierarchy_repository.dart';

class DriftProtectionRepository implements ProtectionRepository {
  DriftProtectionRepository(this.database, {required this.originDeviceId});
  final AppDatabase database;
  final String originDeviceId;
  DriftDependencyRecalculationRepository get engine =>
      DriftDependencyRecalculationRepository(
        database,
        originDeviceId: originDeviceId,
      );
  @override
  Stream<ProjectProtectionSnapshot> watch(String projectId) => database
      .customSelect(
        'SELECT id, revision FROM projects WHERE id = ?',
        variables: [Variable.withString(projectId)],
        readsFrom: database.allTables.toSet(),
      )
      .watch()
      .asyncMap((_) => load(projectId));
  @override
  Future<ProjectProtectionSnapshot> load(String projectId) =>
      database.transaction(() async {
        final recalc = await engine.load(projectId);
        final normRows =
            await (database.select(database.normativeDocuments)
                  ..where((r) => r.deletedAt.isNull())
                  ..orderBy([
                    (r) => OrderingTerm.asc(r.standardCode),
                    (r) => OrderingTerm.asc(r.version),
                  ]))
                .get();
        final rules =
            await (database.select(database.protectionRulesets)
                  ..where(
                    (r) => r.projectId.equals(projectId) & r.deletedAt.isNull(),
                  )
                  ..orderBy([
                    (r) => OrderingTerm.asc(r.ruleId),
                    (r) => OrderingTerm.asc(r.version),
                  ]))
                .get();
        final ids =
            recalc.session.nodes.keys
                .where((k) => k.startsWith('circuit:'))
                .map((k) => k.substring(8))
                .toList();
        final rows =
            await (database.select(database.circuitProtectionSettings)..where(
              (r) => r.circuitId.isIn(ids) & r.deletedAt.isNull(),
            )).get();
        return ProjectProtectionSnapshot(
          recalculation: recalc,
          documents: normRows
              .map(
                (r) => NormativeDocument.fromMap(
                  jsonDecode(r.payloadJson) as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
          rulesets: rules
              .map(
                (r) => ProtectionRuleset.fromMap(
                  jsonDecode(r.payloadJson) as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
          circuits: [
            for (final id in ids)
              CircuitProtectionView(
                circuitId: id,
                label: recalc.session.nodes['circuit:$id']!.label,
                settings:
                    rows.any((r) => r.circuitId == id)
                        ? CircuitProtectionInputs.fromMap(
                          jsonDecode(
                                rows
                                    .firstWhere((r) => r.circuitId == id)
                                    .inputsJson,
                              )
                              as Map<String, dynamic>,
                        )
                        : CircuitProtectionInputs(circuitId: id),
                reviewedFingerprint:
                    rows
                        .where((r) => r.circuitId == id)
                        .firstOrNull
                        ?.reviewedFingerprint,
                fingerprint: recalc.session.fingerprints['protection:$id']!,
                checkpoint: recalc.session.cache['protection:$id'],
              ),
          ],
        );
      });
  @override
  Future<void> saveDocument(
    NormativeDocument doc,
  ) => database.transaction(() async {
    if (doc.validate().isNotEmpty)
      throw ArgumentError(doc.validate().join(' '));
    final old =
        await (database.select(database.normativeDocuments)
          ..where((r) => r.id.equals(doc.id))).getSingleOrNull();
    final payload = canonicalEngineeringJson(doc.toMap());
    if (old != null) {
      if (canonicalEngineeringJson(jsonDecode(old.payloadJson)) != payload)
        throw StateError(
          'Document editions are immutable. Create a new edition or catalog revision.',
        );
      return;
    }
    final duplicate =
        await (database.select(database.normativeDocuments)..where(
          (r) =>
              r.standardCode.equals(doc.standardCode) &
              r.version.equals(doc.version) &
              r.jurisdiction.equals(doc.jurisdiction),
        )).getSingleOrNull();
    if (duplicate != null)
      throw StateError('This document edition is already in the catalog.');
    final now = DateTime.now().toUtc();
    await database
        .into(database.normativeDocuments)
        .insert(
          NormativeDocumentsCompanion.insert(
            id: doc.id,
            standardCode: doc.standardCode,
            version: doc.version,
            jurisdiction: doc.jurisdiction,
            payloadJson: payload,
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
        );
  });
  @override
  Future<void> saveRuleset(
    ProtectionRuleset rule,
  ) => database.transaction(() async {
    if (rule.validate().isNotEmpty)
      throw ArgumentError(rule.validate().join(' '));
    final project = await DriftProjectHierarchyRepository(
      database,
    ).findProject(rule.projectId);
    if (project == null) throw StateError('Project is unavailable.');
    final docRow =
        await (database.select(database.normativeDocuments)..where(
          (r) => r.id.equals(rule.normativeDocumentId) & r.deletedAt.isNull(),
        )).getSingleOrNull();
    if (docRow == null) throw StateError('Choose an active catalog document.');
    final doc = NormativeDocument.fromMap(
      jsonDecode(docRow.payloadJson) as Map<String, dynamic>,
    );
    if (rule.reference.standardCode != doc.standardCode ||
        rule.reference.jurisdiction != doc.jurisdiction ||
        rule.reference.sourceReference != doc.source)
      throw StateError(
        'Ruleset reference must match the selected catalog document.',
      );
    final old =
        await (database.select(database.protectionRulesets)
          ..where((r) => r.id.equals(rule.id))).getSingleOrNull();
    final payload = canonicalEngineeringJson(rule.toMap());
    if (old != null) {
      if (canonicalEngineeringJson(jsonDecode(old.payloadJson)) != payload)
        throw StateError(
          'Ruleset versions are immutable. Create a new version.',
        );
      return;
    }
    final duplicate =
        await (database.select(database.protectionRulesets)..where(
          (r) =>
              r.projectId.equals(rule.projectId) &
              r.ruleId.equals(rule.reference.id) &
              r.version.equals(rule.reference.version),
        )).getSingleOrNull();
    if (duplicate != null) throw StateError('Ruleset version already exists.');
    final now = DateTime.now().toUtc();
    await database
        .into(database.protectionRulesets)
        .insert(
          ProtectionRulesetsCompanion.insert(
            id: rule.id,
            projectId: rule.projectId,
            normativeDocumentId: rule.normativeDocumentId,
            ruleId: rule.reference.id,
            version: rule.reference.version,
            payloadJson: payload,
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
        );
  });
  @override
  Future<void> saveSettings(
    String projectId,
    CircuitProtectionInputs settings,
  ) => database.transaction(() async {
    if (settings.validate().isNotEmpty)
      throw ArgumentError(settings.validate().join(' '));
    final snapshot = await load(projectId);
    if (snapshot.recalculation.project == null ||
        !snapshot.circuits.any((c) => c.circuitId == settings.circuitId))
      throw StateError('Circuit must be active in this project.');
    if (settings.rulesetId != null &&
        !snapshot.rulesets.any((r) => r.id == settings.rulesetId))
      throw StateError('Ruleset must belong to this project.');
    final old =
        await (database.select(database.circuitProtectionSettings)..where(
          (r) => r.circuitId.equals(settings.circuitId),
        )).getSingleOrNull();
    final payload = canonicalEngineeringJson(settings.toMap());
    if (old != null &&
        old.deletedAt == null &&
        canonicalEngineeringJson(jsonDecode(old.inputsJson)) == payload)
      return;
    final now = DateTime.now().toUtc();
    await database
        .into(database.circuitProtectionSettings)
        .insertOnConflictUpdate(
          CircuitProtectionSettingsCompanion(
            circuitId: Value(settings.circuitId),
            rulesetId: Value(settings.rulesetId),
            inputsJson: Value(payload),
            reviewedFingerprint: Value(old?.reviewedFingerprint),
            revision: Value((old?.revision ?? 0) + 1),
            createdAt: Value(old?.createdAt ?? now),
            updatedAt: Value(now),
            deletedAt: const Value(null),
            originDeviceId: Value(originDeviceId),
          ),
        );
    await engine.recalculate(projectId);
  });
  @override
  Future<void> confirm(
    String projectId,
    String circuitId,
    String expectedFingerprint,
  ) => database.transaction(() async {
    final snapshot = await load(projectId);
    final item =
        snapshot.circuits.where((c) => c.circuitId == circuitId).firstOrNull;
    if (item == null ||
        item.fingerprint != expectedFingerprint ||
        item.stale ||
        item.checkpoint?.proposal.values['proposalState'] != 'proposed' ||
        snapshot.recalculation.session.state('protection:$circuitId') !=
            EngineeringDerivedState.current) {
      throw StateError(
        'Recalculate current inputs and resolve all issues before confirming the functional requirement.',
      );
    }
    final row =
        await (database.select(database.circuitProtectionSettings)
          ..where((r) => r.circuitId.equals(circuitId))).getSingle();
    await (database.update(database.circuitProtectionSettings)
      ..where((r) => r.circuitId.equals(circuitId))).write(
      CircuitProtectionSettingsCompanion(
        reviewedFingerprint: Value(expectedFingerprint),
        revision: Value(row.revision + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
  });
  @override
  Future<void> recalculate(String projectId) async {
    await engine.recalculate(projectId);
  }
}
