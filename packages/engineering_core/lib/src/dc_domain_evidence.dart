import 'dc_domain_evaluation.dart';
import 'engineering_hash.dart';
import 'power_dc_backup.dart';
import 'power_dependency.dart';
import 'power_evaluation.dart';
import 'power_numeric.dart';

const dcTreeEvidenceAlgorithmVersion = 'elv4-pwr03-dc-cc-v1';
const dcCpEvidenceAlgorithmVersion = 'elv4-pwr03-dc-cp-v1';
const dcTreeInputSchemaVersion = 'electra.elv4-pwr03-dc-cc-input.v1';
const dcCpInputSchemaVersion = 'electra.elv4-pwr03-dc-cp-input.v1';
const dcOutputSchemaVersion = 'electra.elv4-pwr03-output.v1';

final class DcEvidenceContext {
  DcEvidenceContext({
    required String projectId,
    required String revisionId,
    required String scenarioId,
    required String segmentId,
    required String domainId,
  })  : projectId = _text(projectId, 'projectId'),
        revisionId = _text(revisionId, 'revisionId'),
        scenarioId = _text(scenarioId, 'scenarioId'),
        segmentId = _text(segmentId, 'segmentId'),
        domainId = _text(domainId, 'domainId');

  final String projectId;
  final String revisionId;
  final String scenarioId;
  final String segmentId;
  final String domainId;
}

final class DcSectionPhysicalEvidence {
  DcSectionPhysicalEvidence({
    required String sectionId,
    String? allocationId,
    String? cableRunId,
    String? traversalRef,
    Iterable<String> resourceRefs = const [],
    Iterable<String> terminationRefs = const [],
  })  : sectionId = _text(sectionId, 'sectionId'),
        allocationId = _nullableText(allocationId, 'allocationId'),
        cableRunId = _nullableText(cableRunId, 'cableRunId'),
        traversalRef = _nullableText(traversalRef, 'traversalRef'),
        resourceRefs = List.unmodifiable(_sortedUnique(resourceRefs, 'resourceRefs')),
        terminationRefs =
            List.unmodifiable(_sortedUnique(terminationRefs, 'terminationRefs'));

  final String sectionId;
  final String? allocationId;
  final String? cableRunId;
  final String? traversalRef;
  final List<String> resourceRefs;
  final List<String> terminationRefs;

  bool get complete =>
      allocationId != null &&
      cableRunId != null &&
      traversalRef != null &&
      resourceRefs.isNotEmpty &&
      terminationRefs.isNotEmpty;

  Map<String, Object?> toMap() => {
        'sectionId': sectionId,
        'allocationId': allocationId,
        'cableRunId': cableRunId,
        'traversalRef': traversalRef,
        'resourceRefs': resourceRefs,
        'terminationRefs': terminationRefs,
      };
}

final class DcDomainEvaluationRecord {
  DcDomainEvaluationRecord({
    required this.evaluation,
    required this.consumedInput,
  }) {
    if (evaluation.nodeKey.processCode != PowerProcessCode.pwr03) {
      throw ArgumentError('DC domain evidence record requires PWR-03.');
    }
    if (evaluation.inputFingerprint != consumedInput.inputFingerprint) {
      throw ArgumentError(
        'DC evaluation fingerprint must equal its consumed-input fingerprint.',
      );
    }
  }

  final PowerEvaluationEvidence evaluation;
  final PowerConsumedInput consumedInput;

  Map<String, Object?> toMap() => {
        ...evaluation.toMap(),
        'dependencyKeys': consumedInput.dependencyKeys,
        'consumedFacts':
            consumedInput.facts.map((value) => value.toMap()).toList(),
        'consumedEvaluations':
            consumedInput.evaluations.map((value) => value.toMap()).toList(),
      };

  String get canonicalJson => canonicalEngineeringJsonV1(toMap());
  String get evidenceSha256 => sha256HexUtf8(canonicalJson);

  PowerConsumedInputDiff diff(DcDomainEvaluationRecord previous) =>
      consumedInput.diff(previous.consumedInput);
}

DcDomainEvaluationRecord buildDcTreeEvaluationRecord({
  required String evaluationId,
  required DcEvidenceContext context,
  required DcConstantCurrentDomainInput input,
  required DcDomainEvaluationResult result,
  required Iterable<DcSectionPhysicalEvidence> physicalEvidence,
  required Iterable<PowerEvaluationEvidence> loadDemandEvaluations,
  required Map<String, Object?> scenarioFacts,
}) {
  _validateContext(context, input.domainId);
  final tree = result.treeResult;
  if (result.modelKind != DcDomainModelKind.constantCurrentTree || tree == null) {
    throw ArgumentError('PWR-03 CC evidence requires a CC-tree result.');
  }

  final loadDependencies = _validateCurrentLoadDependencies(
    context: context,
    input: input.tree,
    evaluations: loadDemandEvaluations,
  );
  final physicalBySection = _physicalMap(
    input.tree.sections.map((value) => value.sectionId),
    physicalEvidence,
  );
  final consumedInput = PowerConsumedInput(
    algorithmVersion: dcTreeEvidenceAlgorithmVersion,
    inputSchemaVersion: dcTreeInputSchemaVersion,
    numericPolicyVersion: powerNumericPolicyVersion,
    facts: [
      PowerConsumedFact.present(
        key: _key(
          context,
          kind: PowerDependencyKind.dcDomain,
          entityId: context.domainId,
          purpose: 'DC_CC_DOMAIN',
        ),
        valueSchema: 'electra.elv4.dc-cc-domain.v1',
        value: {
          'sourceNodeId': input.tree.sourceNodeId,
          'sourceVoltage': input.tree.sourceVoltage.toMap(),
          'model': 'CONSTANT_CURRENT_TREE',
        },
      ),
      PowerConsumedFact.present(
        key: _key(
          context,
          kind: PowerDependencyKind.segment,
          entityId: context.segmentId,
          purpose: 'DC_SCENARIO_STATE',
          scenarioScoped: true,
        ),
        valueSchema: 'electra.elv4.dc-scenario-facts.v1',
        value: scenarioFacts,
      ),
      ..._ccLoadFacts(context, input.tree.loads),
      ..._sectionFacts(context, input.tree.sections, physicalBySection),
    ],
    evaluations: loadDependencies,
  );

  final incompleteSections = physicalBySection.values
      .where((value) => !value.complete)
      .map((value) => value.sectionId)
      .toList()
    ..sort();
  final findings = <PowerEvaluationFinding>[
    ...result.findings,
    if (incompleteSections.isNotEmpty)
      PowerEvaluationFinding(
        code: 'ELV4_POWER_PATH_UNRESOLVED',
        severity: 'UNRESOLVED',
        message: 'DC domain lacks complete installed path evidence.',
        sourceRefs: incompleteSections,
      ),
  ];
  final status = _combineStatus(result.status, incompleteSections.isNotEmpty);
  final sections = [...tree.sections]
    ..sort((a, b) => a.sectionId.compareTo(b.sectionId));
  final terminals = [...tree.terminals]
    ..sort((a, b) => a.loadId.compareTo(b.loadId));

  final evaluation = PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: context.revisionId,
      scenarioId: context.scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: context.segmentId,
      processCode: PowerProcessCode.pwr03,
      subjectKind: 'DC_DOMAIN',
      subjectId: context.domainId,
    ),
    algorithmVersion: dcTreeEvidenceAlgorithmVersion,
    inputSchemaVersion: dcTreeInputSchemaVersion,
    outputSchemaVersion: dcOutputSchemaVersion,
    inputFingerprint: consumedInput.inputFingerprint,
    status: status,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: {
      'domainId': context.domainId,
      'model': 'CONSTANT_CURRENT_TREE',
      'dependencyKeys': consumedInput.dependencyKeys,
    },
    output: {
      'sourceCurrentA': tree.sourceCurrentA.toMap(),
      'totalLossW': tree.totalLossW.toMap(),
      'sourceDemandW': tree.sourceNominalW.toMap(),
      'deliveredNominalW': tree.deliveredNominalW.toMap(),
      'conservationResidualW': tree.conservationResidualW.toMap(),
      'sections': sections.map(_sectionResultMap).toList(growable: false),
      'terminals': terminals.map(_terminalResultMap).toList(growable: false),
      'physicalComplete': incompleteSections.isEmpty,
    },
    dependencies: loadDemandEvaluations.map((value) => value.nodeKey),
    quantities: [
      {'code': 'SOURCE_CURRENT_A', 'value': tree.sourceCurrentA.toMap()},
      {'code': 'SOURCE_DEMAND_W', 'value': tree.sourceNominalW.toMap()},
      {'code': 'DELIVERED_W', 'value': tree.deliveredNominalW.toMap()},
      {'code': 'FEEDER_LOSS_W', 'value': tree.totalLossW.toMap()},
    ],
    arithmeticSteps: [
      for (final section in sections) ...[
        {
          'operation': 'MULTIPLY',
          'inputRefs': [
            '${section.sectionId}:CURRENT_A',
            '${section.sectionId}:RESISTANCE_OHM'
          ],
          'outputRef': '${section.sectionId}:DROP_V',
          'value': section.dropV.toMap(),
        },
        {
          'operation': 'I2R_LOSS',
          'inputRefs': [
            '${section.sectionId}:CURRENT_A',
            '${section.sectionId}:RESISTANCE_OHM'
          ],
          'outputRef': '${section.sectionId}:LOSS_W',
          'value': section.lossW.toMap(),
        },
      ],
      {
        'operation': 'CONSERVATION_CHECK',
        'inputRefs': const ['SOURCE_W', 'DELIVERED_W', 'LOSS_W'],
        'outputRef': 'CONSERVATION_RESIDUAL_W',
        'value': tree.conservationResidualW.toMap(),
      },
    ],
    findings: findings,
    assumptions: const [
      'DC_MODEL_CONSTANT_CURRENT_TREE',
      'SOURCE_DEMAND_EQUALS_SOURCE_V_TIMES_SOURCE_I',
      'FEEDER_LOSS_NOT_ADDED_TO_SOURCE_DEMAND_AGAIN',
    ],
  );

  return DcDomainEvaluationRecord(
    evaluation: evaluation,
    consumedInput: consumedInput,
  );
}

DcDomainEvaluationRecord buildDcConstantPowerEvaluationRecord({
  required String evaluationId,
  required DcEvidenceContext context,
  required DcSingleConstantPowerDomainInput input,
  required DcDomainEvaluationResult result,
  required DcSectionPhysicalEvidence physicalEvidence,
  required PowerEvaluationEvidence loadDemandEvaluation,
  required Map<String, Object?> scenarioFacts,
}) {
  _validateContext(context, input.domainId);
  if (physicalEvidence.sectionId != context.domainId) {
    throw ArgumentError('Single-CP physical evidence must use the domain id.');
  }
  final raw = result.constantPowerResult;
  if (result.modelKind != DcDomainModelKind.singleConstantPowerFeeder ||
      raw == null) {
    throw ArgumentError('PWR-03 CP evidence requires a CP feeder result.');
  }
  _validateWattDependency(
    context: context,
    expectedSubjectId: input.loadId,
    expectedW: input.loadPowerW,
    evaluation: loadDemandEvaluation,
  );

  final consumedInput = PowerConsumedInput(
    algorithmVersion: dcCpEvidenceAlgorithmVersion,
    inputSchemaVersion: dcCpInputSchemaVersion,
    numericPolicyVersion: powerNumericPolicyVersion,
    facts: [
      PowerConsumedFact.present(
        key: _key(
          context,
          kind: PowerDependencyKind.dcDomain,
          entityId: context.domainId,
          purpose: 'DC_CP_DOMAIN',
        ),
        valueSchema: 'electra.elv4.dc-cp-domain.v1',
        value: {
          'model': 'SINGLE_CONSTANT_POWER_FEEDER',
          'loadId': input.loadId,
          'sourceVoltageV': input.sourceVoltageV.toMap(),
          'loadPowerW': input.loadPowerW.toMap(),
          'loopResistanceOhm': input.loopResistanceOhm.toMap(),
          'maxIterations': input.maxIterations,
          'toleranceV': input.toleranceV.toMap(),
          'evidenceRef': input.evidenceRef,
        },
      ),
      PowerConsumedFact.present(
        key: _key(
          context,
          kind: PowerDependencyKind.segment,
          entityId: context.segmentId,
          purpose: 'DC_SCENARIO_STATE',
          scenarioScoped: true,
        ),
        valueSchema: 'electra.elv4.dc-scenario-facts.v1',
        value: scenarioFacts,
      ),
      ..._physicalFacts(context, physicalEvidence),
    ],
    evaluations: [
      PowerConsumedEvaluationRef(
        logicalNodeKey: loadDemandEvaluation.nodeKey.encode(),
        evaluationId: loadDemandEvaluation.evaluationId,
        inputFingerprint: loadDemandEvaluation.inputFingerprint,
      ),
    ],
  );

  final findings = <PowerEvaluationFinding>[
    ...result.findings,
    if (!physicalEvidence.complete)
      PowerEvaluationFinding(
        code: 'ELV4_POWER_PATH_UNRESOLVED',
        severity: 'UNRESOLVED',
        message: 'Constant-power feeder lacks complete installed path evidence.',
        sourceRefs: [context.domainId],
      ),
  ];
  final status = _combineStatus(result.status, !physicalEvidence.complete);
  final evaluation = PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: context.revisionId,
      scenarioId: context.scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: context.segmentId,
      processCode: PowerProcessCode.pwr03,
      subjectKind: 'DC_DOMAIN',
      subjectId: context.domainId,
    ),
    algorithmVersion: dcCpEvidenceAlgorithmVersion,
    inputSchemaVersion: dcCpInputSchemaVersion,
    outputSchemaVersion: dcOutputSchemaVersion,
    inputFingerprint: consumedInput.inputFingerprint,
    status: status,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: {
      'domainId': context.domainId,
      'model': 'SINGLE_CONSTANT_POWER_FEEDER',
      'dependencyKeys': consumedInput.dependencyKeys,
    },
    output: {
      'terminalVoltageV': raw.terminalVoltage?.toMap(),
      'currentA': raw.current?.toMap(),
      'lossW': raw.lossW?.toMap(),
      'sourceDemandIntervalW': result.sourceDemandIntervalW?.toMap(),
      'iterations': raw.iterations,
      'physicalComplete': physicalEvidence.complete,
    },
    dependencies: [loadDemandEvaluation.nodeKey],
    quantities: [
      if (raw.terminalVoltage != null)
        {'code': 'TERMINAL_V', 'value': raw.terminalVoltage!.toMap()},
      if (raw.current != null)
        {'code': 'CURRENT_A', 'value': raw.current!.toMap()},
      if (raw.lossW != null)
        {'code': 'LOSS_W', 'value': raw.lossW!.toMap()},
      if (result.sourceDemandIntervalW != null)
        {
          'code': 'SOURCE_DEMAND_W_INTERVAL',
          'value': result.sourceDemandIntervalW!.toMap()
        },
    ],
    arithmeticSteps: [
      {
        'operation': 'SOLVE_QUADRATIC_BOUND',
        'inputRefs': const ['SOURCE_V', 'LOAD_W', 'LOOP_R'],
        'outputRef': 'TERMINAL_V_INTERVAL',
        'iterations': raw.iterations,
      },
    ],
    findings: findings,
    assumptions: const [
      'DC_MODEL_SINGLE_CONSTANT_POWER_FEEDER',
      'HIGH_VOLTAGE_ROOT_ONLY',
      'SOURCE_DEMAND_INTERVAL_PRESERVED',
    ],
  );
  return DcDomainEvaluationRecord(
    evaluation: evaluation,
    consumedInput: consumedInput,
  );
}

List<PowerConsumedEvaluationRef> _validateCurrentLoadDependencies({
  required DcEvidenceContext context,
  required DcTreeInput input,
  required Iterable<PowerEvaluationEvidence> evaluations,
}) {
  final bySubject = <String, PowerEvaluationEvidence>{};
  for (final evaluation in evaluations) {
    final id = evaluation.nodeKey.subjectId;
    if (bySubject.containsKey(id)) {
      throw ArgumentError('Duplicate PWR-01 current dependency for $id.');
    }
    bySubject[id] = evaluation;
  }
  final loads = [...input.loads]..sort((a, b) => a.loadId.compareTo(b.loadId));
  if (bySubject.length != loads.length ||
      !loads.every((load) => bySubject.containsKey(load.loadId))) {
    throw ArgumentError('PWR-03 requires one PWR-01 current result per DC load.');
  }
  return [
    for (final load in loads)
      _currentRef(context, load, bySubject[load.loadId]!),
  ];
}

PowerConsumedEvaluationRef _currentRef(
  DcEvidenceContext context,
  DcConstantCurrentLoad load,
  PowerEvaluationEvidence evaluation,
) {
  final key = evaluation.nodeKey;
  if (key.processCode != PowerProcessCode.pwr01 ||
      key.scopeKind != PowerEvaluationScopeKind.segment ||
      key.revisionId != context.revisionId ||
      key.scenarioId != context.scenarioId ||
      key.scopeId != context.segmentId ||
      key.subjectId != load.loadId ||
      evaluation.output['completeA'] != true) {
    throw ArgumentError('DC load requires complete matching PWR-01 ampere evidence.');
  }
  final known = evaluation.output['knownA'];
  if (known is! Map ||
      PowerRational.fromMap(known.cast<String, Object?>()) != load.currentA) {
    throw ArgumentError('DC load current differs from consumed PWR-01 evidence.');
  }
  return PowerConsumedEvaluationRef(
    logicalNodeKey: key.encode(),
    evaluationId: evaluation.evaluationId,
    inputFingerprint: evaluation.inputFingerprint,
  );
}

void _validateWattDependency({
  required DcEvidenceContext context,
  required String expectedSubjectId,
  required PowerRational expectedW,
  required PowerEvaluationEvidence evaluation,
}) {
  final key = evaluation.nodeKey;
  if (key.processCode != PowerProcessCode.pwr01 ||
      key.scopeKind != PowerEvaluationScopeKind.segment ||
      key.revisionId != context.revisionId ||
      key.scenarioId != context.scenarioId ||
      key.scopeId != context.segmentId ||
      key.subjectId != expectedSubjectId ||
      evaluation.output['completeW'] != true) {
    throw ArgumentError('Constant-power load requires matching PWR-01 watt evidence.');
  }
  final known = evaluation.output['knownW'];
  if (known is! Map ||
      PowerRational.fromMap(known.cast<String, Object?>()) != expectedW) {
    throw ArgumentError('Constant-power load differs from consumed PWR-01 evidence.');
  }
}

Iterable<PowerConsumedFact> _ccLoadFacts(
  DcEvidenceContext context,
  Iterable<DcConstantCurrentLoad> values,
) sync* {
  final loads = [...values]..sort((a, b) => a.loadId.compareTo(b.loadId));
  for (final load in loads) {
    yield PowerConsumedFact.present(
      key: _key(
        context,
        kind: PowerDependencyKind.dcDomain,
        entityId: load.loadId,
        purpose: 'DC_LOAD_TERMINAL',
      ),
      valueSchema: 'electra.elv4.dc-cc-load.v1',
      value: {
        'nodeId': load.nodeId,
        'currentA': load.currentA.toMap(),
        'allowedMinV': load.allowedMinV.toMap(),
        'allowedMaxV': load.allowedMaxV.toMap(),
      },
    );
  }
}

Iterable<PowerConsumedFact> _sectionFacts(
  DcEvidenceContext context,
  Iterable<DcSection> values,
  Map<String, DcSectionPhysicalEvidence> physicalBySection,
) sync* {
  final sections = [...values]..sort((a, b) => a.sectionId.compareTo(b.sectionId));
  for (final section in sections) {
    yield PowerConsumedFact.present(
      key: _key(
        context,
        kind: PowerDependencyKind.dcSection,
        entityId: section.sectionId,
        purpose: 'DC_SECTION_MODEL',
      ),
      valueSchema: 'electra.elv4.dc-section.v1',
      value: _sectionInputMap(section),
    );
    yield* _physicalFacts(context, physicalBySection[section.sectionId]!);
  }
}

Iterable<PowerConsumedFact> _physicalFacts(
  DcEvidenceContext context,
  DcSectionPhysicalEvidence value,
) sync* {
  yield _optionalRefFact(
    _key(
      context,
      kind: PowerDependencyKind.allocation,
      entityId: value.sectionId,
      purpose: 'REQUIRED_ALLOCATION',
    ),
    'electra.elv3.allocation-ref.v1',
    'allocationId',
    value.allocationId,
  );
  yield _optionalRefFact(
    _key(
      context,
      kind: PowerDependencyKind.cableRun,
      entityId: value.sectionId,
      purpose: 'REQUIRED_CABLE_RUN',
    ),
    'electra.elv3.cable-run-ref.v1',
    'cableRunId',
    value.cableRunId,
  );
  yield _optionalRefFact(
    _key(
      context,
      kind: PowerDependencyKind.traversal,
      entityId: value.sectionId,
      purpose: 'REQUIRED_TRAVERSAL',
    ),
    'electra.elv3.traversal-ref.v1',
    'traversalRef',
    value.traversalRef,
  );
  yield _listFact(
    _key(
      context,
      kind: PowerDependencyKind.dcSection,
      entityId: value.sectionId,
      purpose: 'INSTALLED_RESOURCES',
    ),
    'electra.elv3.resource-refs.v1',
    'resourceRefs',
    value.resourceRefs,
  );
  yield _listFact(
    _key(
      context,
      kind: PowerDependencyKind.dcSection,
      entityId: value.sectionId,
      purpose: 'TERMINATIONS',
    ),
    'electra.elv3.termination-refs.v1',
    'terminationRefs',
    value.terminationRefs,
  );
}

PowerConsumedFact _optionalRefFact(
  PowerDependencyKey key,
  String schema,
  String field,
  String? value,
) =>
    value == null
        ? PowerConsumedFact.missing(key: key, valueSchema: schema)
        : PowerConsumedFact.present(
            key: key,
            valueSchema: schema,
            value: {field: value},
          );

PowerConsumedFact _listFact(
  PowerDependencyKey key,
  String schema,
  String field,
  List<String> values,
) =>
    values.isEmpty
        ? PowerConsumedFact.missing(key: key, valueSchema: schema)
        : PowerConsumedFact.present(
            key: key,
            valueSchema: schema,
            value: {field: values},
          );

Map<String, DcSectionPhysicalEvidence> _physicalMap(
  Iterable<String> expectedSectionIds,
  Iterable<DcSectionPhysicalEvidence> provided,
) {
  final expected = expectedSectionIds.toSet();
  final result = <String, DcSectionPhysicalEvidence>{};
  for (final value in provided) {
    if (!expected.contains(value.sectionId)) {
      throw ArgumentError('Physical evidence references an unknown DC section.');
    }
    if (result.containsKey(value.sectionId)) {
      throw ArgumentError('Duplicate DC section physical evidence.');
    }
    result[value.sectionId] = value;
  }
  for (final id in expected) {
    result.putIfAbsent(id, () => DcSectionPhysicalEvidence(sectionId: id));
  }
  return result;
}

PowerEvaluationStatus _combineStatus(
  PowerEvaluationStatus resultStatus,
  bool physicalUnresolved,
) {
  if (resultStatus == PowerEvaluationStatus.blocked) {
    return PowerEvaluationStatus.blocked;
  }
  if (resultStatus == PowerEvaluationStatus.fail) {
    return PowerEvaluationStatus.fail;
  }
  if (physicalUnresolved || resultStatus == PowerEvaluationStatus.unresolved) {
    return PowerEvaluationStatus.unresolved;
  }
  return PowerEvaluationStatus.pass;
}

Map<String, Object?> _sectionInputMap(DcSection value) => {
      'sectionId': value.sectionId,
      'parentNodeId': value.parentNodeId,
      'childNodeId': value.childNodeId,
      'resistanceModel': value.resistanceModel.name.toUpperCase(),
      'loopResistanceOhm': value.loopResistanceOhm.toMap(),
      'installedLengthM': value.installedLengthM?.toMap(),
      'forwardOhmPerM': value.forwardOhmPerM?.toMap(),
      'returnOhmPerM': value.returnOhmPerM?.toMap(),
      'contactResistanceOhm': value.contactResistanceOhm?.toMap(),
      'currentRatingA': value.currentRatingA.toMap(),
      'evidenceRef': value.evidenceRef,
    };

Map<String, Object?> _sectionResultMap(DcSectionResult value) => {
      'sectionId': value.sectionId,
      'currentA': value.currentA.toMap(),
      'resistanceOhm': value.resistanceOhm.toMap(),
      'dropV': value.dropV.toMap(),
      'lossW': value.lossW.toMap(),
      'currentMarginA': value.currentMarginA.toMap(),
    };

Map<String, Object?> _terminalResultMap(DcTerminalResult value) => {
      'loadId': value.loadId,
      'minimumV': value.minimumV.toMap(),
      'nominalV': value.nominalV.toMap(),
      'maximumV': value.maximumV.toMap(),
      'status': value.status.name.toUpperCase(),
    };

void _validateContext(DcEvidenceContext context, String domainId) {
  if (context.domainId != domainId) {
    throw ArgumentError('DC evidence context/domain identity mismatch.');
  }
}

PowerDependencyKey _key(
  DcEvidenceContext context, {
  required PowerDependencyKind kind,
  required String entityId,
  required String purpose,
  bool scenarioScoped = false,
}) =>
    PowerDependencyKey(
      projectId: context.projectId,
      revisionId: context.revisionId,
      kind: kind,
      entityId: entityId,
      purpose: purpose,
      scenarioId: scenarioScoped ? context.scenarioId : null,
      segmentId: scenarioScoped ? context.segmentId : null,
    );

List<String> _sortedUnique(Iterable<String> values, String field) {
  final result = values.map((value) => _text(value, field)).toList()..sort();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must be unique.');
  }
  return result;
}

String? _nullableText(String? value, String field) =>
    value == null ? null : _text(value, field);

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
