import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('layer library separates system and custom definitions', () {
    final library = LayerComponentLibrary(
      discipline: Discipline.electrical,
      definitions: const [
        ComponentDefinition(
          id: 'system-socket',
          code: 'SOCKET_230V',
          displayName: 'Socket 230V',
          category: 'SOCKET',
          primaryDiscipline: Discipline.electrical,
          source: ComponentDefinitionSource.system,
          version: 1,
        ),
        ComponentDefinition(
          id: 'project-machine',
          code: 'CUSTOM_MACHINE_A',
          displayName: 'Custom Machine A',
          category: 'MACHINE',
          primaryDiscipline: Discipline.electrical,
          source: ComponentDefinitionSource.project,
          version: 1,
        ),
      ],
    );

    expect(library.systemDefinitions.map((e) => e.code), ['SOCKET_230V']);
    expect(library.customDefinitions.map((e) => e.code), ['CUSTOM_MACHINE_A']);
  });

  test('component definition can expose cross-discipline ports and electrical profile', () {
    const definition = ComponentDefinition(
      id: 'ahu-1',
      code: 'AHU_GENERIC',
      displayName: 'Air Handling Unit',
      category: 'HVAC_EQUIPMENT',
      primaryDiscipline: Discipline.hvac,
      compatibleDisciplines: [Discipline.electrical, Discipline.industrialAutomation],
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
          type: 'FIELDBUS',
          discipline: Discipline.industrialAutomation,
        ),
      ],
      electricalLoadProfile: ElectricalLoadProfile(
        nominalVoltageV: 400,
        phases: 3,
        ratedPowerW: 7500,
        loadType: 'MOTOR',
        dedicatedCircuitRecommended: true,
      ),
    );

    expect(definition.ports, hasLength(2));
    expect(definition.electricalLoadProfile?.phases, 3);
    expect(definition.electricalLoadProfile?.dedicatedCircuitRecommended, isTrue);
  });
}
