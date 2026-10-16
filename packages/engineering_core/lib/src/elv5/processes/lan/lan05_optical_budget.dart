import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

final class Lan05LossInterval {
  Lan05LossInterval({required this.lower, required this.upper}) {
    if (lower.value < Elv5Rational.zero || upper.value < Elv5Rational.zero) {
      throw ArgumentError('LAN05 physical loss must be nonnegative.');
    }
    if (lower > upper) {
      throw ArgumentError('LAN05 lower loss must not exceed upper loss.');
    }
  }

  factory Lan05LossInterval.exact(LossDb value) =>
      Lan05LossInterval(lower: value, upper: value);

  final LossDb lower;
  final LossDb upper;

  Lan05LossInterval operator +(Lan05LossInterval other) => Lan05LossInterval(
        lower: lower + other.lower,
        upper: upper + other.upper,
      );

  static Lan05LossInterval get zero =>
      Lan05LossInterval.exact(LossDb(Elv5Rational.zero));
}

final class Lan05LengthInterval {
  Lan05LengthInterval({required this.lower, required this.upper}) {
    if (lower.value < Elv5Rational.zero || upper.value < Elv5Rational.zero) {
      throw ArgumentError('LAN05 fiber length must be nonnegative.');
    }
    if (lower > upper) {
      throw ArgumentError('LAN05 lower length must not exceed upper length.');
    }
  }

  factory Lan05LengthInterval.exact(Length value) =>
      Lan05LengthInterval(lower: value, upper: value);

  final Length lower;
  final Length upper;
}

final class Lan05FiberSection {
  Lan05FiberSection({
    required this.sectionId,
    required this.wavelengthNm,
    required this.lengthMeters,
    required this.attenuationDbPerKm,
  }) {
    if (sectionId.trim().isEmpty) {
      throw ArgumentError('LAN05 sectionId must not be empty.');
    }
    if (wavelengthNm <= Elv5Rational.zero) {
      throw ArgumentError('LAN05 wavelength must be positive.');
    }
  }

  final String sectionId;
  final Elv5Rational wavelengthNm;
  final Lan05LengthInterval lengthMeters;
  final Lan05LossInterval attenuationDbPerKm;
}

enum Lan05LossEventKind { connectorPair, splice, other }

final class Lan05LossEvent {
  Lan05LossEvent({
    required this.eventId,
    required this.kind,
    required this.loss,
  }) {
    if (eventId.trim().isEmpty) {
      throw ArgumentError('LAN05 eventId must not be empty.');
    }
  }

  final String eventId;
  final Lan05LossEventKind kind;
  final Lan05LossInterval loss;
}

final class Lan05DirectionInput {
  Lan05DirectionInput({
    required this.wavelengthNm,
    required this.sections,
    required this.events,
    required this.requiredSensitivityMargin,
    this.txMin,
    this.txMax,
    this.rxSensitivity,
    this.rxOverloadMax,
  }) {
    if (wavelengthNm <= Elv5Rational.zero) {
      throw ArgumentError('LAN05 wavelength must be positive.');
    }
    if (sections.length > 4096 || events.length > 4096) {
      throw StateError('LAN05_RESOURCE_LIMIT:path_members');
    }
    if (requiredSensitivityMargin.value < Elv5Rational.zero) {
      throw ArgumentError('LAN05 required sensitivity margin must be nonnegative.');
    }
    if (txMin != null && txMax != null && txMin! > txMax!) {
      throw ArgumentError('LAN05 TxMin must not exceed TxMax.');
    }
    if (rxSensitivity != null &&
        rxOverloadMax != null &&
        rxSensitivity! > rxOverloadMax!) {
      throw ArgumentError('LAN05 sensitivity must not exceed overload maximum.');
    }
  }

  final Elv5Rational wavelengthNm;
  final List<Lan05FiberSection> sections;
  final List<Lan05LossEvent> events;
  final LevelDbm? txMin;
  final LevelDbm? txMax;
  final LevelDbm? rxSensitivity;
  final LevelDbm? rxOverloadMax;
  final LossDb requiredSensitivityMargin;
}

final class Lan05Input {
  const Lan05Input({required this.aToB, required this.bToA});

  final Lan05DirectionInput aToB;
  final Lan05DirectionInput bToA;
}

final class Lan05MarginAssessment {
  const Lan05MarginAssessment({required this.margin, required this.passes});

  final LossDb? margin;
  final bool? passes;
}

final class Lan05DirectionResult {
  const Lan05DirectionResult({
    required this.physicalLoss,
    required this.rxLow,
    required this.rxHigh,
    required this.sensitivity,
    required this.overload,
  });

  final Lan05LossInterval physicalLoss;
  final LevelDbm? rxLow;
  final LevelDbm? rxHigh;
  final Lan05MarginAssessment sensitivity;
  final Lan05MarginAssessment overload;
}

enum Lan05GoverningCase {
  aToBSensitivity,
  aToBOverload,
  bToASensitivity,
  bToAOverload,
}

final class Lan05Result {
  const Lan05Result({
    required this.aToB,
    required this.bToA,
    required this.governingCase,
    required this.governingMargin,
    required this.passes,
  });

  final Lan05DirectionResult aToB;
  final Lan05DirectionResult bToA;
  final Lan05GoverningCase? governingCase;
  final LossDb? governingMargin;

  /// `true` only when all four mandatory margins resolve and pass.
  /// `false` as soon as any resolved mandatory margin fails.
  /// `null` when no failure exists but at least one mandatory margin is unresolved.
  final bool? passes;
}

final class Lan05OpticalBudgetKernel {
  const Lan05OpticalBudgetKernel();

  Lan05Result evaluate(Lan05Input input) {
    final aToB = _evaluateDirection(input.aToB);
    final bToA = _evaluateDirection(input.bToA);

    final cases = <(Lan05GoverningCase, LossDb?)>[
      (Lan05GoverningCase.aToBSensitivity, aToB.sensitivity.margin),
      (Lan05GoverningCase.aToBOverload, aToB.overload.margin),
      (Lan05GoverningCase.bToASensitivity, bToA.sensitivity.margin),
      (Lan05GoverningCase.bToAOverload, bToA.overload.margin),
    ];

    (Lan05GoverningCase, LossDb)? governing;
    for (final entry in cases) {
      final margin = entry.$2;
      if (margin == null) continue;
      if (governing == null || margin < governing.$2) {
        governing = (entry.$1, margin);
      }
    }

    final statuses = <bool?>[
      aToB.sensitivity.passes,
      aToB.overload.passes,
      bToA.sensitivity.passes,
      bToA.overload.passes,
    ];
    final anyFail = statuses.any((status) => status == false);
    final allResolved = statuses.every((status) => status != null);

    return Lan05Result(
      aToB: aToB,
      bToA: bToA,
      governingCase: governing?.$1,
      governingMargin: governing?.$2,
      passes: anyFail ? false : (allResolved ? true : null),
    );
  }

  static Lan05DirectionResult _evaluateDirection(Lan05DirectionInput input) {
    final loss = _computeLoss(input);

    final rxLow = input.txMin == null
        ? null
        : LevelDbm(input.txMin!.value - loss.upper.value);
    final rxHigh = input.txMax == null
        ? null
        : LevelDbm(input.txMax!.value - loss.lower.value);

    LossDb? sensitivityMargin;
    if (rxLow != null && input.rxSensitivity != null) {
      sensitivityMargin = LossDb(
        rxLow.value -
            input.rxSensitivity!.value -
            input.requiredSensitivityMargin.value,
      );
    }

    LossDb? overloadMargin;
    if (rxHigh != null && input.rxOverloadMax != null) {
      overloadMargin = LossDb(input.rxOverloadMax!.value - rxHigh.value);
    }

    return Lan05DirectionResult(
      physicalLoss: loss,
      rxLow: rxLow,
      rxHigh: rxHigh,
      sensitivity: _assessment(sensitivityMargin),
      overload: _assessment(overloadMargin),
    );
  }

  static Lan05LossInterval _computeLoss(Lan05DirectionInput input) {
    final sectionIds = <String>{};
    var total = Lan05LossInterval.zero;
    final thousand = Elv5Rational.integer(1000);

    for (final section in input.sections) {
      if (!sectionIds.add(section.sectionId)) {
        throw StateError('LAN05_DUPLICATE_SECTION:${section.sectionId}');
      }
      if (section.wavelengthNm != input.wavelengthNm) {
        throw StateError('LAN05_WAVELENGTH_MISMATCH:${section.sectionId}');
      }
      final minLoss = LossDb(
        section.attenuationDbPerKm.lower.value *
            section.lengthMeters.lower.value /
            thousand,
      );
      final maxLoss = LossDb(
        section.attenuationDbPerKm.upper.value *
            section.lengthMeters.upper.value /
            thousand,
      );
      total = total + Lan05LossInterval(lower: minLoss, upper: maxLoss);
    }

    final eventIds = <String>{};
    for (final event in input.events) {
      if (!eventIds.add(event.eventId)) {
        throw StateError('LAN05_DUPLICATE_LOSS_EVENT:${event.eventId}');
      }
      total = total + event.loss;
    }
    return total;
  }

  static Lan05MarginAssessment _assessment(LossDb? margin) {
    if (margin == null) {
      return const Lan05MarginAssessment(margin: null, passes: null);
    }
    return Lan05MarginAssessment(
      margin: margin,
      passes: margin.value >= Elv5Rational.zero,
    );
  }
}
