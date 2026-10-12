import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('engineering decision exposes ruleset and reasoning', () {
    const decision = EngineeringDecision(
      id: 'DEC-001',
      decisionType: 'CABLE_SIZE',
      subjectId: 'C-201',
      result: '4 mm2',
      ruleset: ElectricalRulesetRef(
        id: 'RS-001',
        jurisdiction: 'PROJECT',
        standardCode: 'TEST-STANDARD',
        version: '1.0',
      ),
      calculationVersion: '1.0.0',
      inputs: {
        'designCurrentA': 24.0,
        'routeLengthM': 32.0,
      },
      reasons: [
        'ampacity requirement',
        'voltage drop requirement',
      ],
      warnings: [
        'example ruleset only',
      ],
    );

    expect(decision.status, EngineeringDecisionStatus.proposed);
    expect(decision.isExplainable, isTrue);
    expect(decision.ruleset.version, '1.0');
    expect(decision.reasons, contains('ampacity requirement'));
  });
}
