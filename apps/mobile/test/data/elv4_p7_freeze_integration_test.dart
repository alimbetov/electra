import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_design_revision_repository.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P7 freeze captures committed power pointer section and manifest', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 10, 15, 14);
    await db.into(db.projects).insert(
          ProjectsCompanion.insert(
            id: 'project',
            name: 'P7 freeze',
            measurementSystem: 'metric',
            defaultStructuralHeightMm: 3000,
            defaultFinishedCeilingHeightMm: 2700,
            createdAt: now,
            updatedAt: now,
            originDeviceId: 'test',
          ),
        );
    final repo = DriftElvDesignRevisionRepository(
      db,
      originDeviceId: 'test',
      now: () => now,
    );
    final bootstrap = await repo.bootstrap(
      const BootstrapProjectDesignRevisionCommand(
        commandId: 'bootstrap',
        projectId: 'project',
        revisionId: 'REV-1',
        code: 'R1',
      ),
    );
    expect(bootstrap, isA<ElvCommandSuccess<ProjectDesignRevision>>());

    final frozen = await repo.freeze(
      const FreezeProjectDesignRevisionCommand(
        commandId: 'freeze',
        projectId: 'project',
        designRevisionId: 'REV-1',
        expectedRevision: 1,
      ),
    );
    expect(frozen, isA<ElvCommandSuccess<ProjectDesignRevision>>());

    final physical = await db.select(db.designRevisionPhysicalSnapshots).getSingle();
    final power = await db.select(db.designRevisionPowerSnapshots).getSingle();
    final manifest = await db.select(db.designRevisionSnapshotManifests).getSingle();
    expect(power.physicalSha256, physical.payloadSha256);
    expect(manifest.physicalSha256, physical.payloadSha256);
    expect(manifest.powerSha256, power.powerSha256);

    final read = await DriftPowerPublicationRuntime(
      db,
      originDeviceId: 'test',
      now: () => now,
    ).readRevision(projectId: 'project', designRevisionId: 'REV-1');
    expect(read.kind, PowerRevisionReadKind.capturedEmpty);
    expect(read.mutationAllowed, isFalse);
    expect(read.reasonCode, null);
  });
}
