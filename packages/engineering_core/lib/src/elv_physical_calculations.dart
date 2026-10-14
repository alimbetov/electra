import 'dart:math' as math;

import 'elv_cable_reference.dart';
import 'elv_cable_run.dart';
import 'elv_physical_carrier.dart';

abstract final class ElvPhysicalProcessCodes {
  static const installedLength = 'ELV-ROUTE-01';
  static const carrierFillBasis = 'ELV-ROUTE-02';
  static const segregationEvidence = 'ELV-ROUTE-03';
  static const bendRadiusBasis = 'ELV-ROUTE-04';
  static const congestionBasis = 'ELV-ROUTE-05';
  static const reserveAllowance = 'ELV-ROUTE-06';
}

enum ElvCalculationState { current, stale, blocked, failed }

final class ElvPhysicalCalculationResult<T> {
  const ElvPhysicalCalculationResult({
    required this.processCode,
    required this.algorithmVersion,
    required this.projectId,
    required this.designRevisionId,
    required this.subjectId,
    required this.value,
    required this.unit,
    required this.state,
    required this.inputFingerprint,
    this.trace = const {},
    this.blockingCodes = const [],
  });

  final String processCode;
  final String algorithmVersion;
  final String projectId;
  final String designRevisionId;
  final String subjectId;
  final T? value;
  final String unit;
  final ElvCalculationState state;
  final String inputFingerprint;
  final Map<String, Object?> trace;
  final List<String> blockingCodes;
}

final class CableRunTraversalGeometry {
  const CableRunTraversalGeometry({
    required this.traversalId,
    required this.routeSegmentId,
    required this.lengthMm,
    required this.geometryRevision,
  });

  final String traversalId;
  final String routeSegmentId;
  final double lengthMm;
  final int geometryRevision;
}

ElvPhysicalCalculationResult<double> calculateInstalledLength({
  required CanonicalCableRun run,
  required List<CableRunTraversalGeometry> traversals,
  required String inputFingerprint,
}) {
  if (traversals.isEmpty) {
    return ElvPhysicalCalculationResult<double>(
      processCode: ElvPhysicalProcessCodes.installedLength,
      algorithmVersion: 'elv.route.length.v1',
      projectId: run.projectId,
      designRevisionId: run.designRevisionId,
      subjectId: run.id,
      value: null,
      unit: 'mm',
      state: ElvCalculationState.blocked,
      inputFingerprint: inputFingerprint,
      blockingCodes: const ['ELV_ROUTE_GEOMETRY_MISSING'],
    );
  }
  final invalid = traversals.any((item) => !item.lengthMm.isFinite || item.lengthMm < 0);
  if (invalid) {
    return ElvPhysicalCalculationResult<double>(
      processCode: ElvPhysicalProcessCodes.installedLength,
      algorithmVersion: 'elv.route.length.v1',
      projectId: run.projectId,
      designRevisionId: run.designRevisionId,
      subjectId: run.id,
      value: null,
      unit: 'mm',
      state: ElvCalculationState.failed,
      inputFingerprint: inputFingerprint,
      blockingCodes: const ['ELV_ROUTE_GEOMETRY_INVALID'],
    );
  }

  final geometricLengthMm = traversals.fold<double>(0, (sum, item) => sum + item.lengthMm);
  final installedLengthMm =
      geometricLengthMm * (1 + run.reservePercent / 100) + run.terminationAllowanceMm;
  return ElvPhysicalCalculationResult<double>(
    processCode: ElvPhysicalProcessCodes.installedLength,
    algorithmVersion: 'elv.route.length.v1',
    projectId: run.projectId,
    designRevisionId: run.designRevisionId,
    subjectId: run.id,
    value: installedLengthMm,
    unit: 'mm',
    state: ElvCalculationState.current,
    inputFingerprint: inputFingerprint,
    trace: {
      'geometricTraversalLengthMm': geometricLengthMm,
      'reservePercent': run.reservePercent,
      'terminationAllowanceMm': run.terminationAllowanceMm,
    },
  );
}

double? cableOccupiedAreaMm2(CableDefinition definition) {
  final explicit = definition.occupiedAreaMm2;
  if (explicit != null && explicit.isFinite && explicit > 0) return explicit;
  final diameter = definition.outerDiameterMm;
  if (diameter == null || !diameter.isFinite || diameter <= 0) return null;
  return math.pi * diameter * diameter / 4;
}

final class CarrierUsageKey {
  const CarrierUsageKey({
    required this.routeSegmentId,
    required this.physicalCarrierId,
    this.carrierCompartmentId,
  });

  final String routeSegmentId;
  final String physicalCarrierId;
  final String? carrierCompartmentId;

  String get stableKey =>
      '$routeSegmentId/$physicalCarrierId/${carrierCompartmentId ?? 'none'}';

  @override
  bool operator ==(Object other) =>
      other is CarrierUsageKey &&
      other.routeSegmentId == routeSegmentId &&
      other.physicalCarrierId == physicalCarrierId &&
      other.carrierCompartmentId == carrierCompartmentId;

  @override
  int get hashCode => Object.hash(routeSegmentId, physicalCarrierId, carrierCompartmentId);
}

final class CableCarrierUsage {
  const CableCarrierUsage({
    required this.key,
    required this.cableId,
    required this.occupiedAreaMm2,
  });

  final CarrierUsageKey key;
  final String cableId;
  final double occupiedAreaMm2;
}

final class CarrierOccupancyEvidence {
  const CarrierOccupancyEvidence({
    required this.key,
    required this.cableIds,
    required this.occupiedAreaMm2,
    required this.usableAreaMm2,
  });

  final CarrierUsageKey key;
  final List<String> cableIds;
  final double occupiedAreaMm2;
  final double usableAreaMm2;

  double get factualFillRatio => occupiedAreaMm2 / usableAreaMm2;
}

List<CarrierOccupancyEvidence> calculateCarrierOccupancy({
  required List<CableCarrierUsage> usages,
  required Map<CarrierUsageKey, double> usableAreaByKey,
}) {
  final byKey = <CarrierUsageKey, Map<String, double>>{};
  for (final usage in usages) {
    if (!usage.occupiedAreaMm2.isFinite || usage.occupiedAreaMm2 <= 0) continue;
    byKey.putIfAbsent(usage.key, () => <String, double>{})[usage.cableId] =
        usage.occupiedAreaMm2;
  }

  final results = <CarrierOccupancyEvidence>[];
  final keys = byKey.keys.toList()..sort((a, b) => a.stableKey.compareTo(b.stableKey));
  for (final key in keys) {
    final usable = usableAreaByKey[key];
    if (usable == null || !usable.isFinite || usable <= 0) continue;
    final cableMap = byKey[key]!;
    final cableIds = cableMap.keys.toList()..sort();
    results.add(
      CarrierOccupancyEvidence(
        key: key,
        cableIds: cableIds,
        occupiedAreaMm2: cableMap.values.fold<double>(0, (a, b) => a + b),
        usableAreaMm2: usable,
      ),
    );
  }
  return List.unmodifiable(results);
}
