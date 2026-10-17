import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Lan06AssessmentStatus { pass, fail, unresolved, notAssessed }

enum Lan06CapacityBasis { grossWithExclusions, netUsable }

final class Lan06EquipmentDemand {
  Lan06EquipmentDemand({
    required this.equipmentId,
    required this.ru,
    required this.weight,
    required this.depth,
  }) {
    if (equipmentId.isEmpty || ru < 0) {
      throw ArgumentError('LAN06 equipment identity/RU is invalid.');
    }
    if (weight != null && weight!.value < Elv5Rational.zero) {
      throw ArgumentError('LAN06 weight must be nonnegative.');
    }
    if (depth != null && depth!.value < Elv5Rational.zero) {
      throw ArgumentError('LAN06 depth must be nonnegative.');
    }
  }

  final String equipmentId;
  final int ru;
  final Mass? weight;
  final Length? depth;
}

final class Lan06Exclusion {
  Lan06Exclusion({
    required this.exclusionId,
    required this.ru,
    required this.alreadyIncludedInNetCapacity,
  }) {
    if (exclusionId.isEmpty || ru < 0) {
      throw ArgumentError('LAN06 exclusion identity/RU is invalid.');
    }
  }

  final String exclusionId;
  final int ru;
  final bool alreadyIncludedInNetCapacity;
}

final class Lan06CapacityFacts {
  const Lan06CapacityFacts({
    required this.ruCapacity,
    this.weightCapacity,
    this.depthCapacity,
  });

  final int ruCapacity;
  final Mass? weightCapacity;
  final Length? depthCapacity;
}

final class Lan06Input {
  Lan06Input({
    required this.rackId,
    required this.equipment,
    required this.capacityBasis,
    required this.capacity,
    required this.exclusions,
    required this.explicitSpareRu,
  }) {
    if (rackId.isEmpty || capacity.ruCapacity < 0 || explicitSpareRu < 0) {
      throw ArgumentError('LAN06 rack/capacity/spare is invalid.');
    }
    final equipmentIds = <String>{};
    for (final item in equipment) {
      if (!equipmentIds.add(item.equipmentId)) {
        throw ArgumentError('LAN06 duplicate equipmentId: ${item.equipmentId}');
      }
    }
    final exclusionIds = <String>{};
    for (final item in exclusions) {
      if (!exclusionIds.add(item.exclusionId)) {
        throw ArgumentError('LAN06 duplicate exclusionId: ${item.exclusionId}');
      }
    }
  }

  final String rackId;
  final List<Lan06EquipmentDemand> equipment;
  final Lan06CapacityBasis capacityBasis;
  final Lan06CapacityFacts capacity;
  final List<Lan06Exclusion> exclusions;
  final int explicitSpareRu;
}

final class Lan06Result {
  const Lan06Result({
    required this.status,
    required this.requiredRu,
    required this.availableRu,
    required this.ruMargin,
    required this.requiredWeight,
    required this.weightMargin,
    required this.weightStatus,
    required this.requiredDepth,
    required this.depthMargin,
    required this.depthStatus,
    required this.layoutStatus,
  });

  final Lan06AssessmentStatus status;
  final int requiredRu;
  final int availableRu;
  final int ruMargin;
  final Mass? requiredWeight;
  final Mass? weightMargin;
  final Lan06AssessmentStatus weightStatus;
  final Length? requiredDepth;
  final Length? depthMargin;
  final Lan06AssessmentStatus depthStatus;
  final Lan06AssessmentStatus layoutStatus;
}

final class Lan06RackCapacityKernel {
  const Lan06RackCapacityKernel();

  Lan06Result evaluate(Lan06Input input) {
    var requiredRu = input.explicitSpareRu;
    var weight = Mass(Elv5Rational.zero);
    var weightComplete = true;
    Length? maxDepth;
    var depthComplete = true;

    for (final item in input.equipment) {
      requiredRu += item.ru;
      if (item.weight == null) {
        weightComplete = false;
      } else {
        weight = weight + item.weight!;
      }
      if (item.depth == null) {
        depthComplete = false;
      } else if (maxDepth == null || item.depth! > maxDepth!) {
        maxDepth = item.depth;
      }
    }

    var availableRu = input.capacity.ruCapacity;
    if (input.capacityBasis == Lan06CapacityBasis.grossWithExclusions) {
      for (final exclusion in input.exclusions) {
        if (!exclusion.alreadyIncludedInNetCapacity)
          availableRu -= exclusion.ru;
      }
    }
    final ruMargin = availableRu - requiredRu;

    Mass? weightMargin;
    Lan06AssessmentStatus weightStatus;
    if (!weightComplete) {
      weightStatus = Lan06AssessmentStatus.unresolved;
    } else if (input.capacity.weightCapacity == null) {
      weightStatus = Lan06AssessmentStatus.notAssessed;
    } else {
      weightMargin = input.capacity.weightCapacity! - weight;
      weightStatus = weightMargin.value >= Elv5Rational.zero
          ? Lan06AssessmentStatus.pass
          : Lan06AssessmentStatus.fail;
    }

    Length? depthMargin;
    Lan06AssessmentStatus depthStatus;
    if (!depthComplete) {
      depthStatus = Lan06AssessmentStatus.unresolved;
    } else if (maxDepth == null || input.capacity.depthCapacity == null) {
      depthStatus = Lan06AssessmentStatus.notAssessed;
    } else {
      depthMargin = input.capacity.depthCapacity! - maxDepth!;
      depthStatus = depthMargin.value >= Elv5Rational.zero
          ? Lan06AssessmentStatus.pass
          : Lan06AssessmentStatus.fail;
    }

    final ruStatus =
        ruMargin >= 0 ? Lan06AssessmentStatus.pass : Lan06AssessmentStatus.fail;
    final statuses = [ruStatus, weightStatus, depthStatus];
    final overall = statuses.contains(Lan06AssessmentStatus.fail)
        ? Lan06AssessmentStatus.fail
        : (statuses.contains(Lan06AssessmentStatus.unresolved)
            ? Lan06AssessmentStatus.unresolved
            : Lan06AssessmentStatus.pass);

    return Lan06Result(
      status: overall,
      requiredRu: requiredRu,
      availableRu: availableRu,
      ruMargin: ruMargin,
      requiredWeight: weightComplete ? weight : null,
      weightMargin: weightMargin,
      weightStatus: weightStatus,
      requiredDepth: depthComplete ? maxDepth : null,
      depthMargin: depthMargin,
      depthStatus: depthStatus,
      layoutStatus: Lan06AssessmentStatus.notAssessed,
    );
  }
}
