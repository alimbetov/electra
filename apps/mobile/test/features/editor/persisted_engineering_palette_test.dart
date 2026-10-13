import 'package:electra_mobile/app/providers.dart';
import 'package:electra_mobile/features/editor/persisted_room_editor_screen.dart';
import 'package:electra_mobile/features/editor/editor_interaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/application/project_hierarchy_service.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/database/drift_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/drift_geometry_repository.dart';
import 'package:electra_mobile/data/repositories/drift_project_hierarchy_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:convert';
import 'package:electra_mobile/data/repositories/drift_engineering_reference_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_system_repository.dart';
import 'package:electra_mobile/features/editor/room_editor_screen.dart';
import 'engineering_profile_palette_test.dart' show chooseCameraPreview;

void main() {
  testWidgets(
    'persisted editor P3 preview changes no SQLite rows or placement history',
    (tester) async {
      final fixture = await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'electra-elv2-p3-',
        );
        final file = File('${directory.path}/electra.sqlite');
        AppDatabase openDatabase() => AppDatabase(NativeDatabase(file));

        final database = openDatabase();
        final hierarchy = DriftProjectHierarchyRepository(database);
        final hierarchyService = ProjectHierarchyService(
          projects: hierarchy,
          floors: hierarchy,
          rooms: hierarchy,
          unitOfWork: DriftUnitOfWork(database),
          idGenerator: FixedSequenceIdGenerator(const [
            'project-components',
            'floor-components',
            'room-components',
          ]),
          originDeviceId: 'component-test-device',
          clock: () => DateTime.utc(2026, 10, 12, 15),
        );

        final project = await hierarchyService.createProject(
          const ProjectFormDraft(
            name: 'Components Project',
            reference: 'C-01',
            measurementSystem: MeasurementSystem.metric,
            defaultStructuralHeightMm: 3200,
            defaultFinishedCeilingHeightMm: 3000,
          ),
        );
        final floor = await hierarchyService.createFloor(
          projectId: project.id,
          draft: const FloorFormDraft(
            name: 'Floor 01',
            code: 'F01',
            sortOrder: 1,
          ),
        );
        final room = await hierarchyService.createRoom(
          floorId: floor.id,
          draft: const RoomFormDraft(
            name: 'Workshop',
            type: RoomType.workshop,
            category: RoomCategory.technical,
            widthMm: 6000,
            depthMm: 5000,
          ),
        );

        final patch = SurfacePatch(
          id: 'wall-components',
          roomId: room.id,
          surfaceId: 'Wall A',
          frame: LocalCoordinateFrame(
            origin: const Point3Mm(0, 0, 0),
            uAxis: const Vector3D(1, 0, 0),
            vAxis: const Vector3D(0, 0, 1),
          ),
          boundary: Polygon2Mm(const [
            Point2Mm(0, 0),
            Point2Mm(6000, 0),
            Point2Mm(6000, 3200),
            Point2Mm(0, 3200),
          ]),
          orientation: SurfaceOrientation.vertical,
        );
        final geometry = DriftGeometryRepository(
          database,
          originDeviceId: 'component-test-device',
          clock: () => DateTime.utc(2026, 10, 12, 16),
        );
        await geometry.replaceRoomGeometry(
          RoomGeometrySnapshot(roomId: room.id, patches: [patch]),
        );

        final references = DriftEngineeringReferenceRepository(
          database,
          originDeviceId: 'test',
          idGenerator: FixedSequenceIdGenerator([]),
        );
        final catalog = EngineeringReferenceCatalog.fromMap(
          jsonDecode(
                File(
                  '../../docs/examples/elv2-reference-catalog.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
        );
        await references.importCatalog(project.id, catalog);
        final networks = DriftEngineeringSystemRepository(
          database,
          originDeviceId: 'test',
        );
        final family = (await networks.load(
          project.id,
        )).families.singleWhere((f) => f.code == 'CCTV');
        await networks.saveSystem(
          EngineeringSystem(
            id: 'CCTV',
            projectId: project.id,
            code: 'CCTV',
            name: 'CCTV',
            familyId: family.id,
            familyVersion: family.version,
          ),
        );
        return (directory, database, project, floor, room, patch);
      });

      final (directory, database, project, floor, room, patch) = fixture!;
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<int> changes() async => (await database
              .customSelect('SELECT total_changes() AS count')
              .getSingle())
          .read<int>('count');
      final before = await changes();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            home: PersistedRoomEditorScreen(
              projectId: project.id,
              floorId: floor.id,
              roomId: room.id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RoomEditorScreen>(find.byType(RoomEditorScreen))
            .engineeringReferences,
        isNotNull,
      );
      await chooseCameraPreview(tester);
      final rect = tester.getRect(find.byType(InteractiveViewer));
      final transform = SurfaceViewportTransform(
        boundary: patch.boundary,
        viewportWidth: rect.width,
        viewportHeight: rect.height,
      );
      final p = transform.localToViewport(const Point2Mm(1500, 600));
      await tester.tapAt(rect.topLeft + Offset(p.x, p.y));
      await tester.pumpAndSettle();
      expect(find.text('UNRESOLVED'), findsWidgets);
      await tester.tap(find.text('Candidate conditions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to preview'));
      await tester.pumpAndSettle();
      expect(await changes(), before);
      expect(await database.select(database.componentInstances).get(), isEmpty);
      expect(
        await database.select(database.componentReferenceBindings).get(),
        isEmpty,
      );
      expect(
        await database.select(database.engineeringPortInstances).get(),
        isEmpty,
      );
      expect(
        await database.select(database.componentEngineeringMemberships).get(),
        isEmpty,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Undo placement',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Redo placement',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(await changes(), before);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
