import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('derived record exposes upstream dependency relation', () {
    const record = EngineeringDerivedRecord(
      entityId: 'panel:F02',
      state: EngineeringDerivedState.stale,
      rulesetId: 'IEC-LV',
      rulesetVersion: '2026.1',
      inputFingerprint: 'abc123',
      dependencies: [
        EngineeringDependencyRef(
          type: EngineeringDependencyType.consumer,
          entityId: 'load:oven-01',
          revision: 2,
        ),
      ],
    );

    expect(record.dependsOn('load:oven-01'), isTrue);
    expect(record.dependsOn('load:bedroom-light-01'), isFalse);
  });

  test('recalculation impact can stay scoped to affected subgraph', () {
    const impact = RecalculationImpact(
      sourceEntityId: 'load:oven-01',
      affectedEntityIds: [
        'group:kitchen',
        'circuit:kitchen-power',
        'panel:F02',
      ],
      reasonCodes: ['LOAD_CHANGED'],
    );

    expect(impact.affects('panel:F02'), isTrue);
    expect(impact.affects('circuit:bedroom-lighting'), isFalse);
  });
}
