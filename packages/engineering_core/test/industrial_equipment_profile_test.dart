import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('three-phase VFD-fed motor preserves supply and routing constraints', () {
    const motor = ComponentDefinition(
      id: 'motor-15kw',
      code: 'MOTOR_15KW_400V',
      displayName: 'Motor 15 kW',
      category: 'MOTOR',
      primaryDiscipline: Discipline.electrical,
      compatibleDisciplines: [Discipline.industrialAutomation],
      source: ComponentDefinitionSource.system,
      version: 1,
      electricalLoadProfile: ElectricalLoadProfile(
        nominalVoltageV: 400,
        phases: 3,
        supplySystem: SupplySystem.threePhaseAc,
        phaseConfiguration: PhaseConfiguration.l1L2L3,
        frequencyHz: 50,
        ratedPowerW: 15000,
        powerFactor: 0.86,
        efficiency: 0.91,
        startingMethod: StartingMethod.vfd,
        dedicatedCircuitRecommended: true,
        requiresProtectiveEarth: true,
      ),
      ports: [
        ComponentPortDefinition(
          code: 'POWER',
          type: 'POWER',
          discipline: Discipline.electrical,
          required: true,
          routingProfile: RoutingProfile(
            separationClass: RouteSeparationClass.emcSensitive,
            requiresShielding: true,
          ),
        ),
      ],
    );

    final load = motor.electricalLoadProfile!;
    final powerPort = motor.ports.single;

    expect(load.supplySystem, SupplySystem.threePhaseAc);
    expect(load.phases, 3);
    expect(load.startingMethod, StartingMethod.vfd);
    expect(load.dedicatedCircuitRecommended, isTrue);
    expect(powerPort.routingProfile!.separationClass,
        RouteSeparationClass.emcSensitive);
    expect(powerPort.routingProfile!.requiresShielding, isTrue);
  });

  test('industrial equipment can expose ports for several networks', () {
    const cnc = ComponentDefinition(
      id: 'cnc-01',
      code: 'CNC_MACHINE',
      displayName: 'CNC machine',
      category: 'CNC_MACHINE',
      primaryDiscipline: Discipline.industrialAutomation,
      source: ComponentDefinitionSource.system,
      version: 1,
      ports: [
        ComponentPortDefinition(
          code: 'POWER',
          type: 'POWER',
          discipline: Discipline.electrical,
          required: true,
        ),
        ComponentPortDefinition(
          code: 'CONTROL',
          type: 'CONTROL',
          discipline: Discipline.industrialAutomation,
        ),
        ComponentPortDefinition(
          code: 'ETHERNET',
          type: 'ETHERNET',
          discipline: Discipline.lowVoltage,
        ),
        ComponentPortDefinition(
          code: 'COMPRESSED_AIR',
          type: 'COMPRESSED_AIR',
          discipline: Discipline.industrialAutomation,
        ),
      ],
    );

    expect(cnc.ports, hasLength(4));
    expect(cnc.ports.map((port) => port.type),
        containsAll(['POWER', 'CONTROL', 'ETHERNET', 'COMPRESSED_AIR']));
  });
}
