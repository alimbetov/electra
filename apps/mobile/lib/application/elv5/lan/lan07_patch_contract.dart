import 'package:engineering_core/engineering_core_elv5.dart';

final class Lan07PolicyRef {
  Lan07PolicyRef({
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

  factory Lan07PolicyRef.fromMap(Map<String, Object?> map) {
    _exact(map, const {'policyCode', 'editionId', 'contentHash'}, 'policyRef');
    return Lan07PolicyRef(
      policyCode: _mapText(map, 'policyCode'),
      editionId: _mapText(map, 'editionId'),
      contentHash: _mapText(map, 'contentHash'),
    );
  }
}

final class Lan07PatchPanelContract {
  Lan07PatchPanelContract({
    required String panelId,
    required String expectedAggregateFingerprint,
    required Lan07PolicyRef policyRef,
    required Iterable<String> physicalPortIds,
    required Iterable<String> unavailablePortIds,
    required Iterable<String> requiredSourceEndpointIds,
    required this.absoluteMinimumSpare,
    required Elv5Rational spareRatio,
    required String spareCombinerCode,
    required String panelEvidenceRef,
    required String panelEvidenceContentHash,
  })  : panelId = _text(panelId, 'panelId'),
        expectedAggregateFingerprint =
            _sha(expectedAggregateFingerprint, 'expectedAggregateFingerprint'),
        policyRef = policyRef,
        physicalPortIds = Set.unmodifiable(
          physicalPortIds.map((value) => _text(value, 'physicalPortId')),
        ),
        unavailablePortIds = Set.unmodifiable(
          unavailablePortIds.map((value) => _text(value, 'unavailablePortId')),
        ),
        requiredSourceEndpointIds = Set.unmodifiable(
          requiredSourceEndpointIds.map(
            (value) => _text(value, 'requiredSourceEndpointId'),
          ),
        ),
        spareRatio = spareRatio,
        spareCombinerCode = _combiner(spareCombinerCode),
        panelEvidenceRef = _text(panelEvidenceRef, 'panelEvidenceRef'),
        panelEvidenceContentHash =
            _sha(panelEvidenceContentHash, 'panelEvidenceContentHash') {
    if (this.physicalPortIds.isEmpty) {
      throw ArgumentError('LAN07 physical port inventory must not be empty.');
    }
    if (!this.physicalPortIds.containsAll(this.unavailablePortIds)) {
      throw ArgumentError('LAN07 unavailable ports must belong to inventory.');
    }
    if (absoluteMinimumSpare < 0 || spareRatio < Elv5Rational.zero) {
      throw ArgumentError('LAN07 spare policy must be nonnegative.');
    }
  }

  static const schema = 'electra.elv5-lan07-patch-panel-contract.v1';

  final String panelId;
  final String expectedAggregateFingerprint;
  final Lan07PolicyRef policyRef;
  final Set<String> physicalPortIds;
  final Set<String> unavailablePortIds;
  final Set<String> requiredSourceEndpointIds;
  final int absoluteMinimumSpare;
  final Elv5Rational spareRatio;
  final String spareCombinerCode;
  final String panelEvidenceRef;
  final String panelEvidenceContentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': schema,
        'panelId': panelId,
        'expectedAggregateFingerprint': expectedAggregateFingerprint,
        'policyRef': policyRef.toCanonicalValue(),
        'physicalPortIds': physicalPortIds.toList()..sort(),
        'unavailablePortIds': unavailablePortIds.toList()..sort(),
        'requiredSourceEndpointIds': requiredSourceEndpointIds.toList()..sort(),
        'absoluteMinimumSpare': absoluteMinimumSpare,
        'spareRatio': spareRatio.toMap(),
        'spareCombinerCode': spareCombinerCode,
        'panelEvidenceRef': panelEvidenceRef,
        'panelEvidenceContentHash': panelEvidenceContentHash,
      };

  factory Lan07PatchPanelContract.fromMap(Map<String, Object?> map) {
    _exact(
      map,
      const {
        'schema',
        'panelId',
        'expectedAggregateFingerprint',
        'policyRef',
        'physicalPortIds',
        'unavailablePortIds',
        'requiredSourceEndpointIds',
        'absoluteMinimumSpare',
        'spareRatio',
        'spareCombinerCode',
        'panelEvidenceRef',
        'panelEvidenceContentHash',
      },
      'LAN07 contract',
    );
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported LAN07 contract schema.');
    }
    final absoluteMinimumSpare = map['absoluteMinimumSpare'];
    if (absoluteMinimumSpare is! int) {
      throw const FormatException('LAN07 absoluteMinimumSpare must be integer.');
    }
    return Lan07PatchPanelContract(
      panelId: _mapText(map, 'panelId'),
      expectedAggregateFingerprint: _mapText(map, 'expectedAggregateFingerprint'),
      policyRef: Lan07PolicyRef.fromMap(_map(map['policyRef'], 'policyRef')),
      physicalPortIds: _strings(map['physicalPortIds'], 'physicalPortIds'),
      unavailablePortIds:
          _strings(map['unavailablePortIds'], 'unavailablePortIds'),
      requiredSourceEndpointIds: _strings(
        map['requiredSourceEndpointIds'],
        'requiredSourceEndpointIds',
      ),
      absoluteMinimumSpare: absoluteMinimumSpare,
      spareRatio: Elv5Rational.fromMap(_map(map['spareRatio'], 'spareRatio')),
      spareCombinerCode: _mapText(map, 'spareCombinerCode'),
      panelEvidenceRef: _mapText(map, 'panelEvidenceRef'),
      panelEvidenceContentHash: _mapText(map, 'panelEvidenceContentHash'),
    );
  }
}

String lan07AggregateFingerprint(Map<String, Object?> payload) =>
    const Elv5CanonicalJsonV1().sha256(<String, Object?>{
      'schema': 'electra.elv5-lan07-patch-aggregate-fingerprint.v1',
      'payload': payload,
    });

final class Lan07PatchPanelContractSnapshot {
  const Lan07PatchPanelContractSnapshot({
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
  final Lan07PatchPanelContract contract;
}

abstract interface class Lan07PatchPanelContractSource {
  Future<Lan07PatchPanelContractSnapshot?> loadActiveForPanel({
    required String projectId,
    required String designRevisionId,
    required String panelId,
  });
}

final class ReplaceLan07PatchPanelContractCommand {
  ReplaceLan07PatchPanelContractCommand({
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
      throw ArgumentError('LAN07 command identity is required.');
    }
    if (expectedDesignRevision < 1 ||
        (expectedBindingRevision != null && expectedBindingRevision! < 1)) {
      throw ArgumentError('LAN07 expected revisions must be positive.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Lan07PatchPanelContract contract;
}

abstract interface class Lan07PatchPanelContractWriter {
  Future<void> replace(ReplaceLan07PatchPanelContractCommand command);
}

String _combiner(String value) {
  final normalized = _text(value, 'spareCombinerCode').toUpperCase();
  if (!const {'MAX', 'SUM'}.contains(normalized)) {
    throw ArgumentError('LAN07 unsupported spare combiner: $normalized');
  }
  return normalized;
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

List<String> _strings(Object? value, String field) {
  if (value is! List || value.any((element) => element is! String)) {
    throw FormatException('$field must be string array.');
  }
  return [for (final item in value) _text(item as String, field)];
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
