import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('panel proposal keeps functional protection requirement vendor-neutral',
      () {
    const proposal = PanelGenerationProposal(
      id: 'proposal-1',
      panelId: 'DB-F02',
      ruleset: ElectricalRulesetRef(
        id: 'ruleset-1',
        jurisdiction: 'example',
        standardCode: 'example-standard',
        version: '1.0',
      ),
      circuits: [
        GeneratedCircuitProposal(
          id: 'C-01',
          name: 'Lighting',
          sourceConsumptionGroupIds: ['G-01'],
          protectionRequirement: FunctionalDeviceRequirement(
            role: FunctionalDeviceRole.mcb,
            ratedCurrentA: 10,
            poles: 1,
          ),
        ),
      ],
    );

    expect(
      proposal.circuits.single.protectionRequirement.role,
      FunctionalDeviceRole.mcb,
    );
    expect(proposal.circuits.single.selectedManufacturerProductId, isNull);
  });
}
