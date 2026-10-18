import 'dart:convert';
import 'dart:io';
import 'package:electra_mobile/application/elv5/acs/elv5_acs_mutation_service.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_acs_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core.dart';
import 'elv5_f2_fire_sources.dart';
import 'elv5_f2_production_lifecycle.dart';

const f2AcsRoleByComponent = <String, String>{
  'reader': 'READER_ENTRY',
  'rte': 'REQUEST_TO_EXIT',
  'fire': 'FIRE_RELEASE_INPUT',
  'breakglass': 'EMERGENCY_RELEASE',
  'contact': 'DOOR_CONTACT',
  'lock': 'LOCK',
};
Future<void> seedF2AcsTopology(AppDatabase db) async {
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
  for (final entry
      in {
        'reader': 'READER',
        'rte': 'CONTROLLER',
        'fire': 'CONTROLLER',
        'breakglass': 'CONTROLLER',
        'contact': 'CONTROLLER',
        'lock': 'LOCK',
        'controller-1': 'CONTROLLER',
      }.entries) {
    await seedF2FireComponent(db, entry.key);
    await db
        .into(db.componentReferenceBindings)
        .insert(
          ComponentReferenceBindingsCompanion.insert(
            componentId: entry.key,
            projectId: 'p',
            catalogId: catalog.id,
            profileCode: entry.value,
            payloadJson: canonicalEngineeringJsonV1(
              catalog.profile(entry.value).toMap(),
            ),
            createdAt: Elv5F2ProductionLifecycle.now(),
            updatedAt: Elv5F2ProductionLifecycle.now(),
            originDeviceId: 'f2-acs',
          ),
        );
  }
}

Future<void> replaceF2AcsAggregate(
  AppDatabase db, {
  required String operation,
  required Map<String, Object?> payload,
  required String commandId,
}) async {
  final service = Elv5AcsMutationService(
    unitOfWork: DriftElv5AcsWriteUnitOfWork(db, originDeviceId: 'f2-acs'),
    originDeviceId: 'f2-acs',
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

Future<Map<String, Object?>> loadF2AcsAggregate(
  AppDatabase db, {
  required String operation,
  required String subjectId,
}) async {
  final snapshot = await DriftElv5AcsWriteUnitOfWork(
    db,
    originDeviceId: 'f2-acs',
  ).run(
    (session) => session.acs.load(
      projectId: 'p',
      designRevisionId: 'd',
      operation: operation,
      subjectId: subjectId,
    ),
  );
  if (snapshot == null)
    throw StateError('Production ACS aggregate missing: $subjectId');
  return snapshot.payload;
}

String f2AcsHash(String c) => List.filled(64, c).join();
Map<String, Object?> f2AcsDoorPayload() => <String, Object?>{
  'doorAssemblyId': 'door-1',
  'topologyProfileRef': <String, Object?>{
    'profileCode': 'ACS-DOOR-SINGLE',
    'editionId': 'v1',
    'contentHash': f2AcsHash('a'),
  },
  'safetyMode': 'FAIL_SAFE',
  'roleAssignments': <Object?>[
    <String, Object?>{
      'roleCode': 'READER_ENTRY',
      'slot': 0,
      'componentId': 'reader',
    },
    <String, Object?>{
      'roleCode': 'REQUEST_TO_EXIT',
      'slot': 0,
      'componentId': 'rte',
    },
    <String, Object?>{
      'roleCode': 'FIRE_RELEASE_INPUT',
      'slot': 0,
      'componentId': 'fire',
    },
    <String, Object?>{
      'roleCode': 'EMERGENCY_RELEASE',
      'slot': 0,
      'componentId': 'breakglass',
    },
    <String, Object?>{
      'roleCode': 'DOOR_CONTACT',
      'slot': 0,
      'componentId': 'contact',
    },
    <String, Object?>{'roleCode': 'LOCK', 'slot': 0, 'componentId': 'lock'},
  ],
  'releaseTruthTable': <Object?>[
    <String, Object?>{
      'causeCode': 'NORMAL_ACCESS',
      'expectedOutcomeCode': 'UNLOCKED',
      'requiredEvidenceRoles': <String>['READER_ENTRY', 'LOCK'],
    },
    <String, Object?>{
      'causeCode': 'REQUEST_TO_EXIT',
      'expectedOutcomeCode': 'UNLOCKED',
      'requiredEvidenceRoles': <String>['REQUEST_TO_EXIT', 'LOCK'],
    },
    <String, Object?>{
      'causeCode': 'FIRE_RELEASE',
      'expectedOutcomeCode': 'UNLOCKED',
      'requiredEvidenceRoles': <String>['FIRE_RELEASE_INPUT', 'LOCK'],
    },
    <String, Object?>{
      'causeCode': 'EMERGENCY_BREAK_GLASS',
      'expectedOutcomeCode': 'UNLOCKED',
      'requiredEvidenceRoles': <String>['EMERGENCY_RELEASE', 'LOCK'],
    },
    <String, Object?>{
      'causeCode': 'POWER_FAILURE',
      'expectedOutcomeCode': 'UNLOCKED',
      'requiredEvidenceRoles': <String>['LOCK'],
    },
  ],
};

Map<String, Object?> f2AcsControllerPayload({bool duplicateRelay = false}) =>
    <String, Object?>{
      'controllerId': 'controller-1',
      'resourceAssignments': <Object?>[
        <String, Object?>{
          'resourceId': 'reader-1',
          'resourceKind': 'READER_CHANNEL',
          'assignmentRole': 'READER_ENTRY',
          'subjectId': 'door-1',
        },
        <String, Object?>{
          'resourceId': 'reader-2',
          'resourceKind': 'READER_CHANNEL',
          'assignmentRole': 'READER_ENTRY',
          'subjectId': 'door-2',
        },
        <String, Object?>{
          'resourceId': 'reader-3',
          'resourceKind': 'READER_CHANNEL',
          'assignmentRole': 'READER_ENTRY',
          'subjectId': 'door-3',
        },
        <String, Object?>{
          'resourceId': 'relay-1',
          'resourceKind': 'RELAY_OUTPUT',
          'assignmentRole': 'LOCK',
          'subjectId': 'door-1',
        },
        <String, Object?>{
          'resourceId': 'relay-2',
          'resourceKind': 'RELAY_OUTPUT',
          'assignmentRole': 'LOCK',
          'subjectId': 'door-2',
        },
        if (duplicateRelay)
          <String, Object?>{
            'resourceId': 'relay-1',
            'resourceKind': 'RELAY_OUTPUT',
            'assignmentRole': 'LOCK',
            'subjectId': 'door-3',
          },
        <String, Object?>{
          'resourceId': 'input-1',
          'resourceKind': 'SUPERVISED_INPUT',
          'assignmentRole': 'DOOR_CONTACT',
          'subjectId': 'door-1',
        },
      ],
      'reservePolicyRef': <String, Object?>{
        'policyCode': 'ACS-CONTROLLER-SPARE',
        'editionId': 'spare-v1',
        'contentHash': f2AcsHash('b'),
      },
    };
