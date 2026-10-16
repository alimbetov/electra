enum Fa01AssessmentStatus { pass, fail }

final class Fa01AddressKey {
  const Fa01AddressKey({required this.domainId, required this.address});
  final String domainId;
  final int address;

  @override
  bool operator ==(Object other) =>
      other is Fa01AddressKey && other.domainId == domainId && other.address == address;

  @override
  int get hashCode => Object.hash(domainId, address);
}

final class Fa01DeviceAssignment {
  Fa01DeviceAssignment({
    required this.deviceId,
    required this.addresses,
    required this.expectedConsumption,
  }) {
    if (deviceId.isEmpty || expectedConsumption <= 0) {
      throw ArgumentError('FA01 invalid device assignment.');
    }
    if (addresses.length != expectedConsumption) {
      throw ArgumentError('FA01 address expansion cardinality mismatch for $deviceId.');
    }
  }
  final String deviceId;
  final Set<Fa01AddressKey> addresses;
  final int expectedConsumption;
}

final class Fa01CapacityPolicy {
  const Fa01CapacityPolicy({
    required this.deviceLimit,
    required this.addressLimit,
    this.requiredDeviceSpare = 0,
    this.requiredAddressSpare = 0,
  });
  final int deviceLimit;
  final int addressLimit;
  final int requiredDeviceSpare;
  final int requiredAddressSpare;
}

final class Fa01Input {
  Fa01Input({
    required this.loopId,
    required this.devices,
    required this.reserved,
    required this.policy,
  }) {
    if (loopId.isEmpty) throw ArgumentError('FA01 loopId must not be empty.');
    final ids = <String>{};
    for (final device in devices) {
      if (!ids.add(device.deviceId)) {
        throw ArgumentError('FA01 duplicate deviceId: ${device.deviceId}');
      }
    }
  }
  final String loopId;
  final List<Fa01DeviceAssignment> devices;
  final Set<Fa01AddressKey> reserved;
  final Fa01CapacityPolicy policy;
}

final class Fa01Collision {
  const Fa01Collision({required this.key, required this.claimants});
  final Fa01AddressKey key;
  final List<String> claimants;
}

final class Fa01Result {
  const Fa01Result({
    required this.status,
    required this.deviceCount,
    required this.addressCount,
    required this.deviceHeadroom,
    required this.addressHeadroom,
    required this.collisions,
  });
  final Fa01AssessmentStatus status;
  final int deviceCount;
  final int addressCount;
  final int deviceHeadroom;
  final int addressHeadroom;
  final List<Fa01Collision> collisions;
}

final class Fa01AddressCapacityKernel {
  const Fa01AddressCapacityKernel();

  Fa01Result evaluate(Fa01Input input) {
    final claims = <Fa01AddressKey, List<String>>{};
    var addressCount = 0;
    for (final device in input.devices) {
      addressCount += device.addresses.length;
      for (final key in device.addresses) {
        claims.putIfAbsent(key, () => <String>[]).add(device.deviceId);
      }
    }
    for (final key in input.reserved) {
      claims.putIfAbsent(key, () => <String>[]).add('RESERVED');
    }
    final collisions = claims.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => Fa01Collision(
              key: entry.key,
              claimants: List.unmodifiable([...entry.value]..sort()),
            ))
        .toList()
      ..sort((a, b) {
        final d = a.key.domainId.compareTo(b.key.domainId);
        return d != 0 ? d : a.key.address.compareTo(b.key.address);
      });

    final deviceCount = input.devices.length;
    final deviceHeadroom = input.policy.deviceLimit - deviceCount - input.policy.requiredDeviceSpare;
    final addressHeadroom = input.policy.addressLimit - addressCount - input.policy.requiredAddressSpare;
    final status = collisions.isEmpty && deviceHeadroom >= 0 && addressHeadroom >= 0
        ? Fa01AssessmentStatus.pass
        : Fa01AssessmentStatus.fail;
    return Fa01Result(
      status: status,
      deviceCount: deviceCount,
      addressCount: addressCount,
      deviceHeadroom: deviceHeadroom,
      addressHeadroom: addressHeadroom,
      collisions: List.unmodifiable(collisions),
    );
  }
}
