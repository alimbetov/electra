import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/lan/elv5_lan_persistence.dart';
import '../../../application/elv5/persistence/elv5_replacement_persistence.dart';
import '../../../application/elv5/persistence/elv5_runtime_persistence.dart';
import '../../../application/elv_write_unit_of_work.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';
import 'drift_elv5_replacement_write_unit_of_work.dart';

final class DriftElv5LanWriteUnitOfWork implements Elv5LanWriteUnitOfWork {
  const DriftElv5LanWriteUnitOfWork(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<T> run<T>(Future<T> Function(Elv5LanWriteSession session) action) =>
      DriftElv5ReplacementWriteUnitOfWork(
        database,
        originDeviceId: originDeviceId,
      ).run(
        (replacement) => action(
          _Session(
            replacement,
            lan: _Store(database, originDeviceId: originDeviceId),
          ),
        ),
      );
}

final class _Session implements Elv5LanWriteSession {
  const _Session(this.replacement, {required this.lan});
  final Elv5ReplacementWriteSession replacement;
  @override
  ElvCommandLedgerStore get commandLedger => replacement.commandLedger;
  @override
  Elv5EvaluationStore get evaluations => replacement.evaluations;
  @override
  Elv5PointerStore get pointers => replacement.pointers;
  @override
  Elv5DependencyStore get dependencies => replacement.dependencies;
  @override
  Elv5RevisionMutationStore get revisions => replacement.revisions;
  @override
  Elv5RevisionHistoryStore get history => replacement.history;
  @override
  final Elv5LanMutationStore lan;
}

final class _Store implements Elv5LanMutationStore {
  const _Store(this.database, {required this.originDeviceId});
  static const _encoder = Elv5CanonicalJsonV1();
  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<Elv5LanAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) => switch (operation) {
    'REPLACE_LINK_COMPOSITION' => _loadLink(
      projectId,
      designRevisionId,
      subjectId,
    ),
    'REPLACE_PORT_CAPACITY_ASSIGNMENTS' => _loadPorts(
      projectId,
      designRevisionId,
      subjectId,
    ),
    'REPLACE_OPTICAL_LINK_ASSIGNMENTS' => _loadOptical(
      projectId,
      designRevisionId,
      subjectId,
    ),
    'REPLACE_PATCH_PANEL_ASSIGNMENTS' => _loadPatch(
      projectId,
      designRevisionId,
      subjectId,
    ),
    _ => throw FormatException('Unsupported LAN mutation: $operation.'),
  };

  @override
  Future<void> replace({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) => switch (operation) {
    'REPLACE_LINK_COMPOSITION' => _replaceLink(
      projectId,
      designRevisionId,
      subjectId,
      bindingId,
      expectedRootRevision,
      payload,
      updatedAtUtc,
    ),
    'REPLACE_PORT_CAPACITY_ASSIGNMENTS' => _replacePorts(
      projectId,
      designRevisionId,
      subjectId,
      bindingId,
      expectedRootRevision,
      payload,
      updatedAtUtc,
    ),
    'REPLACE_OPTICAL_LINK_ASSIGNMENTS' => _replaceOptical(
      projectId,
      designRevisionId,
      subjectId,
      bindingId,
      expectedRootRevision,
      payload,
      updatedAtUtc,
    ),
    'REPLACE_PATCH_PANEL_ASSIGNMENTS' => _replacePatch(
      projectId,
      designRevisionId,
      subjectId,
      bindingId,
      expectedRootRevision,
      payload,
      updatedAtUtc,
    ),
    _ => throw FormatException('Unsupported LAN mutation: $operation.'),
  };

  Future<Elv5LanAggregateSnapshot?> _loadLink(
    String p,
    String r,
    String id,
  ) async {
    final root = await _root(
      'link_composition_bindings',
      'link_id',
      p,
      r,
      id,
      'policy_binding_id',
    );
    if (root == null) return null;
    final binding = root.read<String>('id');
    final rows = await database
        .customSelect(
          'SELECT ordinal, realized_section_id, section_role FROM link_section_assignments '
          'WHERE project_id = ? AND design_revision_id = ? AND binding_id = ? ORDER BY ordinal',
          variables: [
            Variable.withString(p),
            Variable.withString(r),
            Variable.withString(binding),
          ],
        )
        .get();
    return Elv5LanAggregateSnapshot(
      aggregateKind: 'LAN_LINK_COMPOSITION',
      aggregateId: binding,
      subjectId: id,
      revision: root.read<int>('revision'),
      payload: {
        'linkId': id,
        'orderedSections': [
          for (final row in rows)
            {
              'ordinal': row.read<int>('ordinal'),
              'realizedSectionId': row.read<String>('realized_section_id'),
              'classification': row.read<String>('section_role'),
            },
        ],
        'policyBindingId': root.read<String>('policy_binding_id'),
      },
    );
  }

  Future<Elv5LanAggregateSnapshot?> _loadPorts(
    String p,
    String r,
    String id,
  ) async {
    final root = await _root(
      'port_capacity_bindings',
      'switch_id',
      p,
      r,
      id,
      'spare_policy_ref_json',
    );
    if (root == null) return null;
    final binding = root.read<String>('id');
    final rows = await database
        .customSelect(
          'SELECT endpoint_id, port_id, selected_mode FROM port_capacity_assignments '
          'WHERE project_id = ? AND design_revision_id = ? AND binding_id = ? ORDER BY port_id',
          variables: [
            Variable.withString(p),
            Variable.withString(r),
            Variable.withString(binding),
          ],
        )
        .get();
    return Elv5LanAggregateSnapshot(
      aggregateKind: 'LAN_PORT_CAPACITY',
      aggregateId: binding,
      subjectId: id,
      revision: root.read<int>('revision'),
      payload: {
        'switchId': id,
        'assignments': [
          for (final row in rows)
            {
              'portId': row.read<String>('port_id'),
              'endpointId': row.read<String>('endpoint_id'),
              ..._object(row.read<String>('selected_mode')),
            },
        ],
        'sparePolicyRef': jsonDecode(
          root.read<String>('spare_policy_ref_json'),
        ),
      },
    );
  }

  Future<Elv5LanAggregateSnapshot?> _loadOptical(
    String p,
    String r,
    String id,
  ) async {
    final root = await _root(
      'optical_link_bindings',
      'link_id',
      p,
      r,
      id,
      'forward_optics_json, reverse_optics_json',
    );
    if (root == null) return null;
    final binding = root.read<String>('id');
    final rows = await database
        .customSelect(
          'SELECT event_id, event_kind, loss_interval_json FROM optical_loss_events '
          'WHERE project_id = ? AND design_revision_id = ? AND binding_id = ? ORDER BY ordinal, event_id',
          variables: [
            Variable.withString(p),
            Variable.withString(r),
            Variable.withString(binding),
          ],
        )
        .get();
    List<Map<String, Object?>> events(String kind) => [
      for (final row in rows.where((e) => e.read<String>('event_kind') == kind))
        {
          'eventId': row.read<String>('event_id'),
          ..._object(row.read<String>('loss_interval_json')),
        },
    ];
    return Elv5LanAggregateSnapshot(
      aggregateKind: 'LAN_OPTICAL_LINK',
      aggregateId: binding,
      subjectId: id,
      revision: root.read<int>('revision'),
      payload: {
        'linkId': id,
        'forwardOptics': jsonDecode(root.read<String>('forward_optics_json')),
        'reverseOptics': jsonDecode(root.read<String>('reverse_optics_json')),
        'connectorEvents': events('CONNECTOR'),
        'spliceEvents': events('SPLICE'),
      },
    );
  }

  Future<Elv5LanAggregateSnapshot?> _loadPatch(
    String p,
    String r,
    String id,
  ) async {
    final root = await _root(
      'patch_panel_bindings',
      'panel_id',
      p,
      r,
      id,
      'spare_policy_ref_json',
    );
    if (root == null) return null;
    final binding = root.read<String>('id');
    final rows = await database
        .customSelect(
          'SELECT panel_port_id, endpoint_id, destination_ref_json FROM patch_panel_assignments '
          'WHERE project_id = ? AND design_revision_id = ? AND binding_id = ? ORDER BY panel_port_id',
          variables: [
            Variable.withString(p),
            Variable.withString(r),
            Variable.withString(binding),
          ],
        )
        .get();
    return Elv5LanAggregateSnapshot(
      aggregateKind: 'LAN_PATCH_PANEL',
      aggregateId: binding,
      subjectId: id,
      revision: root.read<int>('revision'),
      payload: {
        'panelId': id,
        'assignments': [
          for (final row in rows)
            {
              'panelPortId': row.read<String>('panel_port_id'),
              'terminationId': _object(
                row.read<String>('destination_ref_json'),
              )['terminationId'],
              'linkId': _object(
                row.read<String>('destination_ref_json'),
              )['linkId'],
            },
        ],
        'sparePolicyRef': jsonDecode(
          root.read<String>('spare_policy_ref_json'),
        ),
      },
    );
  }

  Future<QueryRow?> _root(
    String table,
    String subjectColumn,
    String p,
    String r,
    String id,
    String extra,
  ) => database
      .customSelect(
        'SELECT id, revision, $extra FROM $table WHERE project_id = ? '
        'AND design_revision_id = ? AND $subjectColumn = ? AND deleted_at IS NULL',
        variables: [
          Variable.withString(p),
          Variable.withString(r),
          Variable.withString(id),
        ],
      )
      .getSingleOrNull();

  Future<void> _replaceLink(
    String p,
    String r,
    String id,
    String b,
    int? rev,
    Map<String, Object?> payload,
    DateTime now,
  ) async {
    await _upsertRoot(
      table: 'link_composition_bindings',
      subjectColumn: 'link_id',
      p: p,
      r: r,
      subjectId: id,
      bindingId: b,
      expectedRevision: rev,
      now: now,
      insertColumns: 'policy_binding_id, composition_kind',
      insertValues: [
        Variable.withString(payload['policyBindingId']! as String),
        Variable.withString('ORDERED'),
      ],
      updateSet: 'policy_binding_id = ?, composition_kind = ?',
      updateValues: [
        Variable.withString(payload['policyBindingId']! as String),
        Variable.withString('ORDERED'),
      ],
    );
    await _deleteChildren('link_section_assignments', p, r, b);
    for (final raw in payload['orderedSections']! as List) {
      final row = Map<String, Object?>.from(raw as Map);
      await runRawStatement(
        database,
        'INSERT INTO link_section_assignments (project_id, design_revision_id, binding_id, ordinal, realized_section_id, section_role, evidence_json) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(p),
          Variable.withString(r),
          Variable.withString(b),
          Variable<int>(row['ordinal']! as int),
          Variable.withString(row['realizedSectionId']! as String),
          Variable.withString(row['classification']! as String),
          Variable.withString('{}'),
        ],
      );
    }
  }

  Future<void> _replacePorts(
    String p,
    String r,
    String id,
    String b,
    int? rev,
    Map<String, Object?> payload,
    DateTime now,
  ) async {
    final policy = _canonical(payload['sparePolicyRef']);
    await _upsertRoot(
      table: 'port_capacity_bindings',
      subjectColumn: 'switch_id',
      p: p,
      r: r,
      subjectId: id,
      bindingId: b,
      expectedRevision: rev,
      now: now,
      insertColumns: 'spare_policy_ref_json',
      insertValues: [Variable.withString(policy)],
      updateSet: 'spare_policy_ref_json = ?',
      updateValues: [Variable.withString(policy)],
    );
    await _deleteChildren('port_capacity_assignments', p, r, b);
    for (final raw in payload['assignments']! as List) {
      final row = Map<String, Object?>.from(raw as Map);
      final mode = _canonical({
        'media': row['media'],
        'speedBps': row['speedBps'],
      });
      await runRawStatement(
        database,
        'INSERT INTO port_capacity_assignments (project_id, design_revision_id, binding_id, endpoint_id, port_id, selected_mode) VALUES (?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(p),
          Variable.withString(r),
          Variable.withString(b),
          Variable.withString(row['endpointId']! as String),
          Variable.withString(row['portId']! as String),
          Variable.withString(mode),
        ],
      );
    }
  }

  Future<void> _replaceOptical(
    String p,
    String r,
    String id,
    String b,
    int? rev,
    Map<String, Object?> payload,
    DateTime now,
  ) async {
    final forward = _canonical(payload['forwardOptics']);
    final reverse = _canonical(payload['reverseOptics']);
    await _upsertRoot(
      table: 'optical_link_bindings',
      subjectColumn: 'link_id',
      p: p,
      r: r,
      subjectId: id,
      bindingId: b,
      expectedRevision: rev,
      now: now,
      insertColumns:
          'forward_optics_json, reverse_optics_json, policy_ref_json',
      insertValues: [
        Variable.withString(forward),
        Variable.withString(reverse),
        Variable<String>(null),
      ],
      updateSet: 'forward_optics_json = ?, reverse_optics_json = ?, policy_ref_json = ?',
      updateValues: [
        Variable.withString(forward),
        Variable.withString(reverse),
        Variable<String>(null),
      ],
    );
    await _deleteChildren('optical_loss_events', p, r, b);
    var ordinal = 0;
    for (final entry in const [
      ('connectorEvents', 'CONNECTOR'),
      ('spliceEvents', 'SPLICE'),
    ]) {
      for (final raw in payload[entry.$1]! as List) {
        final row = Map<String, Object?>.from(raw as Map);
        await runRawStatement(
          database,
          'INSERT INTO optical_loss_events (project_id, design_revision_id, binding_id, direction_code, event_id, event_kind, ordinal, loss_interval_json, evidence_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            Variable.withString(p),
            Variable.withString(r),
            Variable.withString(b),
            Variable.withString('BOTH'),
            Variable.withString(row['eventId']! as String),
            Variable.withString(entry.$2),
            Variable<int>(ordinal++),
            Variable.withString(
              _canonical({
                'lossMinDb': row['lossMinDb'],
                'lossMaxDb': row['lossMaxDb'],
              }),
            ),
            Variable.withString('{}'),
          ],
        );
      }
    }
  }

  Future<void> _replacePatch(
    String p,
    String r,
    String id,
    String b,
    int? rev,
    Map<String, Object?> payload,
    DateTime now,
  ) async {
    final policy = _canonical(payload['sparePolicyRef']);
    await _upsertRoot(
      table: 'patch_panel_bindings',
      subjectColumn: 'panel_id',
      p: p,
      r: r,
      subjectId: id,
      bindingId: b,
      expectedRevision: rev,
      now: now,
      insertColumns: 'spare_policy_ref_json',
      insertValues: [Variable.withString(policy)],
      updateSet: 'spare_policy_ref_json = ?',
      updateValues: [Variable.withString(policy)],
    );
    await _deleteChildren('patch_panel_assignments', p, r, b);
    for (final raw in payload['assignments']! as List) {
      final row = Map<String, Object?>.from(raw as Map);
      final destination = _canonical({
        'terminationId': row['terminationId'],
        'linkId': row['linkId'],
      });
      await runRawStatement(
        database,
        'INSERT INTO patch_panel_assignments (project_id, design_revision_id, binding_id, panel_port_id, endpoint_id, destination_ref_json) VALUES (?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(p),
          Variable.withString(r),
          Variable.withString(b),
          Variable.withString(row['panelPortId']! as String),
          Variable.withString(row['terminationId']! as String),
          Variable.withString(destination),
        ],
      );
    }
  }

  Future<void> _upsertRoot({
    required String table,
    required String subjectColumn,
    required String p,
    required String r,
    required String subjectId,
    required String bindingId,
    required int? expectedRevision,
    required DateTime now,
    required String insertColumns,
    required List<Variable> insertValues,
    required String updateSet,
    required List<Variable> updateValues,
  }) async {
    if (expectedRevision == null) {
      final placeholders = List.filled(insertValues.length, '?').join(', ');
      await runRawStatement(
        database,
        'INSERT INTO $table (project_id, design_revision_id, id, revision, created_at, updated_at, deleted_at, origin_device_id, $subjectColumn, $insertColumns) '
        'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, $placeholders)',
        [
          Variable.withString(p),
          Variable.withString(r),
          Variable.withString(bindingId),
          Variable<DateTime>(now.toUtc()),
          Variable<DateTime>(now.toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(subjectId),
          ...insertValues,
        ],
      );
      return;
    }
    final changed = await database.customUpdate(
      'UPDATE $table SET revision = revision + 1, updated_at = ?, origin_device_id = ?, $updateSet '
      'WHERE project_id = ? AND design_revision_id = ? AND id = ? AND $subjectColumn = ? AND revision = ? AND deleted_at IS NULL',
      variables: [
        Variable<DateTime>(now.toUtc()),
        Variable.withString(originDeviceId),
        ...updateValues,
        Variable.withString(p),
        Variable.withString(r),
        Variable.withString(bindingId),
        Variable.withString(subjectId),
        Variable<int>(expectedRevision),
      ],
    );
    if (changed != 1) throw StateError('ELV5_LAN_ROOT_CAS_CONFLICT');
  }

  Future<void> _deleteChildren(
    String table,
    String p,
    String r,
    String b,
  ) => database
      .customUpdate(
        'DELETE FROM $table WHERE project_id = ? AND design_revision_id = ? AND binding_id = ?',
        variables: [
          Variable.withString(p),
          Variable.withString(r),
          Variable.withString(b),
        ],
      )
      .then((_) {});

  Map<String, Object?> _object(String value) =>
      Map<String, Object?>.from(jsonDecode(value) as Map);
  String _canonical(Object? value) =>
      utf8.decode(_encoder.encode(value), allowMalformed: false);
}
