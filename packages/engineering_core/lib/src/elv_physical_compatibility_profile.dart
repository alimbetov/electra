import 'engineering_hash.dart';

final class PhysicalCompatibilityProfileRef {
  const PhysicalCompatibilityProfileRef({
    required this.catalogId,
    required this.catalogVersion,
    required this.profileCode,
    required this.profileContentHash,
  });

  final String catalogId;
  final String catalogVersion;
  final String profileCode;
  final String profileContentHash;
}

final class PhysicalCompatibilitySelector {
  PhysicalCompatibilitySelector({
    Iterable<String> mediaCodes = const [],
    Iterable<String> cableCategoryCodes = const [],
    Iterable<String> cableTechnicalClassCodes = const [],
    Iterable<String> carrierKinds = const [],
    Iterable<String> pathwayKinds = const [],
  })  : mediaCodes = _codes(mediaCodes),
        cableCategoryCodes = _codes(cableCategoryCodes),
        cableTechnicalClassCodes = _codes(cableTechnicalClassCodes),
        carrierKinds = _codes(carrierKinds),
        pathwayKinds = _codes(pathwayKinds);

  final List<String> mediaCodes;
  final List<String> cableCategoryCodes;
  final List<String> cableTechnicalClassCodes;
  final List<String> carrierKinds;
  final List<String> pathwayKinds;

  bool matches({
    required String mediaCode,
    String? cableCategoryCode,
    required Iterable<String> cableTechnicalClassCodes,
    required String carrierKind,
    required String pathwayKind,
  }) {
    bool dimension(List<String> accepted, Iterable<String> actual) =>
        accepted.isEmpty || actual.any(accepted.contains);
    return dimension(mediaCodes, [mediaCode.toUpperCase()]) &&
        dimension(
          this.cableCategoryCodes,
          [if (cableCategoryCode != null) cableCategoryCode.toUpperCase()],
        ) &&
        dimension(
          this.cableTechnicalClassCodes,
          cableTechnicalClassCodes.map((e) => e.toUpperCase()),
        ) &&
        dimension(carrierKinds, [carrierKind.toUpperCase()]) &&
        dimension(pathwayKinds, [pathwayKind.toUpperCase()]);
  }

  Map<String, Object?> toMap() => {
        'mediaCodes': mediaCodes,
        'cableCategoryCodes': cableCategoryCodes,
        'cableTechnicalClassCodes': cableTechnicalClassCodes,
        'carrierKinds': carrierKinds,
        'pathwayKinds': pathwayKinds,
      };
}

sealed class PhysicalCompatibilityRule {
  const PhysicalCompatibilityRule(this.selector);
  final PhysicalCompatibilitySelector selector;
  Map<String, Object?> toMap();
}

final class AllowedCarrierKindRule extends PhysicalCompatibilityRule {
  AllowedCarrierKindRule(super.selector, Iterable<String> allowedKinds)
      : allowedKinds = _codes(allowedKinds);
  final List<String> allowedKinds;
  @override
  Map<String, Object?> toMap() => {
        'type': 'ALLOWED_CARRIER_KIND',
        'selector': selector.toMap(),
        'allowedKinds': allowedKinds,
      };
}

final class AllowedInstallationClassRule extends PhysicalCompatibilityRule {
  AllowedInstallationClassRule(super.selector, Iterable<String> allowedCodes)
      : allowedCodes = _codes(allowedCodes);
  final List<String> allowedCodes;
  @override
  Map<String, Object?> toMap() => {
        'type': 'ALLOWED_INSTALLATION_CLASS',
        'selector': selector.toMap(),
        'allowedCodes': allowedCodes,
      };
}

final class AllowedEnvironmentClassRule extends PhysicalCompatibilityRule {
  AllowedEnvironmentClassRule({
    required super.selector,
    required this.dimension,
    required Iterable<String> allowedCodes,
  }) : allowedCodes = _codes(allowedCodes);
  final String dimension;
  final List<String> allowedCodes;
  @override
  Map<String, Object?> toMap() => {
        'type': 'ALLOWED_ENVIRONMENT_CLASS',
        'selector': selector.toMap(),
        'dimension': dimension.toUpperCase(),
        'allowedCodes': allowedCodes,
      };
}

final class MaximumCableDiameterRule extends PhysicalCompatibilityRule {
  const MaximumCableDiameterRule(super.selector, this.maximumDiameterMm);
  final double maximumDiameterMm;
  @override
  Map<String, Object?> toMap() => {
        'type': 'MAXIMUM_CABLE_DIAMETER',
        'selector': selector.toMap(),
        'maximumDiameterMm': maximumDiameterMm,
      };
}

final class MinimumCarrierUsableAreaRule extends PhysicalCompatibilityRule {
  const MinimumCarrierUsableAreaRule(super.selector, this.minimumAreaMm2);
  final double minimumAreaMm2;
  @override
  Map<String, Object?> toMap() => {
        'type': 'MINIMUM_CARRIER_USABLE_AREA',
        'selector': selector.toMap(),
        'minimumAreaMm2': minimumAreaMm2,
      };
}

final class DirectIntrinsicProhibitionRule extends PhysicalCompatibilityRule {
  const DirectIntrinsicProhibitionRule(super.selector, this.code);
  final String code;
  @override
  Map<String, Object?> toMap() => {
        'type': 'DIRECT_PROHIBITION',
        'selector': selector.toMap(),
        'code': code,
      };
}

final class PhysicalCompatibilityProfile {
  PhysicalCompatibilityProfile({
    required this.code,
    required this.label,
    required Iterable<PhysicalCompatibilityRule> rules,
    this.deprecated = false,
  })  : code = code.trim().toUpperCase(),
        rules = List.unmodifiable(rules);

  final String code;
  final String label;
  final bool deprecated;
  final List<PhysicalCompatibilityRule> rules;

  Map<String, Object?> toMap() => {
        'code': code,
        'label': label,
        'deprecated': deprecated,
        'rules': rules.map((rule) => rule.toMap()).toList(growable: false),
      };
}

String physicalCompatibilityProfileContentHashV1(
  PhysicalCompatibilityProfile profile,
) =>
    sha256HexUtf8(
      canonicalEngineeringJsonV1({
        'schema': 'electra.physical-compatibility-profile.v1',
        'profile': profile.toMap(),
      }),
    );

List<String> _codes(Iterable<String> values) => List.unmodifiable(
      values
          .map((value) => value.trim().toUpperCase())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    );
