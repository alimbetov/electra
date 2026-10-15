import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/power_mutation_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/database/drift_raw_statement.dart';
import 'package:electra_mobile/data/repositories/drift_power_command_service.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:electra_mobile/data/repositories/drift_power_runtime_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 15, 20);

void main() {
  test('P2 public power commands persist, advance token and replay once', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    final service = DriftPowerCommandService(
      db,
      originDeviceId: 'test',
      now: () => _now,
    );

    final component = BindPowerComponentCommand(
      operationId: 'bind-component',
      projectId: 'project',
      designRevisionId: 'rev-1',
      expectedRevision: 1,
      changedDependencies: [_dep('COMP-LOAD')],
      bindingId: 'component-binding',
      binding: PowerComponentBinding(
        componentId: 'comp-load',
        capabilities: const [PowerComponentCapability.consumer],
        definitionRefs: [_ref(PowerDefinitionKind.component, 'LOAD')],
      ),
    );
    final r1 = await service.execute(component);
    expect(r1.currentRevision, 2);
    expect(r1.replayed, isFalse);

    final port = BindPowerPortCommand(
      operationId: 'bind-port',
      projectId: 'project',
      designRevisionId: 'rev-1',
      expectedRevision: 2,
      changedDependencies: [_dep('PORT-LOAD')],
      bindingId: 'port-binding',
      binding: _portBinding('p-load'),
    );
    expect((await service.execute(port)).currentRevision, 3);

    final load = SetPowerLoadCommand(
      operationId: 'set-load',
      projectId: 'project',
      designRevisionId: 'rev-1',
      expectedRevision: 3,
      changedDependencies: [_dep('LOAD-1')],
      contribution: PowerOwnLoadContribution(
        id: 'LOAD-1',
        componentId: 'comp-load',
        inputPortId: 'p-load',
        accountingKind: PowerAccountingKind.consumerInput,
        stateCode: 'NORMAL',
        demand: DcConstantPowerDemand(PowerRational.integer(12)),
      ),
    );
    final firstLoad = await service.execute(load);
    final replayLoad = await service.execute(load);
    expect(firstLoad.currentRevision, 4);
    expect(replayLoad.currentRevision, 4);
    expect(replayLoad.replayed, isTrue);
    expect(await _revision(db), 4);

    expect(
      await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM power_component_bindings WHERE design_revision_id = 'rev-1'",
          )
          .getSingle()
          .then((row) => row.read<int>('c')),
      1,
    );
    expect(
      await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM power_port_bindings WHERE design_revision_id = 'rev-1'",
          )
          .getSingle()
          .then((row) => row.read<int>('c')),
      1,
    );
    expect(
      await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM power_load_bindings WHERE design_revision_id = 'rev-1'",
          )
          .getSingle()
          .then((row) => row.read<int>('c')),
      1,
    );

    final conflicting = SetPowerLoadCommand(
      operationId: 'set-load',
      projectId: 'project',
      designRevisionId: 'rev-1',
      expectedRevision: 3,
      changedDependencies: [_dep('LOAD-1')],
      contribution: PowerOwnLoadContribution(
        id: 'LOAD-1',
        componentId: 'comp-load',
        inputPortId: 'p-load',
        accountingKind: PowerAccountingKind.consumerInput,
        stateCode: 'NORMAL',
        demand: DcConstantPowerDemand(PowerRational.integer(13)),
      ),
    );
    await expectLater(
      service.execute(conflicting),
      throwsA(
        isA<PowerRuntimeStorageException>().having(
          (error) => error.code,
          'code',
          'ELV4_OPERATION_FINGERPRINT_CONFLICT',
        ),
      ),
    );
    expect(await _revision(db), 4);
  });

  test(
    'P2 command invalidates only exact dependency closure atomically',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      final publication = DriftPowerPublicationRuntime(
        db,
        originDeviceId: 'test',
        now: () => _now,
      );
      await publication.ensureRuntimeSchema();

      final affectedNode = PowerNodeKeyV2(
        revisionId: 'rev-1',
        scenarioId: 'NORMAL',
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: 'S1',
        processCode: PowerProcessCode.pwr01,
        subjectKind: 'LOAD',
        subjectId: 'comp-load',
      );
      final unaffectedNode = PowerNodeKeyV2(
        revisionId: 'rev-1',
        scenarioId: 'NORMAL',
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: 'S1',
        processCode: PowerProcessCode.pwr01,
        subjectKind: 'LOAD',
        subjectId: 'comp-source',
      );
      await _seedPointer(db, affectedNode, _dep('PORT-LOAD'));
      await _seedPointer(db, unaffectedNode, _dep('UNRELATED'));

      final service = DriftPowerCommandService(
        db,
        originDeviceId: 'test',
        now: () => _now,
      );
      final receipt = await service.execute(
        BindPowerPortCommand(
          operationId: 'bind-port-invalidate',
          projectId: 'project',
          designRevisionId: 'rev-1',
          expectedRevision: 1,
          changedDependencies: [_dep('PORT-LOAD')],
          bindingId: 'port-binding',
          binding: _portBinding('p-load'),
        ),
      );
      expect(receipt.invalidatedNodeKeys, [affectedNode]);

      final affected = await _pointerState(db, affectedNode);
      final unaffected = await _pointerState(db, unaffectedNode);
      expect(affected.$1, 'STALE');
      expect(affected.$2, 2);
      expect(unaffected.$1, 'CURRENT');
      expect(unaffected.$2, 1);
      expect(
        await db
            .customSelect(
              'SELECT COUNT(*) AS c FROM power_dependency_index_records '
              'WHERE logical_node_key_sha256 = ?',
              variables: [Variable.withString(affectedNode.sha256)],
            )
            .getSingle()
            .then((row) => row.read<int>('c')),
        0,
      );
      expect(
        await db
            .customSelect(
              'SELECT COUNT(*) AS c FROM power_dependency_index_records '
              'WHERE logical_node_key_sha256 = ?',
              variables: [Variable.withString(unaffectedNode.sha256)],
            )
            .getSingle()
            .then((row) => row.read<int>('c')),
        1,
      );
    },
  );

  test(
    'P2 failed command rolls back aspect rows, token and operation ledger',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      final service = DriftPowerCommandService(
        db,
        originDeviceId: 'test',
        now: () => _now,
      );

      final scenario = PowerOperatingScenario(
        scenarioId: 'NORMAL',
        role: PowerScenarioRole.normal,
        rowRevision: 1,
        segments: [
          PowerScenarioSegment(
            segmentId: 'S1',
            ordinal: 1,
            componentStates: const {
              'missing-component': PowerDeviceState.normal,
            },
          ),
        ],
      );
      await expectLater(
        service.execute(
          ReplacePowerScenarioCommand(
            operationId: 'bad-scenario',
            projectId: 'project',
            designRevisionId: 'rev-1',
            expectedRevision: 1,
            changedDependencies: [_dep('SCENARIO-NORMAL')],
            scenario: scenario,
          ),
        ),
        throwsA(
          isA<PowerRuntimeStorageException>().having(
            (error) => error.code,
            'code',
            'ELV4_COMPONENT_SCOPE_MISMATCH',
          ),
        ),
      );

      expect(await _revision(db), 1);
      expect(
        await db
            .customSelect(
              "SELECT COUNT(*) AS c FROM power_operating_scenarios WHERE design_revision_id = 'rev-1'",
            )
            .getSingle()
            .then((row) => row.read<int>('c')),
        0,
      );
      expect(
        await db
            .customSelect(
              "SELECT COUNT(*) AS c FROM power_operation_records WHERE operation_id = 'bad-scenario'",
            )
            .getSingle()
            .then((row) => row.read<int>('c')),
        0,
      );
    },
  );
}

PowerPortBinding _portBinding(String portId) => PowerPortBinding(
  portId: portId,
  profileRef: _ref(PowerDefinitionKind.port, 'PORT'),
  role: PowerPortRole.consumer,
  voltageEnvelope: PowerVoltageEnvelope(
    currentKind: PowerCurrentKind.dc,
    minV: PowerRational.integer(10),
    nominalV: PowerRational.integer(12),
    maxV: PowerRational.integer(14),
  ),
  terminalRoles: const ['POWER'],
  ownership: PowerProjectionOwnership([
    for (final field in const [
      PowerProjectionField.currentKind,
      PowerProjectionField.voltageEnvelope,
      PowerProjectionField.powerDirection,
      PowerProjectionField.terminalRoles,
    ])
      PowerProjectionClaim(
        field: field,
        ownerKind: PowerProjectionOwnerKind.elv4,
        ownerRef: 'test',
      ),
  ]),
);

PowerDefinitionRef _ref(PowerDefinitionKind kind, String code) =>
    PowerDefinitionRef(
      catalogId: 'catalog',
      catalogVersion: '1',
      definitionKind: kind,
      definitionCode: code,
      definitionVersion: '1',
      definitionSchema: 'test.v1',
      contentSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      sourceRef: 'test',
    );

PowerDependencyKey _dep(String id) => PowerDependencyKey(
  projectId: 'project',
  revisionId: 'rev-1',
  kind: PowerDependencyKind.definition,
  entityId: id,
  purpose: 'INPUT',
);

Future<int> _revision(AppDatabase db) => db
    .customSelect(
      "SELECT revision FROM project_design_revisions WHERE id = 'rev-1'",
    )
    .getSingle()
    .then((row) => row.read<int>('revision'));

Future<(String, int)> _pointerState(AppDatabase db, PowerNodeKeyV2 node) => db
    .customSelect(
      'SELECT state, generation FROM power_evaluation_pointers '
      'WHERE design_revision_id = ? AND logical_node_key_sha256 = ?',
      variables: [
        Variable.withString('rev-1'),
        Variable.withString(node.sha256),
      ],
    )
    .getSingle()
    .then((row) => (row.read<String>('state'), row.read<int>('generation')));

Future<void> _seedPointer(
  AppDatabase db,
  PowerNodeKeyV2 node,
  PowerDependencyKey dependency,
) async {
  await runRawStatement(
    db,
    'INSERT INTO power_evaluation_pointers '
    '(project_id, design_revision_id, logical_node_key_json, logical_node_key_sha256, '
    'state, generation, evaluation_id, evidence_sha256, updated_at, origin_device_id) '
    "VALUES ('project', 'rev-1', ?, ?, 'CURRENT', 1, ?, ?, ?, 'test')",
    [
      Variable.withString(node.encode()),
      Variable.withString(node.sha256),
      Variable.withString('eval-${node.subjectId}'),
      Variable.withString(
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
      Variable<DateTime>(_now),
    ],
  );
  await runRawStatement(
    db,
    'INSERT INTO power_dependency_index_records '
    '(project_id, design_revision_id, dependency_ref_type, dependency_ref_json, '
    'dependency_ref_sha256, logical_node_key_json, logical_node_key_sha256, '
    'pointer_generation, updated_at, origin_device_id) '
    "VALUES ('project', 'rev-1', 'FACT', ?, ?, ?, ?, 1, ?, 'test')",
    [
      Variable.withString(dependency.encode()),
      Variable.withString(dependency.sha256),
      Variable.withString(node.encode()),
      Variable.withString(node.sha256),
      Variable<DateTime>(_now),
    ],
  );
}

Future<void> _seed(AppDatabase db) async {
  await runRawStatement(
    db,
    'INSERT INTO projects '
    '(id, name, reference, measurement_system, default_structural_height_mm, '
    'default_finished_ceiling_height_mm, revision, created_at, updated_at, '
    "deleted_at, origin_device_id) VALUES ('project', 'P2', '', 'metric', 3000, 2700, 1, ?, ?, NULL, 'test')",
    [Variable<DateTime>(_now), Variable<DateTime>(_now)],
  );
  await runRawStatement(
    db,
    'INSERT INTO floors '
    '(id, project_id, name, code, sort_order, revision, created_at, updated_at, deleted_at, origin_device_id) '
    "VALUES ('floor', 'project', 'Floor', 'F1', 1, 1, ?, ?, NULL, 'test')",
    [Variable<DateTime>(_now), Variable<DateTime>(_now)],
  );
  await runRawStatement(
    db,
    'INSERT INTO rooms '
    '(id, floor_id, name, room_type, room_category, width_mm, depth_mm, revision, '
    "created_at, updated_at, deleted_at, origin_device_id) VALUES ('room', 'floor', 'Room', "
    "'technical', 'technical', 5000, 5000, 1, ?, ?, NULL, 'test')",
    [Variable<DateTime>(_now), Variable<DateTime>(_now)],
  );
  await runRawStatement(
    db,
    'INSERT INTO surface_patches '
    '(id, room_id, surface_id, origin_xmm, origin_ymm, origin_zmm, u_axis_x, u_axis_y, '
    'u_axis_z, v_axis_x, v_axis_y, v_axis_z, orientation, boundary_json, revision, '
    "created_at, updated_at, deleted_at, origin_device_id) VALUES ('patch', 'room', 'wall', "
    "0,0,0,1,0,0,0,1,0,'WALL','[]',1,?,?,NULL,'test')",
    [Variable<DateTime>(_now), Variable<DateTime>(_now)],
  );
  for (final id in [
    'comp-load',
    'comp-source',
    'comp-bank',
    'comp-ups',
    'comp-charger',
  ]) {
    await runRawStatement(
      db,
      'INSERT INTO component_instances '
      '(id, definition_id, definition_version, room_id, host_surface_patch_id, local_xmm, '
      'local_ymm, rotation_radians, metadata_overrides_json, revision, created_at, updated_at, '
      'deleted_at, origin_device_id) VALUES (?, ?, 1, \'room\', \'patch\', 100, 100, 0, \'{}\', 1, ?, ?, NULL, \'test\')',
      [
        Variable.withString(id),
        Variable.withString('def-$id'),
        Variable<DateTime>(_now),
        Variable<DateTime>(_now),
      ],
    );
  }
  for (final entry
      in const {
        'p-load': 'comp-load',
        'p-source': 'comp-source',
        'p-out': 'comp-source',
        'p-bank': 'comp-bank',
      }.entries) {
    await runRawStatement(
      db,
      'INSERT INTO engineering_port_instances '
      '(id, project_id, component_id, code, payload_json, revision, created_at, updated_at, '
      'deleted_at, origin_device_id) VALUES (?, \'project\', ?, ?, \'{}\', 1, ?, ?, NULL, \'test\')',
      [
        Variable.withString(entry.key),
        Variable.withString(entry.value),
        Variable.withString(entry.key.toUpperCase()),
        Variable<DateTime>(_now),
        Variable<DateTime>(_now),
      ],
    );
  }
  await runRawStatement(
    db,
    'INSERT INTO project_design_revisions '
    '(id, project_id, code, sequence, state, revision, created_at, updated_at, deleted_at, origin_device_id) '
    "VALUES ('rev-1', 'project', 'R1', 1, 'WORKING', 1, ?, ?, NULL, 'test')",
    [Variable<DateTime>(_now), Variable<DateTime>(_now)],
  );
}
