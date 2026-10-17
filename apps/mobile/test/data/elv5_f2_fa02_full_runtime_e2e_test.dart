import 'package:electra_mobile/application/elv4_wire_command_dispatcher.dart';
import 'package:electra_mobile/application/elv4_wire_power_payload.dart';
import 'package:electra_mobile/application/power_mutation_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_power_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';
import '../support/elv5_f2_fire_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 FA-02 production Q6/Q7/Q8 exact ELV4 DC states, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.fa02,
        subjectKind: 'FIRE_LOOP',
        subjectId: 'loop-1',
      );
      late Object initialStartupUpper;

      await lifecycle.run(
        seed: (db) async {
          await seedF2FireTopology(db);
          await replaceF2FireLoop(db);
          final builder = Elv4QualificationBuilder(
            db,
            projectId: 'p',
            revisionId: 'd',
            instant: Elv5F2ProductionLifecycle.now(),
          );
          await _seedPowerPorts(builder);
          final coordinator = _coordinator(db);

          await _replaceLoads(
            coordinator: coordinator,
            db: db,
            componentId: 'panel-1',
            commandId: 'fa02-panel-loads',
            standbyA: '0.020',
            alarmA: '0.040',
            startupA: '0.100',
          );
          await _replaceLoads(
            coordinator: coordinator,
            db: db,
            componentId: 'd1',
            commandId: 'fa02-d1-loads',
            standbyA: '0.010',
            alarmA: '0.020',
            startupA: '0.050',
          );
          await _replaceLoads(
            coordinator: coordinator,
            db: db,
            componentId: 'd2',
            commandId: 'fa02-d2-loads',
            standbyA: '0.010',
            alarmA: '0.020',
            startupA: '0.050',
          );

          await _replaceScenario(
            coordinator,
            db,
            id: 'FA02-STANDBY',
            role: PowerScenarioRole.standby,
            state: PowerDeviceState.standby,
          );
          await _replaceScenario(
            coordinator,
            db,
            id: 'FA02-ALARM',
            role: PowerScenarioRole.alarm,
            state: PowerDeviceState.alarm,
          );
          await _replaceScenario(
            coordinator,
            db,
            id: 'FA02-STARTUP',
            role: PowerScenarioRole.startup,
            state: PowerDeviceState.startup,
          );
        },
        mutate: (db) async {
          await _replaceLoads(
            coordinator: _coordinator(db),
            db: db,
            componentId: 'd2',
            commandId: 'fa02-d2-loads-hot-start',
            standbyA: '0.010',
            alarmA: '0.020',
            startupA: '0.080',
          );
        },
        dependencyDomains: const {
          'FIRE_LOOP',
          'POWER_COMPONENT_STATE_LOADS',
          'POWER_OPERATING_SCENARIO',
        },
        initialAssessment: 'NOT_ASSESSED',
        changedAssessment: 'NOT_ASSESSED',
        initialOutput: (output) {
          expect(output['status'], 'complete');
          expect(output['governingCase'], 'startupInrush');
          final cases = Map<String, Object?>.from(output['cases'] as Map);
          expect(
            cases.keys,
            containsAll(<String>['standby', 'alarm', 'startupInrush']),
          );
          final startup = Map<String, Object?>.from(
            cases['startupInrush'] as Map,
          );
          expect(startup['missingOriginIds'], isEmpty);
          initialStartupUpper = startup['knownSubtotalUpperA']!;
        },
        changedOutput: (output) {
          expect(output['status'], 'complete');
          expect(output['governingCase'], 'startupInrush');
          final startup = Map<String, Object?>.from(
            (output['cases'] as Map)['startupInrush'] as Map,
          );
          expect(startup['missingOriginIds'], isEmpty);
          expect(
            startup['knownSubtotalUpperA'],
            isNot(equals(initialStartupUpper)),
          );
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replaceLoads(
              coordinator: _coordinator(db),
              db: db,
              componentId: 'd2',
              commandId: 'fa02-d2-loads-after-freeze',
              standbyA: '0.010',
              alarmA: '0.020',
              startupA: '0.090',
            ),
            throwsA(
              predicate(
                (error) => error.toString().contains(
                  'ELV4_DESIGN_REVISION_CAS_FAILED',
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

DriftElv5PowerMutationCoordinator _coordinator(AppDatabase db) =>
    DriftElv5PowerMutationCoordinator(
      db,
      originDeviceId: 'f2-fa02',
      nowUtc: Elv5F2ProductionLifecycle.now,
    );

Future<int> _revision(AppDatabase db) async => (await db
        .customSelect(
          "SELECT revision FROM project_design_revisions WHERE project_id = 'p' AND id = 'd'",
        )
        .getSingle())
    .read<int>('revision');

Future<void> _seedPowerPorts(Elv4QualificationBuilder builder) async {
  for (final componentId in const <String>['panel-1', 'd1', 'd2']) {
    await builder.topology.savePort(
      builder.projectId,
      builder.powerPort(componentId, 'DC-IN'),
    );
  }
}

Future<void> _replaceLoads({
  required DriftElv5PowerMutationCoordinator coordinator,
  required AppDatabase db,
  required String componentId,
  required String commandId,
  required String standbyA,
  required String alarmA,
  required String startupA,
}) async {
  final portId = '$componentId-DC-IN';
  final originId = 'FA02:$componentId';
  final loads = <Elv4WireLoadEntry>[
    _load('$componentId-standby', portId, 'STANDBY', originId, standbyA),
    _load('$componentId-alarm', portId, 'ALARM', originId, alarmA),
    _load('$componentId-startup', portId, 'STARTUP', originId, startupA),
  ];
  final payload = <String, Object?>{
    'componentId': componentId,
    'loads': loads.map((value) => value.toMap()).toList(growable: false),
  };
  await coordinator.replaceLoadProfile(
    envelope: Elv4WireCommandEnvelope(
      schema: Elv4WireCommandEnvelope.powerCommandSchema,
      operation: 'SET_POWER_LOAD_PROFILE',
      payloadSchemaVersion: 1,
      projectId: 'p',
      designRevisionId: 'd',
      commandId: commandId,
      expectedDesignRowRevision: await _revision(db),
      expectedRows: const <String, int>{},
      reviewedImpactFingerprint: null,
      payload: payload,
    ),
    changedDependencyRefs: const <String>[],
    componentId: componentId,
    loads: loads,
  );
}

Elv4WireLoadEntry _load(
  String id,
  String portId,
  String state,
  String originId,
  String currentA,
) => Elv4WireLoadEntry(
  loadId: id,
  inputPortId: portId,
  stateCode: state,
  accountingKind: 'CONSUMER_INPUT',
  originId: originId,
  demand: DcConstantCurrentDemand(PowerRational.fromWireDecimal(currentA)),
);

Future<void> _replaceScenario(
  DriftElv5PowerMutationCoordinator coordinator,
  AppDatabase db, {
  required String id,
  required PowerScenarioRole role,
  required PowerDeviceState state,
}) async {
  await coordinator.execute(
    ReplacePowerScenarioCommand(
      operationId: 'replace-${id.toLowerCase()}',
      projectId: 'p',
      designRevisionId: 'd',
      expectedRevision: await _revision(db),
      changedDependencies: const [],
      scenario: PowerOperatingScenario(
        scenarioId: id,
        role: role,
        rowRevision: 1,
        segments: <PowerScenarioSegment>[
          PowerScenarioSegment(
            segmentId: 'CASE',
            ordinal: 1,
            componentStates: <String, PowerDeviceState>{
              'panel-1': state,
              'd1': state,
              'd2': state,
            },
          ),
        ],
      ),
    ),
  );
}
