enum Elv5EvidenceBasis {
  manufacturerGuaranteed,
  manufacturerTypical,
  measured,
  estimated,
  projectPolicy,
  syntheticFixture,
}

final class Elv5SourceRef {
  Elv5SourceRef({
    required this.kind,
    required this.reference,
    required this.contentHash,
  }) {
    if (kind.trim().isEmpty || reference.trim().isEmpty) {
      throw ArgumentError('Source kind/reference must be non-empty.');
    }
    if (!_sha256.hasMatch(contentHash)) {
      throw ArgumentError.value(
        contentHash,
        'contentHash',
        'Expected SHA-256.',
      );
    }
  }

  static final _sha256 = RegExp(r'^[0-9a-f]{64}$');

  final String kind;
  final String reference;
  final String contentHash;

  Map<String, Object?> toMap() => <String, Object?>{
        'kind': kind,
        'reference': reference,
        'contentHash': contentHash,
      };
}

final class Elv5Applicability {
  const Elv5Applicability({
    required this.modelCode,
    this.environmentCodes = const <String>{},
  });

  final String modelCode;
  final Set<String> environmentCodes;

  Map<String, Object?> toMap() => <String, Object?>{
        'modelCode': modelCode,
        'environmentCodes': environmentCodes,
      };
}

final class Elv5EngineeringValue<T> {
  const Elv5EngineeringValue({
    required this.value,
    required this.basis,
    required this.source,
    required this.applicability,
  });

  final T value;
  final Elv5EvidenceBasis basis;
  final Elv5SourceRef source;
  final Elv5Applicability applicability;
}
