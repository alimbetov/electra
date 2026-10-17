import 'package:engineering_core/engineering_core_elv5.dart';

final class Lan02PolicyIdentity {
  Lan02PolicyIdentity({
    required String policyCode,
    required String editionId,
    required String contentHash,
  }) : policyCode = _text(policyCode, 'policyCode'),
       editionId = _text(editionId, 'editionId'),
       contentHash = _sha(contentHash, 'contentHash');
  final String policyCode;
  final String editionId;
  final String contentHash;
  Map<String, Object?> toCanonicalValue() => {
    'policyCode': policyCode,
    'editionId': editionId,
    'contentHash': contentHash,
  };
  factory Lan02PolicyIdentity.fromMap(Map<String, Object?> map) {
    _exact(map, const {'policyCode', 'editionId', 'contentHash'}, 'policy');
    return Lan02PolicyIdentity(
      policyCode: _mapText(map, 'policyCode'),
      editionId: _mapText(map, 'editionId'),
      contentHash: _mapText(map, 'contentHash'),
    );
  }
}

final class Lan02PortContractItem {
  Lan02PortContractItem({
    required String portId,
    required String media,
    required this.maxSpeedMbps,
  }) : portId = _text(portId, 'portId'),
       media = _text(media, 'media').toUpperCase() {
    if (maxSpeedMbps <= 0)
      throw ArgumentError('LAN02 maxSpeedMbps must be positive.');
  }
  final String portId;
  final String media;
  final int maxSpeedMbps;
  Map<String, Object?> toCanonicalValue() => {
    'portId': portId,
    'media': media,
    'maxSpeedMbps': maxSpeedMbps,
  };
  factory Lan02PortContractItem.fromMap(Map<String, Object?> map) {
    _exact(map, const {'portId', 'media', 'maxSpeedMbps'}, 'port');
    final speed = map['maxSpeedMbps'];
    if (speed is! int)
      throw const FormatException('maxSpeedMbps must be integer.');
    return Lan02PortContractItem(
      portId: _mapText(map, 'portId'),
      media: _mapText(map, 'media'),
      maxSpeedMbps: speed,
    );
  }
}

final class Lan02PortContract {
  Lan02PortContract({
    required String switchId,
    required String expectedAggregateFingerprint,
    required this.sparePolicy,
    required Iterable<Lan02PortContractItem> ports,
    Iterable<String> unavailablePortIds = const [],
    required this.absoluteMinimum,
    required this.ratio,
    required String combinerCode,
  }) : switchId = _text(switchId, 'switchId'),
       expectedAggregateFingerprint = _sha(
         expectedAggregateFingerprint,
         'expectedAggregateFingerprint',
       ),
       ports = List.unmodifiable(_ports(ports)),
       unavailablePortIds = Set.unmodifiable(
         unavailablePortIds.map((e) => _text(e, 'unavailablePortId')),
       ),
       combinerCode = _combiner(combinerCode) {
    if (absoluteMinimum < 0 || ratio < Elv5Rational.zero)
      throw ArgumentError('LAN02 spare values must be nonnegative.');
    final ids = this.ports.map((e) => e.portId).toSet();
    if (!ids.containsAll(this.unavailablePortIds))
      throw ArgumentError('LAN02 unavailable port must exist in inventory.');
  }
  static const schema = 'electra.elv5-lan02-port-contract.v1';
  final String switchId;
  final String expectedAggregateFingerprint;
  final Lan02PolicyIdentity sparePolicy;
  final List<Lan02PortContractItem> ports;
  final Set<String> unavailablePortIds;
  final int absoluteMinimum;
  final Elv5Rational ratio;
  final String combinerCode;
  Map<String, Object?> toCanonicalValue() => {
    'schema': schema,
    'switchId': switchId,
    'expectedAggregateFingerprint': expectedAggregateFingerprint,
    'sparePolicy': sparePolicy.toCanonicalValue(),
    'ports': [for (final p in ports) p.toCanonicalValue()],
    'unavailablePortIds': unavailablePortIds.toList()..sort(),
    'absoluteMinimum': absoluteMinimum,
    'ratio': ratio.toMap(),
    'combinerCode': combinerCode,
  };
  factory Lan02PortContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {
      'schema',
      'switchId',
      'expectedAggregateFingerprint',
      'sparePolicy',
      'ports',
      'unavailablePortIds',
      'absoluteMinimum',
      'ratio',
      'combinerCode',
    }, 'LAN02 contract');
    if (map['schema'] != schema)
      throw const FormatException('Unsupported LAN02 contract schema.');
    final ports = map['ports'];
    final unavailable = map['unavailablePortIds'];
    final minimum = map['absoluteMinimum'];
    if (ports is! List || unavailable is! List || minimum is! int)
      throw const FormatException('LAN02 contract field type mismatch.');
    return Lan02PortContract(
      switchId: _mapText(map, 'switchId'),
      expectedAggregateFingerprint: _mapText(
        map,
        'expectedAggregateFingerprint',
      ),
      sparePolicy: Lan02PolicyIdentity.fromMap(
        _map(map['sparePolicy'], 'sparePolicy'),
      ),
      ports: [
        for (final raw in ports)
          Lan02PortContractItem.fromMap(_map(raw, 'port')),
      ],
      unavailablePortIds: [
        for (final raw in unavailable) _string(raw, 'unavailablePortId'),
      ],
      absoluteMinimum: minimum,
      ratio: Elv5Rational.fromMap(_map(map['ratio'], 'ratio')),
      combinerCode: _mapText(map, 'combinerCode'),
    );
  }
}

final class Lan02PortContractSnapshot {
  const Lan02PortContractSnapshot({
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
  final Lan02PortContract contract;
}

abstract interface class Lan02PortContractSource {
  Future<Lan02PortContractSnapshot?> loadActiveForSwitch({
    required String projectId,
    required String designRevisionId,
    required String switchId,
  });
}

final class ReplaceLan02PortContractCommand {
  ReplaceLan02PortContractCommand({
    required this.projectId,
    required this.designRevisionId,
    required this.expectedDesignRevision,
    required this.bindingId,
    required this.expectedBindingRevision,
    required this.contract,
  }) {
    if (projectId.trim().isEmpty ||
        designRevisionId.trim().isEmpty ||
        bindingId.trim().isEmpty)
      throw ArgumentError('LAN02 command identity is required.');
    if (expectedDesignRevision < 1 ||
        (expectedBindingRevision != null && expectedBindingRevision! < 1))
      throw ArgumentError('LAN02 expected revisions must be positive.');
  }
  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Lan02PortContract contract;
}

abstract interface class Lan02PortContractWriter {
  Future<void> replace(ReplaceLan02PortContractCommand command);
}

List<Lan02PortContractItem> _ports(Iterable<Lan02PortContractItem> values) {
  final out = values.toList()..sort((a, b) => a.portId.compareTo(b.portId));
  final ids = <String>{};
  for (final p in out) {
    if (!ids.add(p.portId))
      throw ArgumentError('LAN02 duplicate portId: ${p.portId}');
  }
  if (out.isEmpty)
    throw ArgumentError('LAN02 port inventory must not be empty.');
  return out;
}

String _combiner(String value) {
  final code = _text(value, 'combinerCode').toUpperCase();
  if (code != 'MAX' && code != 'SUM')
    throw ArgumentError('LAN02 unsupported spare combiner: $code');
  return code;
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String key) => _string(map[key], key);
String _string(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be text.');
  return _text(value, field);
}

String _text(String value, String field) {
  final v = value.trim();
  if (v.isEmpty) throw ArgumentError.value(value, field, 'Must not be empty.');
  return v;
}

String _sha(String value, String field) {
  final v = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(v))
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  return v;
}

void _exact(Map<String, Object?> map, Set<String> expected, String field) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty)
    throw FormatException('$field has missing or unknown fields.');
}
