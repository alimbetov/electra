import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:electra_mobile/application/elv5/fire/elv5_fire_mutation_service.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_fire_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core.dart';

Future<void> seedF2FireTopology(
  AppDatabase db, {
  bool notificationDevices = false,
}) async {
  final now = DateTime.utc(2026, 10, 17, 12);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'p',
          name: 'F2 FA-08 production qualification',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
  await db
      .into(db.projectDesignRevisions)
      .insert(
        ProjectDesignRevisionsCompanion.insert(
          id: 'd',
          projectId: 'p',
          code: 'R1',
          sequence: 1,
          state: 'WORKING',
          revision: const Value(1),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
  await db
      .into(db.floors)
      .insert(
        FloorsCompanion.insert(
          id: 'floor-x',
          projectId: 'p',
          name: 'Qualification floor',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
  await db.customStatement(
    "INSERT INTO rooms (id,floor_id,name,room_type,room_category,width_mm,depth_mm,structural_height_mm_override,finished_ceiling_height_mm_override,revision,created_at,updated_at,deleted_at,origin_device_id) VALUES ('room-1','floor-x','Electrical room','technical','technical',4000,4000,NULL,NULL,1,'${now.millisecondsSinceEpoch ~/ 1000}','${now.millisecondsSinceEpoch ~/ 1000}',NULL,'f2-fa08-production')",
  );
  await db
      .into(db.surfacePatches)
      .insert(
        SurfacePatchesCompanion.insert(
          id: 'patch-x',
          roomId: 'room-1',
          surfaceId: 'floor',
          originXmm: 0,
          originYmm: 0,
          originZmm: 0,
          uAxisX: 1,
          uAxisY: 0,
          uAxisZ: 0,
          vAxisX: 0,
          vAxisY: 1,
          vAxisZ: 0,
          orientation: 'horizontal',
          boundaryJson: '[[0,0],[4000,0],[4000,4000],[0,4000]]',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );

  final catalogMap = Map<String, Object?>.from(
    jsonDecode(
          File(
            '../../docs/examples/elv2-interface-catalog.json',
          ).readAsStringSync(),
        )
        as Map,
  );
  if (notificationDevices) {
    final profiles =
        (catalogMap['profiles'] as List)
            .map((v) => Map<String, Object?>.from(v as Map))
            .toList();
    final template = profiles.singleWhere((v) => v['code'] == 'DETECTOR');
    profiles.add({
      ...template,
      'code': 'SOUNDER',
      'label': 'Fictional addressed notification module',
      'engineeringClass': 'loopModule',
    });
    catalogMap['profiles'] = profiles;
  }
  final catalog = EngineeringReferenceCatalog.fromMap(catalogMap);
  await db
      .into(db.engineeringReferenceCatalogs)
      .insert(
        EngineeringReferenceCatalogsCompanion.insert(
          id: catalog.id,
          projectId: 'p',
          code: catalog.code,
          catalogVersion: catalog.version,
          payloadJson: canonicalEngineeringJsonV1(catalog.toMap()),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fire',
        ),
      );
  for (final entry
      in {
        'panel-1': 'FACP',
        'd1': notificationDevices ? 'SOUNDER' : 'DETECTOR',
        'd2': notificationDevices ? 'SOUNDER' : 'DETECTOR',
        'd3': notificationDevices ? 'SOUNDER' : 'DETECTOR',
      }.entries) {
    final profile = catalog.profile(entry.value);
    await db
        .into(db.componentInstances)
        .insert(
          ComponentInstancesCompanion.insert(
            id: entry.key,
            definitionId: 'fictional-${entry.value}',
            definitionVersion: 1,
            roomId: 'room-1',
            hostSurfacePatchId: 'patch-x',
            localXmm: 0,
            localYmm: 0,
            createdAt: now,
            updatedAt: now,
            originDeviceId: 'f2-fire',
          ),
        );
    await db
        .into(db.componentReferenceBindings)
        .insert(
          ComponentReferenceBindingsCompanion.insert(
            componentId: entry.key,
            projectId: 'p',
            catalogId: catalog.id,
            profileCode: entry.value,
            payloadJson: canonicalEngineeringJsonV1(profile.toMap()),
            createdAt: now,
            updatedAt: now,
            originDeviceId: 'f2-fire',
          ),
        );
  }
}

Future<void> replaceF2FireLoop(
  AppDatabase db, {
  int deviceCount = 2,
  String commandId = 'seed-loop',
}) async {
  final service = Elv5FireMutationService(
    unitOfWork: DriftElv5FireWriteUnitOfWork(db, originDeviceId: 'f2-fire'),
    originDeviceId: 'f2-fire',
    now: () => DateTime.utc(2026, 10, 17, 15),
  );
  final payload = <String, Object?>{
    'loopId': 'loop-1',
    'topologyProfileRef': {
      'profileCode': 'CLASS-A',
      'editionId': 'v1',
      'contentHash': List.filled(64, 'a').join(),
    },
    'addressDomain': {
      'panelId': 'panel-1',
      'loopId': 'loop-1',
      'minAddress': 1,
      'maxAddress': 10,
      'reservedAddresses': <int>[],
    },
    'deviceAssignments': [
      for (var i = 1; i <= deviceCount; i++)
        {
          'deviceId': 'd$i',
          'profileRef': 'DETECTOR',
          'expandedAddresses': [i],
        },
    ],
  };
  final preview = await service.preview(
    projectId: 'p',
    designRevisionId: 'd',
    operation: 'REPLACE_FIRE_LOOP_ASSIGNMENTS',
    payload: payload,
  );
  await service.execute(
    Elv5WireCommandEnvelope(
      operation: 'REPLACE_FIRE_LOOP_ASSIGNMENTS',
      projectId: 'p',
      designRevisionId: 'd',
      commandId: commandId,
      expectedDesignRowRevision: preview.designRowRevision,
      expectedRows: preview.expectedRows,
      reviewedImpactFingerprint: preview.reviewedImpactFingerprint,
      payload: payload,
    ),
  );
}
