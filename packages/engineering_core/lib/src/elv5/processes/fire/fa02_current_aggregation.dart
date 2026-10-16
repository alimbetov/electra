import '../../numeric/interval.dart';
import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Fa02OperatingCase { standby, alarm, startupInrush }

enum Fa02AssessmentStatus { complete, unresolved, fail }

final class Fa02LoadOrigin {
  Fa02LoadOrigin({
    required this.originId,
    required this.currents,
  }) {
    if (originId.isEmpty) throw ArgumentError('FA02 originId must not be empty.');
    for (final entry in currents.entries) {
      if (entry.value.lower.value < Elv5Rational.zero ||
          entry.value.upper.value < Elv5Rational.zero) {
        throw ArgumentError('FA02 current intervals must be nonnegative.');
      }
    }
  }

  final String originId;
  final Map<Fa02OperatingCase, Elv5Interval<CurrentDim>> currents;
}

final class Fa02CasePolicy {
  Fa02CasePolicy({
    required this.operatingCase,
    required this.selectedOriginIds,
    this.explicitCurrentLimit,
  }) {
    if (selectedOriginIds.isEmpty) {
      throw ArgumentError('FA02 case must select at least one origin.');
    }
    if (explicitCurrentLimit != null &&
        explicitCurrentLimit!.value < Elv5Rational.zero) {
      throw ArgumentError('FA02 current limit must be nonnegative.');
    }
  }

  final Fa02OperatingCase operatingCase;
  final Set<String> selectedOriginIds;
  final Current? explicitCurrentLimit;
}

final class Fa02Input {
  Fa02Input({
    required this.segmentId,
    required this.origins,
    required this.cases,
  }) {
    if (segmentId.isEmpty) throw ArgumentError('FA02 segmentId must not be empty.');
    final originIds = <String>{};
    for (final origin in origins) {
      if (!originIds.add(origin.originId)) {
        throw ArgumentError('FA02 duplicate load origin: ${origin.originId}');
      }
    }
    final caseIds = <Fa02OperatingCase>{};
    for (final item in cases) {
      if (!caseIds.add(item.operatingCase)) {
        throw ArgumentError('FA02 duplicate operating case: ${item.operatingCase}');
      }
      for (final id in item.selectedOriginIds) {
        if (!originIds.contains(id)) {
          throw ArgumentError('FA02 case references unknown origin: $id');
        }
      }
    }
  }

  final String segmentId;
  final List<Fa02LoadOrigin> origins;
  final List<Fa02CasePolicy> cases;
}

final class Fa02CaseResult {
  const Fa02CaseResult({
    required this.operatingCase,
    required this.knownSubtotal,
    required this.missingOriginIds,
    required this.status,
    this.margin,
  });

  final Fa02OperatingCase operatingCase;
  final Elv5Interval<CurrentDim> knownSubtotal;
  final List<String> missingOriginIds;
  final Fa02AssessmentStatus status;
  final Current? margin;

  bool get complete => missingOriginIds.isEmpty;
}

final class Fa02Result {
  const Fa02Result({
    required this.cases,
    required this.status,
    this.governingCase,
  });

  final Map<Fa02OperatingCase, Fa02CaseResult> cases;
  final Fa02AssessmentStatus status;
  final Fa02OperatingCase? governingCase;
}

final class Fa02CurrentAggregationKernel {
  const Fa02CurrentAggregationKernel();

  Fa02Result evaluate(Fa02Input input) {
    final byId = <String, Fa02LoadOrigin>{
      for (final origin in input.origins) origin.originId: origin,
    };
    final results = <Fa02OperatingCase, Fa02CaseResult>{};

    for (final policy in input.cases) {
      var lower = Current(Elv5Rational.zero);
      var upper = Current(Elv5Rational.zero);
      final missing = <String>[];
      final ids = [...policy.selectedOriginIds]..sort();
      for (final id in ids) {
        final interval = byId[id]!.currents[policy.operatingCase];
        if (interval == null) {
          missing.add(id);
          continue;
        }
        lower = lower + interval.lower;
        upper = upper + interval.upper;
      }

      final subtotal = Elv5Interval<CurrentDim>(lower, upper);
      Current? margin;
      Fa02AssessmentStatus status;
      if (missing.isNotEmpty) {
        status = Fa02AssessmentStatus.unresolved;
      } else if (policy.explicitCurrentLimit != null) {
        margin = policy.explicitCurrentLimit! - upper;
        status = margin.value >= Elv5Rational.zero
            ? Fa02AssessmentStatus.complete
            : Fa02AssessmentStatus.fail;
      } else {
        status = Fa02AssessmentStatus.complete;
      }

      results[policy.operatingCase] = Fa02CaseResult(
        operatingCase: policy.operatingCase,
        knownSubtotal: subtotal,
        missingOriginIds: List.unmodifiable(missing),
        status: status,
        margin: margin,
      );
    }

    Fa02AssessmentStatus overall = Fa02AssessmentStatus.complete;
    Fa02OperatingCase? governing;

    final orderedCases = Fa02OperatingCase.values.where(results.containsKey);
    for (final operatingCase in orderedCases) {
      if (results[operatingCase]!.status == Fa02AssessmentStatus.fail) {
        overall = Fa02AssessmentStatus.fail;
        governing = operatingCase;
        break;
      }
    }
    if (overall != Fa02AssessmentStatus.fail) {
      for (final operatingCase in orderedCases) {
        if (results[operatingCase]!.status == Fa02AssessmentStatus.unresolved) {
          overall = Fa02AssessmentStatus.unresolved;
          governing = operatingCase;
          break;
        }
      }
    }
    if (governing == null && results.isNotEmpty) {
      Fa02CaseResult? highest;
      for (final value in results.values) {
        if (!value.complete) continue;
        if (highest == null || value.knownSubtotal.upper > highest.knownSubtotal.upper) {
          highest = value;
        }
      }
      governing = highest?.operatingCase;
    }

    return Fa02Result(
      cases: Map.unmodifiable(results),
      status: overall,
      governingCase: governing,
    );
  }
}
