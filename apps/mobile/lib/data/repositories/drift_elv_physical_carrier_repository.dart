import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_command_result.dart';
import '../../application/elv_failure_probe.dart';
import '../../application/elv_physical_carrier_command.dart';
import '../../application/elv_physical_carrier_repository.dart';
import '../database/app_database.dart';
import 'drift_elv_runtime_support.dart';

final class DriftElvPhysicalCarrierRepository
    implements ElvPhysicalCarrierRepository {
  DriftElvPhysicalCarrierRepository(
    this.database, {
    required this.originDeviceId,
    ElvFailureProbe? failureProbe,
  }) : failureProbe = failureProbe ?? const NoopElvFailureProbe();

  final AppDatabase database;
  final String originDeviceId;
  final ElvFailureProbe failureProbe;

  @override
  Future<List<PhysicalCarrier>> loadCarriers(String projectId) async {
    final rows =
        await (database.select(database.physicalCarriers)
              ..where(
                (row) =>
                    row.projectId.equals(projectId) & row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.normalizedCode)]))
            .get();
    return rows.map(_carrierFromRow).toList(growable: false);
  }

  @override
  Future<List<PhysicalCarrierCompartment>> loadCompartments(
    String carrierId,
  ) async {
    final rows =
        await (database.select(database.physicalCarrierCompartments)
              ..where(
                (row) =>
                    row.carrierId.equals(carrierId) & row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.sequence)]))
            .get();
    return rows.map(_compartmentFromRow).toList(growable: false);
  }

  @override
  Future<CarrierImpactPreview> previewCarrierImpact(
    String projectId,
    String carrierId,
  ) async {
    final rows = await database
        .customSelect(
          'SELECT DISTINCT a.cable_run_id FROM traversal_carrier_assignments a WHERE a.project_id = ? AND a.carrier_id = ? AND a.deleted_at IS NULL ORDER BY a.cable_run_id',
          variables: [
            Variable.withString(projectId),
            Variable.withString(carrierId),
          ],
        )
        .get();
    final ids = rows
        .map((row) => row.read<String>('cable_run_id'))
        .toList(growable: false);
    return CarrierImpactPreview(
      affectedCableRunIds: ids,
      impactFingerprint: elvRuntimeFingerprint('electra.carrier-impact.v1', {
        'projectId': projectId,
        'carrierId': carrierId,
        'cableRunIds': ids,
      }),
    );
  }

  @override
  Future<ElvCommandResult<PhysicalCarrier>> create(
    CreatePhysicalCarrierCommand command,
  ) => database.transaction(() async {
    final carrier = command.carrier;
    final errors = carrier.validate();
    if (errors.isNotEmpty)
      return elvRuntimeFailure(
        'ELV_CARRIER_INVALID',
        ElvFailureCategory.validation,
        details: {'errors': errors},
      );
    final pathway =
        await (database.select(database.pathwayContexts)..where(
              (row) =>
                  row.id.equals(carrier.pathwayContextId) &
                  row.projectId.equals(carrier.projectId) &
                  row.lifecycleState.equals('ACTIVE') &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (pathway == null)
      return elvRuntimeFailure(
        'ELV_CARRIER_PATHWAY_NOT_FOUND',
        ElvFailureCategory.referenceIntegrity,
      );
    final duplicate =
        await (database.select(database.physicalCarriers)..where(
              (row) =>
                  row.projectId.equals(carrier.projectId) &
                  row.normalizedCode.equals(carrier.normalizedCode) &
                  row.lifecycleState.equals('ACTIVE') &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (duplicate != null)
      return elvRuntimeFailure(
        'ELV_CARRIER_CODE_EXISTS',
        ElvFailureCategory.validation,
      );
    final now = DateTime.now().toUtc();
    await database
        .into(database.physicalCarriers)
        .insert(
          PhysicalCarriersCompanion.insert(
            id: carrier.id,
            projectId: carrier.projectId,
            pathwayContextId: carrier.pathwayContextId,
            code: carrier.code,
            normalizedCode: carrier.normalizedCode,
            name: carrier.name,
            kind: carrier.kind.name.toUpperCase(),
            payloadJson: jsonEncode(_carrierPayload(carrier)),
            lifecycleState: carrier.lifecycleState.name.toUpperCase(),
            revision: Value(carrier.revision),
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
        );
    return ElvCommandSuccess(carrier);
  });

  @override
  Future<ElvCommandResult<PhysicalCarrier>> update(
    UpdatePhysicalCarrierCommand command,
  ) => database.transaction(() async {
    final row =
        await (database.select(database.physicalCarriers)..where(
              (candidate) =>
                  candidate.id.equals(command.carrier.id) &
                  candidate.projectId.equals(command.carrier.projectId) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null)
      return elvRuntimeFailure(
        'ELV_CARRIER_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    if (row.revision != command.expectedRevision)
      return elvRuntimeFailure(
        'ELV_CARRIER_REVISION_CONFLICT',
        ElvFailureCategory.revisionConflict,
        expectedRevision: command.expectedRevision,
        actualRevision: row.revision,
      );
    final preview = await previewCarrierImpact(
      command.carrier.projectId,
      command.carrier.id,
    );
    if (preview.impactFingerprint != command.expectedImpactFingerprint)
      return elvRuntimeFailure(
        'ELV_CARRIER_IMPACT_CHANGED',
        ElvFailureCategory.dependencyImpact,
      );
    final next = PhysicalCarrier(
      id: command.carrier.id,
      projectId: command.carrier.projectId,
      pathwayContextId: command.carrier.pathwayContextId,
      code: command.carrier.code,
      name: command.carrier.name,
      kind: command.carrier.kind,
      crossSection: command.carrier.crossSection,
      environmentFacts: command.carrier.environmentFacts,
      installationFacts: command.carrier.installationFacts,
      lifecycleState: command.carrier.lifecycleState,
      revision: row.revision + 1,
    );
    final errors = next.validate();
    if (errors.isNotEmpty)
      return elvRuntimeFailure(
        'ELV_CARRIER_INVALID',
        ElvFailureCategory.validation,
        details: {'errors': errors},
      );
    await (database.update(
      database.physicalCarriers,
    )..where((candidate) => candidate.id.equals(next.id))).write(
      PhysicalCarriersCompanion(
        pathwayContextId: Value(next.pathwayContextId),
        code: Value(next.code),
        normalizedCode: Value(next.normalizedCode),
        name: Value(next.name),
        kind: Value(next.kind.name.toUpperCase()),
        payloadJson: Value(jsonEncode(_carrierPayload(next))),
        lifecycleState: Value(next.lifecycleState.name.toUpperCase()),
        revision: Value(next.revision),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    return ElvCommandSuccess(next);
  });

  @override
  Future<ElvCommandResult<void>> archive(
    ArchivePhysicalCarrierCommand command,
  ) => database.transaction(() async {
    final row =
        await (database.select(database.physicalCarriers)..where(
              (candidate) =>
                  candidate.id.equals(command.carrierId) &
                  candidate.projectId.equals(command.projectId) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null)
      return elvRuntimeFailure(
        'ELV_CARRIER_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    if (row.revision != command.expectedRevision)
      return elvRuntimeFailure(
        'ELV_CARRIER_REVISION_CONFLICT',
        ElvFailureCategory.revisionConflict,
        expectedRevision: command.expectedRevision,
        actualRevision: row.revision,
      );
    final assignment =
        await (database.select(database.traversalCarrierAssignments)..where(
              (candidate) =>
                  candidate.carrierId.equals(command.carrierId) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (assignment != null)
      return elvRuntimeFailure(
        'ELV_CARRIER_IN_USE',
        ElvFailureCategory.referenceIntegrity,
      );
    await (database.update(
      database.physicalCarriers,
    )..where((candidate) => candidate.id.equals(command.carrierId))).write(
      PhysicalCarriersCompanion(
        lifecycleState: const Value('ARCHIVED'),
        revision: Value(row.revision + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    return const ElvCommandSuccess<void>(null);
  });

  @override
  Future<ElvCommandResult<PhysicalCarrierCompartment>> createCompartment(
    CreateCarrierCompartmentCommand command,
  ) => database.transaction(() async {
    final carrierRow =
        await (database.select(database.physicalCarriers)..where(
              (row) =>
                  row.id.equals(command.compartment.carrierId) &
                  row.projectId.equals(command.projectId) &
                  row.lifecycleState.equals('ACTIVE') &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (carrierRow == null)
      return elvRuntimeFailure(
        'ELV_CARRIER_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    final existing = await loadCompartments(command.compartment.carrierId);
    final carrier = _carrierFromRow(carrierRow);
    final errors = validateCarrierCompartments(
      carrier: carrier,
      compartments: [...existing, command.compartment],
    );
    if (errors.isNotEmpty)
      return elvRuntimeFailure(
        'ELV_CARRIER_COMPARTMENT_INVALID',
        ElvFailureCategory.validation,
        details: {'errors': errors},
      );
    final now = DateTime.now().toUtc();
    await database
        .into(database.physicalCarrierCompartments)
        .insert(
          PhysicalCarrierCompartmentsCompanion.insert(
            id: command.compartment.id,
            carrierId: command.compartment.carrierId,
            code: command.compartment.code,
            normalizedCode: command.compartment.normalizedCode,
            sequence: command.compartment.sequence,
            payloadJson: jsonEncode(
              _crossSectionToMap(command.compartment.crossSection),
            ),
            lifecycleState: command.compartment.lifecycleState.name
                .toUpperCase(),
            revision: Value(command.compartment.revision),
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
        );
    return ElvCommandSuccess(command.compartment);
  });

  @override
  Future<ElvCommandResult<PhysicalCarrierCompartment>> updateCompartment(
    UpdateCarrierCompartmentCommand command,
  ) => database.transaction(() async {
    final row =
        await (database.select(database.physicalCarrierCompartments)..where(
              (candidate) =>
                  candidate.id.equals(command.compartment.id) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null)
      return elvRuntimeFailure(
        'ELV_CARRIER_COMPARTMENT_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    if (row.revision != command.expectedRevision)
      return elvRuntimeFailure(
        'ELV_CARRIER_COMPARTMENT_REVISION_CONFLICT',
        ElvFailureCategory.revisionConflict,
        expectedRevision: command.expectedRevision,
        actualRevision: row.revision,
      );
    final preview = await previewCarrierImpact(
      command.projectId,
      row.carrierId,
    );
    if (preview.impactFingerprint != command.expectedImpactFingerprint)
      return elvRuntimeFailure(
        'ELV_CARRIER_IMPACT_CHANGED',
        ElvFailureCategory.dependencyImpact,
      );
    final next = PhysicalCarrierCompartment(
      id: command.compartment.id,
      carrierId: command.compartment.carrierId,
      code: command.compartment.code,
      sequence: command.compartment.sequence,
      crossSection: command.compartment.crossSection,
      lifecycleState: command.compartment.lifecycleState,
      revision: row.revision + 1,
    );
    final carrierRow = await (database.select(
      database.physicalCarriers,
    )..where((candidate) => candidate.id.equals(next.carrierId))).getSingle();
    final others = (await loadCompartments(next.carrierId))
        .where((item) => item.id != next.id);
    final errors = validateCarrierCompartments(
      carrier: _carrierFromRow(carrierRow),
      compartments: [...others, next],
    );
    if (errors.isNotEmpty)
      return elvRuntimeFailure(
        'ELV_CARRIER_COMPARTMENT_INVALID',
        ElvFailureCategory.validation,
        details: {'errors': errors},
      );
    await (database.update(
      database.physicalCarrierCompartments,
    )..where((candidate) => candidate.id.equals(next.id))).write(
      PhysicalCarrierCompartmentsCompanion(
        code: Value(next.code),
        normalizedCode: Value(next.normalizedCode),
        sequence: Value(next.sequence),
        payloadJson: Value(jsonEncode(_crossSectionToMap(next.crossSection))),
        lifecycleState: Value(next.lifecycleState.name.toUpperCase()),
        revision: Value(next.revision),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    return ElvCommandSuccess(next);
  });

  @override
  Future<ElvCommandResult<CanonicalCableRun>> attachTraversal(
    AttachTraversalToCarrierCommand command,
  ) => database.transaction(() async {
    final run =
        await (database.select(database.canonicalCableRuns)..where(
              (row) =>
                  row.id.equals(command.cableRunId) &
                  row.projectId.equals(command.projectId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (run == null)
      return elvRuntimeFailure(
        'ELV_CABLE_RUN_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    if (run.revision != command.expectedCableRunRevision)
      return elvRuntimeFailure(
        'ELV_CABLE_RUN_REVISION_CONFLICT',
        ElvFailureCategory.revisionConflict,
        expectedRevision: command.expectedCableRunRevision,
        actualRevision: run.revision,
      );
    final traversal =
        await (database.select(database.cableRunTraversals)..where(
              (row) =>
                  row.id.equals(command.traversalId) &
                  row.cableRunId.equals(command.cableRunId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (traversal == null)
      return elvRuntimeFailure(
        'ELV_TRAVERSAL_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    final carrier =
        await (database.select(database.physicalCarriers)..where(
              (row) =>
                  row.id.equals(command.carrierId) &
                  row.projectId.equals(command.projectId) &
                  row.lifecycleState.equals('ACTIVE') &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (carrier == null)
      return elvRuntimeFailure(
        'ELV_CARRIER_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    PhysicalCarrierCompartmentRow? compartment;
    if (command.compartmentId != null) {
      compartment =
          await (database.select(database.physicalCarrierCompartments)..where(
                (row) =>
                    row.id.equals(command.compartmentId!) &
                    row.carrierId.equals(command.carrierId) &
                    row.lifecycleState.equals('ACTIVE') &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (compartment == null)
        return elvRuntimeFailure(
          'ELV_CARRIER_COMPARTMENT_NOT_FOUND',
          ElvFailureCategory.referenceIntegrity,
        );
    }
    final revisionRow =
        await (database.select(database.projectDesignRevisions)..where(
              (row) =>
                  row.id.equals(run.designRevisionId) &
                  row.state.equals('WORKING') &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (revisionRow == null)
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_READ_ONLY',
        ElvFailureCategory.lifecycle,
      );
    await (database.update(
      database.cableRunTraversals,
    )..where((row) => row.id.equals(command.traversalId))).write(
      CableRunTraversalsCompanion(
        physicalCarrierId: Value(command.carrierId),
        carrierCompartmentId: Value(command.compartmentId),
        revision: Value(traversal.revision + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    final now = DateTime.now().toUtc();
    await database
        .into(database.traversalCarrierAssignments)
        .insertOnConflictUpdate(
          TraversalCarrierAssignmentsCompanion.insert(
            traversalId: command.traversalId,
            cableRunId: command.cableRunId,
            projectId: command.projectId,
            designRevisionId: run.designRevisionId,
            carrierId: command.carrierId,
            compartmentId: Value(command.compartmentId),
            revision: Value(
              ((await (database.select(
                                database.traversalCarrierAssignments,
                              )..where(
                                (row) =>
                                    row.traversalId.equals(command.traversalId),
                              ))
                              .getSingleOrNull())
                          ?.revision ??
                      0) +
                  1,
            ),
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
        );
    await failureProbe.hit(
      ElvFailurePoints.p4AttachCarrierAfterTraversalUpdate,
    );
    await (database.update(
      database.canonicalCableRuns,
    )..where((row) => row.id.equals(run.id))).write(
      CanonicalCableRunsCompanion(
        revision: Value(run.revision + 1),
        updatedAt: Value(now),
        originDeviceId: Value(originDeviceId),
      ),
    );
    final next = CanonicalCableRun(
      id: run.id,
      projectId: run.projectId,
      cableId: run.cableId,
      designRevisionId: run.designRevisionId,
      basedOnCableRunId: run.basedOnCableRunId,
      state: CanonicalCableRunState.values.byName(
        run.lifecycleState.toLowerCase(),
      ),
      reservePercent: run.reservePercent,
      terminationAllowanceMm: run.terminationAllowanceMm,
      revision: run.revision + 1,
    );
    return ElvCommandSuccess(next);
  });
}

Map<String, Object?> _carrierPayload(PhysicalCarrier carrier) => {
  'crossSection': _crossSectionToMap(carrier.crossSection),
  'environmentFacts': {
    'exposure': carrier.environmentFacts.exposure?.name,
    'moistureClassCode': carrier.environmentFacts.moistureClassCode,
    'contaminationClassCode': carrier.environmentFacts.contaminationClassCode,
    'climateClassCode': carrier.environmentFacts.climateClassCode,
    'temperatureRange': carrier.environmentFacts.temperatureRange == null
        ? null
        : {
            'minimumC': carrier.environmentFacts.temperatureRange!.minimumC,
            'maximumC': carrier.environmentFacts.temperatureRange!.maximumC,
          },
  },
  'installationFacts': {
    'installationClassCode': carrier.installationFacts.installationClassCode,
    'accessibility': carrier.installationFacts.accessibility?.name,
    'barrierPresent': carrier.installationFacts.barrierPresent,
  },
};

Map<String, Object?> _crossSectionToMap(CarrierCrossSection value) =>
    switch (value) {
      RectangularCarrierCrossSection(:final widthMm, :final heightMm) => {
        'type': 'RECTANGULAR',
        'widthMm': widthMm,
        'heightMm': heightMm,
      },
      CircularCarrierCrossSection(:final diameterMm) => {
        'type': 'CIRCULAR',
        'diameterMm': diameterMm,
      },
      CustomCarrierCrossSection(:final areaMm2, :final provenance) => {
        'type': 'CUSTOM',
        'areaMm2': areaMm2,
        'provenance': provenance,
      },
    };

CarrierCrossSection _crossSectionFromMap(Map<String, dynamic> map) =>
    switch (map['type']) {
      'RECTANGULAR' => RectangularCarrierCrossSection(
        widthMm: (map['widthMm'] as num).toDouble(),
        heightMm: (map['heightMm'] as num).toDouble(),
      ),
      'CIRCULAR' => CircularCarrierCrossSection(
        (map['diameterMm'] as num).toDouble(),
      ),
      'CUSTOM' => CustomCarrierCrossSection(
        areaMm2: (map['areaMm2'] as num).toDouble(),
        provenance: map['provenance'] as String,
      ),
      _ => throw StateError('Unknown carrier cross-section'),
    };

PhysicalCarrier _carrierFromRow(PhysicalCarrierRow row) {
  final payload = (jsonDecode(row.payloadJson) as Map).cast<String, dynamic>();
  final env = (payload['environmentFacts'] as Map).cast<String, dynamic>();
  final install = (payload['installationFacts'] as Map).cast<String, dynamic>();
  final temperature = env['temperatureRange'] == null
      ? null
      : (env['temperatureRange'] as Map).cast<String, dynamic>();
  return PhysicalCarrier(
    id: row.id,
    projectId: row.projectId,
    pathwayContextId: row.pathwayContextId,
    code: row.code,
    name: row.name,
    kind: PhysicalCarrierKind.values.byName(row.kind.toLowerCase()),
    crossSection: _crossSectionFromMap(
      (payload['crossSection'] as Map).cast<String, dynamic>(),
    ),
    environmentFacts: CarrierEnvironmentFacts(
      exposure: env['exposure'] == null
          ? null
          : CarrierEnclosureExposure.values.byName(env['exposure'] as String),
      moistureClassCode: env['moistureClassCode'] as String?,
      contaminationClassCode: env['contaminationClassCode'] as String?,
      climateClassCode: env['climateClassCode'] as String?,
      temperatureRange: temperature == null
          ? null
          : CarrierTemperatureRange(
              minimumC: (temperature['minimumC'] as num).toDouble(),
              maximumC: (temperature['maximumC'] as num).toDouble(),
            ),
    ),
    installationFacts: CarrierInstallationFacts(
      installationClassCode: install['installationClassCode'] as String?,
      accessibility: install['accessibility'] == null
          ? null
          : MaintenanceAccessibility.values.byName(
              install['accessibility'] as String,
            ),
      barrierPresent: install['barrierPresent'] as bool? ?? false,
    ),
    lifecycleState: PhysicalCarrierLifecycleState.values.byName(
      row.lifecycleState.toLowerCase(),
    ),
    revision: row.revision,
  );
}

PhysicalCarrierCompartment _compartmentFromRow(
  PhysicalCarrierCompartmentRow row,
) => PhysicalCarrierCompartment(
  id: row.id,
  carrierId: row.carrierId,
  code: row.code,
  sequence: row.sequence,
  crossSection: _crossSectionFromMap(
    (jsonDecode(row.payloadJson) as Map).cast<String, dynamic>(),
  ),
  lifecycleState: CarrierCompartmentLifecycleState.values.byName(
    row.lifecycleState.toLowerCase(),
  ),
  revision: row.revision,
);
