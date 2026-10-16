#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / 'apps/mobile/lib/data/database/app_database.dart'
POWER = ROOT / 'apps/mobile/lib/data/database/power_database_tables.dart'


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one anchor, found {count}: {old[:80]!r}')
    path.write_text(text.replace(old, new), encoding='utf-8')


replace_once(
    DB,
    "part 'elv_history_database_tables.dart';\n",
    "part 'elv_history_database_tables.dart';\npart 'discipline_database_tables.dart';\n",
)

new_tables = '''    DisciplinePolicyBindings,
    CameraStreamSetBindings,
    CameraStreamBindings,
    CameraStreamSubscriptions,
    RecordingPoolBindings,
    RecordingAssignments,
    RecordingScheduleSegments,
    RecorderCapacityBindings,
    RecorderAssignments,
    LinkCompositionBindings,
    LinkSectionAssignments,
    PortCapacityBindings,
    PortCapacityAssignments,
    OpticalLinkBindings,
    OpticalLossEvents,
    RackCapacityBindings,
    RackEquipmentMemberships,
    PatchPanelBindings,
    PatchPanelAssignments,
    DoorCalculationBindings,
    DoorRoleAssignments,
    DoorReleaseTruthRows,
    ControllerResourceBindings,
    ControllerResourceAssignments,
    FireLoopBindings,
    FireLoopDeviceAssignments,
    FireAddressClaims,
    NotificationCircuitBindings,
    NotificationCircuitAssignments,
    DisciplineEvaluationRecords,
    DisciplineEvaluationPointers,
    DisciplineDependencyIndex,
    DesignRevisionDisciplineSnapshots,
'''
replace_once(
    DB,
    '    ElvRevisionCommandHistoryExecutions,\n  ],\n',
    '    ElvRevisionCommandHistoryExecutions,\n' + new_tables + '  ],\n',
)
replace_once(DB, '  int get schemaVersion => 23;', '  int get schemaVersion => 24;')

migration24 = '''        if (from < 24) {
          await migrator.addColumn(
            designRevisionSnapshotManifests,
            designRevisionSnapshotManifests.disciplineSectionSchema,
          );
          await migrator.addColumn(
            designRevisionSnapshotManifests,
            designRevisionSnapshotManifests.disciplineSha256,
          );
          await migrator.createTable(disciplinePolicyBindings);
          await migrator.createTable(cameraStreamSetBindings);
          await migrator.createTable(cameraStreamBindings);
          await migrator.createTable(cameraStreamSubscriptions);
          await migrator.createTable(recordingPoolBindings);
          await migrator.createTable(recordingAssignments);
          await migrator.createTable(recordingScheduleSegments);
          await migrator.createTable(recorderCapacityBindings);
          await migrator.createTable(recorderAssignments);
          await migrator.createTable(linkCompositionBindings);
          await migrator.createTable(linkSectionAssignments);
          await migrator.createTable(portCapacityBindings);
          await migrator.createTable(portCapacityAssignments);
          await migrator.createTable(opticalLinkBindings);
          await migrator.createTable(opticalLossEvents);
          await migrator.createTable(rackCapacityBindings);
          await migrator.createTable(rackEquipmentMemberships);
          await migrator.createTable(patchPanelBindings);
          await migrator.createTable(patchPanelAssignments);
          await migrator.createTable(doorCalculationBindings);
          await migrator.createTable(doorRoleAssignments);
          await migrator.createTable(doorReleaseTruthRows);
          await migrator.createTable(controllerResourceBindings);
          await migrator.createTable(controllerResourceAssignments);
          await migrator.createTable(fireLoopBindings);
          await migrator.createTable(fireLoopDeviceAssignments);
          await migrator.createTable(fireAddressClaims);
          await migrator.createTable(notificationCircuitBindings);
          await migrator.createTable(notificationCircuitAssignments);
          await migrator.createTable(disciplineEvaluationRecords);
          await migrator.createTable(disciplineEvaluationPointers);
          await migrator.createTable(disciplineDependencyIndex);
          await migrator.createTable(designRevisionDisciplineSnapshots);
        }
'''
replace_once(
    DB,
    '''        if (from < 23) {
          await migrator.createTable(elvRevisionAggregateEvidenceRecords);
          await migrator.createTable(elvRevisionCommandHistoryOperations);
          await migrator.createTable(elvRevisionCommandHistoryCursors);
          await migrator.createTable(elvRevisionCommandHistoryExecutions);
        }
''',
    '''        if (from < 23) {
          await migrator.createTable(elvRevisionAggregateEvidenceRecords);
          await migrator.createTable(elvRevisionCommandHistoryOperations);
          await migrator.createTable(elvRevisionCommandHistoryCursors);
          await migrator.createTable(elvRevisionCommandHistoryExecutions);
        }
''' + migration24,
)

# The existing ELV4 guard call occurs once after upgrade and once in beforeOpen.
text = DB.read_text(encoding='utf-8')
anchor = '      await _createPowerIntegrityGuards();\n'
if text.count(anchor) != 2:
    raise SystemExit(f'app_database.dart: expected two power guard calls, found {text.count(anchor)}')
DB.write_text(
    text.replace(anchor, anchor + '      await _createDisciplineIndexesAndGuards();\n'),
    encoding='utf-8',
)

new_method = r'''

  Future<void> _createDisciplineIndexesAndGuards() async {
    const activeRootIndexes = <String, String>{
      'camera_stream_set_bindings': 'camera_id',
      'recording_pool_bindings': 'pool_id',
      'recorder_capacity_bindings': 'recorder_id',
      'link_composition_bindings': 'link_id',
      'port_capacity_bindings': 'switch_id',
      'optical_link_bindings': 'link_id',
      'rack_capacity_bindings': 'rack_id',
      'patch_panel_bindings': 'panel_id',
      'door_calculation_bindings': 'door_assembly_id',
      'controller_resource_bindings': 'controller_id',
      'fire_loop_bindings': 'loop_id',
      'notification_circuit_bindings': 'circuit_id',
    };
    for (final entry in activeRootIndexes.entries) {
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS ux_elv5_${entry.key}_active_subject '
        'ON ${entry.key}(design_revision_id, ${entry.value}) '
        'WHERE deleted_at IS NULL',
      );
    }

    const indexes = <String>[
      'CREATE INDEX IF NOT EXISTS idx_elv5_policy_subject ON discipline_policy_bindings(project_id, design_revision_id, subject_kind, subject_id)',
      'CREATE INDEX IF NOT EXISTS idx_elv5_camera_stream ON camera_stream_bindings(project_id, design_revision_id, camera_id, encoded_stream_id)',
      'CREATE INDEX IF NOT EXISTS idx_elv5_camera_subscription_stream ON camera_stream_subscriptions(project_id, design_revision_id, encoded_stream_id, receiver_id)',
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_elv5_recording_schedule_ordinal ON recording_schedule_segments(design_revision_id, binding_id, schedule_profile_id, ordinal)',
      'CREATE INDEX IF NOT EXISTS idx_elv5_recording_assignment_profile ON recording_assignments(project_id, design_revision_id, binding_id, schedule_profile_id)',
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_elv5_link_section_identity ON link_section_assignments(design_revision_id, binding_id, realized_section_id)',
      'CREATE INDEX IF NOT EXISTS idx_elv5_evaluation_process ON discipline_evaluation_records(project_id, design_revision_id, process_code)',
      'CREATE INDEX IF NOT EXISTS idx_elv5_evaluation_subject ON discipline_evaluation_records(project_id, design_revision_id, subject_kind, subject_id)',
      'CREATE INDEX IF NOT EXISTS idx_elv5_evaluation_input ON discipline_evaluation_records(input_fingerprint)',
      'CREATE INDEX IF NOT EXISTS idx_elv5_evaluation_output ON discipline_evaluation_records(output_sha256)',
      'CREATE INDEX IF NOT EXISTS idx_elv5_pointer_scope ON discipline_evaluation_pointers(project_id, design_revision_id, logical_node_key_sha256)',
      'CREATE INDEX IF NOT EXISTS idx_elv5_dependency_reverse ON discipline_dependency_index(project_id, design_revision_id, dependency_key_sha256)',
    ];
    for (final sql in indexes) {
      await customStatement(sql);
    }

    const scopedTables = <String>[
      'discipline_policy_bindings',
      'camera_stream_set_bindings',
      'camera_stream_bindings',
      'camera_stream_subscriptions',
      'recording_pool_bindings',
      'recording_assignments',
      'recording_schedule_segments',
      'recorder_capacity_bindings',
      'recorder_assignments',
      'link_composition_bindings',
      'link_section_assignments',
      'port_capacity_bindings',
      'port_capacity_assignments',
      'optical_link_bindings',
      'optical_loss_events',
      'rack_capacity_bindings',
      'rack_equipment_memberships',
      'patch_panel_bindings',
      'patch_panel_assignments',
      'door_calculation_bindings',
      'door_role_assignments',
      'door_release_truth_rows',
      'controller_resource_bindings',
      'controller_resource_assignments',
      'fire_loop_bindings',
      'fire_loop_device_assignments',
      'fire_address_claims',
      'notification_circuit_bindings',
      'notification_circuit_assignments',
      'discipline_evaluation_records',
      'discipline_evaluation_pointers',
      'discipline_dependency_index',
      'design_revision_discipline_snapshots',
    ];
    for (final table in scopedTables) {
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS trg_elv5_${table}_scope_insert '
        'BEFORE INSERT ON $table FOR EACH ROW '
        'WHEN NOT EXISTS ('
        'SELECT 1 FROM project_design_revisions r '
        'WHERE r.id = NEW.design_revision_id '
        'AND r.project_id = NEW.project_id '
        'AND r.deleted_at IS NULL) '
        "BEGIN SELECT RAISE(ABORT, 'ELV5_SCOPE_REVISION_PROJECT_MISMATCH'); END",
      );
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS trg_elv5_${table}_scope_update '
        'BEFORE UPDATE ON $table FOR EACH ROW '
        'WHEN NOT EXISTS ('
        'SELECT 1 FROM project_design_revisions r '
        'WHERE r.id = NEW.design_revision_id '
        'AND r.project_id = NEW.project_id '
        'AND r.deleted_at IS NULL) '
        "BEGIN SELECT RAISE(ABORT, 'ELV5_SCOPE_REVISION_PROJECT_MISMATCH'); END",
      );
    }

    const childRoots = <String, String>{
      'recording_assignments': 'recording_pool_bindings',
      'recording_schedule_segments': 'recording_pool_bindings',
      'recorder_assignments': 'recorder_capacity_bindings',
      'link_section_assignments': 'link_composition_bindings',
      'port_capacity_assignments': 'port_capacity_bindings',
      'optical_loss_events': 'optical_link_bindings',
      'rack_equipment_memberships': 'rack_capacity_bindings',
      'patch_panel_assignments': 'patch_panel_bindings',
      'door_role_assignments': 'door_calculation_bindings',
      'door_release_truth_rows': 'door_calculation_bindings',
      'controller_resource_assignments': 'controller_resource_bindings',
      'fire_loop_device_assignments': 'fire_loop_bindings',
      'notification_circuit_assignments': 'notification_circuit_bindings',
    };
    for (final entry in childRoots.entries) {
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS trg_elv5_${entry.key}_root_insert '
        'BEFORE INSERT ON ${entry.key} FOR EACH ROW '
        'WHEN NOT EXISTS ('
        'SELECT 1 FROM ${entry.value} r '
        'WHERE r.project_id = NEW.project_id '
        'AND r.design_revision_id = NEW.design_revision_id '
        'AND r.id = NEW.binding_id '
        'AND r.deleted_at IS NULL) '
        "BEGIN SELECT RAISE(ABORT, 'ELV5_BINDING_SCOPE_MISMATCH'); END",
      );
    }

    for (final table in const <String>[
      'camera_stream_bindings',
      'camera_stream_subscriptions',
    ]) {
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS trg_elv5_${table}_root_insert '
        'BEFORE INSERT ON $table FOR EACH ROW '
        'WHEN NOT EXISTS ('
        'SELECT 1 FROM camera_stream_set_bindings r '
        'WHERE r.project_id = NEW.project_id '
        'AND r.design_revision_id = NEW.design_revision_id '
        'AND r.id = NEW.binding_id '
        'AND r.camera_id = NEW.camera_id '
        'AND r.deleted_at IS NULL) '
        "BEGIN SELECT RAISE(ABORT, 'ELV5_CAMERA_BINDING_SCOPE_MISMATCH'); END",
      );
    }

    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS trg_elv5_fire_claim_membership_insert '
      'BEFORE INSERT ON fire_address_claims FOR EACH ROW '
      'WHEN NEW.address < 0 OR NOT EXISTS ('
      'SELECT 1 FROM fire_loop_device_assignments d '
      'WHERE d.project_id = NEW.project_id '
      'AND d.design_revision_id = NEW.design_revision_id '
      'AND d.binding_id = NEW.binding_id '
      'AND d.device_id = NEW.device_id) '
      "BEGIN SELECT RAISE(ABORT, 'ELV5_FIRE_ADDRESS_MEMBERSHIP_INVALID'); END",
    );

    for (final table in const <String>[
      'discipline_evaluation_records',
      'design_revision_discipline_snapshots',
    ]) {
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS trg_elv5_${table}_immutable_update '
        'BEFORE UPDATE ON $table '
        "BEGIN SELECT RAISE(ABORT, 'ELV5_IMMUTABLE_EVIDENCE'); END",
      );
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS trg_elv5_${table}_immutable_delete '
        'BEFORE DELETE ON $table '
        "BEGIN SELECT RAISE(ABORT, 'ELV5_IMMUTABLE_EVIDENCE'); END",
      );
    }
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS trg_elv5_pointer_generation_insert '
      'BEFORE INSERT ON discipline_evaluation_pointers FOR EACH ROW '
      'WHEN NEW.generation < 0 '
      "BEGIN SELECT RAISE(ABORT, 'ELV5_POINTER_GENERATION_INVALID'); END",
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS trg_elv5_pointer_generation_monotonic '
      'BEFORE UPDATE ON discipline_evaluation_pointers FOR EACH ROW '
      'WHEN NEW.generation < OLD.generation '
      "BEGIN SELECT RAISE(ABORT, 'ELV5_POINTER_GENERATION_REGRESSION'); END",
    );
  }
'''

text = DB.read_text(encoding='utf-8')
pos = text.rfind('\n}')
if pos < 0 or '_createDisciplineIndexesAndGuards' in text[:pos]:
    raise SystemExit('app_database.dart: cannot place discipline guard method safely')
DB.write_text(text[:pos] + new_method + text[pos:], encoding='utf-8')

replace_once(
    POWER,
    '  TextColumn get powerSha256 => text()();\n  DateTimeColumn get createdAt => dateTime()();\n',
    '  TextColumn get powerSha256 => text()();\n'
    '  TextColumn get disciplineSectionSchema => text().nullable()();\n'
    '  TextColumn get disciplineSha256 => text().nullable()();\n'
    '  DateTimeColumn get createdAt => dateTime()();\n',
)

print('ELV5 schema-24 AppDatabase patch applied')
