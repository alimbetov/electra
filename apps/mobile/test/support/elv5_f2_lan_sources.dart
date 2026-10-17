import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:electra_mobile/application/elv5/lan/elv5_lan_mutation_service.dart';
import 'package:electra_mobile/application/elv5/lan/elv5_lan_rack_mutation_service.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_lan_write_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_lan_rack_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core.dart';
import 'elv5_f2_fire_sources.dart';
import 'elv5_f2_production_lifecycle.dart';

Future<void> seedF2LanTopology(AppDatabase db) async {
  await seedF2FireTopology(db);
  final catalog = EngineeringReferenceCatalog.fromMap(
    Map<String, Object?>.from(
      jsonDecode(
            File(
              '../../docs/examples/elv2-interface-catalog.json',
            ).readAsStringSync(),
          )
          as Map,
    ),
  );
  for (final e
      in {
        'switch-1': 'LAN_SWITCH',
        'pse-1': 'POE_SWITCH',
        'patch-panel-1': 'PATCH',
        'rack-1': 'PATCH',
        'eq-1': 'LAN_SWITCH',
        'eq-2': 'PATCH',
        'endpoint-1': 'OUTLET',
        'endpoint-2': 'OUTLET',
      }.entries) {
    await seedF2FireComponent(db, e.key);
    final profile = catalog.profile(e.value);
    await db
        .into(db.componentReferenceBindings)
        .insert(
          ComponentReferenceBindingsCompanion.insert(
            componentId: e.key,
            projectId: 'p',
            catalogId: catalog.id,
            profileCode: e.value,
            payloadJson: canonicalEngineeringJsonV1(profile.toMap()),
            createdAt: Elv5F2ProductionLifecycle.now(),
            updatedAt: Elv5F2ProductionLifecycle.now(),
            originDeviceId: 'f2-lan',
          ),
        );
    final count =
        e.key == 'switch-1'
            ? 3
            : e.key == 'pse-1'
            ? 2
            : e.key == 'patch-panel-1'
            ? 8
            : 0;
    for (var i = 1; i <= count; i++) {
      final port = EngineeringPort.fromMap({
        ...profile.portTemplates.first.toMap(),
        'id': '${e.key}-p$i',
        'componentId': e.key,
        'code': 'P$i',
      });
      await db
          .into(db.engineeringPortInstances)
          .insert(
            EngineeringPortInstancesCompanion.insert(
              id: port.id,
              projectId: 'p',
              componentId: e.key,
              code: port.code,
              payloadJson: canonicalEngineeringJsonV1(port.toMap()),
              createdAt: Elv5F2ProductionLifecycle.now(),
              updatedAt: Elv5F2ProductionLifecycle.now(),
              originDeviceId: 'f2-lan',
            ),
          );
    }
  }
}

Future<void> replaceF2LanAggregate(
  AppDatabase db, {
  required String operation,
  required Map<String, Object?> payload,
  required String commandId,
}) async {
  final service = Elv5LanMutationService(
    unitOfWork: DriftElv5LanWriteUnitOfWork(db, originDeviceId: 'f2-lan'),
    originDeviceId: 'f2-lan',
    now: Elv5F2ProductionLifecycle.now,
  );
  final preview = await service.preview(
    projectId: 'p',
    designRevisionId: 'd',
    operation: operation,
    payload: payload,
  );
  await service.execute(
    Elv5WireCommandEnvelope(
      operation: operation,
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

Future<void> replaceF2LanRack(
  AppDatabase db,
  Map<String, Object?> payload,
  String commandId,
) async {
  final service = Elv5LanRackMutationService(
    unitOfWork: DriftElv5LanRackWriteUnitOfWork(db, originDeviceId: 'f2-lan'),
    originDeviceId: 'f2-lan',
    now: Elv5F2ProductionLifecycle.now,
  );
  final preview = await service.preview(
    projectId: 'p',
    designRevisionId: 'd',
    payload: payload,
  );
  await service.execute(
    Elv5WireCommandEnvelope(
      operation: 'REPLACE_RACK_CAPACITY_BASIS',
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

Future<Map<String, Object?>> loadF2LanAggregate(
  AppDatabase db,
  String operation,
  String subjectId,
) async {
  if (operation == 'REPLACE_RACK_CAPACITY_BASIS') {
    final rack = await DriftElv5LanRackWriteUnitOfWork(
      db,
      originDeviceId: 'f2-lan',
    ).run(
      (s) => s.racks.loadRack(
        projectId: 'p',
        designRevisionId: 'd',
        rackId: subjectId,
      ),
    );
    if (rack == null) throw StateError('Production rack source missing');
    return rack.payload;
  }
  final value = await DriftElv5LanWriteUnitOfWork(
    db,
    originDeviceId: 'f2-lan',
  ).run(
    (s) => s.lan.load(
      projectId: 'p',
      designRevisionId: 'd',
      operation: operation,
      subjectId: subjectId,
    ),
  );
  if (value == null) throw StateError('Production LAN source missing');
  return value.payload;
}

String f2LanHash(String c) => List.filled(64, c).join();
Map<String, Object?> f2Lan02Payload({String requiredSpeedBps = '1000000000'}) =>
    <String, Object?>{
      'switchId': 'switch-1',
      'assignments': <Object?>[
        <String, Object?>{
          'portId': 'switch-1-p1',
          'endpointId': 'endpoint-1',
          'media': 'COPPER',
          'speedBps': '1000000000',
        },
        <String, Object?>{
          'portId': 'switch-1-p2',
          'endpointId': 'endpoint-2',
          'media': 'COPPER',
          'speedBps': requiredSpeedBps,
        },
      ],
      'sparePolicyRef': <String, Object?>{
        'policyCode': 'LAN-PORT-SPARE',
        'editionId': 'spare-v1',
        'contentHash': f2LanHash('b'),
      },
    };

Map<String, Object?> f2Lan04Payload() => <String, Object?>{
  'linkId': 'link-1',
  'orderedSections': <Object?>[
    <String, Object?>{
      'ordinal': 0,
      'realizedSectionId': 'section-1',
      'classification': 'PERMANENT',
    },
    <String, Object?>{
      'ordinal': 1,
      'realizedSectionId': 'section-2',
      'classification': 'PERMANENT',
    },
  ],
  'policyBindingId': 'policy-link-1',
};

Map<String, Object?> f2Lan06Payload({
  required String capacityBasis,
  String reservedRu = '0',
  String unavailableRu = '0',
}) => <String, Object?>{
  'rackId': 'rack-1',
  'capacityBasis': capacityBasis,
  'equipmentIds': <String>['eq-1', 'eq-2'],
  'excludedCapacity': <String, Object?>{
    'reservedRu': reservedRu,
    'unavailableRu': unavailableRu,
    'provenance': 'rack-definition-v1',
  },
  'policyRef': <String, Object?>{
    'policyCode': 'RACK_CAPACITY_POLICY',
    'editionId': 'rack-policy-v1',
    'contentHash': f2LanHash('d'),
  },
};

List<Map<String, Object?>> f2Lan07Assignments(int count) =>
    <Map<String, Object?>>[
      for (var i = 1; i <= count; i++)
        <String, Object?>{
          'panelPortId': 'patch-panel-1-p$i',
          'terminationId': 'term-$i',
          'linkId': 'link-$i',
        },
    ];

Map<String, Object?> f2Lan07Payload(List<Map<String, Object?>> assignments) =>
    <String, Object?>{
      'panelId': 'patch-panel-1',
      'assignments': assignments,
      'sparePolicyRef': <String, Object?>{
        'policyCode': 'PATCH_SPARE_POLICY',
        'editionId': 'patch-policy-v1',
        'contentHash': f2LanHash('d'),
      },
    };

Future<void> seedF2LanRoute(AppDatabase db) async {
  final now = Elv5F2ProductionLifecycle.now();
  await db.customStatement(
    "INSERT INTO cable_routes (id,room_id,name,revision,created_at,updated_at,deleted_at,origin_device_id) VALUES ('route-1','room-1','Fire route',1,'${now.millisecondsSinceEpoch ~/ 1000}','${now.millisecondsSinceEpoch ~/ 1000}',NULL,'f2-fa08-production')",
  );
  for (final entry in {'node-a': 0, 'node-b': 1000}.entries) {
    await db
        .into(db.cableRouteNodes)
        .insert(
          CableRouteNodesCompanion.insert(
            id: entry.key,
            routeId: 'route-1',
            sequence: entry.value == 0 ? 1 : 2,
            kind: 'WAYPOINT',
            patchId: 'patch-x',
            localXmm: entry.value,
            localYmm: 0,
            worldXmm: entry.value,
            worldYmm: 0,
            worldZmm: 0,
            createdAt: now,
            updatedAt: now,
            originDeviceId: 'f2-fa08-production',
          ),
        );
  }
  await db.customStatement(
    "INSERT INTO cable_route_segments (id,route_id,sequence,from_node_id,to_node_id,surface_patch_id,laying_method,physical_channel_id,revision,created_at,updated_at,deleted_at,origin_device_id) VALUES ('section-1','route-1',1,'node-a','node-b','patch-x','TRAY',NULL,1,'${now.millisecondsSinceEpoch ~/ 1000}','${now.millisecondsSinceEpoch ~/ 1000}',NULL,'f2-fa08-production')",
  );

  final definition = CableDefinition(
    code: 'LAN-CABLE',
    label: 'Fictional LAN cable',
    mediaCode: 'COPPER',
    resourceDefinitions: [
      CableResourceDefinition(
        identity: '__WHOLE_CABLE__',
        kind: CableResourceKind.wholeCable,
        allocatable: true,
        atomic: true,
        terminationPolicy: TerminationPolicy(
          mode: TerminationPolicyMode.bothEnds,
          terminalRequired: true,
        ),
      ),
    ],
  );
  final catalog = EngineeringReferenceCatalog(
    id: 'catalog-lan-cables',
    code: 'LAN-CABLES',
    version: '1',
    source: 'F2 explicit routing fixture',
    cableDefinitions: [definition],
  );
  final definitionRef = catalog.cableDefinitionRef('LAN-CABLE');
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
          originDeviceId: 'f2-lan',
        ),
      );
  await db
      .into(db.elvCables)
      .insert(
        ElvCablesCompanion.insert(
          id: 'cable-1',
          projectId: 'p',
          label: 'FC-1',
          normalizedLabel: 'FC-1',
          name: 'Fire cable',
          definitionCatalogId: definitionRef.catalogId,
          definitionCatalogVersion: definitionRef.catalogVersion,
          definitionCode: definitionRef.definitionCode,
          definitionContentHash: definitionRef.definitionContentHash,
          lifecycleState: 'ACTIVE',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
  await db
      .into(db.canonicalCableRuns)
      .insert(
        CanonicalCableRunsCompanion.insert(
          id: 'run-1',
          projectId: 'p',
          cableId: 'cable-1',
          designRevisionId: 'd',
          lifecycleState: 'ACTIVE',
          reservePercent: const Value(0),
          terminationAllowanceMm: const Value(0),
          revision: const Value(1),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
  await db
      .into(db.cableRunTraversals)
      .insert(
        CableRunTraversalsCompanion.insert(
          id: 'traversal-1',
          cableRunId: 'run-1',
          sequence: 1,
          routeSegmentId: 'section-1',
          direction: 'FORWARD',
          revision: const Value(1),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
}
