import 'package:engineering_core/engineering_core_elv5.dart';

final class Cctv06SectionEvidenceContract {
  Cctv06SectionEvidenceContract({
    required String sectionId,
    required String mediumCode,
    required String interfaceKind,
    required String categoryToken,
    required this.shieldContinuityKnown,
    required this.shieldContinuity,
    required String evidenceRef,
    required String evidenceContentHash,
  }) : sectionId = _text(sectionId, 'sectionId'),
       mediumCode = _medium(mediumCode),
       interfaceKind = _token(interfaceKind, 'interfaceKind'),
       categoryToken = _token(categoryToken, 'categoryToken'),
       evidenceRef = _text(evidenceRef, 'evidenceRef'),
       evidenceContentHash = _sha(evidenceContentHash, 'evidenceContentHash') {
    if (!shieldContinuityKnown && shieldContinuity) {
      throw ArgumentError(
        'CCTV06 unknown shield continuity cannot assert true.',
      );
    }
  }

  final String sectionId;
  final String mediumCode;
  final String interfaceKind;
  final String categoryToken;
  final bool shieldContinuityKnown;
  final bool shieldContinuity;
  final String evidenceRef;
  final String evidenceContentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'sectionId': sectionId,
    'mediumCode': mediumCode,
    'interfaceKind': interfaceKind,
    'categoryToken': categoryToken,
    'shieldContinuityKnown': shieldContinuityKnown,
    'shieldContinuity': shieldContinuity,
    'evidenceRef': evidenceRef,
    'evidenceContentHash': evidenceContentHash,
  };

  factory Cctv06SectionEvidenceContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'sectionId',
      'mediumCode',
      'interfaceKind',
      'categoryToken',
      'shieldContinuityKnown',
      'shieldContinuity',
      'evidenceRef',
      'evidenceContentHash',
    }, 'CCTV06 section evidence');
    return Cctv06SectionEvidenceContract(
      sectionId: _mapText(map, 'sectionId'),
      mediumCode: _mapText(map, 'mediumCode'),
      interfaceKind: _mapText(map, 'interfaceKind'),
      categoryToken: _mapText(map, 'categoryToken'),
      shieldContinuityKnown: _bool(map, 'shieldContinuityKnown'),
      shieldContinuity: _bool(map, 'shieldContinuity'),
      evidenceRef: _mapText(map, 'evidenceRef'),
      evidenceContentHash: _mapText(map, 'evidenceContentHash'),
    );
  }
}

final class Cctv06LinkContract {
  Cctv06LinkContract({
    required String linkId,
    required String expectedCompositionFingerprint,
    required Iterable<String> allowedMediaCodes,
    required Iterable<String> allowedInterfaceKinds,
    required Iterable<String> allowedCategoryTokens,
    required this.shieldingRequired,
    this.maximumLengthM,
    required Iterable<Cctv06SectionEvidenceContract> sections,
    required this.powered,
    this.pseId,
    this.scenarioId,
    this.segmentId,
    Map<String, String> expectedPwr06InputFingerprintByDeliveryId = const {},
    Map<String, String> poweredSectionToDeliveryId = const {},
  }) : linkId = _text(linkId, 'linkId'),
       expectedCompositionFingerprint = _sha(
         expectedCompositionFingerprint,
         'expectedCompositionFingerprint',
       ),
       allowedMediaCodes = Set.unmodifiable(allowedMediaCodes.map(_medium)),
       allowedInterfaceKinds = Set.unmodifiable(
         allowedInterfaceKinds.map((e) => _token(e, 'allowedInterfaceKind')),
       ),
       allowedCategoryTokens = Set.unmodifiable(
         allowedCategoryTokens.map((e) => _token(e, 'allowedCategoryToken')),
       ),
       sections = List.unmodifiable(sections),
       expectedPwr06InputFingerprintByDeliveryId = Map.unmodifiable(
         _fingerprints(expectedPwr06InputFingerprintByDeliveryId),
       ),
       poweredSectionToDeliveryId = Map.unmodifiable(<String, String>{
         for (final entry in poweredSectionToDeliveryId.entries)
           _text(entry.key, 'poweredSectionId'): _text(
             entry.value,
             'deliveryId',
           ),
       }) {
    if (this.sections.isEmpty) {
      throw ArgumentError('CCTV06 sections must not be empty.');
    }
    final sectionIds = <String>{};
    for (final section in this.sections) {
      if (!sectionIds.add(section.sectionId)) {
        throw ArgumentError('CCTV06 duplicate sectionId: ${section.sectionId}');
      }
    }
    if (maximumLengthM != null && maximumLengthM! < Elv5Rational.zero) {
      throw ArgumentError('CCTV06 maximum length must be nonnegative.');
    }
    if (this.allowedMediaCodes.isEmpty ||
        this.allowedInterfaceKinds.isEmpty ||
        this.allowedCategoryTokens.isEmpty) {
      throw ArgumentError('CCTV06 policy sets must not be empty.');
    }
    if (powered) {
      _text(pseId ?? '', 'pseId');
      _text(scenarioId ?? '', 'scenarioId');
      _text(segmentId ?? '', 'segmentId');
      if (this.expectedPwr06InputFingerprintByDeliveryId.isEmpty ||
          this.poweredSectionToDeliveryId.isEmpty) {
        throw ArgumentError(
          'Powered CCTV06 contract requires PWR06 delivery and section mapping.',
        );
      }
      for (final entry in this.poweredSectionToDeliveryId.entries) {
        if (!sectionIds.contains(entry.key) ||
            !this.expectedPwr06InputFingerprintByDeliveryId.containsKey(
              entry.value,
            )) {
          throw ArgumentError(
            'CCTV06 powered section mapping is outside section/delivery closure.',
          );
        }
      }
    } else if (pseId != null ||
        scenarioId != null ||
        segmentId != null ||
        this.expectedPwr06InputFingerprintByDeliveryId.isNotEmpty ||
        this.poweredSectionToDeliveryId.isNotEmpty) {
      throw ArgumentError(
        'Unpowered CCTV06 contract cannot carry PWR06 binding.',
      );
    }
  }

  static const schema = 'electra.elv5-cctv06-link-contract.v1';

  final String linkId;
  final String expectedCompositionFingerprint;
  final Set<String> allowedMediaCodes;
  final Set<String> allowedInterfaceKinds;
  final Set<String> allowedCategoryTokens;
  final bool shieldingRequired;
  final Elv5Rational? maximumLengthM;
  final List<Cctv06SectionEvidenceContract> sections;
  final bool powered;
  final String? pseId;
  final String? scenarioId;
  final String? segmentId;
  final Map<String, String> expectedPwr06InputFingerprintByDeliveryId;
  final Map<String, String> poweredSectionToDeliveryId;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'linkId': linkId,
    'expectedCompositionFingerprint': expectedCompositionFingerprint,
    'allowedMediaCodes': allowedMediaCodes.toList()..sort(),
    'allowedInterfaceKinds': allowedInterfaceKinds.toList()..sort(),
    'allowedCategoryTokens': allowedCategoryTokens.toList()..sort(),
    'shieldingRequired': shieldingRequired,
    'maximumLengthM': maximumLengthM?.toMap(),
    'sections': <Object?>[
      for (final section in sections) section.toCanonicalValue(),
    ],
    'powered': powered,
    'pseId': pseId,
    'scenarioId': scenarioId,
    'segmentId': segmentId,
    'expectedPwr06InputFingerprintByDeliveryId': <String, Object?>{
      for (final key
          in expectedPwr06InputFingerprintByDeliveryId.keys.toList()..sort())
        key: expectedPwr06InputFingerprintByDeliveryId[key],
    },
    'poweredSectionToDeliveryId': <String, Object?>{
      for (final key in poweredSectionToDeliveryId.keys.toList()..sort())
        key: poweredSectionToDeliveryId[key],
    },
  };

  factory Cctv06LinkContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'schema',
      'linkId',
      'expectedCompositionFingerprint',
      'allowedMediaCodes',
      'allowedInterfaceKinds',
      'allowedCategoryTokens',
      'shieldingRequired',
      'maximumLengthM',
      'sections',
      'powered',
      'pseId',
      'scenarioId',
      'segmentId',
      'expectedPwr06InputFingerprintByDeliveryId',
      'poweredSectionToDeliveryId',
    }, 'CCTV06 link contract');
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported CCTV06 link contract schema.');
    }
    final sections = map['sections'];
    if (sections is! List) {
      throw const FormatException('CCTV06 sections must be list.');
    }
    return Cctv06LinkContract(
      linkId: _mapText(map, 'linkId'),
      expectedCompositionFingerprint: _mapText(
        map,
        'expectedCompositionFingerprint',
      ),
      allowedMediaCodes: _strings(
        map['allowedMediaCodes'],
        'allowedMediaCodes',
      ),
      allowedInterfaceKinds: _strings(
        map['allowedInterfaceKinds'],
        'allowedInterfaceKinds',
      ),
      allowedCategoryTokens: _strings(
        map['allowedCategoryTokens'],
        'allowedCategoryTokens',
      ),
      shieldingRequired: _bool(map, 'shieldingRequired'),
      maximumLengthM: map['maximumLengthM'] == null
          ? null
          : Elv5Rational.fromMap(_map(map['maximumLengthM'], 'maximumLengthM')),
      sections: <Cctv06SectionEvidenceContract>[
        for (final raw in sections)
          Cctv06SectionEvidenceContract.fromMap(_map(raw, 'section')),
      ],
      powered: _bool(map, 'powered'),
      pseId: _nullableText(map['pseId'], 'pseId'),
      scenarioId: _nullableText(map['scenarioId'], 'scenarioId'),
      segmentId: _nullableText(map['segmentId'], 'segmentId'),
      expectedPwr06InputFingerprintByDeliveryId: _stringMap(
        map['expectedPwr06InputFingerprintByDeliveryId'],
        'expectedPwr06InputFingerprintByDeliveryId',
      ),
      poweredSectionToDeliveryId: _stringMap(
        map['poweredSectionToDeliveryId'],
        'poweredSectionToDeliveryId',
      ),
    );
  }
}

final class Cctv06LinkContractSnapshot {
  const Cctv06LinkContractSnapshot({
    required this.bindingId,
    required this.bindingRevision,
    required this.evidenceRef,
    required this.contentHash,
    required this.contract,
  });

  final String bindingId;
  final int bindingRevision;
  final String evidenceRef;
  final String contentHash;
  final Cctv06LinkContract contract;
}

abstract interface class Cctv06LinkContractSource {
  Future<Cctv06LinkContractSnapshot?> loadActiveForLink({
    required String projectId,
    required String designRevisionId,
    required String linkId,
  });
}

final class ReplaceCctv06LinkContractCommand {
  ReplaceCctv06LinkContractCommand({
    required this.projectId,
    required this.designRevisionId,
    required this.expectedDesignRevision,
    required this.bindingId,
    required this.expectedBindingRevision,
    required this.contract,
  }) {
    _text(projectId, 'projectId');
    _text(designRevisionId, 'designRevisionId');
    _text(bindingId, 'bindingId');
    if (expectedDesignRevision < 1 ||
        (expectedBindingRevision != null && expectedBindingRevision! < 1)) {
      throw ArgumentError('CCTV06 expected revisions must be positive.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Cctv06LinkContract contract;
}

abstract interface class Cctv06LinkContractWriter {
  Future<void> replace(ReplaceCctv06LinkContractCommand command);
}

Map<String, String> _fingerprints(Map<String, String> values) =>
    <String, String>{
      for (final entry in values.entries)
        _text(entry.key, 'deliveryId'): _sha(entry.value, 'inputFingerprint'),
    };

String _medium(String value) {
  final normalized = _token(value, 'mediumCode');
  if (!const <String>{'COPPER', 'FIBER', 'OTHER'}.contains(normalized)) {
    throw ArgumentError('Unsupported CCTV06 medium $normalized');
  }
  return normalized;
}

String _token(String value, String field) => _text(value, field).toUpperCase();

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _sha(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('$key must be text.');
  return _text(value, key);
}

bool _bool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! bool) throw FormatException('$key must be bool.');
  return value;
}

List<String> _strings(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$field must be a string list.');
  }
  return value.cast<String>();
}

String? _nullableText(Object? value, String field) {
  if (value == null) return null;
  if (value is! String) throw FormatException('$field must be nullable text.');
  return _text(value, field);
}

Map<String, String> _stringMap(Object? value, String field) {
  final map = _map(value, field);
  return <String, String>{
    for (final entry in map.entries)
      _text(entry.key, field): entry.value is String
          ? _text(entry.value as String, field)
          : throw FormatException('$field value must be text.'),
  };
}

void _exact(Map<String, Object?> map, Set<String> expected, String field) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$field has missing or unknown fields.');
  }
}
