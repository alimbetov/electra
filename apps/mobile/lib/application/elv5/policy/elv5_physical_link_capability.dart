enum Elv5PhysicalMedium {
  copper('COPPER'),
  fiber('FIBER'),
  other('OTHER');

  const Elv5PhysicalMedium(this.code);

  final String code;

  static Elv5PhysicalMedium parse(String value) {
    final code = elv5PhysicalToken(value, 'mediumCode');
    for (final medium in values) {
      if (medium.code == code) return medium;
    }
    throw ArgumentError.value(value, 'mediumCode', 'Unsupported ELV5 medium.');
  }
}

/// Canonical cross-discipline representation of the physical properties that
/// CCTV-06 and LAN-04 use when deciding whether a realized link section is
/// compatible with an engineering requirement.
///
/// The primitive deliberately contains no engineering defaults. Missing
/// interface/category/connector/speed evidence stays missing and must be
/// handled by the consuming process as BLOCKED/UNRESOLVED where required.
final class Elv5PhysicalLinkCapability {
  Elv5PhysicalLinkCapability({
    required String mediumCode,
    required Iterable<String> interfaceKinds,
    Iterable<String> categoryTokens = const <String>[],
    Iterable<String> connectorKinds = const <String>[],
    Iterable<String> speedModes = const <String>[],
    required bool shieldContinuityKnown,
    required bool shieldContinuity,
  }) : medium = Elv5PhysicalMedium.parse(mediumCode),
       interfaceKinds = _tokens(interfaceKinds, 'interfaceKind'),
       categoryTokens = _tokens(categoryTokens, 'categoryToken'),
       connectorKinds = _tokens(connectorKinds, 'connectorKind'),
       speedModes = _tokens(speedModes, 'speedMode'),
       shieldContinuity = Elv5ShieldContinuity.validated(
         known: shieldContinuityKnown,
         continuous: shieldContinuity,
       ) {
    if (this.interfaceKinds.isEmpty) {
      throw ArgumentError(
        'ELV5 physical capability requires explicit interface evidence.',
      );
    }
  }

  final Elv5PhysicalMedium medium;
  final Set<String> interfaceKinds;
  final Set<String> categoryTokens;
  final Set<String> connectorKinds;
  final Set<String> speedModes;
  final Elv5ShieldContinuity shieldContinuity;

  String get mediumCode => medium.code;
}

/// Shield continuity is evidence, not a boolean engineering default.
/// `known == false` means the continuity is unresolved and therefore cannot
/// be represented as continuous.
final class Elv5ShieldContinuity {
  const Elv5ShieldContinuity._({
    required this.known,
    required this.continuous,
  });

  factory Elv5ShieldContinuity.validated({
    required bool known,
    required bool continuous,
  }) {
    if (!known && continuous) {
      throw ArgumentError(
        'Unknown ELV5 shield continuity cannot assert continuity.',
      );
    }
    return Elv5ShieldContinuity._(known: known, continuous: continuous);
  }

  final bool known;
  final bool continuous;
}

String elv5PhysicalMediumCode(String value) =>
    Elv5PhysicalMedium.parse(value).code;

String elv5PhysicalToken(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized.toUpperCase();
}

void validateElv5ShieldContinuity({
  required bool known,
  required bool continuous,
}) {
  Elv5ShieldContinuity.validated(known: known, continuous: continuous);
}

Set<String> _tokens(Iterable<String> values, String field) => Set.unmodifiable(
  values.map((value) => elv5PhysicalToken(value, field)),
);
