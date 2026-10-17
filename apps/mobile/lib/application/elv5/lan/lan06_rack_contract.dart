import 'package:engineering_core/engineering_core_elv5.dart';

final class Lan06PolicyRef {
  Lan06PolicyRef({
    required String policyCode,
    required String editionId,
    required String contentHash,
  })  : policyCode = _text(policyCode, 'policyCode'),
        editionId = _text(editionId, 'editionId'),
        contentHash = _sha(contentHash, 'contentHash');

  final String policyCode;
  final String editionId;
  final String contentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'policyCode': policyCode,
        'editionId': editionId,
        'contentHash': contentHash,
      };

  factory Lan06PolicyRef.fromMap(Map<String, Object?> map) {
    _exact(map, const {'policyCode', 'editionId', 'contentHash'}, 'policyRef');
    return Lan06PolicyRef(
      policyCode: _mapText(map, 'policyCode'),
      editionId: _mapText(map, 'editionId'),
      contentHash: _mapText(map, 'contentHash'),
    );
  }
}

final class Lan06EquipmentBasisContract {
  Lan06EquipmentBasisContract({
    required String equipmentId,
    required this.ru,
    required this.weightKg,
    required this.depthM,
    required String evidenceRef,
    required String evidenceContentHash,
  })  : equipmentId = _text(equipmentId, 'equipmentId'),
        evidenceRef = _text(evidenceRef, 'evidenceRef'),
        evidenceContentHash = _sha(evidenceContentHash, 'evidenceContentHash') {
    if (ru < 0) throw ArgumentError('LAN06 equipment RU must be nonnegative.');
    if (weightKg != null && weightKg! < Elv5Rational.zero) {
      throw ArgumentError('LAN06 equipment weight must be nonnegative.');
    }
    if (depthM != null && depthM! < Elv5Rational.zero) {
      throw ArgumentError('LAN06 equipment depth must be nonnegative.');
    }
  }

  final String equipmentId;
  final int ru;
  final Elv5Rational? weightKg;
  final Elv5Rational? depthM;
  final String evidenceRef;
  final String evidenceContentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'equipmentId': equipmentId,
        'ru': ru,
        'weightKg': weightKg?.toMap(),
        'depthM': depthM?.toMap(),
        'evidenceRef': evidenceRef,
        'evidenceContentHash': evidenceContentHash,
      };

  factory Lan06EquipmentBasisContract.fromMap(Map<String, Object?> map) {
    _exact(
      map,
      const {
        'equipmentId',
        'ru',
        'weightKg',
        'depthM',
        'evidenceRef',
        'evidenceContentHash',
      },
      'equipment',
    );
    final ru = map['ru'];
    if (ru is! int) throw const FormatException('LAN06 equipment ru must be integer.');
    return Lan06EquipmentBasisContract(
      equipmentId: _mapText(map, 'equipmentId'),
      ru: ru,
      weightKg: _nullableRational(map['weightKg'], 'weightKg'),
      depthM: _nullableRational(map['depthM'], 'depthM'),
      evidenceRef: _mapText(map, 'evidenceRef'),
      evidenceContentHash: _mapText(map, 'evidenceContentHash'),
    );
  }
}

final class Lan06RackBasisContract {
  Lan06RackBasisContract({
    required String rackId,
    required String expectedAggregateFingerprint,
    required Lan06PolicyRef policyRef,
    required this.ruCapacity,
    required this.weightCapacityKg,
    required this.depthCapacityM,
    required this.explicitSpareRu,
    required Iterable<Lan06EquipmentBasisContract> equipment,
    required String rackEvidenceRef,
    required String rackEvidenceContentHash,
  })  : rackId = _text(rackId, 'rackId'),
        expectedAggregateFingerprint =
            _sha(expectedAggregateFingerprint, 'expectedAggregateFingerprint'),
        policyRef = policyRef,
        equipment = List.unmodifiable(_equipment(equipment)),
        rackEvidenceRef = _text(rackEvidenceRef, 'rackEvidenceRef'),
        rackEvidenceContentHash =
            _sha(rackEvidenceContentHash, 'rackEvidenceContentHash') {
    if (ruCapacity < 0 || explicitSpareRu < 0) {
      throw ArgumentError('LAN06 rack capacity/spare must be nonnegative.');
    }
    if (weightCapacityKg != null && weightCapacityKg! < Elv5Rational.zero) {
      throw ArgumentError('LAN06 weight capacity must be nonnegative.');
    }
    if (depthCapacityM != null && depthCapacityM! < Elv5Rational.zero) {
      throw ArgumentError('LAN06 depth capacity must be nonnegative.');
    }
  }

  static const schema = 'electra.elv5-lan06-rack-basis-contract.v1';

  final String rackId;
  final String expectedAggregateFingerprint;
  final Lan06PolicyRef policyRef;
  final int ruCapacity;
  final Elv5Rational? weightCapacityKg;
  final Elv5Rational? depthCapacityM;
  final int explicitSpareRu;
  final List<Lan06EquipmentBasisContract> equipment;
  final String rackEvidenceRef;
  final String rackEvidenceContentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': schema,
        'rackId': rackId,
        'expectedAggregateFingerprint': expectedAggregateFingerprint,
        'policyRef': policyRef.toCanonicalValue(),
        'ruCapacity': ruCapacity,
        'weightCapacityKg': weightCapacityKg?.toMap(),
        'depthCapacityM': depthCapacityM?.toMap(),
        'explicitSpareRu': explicitSpareRu,
        'equipment': [for (final item in equipment) item.toCanonicalValue()],
        'rackEvidenceRef': rackEvidenceRef,
        'rackEvidenceContentHash': rackEvidenceContentHash,
      };

  factory Lan06RackBasisContract.fromMap(Map<String, Object?> map) {
    _exact(
      map,
      const {
        'schema',
        'rackId',
        'expectedAggregateFingerprint',
        'policyRef',
        'ruCapacity',
        'weightCapacityKg',
        'depthCapacityM',
        'explicitSpareRu',
        'equipment',
        'rackEvidenceRef',
        'rackEvidenceContentHash',
      },
      'LAN06 contract',
    );
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported LAN06 contract schema.');
    }
    final ruCapacity = map['ruCapacity'];
    final explicitSpareRu = map['explicitSpareRu'];
    final equipment = map['equipment'];
    if (ruCapacity is! int || explicitSpareRu is! int || equipment is! List) {
      throw const FormatException('LAN06 integer/list fields are invalid.');
    }
    return Lan06RackBasisContract(
      rackId: _mapText(map, 'rackId'),
      expectedAggregateFingerprint: _mapText(map, 'expectedAggregateFingerprint'),
      policyRef: Lan06PolicyRef.fromMap(_map(map['policyRef'], 'policyRef')),
      ruCapacity: ruCapacity,
      weightCapacityKg: _nullableRational(map['weightCapacityKg'], 'weightCapacityKg'),
      depthCapacityM: _nullableRational(map['depthCapacityM'], 'depthCapacityM'),
      explicitSpareRu: explicitSpareRu,
      equipment: [
        for (final raw in equipment)
          Lan06EquipmentBasisContract.fromMap(_map(raw, 'equipment')),
      ],
      rackEvidenceRef: _mapText(map, 'rackEvidenceRef'),
      rackEvidenceContentHash: _mapText(map, 'rackEvidenceContentHash'),
    );
  }
}

String lan06AggregateFingerprint(Map<String, Object?> payload) =>
    const Elv5CanonicalJsonV1().sha256(<String, Object?>{
      'schema': 'electra.elv5-lan06-rack-aggregate-fingerprint.v1',
      'payload': payload,
    });

final class Lan06RackBasisContractSnapshot {
  const Lan06RackBasisContractSnapshot({
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
  final Lan06RackBasisContract contract;
}

abstract interface class Lan06RackBasisContractSource {
  Future<Lan06RackBasisContractSnapshot?> loadActiveForRack({
    required String projectId,
    required String designRevisionId,
    required String rackId,
  });
}

final class ReplaceLan06RackBasisContractCommand {
  ReplaceLan06RackBasisContractCommand({
    required this.projectId,
    required this.designRevisionId,
    required this.expectedDesignRevision,
    required this.bindingId,
    required this.expectedBindingRevision,
    required this.contract,
  }) {
    if (projectId.trim().isEmpty ||
        designRevisionId.trim().isEmpty ||
        bindingId.trim().isEmpty) {
      throw ArgumentError('LAN06 command identity is required.');
    }
    if (expectedDesignRevision < 1 ||
        (expectedBindingRevision != null && expectedBindingRevision! < 1)) {
      throw ArgumentError('LAN06 expected revisions must be positive.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Lan06RackBasisContract contract;
}

abstract interface class Lan06RackBasisContractWriter {
  Future<void> replace(ReplaceLan06RackBasisContractCommand command);
}

List<Lan06EquipmentBasisContract> _equipment(
  Iterable<Lan06EquipmentBasisContract> input,
) {
  final values = input.toList()
    ..sort((a, b) => a.equipmentId.compareTo(b.equipmentId));
  if (values.isEmpty) throw ArgumentError('LAN06 equipment must not be empty.');
  final seen = <String>{};
  for (final item in values) {
    if (!seen.add(item.equipmentId)) {
      throw ArgumentError('LAN06 duplicate equipmentId: ${item.equipmentId}');
    }
  }
  return values;
}

Elv5Rational? _nullableRational(Object? value, String field) {
  if (value == null) return null;
  return Elv5Rational.fromMap(_map(value, field));
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

void _exact(Map<String, Object?> map, Set<String> expected, String field) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$field has missing or unknown fields.');
  }
}
