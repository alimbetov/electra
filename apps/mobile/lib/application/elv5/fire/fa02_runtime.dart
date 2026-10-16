import 'dart:convert';

import 'package:engineering_core/engineering_core.dart'
    show PowerDeviceState, PowerRational, PowerScenarioRole;
import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import '../power/elv4_operating_fact_source.dart';
import 'elv5_fire_persistence.dart';

final class Fa02PersistedInputResolver
    implements Elv5ProcessInputResolver<Fa02Input> {
  Fa02PersistedInputResolver({
    required this.fireStore,
    required this.powerFacts,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5FireMutationStore fireStore;
  final Elv4OperatingFactSource powerFacts;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.fa02;

  @override
  Future<Elv5CapturedInput<Fa02Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('FA02_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'FIRE_LOOP') {
      throw StateError('FA02_SUBJECT_KIND_MUST_BE_FIRE_LOOP');
    }

    final loop = await fireStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_FIRE_LOOP_ASSIGNMENTS',
      subjectId: request.subject.id,
    );
    if (loop == null) {
      throw StateError('FA02_FIRE_LOOP_FACTS_MISSING:${request.subject.id}');
    }
    final loopId = _text(loop.payload, 'loopId');
    if (loopId != request.subject.id) {
      throw StateError('FA02_LOOP_ID_MISMATCH:$loopId:${request.subject.id}');
    }

    final addressDomain = _map(loop.payload['addressDomain'], 'addressDomain');
    final memberIds = <String>{_text(addressDomain, 'panelId')};
    for (final assignment in _objects(
      loop.payload['deviceAssignments'],
      'deviceAssignments',
    )) {
      memberIds.add(_text(assignment, 'deviceId'));
    }

    final loadFacts = await powerFacts.loadExactDcLoads(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      componentIds: memberIds,
    );
    final scenarios = await powerFacts.loadScenarioSegments(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      roles: const <PowerScenarioRole>{
        PowerScenarioRole.standby,
        PowerScenarioRole.alarm,
        PowerScenarioRole.startup,
      },
    );

    final dependencies = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'FIRE_LOOP', loopId),
      for (final componentId in memberIds.toList()..sort())
        _dependency(request, 'FACT', 'POWER_COMPONENT_STATE_LOADS', componentId),
      for (final segment in scenarios)
        _dependency(
          request,
          'SET',
          'POWER_OPERATING_SCENARIO',
          segment.scenarioId,
          memberId: '${segment.scenarioRevision}:${segment.segmentId}',
        ),
    ];
    final inputBasis = <String, Object?>{
      'schema': 'electra.elv5-fa02-captured-input.v1',
      'loopAggregateId': loop.aggregateId,
      'loopRevision': loop.revision,
      'members': memberIds.toList()..sort(),
      'loads': [
        for (final fact in loadFacts)
          <String, Object?>{
            'bindingId': fact.bindingId,
            'bindingRevision': fact.bindingRevision,
            'componentId': fact.componentId,
            'originId': fact.originId,
            'stateCode': fact.stateCode,
            'currentA': fact.currentA.toMap(),
          },
      ],
      'scenarios': [
        for (final segment in scenarios)
          <String, Object?>{
            'scenarioId': segment.scenarioId,
            'revision': segment.scenarioRevision,
            'role': segment.role.name,
            'segmentId': segment.segmentId,
            'states': <String, Object?>{
              for (final id in memberIds.toList()..sort())
                id: segment.componentStates[id]?.name,
            },
          },
      ],
    };
    final inputFingerprint = _encoder.sha256(inputBasis);
    final policyFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-fa02-policy-basis.v1',
      'selectionSource': 'ELV4_OPERATING_SCENARIO_COMPONENT_STATES',
      'capacityLimit': null,
    });

    Never blocked(
      String reasonCode, {
      String? scenarioId,
      String? segmentId,
      String? componentId,
      String? role,
    }) {
      throw Elv5CaptureBlockedException(
        request: request,
        reasonCode: reasonCode,
        inputFingerprint: inputFingerprint,
        policyFingerprint: policyFingerprint,
        dependencies: dependencies,
        evidence: <String, Object?>{
          'source': 'ELV5_FIRE_MEMBERSHIP_PLUS_ELV4_EXACT_DC_LOADS',
          'loopAggregateId': loop.aggregateId,
          'loopRevision': loop.revision,
          if (scenarioId != null) 'scenarioId': scenarioId,
          if (segmentId != null) 'segmentId': segmentId,
          if (componentId != null) 'componentId': componentId,
          if (role != null) 'scenarioRole': role,
        },
      );
    }

    final stateByCase = <Fa02OperatingCase, Map<String, PowerDeviceState>>{};
    for (final entry in const <(Fa02OperatingCase, PowerScenarioRole)>[
      (Fa02OperatingCase.standby, PowerScenarioRole.standby),
      (Fa02OperatingCase.alarm, PowerScenarioRole.alarm),
      (Fa02OperatingCase.startupInrush, PowerScenarioRole.startup),
    ]) {
      final matching = scenarios.where((segment) => segment.role == entry.$2).toList();
      if (matching.isEmpty) continue;
      Map<String, PowerDeviceState>? canonical;
      for (final segment in matching) {
        final selected = <String, PowerDeviceState>{};
        for (final componentId in memberIds) {
          final state = segment.componentStates[componentId];
          if (state == null) {
            blocked(
              'FA02_SCENARIO_COMPONENT_STATE_MISSING',
              scenarioId: segment.scenarioId,
              segmentId: segment.segmentId,
              componentId: componentId,
              role: entry.$2.name,
            );
          }
          selected[componentId] = state;
        }
        if (canonical == null) {
          canonical = selected;
        } else if (!_sameStates(canonical, selected)) {
          blocked(
            'FA02_SIMULTANEITY_POLICY_AMBIGUOUS',
            scenarioId: segment.scenarioId,
            segmentId: segment.segmentId,
            role: entry.$2.name,
          );
        }
      }
      stateByCase[entry.$1] = canonical!;
    }
    if (!stateByCase.containsKey(Fa02OperatingCase.standby) ||
        !stateByCase.containsKey(Fa02OperatingCase.alarm)) {
      blocked('FA02_REQUIRED_STANDBY_ALARM_SCENARIOS_MISSING');
    }

    final factsByComponent = <String, List<Elv4ExactDcLoadFact>>{};
    for (final fact in loadFacts) {
      (factsByComponent[fact.componentId] ??= <Elv4ExactDcLoadFact>[]).add(fact);
    }

    final origins = <Fa02LoadOrigin>[];
    final selectedByCase = <Fa02OperatingCase, Set<String>>{
      for (final operatingCase in stateByCase.keys) operatingCase: <String>{},
    };
    for (final componentId in memberIds.toList()..sort()) {
      final componentFacts =
          factsByComponent[componentId] ?? const <Elv4ExactDcLoadFact>[];
      final originIds = componentFacts.map((value) => value.originId).toSet();
      if (originIds.isEmpty) {
        final missingId = 'MISSING_POWER_LOAD:$componentId';
        origins.add(Fa02LoadOrigin(originId: missingId, currents: const {}));
        for (final selected in selectedByCase.values) selected.add(missingId);
        continue;
      }
      for (final originId in originIds.toList()..sort()) {
        final originFacts =
            componentFacts.where((value) => value.originId == originId).toList();
        final currents = <Fa02OperatingCase, Elv5Interval<CurrentDim>>{};
        for (final entry in stateByCase.entries) {
          final state = entry.value[componentId]!;
          final stateCode = state.name.toUpperCase();
          final matching =
              originFacts.where((fact) => fact.stateCode == stateCode).toList();
          if (matching.length > 1) {
            throw StateError('FA02_DUPLICATE_ORIGIN_STATE:$originId:$stateCode');
          }
          selectedByCase[entry.key]!.add(originId);
          if (matching.isEmpty) continue;
          final current = _current(matching.single.currentA);
          currents[entry.key] = Elv5Interval<CurrentDim>(current, current);
        }
        origins.add(Fa02LoadOrigin(originId: originId, currents: currents));
      }
    }

    final cases = <Fa02CasePolicy>[
      for (final operatingCase in Fa02OperatingCase.values)
        if (selectedByCase.containsKey(operatingCase))
          Fa02CasePolicy(
            operatingCase: operatingCase,
            selectedOriginIds: Set.unmodifiable(selectedByCase[operatingCase]!),
          ),
    ];

    return Elv5CapturedInput<Fa02Input>(
      request: request,
      value: Fa02Input(segmentId: loopId, origins: origins, cases: cases),
      inputFingerprint: inputFingerprint,
      policyFingerprint: policyFingerprint,
      dependencies: dependencies,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: loop.revision,
    );
  }

  Elv5DependencyMarker _dependency(
    Elv5CalculationRequest request,
    String relationKind,
    String domain,
    String subjectId, {
    String? memberId,
  }) {
    final value = <String, Object?>{
      'schema': 'electra.elv5-dependency-key.v1',
      'relationKind': relationKind,
      'domain': domain,
      'subjectId': subjectId,
      if (memberId != null) 'memberId': memberId,
    };
    return Elv5DependencyMarker(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      dependencyKey: utf8.decode(_encoder.encode(value)),
      dependencyKeySha256: _encoder.sha256(value),
      logicalNodeKeySha256: _encoder.sha256(request.nodeKey.toCanonicalValue()),
      relationKind: relationKind,
      updatedAtUtc: _nowUtc().toUtc(),
    );
  }
}

Elv5PureKernelExecutor<Fa02Input, Fa02Result> buildFa02Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Fa02Input, Fa02Result>(
  processCode: Elv5ProcessCode.fa02,
  calculate: const Fa02CurrentAggregationKernel().evaluate,
  encodeOutput: (result) => <String, Object?>{
    'schema': 'electra.elv5-fa02-output.v1',
    'status': result.status.name,
    'governingCase': result.governingCase?.name,
    'cases': <String, Object?>{
      for (final operatingCase in Fa02OperatingCase.values)
        if (result.cases.containsKey(operatingCase))
          operatingCase.name: <String, Object?>{
            'knownSubtotalLowerA':
                result.cases[operatingCase]!.knownSubtotal.lower.value.toMap(),
            'knownSubtotalUpperA':
                result.cases[operatingCase]!.knownSubtotal.upper.value.toMap(),
            'missingOriginIds': result.cases[operatingCase]!.missingOriginIds,
            'status': result.cases[operatingCase]!.status.name,
            'marginA': result.cases[operatingCase]!.margin?.value.toMap(),
          },
    },
  },
  encodeEvidence: (captured, _) => <String, Object?>{
    'schema': 'electra.elv5-fa02-evidence.v1',
    'source': 'ELV5_FIRE_MEMBERSHIP_PLUS_ELV4_EXACT_DC_LOADS',
    'captureRevision': captured.captureRevision,
    'stateSelection': 'ELV4_OPERATING_SCENARIOS_V1',
    'explicitCapacityLimit': 'NOT_CAPTURED_V1',
  },
  executionOf: (_) => Elv5Execution.succeeded,
  completionOf: (result) => result.status == Fa02AssessmentStatus.unresolved
      ? Elv5Completion.incomplete
      : Elv5Completion.complete,
  assessmentOf: (result) => switch (result.status) {
    Fa02AssessmentStatus.fail => Elv5Assessment.fail,
    Fa02AssessmentStatus.unresolved => Elv5Assessment.unresolved,
    Fa02AssessmentStatus.complete => Elv5Assessment.notAssessed,
  },
  nowUtc: nowUtc,
);

Current _current(PowerRational value) =>
    Current(Elv5Rational(value.numerator, value.denominator));

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

List<Map<String, Object?>> _objects(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be list.');
  return [for (final item in value) _map(item, field)];
}

String _text(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return raw.trim();
}

bool _sameStates(
  Map<String, PowerDeviceState> left,
  Map<String, PowerDeviceState> right,
) => left.length == right.length &&
    left.entries.every((entry) => right[entry.key] == entry.value);
