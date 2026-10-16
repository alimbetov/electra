import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Lan01SectionClass { permanent, patch, otherExplicit }

final class Lan01LengthInterval {
  Lan01LengthInterval({required this.lower, required this.upper}) {
    if (lower.value < Elv5Rational.zero || upper.value < Elv5Rational.zero) {
      throw ArgumentError('LAN01 length bounds must be nonnegative.');
    }
    if (lower > upper) {
      throw ArgumentError('LAN01 lower length bound must not exceed upper.');
    }
  }

  factory Lan01LengthInterval.exact(Length value) =>
      Lan01LengthInterval(lower: value, upper: value);

  final Length lower;
  final Length upper;

  Lan01LengthInterval operator +(Lan01LengthInterval other) =>
      Lan01LengthInterval(lower: lower + other.lower, upper: upper + other.upper);

  static Lan01LengthInterval get zero => Lan01LengthInterval.exact(
        Length(Elv5Rational.zero),
      );
}

final class Lan01RealizedSection {
  Lan01RealizedSection({
    required this.sectionId,
    required this.sectionClass,
    required this.installedLength,
  }) {
    if (sectionId.trim().isEmpty) {
      throw ArgumentError('LAN01 sectionId must not be empty.');
    }
  }

  final String sectionId;
  final Lan01SectionClass sectionClass;
  final Lan01LengthInterval installedLength;
}

final class Lan01ExplicitAllowance {
  Lan01ExplicitAllowance({
    required this.allowanceId,
    required this.length,
    required this.appliesToPermanent,
    required this.appliesToChannel,
    required this.alreadyIncludedInInstalledLength,
  }) {
    if (allowanceId.trim().isEmpty) {
      throw ArgumentError('LAN01 allowanceId must not be empty.');
    }
    if (!appliesToPermanent && !appliesToChannel) {
      throw ArgumentError('LAN01 allowance must target at least one aggregate.');
    }
  }

  final String allowanceId;
  final Lan01LengthInterval length;
  final bool appliesToPermanent;
  final bool appliesToChannel;
  final bool alreadyIncludedInInstalledLength;
}

final class Lan01MaximumPolicy {
  Lan01MaximumPolicy({required this.limit, this.inclusive = true}) {
    if (limit.value < Elv5Rational.zero) {
      throw ArgumentError('LAN01 maximum length must be nonnegative.');
    }
  }

  final Length limit;
  final bool inclusive;
}

final class Lan01Policy {
  const Lan01Policy({this.permanentMaximum, this.channelMaximum});

  final Lan01MaximumPolicy? permanentMaximum;
  final Lan01MaximumPolicy? channelMaximum;
}

final class Lan01Input {
  Lan01Input({
    required this.linkId,
    required this.orderedSections,
    this.allowances = const <Lan01ExplicitAllowance>[],
    this.policy = const Lan01Policy(),
  }) {
    if (linkId.trim().isEmpty) {
      throw ArgumentError('LAN01 linkId must not be empty.');
    }
    if (orderedSections.isEmpty) {
      throw ArgumentError('LAN01 requires a realized path.');
    }
    if (orderedSections.length > 4096 || allowances.length > 4096) {
      throw StateError('LAN01_RESOURCE_LIMIT:path_members');
    }
  }

  final String linkId;
  final List<Lan01RealizedSection> orderedSections;
  final List<Lan01ExplicitAllowance> allowances;
  final Lan01Policy policy;
}

final class Lan01LengthAssessment {
  const Lan01LengthAssessment({
    required this.length,
    required this.margin,
    required this.passes,
  });

  final Lan01LengthInterval length;
  final Length? margin;
  final bool? passes;
}

enum Lan01GoverningDimension { permanent, channel }

final class Lan01Result {
  const Lan01Result({
    required this.linkId,
    required this.permanent,
    required this.channel,
    required this.governingDimension,
  });

  final String linkId;
  final Lan01LengthAssessment permanent;
  final Lan01LengthAssessment channel;
  final Lan01GoverningDimension? governingDimension;
}

final class Lan01PathLengthKernel {
  const Lan01PathLengthKernel();

  Lan01Result evaluate(Lan01Input input) {
    _validateUniqueIds(input);

    var permanent = Lan01LengthInterval.zero;
    var channel = Lan01LengthInterval.zero;

    for (final section in input.orderedSections) {
      channel = channel + section.installedLength;
      if (section.sectionClass == Lan01SectionClass.permanent) {
        permanent = permanent + section.installedLength;
      }
    }

    for (final allowance in input.allowances) {
      if (allowance.alreadyIncludedInInstalledLength) {
        continue;
      }
      if (allowance.appliesToPermanent) {
        permanent = permanent + allowance.length;
      }
      if (allowance.appliesToChannel) {
        channel = channel + allowance.length;
      }
    }

    final permanentAssessment = _assess(
      permanent,
      input.policy.permanentMaximum,
    );
    final channelAssessment = _assess(
      channel,
      input.policy.channelMaximum,
    );

    return Lan01Result(
      linkId: input.linkId,
      permanent: permanentAssessment,
      channel: channelAssessment,
      governingDimension: _selectGoverning(
        permanentAssessment,
        channelAssessment,
      ),
    );
  }

  static void _validateUniqueIds(Lan01Input input) {
    final sectionIds = <String>{};
    for (final section in input.orderedSections) {
      if (!sectionIds.add(section.sectionId)) {
        throw StateError('LAN01_DUPLICATE_SECTION:${section.sectionId}');
      }
    }

    final allowanceIds = <String>{};
    for (final allowance in input.allowances) {
      if (!allowanceIds.add(allowance.allowanceId)) {
        throw StateError('LAN01_DUPLICATE_ALLOWANCE:${allowance.allowanceId}');
      }
    }
  }

  static Lan01LengthAssessment _assess(
    Lan01LengthInterval length,
    Lan01MaximumPolicy? policy,
  ) {
    if (policy == null) {
      return Lan01LengthAssessment(length: length, margin: null, passes: null);
    }

    final margin = policy.limit - length.upper;
    final passes = policy.inclusive
        ? margin.value >= Elv5Rational.zero
        : margin.value > Elv5Rational.zero;
    return Lan01LengthAssessment(
      length: length,
      margin: margin,
      passes: passes,
    );
  }

  static Lan01GoverningDimension? _selectGoverning(
    Lan01LengthAssessment permanent,
    Lan01LengthAssessment channel,
  ) {
    final permanentMargin = permanent.margin;
    final channelMargin = channel.margin;
    if (permanentMargin == null && channelMargin == null) return null;
    if (permanentMargin == null) return Lan01GoverningDimension.channel;
    if (channelMargin == null) return Lan01GoverningDimension.permanent;
    return permanentMargin <= channelMargin
        ? Lan01GoverningDimension.permanent
        : Lan01GoverningDimension.channel;
  }
}
