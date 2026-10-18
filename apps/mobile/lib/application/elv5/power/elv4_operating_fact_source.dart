import 'package:engineering_core/engineering_core.dart';

final class Elv4ScenarioSegmentFact {
  Elv4ScenarioSegmentFact({
    required this.scenarioId,
    required this.role,
    required this.scenarioRevision,
    required this.segmentId,
    required this.ordinal,
    required this.durationSeconds,
    required Map<String, PowerDeviceState> componentStates,
  }) : componentStates = Map.unmodifiable(componentStates);

  final String scenarioId;
  final PowerScenarioRole role;
  final int scenarioRevision;
  final String segmentId;
  final int ordinal;
  final PowerRational? durationSeconds;
  final Map<String, PowerDeviceState> componentStates;
}

final class Elv4ExactDcLoadFact {
  const Elv4ExactDcLoadFact({
    required this.bindingId,
    required this.bindingRevision,
    required this.componentId,
    required this.inputPortId,
    required this.originId,
    required this.stateCode,
    required this.currentA,
    required this.accountingKind,
  });

  final String bindingId;
  final int bindingRevision;
  final String componentId;
  final String inputPortId;
  final String originId;
  final String stateCode;
  final PowerRational currentA;
  final PowerAccountingKind accountingKind;
}

abstract interface class Elv4OperatingFactSource {
  Future<List<Elv4ScenarioSegmentFact>> loadScenarioSegments({
    required String projectId,
    required String designRevisionId,
    Set<PowerScenarioRole>? roles,
  });

  Future<List<Elv4ExactDcLoadFact>> loadExactDcLoads({
    required String projectId,
    required String designRevisionId,
    required Set<String> componentIds,
  });
}
