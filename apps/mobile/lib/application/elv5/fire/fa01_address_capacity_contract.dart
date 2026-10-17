final class Fa01AddressCapacityContract {
  Fa01AddressCapacityContract({
    required String loopId,
    required this.deviceLimit,
    required this.addressLimit,
    required this.requiredDeviceSpare,
    required this.requiredAddressSpare,
    required Map<String, int> profileAddressConsumption,
    required Map<String, int> profileDeviceCountContribution,
  }) : loopId = _text(loopId, 'loopId'),
       profileAddressConsumption = Map.unmodifiable(
         _profileConsumption(profileAddressConsumption, 'address consumption'),
       ),
       profileDeviceCountContribution = Map.unmodifiable(
         _profileConsumption(
           profileDeviceCountContribution,
           'device contribution',
         ),
       ) {
    if (deviceLimit < 0 ||
        addressLimit < 0 ||
        requiredDeviceSpare < 0 ||
        requiredAddressSpare < 0) {
      throw ArgumentError('FA01 limits/spares must be nonnegative.');
    }
    if (this.profileAddressConsumption.keys.toSet().length !=
            this.profileDeviceCountContribution.keys.toSet().length ||
        !this.profileAddressConsumption.keys.toSet().containsAll(
          this.profileDeviceCountContribution.keys,
        )) {
      throw ArgumentError(
        'FA01 profile resource maps must have identical keys.',
      );
    }
  }

  static const schema = 'electra.elv5-fa01-address-capacity-contract.v1';
  final String loopId;
  final int deviceLimit;
  final int addressLimit;
  final int requiredDeviceSpare;
  final int requiredAddressSpare;
  final Map<String, int> profileAddressConsumption;
  final Map<String, int> profileDeviceCountContribution;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'loopId': loopId,
    'deviceLimit': deviceLimit,
    'addressLimit': addressLimit,
    'requiredDeviceSpare': requiredDeviceSpare,
    'requiredAddressSpare': requiredAddressSpare,
    'profileAddressConsumption': <String, Object?>{
      for (final key in (profileAddressConsumption.keys.toList()..sort()))
        key: profileAddressConsumption[key],
    },
    'profileDeviceCountContribution': <String, Object?>{
      for (final key in (profileDeviceCountContribution.keys.toList()..sort()))
        key: profileDeviceCountContribution[key],
    },
  };

  factory Fa01AddressCapacityContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'schema',
      'loopId',
      'deviceLimit',
      'addressLimit',
      'requiredDeviceSpare',
      'requiredAddressSpare',
      'profileAddressConsumption',
      'profileDeviceCountContribution',
    });
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported FA01 contract schema.');
    }
    final addresses = map['profileAddressConsumption'];
    final devices = map['profileDeviceCountContribution'];
    if (addresses is! Map || devices is! Map) {
      throw const FormatException(
        'FA01 profile resource maps must be objects.',
      );
    }
    return Fa01AddressCapacityContract(
      loopId: _mapText(map, 'loopId'),
      deviceLimit: _int(map, 'deviceLimit'),
      addressLimit: _int(map, 'addressLimit'),
      requiredDeviceSpare: _int(map, 'requiredDeviceSpare'),
      requiredAddressSpare: _int(map, 'requiredAddressSpare'),
      profileAddressConsumption: _intMap(
        addresses,
        'profileAddressConsumption',
      ),
      profileDeviceCountContribution: _intMap(
        devices,
        'profileDeviceCountContribution',
      ),
    );
  }
}

final class Fa01AddressCapacityContractSnapshot {
  const Fa01AddressCapacityContractSnapshot({
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
  final Fa01AddressCapacityContract contract;
}

abstract interface class Fa01AddressCapacityContractSource {
  Future<Fa01AddressCapacityContractSnapshot?> loadActiveForLoop({
    required String projectId,
    required String designRevisionId,
    required String loopId,
  });
}

Map<String, int> _profileConsumption(Map<String, int> input, String label) {
  final out = <String, int>{};
  for (final entry in input.entries) {
    final key = _text(entry.key, 'profileRef');
    if (entry.value <= 0) {
      throw ArgumentError('FA01 profile $label must be positive: $key');
    }
    out[key] = entry.value;
  }
  if (out.isEmpty) throw ArgumentError('FA01 profile map must not be empty.');
  return out;
}

Map<String, int> _intMap(Map raw, String field) {
  final out = <String, int>{};
  for (final entry in raw.entries) {
    if (entry.value is! int)
      throw FormatException('$field values must be int.');
    out[_text(entry.key.toString(), 'profileRef')] = entry.value as int;
  }
  return out;
}

void _exact(Map<String, Object?> map, Set<String> expected) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw const FormatException('FA01 contract has missing or unknown fields.');
  }
}

int _int(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('$key must be int.');
  return value;
}

String _mapText(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('$key must be text.');
  return _text(value, key);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty)
    throw ArgumentError.value(value, field, 'Must not be empty.');
  return normalized;
}
