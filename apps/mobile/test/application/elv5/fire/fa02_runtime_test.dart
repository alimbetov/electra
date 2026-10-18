import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/fire/elv5_fire_persistence.dart';
import 'package:electra_mobile/application/elv5/fire/fa02_runtime.dart';
import 'package:electra_mobile/application/elv5/power/elv4_operating_fact_source.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregates persisted standby/alarm exact DC load states', () async {
    final captured = await Fa02PersistedInputResolver(
      fireStore: _FireStore(),
      powerFacts: _PowerFacts(),
    ).capture(_request());

    final result = const Fa02CurrentAggregationKernel().evaluate(
      captured.value,
    );

    expect(result.status, Fa02AssessmentStatus.complete);
    expect(
      result.cases[Fa02OperatingCase.standby]!.knownSubtotal.upper.value,
      Elv5Rational.parseDecimal('0.04'),
    );
    expect(
      result.cases[Fa02OperatingCase.alarm]!.knownSubtotal.upper.value,
      Elv5Rational.parseDecimal('0.08'),
    );
  });

  test('missing member load profile remains unresolved', () async {
    final captured = await Fa02PersistedInputResolver(
      fireStore: _FireStore(includeSecondDevice: true),
      powerFacts: _PowerFacts(),
    ).capture(_request());
    final result = const Fa02CurrentAggregationKernel().evaluate(
      captured.value,
    );

    expect(result.status, Fa02AssessmentStatus.unresolved);
    expect(
      result.cases[Fa02OperatingCase.standby]!.missingOriginIds,
      contains('MISSING_POWER_LOAD:det-2'),
    );
  });
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'p',
  designRevisionId: 'd',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'd',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.fa02,
  subject: Elv5SubjectRef(kind: 'FIRE_LOOP', id: 'loop-1'),
  expectedPointerGeneration: 0,
);

final class _FireStore implements Elv5FireMutationStore {
  _FireStore({this.includeSecondDevice = false});
  final bool includeSecondDevice;

  @override
  Future<Elv5FireAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) async => Elv5FireAggregateSnapshot(
    aggregateKind: 'FIRE_LOOP',
    aggregateId: 'fire-loop-1',
    subjectId: 'loop-1',
    revision: 5,
    payload: <String, Object?>{
      'loopId': 'loop-1',
      'addressDomain': <String, Object?>{
        'panelId': 'panel-1',
        'loopId': 'loop-1',
      },
      'deviceAssignments': <Object?>[
        <String, Object?>{'deviceId': 'det-1'},
        if (includeSecondDevice) <String, Object?>{'deviceId': 'det-2'},
      ],
      'topologyProfileRef': <String, Object?>{'id': 'topology-1'},
    },
  );

  @override
  Future<void> replace({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) => throw UnimplementedError();
}

final class _PowerFacts implements Elv4OperatingFactSource {
  @override
  Future<List<Elv4ExactDcLoadFact>> loadExactDcLoads({
    required String projectId,
    required String designRevisionId,
    required Set<String> componentIds,
  }) async =>
      <Elv4ExactDcLoadFact>[
        _load('panel-1', 'panel-load', 'STANDBY', '0.02'),
        _load('panel-1', 'panel-load', 'ALARM', '0.02'),
        _load('det-1', 'det-1-load', 'STANDBY', '0.02'),
        _load('det-1', 'det-1-load', 'ALARM', '0.06'),
      ].where((value) => componentIds.contains(value.componentId)).toList();

  @override
  Future<List<Elv4ScenarioSegmentFact>> loadScenarioSegments({
    required String projectId,
    required String designRevisionId,
    Set<PowerScenarioRole>? roles,
  }) async {
    final values = <Elv4ScenarioSegmentFact>[
      _segment(PowerScenarioRole.standby, PowerDeviceState.standby),
      _segment(PowerScenarioRole.alarm, PowerDeviceState.alarm),
    ];
    return values
        .where((value) => roles == null || roles.contains(value.role))
        .toList();
  }

  Elv4ExactDcLoadFact _load(
    String componentId,
    String originId,
    String state,
    String current,
  ) => Elv4ExactDcLoadFact(
    bindingId: '$componentId-$state',
    bindingRevision: 1,
    componentId: componentId,
    inputPortId: '$componentId-in',
    originId: originId,
    stateCode: state,
    currentA: PowerRational.parseDecimal(current),
    accountingKind: PowerAccountingKind.consumerInput,
  );

  Elv4ScenarioSegmentFact _segment(
    PowerScenarioRole role,
    PowerDeviceState state,
  ) => Elv4ScenarioSegmentFact(
    scenarioId: role.name,
    role: role,
    scenarioRevision: 1,
    segmentId: '${role.name}-1',
    ordinal: 1,
    durationSeconds: PowerRational.integer(60),
    componentStates: <String, PowerDeviceState>{
      'panel-1': state,
      'det-1': state,
      'det-2': state,
    },
  );
}
