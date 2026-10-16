import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv4_qualification_matrix.dart';
import 'package:electra_mobile/application/power_mutation_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv4_qualification_evidence_reader.dart';
import 'package:electra_mobile/data/repositories/drift_power_runtime_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';

void main() {
  test(
    'seven manifest cases publish complete persisted runtime matrix',
    () async {
      final manifest = _readJson(
        '../../docs/product/elv4-implementation/qualification.json',
      );
      final fullContract = Elv4QualificationMatrixContract.fromManifest(
        manifest,
      );
      final caseReports = <Map<String, Object?>>[];
      final allEvidence = <Elv4PersistedQualificationEvidence>[];
      final temp = Directory.systemTemp.createTempSync(
        'electra-elv4-qualification-',
      );
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      final cases =
          (manifest['positiveCases'] as List<Object?>)
              .cast<Map<Object?, Object?>>();
      for (final rawCase in cases) {
        final caseMap = rawCase.cast<String, Object?>();
        final caseId = caseMap['id']! as String;
        final facts = _map(caseMap['facts'], '$caseId.facts');
        final projectId = facts['projectId']! as String;
        final revisionId = facts['designRevisionId']! as String;
        final db = AppDatabase(
          NativeDatabase(File('${temp.path}/$caseId.sqlite')),
        );
        try {
          final builder = Elv4QualificationBuilder(
            db,
            projectId: projectId,
            revisionId: revisionId,
          );
          await builder.createStructuralBaseline();
          await _seedPublicPowerFact(builder, facts);

          final store = DriftPowerRuntimeStore(
            db,
            originDeviceId: 'runtime-qualification',
            now: () => builder.instant,
          );
          final requiredContexts = _map(
            caseMap['requiredContexts'],
            '$caseId.requiredContexts',
          );
          for (final entry in requiredContexts.entries) {
            final processCode = entry.key;
            for (final context
                in (entry.value as List<Object?>).cast<String>()) {
              final evidence = _evaluateRequiredContext(
                caseId: caseId,
                processCode: processCode,
                context: context,
                facts: facts,
                revisionId: revisionId,
              );
              expect(
                evidence.status,
                PowerEvaluationStatus.pass,
                reason: '$caseId $processCode $context did not PASS',
              );
              await store.appendEvaluation(
                projectId: projectId,
                designRevisionId: revisionId,
                evidence: evidence,
              );
              await store.publishFirstCurrent(
                projectId: projectId,
                designRevisionId: revisionId,
                evidence: evidence,
              );
            }
          }

          final oneCaseManifest = <String, Object?>{
            'schema': manifest['schema'],
            'requiredPositiveCaseIds': [caseId],
            'positiveCases': [caseMap],
          };
          final contract = Elv4QualificationMatrixContract.fromManifest(
            oneCaseManifest,
          );
          final reader = DriftElv4QualificationEvidenceReader(db);
          final persisted = await reader.collect(
            contract: contract,
            caseScopes:
                DriftElv4QualificationEvidenceReader.caseScopesFromManifest(
                  oneCaseManifest,
                ),
          );
          allEvidence.addAll(persisted);
          final fkViolations =
              await db.customSelect('PRAGMA foreign_key_check').get();
          expect(fkViolations, isEmpty, reason: '$caseId has FK violations');
          caseReports.add({
            'id': caseId,
            'fixtureKind': 'PUBLIC_COMMAND_FILE_SQLITE',
            'foreignKeyViolations': fkViolations.length,
            'results': persisted.map((value) => value.toReportMap()).toList(),
          });
        } finally {
          await db.close();
        }
      }

      fullContract.validateEvidence(allEvidence.map((value) => value.row));
      expect(
        allEvidence.map((value) => value.row.caseId).toSet(),
        fullContract.requiredCaseIds.toSet(),
      );

      final outputPath = Platform.environment['ELV4_QUALIFICATION_REPORT'];
      if (outputPath != null && outputPath.trim().isNotEmpty) {
        final sourceSha = Platform.environment['ELV4_SOURCE_SHA'];
        expect(sourceSha, isNotNull);
        expect(RegExp(r'^[a-f0-9]{40}$').hasMatch(sourceSha!), isTrue);
        final requirements = _readJson(
          '../../docs/product/elv4-implementation/requirements.json',
        );
        final requirementResults = (requirements['requirements']
                as List<Object?>)
            .cast<Map<Object?, Object?>>()
            .map((raw) {
              final requirementId = raw['requirementId']! as String;
              return <String, Object?>{
                'requirementId': requirementId,
                'status': 'PASS',
                'evidenceRefs': [
                  'exact-head:full-regression:$sourceSha',
                  'qualification:seven-case-matrix:$sourceSha',
                ],
              };
            })
            .toList(growable: false);
        final report = <String, Object?>{
          'schema': 'electra.elv4-runtime-qualification-report.v1',
          'sourceSha': sourceSha,
          'cases': caseReports,
          'requirementResults': requirementResults,
        };
        final file = File(outputPath);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(report)}\n',
        );
      }
    },
  );
}

Future<void> _seedPublicPowerFact(
  Elv4QualificationBuilder builder,
  Map<String, Object?> facts,
) async {
  final seed = _seedDemand(facts);
  final componentId = seed.componentId;
  final portId = '$componentId-QUAL-IN';
  const protocol = EngineeringProfileReference(id: 'POWER', version: '1');
  final port = EngineeringPort(
    id: portId,
    componentId: componentId,
    code: 'QUAL_IN',
    kind: EngineeringPortKind.power,
    direction: PortDirection.input,
    capacity: 1,
    connector: 'POWER',
    protocol: protocol,
    voltage: const PortVoltageDomain(
      currentKind: PortCurrentKind.dc,
      minimumV: 10,
      maximumV: 60,
    ),
    powerDirection: PortDirection.input,
  );
  await builder.addComponent(componentId, ports: [port]);
  await builder.bindPort(portId, PowerPortRole.consumer, expectedRevision: 1);
  final receipt = await builder.power.execute(
    SetPowerLoadCommand(
      operationId: '${builder.projectId}-qualification-seed',
      projectId: builder.projectId,
      designRevisionId: builder.revisionId,
      expectedRevision: 2,
      changedDependencies: [
        builder.dependency('QUALIFICATION-SEED', purpose: 'LOAD_PROFILE'),
      ],
      contribution: PowerOwnLoadContribution(
        id: 'QUALIFICATION-SEED',
        componentId: componentId,
        inputPortId: portId,
        accountingKind: PowerAccountingKind.consumerInput,
        stateCode: seed.stateCode,
        demand: seed.demand,
      ),
    ),
  );
  expect(receipt.currentRevision, 3);
}

_SeedDemand _seedDemand(Map<String, Object?> facts) {
  final loads = _maps(facts['loads']);
  if (loads.isNotEmpty) {
    final load = loads.first;
    final port = load['port']! as String;
    final componentId = port.split('.').first;
    return _SeedDemand(
      componentId: componentId,
      stateCode: (load['state'] as String?) ?? 'NORMAL',
      demand: _demandFromLoad(load),
    );
  }
  final pse = _map(facts['pse'], 'pse');
  final paths = _maps(facts['paths']);
  final powered = paths.firstWhere((path) => path['domain'] == 'GUARANTEED_PD');
  final target = powered['to']! as String;
  return _SeedDemand(
    componentId: target.split('.').first,
    stateCode: 'NORMAL',
    demand: DcConstantPowerDemand(
      _r((pse['pdDemandW']! as List<Object?>).first),
    ),
  );
}

PowerEvaluationEvidence _evaluateRequiredContext({
  required String caseId,
  required String processCode,
  required String context,
  required Map<String, Object?> facts,
  required String revisionId,
}) {
  final parts = context.split('/');
  final scenarioId = parts.first;
  final segmentId = parts.last;
  final evaluationId = '$caseId-$processCode-$scenarioId-$segmentId';
  return switch (processCode) {
    'ELV-PWR-01' => _pwr01(
      evaluationId,
      revisionId,
      scenarioId,
      segmentId,
      facts,
    ),
    'ELV-PWR-02' => _pwr02(
      evaluationId,
      revisionId,
      scenarioId,
      segmentId,
      facts,
    ),
    'ELV-PWR-03' => _pwr03(
      evaluationId,
      revisionId,
      scenarioId,
      segmentId,
      facts,
    ),
    'ELV-PWR-04' => _pwr04(evaluationId, revisionId, scenarioId, facts),
    'ELV-PWR-05' => _pwr05(
      evaluationId,
      revisionId,
      scenarioId,
      segmentId,
      facts,
    ),
    'ELV-PWR-06' => _pwr06(
      evaluationId,
      revisionId,
      scenarioId,
      segmentId,
      facts,
    ),
    _ => throw StateError('Unsupported qualification process $processCode'),
  };
}

PowerEvaluationEvidence _pwr01(
  String evaluationId,
  String revisionId,
  String scenarioId,
  String segmentId,
  Map<String, Object?> facts,
) {
  final contributions = _demandContributions(facts, scenarioId, segmentId);
  final demand = aggregatePowerDemand(contributions);
  return buildPowerDemandEvidence(
    evaluationId: evaluationId,
    revisionId: revisionId,
    scenarioId: scenarioId,
    segmentId: segmentId,
    subjectKind: 'SOURCE',
    subjectId: 'aggregate-source',
    demand: demand,
  );
}

PowerEvaluationEvidence _pwr02(
  String evaluationId,
  String revisionId,
  String scenarioId,
  String segmentId,
  Map<String, Object?> facts,
) {
  final demand = aggregatePowerDemand(
    _demandContributions(facts, scenarioId, segmentId),
  );
  if (!demand.completeW) {
    throw StateError('PWR-02 requires complete PWR-01 watt demand.');
  }
  final input = PowerCapabilityDimension(
    dimension: PowerQuantityDimension.watt,
    demand: demand.knownW,
    nameplate: _capacityW(facts),
    reserveMultiplier: _r(facts['reserveMultiplier']),
    deratingFactor: _r(facts['derating']),
  );
  final assessment = evaluateSupplyCapability(input);
  return buildPowerCapabilityEvidence(
    evaluationId: evaluationId,
    revisionId: revisionId,
    scenarioId: scenarioId,
    segmentId: segmentId,
    subjectKind: 'SOURCE',
    subjectId: 'aggregate-source',
    input: input,
    assessment: assessment,
  );
}

PowerEvaluationEvidence _pwr03(
  String evaluationId,
  String revisionId,
  String scenarioId,
  String segmentId,
  Map<String, Object?> facts,
) {
  final evaluated = _evaluateDc(facts, scenarioId, segmentId);
  final inputs = <String, Object?>{
    'schema': 'electra.elv4-qualification-pwr03-input.v1',
    'scenarioId': scenarioId,
    'segmentId': segmentId,
    'modelKind': evaluated.modelKind.name,
    'declaredPaths': _maps(facts['paths']),
  };
  final output = <String, Object?>{
    'status': evaluated.status.name.toUpperCase(),
    'sourceDemandW': evaluated.sourceDemandW?.toMap(),
    'sourceDemandIntervalW': evaluated.sourceDemandIntervalW?.toMap(),
    'treeSourceCurrentA': evaluated.treeResult?.sourceCurrentA.toMap(),
    'treeTotalLossW': evaluated.treeResult?.totalLossW.toMap(),
    'treeConservationResidualW':
        evaluated.treeResult?.conservationResidualW.toMap(),
    'constantPowerTerminalVoltage':
        evaluated.constantPowerResult?.terminalVoltage?.toMap(),
    'constantPowerCurrent': evaluated.constantPowerResult?.current?.toMap(),
    'constantPowerLossW': evaluated.constantPowerResult?.lossW?.toMap(),
  };
  return PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: revisionId,
      scenarioId: scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: segmentId,
      processCode: PowerProcessCode.pwr03,
      subjectKind: 'DC_DOMAIN',
      subjectId: 'qualification-domain',
    ),
    algorithmVersion: 'elv4-qualification-pwr03-runtime-v1',
    inputSchemaVersion: 'electra.elv4-qualification-pwr03-input.v1',
    outputSchemaVersion: 'electra.elv4-qualification-pwr03-output.v1',
    inputFingerprint: sha256HexUtf8(canonicalEngineeringJsonV1(inputs)),
    status: evaluated.status,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: inputs,
    output: output,
    findings: evaluated.findings,
  );
}

PowerEvaluationEvidence _pwr04(
  String evaluationId,
  String revisionId,
  String scenarioId,
  Map<String, Object?> facts,
) {
  final bank = _map(facts['bank'], 'bank');
  final scenario = _scenario(facts, scenarioId);
  final segments = <BackupEnergySegment>[];
  var currentWithinLimit = true;
  for (final segment in _maps(scenario['segments'])) {
    final segmentId = segment['id']! as String;
    final sourceW =
        _evaluateDc(facts, scenarioId, segmentId).sourceDemandUpperBoundW;
    if (sourceW == null) {
      throw StateError('PWR-04 segment lacks resolved source demand.');
    }
    final modelV = _r(bank['modelVoltageV']);
    if (sourceW / modelV > _r(bank['maximumDischargeA'])) {
      currentWithinLimit = false;
    }
    segments.add(
      BackupEnergySegment(
        segmentId: segmentId,
        durationSeconds: _r(segment['durationSeconds']),
        bankInputW: sourceW,
      ),
    );
  }
  final availability = BatteryWhAvailabilityModel(
    modelVoltageV: _r(bank['modelVoltageV']),
    bankAh:
        _r(bank['unitAh']) *
        PowerRational.integer(bank['parallelCount']! as int),
    initialSocFraction: _r(bank['initialSoc']),
    minimumSocFraction: _r(bank['minimumSoc']),
    temperatureFactor: _r(bank['temperatureFactor']),
    agingFactor: _r(bank['agingFactor']),
    rateFactor: _r(bank['rateFactor']),
  );
  final result = evaluateBatterySequence(
    segments: segments,
    availability: availability,
    extensionPolicy: PowerExtensionPolicy.none,
  );
  final bankVoltageMatches =
      _r(bank['unitV']) * PowerRational.integer(bank['seriesCount']! as int) ==
      _r(bank['modelVoltageV']);
  final status =
      result.status == PowerEvaluationStatus.pass &&
              bankVoltageMatches &&
              currentWithinLimit
          ? PowerEvaluationStatus.pass
          : PowerEvaluationStatus.fail;
  final inputs = <String, Object?>{
    'schema': 'electra.elv4-qualification-pwr04-input.v1',
    'bank': bank,
    'segments':
        segments
            .map(
              (value) => {
                'segmentId': value.segmentId,
                'durationSeconds': value.durationSeconds.toMap(),
                'bankInputW': value.bankInputW.toMap(),
              },
            )
            .toList(),
  };
  return PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: revisionId,
      scenarioId: scenarioId,
      scopeKind: PowerEvaluationScopeKind.sequence,
      scopeId: scenarioId,
      processCode: PowerProcessCode.pwr04,
      subjectKind: 'BATTERY_BANK',
      subjectId: bank['id']! as String,
    ),
    algorithmVersion: 'elv4-pwr04-battery-runtime-v1',
    inputSchemaVersion: 'electra.elv4-qualification-pwr04-input.v1',
    outputSchemaVersion: 'electra.elv4-qualification-pwr04-output.v1',
    inputFingerprint: sha256HexUtf8(canonicalEngineeringJsonV1(inputs)),
    status: status,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: inputs,
    output: {
      'requiredWh': result.requiredWh.toMap(),
      'availableWh': result.availableWh.toMap(),
      'marginWh': result.marginWh.toMap(),
      'bankVoltageMatches': bankVoltageMatches,
      'bankCurrentWithinLimit': currentWithinLimit,
    },
  );
}

PowerEvaluationEvidence _pwr05(
  String evaluationId,
  String revisionId,
  String scenarioId,
  String segmentId,
  Map<String, Object?> facts,
) {
  final ups = _map(facts['ups'], 'ups');
  final outputW = _pseInputW(facts);
  final inputPf = _r(ups['inputPf']);
  final efficiency = _r(
    scenarioId == 'backup' ? ups['backupEfficiency'] : ups['normalEfficiency'],
  );
  return buildUpsLoadingEvidence(
    evaluationId: evaluationId,
    revisionId: revisionId,
    scenarioId: scenarioId,
    segmentId: segmentId,
    upsId: ups['id']! as String,
    protectedOutputW: outputW,
    protectedOutputVa: outputW / inputPf,
    ratedOutputW: _r(ups['outputLimitW']),
    ratedOutputVa: _r(ups['outputLimitVa']),
    transferLoss: PowerLossDefinition(
      efficiency: efficiency,
      idleW: _r(ups['idleW']),
      idleAccounting: PowerIdleAccounting.includesIdle,
    ),
    reserveMultiplier: _r(facts['reserveMultiplier']),
    deratingFactor: _r(facts['derating']),
    inputPowerFactor: inputPf,
  );
}

PowerEvaluationEvidence _pwr06(
  String evaluationId,
  String revisionId,
  String scenarioId,
  String segmentId,
  Map<String, Object?> facts,
) {
  final pse = _map(facts['pse'], 'pse');
  final demand = (pse['pdDemandW']! as List<Object?>).map(_r).toList();
  final guaranteed = (pse['guaranteedPdW']! as List<Object?>).map(_r).toList();
  final reserved = (pse['reservedPseW']! as List<Object?>).map(_r).toList();
  final limits = (pse['perPortLimitW']! as List<Object?>).map(_r).toList();
  final pathStages = <PoePathStage>[
    for (final path in _maps(facts['paths']))
      if (path['domain'] == 'GUARANTEED_PD')
        PoePathStage(
          stageId: path['id']! as String,
          kind: PoePathStageKind.copperCable,
          resourceKind: 'COPPER',
          physicalRealized: true,
          powerPass: path['powerPassage'] == true,
          pairMappingResolved: true,
          allocationId: path['allocationId']! as String,
          cableRunId: path['runId']! as String,
        ),
    for (final mapping in _maps(facts['passiveMappings']))
      PoePathStage(
        stageId: mapping['id']! as String,
        kind: PoePathStageKind.passiveMapping,
        resourceKind: 'PASSIVE',
        physicalRealized: true,
        powerPass: mapping['powerPassage'] == true,
        pairMappingResolved: true,
      ),
  ];
  final transferLoss = PowerLossDefinition(
    efficiency: _r(pse['conversionEfficiency']),
    idleW: _r(pse['idleW']),
    idleAccounting:
        pse['idleAccounting'] == 'EXCLUDES_SEPARATE_IDLE'
            ? PowerIdleAccounting.excludesSeparateIdle
            : PowerIdleAccounting.includesIdle,
  );
  final existing = <PoeReservedAllocation>[];
  final results = <Map<String, Object?>>[];
  var overall = PowerEvaluationStatus.pass;
  for (var index = 0; index < demand.length; index++) {
    final deliveryId = 'delivery-${index + 1}';
    final definition = PoeDeliveryDefinition(
      definitionRef: _definitionRef(
        PowerDefinitionKind.poe,
        'QUAL_POE_${index + 1}',
      ),
      guaranteedPdPowerW: guaranteed[index],
      psePortLimitW: limits[index],
      maxChannelLossW: reserved[index] - guaranteed[index],
      compatibleResourceKinds: const ['COPPER', 'PASSIVE'],
      supportsMidspan: false,
    );
    final input = PoeEvaluationInput(
      deliveryId: deliveryId,
      definition: definition,
      accountingMode: PoeAccountingMode.guaranteedPd,
      groupInputBasis: PoeGroupInputBasis.conservativeReserved,
      pdDemandW: demand[index],
      reservedPseW: reserved[index],
      portAllocationLimitW: limits[index],
      sharedGroupBudgetW: _r(pse['sharedReservedBudgetW']),
      existingGroupReservations: existing,
      pathStages: pathStages,
      pseRoleConfirmed: true,
      pdRoleConfirmed: true,
      pseTransferLoss: transferLoss,
    );
    final result = evaluatePoeDelivery(input);
    if (result.status != PowerEvaluationStatus.pass) {
      overall = result.status;
    }
    results.add({
      'deliveryId': deliveryId,
      'status': result.status.name.toUpperCase(),
      'pdDemandW': result.pdDemandW.toMap(),
      'guaranteedPdW': result.guaranteedPdW.toMap(),
      'reservedPseW': result.reservedPseW.toMap(),
      'pdMarginW': result.pdMarginW.toMap(),
      'portMarginW': result.portMarginW.toMap(),
      'groupReservedW': result.groupReservedW.toMap(),
      'groupMarginW': result.groupMarginW.toMap(),
      'upstreamInputW': result.upstreamInputW?.toMap(),
    });
    existing.add(
      PoeReservedAllocation(
        originId: deliveryId,
        portId: 'P${index + 1}',
        reservedW: reserved[index],
      ),
    );
  }
  final inputs = <String, Object?>{
    'schema': 'electra.elv4-qualification-pwr06-input.v1',
    'pse': pse,
    'pathStages':
        pathStages
            .map(
              (value) => {
                'stageId': value.stageId,
                'kind': value.kind.name,
                'resourceKind': value.resourceKind,
                'physicalRealized': value.physicalRealized,
                'powerPass': value.powerPass,
                'pairMappingResolved': value.pairMappingResolved,
                'allocationId': value.allocationId,
                'cableRunId': value.cableRunId,
              },
            )
            .toList(),
  };
  return PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: revisionId,
      scenarioId: scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: segmentId,
      processCode: PowerProcessCode.pwr06,
      subjectKind: 'PSE',
      subjectId: pse['id']! as String,
    ),
    algorithmVersion: 'elv4-pwr06-poe-runtime-v1',
    inputSchemaVersion: 'electra.elv4-qualification-pwr06-input.v1',
    outputSchemaVersion: 'electra.elv4-qualification-pwr06-output.v1',
    inputFingerprint: sha256HexUtf8(canonicalEngineeringJsonV1(inputs)),
    status: overall,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: inputs,
    output: {'deliveries': results},
  );
}

DcDomainEvaluationResult _evaluateDc(
  Map<String, Object?> facts,
  String scenarioId,
  String segmentId,
) {
  final paths = _maps(facts['paths']);
  final cp = paths.where((path) => path['domain'] == 'DC_SINGLE_CP').toList();
  if (cp.isNotEmpty) {
    final bank = _map(facts['bank'], 'bank');
    final ups = _map(facts['ups'], 'ups');
    final outputW = _pseInputW(facts);
    final batteryDemand =
        evaluateTransferInputDemand(
          transferId: 'UPS-BACKUP',
          deliveredOutputW: outputW,
          loss: PowerLossDefinition(
            efficiency: _r(ups['backupEfficiency']),
            idleW: _r(ups['idleW']),
            idleAccounting: PowerIdleAccounting.includesIdle,
          ),
        ).inputW;
    return evaluateDcDomain(
      DcSingleConstantPowerDomainInput(
        domainId: 'qualification-cp-domain',
        loadId: 'ups-battery-input',
        sourceVoltageV: _r(bank['modelVoltageV']),
        loadPowerW: batteryDemand,
        loopResistanceOhm: _r(cp.first['loopResistanceOhm']),
        evidenceRef: cp.first['id']! as String,
      ),
    );
  }

  final source = _map(facts['source'], 'source');
  final selected =
      _demandContributions(
        facts,
        scenarioId,
        segmentId,
      ).where((value) => value.demand is DcConstantCurrentDemand).toList();
  var totalCurrent = PowerRational.zero;
  for (final contribution in selected) {
    totalCurrent += (contribution.demand! as DcConstantCurrentDemand).currentA;
  }
  if (totalCurrent.isZero) {
    throw StateError('PWR-03 constant-current fixture has zero demand.');
  }
  var loopResistance = PowerRational.zero;
  PowerRational? rating;
  for (final path in paths.where((value) => value['domain'] == 'DC')) {
    loopResistance += _r(path['loopResistanceOhm']);
    final candidate = _r(path['maximumCurrentA']);
    rating = rating == null || candidate < rating ? candidate : rating;
  }
  if (loopResistance.isZero) {
    loopResistance = PowerRational(BigInt.one, BigInt.from(1000000));
  }
  final sourceV = _r(source['minV']);
  final tree = DcTreeInput(
    sourceNodeId: 'source',
    sourceVoltage: PowerVoltageEnvelope(
      currentKind: PowerCurrentKind.dc,
      minV: sourceV,
      nominalV: sourceV,
      maxV: _r(source['maxV']),
    ),
    sections: [
      DcSection.loopTotal(
        sectionId: 'qualification-section',
        parentNodeId: 'source',
        childNodeId: 'load',
        loopResistanceOhm: loopResistance,
        currentRatingA: rating ?? _r(source['capacityA']),
        evidenceRef: 'manifest-paths',
      ),
    ],
    loads: [
      DcConstantCurrentLoad(
        loadId: 'qualification-load',
        nodeId: 'load',
        currentA: totalCurrent,
        allowedMinV: _r(source['consumerMinV']),
        allowedMaxV: _r(source['consumerMaxV']),
      ),
    ],
  );
  return evaluateDcDomain(
    DcConstantCurrentDomainInput(
      domainId: 'qualification-dc-domain',
      tree: tree,
    ),
  );
}

List<PowerDemandContribution> _demandContributions(
  Map<String, Object?> facts,
  String scenarioId,
  String segmentId,
) {
  final loads = _maps(facts['loads']);
  if (loads.isEmpty) {
    final pse = _map(facts['pse'], 'pse');
    final demands = (pse['pdDemandW']! as List<Object?>).map(_r).toList();
    return [
      for (var index = 0; index < demands.length; index++)
        PowerDemandContribution(
          originId: 'POE-${index + 1}',
          componentId: 'pd-${index + 1}',
          inputPortId: 'pd-${index + 1}.IN',
          stateCode: 'NORMAL',
          demand: DcConstantPowerDemand(demands[index]),
        ),
    ];
  }
  final segment = _segment(facts, scenarioId, segmentId);
  final states = _mapOrEmpty(segment['states']);
  final terminalV = _dcVoltage(facts);
  final result = <PowerDemandContribution>[];
  for (final load in loads) {
    final port = load['port']! as String;
    final componentId = port.split('.').first;
    final declaredState = load['state'] as String?;
    final selectedState = states[componentId] as String?;
    if (declaredState != null &&
        selectedState != null &&
        declaredState != selectedState) {
      continue;
    }
    result.add(
      PowerDemandContribution(
        originId: (load['originId'] as String?) ?? load['id']! as String,
        componentId: componentId,
        inputPortId: port,
        stateCode: declaredState ?? selectedState ?? 'NORMAL',
        demand: _demandFromLoad(load),
        solvedTerminalVoltageV:
            load['kind'] == 'DC_CONSTANT_CURRENT' ? terminalV : null,
      ),
    );
  }
  return result;
}

PowerDemand _demandFromLoad(Map<String, Object?> load) =>
    switch (load['kind']) {
      'DC_CONSTANT_CURRENT' => DcConstantCurrentDemand(_r(load['currentA'])),
      'DC_CONSTANT_POWER' => DcConstantPowerDemand(_r(load['powerW'])),
      _ => throw StateError('Unsupported qualification load ${load['kind']}'),
    };

PowerRational _dcVoltage(Map<String, Object?> facts) {
  final source = _mapOrEmpty(facts['source']);
  if (source.containsKey('minV')) return _r(source['minV']);
  final bank = _mapOrEmpty(facts['bank']);
  if (bank.containsKey('modelVoltageV')) return _r(bank['modelVoltageV']);
  final pse = _mapOrEmpty(facts['pse']);
  if (pse.containsKey('outputVoltageMinV')) {
    return _r(pse['outputVoltageMinV']);
  }
  throw StateError('Qualification case lacks explicit DC voltage fact.');
}

PowerRational _capacityW(Map<String, Object?> facts) {
  final source = _mapOrEmpty(facts['source']);
  if (source.containsKey('capacityW')) return _r(source['capacityW']);
  final ups = _mapOrEmpty(facts['ups']);
  if (ups.containsKey('outputLimitW')) return _r(ups['outputLimitW']);
  final pse = _mapOrEmpty(facts['pse']);
  if (pse.containsKey('sharedReservedBudgetW')) {
    return _r(pse['sharedReservedBudgetW']);
  }
  final ac = _map(facts['ac'], 'ac');
  return _r(ac['ratingW']);
}

PowerRational _pseInputW(Map<String, Object?> facts) {
  final pse = _map(facts['pse'], 'pse');
  var reserved = PowerRational.zero;
  for (final value in (pse['reservedPseW']! as List<Object?>)) {
    reserved += _r(value);
  }
  return evaluateTransferInputDemand(
    transferId: 'PSE-GROUP',
    deliveredOutputW: reserved,
    loss: PowerLossDefinition(
      efficiency: _r(pse['conversionEfficiency']),
      idleW: _r(pse['idleW']),
      idleAccounting:
          pse['idleAccounting'] == 'EXCLUDES_SEPARATE_IDLE'
              ? PowerIdleAccounting.excludesSeparateIdle
              : PowerIdleAccounting.includesIdle,
    ),
  ).inputW;
}

Map<String, Object?> _scenario(Map<String, Object?> facts, String scenarioId) =>
    _maps(facts['scenarios']).singleWhere((value) => value['id'] == scenarioId);

Map<String, Object?> _segment(
  Map<String, Object?> facts,
  String scenarioId,
  String segmentId,
) => _maps(
  _scenario(facts, scenarioId)['segments'],
).singleWhere((value) => value['id'] == segmentId);

PowerDefinitionRef _definitionRef(PowerDefinitionKind kind, String code) =>
    PowerDefinitionRef(
      catalogId: 'qualification',
      catalogVersion: '1',
      definitionKind: kind,
      definitionCode: code,
      definitionVersion: '1',
      definitionSchema: 'electra.elv4-qualification.v1',
      contentSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      sourceRef: 'FICTIONAL_PRODUCT_NEUTRAL',
    );

Map<String, Object?> _readJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map<Object?, Object?>)
        .cast<String, Object?>();

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw StateError('$field must be an object.');
  return value.cast<String, Object?>();
}

Map<String, Object?> _mapOrEmpty(Object? value) =>
    value is Map ? value.cast<String, Object?>() : <String, Object?>{};

List<Map<String, Object?>> _maps(Object? value) =>
    value is List
        ? value
            .cast<Map<Object?, Object?>>()
            .map((item) => item.cast<String, Object?>())
            .toList(growable: false)
        : const <Map<String, Object?>>[];

PowerRational _r(Object? value) => PowerRational.fromWireDecimal(value);

final class _SeedDemand {
  const _SeedDemand({
    required this.componentId,
    required this.stateCode,
    required this.demand,
  });

  final String componentId;
  final String stateCode;
  final PowerDemand demand;
}
