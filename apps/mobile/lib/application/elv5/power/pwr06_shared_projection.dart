import 'package:engineering_core/engineering_core_elv5.dart';

/// Canonical physical PoE-capacity-group closure shared by LAN-03 and CCTV-04.
///
/// Discipline-specific projection processes must hash the same complete PWR-06
/// membership into the same closure fingerprint. A filtered LAN-only or
/// CCTV-only member set is therefore a different closure and cannot masquerade
/// as the physical PSE budget.
String elv5Pwr06SharedClosureFingerprint({
  required String pseId,
  required Iterable<Map<String, Object?>> members,
}) {
  final normalized = <Map<String, Object?>>[];
  for (final member in members) {
    normalized.add(<String, Object?>{
      'originId': _text(member, 'originId'),
      'portId': _text(member, 'portId'),
      'reservedW': Elv5Rational.fromMap(
        _map(member['reservedW'], 'reservedW'),
      ).toMap(),
    });
  }
  normalized.sort(
    (a, b) => (a['originId']! as String).compareTo(b['originId']! as String),
  );
  return const Elv5CanonicalJsonV1().sha256(<String, Object?>{
    'schema': 'electra.elv5-pwr06-shared-closure.v1',
    'pseId': _requiredText(pseId, 'pseId'),
    'members': normalized,
  });
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

String _text(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('$key must be text.');
  return _requiredText(value, key);
}

String _requiredText(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
