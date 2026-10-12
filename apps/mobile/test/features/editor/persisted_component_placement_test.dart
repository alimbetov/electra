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
import 'package:electra_mobile/data/repositories/drift_component_instance_repository.dart';
import 'package:electra_mobile/data/repositories/drift_geometry_repository.dart';
import 'package:electra_mobile/data/repositories/drift_project_hierarchy_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'persisted catalog placement undo redo and preferences survive reopening',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp('electra-fl6-');
      final file = File('${directory.path}/electra.sqlite');
      AppDatabase openDatabase() => AppDatabase(NativeDatabase(file));

      var database = openDatabase();
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

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget application() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: PersistedRoomEditorScreen(
            projectId: project.id,
            floorId: floor.id,
            roomId: room.id,
          ),
        ),
      );
      await tester.pumpWidget(application());
      await tester.pumpAndSettle();
      await tester.tap(find.text('equipment'));
      await tester.pump();
      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add favorite').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Socket 230V'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(InteractiveViewer));
      final transform = SurfaceViewportTransform(
        boundary: patch.boundary,
        viewportWidth: rect.width,
        viewportHeight: rect.height,
      );
      final point = transform.localToViewport(const Point2Mm(1500, 600));
      await tester.tapAt(rect.topLeft + Offset(point.x, point.y));
      await tester.pumpAndSettle();
      final repository = DriftComponentInstanceRepository(
        database,
        originDeviceId: 'widget-test',
      );
      final placed = (await repository.loadRoomComponents(room.id)).single;
      expect(placed.localPosition, const Point2Mm(1500, 600));
      await tester.tap(find.byTooltip('Undo placement'));
      await tester.pumpAndSettle();
      expect(await repository.loadRoomComponents(room.id), isEmpty);
      await tester.tap(find.byTooltip('Redo placement'));
      await tester.pumpAndSettle();
      expect(
        (await repository.loadRoomComponents(room.id)).single.id,
        placed.id,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await database.close();
      database = openDatabase();
      await tester.pumpWidget(application());
      await tester.pumpAndSettle();
      final restored = await DriftComponentInstanceRepository(
        database,
        originDeviceId: 'widget-test',
      ).loadRoomComponents(room.id);
      expect(restored.single.id, placed.id);
      expect(restored.single.localPosition, placed.localPosition);
      // Preferences are reconstructed by the new editor/catalog instance.
      await tester.tap(find.text('equipment'));
      await tester.pump();
      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Socket 230V'), findsOneWidget);
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();
      expect(find.text('Socket 230V'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
