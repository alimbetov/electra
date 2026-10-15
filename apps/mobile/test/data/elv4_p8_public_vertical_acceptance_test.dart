import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/application/power_mutation_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';
import '../support/elv4_power_qualification_topology.dart';

final class _BuiltVerticals {
  const _BuiltVerticals(this.revision);
  final int revision;
}

QueryExecutor _native(File file, {bool configureWal = false}) =>
    NativeDatabase.createInBackground(
      file,
      setup: (raw) {
        if (configureWal) raw.execute('PRAGMA journal_mode=WAL');
        raw.execute('PRAGMA busy_timeout=30000');
        raw.execute('PRAGMA foreign_keys=ON');
      },
    );

void main() {
  test(
    'P8 CCTV LAN ACS FIRE verticals persist through public commands with exact shared ownership',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'electra-elv4-p8-verticals-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/electra.sqlite');
      var db = AppDatabase(_native(file, configureWal: true));
      final builder = Elv4QualificationBuilder(db);
      await builder.createStructuralBaseline();
      final built = await _buildFourVerticals(builder);

      final fk = await db.customSelect('PRAGMA foreign_key_check').get();
      expect(fk, isEmpty);
      expect(await _count(db, 'power_operation_records'), greaterThan(20));
      expect(await _count(db, 'power_component_bindings'), 10);
      expect(await _count(db, 'power_load_bindings'), 4);
      expect(await _count(db, 'poe_delivery_bindings'), 2);
      expect(await _count(db, 'poe_delivery_path_members'), 2);
      expect(await _count(db, 'backup_assemblies'), 2);
      expect(await _count(db, 'battery_bank_bindings'), 2);

      // CCTV + LAN share one PSE and one explicit group. Their loads are still
      // separate contributions, so group usage cannot multiply the PSE own load.
      expect(
        await _countWhere(
          db,
          'power_capacity_groups',
          "id = 'SHARED_PSE_GROUP'",
        ),
        1,
      );
      expect(
        await _countWhere(
          db,
          'power_capacity_group_members',
          "group_id = 'SHARED_PSE_GROUP'",
        ),
        2,
      );
      expect(
        await _countWhere(
          db,
          'power_load_bindings',
          "id IN ('CCTV_CAMERA_LOAD', 'LAN_PD_LOAD')",
        ),
        2,
      );

      // ACS bank direction is explicit, not inferred from scenario name.
      final acsState =
          await db
              .customSelect(
                "SELECT state_code FROM power_scenario_states "
                "WHERE scenario_id = 'ACS_BACKUP' AND component_id = 'acs-bank'",
              )
              .getSingle();
      expect(acsState.read<String>('state_code'), 'DISCHARGING');

      // Fire semantics are explicit two-segment state data with no hidden
      // policy attachment.
      expect(
        await _countWhere(
          db,
          'power_scenario_segments',
          "scenario_id = 'FIRE_SEQUENCE'",
        ),
        2,
      );
      final fire =
          await db
              .customSelect(
                "SELECT policy_refs_json FROM power_operating_scenarios "
                "WHERE id = 'FIRE_SEQUENCE'",
              )
              .getSingle();
      expect(fire.read<String>('policy_refs_json'), '[]');

      // LAN fiber is never silently treated as a powered copper channel.
      await builder.addComponent(
        'lan-fiber-endpoint',
        xMm: 9000,
        ports: [
          EngineeringPort(
            id: 'lan-fiber-endpoint-fiber',
            componentId: 'lan-fiber-endpoint',
            code: 'FIBER',
            kind: EngineeringPortKind.fiber,
            direction: PortDirection.input,
            capacity: 1,
            connector: 'LC',
          ),
        ],
      );
      await expectLater(
        builder.connectDataPower(
          familyCode: 'LAN',
          connectionId: 'lan-invalid-fiber-power',
          fromPortId: 'shared-pse-lan-out',
          toPortId: 'lan-fiber-endpoint-fiber',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        await _countWhere(
          db,
          'engineering_port_connections',
          "id = 'lan-invalid-fiber-power'",
        ),
        0,
      );

      // Domain guard: declared PoE loss cannot make guaranteed PD delivery
      // exceed the PSE port budget.
      expect(
        () => PoeDeliveryDefinition(
          definitionRef: builder.definition(PowerDefinitionKind.poe, 'POE-BAD'),
          guaranteedPdPowerW: PowerRational.integer(29),
          psePortLimitW: PowerRational.integer(30),
          maxChannelLossW: PowerRational.integer(2),
          compatibleResourceKinds: const ['COPPER'],
          supportsMidspan: false,
        ),
        throwsArgumentError,
      );

      await _publishVerticalEvidence(builder, db);
      expect(
        await _countWhere(db, 'power_evaluation_pointers', "state = 'CURRENT'"),
        4,
      );

      final frozen = await builder.revisions.freeze(
        FreezeProjectDesignRevisionCommand(
          commandId: 'p8-freeze-four-verticals',
          projectId: builder.projectId,
          designRevisionId: builder.revisionId,
          expectedRevision: built.revision,
        ),
      );
      expect(frozen, isA<ElvCommandSuccess<ProjectDesignRevision>>());
      final frozenValue =
          (frozen as ElvCommandSuccess<ProjectDesignRevision>).value;
      expect(frozenValue.state, ProjectDesignRevisionState.frozen);

      final powerSnapshot =
          await db
              .customSelect(
                'SELECT power_sha256, physical_sha256 FROM design_revision_power_snapshots '
                'WHERE design_revision_id = ?',
                variables: [Variable.withString(builder.revisionId)],
              )
              .getSingle();
      final manifest =
          await db
              .customSelect(
                'SELECT manifest_sha256, power_sha256, physical_sha256 '
                'FROM design_revision_snapshot_manifests WHERE design_revision_id = ?',
                variables: [Variable.withString(builder.revisionId)],
              )
              .getSingle();
      final powerSha = powerSnapshot.read<String>('power_sha256');
      final physicalSha = powerSnapshot.read<String>('physical_sha256');
      expect(manifest.read<String>('power_sha256'), powerSha);
      expect(manifest.read<String>('physical_sha256'), physicalSha);
      final manifestSha = manifest.read<String>('manifest_sha256');

      await db.close();
      db = AppDatabase(_native(file));
      addTearDown(db.close);

      final powerView = await DriftPowerPublicationRuntime(
        db,
        originDeviceId: 'qualification',
      ).readRevision(
        projectId: builder.projectId,
        designRevisionId: builder.revisionId,
      );
      expect(powerView.kind, PowerRevisionReadKind.captured);
      expect(powerView.mutationAllowed, isFalse);
      final reopenedSnapshot =
          await db
              .customSelect(
                'SELECT power_sha256, physical_sha256 FROM design_revision_power_snapshots '
                'WHERE design_revision_id = ?',
                variables: [Variable.withString(builder.revisionId)],
              )
              .getSingle();
      final reopenedManifest =
          await db
              .customSelect(
                'SELECT manifest_sha256 FROM design_revision_snapshot_manifests '
                'WHERE design_revision_id = ?',
                variables: [Variable.withString(builder.revisionId)],
              )
              .getSingle();
      expect(reopenedSnapshot.read<String>('power_sha256'), powerSha);
      expect(reopenedSnapshot.read<String>('physical_sha256'), physicalSha);
      expect(reopenedManifest.read<String>('manifest_sha256'), manifestSha);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}

Future<_BuiltVerticals> _buildFourVerticals(
  Elv4QualificationBuilder builder,
) async {
  final components = <String, List<EngineeringPort>>{
    'shared-ups': [
      builder.powerPort('shared-ups', 'ac-in', direction: PortDirection.input),
      builder.powerPort(
        'shared-ups',
        'dc-out',
        direction: PortDirection.output,
      ),
    ],
    'shared-pse': [
      builder.powerPort('shared-pse', 'dc-in', direction: PortDirection.input),
      _dataPowerPort('shared-pse', 'cctv-out', PortDirection.output),
      _dataPowerPort('shared-pse', 'lan-out', PortDirection.output),
    ],
    'cctv-camera': [
      _dataPowerPort('cctv-camera', 'poe-in', PortDirection.input),
    ],
    'lan-pd': [_dataPowerPort('lan-pd', 'poe-in', PortDirection.input)],
    'acs-psu': [
      builder.powerPort('acs-psu', 'dc-in', direction: PortDirection.input),
      builder.powerPort('acs-psu', 'dc-out', direction: PortDirection.output),
    ],
    'acs-controller': [
      builder.powerPort(
        'acs-controller',
        'dc-in',
        direction: PortDirection.input,
      ),
    ],
    'acs-bank': const [],
    'fire-psu': [
      builder.powerPort('fire-psu', 'dc-in', direction: PortDirection.input),
      builder.powerPort('fire-psu', 'dc-out', direction: PortDirection.output),
    ],
    'fire-panel': [
      builder.powerPort('fire-panel', 'dc-in', direction: PortDirection.input),
    ],
    'fire-bank': const [],
  };
  var x = 500;
  for (final entry in components.entries) {
    await builder.addComponent(entry.key, xMm: x, ports: entry.value);
    x += 800;
  }

  await builder.connectDataPower(
    familyCode: 'CCTV',
    connectionId: 'cctv-poe-link',
    fromPortId: 'shared-pse-cctv-out',
    toPortId: 'cctv-camera-poe-in',
  );
  await builder.connectDataPower(
    familyCode: 'LAN',
    connectionId: 'lan-poe-link',
    fromPortId: 'shared-pse-lan-out',
    toPortId: 'lan-pd-poe-in',
  );

  var revision = 1;
  Future<void> bindComponent(
    String id,
    List<PowerComponentCapability> capabilities, {
    List<String> ownLoads = const [],
  }) async {
    revision =
        (await builder.bindComponent(
          id,
          capabilities,
          expectedRevision: revision,
          ownLoadContributionIds: ownLoads,
        )).currentRevision;
  }

  await bindComponent('shared-ups', [
    PowerComponentCapability.transfer,
    PowerComponentCapability.backup,
  ]);
  await bindComponent('shared-pse', [
    PowerComponentCapability.transfer,
    PowerComponentCapability.distribution,
    PowerComponentCapability.poeSource,
  ]);
  await bindComponent(
    'cctv-camera',
    [PowerComponentCapability.consumer, PowerComponentCapability.poeConsumer],
    ownLoads: const ['CCTV_CAMERA_LOAD'],
  );
  await bindComponent(
    'lan-pd',
    [PowerComponentCapability.consumer, PowerComponentCapability.poeConsumer],
    ownLoads: const ['LAN_PD_LOAD'],
  );
  await bindComponent('acs-psu', [
    PowerComponentCapability.transfer,
    PowerComponentCapability.source,
  ]);
  await bindComponent(
    'acs-controller',
    [PowerComponentCapability.consumer],
    ownLoads: const ['ACS_CONTROLLER_LOAD'],
  );
  await bindComponent('acs-bank', [PowerComponentCapability.storage]);
  await bindComponent('fire-psu', [
    PowerComponentCapability.transfer,
    PowerComponentCapability.source,
  ]);
  await bindComponent(
    'fire-panel',
    [PowerComponentCapability.consumer],
    ownLoads: const ['FIRE_STANDBY_LOAD', 'FIRE_ALARM_LOAD'],
  );
  await bindComponent('fire-bank', [PowerComponentCapability.storage]);

  final ports = <(String, PowerPortRole)>[
    ('shared-ups-ac-in', PowerPortRole.consumer),
    ('shared-ups-dc-out', PowerPortRole.source),
    ('shared-pse-dc-in', PowerPortRole.consumer),
    ('shared-pse-cctv-out', PowerPortRole.source),
    ('shared-pse-lan-out', PowerPortRole.source),
    ('cctv-camera-poe-in', PowerPortRole.consumer),
    ('lan-pd-poe-in', PowerPortRole.consumer),
    ('acs-psu-dc-in', PowerPortRole.consumer),
    ('acs-psu-dc-out', PowerPortRole.source),
    ('acs-controller-dc-in', PowerPortRole.consumer),
    ('fire-psu-dc-in', PowerPortRole.consumer),
    ('fire-psu-dc-out', PowerPortRole.source),
    ('fire-panel-dc-in', PowerPortRole.consumer),
  ];
  for (final entry in ports) {
    revision =
        (await builder.bindPort(
          entry.$1,
          entry.$2,
          expectedRevision: revision,
          currentKind:
              entry.$1 == 'shared-ups-ac-in'
                  ? PowerCurrentKind.ac
                  : PowerCurrentKind.dc,
        )).currentRevision;
  }

  revision =
      (await builder.power.execute(
        ReplacePowerTransferCommand(
          operationId: 'transfer-shared-ups',
          projectId: builder.projectId,
          designRevisionId: builder.revisionId,
          expectedRevision: revision,
          changedDependencies: [builder.dependency('TRANSFER-SHARED-UPS')],
          transfer: PowerTransferBinding(
            id: 'SHARED_UPS',
            componentId: 'shared-ups',
            definitionRef: builder.definition(
              PowerDefinitionKind.transfer,
              'UPS',
            ),
            kind: PowerTransferKind.ups,
            inputPortIds: const ['shared-ups-ac-in'],
            outputPortIds: const ['shared-ups-dc-out'],
            enabledStateCodes: const ['NORMAL', 'BACKUP'],
            inputAccountingOrigin: 'UPS_INPUT',
            lossDefinition: builder.efficientLoss,
          ),
        ),
      )).currentRevision;

  revision =
      (await builder.power.execute(
        ReplacePowerTransferCommand(
          operationId: 'transfer-shared-pse',
          projectId: builder.projectId,
          designRevisionId: builder.revisionId,
          expectedRevision: revision,
          changedDependencies: [builder.dependency('TRANSFER-SHARED-PSE')],
          transfer: PowerTransferBinding(
            id: 'SHARED_PSE',
            componentId: 'shared-pse',
            definitionRef: builder.definition(
              PowerDefinitionKind.transfer,
              'PSE',
            ),
            kind: PowerTransferKind.pse,
            inputPortIds: const ['shared-pse-dc-in'],
            outputPortIds: const ['shared-pse-cctv-out', 'shared-pse-lan-out'],
            enabledStateCodes: const ['NORMAL', 'BACKUP'],
            inputAccountingOrigin: 'PSE_INPUT',
            lossDefinition: builder.efficientLoss,
          ),
        ),
      )).currentRevision;

  revision =
      (await builder.power.execute(
        ReplacePowerCapacityGroupCommand(
          operationId: 'shared-pse-capacity',
          projectId: builder.projectId,
          designRevisionId: builder.revisionId,
          expectedRevision: revision,
          changedDependencies: [builder.dependency('GROUP-SHARED-PSE')],
          group: PowerCapacityGroup(
            id: 'SHARED_PSE_GROUP',
            ownerComponentId: 'shared-pse',
            memberOutputPortIds: const [
              'shared-pse-cctv-out',
              'shared-pse-lan-out',
            ],
            limits: [
              PowerCapacityLimit(
                dimension: PowerCapacityDimension.watt,
                limit: PowerRational.integer(120),
              ),
            ],
            applicabilityStateCodes: const ['NORMAL', 'BACKUP'],
          ),
        ),
      )).currentRevision;

  for (final load in [
    PowerOwnLoadContribution(
      id: 'CCTV_CAMERA_LOAD',
      componentId: 'cctv-camera',
      inputPortId: 'cctv-camera-poe-in',
      accountingKind: PowerAccountingKind.consumerInput,
      stateCode: 'NORMAL',
      demand: DcConstantPowerDemand(PowerRational.integer(12)),
    ),
    PowerOwnLoadContribution(
      id: 'LAN_PD_LOAD',
      componentId: 'lan-pd',
      inputPortId: 'lan-pd-poe-in',
      accountingKind: PowerAccountingKind.consumerInput,
      stateCode: 'NORMAL',
      demand: DcConstantPowerDemand(PowerRational.integer(18)),
    ),
    PowerOwnLoadContribution(
      id: 'ACS_CONTROLLER_LOAD',
      componentId: 'acs-controller',
      inputPortId: 'acs-controller-dc-in',
      accountingKind: PowerAccountingKind.consumerInput,
      stateCode: 'NORMAL',
      demand: DcConstantPowerDemand(PowerRational.integer(20)),
    ),
    PowerOwnLoadContribution(
      id: 'FIRE_STANDBY_LOAD',
      componentId: 'fire-panel',
      inputPortId: 'fire-panel-dc-in',
      accountingKind: PowerAccountingKind.consumerInput,
      stateCode: 'STANDBY',
      demand: DcConstantPowerDemand(PowerRational.integer(8)),
    ),
  ]) {
    revision =
        (await builder.power.execute(
          SetPowerLoadCommand(
            operationId: 'load-${load.id.toLowerCase()}',
            projectId: builder.projectId,
            designRevisionId: builder.revisionId,
            expectedRevision: revision,
            changedDependencies: [builder.dependency('LOAD-${load.id}')],
            contribution: load,
          ),
        )).currentRevision;
  }

  final poeDefinition = PoeDeliveryDefinition(
    definitionRef: builder.definition(PowerDefinitionKind.poe, 'POE-CLASS'),
    guaranteedPdPowerW: PowerRational.integer(25),
    psePortLimitW: PowerRational.integer(30),
    maxChannelLossW: PowerRational.integer(3),
    compatibleResourceKinds: const ['COPPER'],
    supportsMidspan: true,
  );
  for (final delivery in [
    ('CCTV_POE', 'shared-pse-cctv-out', 'cctv-camera-poe-in', 'cctv-poe-link'),
    ('LAN_POE', 'shared-pse-lan-out', 'lan-pd-poe-in', 'lan-poe-link'),
  ]) {
    revision =
        (await builder.power.execute(
          BindPoeDeliveryCommand(
            operationId: 'poe-${delivery.$1.toLowerCase()}',
            projectId: builder.projectId,
            designRevisionId: builder.revisionId,
            expectedRevision: revision,
            changedDependencies: [builder.dependency('POE-${delivery.$1}')],
            deliveryId: delivery.$1,
            psePortId: delivery.$2,
            pdPortId: delivery.$3,
            accountingMode: 'PD_OUTPUT',
            definition: poeDefinition,
            path: [
              PowerPoePathMemberInput(
                connectionId: delivery.$4,
                evidence: const {'resourceKind': 'COPPER'},
              ),
            ],
          ),
        )).currentRevision;
  }

  for (final transfer in [
    ('ACS_PSU', 'acs-psu', 'acs-psu-dc-in', 'acs-psu-dc-out'),
    ('FIRE_PSU', 'fire-psu', 'fire-psu-dc-in', 'fire-psu-dc-out'),
  ]) {
    revision =
        (await builder.power.execute(
          ReplacePowerTransferCommand(
            operationId: 'transfer-${transfer.$1.toLowerCase()}',
            projectId: builder.projectId,
            designRevisionId: builder.revisionId,
            expectedRevision: revision,
            changedDependencies: [
              builder.dependency('TRANSFER-${transfer.$1}'),
            ],
            transfer: PowerTransferBinding(
              id: transfer.$1,
              componentId: transfer.$2,
              definitionRef: builder.definition(
                PowerDefinitionKind.transfer,
                'PSU',
              ),
              kind: PowerTransferKind.psu,
              inputPortIds: [transfer.$3],
              outputPortIds: [transfer.$4],
              enabledStateCodes: const ['NORMAL', 'STANDBY', 'ALARM', 'BACKUP'],
              inputAccountingOrigin: '${transfer.$1}_INPUT',
              lossDefinition: builder.efficientLoss,
            ),
          ),
        )).currentRevision;
  }

  for (final bank in [('ACS_BANK', 'acs-bank'), ('FIRE_BANK', 'fire-bank')]) {
    final binding = BatteryBankBinding(
      componentId: bank.$2,
      unitDefinition: BatteryUnitDefinition(
        definitionRef: builder.definition(
          PowerDefinitionKind.battery,
          '${bank.$1}_UNIT',
        ),
        technology: 'VRLA',
        nominalV: PowerRational.integer(12),
        capacityBasis: BatteryCapacityBasis.ampHour,
        ratedCapacity: PowerRational.integer(18),
        usableFraction: PowerRational(BigInt.from(4), BigInt.from(5)),
        maxSeriesCount: 4,
        maxParallelCount: 4,
        arrangementCodes: const ['SERIES_PARALLEL'],
      ),
      seriesCount: 2,
      parallelCount: 1,
      arrangementCode: 'SERIES_PARALLEL',
      socMin: PowerRational(BigInt.one, BigInt.from(5)),
      socMax: PowerRational.one,
      endOfDischargeVoltagePerUnit: PowerRational.integer(10),
    );
    revision =
        (await builder.power.execute(
          ReplaceBatteryBankCommand(
            operationId: 'battery-${bank.$1.toLowerCase()}',
            projectId: builder.projectId,
            designRevisionId: builder.revisionId,
            expectedRevision: revision,
            changedDependencies: [builder.dependency('BATTERY-${bank.$1}')],
            bindingId: bank.$1,
            binding: binding,
          ),
        )).currentRevision;
  }

  for (final backup in [
    ('ACS_BACKUP_ASSEMBLY', 'acs-bank', 'acs-psu-dc-out'),
    ('FIRE_BACKUP_ASSEMBLY', 'fire-bank', 'fire-psu-dc-out'),
  ]) {
    revision =
        (await builder.power.execute(
          ConfigureBackupAssemblyCommand(
            operationId: 'backup-${backup.$1.toLowerCase()}',
            projectId: builder.projectId,
            designRevisionId: builder.revisionId,
            expectedRevision: revision,
            changedDependencies: [builder.dependency('BACKUP-${backup.$1}')],
            assemblyId: backup.$1,
            bankComponentId: backup.$2,
            protectedOutputPortIds: [backup.$3],
            policy: const {'sourceSelection': 'EXPLICIT'},
          ),
        )).currentRevision;
  }

  revision =
      (await builder.power.execute(
        ReplacePowerScenarioCommand(
          operationId: 'scenario-acs-backup',
          projectId: builder.projectId,
          designRevisionId: builder.revisionId,
          expectedRevision: revision,
          changedDependencies: [builder.dependency('SCENARIO-ACS-BACKUP')],
          scenario: PowerOperatingScenario(
            scenarioId: 'ACS_BACKUP',
            role: PowerScenarioRole.backup,
            rowRevision: 1,
            segments: [
              PowerScenarioSegment(
                segmentId: 'BACKUP',
                ordinal: 1,
                componentStates: const {
                  'acs-controller': PowerDeviceState.normal,
                },
                dischargingBankIds: const ['acs-bank'],
              ),
            ],
          ),
        ),
      )).currentRevision;

  revision =
      (await builder.power.execute(
        ReplacePowerScenarioCommand(
          operationId: 'scenario-fire-sequence',
          projectId: builder.projectId,
          designRevisionId: builder.revisionId,
          expectedRevision: revision,
          changedDependencies: [builder.dependency('SCENARIO-FIRE-SEQUENCE')],
          scenario: PowerOperatingScenario(
            scenarioId: 'FIRE_SEQUENCE',
            role: PowerScenarioRole.custom,
            rowRevision: 1,
            segments: [
              PowerScenarioSegment(
                segmentId: 'STANDBY',
                ordinal: 1,
                componentStates: const {'fire-panel': PowerDeviceState.standby},
              ),
              PowerScenarioSegment(
                segmentId: 'ALARM',
                ordinal: 2,
                componentStates: const {'fire-panel': PowerDeviceState.alarm},
              ),
            ],
            policyRefs: const [],
          ),
        ),
      )).currentRevision;

  return _BuiltVerticals(revision);
}

EngineeringPort _dataPowerPort(
  String componentId,
  String code,
  PortDirection direction,
) => EngineeringPort(
  id: '$componentId-$code',
  componentId: componentId,
  code: code,
  kind: EngineeringPortKind.dataPower,
  direction: direction,
  capacity: 1,
  connector: 'RJ45',
  protocol: const EngineeringProfileReference(id: 'POE', version: '1'),
  voltage: const PortVoltageDomain(
    currentKind: PortCurrentKind.dc,
    minimumV: 40,
    maximumV: 60,
  ),
  powerDirection: direction,
  powerLimitW: direction == PortDirection.output ? 30 : null,
  powerDemandW: direction == PortDirection.input ? 25 : null,
);

Future<int> _count(AppDatabase db, String table) => db
    .customSelect('SELECT COUNT(*) AS c FROM $table')
    .getSingle()
    .then((row) => row.read<int>('c'));

Future<int> _countWhere(AppDatabase db, String table, String where) => db
    .customSelect('SELECT COUNT(*) AS c FROM $table WHERE $where')
    .getSingle()
    .then((row) => row.read<int>('c'));

Future<void> _publishVerticalEvidence(
  Elv4QualificationBuilder builder,
  AppDatabase db,
) async {
  final runtime = DriftPowerPublicationRuntime(
    db,
    originDeviceId: 'qualification',
    now: () => DateTime.utc(2026, 10, 15, 21, 15),
  );
  final cases = <(String, String, String, String)>[
    ('CCTV', 'NORMAL', 'cctv-camera', 'LOAD-CCTV_CAMERA_LOAD'),
    ('LAN', 'NORMAL', 'lan-pd', 'LOAD-LAN_PD_LOAD'),
    ('ACS', 'ACS_BACKUP', 'acs-controller', 'SCENARIO-ACS-BACKUP'),
    ('FIRE', 'FIRE_SEQUENCE', 'fire-panel', 'SCENARIO-FIRE-SEQUENCE'),
  ];
  for (final item in cases) {
    final node = PowerNodeKeyV2(
      revisionId: builder.revisionId,
      scenarioId: item.$2,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: '${item.$1}-QUALIFICATION',
      processCode: PowerProcessCode.pwr01,
      subjectKind: 'COMPONENT',
      subjectId: item.$3,
    );
    final fact = builder.dependency(item.$4, purpose: 'QUALIFICATION_INPUT');
    final input = PowerConsumedInput(
      algorithmVersion: 'elv4-p8-qualification-v1',
      inputSchemaVersion: 'electra.elv4-p8-qualification-input.v1',
      numericPolicyVersion: powerNumericPolicyVersion,
      facts: [
        PowerConsumedFact.present(
          key: fact,
          valueSchema: 'electra.elv4-p8-qualification-fact.v1',
          value: {
            'discipline': item.$1,
            'entityId': fact.entityId,
            'purpose': fact.purpose,
          },
        ),
      ],
      evaluations: const [],
    );
    final capture = await runtime.captureForCalculation(
      projectId: builder.projectId,
      designRevisionId: builder.revisionId,
      targetNodeKey: node,
      captureInput: () async => input,
    );
    final evidence = PowerEvaluationEvidence(
      evaluationId: 'P8-${item.$1}-PWR01',
      nodeKey: node,
      algorithmVersion: input.algorithmVersion,
      inputSchemaVersion: input.inputSchemaVersion,
      outputSchemaVersion: 'electra.elv4-p8-qualification-output.v1',
      numericPolicyVersion: input.numericPolicyVersion,
      inputFingerprint: input.inputFingerprint,
      status: PowerEvaluationStatus.pass,
      applicability: PowerEvaluationApplicability.applicable,
      inputs: {'dependencyKeys': input.dependencyKeys},
      output: {'qualified': true, 'discipline': item.$1},
      dependencies: const [],
    );
    final receipt = await runtime.publishGuarded(
      capture: capture,
      evidence: evidence,
      operationId: 'p8-qualify-${item.$1.toLowerCase()}',
      commandFingerprint: sha256HexUtf8('p8-qualify-${item.$1}'),
      recaptureInput: () async => input,
    );
    expect(receipt.replayed, isFalse);
  }
}
