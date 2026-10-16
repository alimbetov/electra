import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../database/app_database.dart';
import 'drift_engineering_topology_repository.dart';
import 'drift_power_publication_runtime.dart';
import 'drift_power_runtime_store.dart';

final class PowerCanonicalProjectionReview {
  PowerCanonicalProjectionReview({
    required this.projectId,
    required this.designRevisionId,
    required this.portId,
    required this.expectedDesignRevision,
    required this.expectedPortRevision,
    required this.beforePayload,
    required this.candidatePayload,
    required Iterable<String> affectedConnectionIds,
    required Iterable<String> affectedInternalIds,
    required Iterable<String> affectedGroupIds,
    required Iterable<PowerDependencyKey> oldClosure,
    required Iterable<PowerDependencyKey> newClosure,
    required this.reviewedImpactFingerprint,
  }) : affectedConnectionIds = List.unmodifiable(
         affectedConnectionIds.toList()..sort(),
       ),
       affectedInternalIds = List.unmodifiable(
         affectedInternalIds.toList()..sort(),
       ),
       affectedGroupIds = List.unmodifiable(affectedGroupIds.toList()..sort()),
       oldClosure = List.unmodifiable(oldClosure.toSet().toList()..sort()),
       newClosure = List.unmodifiable(newClosure.toSet().toList()..sort());

  final String projectId;
  final String designRevisionId;
  final String portId;
  final int expectedDesignRevision;
  final int expectedPortRevision;
  final Map<String, Object?> beforePayload;
  final Map<String, Object?> candidatePayload;
  final List<String> affectedConnectionIds;
  final List<String> affectedInternalIds;
  final List<String> affectedGroupIds;
  final List<PowerDependencyKey> oldClosure;
  final List<PowerDependencyKey> newClosure;
  final String reviewedImpactFingerprint;
}

/// RM03 reviewed positive path for changing static canonical fields owned by an
/// ELV4 power binding.
///
/// Direct ELV1 writers remain fail-closed for power-owned ports. This store is
/// the deliberate exception: it validates field ownership, the whole connected
/// candidate graph and optimistic row/design revisions before mutating the
/// canonical port. It then invalidates the exact old/new dependency union in
/// the same SQLite transaction as the canonical write and design-token CAS.
final class DriftPowerCanonicalProjectionWriteStore {
  DriftPowerCanonicalProjectionWriteStore(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       publicationRuntime = DriftPowerPublicationRuntime(
         database,
         originDeviceId: originDeviceId,
         now: now,
       );

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() now;
  final DriftPowerPublicationRuntime publicationRuntime;

  Future<PowerCanonicalProjectionReview> preview({
    required String projectId,
    required String designRevisionId,
    required EngineeringPort candidate,
    required PowerPortBinding binding,
  }) async {
    if (candidate.id != binding.portId) {
      throw const PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_PORT_MISMATCH',
      );
    }
    final revision = await _workingRevision(projectId, designRevisionId);
    final row = await _portRow(projectId, candidate.id);
    final before = EngineeringPort.fromMap(
      (jsonDecode(row.read<String>('payload_json')) as Map)
          .cast<String, dynamic>(),
    );
    if (before.componentId != candidate.componentId) {
      throw const PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_COMPONENT_MOVE_FORBIDDEN',
      );
    }
    final validation = candidate.validate();
    if (validation.isNotEmpty) {
      throw PowerRuntimeStorageException('ELV4_POWER_PROJECTION_PORT_INVALID', {
        'findings': validation,
      });
    }

    _validateOwnedProjection(before, candidate, binding);

    final topology = DriftEngineeringTopologyRepository(
      database,
      originDeviceId: originDeviceId,
    );
    final snapshot = await topology.load(projectId);
    final graph = snapshot.graph(port: candidate);
    final connections = snapshot.connections
        .where(
          (value) =>
              value.fromPortId == candidate.id ||
              value.toPortId == candidate.id,
        )
        .toList(growable: false);
    final internals = snapshot.internalLinks
        .where(
          (value) =>
              value.fromPortId == candidate.id ||
              value.toPortId == candidate.id,
        )
        .toList(growable: false);
    final connectionIds = connections.map((value) => value.id).toSet();
    final groups = snapshot.groups
        .where(
          (value) =>
              value.startPortId == candidate.id ||
              value.endPortId == candidate.id ||
              snapshot.connections.any(
                (connection) =>
                    connection.groupId == value.id &&
                    connectionIds.contains(connection.id),
              ),
        )
        .toList(growable: false);

    final findings = <TopologyFinding>[
      ...graph.portFindings(candidate),
      for (final connection in connections)
        ...graph.connectionFindings(connection),
      for (final mapping in internals) ...graph.internalFindings(mapping),
      for (final group in groups) ...graph.groupFindings(group),
    ];
    if (findings.isNotEmpty) {
      throw PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_GRAPH_REJECTED',
        {
          'findings': [
            for (final finding in findings)
              '${finding.code}: ${finding.message}',
          ],
        },
      );
    }

    final oldClosure = _closure(
      projectId: projectId,
      designRevisionId: designRevisionId,
      port: before,
      connections: connections,
      internals: internals,
      groups: groups,
    );
    final newClosure = _closure(
      projectId: projectId,
      designRevisionId: designRevisionId,
      port: candidate,
      connections: connections,
      internals: internals,
      groups: groups,
    );
    final beforePayload = before.toMap();
    final candidatePayload = candidate.toMap();
    final fingerprint = sha256HexUtf8(
      canonicalEngineeringJsonV1({
        'schema': 'electra.elv4-reviewed-canonical-projection.v1',
        'projectId': projectId,
        'designRevisionId': designRevisionId,
        'expectedDesignRevision': revision,
        'portId': candidate.id,
        'expectedPortRevision': row.read<int>('revision'),
        'before': beforePayload,
        'candidate': candidatePayload,
        'binding': binding.toMap(),
        'connections': connectionIds.toList()..sort(),
        'internals': internals.map((value) => value.id).toList()..sort(),
        'groups': groups.map((value) => value.id).toList()..sort(),
        'oldClosure': oldClosure.map((value) => value.encode()).toList(),
        'newClosure': newClosure.map((value) => value.encode()).toList(),
      }),
    );

    return PowerCanonicalProjectionReview(
      projectId: projectId,
      designRevisionId: designRevisionId,
      portId: candidate.id,
      expectedDesignRevision: revision,
      expectedPortRevision: row.read<int>('revision'),
      beforePayload: Map.unmodifiable(beforePayload),
      candidatePayload: Map.unmodifiable(candidatePayload),
      affectedConnectionIds: connectionIds,
      affectedInternalIds: internals.map((value) => value.id),
      affectedGroupIds: groups.map((value) => value.id),
      oldClosure: oldClosure,
      newClosure: newClosure,
      reviewedImpactFingerprint: fingerprint,
    );
  }

  Future<PowerInvalidationReceipt> applyReviewedProjection({
    required PowerCanonicalProjectionReview review,
    required EngineeringPort candidate,
    required PowerPortBinding binding,
  }) async {
    final fresh = await preview(
      projectId: review.projectId,
      designRevisionId: review.designRevisionId,
      candidate: candidate,
      binding: binding,
    );
    if (fresh.reviewedImpactFingerprint != review.reviewedImpactFingerprint ||
        fresh.expectedDesignRevision != review.expectedDesignRevision ||
        fresh.expectedPortRevision != review.expectedPortRevision) {
      throw const PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_STALE_REVIEW',
      );
    }

    return publicationRuntime.mutateAndInvalidate(
      projectId: review.projectId,
      designRevisionId: review.designRevisionId,
      oldClosure: fresh.oldClosure,
      applyMutation: () async {
        final changed = await database.customUpdate(
          'UPDATE engineering_port_instances '
          'SET payload_json = ?, revision = revision + 1, updated_at = ?, '
          'origin_device_id = ? '
          'WHERE project_id = ? AND id = ? AND deleted_at IS NULL '
          'AND revision = ?',
          variables: [
            Variable.withString(canonicalEngineeringJson(candidate.toMap())),
            Variable<DateTime>(now().toUtc()),
            Variable.withString(originDeviceId),
            Variable.withString(review.projectId),
            Variable.withString(review.portId),
            Variable.withInt(review.expectedPortRevision),
          ],
        );
        if (changed != 1) {
          throw const PowerRuntimeStorageException(
            'ELV4_POWER_PROJECTION_PORT_CAS_FAILED',
          );
        }
        final token = await database.customUpdate(
          'UPDATE project_design_revisions '
          'SET revision = revision + 1, updated_at = ?, origin_device_id = ? '
          'WHERE project_id = ? AND id = ? AND state = ? '
          'AND deleted_at IS NULL AND revision = ?',
          variables: [
            Variable<DateTime>(now().toUtc()),
            Variable.withString(originDeviceId),
            Variable.withString(review.projectId),
            Variable.withString(review.designRevisionId),
            Variable.withString('WORKING'),
            Variable.withInt(review.expectedDesignRevision),
          ],
        );
        if (token != 1) {
          throw const PowerRuntimeStorageException(
            'ELV4_POWER_PROJECTION_DESIGN_CAS_FAILED',
          );
        }
      },
      captureNewClosure: () async {
        final after = await preview(
          projectId: review.projectId,
          designRevisionId: review.designRevisionId,
          candidate: candidate,
          binding: binding,
        );
        return after.newClosure;
      },
    );
  }

  Future<int> _workingRevision(
    String projectId,
    String designRevisionId,
  ) async {
    final row =
        await database
            .customSelect(
              'SELECT revision, state FROM project_design_revisions '
              'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
              variables: [
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
              ],
            )
            .getSingleOrNull();
    if (row == null) {
      throw const PowerRuntimeStorageException('ELV4_REVISION_NOT_FOUND');
    }
    if (row.read<String>('state') != 'WORKING') {
      throw const PowerRuntimeStorageException('ELV4_REVISION_NOT_WORKING');
    }
    return row.read<int>('revision');
  }

  Future<QueryRow> _portRow(String projectId, String portId) async {
    final row =
        await database
            .customSelect(
              'SELECT revision, payload_json FROM engineering_port_instances '
              'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
              variables: [
                Variable.withString(projectId),
                Variable.withString(portId),
              ],
              readsFrom: database.allTables.toSet(),
            )
            .getSingleOrNull();
    if (row == null) {
      throw const PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_PORT_NOT_FOUND',
      );
    }
    return row;
  }

  void _validateOwnedProjection(
    EngineeringPort before,
    EngineeringPort candidate,
    PowerPortBinding binding,
  ) {
    final beforeMap =
        Map<String, Object?>.from(before.toMap())
          ..remove('voltage')
          ..remove('powerDirection');
    final candidateMap =
        Map<String, Object?>.from(candidate.toMap())
          ..remove('voltage')
          ..remove('powerDirection');
    if (canonicalEngineeringJson(beforeMap) !=
        canonicalEngineeringJson(candidateMap)) {
      throw const PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_UNOWNED_STATIC_FIELD',
      );
    }

    final currentKindChanged =
        before.voltage?.currentKind != candidate.voltage?.currentKind;
    final voltageChanged =
        before.voltage?.minimumV != candidate.voltage?.minimumV ||
        before.voltage?.maximumV != candidate.voltage?.maximumV;
    final directionChanged = before.powerDirection != candidate.powerDirection;

    void requireElv4Owner(PowerProjectionField field) {
      final owner = binding.ownership.ownerOf(field);
      if (owner == null || owner.ownerKind != PowerProjectionOwnerKind.elv4) {
        throw PowerRuntimeStorageException(
          'ELV4_POWER_PROJECTION_FIELD_NOT_OWNED',
          {'field': field.name},
        );
      }
    }

    if (currentKindChanged) requireElv4Owner(PowerProjectionField.currentKind);
    if (voltageChanged) requireElv4Owner(PowerProjectionField.voltageEnvelope);
    if (directionChanged) requireElv4Owner(PowerProjectionField.powerDirection);

    final voltage = candidate.voltage;
    if (voltage == null) {
      throw const PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_VOLTAGE_REQUIRED',
      );
    }
    final expectedKind = switch (binding.voltageEnvelope.currentKind) {
      PowerCurrentKind.ac => PortCurrentKind.ac,
      PowerCurrentKind.dc => PortCurrentKind.dc,
    };
    final expectedMin =
        binding.voltageEnvelope.minV.numerator.toDouble() /
        binding.voltageEnvelope.minV.denominator.toDouble();
    final expectedMax =
        binding.voltageEnvelope.maxV.numerator.toDouble() /
        binding.voltageEnvelope.maxV.denominator.toDouble();
    if (voltage.currentKind != expectedKind ||
        voltage.minimumV != expectedMin ||
        voltage.maximumV != expectedMax) {
      throw const PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_BINDING_MISMATCH',
      );
    }
    final expectedDirection = switch (binding.role) {
      PowerPortRole.source => PortDirection.output,
      PowerPortRole.consumer => PortDirection.input,
      PowerPortRole.bidirectional => PortDirection.bidirectional,
      PowerPortRole.passive => candidate.direction,
    };
    if (candidate.powerDirection != expectedDirection) {
      throw const PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_DIRECTION_MISMATCH',
      );
    }
  }

  List<PowerDependencyKey> _closure({
    required String projectId,
    required String designRevisionId,
    required EngineeringPort port,
    required Iterable<EngineeringConnection> connections,
    required Iterable<InternalConnectivity> internals,
    required Iterable<TopologyGroup> groups,
  }) {
    final result = <PowerDependencyKey>[
      PowerDependencyKey(
        projectId: projectId,
        revisionId: designRevisionId,
        kind: PowerDependencyKind.definition,
        entityId: 'PORT-${port.id}',
        purpose: 'INPUT',
      ),
      PowerDependencyKey(
        projectId: projectId,
        revisionId: designRevisionId,
        kind: PowerDependencyKind.definition,
        entityId: 'COMPONENT-${port.componentId}',
        purpose: 'INPUT',
      ),
      for (final connection in connections)
        PowerDependencyKey(
          projectId: projectId,
          revisionId: designRevisionId,
          kind: PowerDependencyKind.pathStage,
          entityId: connection.id,
          purpose: 'INPUT',
        ),
      for (final mapping in internals)
        PowerDependencyKey(
          projectId: projectId,
          revisionId: designRevisionId,
          kind: PowerDependencyKind.pathStage,
          entityId: mapping.id,
          purpose: 'INPUT',
        ),
      for (final group in groups)
        PowerDependencyKey(
          projectId: projectId,
          revisionId: designRevisionId,
          kind: PowerDependencyKind.groupMembership,
          entityId: group.id,
          purpose: 'INPUT',
        ),
    ]..sort();
    return result;
  }
}
