import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  test('FA-01 counts devices and expanded addresses independently', () {
    final result = const Fa01AddressCapacityKernel().evaluate(
      Fa01Input(
        loopId: 'loop-1',
        devices: [
          Fa01DeviceAssignment(
            deviceId: 'd1',
            addresses: {Fa01AddressKey(domainId: 'L1', address: 1)},
            expectedConsumption: 1,
          ),
          Fa01DeviceAssignment(
            deviceId: 'd2',
            addresses: {Fa01AddressKey(domainId: 'L1', address: 2)},
            expectedConsumption: 1,
          ),
          Fa01DeviceAssignment(
            deviceId: 'd3',
            addresses: {
              Fa01AddressKey(domainId: 'L1', address: 3),
              Fa01AddressKey(domainId: 'L1', address: 4),
            },
            expectedConsumption: 2,
          ),
        ],
        reserved: {},
        policy: Fa01CapacityPolicy(deviceLimit: 5, addressLimit: 5),
      ),
    );
    expect(result.deviceCount, 3);
    expect(result.addressCount, 4);
    expect(result.addressHeadroom, 1);
    expect(result.status, Fa01AssessmentStatus.pass);
  });

  test('expanded multi-address overlap is detected', () {
    final result = const Fa01AddressCapacityKernel().evaluate(
      Fa01Input(
        loopId: 'loop-1',
        devices: [
          Fa01DeviceAssignment(
            deviceId: 'a',
            addresses: {
              Fa01AddressKey(domainId: 'L1', address: 10),
              Fa01AddressKey(domainId: 'L1', address: 11),
            },
            expectedConsumption: 2,
          ),
          Fa01DeviceAssignment(
            deviceId: 'b',
            addresses: {
              Fa01AddressKey(domainId: 'L1', address: 11),
              Fa01AddressKey(domainId: 'L1', address: 12),
            },
            expectedConsumption: 2,
          ),
        ],
        reserved: {},
        policy: Fa01CapacityPolicy(deviceLimit: 10, addressLimit: 10),
      ),
    );
    expect(result.status, Fa01AssessmentStatus.fail);
    expect(result.collisions.single.key.address, 11);
  });

  test('reserved address participates in collision detection', () {
    final key = Fa01AddressKey(domainId: 'L1', address: 7);
    final result = const Fa01AddressCapacityKernel().evaluate(
      Fa01Input(
        loopId: 'loop-1',
        devices: [
          Fa01DeviceAssignment(deviceId: 'd1', addresses: {key}, expectedConsumption: 1),
        ],
        reserved: {key},
        policy: Fa01CapacityPolicy(deviceLimit: 2, addressLimit: 2),
      ),
    );
    expect(result.status, Fa01AssessmentStatus.fail);
    expect(result.collisions.single.claimants, contains('RESERVED'));
  });
}
