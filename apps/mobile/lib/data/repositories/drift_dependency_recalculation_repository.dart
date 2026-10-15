import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/dependency_recalculation_repository.dart';
import '../database/app_database.dart';
import 'drift_project_hierarchy_repository.dart';
import 'drift_floor_routing_repository.dart';
import 'drift_electrical_load_repository.dart';

class DriftDependencyRecalculationRepository
    implements DependencyRecalculationRepository {
  DriftDependencyRecalculationRepository(
    this.database, {
    required this.originDeviceId,
  });
  final AppDatabase database;
  final String originDeviceId;
  @override
  Stream<ProjectRecalculationSnapshot> watch(String projectId) => database
      .customSelect(
        'SELECT id, revision FROM projects WHERE id = ?',
        variables: [Variable.withString(projectId)],
        readsFrom: database.allTables.toSet(),
      )
      .watch()
      .asyncMap((_) => load(projectId));
  static RecalculationCache decode(
    ProjectDerivedResultRow r, {
    bool restored = false,
  }) => RecalculationCache(
    key: r.nodeKey,
    fingerprint: restored ? "${r.fingerprint}:retired" : r.fingerprint,
    inputsJson: r.inputsJson,
    dependenciesJson: r.dependenciesJson,
    resultJson: r.resultJson,
    state: EngineeringDerivedState.values.byName(r.state),
    previousResultJson: r.previousResultJson,
    changesJson: r.changesJson,
    manualValue: r.manualValue,
    manualReason: r.manualReason,
    manualReviewedFingerprint: restored ? null : r.manualReviewedFingerprint,
  );
  static Map<String, Object?> semantic(Map<String, dynamic> row) =>
      Map<String, Object?>.from(row)..removeWhere(
        (key, _) => [
          'revision',
          'createdAt',
          'updatedAt',
          'deletedAt',
          'originDeviceId',
          'name',
          'code',
          'surfaceId',
        ].contains(key),
      );

  @override
  Future<ProjectRecalculationSnapshot> load(
    String projectId,
  ) => database.transaction(() async {
    final project = await DriftProjectHierarchyRepository(database)
        .findProject(projectId);
    if (project == null)
      return ProjectRecalculationSnapshot(
        project: null,
        session: RecalculationSession(nodes: const []),
      );
    final rows = await (database.select(
      database.projectDerivedResults,
    )..where((r) => r.projectId.equals(projectId))).get();
    final cache = rows.where((r) => r.deletedAt == null).map(decode).toList();
    final nodes = <String, RecalculationNode>{};
    void add(
      String key,
      String label,
      String version,
      Map<String, Object?> inputs,
      List<String> dependencies,
      DependencyProposal Function(Map<String, DependencyProposal>) evaluate,
    ) {
      nodes[key] = RecalculationNode(
        key: key,
        label: label,
        version: version,
        inputs: inputs,
        dependencies: dependencies.toSet().toList()..sort(),
        evaluate: evaluate,
      );
    }

    final normRows = await (database.select(
      database.normativeDocuments,
    )..where((r) => r.deletedAt.isNull())).get();
    final norms = {
      for (final row in normRows)
        row.id: NormativeDocument.fromMap(
          jsonDecode(row.payloadJson) as Map<String, dynamic>,
        ),
    };
    final ruleRows =
        await (database.select(database.protectionRulesets)..where(
              (r) => r.projectId.equals(projectId) & r.deletedAt.isNull(),
            ))
            .get();
    final rules = {
      for (final row in ruleRows)
        row.id: ProtectionRuleset.fromMap(
          jsonDecode(row.payloadJson) as Map<String, dynamic>,
        ),
    };
    // Only assigned rules are graph sources; merely browsing the catalog changes no result.
    final floors =
        await (database.select(database.floors)
              ..where(
                (r) => r.projectId.equals(projectId) & r.deletedAt.isNull(),
              )
              ..orderBy([(r) => OrderingTerm.asc(r.id)]))
            .get();
    for (final floor in floors) {
      final snapshot = await DriftFloorRoutingRepository(
        database,
        originDeviceId: originDeviceId,
      ).load(floor.id);
      final floorGraph = snapshot.graph();
      final generationGroups = <RoomConsumptionGroup>[];
      final generationLoads = <EquipmentElectricalLoad>[];
      for (final room in snapshot.rooms) {
        final routing = snapshot.routing[room.id]!;
        final circuitRows =
            await (database.select(database.electricalCircuits)
                  ..where(
                    (r) => r.roomId.equals(room.id) & r.deletedAt.isNull(),
                  )
                  ..orderBy([(r) => OrderingTerm.asc(r.id)]))
                .get();
        final assignments =
            await (database.select(database.circuitLoadAssignments)
                  ..where((r) => r.circuitId.isIn(circuitRows.map((r) => r.id)))
                  ..orderBy([(r) => OrderingTerm.asc(r.componentInstanceId)]))
                .get();
        final circuits = circuitRows
            .map(
              (row) => ElectricalCircuit(
                id: row.id,
                roomId: row.roomId,
                name: row.name,
                inputs: ElectricalCircuitInputs(
                  nominalVoltageV: row.nominalVoltageV,
                  phases: row.phases,
                  supplySystem: SupplySystem.values.byName(row.supplySystem),
                  demandFactor: row.demandFactor,
                ),
                loadIds: assignments
                    .where((a) => a.circuitId == row.id)
                    .map((a) => a.componentInstanceId),
              ),
            )
            .toList();
        final activeLoads = await DriftElectricalLoadRepository(
          database,
          originDeviceId: originDeviceId,
        ).loadRoomLoads(room.id);
        generationLoads.addAll(activeLoads);
        generationGroups.addAll(
          await DriftElectricalLoadRepository(
            database,
            originDeviceId: originDeviceId,
          ).loadRoomGroups(room.id),
        );
        final ids = {
          ...activeLoads.map((l) => l.componentInstanceId),
          ...circuits.expand((c) => c.loadIds),
        };
        for (final id in ids) {
          final row = await (database.select(
            database.equipmentElectricalLoads,
          )..where((r) => r.componentInstanceId.equals(id))).getSingleOrNull();
          final available = activeLoads.any((l) => l.componentInstanceId == id);
          final inputs = row == null || !available
              ? <String, Object?>{'available': false}
              : (semantic(row.toJson())
                  ..remove('consumptionGroupId')
                  ..['available'] = true);
          add(
            'consumer:$id',
            '${room.name} · Load $id',
            'fl12-load-v1',
            inputs,
            [],
            (_) => DependencyProposal(
              values: inputs,
              issues: available ? [] : ['Load is unavailable.'],
            ),
          );
        }
        final patchIds = routing.geometry.patches.map((p) => p.id).toSet();
        // Sources are patch-scoped, so an unrelated wall does not invalidate other routes.
        final patches = await (database.select(
          database.surfacePatches,
        )..where((r) => r.id.isIn(patchIds))).get();
        final edges = await (database.select(
          database.surfaceEdges,
        )..where((r) => r.patchId.isIn(patchIds) & r.deletedAt.isNull())).get();
        final adjacencies =
            await (database.select(database.surfaceAdjacencies)..where(
                  (r) => r.fromPatchId.isIn(patchIds) & r.deletedAt.isNull(),
                ))
                .get();
        final openings =
            await (database.select(database.openings)..where(
                  (r) =>
                      r.hostSurfacePatchId.isIn(patchIds) &
                      r.deletedAt.isNull(),
                ))
                .get();
        for (final patch in patches) {
          List<Map<String, Object?>> sortedRows(
            Iterable<Map<String, dynamic>> rows,
          ) {
            final items = rows.map(semantic).toList()
              ..sort(
                (a, b) => (a['id'] as String).compareTo(b['id'] as String),
              );
            return items;
          }

          final inputs = <String, Object?>{
            'patch': semantic(patch.toJson()),
            'edges': sortedRows(
              edges.where((e) => e.patchId == patch.id).map((e) => e.toJson()),
            ),
            'adjacencies': sortedRows(
              adjacencies
                  .where(
                    (a) => a.fromPatchId == patch.id || a.toPatchId == patch.id,
                  )
                  .map((a) => a.toJson()),
            ),
            'openings': sortedRows(
              openings
                  .where((o) => o.hostSurfacePatchId == patch.id)
                  .map((o) => o.toJson()),
            ),
          };
          add(
            'geometry:${patch.id}',
            '${room.name} · Surface ${patch.id}',
            'fl12-geometry-v1',
            inputs,
            [],
            (_) => DependencyProposal(values: {'available': true}),
          );
        }
        for (final channel in routing.channels) {
          add(
            'channel:${channel.id}',
            channel.name,
            'fl12-channel-v1',
            {'roomId': channel.roomId, 'kind': channel.kind.name},
            [],
            (_) => DependencyProposal(values: {'kind': channel.kind.name}),
          );
        }
        for (final c in circuits) {
          add(
            'circuit:${c.id}',
            c.name,
            CircuitCalculation.algorithmVersion,
            {
              'roomId': c.roomId,
              'voltageV': c.inputs.nominalVoltageV,
              'phases': c.inputs.phases,
              'supplySystem': c.inputs.supplySystem.name,
              'demandFactor': c.inputs.demandFactor,
            },
            [for (final id in c.loadIds) 'consumer:$id'],
            (_) {
              final calculation = CircuitCurrentCalculator.calculate(
                c,
                activeLoads,
              );
              return DependencyProposal(
                values: {'designCurrentA': calculation.designCurrentA},
                issues: calculation.issues.map((i) => i.message),
              );
            },
          );
          final settingRow =
              await (database.select(database.circuitProtectionSettings)..where(
                    (r) => r.circuitId.equals(c.id) & r.deletedAt.isNull(),
                  ))
                  .getSingleOrNull();
          final settings = settingRow == null
              ? CircuitProtectionInputs(circuitId: c.id)
              : CircuitProtectionInputs.fromMap(
                  jsonDecode(settingRow.inputsJson) as Map<String, dynamic>,
                );
          final ruleset = rules[settings.rulesetId],
              norm = norms[ruleset?.normativeDocumentId];
          if (ruleset != null) {
            if (norm != null)
              add(
                'normative:${norm.id}',
                norm.title,
                'fl13-normative-v1',
                norm.toMap(),
                [],
                (_) => DependencyProposal(values: norm.toMap()),
              );
            add(
              'ruleset:${ruleset.id}',
              ruleset.reference.id,
              'fl13-ruleset-v1',
              ruleset.toMap(),
              ['normative:${ruleset.normativeDocumentId}'],
              (_) => DependencyProposal(values: ruleset.toMap()),
            );
          }
          add(
            'protection:${c.id}',
            '${c.name} · Protection requirement',
            ProtectionRequirementPlanner.algorithmVersion,
            settings.toMap(),
            [
              'circuit:${c.id}',
              for (final run in routing.runs.where((r) => r.circuitId == c.id))
                'cable:${run.id}',
              if (settings.rulesetId != null) 'ruleset:${settings.rulesetId}',
            ],
            (deps) {
              final proposal = ProtectionRequirementPlanner.propose(
                settings: settings,
                ruleset: ruleset,
                normativeDocument: norm,
                designCurrentA:
                    (deps['circuit:${c.id}']!.values['designCurrentA'] as num?)
                        ?.toDouble(),
                nominalVoltageV: c.inputs.nominalVoltageV,
                phases: c.inputs.phases,
                supplySystem: c.inputs.supplySystem,
              );
              return DependencyProposal(
                values: proposal.toMap(),
                issues: proposal.issues,
                requiresReview: !proposal.ready,
              );
            },
          );
        }
        for (final route in routing.routes) {
          final dependencies = <String>[
            for (final n in route.nodes) ...[
              'geometry:${n.anchor.patchId}',
              if (n.otherAnchor != null) 'geometry:${n.otherAnchor!.patchId}',
            ],
            for (final s in route.segments)
              if (s.physicalChannelId != null) 'channel:${s.physicalChannelId}',
          ];
          final inputs = <String, Object?>{
            'roomId': route.roomId,
            'nodes': [
              for (final n in route.nodes)
                {
                  'id': n.id,
                  'kind': n.kind.name,
                  'patch': n.anchor.patchId,
                  'local': [
                    n.anchor.localPosition.xMm,
                    n.anchor.localPosition.yMm,
                  ],
                  'world': [
                    n.worldPosition.xMm,
                    n.worldPosition.yMm,
                    n.worldPosition.zMm,
                  ],
                  'otherPatch': n.otherAnchor?.patchId,
                  'otherLocal': n.otherAnchor == null
                      ? null
                      : [
                          n.otherAnchor!.localPosition.xMm,
                          n.otherAnchor!.localPosition.yMm,
                        ],
                  'adjacency': n.adjacencyId,
                },
            ],
            'segments': [
              for (final s in route.segments)
                {
                  'id': s.id,
                  'from': s.fromNodeId,
                  'to': s.toNodeId,
                  'patch': s.surfacePatchId,
                  'method': s.layingMethod.name,
                  'channel': s.physicalChannelId,
                },
            ],
          };
          add(
            'route:${route.id}',
            route.name,
            'fl9-route-length-v1',
            inputs,
            dependencies,
            (_) {
              final result = routing.calculate(route);
              return DependencyProposal(
                values: {'geometricLengthMm': result.geometricLengthMm},
                issues: result.issues.map((i) => i.message),
              );
            },
          );
        }
        for (final run in routing.runs) {
          add(
            'cable:${run.id}',
            run.name,
            'fl12-cable-basis-v1',
            {
              'roomId': run.roomId,
              'circuitId': run.circuitId,
              'routeId': run.routeId,
              'reservePercent': run.reservePercent,
              'terminationAllowanceMm': run.terminationAllowanceMm,
            },
            ['circuit:${run.circuitId}', 'route:${run.routeId}'],
            (deps) {
              final length = routing.cableLength(run);
              return DependencyProposal(
                values: {
                  'cableLengthMm': length,
                  'designCurrentA': deps['circuit:${run.circuitId}']!
                      .values['designCurrentA'],
                },
                issues: length == null
                    ? ['Cable route or allowances are invalid.']
                    : [],
              );
            },
          );
        }
      }
      final generationRows =
          await (database.select(database.panelGenerationConfigs)..where(
                (r) =>
                    r.floorId.equals(floor.id) &
                    r.projectId.equals(projectId) &
                    r.deletedAt.isNull(),
              ))
              .get();
      for (final row in generationRows) {
        final policy = PanelGenerationPolicy.fromMap(
          jsonDecode(row.payloadJson) as Map<String, dynamic>,
        );
        final ruleset = rules[policy.rulesetId],
            norm = norms[ruleset?.normativeDocumentId];
        if (ruleset != null) {
          if (norm != null)
            add(
              'normative:${norm.id}',
              norm.title,
              'fl13-normative-v1',
              norm.toMap(),
              [],
              (_) => DependencyProposal(values: norm.toMap()),
            );
          add(
            'ruleset:${ruleset.id}',
            ruleset.reference.id,
            'fl13-ruleset-v1',
            ruleset.toMap(),
            ['normative:${ruleset.normativeDocumentId}'],
            (_) => DependencyProposal(values: ruleset.toMap()),
          );
        }
        final groups = generationGroups.toList()
          ..sort((a, b) => a.id.compareTo(b.id));
        final loads = generationLoads.toList()
          ..sort(
            (a, b) => a.componentInstanceId.compareTo(b.componentInstanceId),
          );
        add(
          'panelProposal:${row.id}',
          policy.name,
          PanelGenerationEngine.algorithmVersion,
          {
            'policy': policy.toMap(),
            'groups': [
              for (final g in groups)
                {'id': g.id, 'roomId': g.roomId, 'name': g.name},
            ],
            'membership': [
              for (final l in loads)
                {'id': l.componentInstanceId, 'groupId': l.consumptionGroupId},
            ],
          },
          [
            'ruleset:${policy.rulesetId}',
            for (final l in loads) 'consumer:${l.componentInstanceId}',
          ],
          (_) => PanelGenerationEngine.generate(
            policy: policy,
            groups: groups,
            loads: loads,
            ruleset: ruleset,
            normativeDocument: norm,
          ),
        );
      }
      for (final panel in snapshot.panels) {
        final downstream = <String>{};
        for (final feed in panel.feeds) {
          downstream.addAll(
            floorGraph.trace(feed.runId, FloorTraceDirection.downstream).runIds,
          );
        }
        final deps = <String>[
          for (final id in downstream) 'cable:$id',
          for (final id in downstream)
            'protection:${floorGraph.runs[id]!.run.circuitId}',
        ];
        final relevantKeys = <String>{
          'panel:${panel.id}',
          for (final h in snapshot.handoffs)
            if (downstream.contains(h.fromRunId) ||
                downstream.contains(h.toRunId))
              'handoff:${h.id}',
          for (final room in snapshot.routing.values)
            for (final j in room.junctions)
              if (j.connections.any((c) => downstream.contains(c.runId)))
                'junction:${j.id}',
        };
        final topology = <String, Object?>{
          'floorId': floor.id,
          'feeds': [
            for (final f in panel.feeds)
              {'run': f.runId, 'signature': f.endpointSignature},
          ],
          'edges': [
            for (final e in floorGraph.edges.where(
              (e) => downstream.contains(e.from),
            ))
              {'id': e.id, 'from': e.from, 'to': e.to, 'physical': e.physical},
          ],
          'topologyIssues':
              floorGraph.issues.entries
                  .where((e) => relevantKeys.contains(e.key))
                  .map((e) => '${e.key}: ${e.value.join(" ")}')
                  .toList()
                ..sort(),
        };
        add(
          'panel:${panel.id}',
          '${panel.code} · ${panel.name}',
          'fl12-panel-feed-basis-v1',
          topology,
          deps,
          (values) {
            final currents = <String, Object?>{};
            for (final id in downstream) {
              final run = floorGraph.runs[id]!.run;
              currents[run.circuitId] =
                  values['cable:$id']!.values['designCurrentA'];
            }
            final issues = (topology['topologyIssues'] as List).cast<String>();
            return DependencyProposal(
              values: {
                'circuitCurrentsA': currents,
                'capability': 'Per-circuit basis only; panel rating and phase balance are not calculated.',
              },
              issues: issues,
              requiresReview: true,
            );
          },
        );
      }
    }
    final circuitIds = nodes.keys
        .where((k) => k.startsWith('circuit:'))
        .map((k) => k.substring(8))
        .toList();
    final selections = await (database.select(
      database.circuitProductSelections,
    )..where((r) => r.circuitId.isIn(circuitIds) & r.deletedAt.isNull())).get();
    if (selections.isNotEmpty) {
      final policyRow =
          await (database.select(database.manufacturerPolicies)..where(
                (r) => r.projectId.equals(projectId) & r.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      final policy = policyRow == null
          ? const ProjectManufacturerPolicy()
          : ManufacturerCatalogCodec.decodePolicy(
              jsonDecode(policyRow.payloadJson) as Map<String, dynamic>,
            );
      final policyMap = ManufacturerCatalogCodec.policy(policy);
      add(
        'manufacturerPolicy:$projectId',
        'Manufacturer policy',
        'fl14-policy-v1',
        policyMap,
        [],
        (_) => DependencyProposal(values: policyMap),
      );
      // Protection fingerprints are computed before commercial selection nodes are appended.
      final normative = RecalculationSession(nodes: nodes.values, cache: cache);
      for (final selected in selections) {
        final row = await (database.select(
          database.manufacturerProducts,
        )..where((r) => r.id.equals(selected.productId))).getSingleOrNull();
        final catalog = row == null
            ? null
            : await (database.select(
                database.manufacturerCatalogs,
              )..where((r) => r.id.equals(row.catalogId))).getSingleOrNull();
        final available =
            row != null &&
            row.deletedAt == null &&
            catalog != null &&
            catalog.deletedAt == null;
        final commercialInputs = <String, Object?>{
          'available': available,
          'catalogId': catalog?.id,
          'catalogVersion': catalog?.catalogVersion,
          'region': catalog?.region,
          'source': catalog?.sourceReference,
          'product': row == null ? null : jsonDecode(row.payloadJson),
        };
        add(
          'catalogProduct:${selected.productId}',
          'Catalog product ${row?.sku ?? selected.productId}',
          'fl14-product-source-v1',
          commercialInputs,
          [],
          (_) => DependencyProposal(
            values: commercialInputs,
            issues: available
                ? []
                : ['Selected catalog product is archived or unavailable.'],
          ),
        );
        final input = <String, Object?>{
          'productId': selected.productId,
          'snapshot': jsonDecode(selected.snapshotJson),
          'reviewedRequirementFingerprint': selected.requirementFingerprint,
          'reviewedPolicy': jsonDecode(selected.policyJson),
        };
        add(
          'product:${selected.circuitId}',
          '${nodes["circuit:${selected.circuitId}"]!.label} · Manufacturer selection',
          ManufacturerProductMatcher.algorithmVersion,
          input,
          [
            'protection:${selected.circuitId}',
            'catalogProduct:${selected.productId}',
            'manufacturerPolicy:$projectId',
          ],
          (deps) {
            final requirement = ManufacturerCatalogCodec.protectionRequirement(
              deps['protection:${selected.circuitId}']!.values,
            );
            final selectedSnapshot =
                jsonDecode(selected.snapshotJson) as Map<String, dynamic>;
            final product = ManufacturerCatalogCodec.decodeProduct(
              selectedSnapshot['product'] as Map<String, dynamic>,
            );
            final problems = requirement == null
                ? ['Functional requirement is unavailable.']
                : ManufacturerProductMatcher.match(
                    requirement,
                    product,
                    policy: policy,
                    catalogRegion: catalog?.region,
                  ).issues;
            final needsReview =
                selected.requirementFingerprint !=
                    normative
                        .fingerprints['protection:${selected.circuitId}'] ||
                canonicalEngineeringJson(jsonDecode(selected.policyJson)) !=
                    canonicalEngineeringJson(policyMap);
            return DependencyProposal(
              values: {
                'selectedProduct': selectedSnapshot,
                'compatible': problems.isEmpty,
                'reviewRequired': needsReview,
              },
              issues: problems,
              requiresReview: needsReview,
            );
          },
        );
      }
    }
    return ProjectRecalculationSnapshot(
      project: project,
      session: RecalculationSession(
        nodes: nodes.values,
        cache: [
          ...cache,
          for (final row in rows.where(
            (r) => r.deletedAt != null && nodes.containsKey(r.nodeKey),
          ))
            decode(row, restored: true),
        ],
      ),
      retired: rows
          .where((r) => r.deletedAt != null && !nodes.containsKey(r.nodeKey))
          .map(decode)
          .toList(growable: false),
      revisions: {for (final row in rows) row.nodeKey: row.revision},
    );
  });

  @override
  Future<Set<String>> recalculate(
    String projectId,
  ) => database.transaction(() async {
    final snapshot = await load(projectId);
    if (snapshot.project == null) throw StateError('Project is unavailable.');
    final updates = snapshot.session.recalculate();
    final now = DateTime.now().toUtc();
    for (final item in updates.values) {
      final old =
          await (database.select(database.projectDerivedResults)..where(
                (r) =>
                    r.projectId.equals(projectId) & r.nodeKey.equals(item.key),
              ))
              .getSingleOrNull();
      await database
          .into(database.projectDerivedResults)
          .insertOnConflictUpdate(
            ProjectDerivedResultsCompanion(
              projectId: Value(projectId),
              nodeKey: Value(item.key),
              fingerprint: Value(item.fingerprint),
              inputsJson: Value(item.inputsJson),
              dependenciesJson: Value(item.dependenciesJson),
              resultJson: Value(item.resultJson),
              state: Value(item.state.name),
              previousResultJson: Value(item.previousResultJson),
              changesJson: Value(item.changesJson),
              manualValue: Value(item.manualValue),
              manualReason: Value(item.manualReason),
              manualReviewedFingerprint: Value(item.manualReviewedFingerprint),
              revision: Value((old?.revision ?? 0) + 1),
              createdAt: Value(old?.createdAt ?? now),
              updatedAt: Value(now),
              deletedAt: const Value(null),
              originDeviceId: Value(originDeviceId),
            ),
          );
    }
    for (final key in snapshot.session.removedKeys) {
      await (database.update(database.projectDerivedResults)..where(
            (r) => r.projectId.equals(projectId) & r.nodeKey.equals(key),
          ))
          .write(
            ProjectDerivedResultsCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
              revision: Value(snapshot.revisions[key]! + 1),
              originDeviceId: Value(originDeviceId),
            ),
          );
    }
    return updates.keys.toSet();
  });

  @override
  Future<void> saveManualDecision({
    required String projectId,
    required String key,
    required String value,
    required String reason,
  }) => database.transaction(() async {
    if (value.trim().isEmpty || reason.trim().isEmpty)
      throw ArgumentError('Manual value and reason are required.');
    final snapshot = await load(projectId), entry = snapshot.session.cache[key];
    if (snapshot.project == null ||
        entry == null ||
        !snapshot.session.nodes.containsKey(key) ||
        snapshot.session.affectedKeys.contains(key))
      throw StateError(
        'Recalculate current inputs before recording a manual decision.',
      );
    if (!key.startsWith('cable:') &&
        !key.startsWith('circuit:') &&
        !key.startsWith('protection:') &&
        !key.startsWith('panel:')) {
      throw StateError('Manual decisions apply to engineering proposals only.');
    }
    await _manual(
      projectId,
      key,
      Value(value.trim()),
      Value(reason.trim()),
      Value(snapshot.session.fingerprints[key]),
    );
  });
  @override
  Future<void> reviewManualDecision(String projectId, String key) =>
      database.transaction(() async {
        final snapshot = await load(projectId),
            entry = snapshot.session.cache[key];
        if (snapshot.project == null ||
            entry?.manualValue == null ||
            snapshot.session.affectedKeys.contains(key) ||
            entry!.state == EngineeringDerivedState.error)
          throw StateError('Recalculate and resolve errors before reviewing.');
        await _manual(
          projectId,
          key,
          Value(entry.manualValue),
          Value(entry.manualReason),
          Value(snapshot.session.fingerprints[key]),
        );
      });
  @override
  Future<void> clearManualDecision(String projectId, String key) =>
      database.transaction(() async {
        final snapshot = await load(projectId);
        if (snapshot.project == null ||
            !snapshot.session.nodes.containsKey(key))
          throw StateError('Proposal is unavailable.');
        await _manual(
          projectId,
          key,
          const Value(null),
          const Value(null),
          const Value(null),
        );
      });
  Future<void> _manual(
    String projectId,
    String key,
    Value<String?> value,
    Value<String?> reason,
    Value<String?> reviewed,
  ) async {
    final row =
        await (database.select(database.projectDerivedResults)..where(
              (r) =>
                  r.projectId.equals(projectId) &
                  r.nodeKey.equals(key) &
                  r.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null) throw StateError('Recalculate this proposal first.');
    await (database.update(database.projectDerivedResults)
          ..where((r) => r.projectId.equals(projectId) & r.nodeKey.equals(key)))
        .write(
          ProjectDerivedResultsCompanion(
            manualValue: value,
            manualReason: reason,
            manualReviewedFingerprint: reviewed,
            revision: Value(row.revision + 1),
            updatedAt: Value(DateTime.now().toUtc()),
            originDeviceId: Value(originDeviceId),
          ),
        );
  }
}
