import 'power_evaluation.dart';
import 'power_graph.dart';

enum PowerGraphReadinessDimension { topology, realization, capacity, backup }

final class PowerGraphDimensionResult {
  PowerGraphDimensionResult({
    required this.dimension,
    required this.status,
    Iterable<String> dependencyKeys = const [],
    Iterable<String> findingCodes = const [],
  })  : dependencyKeys = List.unmodifiable(_sortedUnique(dependencyKeys)),
        findingCodes = List.unmodifiable(_sortedUnique(findingCodes));

  final PowerGraphReadinessDimension dimension;
  final PowerEvaluationStatus status;
  final List<String> dependencyKeys;
  final List<String> findingCodes;
}

final class PowerGraphReadiness {
  PowerGraphReadiness(Iterable<PowerGraphDimensionResult> dimensions)
      : dimensions = List.unmodifiable(_canonicalDimensions(dimensions));

  final List<PowerGraphDimensionResult> dimensions;

  PowerGraphDimensionResult operator [](
          PowerGraphReadinessDimension dimension) =>
      dimensions.singleWhere((value) => value.dimension == dimension);

  bool get topologyUsable =>
      this[PowerGraphReadinessDimension.topology].status ==
      PowerEvaluationStatus.pass;

  bool get fullyResolved => dimensions.every(
        (value) => value.status == PowerEvaluationStatus.pass,
      );
}

PowerGraphReadiness assessPowerGraphReadiness({
  required PowerTopologyValidation topology,
  Iterable<String> missingRealizationDependencyKeys = const [],
  PowerEvaluationStatus? capacityStatus,
  Iterable<String> capacityDependencyKeys = const [],
  PowerEvaluationStatus? backupStatus,
  Iterable<String> backupDependencyKeys = const [],
}) {
  final realizationDependencies =
      _sortedUnique(missingRealizationDependencyKeys);
  final capacityDependencies = _sortedUnique(capacityDependencyKeys);
  final backupDependencies = _sortedUnique(backupDependencyKeys);

  return PowerGraphReadiness([
    PowerGraphDimensionResult(
      dimension: PowerGraphReadinessDimension.topology,
      status: topology.status,
      findingCodes: topology.findings.map((value) => value.code),
    ),
    PowerGraphDimensionResult(
      dimension: PowerGraphReadinessDimension.realization,
      status: realizationDependencies.isEmpty
          ? PowerEvaluationStatus.pass
          : PowerEvaluationStatus.unresolved,
      dependencyKeys: realizationDependencies,
    ),
    PowerGraphDimensionResult(
      dimension: PowerGraphReadinessDimension.capacity,
      status: capacityStatus ?? PowerEvaluationStatus.unresolved,
      dependencyKeys: capacityDependencies,
    ),
    PowerGraphDimensionResult(
      dimension: PowerGraphReadinessDimension.backup,
      status: backupStatus ?? PowerEvaluationStatus.unresolved,
      dependencyKeys: backupDependencies,
    ),
  ]);
}

List<PowerGraphDimensionResult> _canonicalDimensions(
  Iterable<PowerGraphDimensionResult> input,
) {
  final byDimension =
      <PowerGraphReadinessDimension, PowerGraphDimensionResult>{};
  for (final value in input) {
    if (byDimension.containsKey(value.dimension)) {
      throw ArgumentError('Power graph readiness dimensions must be unique.');
    }
    byDimension[value.dimension] = value;
  }
  for (final dimension in PowerGraphReadinessDimension.values) {
    if (!byDimension.containsKey(dimension)) {
      throw ArgumentError('Power graph readiness must cover every dimension.');
    }
  }
  return [
    for (final dimension in PowerGraphReadinessDimension.values)
      byDimension[dimension]!,
  ];
}

List<String> _sortedUnique(Iterable<String> values) {
  final result = values
      .map((value) {
        final normalized = value.trim();
        if (normalized.isEmpty) {
          throw ArgumentError(
              'Power graph dependency/finding identity is required.');
        }
        return normalized;
      })
      .toSet()
      .toList()
    ..sort();
  return result;
}
