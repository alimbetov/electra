import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_pathway_command.dart';
import 'package:electra_mobile/application/elv_physical_carrier_command.dart';
import 'package:electra_mobile/application/elv_failure_probe.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_pathway_repository.dart';
import 'package:electra_mobile/data/repositories/drift_elv_physical_carrier_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _seedProject(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 14);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'p',
          name: 'P4',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
}

final class _ThrowProbe implements ElvFailureProbe {
  const _ThrowProbe(this.point);
  final String point;
  @override
  Future<void> hit(String actual) async {
    if (actual == point) throw StateError('probe:$actual');
  }
}

void main() {
  test('schema 21 exposes P4 pathway/carrier persistence roots', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 21);
    final names =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type='table'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toSet();
    expect(
      names,
      containsAll({
        'pathway_contexts',
        'physical_carriers',
        'physical_carrier_compartments',
        'traversal_carrier_assignments',
      }),
    );
  });

  test('pathway and carrier round-trip through SQLite', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final pathwayRepo = DriftElvPathwayRepository(db, originDeviceId: 'test');
    const context = PathwayContext(
      id: 'path-1',
      projectId: 'p',
      kind: PathwayContextKind.projectShared,
      host: ProjectHost('p'),
      lifecycleState: PathwayContextLifecycleState.active,
      revision: 1,
    );
    final createdPath = await pathwayRepo.create(
      const CreatePathwayContextCommand(
        commandId: 'path-cmd',
        context: context,
      ),
    );
    expect(createdPath, isA<ElvCommandSuccess<PathwayContext>>());
    final carrierRepo = DriftElvPhysicalCarrierRepository(
      db,
      originDeviceId: 'test',
    );
    const carrier = PhysicalCarrier(
      id: 'carrier-1',
      projectId: 'p',
      pathwayContextId: 'path-1',
      code: 'TRAY-01',
      name: 'Main tray',
      kind: PhysicalCarrierKind.tray,
      crossSection: RectangularCarrierCrossSection(widthMm: 200, heightMm: 50),
      environmentFacts: CarrierEnvironmentFacts(
        exposure: CarrierEnclosureExposure.indoor,
      ),
      installationFacts: CarrierInstallationFacts(
        accessibility: MaintenanceAccessibility.accessible,
      ),
      lifecycleState: PhysicalCarrierLifecycleState.active,
      revision: 1,
    );
    final createdCarrier = await carrierRepo.create(
      const CreatePhysicalCarrierCommand(
        commandId: 'carrier-cmd',
        carrier: carrier,
      ),
    );
    expect(createdCarrier, isA<ElvCommandSuccess<PhysicalCarrier>>());
    final reloaded = await carrierRepo.loadCarriers('p');
    expect(reloaded.single.normalizedCode, 'TRAY-01');
    expect(reloaded.single.crossSection.usableAreaMm2, 10000);
  });

  test('pathway hierarchy cycle is rejected before persistence', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final repo = DriftElvPathwayRepository(db, originDeviceId: 'test');
    const a = PathwayContext(
      id: 'a',
      projectId: 'p',
      kind: PathwayContextKind.projectShared,
      host: ProjectHost('p'),
      parentContextId: 'b',
      lifecycleState: PathwayContextLifecycleState.active,
      revision: 1,
    );
    final result = await repo.create(
      const CreatePathwayContextCommand(commandId: 'a', context: a),
    );
    expect(result, isA<ElvCommandFailureResult<PathwayContext>>());
    expect(await repo.loadContexts('p'), isEmpty);
  });

  test(
    'P4 attach failure probe rolls back traversal carrier assignment',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedProject(db);
      final pathwayRepo = DriftElvPathwayRepository(db, originDeviceId: 'test');
      await pathwayRepo.create(
        const CreatePathwayContextCommand(
          commandId: 'pc',
          context: PathwayContext(
            id: 'path-1',
            projectId: 'p',
            kind: PathwayContextKind.projectShared,
            host: ProjectHost('p'),
            lifecycleState: PathwayContextLifecycleState.active,
            revision: 1,
          ),
        ),
      );
      final carrierRepo = DriftElvPhysicalCarrierRepository(
        db,
        originDeviceId: 'test',
      );
      await carrierRepo.create(
        const CreatePhysicalCarrierCommand(
          commandId: 'cc',
          carrier: PhysicalCarrier(
            id: 'carrier-1',
            projectId: 'p',
            pathwayContextId: 'path-1',
            code: 'T1',
            name: 'Tray',
            kind: PhysicalCarrierKind.tray,
            crossSection: RectangularCarrierCrossSection(
              widthMm: 100,
              heightMm: 50,
            ),
            environmentFacts: CarrierEnvironmentFacts(),
            installationFacts: CarrierInstallationFacts(),
            lifecycleState: PhysicalCarrierLifecycleState.active,
            revision: 1,
          ),
        ),
      );
      final now = DateTime.utc(2026, 10, 14);
      await db
          .into(db.projectDesignRevisions)
          .insert(
            ProjectDesignRevisionsCompanion.insert(
              id: 'rev',
              projectId: 'p',
              code: 'R1',
              sequence: 1,
              state: 'WORKING',
              revision: const Value(1),
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'test',
            ),
          );
      // P4 rollback is verified at the SQLite transaction boundary with a minimal P3 run/traversal chain.
      await db.customStatement("PRAGMA foreign_keys = OFF");
      await db
          .into(db.canonicalCableRuns)
          .insert(
            CanonicalCableRunsCompanion.insert(
              id: 'run',
              projectId: 'p',
              cableId: 'cable-fixture',
              designRevisionId: 'rev',
              lifecycleState: 'ACTIVE',
              revision: const Value(1),
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'test',
            ),
          );
      await db
          .into(db.cableRunTraversals)
          .insert(
            CableRunTraversalsCompanion.insert(
              id: 'tr',
              cableRunId: 'run',
              sequence: 1,
              routeSegmentId: 'segment-fixture',
              direction: 'FORWARD',
              revision: const Value(1),
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'test',
            ),
          );
      await db.customStatement("PRAGMA foreign_keys = ON");
      final failingRepo = DriftElvPhysicalCarrierRepository(
        db,
        originDeviceId: 'test',
        failureProbe: const _ThrowProbe(
          ElvFailurePoints.p4AttachCarrierAfterTraversalUpdate,
        ),
      );
      await expectLater(
        () => failingRepo.attachTraversal(
          const AttachTraversalToCarrierCommand(
            commandId: 'attach',
            projectId: 'p',
            cableRunId: 'run',
            traversalId: 'tr',
            carrierId: 'carrier-1',
            expectedCableRunRevision: 1,
          ),
        ),
        throwsStateError,
      );
      final traversal = await db.select(db.cableRunTraversals).getSingle();
      expect(traversal.physicalCarrierId, isNull);
      expect(await db.select(db.traversalCarrierAssignments).get(), isEmpty);
    },
  );
}
