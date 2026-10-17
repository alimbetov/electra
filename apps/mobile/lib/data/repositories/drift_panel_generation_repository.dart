import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/panel_generation_repository.dart';
import '../database/app_database.dart';
import 'drift_protection_repository.dart';
import 'drift_project_hierarchy_repository.dart';
import 'drift_dependency_recalculation_repository.dart';

class DriftPanelGenerationRepository implements PanelGenerationRepository {
  DriftPanelGenerationRepository(this.database, {required this.originDeviceId});
  final AppDatabase database;
  final String originDeviceId;
  @override
  Stream<ProjectPanelGenerationSnapshot> watch(String projectId) => database
      .customSelect(
        'SELECT id FROM projects WHERE id = ?',
        variables: [Variable.withString(projectId)],
        readsFrom: database.allTables.toSet(),
      )
      .watch()
      .asyncMap((_) => load(projectId));
  @override
  Future<ProjectPanelGenerationSnapshot> load(String projectId) =>
      database.transaction(() async {
        final protection = await DriftProtectionRepository(
          database,
          originDeviceId: originDeviceId,
        ).load(projectId);
        final floorRows =
            await (database.select(database.floors)
                  ..where(
                    (r) => r.projectId.equals(projectId) & r.deletedAt.isNull(),
                  )
                  ..orderBy([(r) => OrderingTerm.asc(r.id)]))
                .get();
        final floors = [
          for (final r in floorRows)
            (await DriftProjectHierarchyRepository(database).findFloor(r.id))!,
        ];
        final rows =
            await (database.select(database.panelGenerationConfigs)..where(
                  (r) => r.projectId.equals(projectId) & r.deletedAt.isNull(),
                ))
                .get();
        return ProjectPanelGenerationSnapshot(
          protection: protection,
          floors: floors,
          panels: [
            for (final r in rows)
              if (floors.any((f) => f.id == r.floorId))
                PanelGenerationView(
                  PanelGenerationPolicy.fromMap(
                    jsonDecode(r.payloadJson) as Map<String, dynamic>,
                  ),
                  r.reviewedFingerprint,
                ),
          ],
        );
      });
  @override
  Future<void> save(PanelGenerationPolicy policy) => database.transaction(
    () async {
      final errors = policy.validate();
      if (errors.isNotEmpty) throw ArgumentError(errors.join(' '));
      final snapshot = await load(policy.projectId);
      if (snapshot.protection.recalculation.project == null ||
          !snapshot.floors.any((f) => f.id == policy.floorId) ||
          !snapshot.protection.rulesets.any((r) => r.id == policy.rulesetId))
        throw StateError(
          'Active project, floor and project ruleset are required.',
        );
      final old = await (database.select(
        database.panelGenerationConfigs,
      )..where((r) => r.id.equals(policy.id))).getSingleOrNull();
      if (old != null &&
          (old.projectId != policy.projectId || old.floorId != policy.floorId))
        throw StateError('Panel identity cannot move between scopes.');
      final others = await (database.select(
        database.panelGenerationConfigs,
      )..where((r) => r.floorId.equals(policy.floorId))).get();
      if (others.any((r) => r.id != policy.id))
        throw StateError(
          'This baseline supports one generated panel per floor. Edit or restore its existing policy.',
        );
      final payload = canonicalEngineeringJson(policy.toMap());
      if (old?.payloadJson == payload && old?.deletedAt == null) return;
      final now = DateTime.now().toUtc();
      await database
          .into(database.panelGenerationConfigs)
          .insertOnConflictUpdate(
            PanelGenerationConfigsCompanion(
              id: Value(policy.id),
              projectId: Value(policy.projectId),
              floorId: Value(policy.floorId),
              payloadJson: Value(payload),
              reviewedFingerprint: const Value(null),
              revision: Value((old?.revision ?? 0) + 1),
              createdAt: Value(old?.createdAt ?? now),
              updatedAt: Value(now),
              deletedAt: const Value(null),
              originDeviceId: Value(originDeviceId),
            ),
          );
      await recalculate(policy.projectId);
    },
  );
  @override
  Future<void> recalculate(String projectId) async {
    await DriftDependencyRecalculationRepository(
      database,
      originDeviceId: originDeviceId,
    ).recalculate(projectId);
  }

  @override
  Future<void> confirm(
    String projectId,
    String panelId,
    String expectedFingerprint,
  ) => database.transaction(() async {
    final snapshot = await load(projectId),
        session = snapshot.protection.recalculation.session;
    final panel = snapshot.panels
        .where((p) => p.policy.id == panelId)
        .firstOrNull;
    if (panel == null ||
        session.fingerprints[panel.key] != expectedFingerprint ||
        session.affectedKeys.contains(panel.key) ||
        session.state(panel.key) != EngineeringDerivedState.current ||
        session.cache[panel.key]?.proposal.values['proposalState'] !=
            'proposed')
      throw StateError(
        'Recalculate and resolve inputs before confirming this exact proposal.',
      );
    final row = await (database.select(
      database.panelGenerationConfigs,
    )..where((r) => r.id.equals(panelId))).getSingle();
    await (database.update(
      database.panelGenerationConfigs,
    )..where((r) => r.id.equals(panelId))).write(
      PanelGenerationConfigsCompanion(
        reviewedFingerprint: Value(expectedFingerprint),
        revision: Value(row.revision + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
  });
  @override
  Future<void> archive(String projectId, String panelId) =>
      database.transaction(() async {
        final snapshot = await load(projectId);
        if (!snapshot.panels.any((p) => p.policy.id == panelId))
          throw StateError('Panel is unavailable.');
        final row = await (database.select(
          database.panelGenerationConfigs,
        )..where((r) => r.id.equals(panelId))).getSingle();
        final now = DateTime.now().toUtc();
        await (database.update(
          database.panelGenerationConfigs,
        )..where((r) => r.id.equals(panelId))).write(
          PanelGenerationConfigsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            revision: Value(row.revision + 1),
            originDeviceId: Value(originDeviceId),
          ),
        );
        await recalculate(projectId);
      });
}
