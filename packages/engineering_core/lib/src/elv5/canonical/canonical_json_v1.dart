import 'dart:convert';
import 'dart:typed_data';

import '../../engineering_hash.dart' show sha256HexUtf8;

abstract interface class Elv5CanonicalValue {
  Object? toCanonicalValue();
}

abstract interface class Elv5CanonicalEncoder {
  String get version;
  Uint8List encode(Object? value);
  String sha256(Object? value);
}

final class Elv5CanonicalJsonV1 implements Elv5CanonicalEncoder {
  const Elv5CanonicalJsonV1();

  @override
  String get version => 'electra.canonical-json.v1';

  @override
  Uint8List encode(Object? value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(_canonicalize(value))));

  @override
  String sha256(Object? value) =>
      sha256HexUtf8(utf8.decode(encode(value), allowMalformed: false));
}

Object? _canonicalize(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is BigInt) return value.toString();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Enum) return value.name;
  if (value is Elv5CanonicalValue) {
    return _canonicalize(value.toCanonicalValue());
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError('Canonical JSON map keys must be strings.');
      }
      if (result.containsKey(key)) {
        throw ArgumentError('Duplicate canonical map key: $key');
      }
      result[key] = _canonicalize(entry.value);
    }
    final keys = result.keys.toList()..sort();
    return <String, Object?>{for (final key in keys) key: result[key]};
  }
  if (value is Set) {
    final items = value.map(_canonicalize).toList(growable: false);
    final keyed = <(String, Object?)>[
      for (final item in items) (jsonEncode(item), item),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return <Object?>[for (final item in keyed) item.$2];
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  throw ArgumentError(
    'Unsupported canonical JSON value type: ${value.runtimeType}',
  );
}
