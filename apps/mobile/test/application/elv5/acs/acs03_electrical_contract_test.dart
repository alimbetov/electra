import 'package:electra_mobile/application/elv5/acs/acs03_electrical_contract.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips exact ACS-03 contract without floating point', () {
    final contract = _contract();
    final decoded = Acs03ElectricalContract.fromMap(contract.toCanonicalValue());

    expect(decoded.doorId, 'door-1');
    expect(decoded.lockId, 'lock-1');
    expect(decoded.events, hasLength(3));
    expect(
      decoded.events.last.lockCurrent.value,
      Elv5Rational(BigInt.from(3), BigInt.from(10)),
    );
    expect(
      decoded.minimumTerminalVoltage!.value,
      Elv5Rational.integer(22),
    );
  });

  test('requires holding active and startup states', () {
    expect(
      () => Acs03ElectricalContract(
        doorId: 'door-1',
        lockId: 'lock-1',
        conductiveFeedPathId: 'feed-1',
        controlPathId: 'control-1',
        events: <Acs03ElectricalEventContract>[
          _event('holding', Acs03StateCode.holding, '0.1'),
          _event('active', Acs03StateCode.activeRelease, '0.2'),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('rejects duplicate event identity', () {
    expect(
      () => Acs03ElectricalContract(
        doorId: 'door-1',
        lockId: 'lock-1',
        conductiveFeedPathId: 'feed-1',
        controlPathId: 'control-1',
        events: <Acs03ElectricalEventContract>[
          _event('same', Acs03StateCode.holding, '0.1'),
          _event('same', Acs03StateCode.activeRelease, '0.2'),
          _event('startup', Acs03StateCode.startupInrush, '0.3'),
        ],
      ),
      throwsArgumentError,
    );
  });
}

Acs03ElectricalContract _contract() => Acs03ElectricalContract(
  doorId: 'door-1',
  lockId: 'lock-1',
  conductiveFeedPathId: 'feed-1',
  controlPathId: 'control-1',
  minimumTerminalVoltage: Voltage(Elv5Rational.integer(22)),
  maximumTerminalVoltage: Voltage(Elv5Rational.integer(28)),
  events: <Acs03ElectricalEventContract>[
    _event('holding', Acs03StateCode.holding, '0.1'),
    _event('active', Acs03StateCode.activeRelease, '0.2'),
    _event('startup', Acs03StateCode.startupInrush, '0.3'),
  ],
);

Acs03ElectricalEventContract _event(
  String id,
  Acs03StateCode state,
  String current,
) => Acs03ElectricalEventContract(
  eventId: id,
  state: state,
  durationMicroseconds: BigInt.from(1000000),
  scenarioId: 'scenario-${state.name}',
  segmentId: 'segment-${state.name}',
  domainId: 'domain-1',
  lockLoadOriginId: 'lock-load-1',
  sharedTrunkSectionId: 'trunk-1',
  lockCurrent: Current(Elv5Rational.parseDecimal(current)),
);
