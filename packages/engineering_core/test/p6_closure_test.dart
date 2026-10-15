import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P6 canonical DC domain', () {
    test('unsupported model is BLOCKED with a stable finding', () {
      final result = evaluateDcDomain(
        DcUnsupportedDomainInput(
          domainId: 'dc-domain',
          modelCode: 'SHARED_RETURN_MESH',
          evidenceRefs: const ['route:1'],
        ),
      );

      expect(result.status, PowerEvaluationStatus.blocked);
      expect(
        result.findings.single.code,
        'ELV4_UNSUPPORTED_ELECTRICAL_MODEL',
      );
    });

    test('CC pipeline owns feeder loss once before parent PWR-01', () {
      final context = _dcContext();
      final input = _ccInput();
      final currentEvidence = _currentDemandEvidence(
        loadId: 'lock',
        currentA: _r('2'),
        segmentId: 'segment-1',
      );
      final pipeline = evaluateDcTreeToCapabilityPipeline(
        context: context,
        domainInput: input,
        physicalEvidence: [_completePhysical('s1')],
        loadDemandEvaluations: [currentEvidence],
        scenarioFacts: const {'state': 'NORMAL'},
        domainEvaluationId: 'pwr03-1',
        parentDemandEvaluationId: 'parent-pwr01-1',
        capabilityEvaluationId: 'pwr02-1',
        parentBoundaryRef: 'SOURCE_PANEL',
        parentSubjectKind: 'SOURCE',
        parentSubjectId: 'source-1',
        capabilitySubjectKind: 'SOURCE',
        capabilitySubjectId: 'source-1',
        sourceNameplateW: _r('100'),
        directContributions: [
          PowerDemandContribution(
            originId: 'local-load',
            componentId: 'panel',
            inputPortId: 'in',
            stateCode: 'NORMAL',
            demand: DcConstantPowerDemand(_r('10')),
          ),
        ],
      );

      expect(pipeline.domain.status, PowerEvaluationStatus.pass);
      expect(pipeline.domain.sourceDemandW, _r('48'));
      expect(pipeline.domain.treeResult!.deliveredNominalW, _r('44'));
      expect(pipeline.domain.treeResult!.totalLossW, _r('4'));
      expect(pipeline.parentDemand.outputDemandW, _r('58'));
      expect(pipeline.parentDemand.upstreamInputW, _r('58'));
      expect(pipeline.parentDemand.outputDemandW, isNot(_r('62')));
      expect(
        pipeline.parentDemandEvidence.dependencies.single,
        pipeline.domainEvidence.evaluation.nodeKey,
      );
      expect(
        pipeline.capabilityEvidence!.dependencies.single,
        pipeline.parentDemandEvidence.nodeKey,
      );
    });

    test('physical completion changes only exact PWR-03 dependency facts', () {
      final context = _dcContext();
      final input = _ccInput();
      final demand = _currentDemandEvidence(
        loadId: 'lock',
        currentA: _r('2'),
        segmentId: 'segment-1',
      );
      final result = evaluateDcDomain(input);
      final missing = buildDcTreeEvaluationRecord(
        evaluationId: 'eval-a',
        context: context,
        input: input,
        result: result,
        physicalEvidence: [
          DcSectionPhysicalEvidence(
            sectionId: 's1',
            allocationId: 'allocation-s1',
            traversalRef: 'traversal-s1',
            resourceRefs: const ['resource-s1'],
            terminationRefs: const ['term-a-s1', 'term-b-s1'],
          ),
        ],
        loadDemandEvaluations: [demand],
        scenarioFacts: const {'state': 'NORMAL'},
      );
      final complete = buildDcTreeEvaluationRecord(
        evaluationId: 'eval-b',
        context: context,
        input: input,
        result: result,
        physicalEvidence: [_completePhysical('s1')],
        loadDemandEvaluations: [demand],
        scenarioFacts: const {'state': 'NORMAL'},
      );

      expect(missing.evaluation.status, PowerEvaluationStatus.unresolved);
      expect(complete.evaluation.status, PowerEvaluationStatus.pass);
      final diff = complete.diff(missing);
      expect(diff.requiresRecalculation, isTrue);
      expect(diff.changedDependencyKeys, hasLength(1));
      expect(diff.changedDependencyKeys.single, contains('REQUIRED_CABLE_RUN'));
    });

    test('single-CP source demand remains an interval into PWR-02', () {
      final context = _dcContext(domainId: 'cp-domain');
      final input = DcSingleConstantPowerDomainInput(
        domainId: 'cp-domain',
        loadId: 'camera',
        sourceVoltageV: _r('24'),
        loadPowerW: _r('10'),
        loopResistanceOhm: _r('1'),
        evidenceRef: 'fixture:cp',
      );
      final demand = _wattDemandEvidence(
        subjectId: 'camera',
        watts: _r('10'),
        segmentId: 'segment-1',
      );
      final pipeline = evaluateConstantPowerFeederToCapabilityPipeline(
        context: context,
        domainInput: input,
        physicalEvidence: _completePhysical('cp-domain'),
        loadDemandEvaluation: demand,
        scenarioFacts: const {'state': 'NORMAL'},
        domainEvaluationId: 'cp-pwr03',
        capabilityEvaluationId: 'cp-pwr02',
        capabilitySubjectKind: 'SOURCE',
        capabilitySubjectId: 'source-cp',
        sourceNameplateW: _r('20'),
      );

      expect(pipeline.domain.status, PowerEvaluationStatus.pass);
      expect(pipeline.domain.sourceDemandW, isNull);
      expect(pipeline.domain.sourceDemandIntervalW, isNotNull);
      expect(pipeline.capability!.status, PowerEvaluationStatus.pass);
      expect(
        pipeline.capabilityEvidence!.dependencies.single,
        pipeline.domainEvidence.evaluation.nodeKey,
      );
    });
  });

  group('P6 battery PWR-04', () {
    test('series bank uses SOC window once and preserves ordered dependencies', () {
      final bank = _bank();
      final availability = _availability();
      final standby = BackupEnergySegment(
        segmentId: 'standby',
        durationSeconds: _r('7200'),
        bankInputW: _r('25'),
      );
      final alarm = BackupEnergySegment(
        segmentId: 'alarm',
        durationSeconds: _r('1800'),
        bankInputW: _r('50'),
      );
      final context = BackupEvidenceContext(
        projectId: 'project',
        revisionId: 'revision',
        scenarioId: 'backup',
        sequenceId: 'standby-alarm',
        bankId: 'bank-1',
      );
      final standbyEvidence = _wattDemandEvidence(
        subjectId: 'bank-demand-standby',
        watts: _r('25'),
        segmentId: 'standby',
        scenarioId: 'backup',
      );
      final alarmEvidence = _wattDemandEvidence(
        subjectId: 'bank-demand-alarm',
        watts: _r('50'),
        segmentId: 'alarm',
        scenarioId: 'backup',
      );

      final first = evaluateBatterySequencePipeline(
        evaluationId: 'pwr04-a',
        context: context,
        bank: bank,
        availability: availability,
        segments: [standby, alarm],
        extensionPolicy: PowerExtensionPolicy.none,
        segmentDemandEvaluations: [alarmEvidence, standbyEvidence],
      );
      final reopened = evaluateBatterySequencePipeline(
        evaluationId: 'pwr04-b',
        context: context,
        bank: bank,
        availability: availability,
        segments: [standby, alarm],
        extensionPolicy: PowerExtensionPolicy.none,
        segmentDemandEvaluations: [standbyEvidence, alarmEvidence],
      );

      expect(first.evaluation.output['requiredWh'], _r('75').toMap());
      expect(first.evaluation.output['availableWh'], _r('134.4').toMap());
      expect(first.evaluation.output['marginWh'], _r('59.4').toMap());
      expect(first.evaluation.output['estimatedAutonomySeconds'], isNull);
      expect(first.evaluation.status, PowerEvaluationStatus.pass);
      expect(first.evaluation.inputFingerprint, reopened.evaluation.inputFingerprint);
      expect(reopened.diff(first).requiresRecalculation, isFalse);
    });

    test('duration edit invalidates sequence fact without rewriting bank facts', () {
      final bank = _bank();
      final availability = _availability();
      final context = BackupEvidenceContext(
        projectId: 'project',
        revisionId: 'revision',
        scenarioId: 'backup',
        sequenceId: 'sequence',
        bankId: 'bank-1',
      );
      final demand = _wattDemandEvidence(
        subjectId: 'bank-demand',
        watts: _r('25'),
        segmentId: 'standby',
        scenarioId: 'backup',
      );
      final first = evaluateBatterySequencePipeline(
        evaluationId: 'a',
        context: context,
        bank: bank,
        availability: availability,
        segments: [
          BackupEnergySegment(
            segmentId: 'standby',
            durationSeconds: _r('3600'),
            bankInputW: _r('25'),
          ),
        ],
        extensionPolicy: PowerExtensionPolicy.none,
        segmentDemandEvaluations: [demand],
      );
      final second = evaluateBatterySequencePipeline(
        evaluationId: 'b',
        context: context,
        bank: bank,
        availability: availability,
        segments: [
          BackupEnergySegment(
            segmentId: 'standby',
            durationSeconds: _r('7200'),
            bankInputW: _r('25'),
          ),
        ],
        extensionPolicy: PowerExtensionPolicy.none,
        segmentDemandEvaluations: [demand],
      );

      final diff = second.diff(first);
      expect(diff.changedDependencyKeys, hasLength(1));
      expect(diff.changedDependencyKeys.single, contains('PROTECTED_SEQUENCE'));
    });
  });

  group('P6 charger boundary', () {
    test('charger conversion enters parent once and is dependency-backed', () {
      final bank = _bank();
      final charger = _charger();
      final context = ChargerEvidenceContext(
        projectId: 'project',
        revisionId: 'revision',
        scenarioId: 'normal',
        segmentId: 'segment-charge',
        chargerId: 'charger-1',
        bankId: 'bank-1',
      );
      final operating = _wattDemandEvidence(
        subjectId: 'operating-load',
        watts: _r('20'),
        segmentId: 'segment-charge',
      );
      final pipeline = evaluateChargerToCapabilityPipeline(
        context: context,
        charger: charger,
        bank: bank,
        bankCompatibility: ChargerBankCompatibilityEvidence(
          seriesCount: 2,
          compatible: true,
          evidenceRef: 'catalog:charger-bank-2s',
        ),
        operatingOutputW: _r('20'),
        chargeVoltageV: _r('27'),
        selectedChargeCurrentA: _r('2'),
        chargingSelected: true,
        dischargingSelected: false,
        operatingDemandEvaluation: operating,
        scenarioFacts: const {'mains': 'AVAILABLE', 'mode': 'RECHARGE'},
        chargerEvaluationId: 'charger-boundary',
        parentDemandEvaluationId: 'charger-parent',
        capabilityEvaluationId: 'charger-capability',
        parentBoundaryRef: 'AC_SOURCE',
        parentSubjectKind: 'SOURCE',
        parentSubjectId: 'ac-source',
        capabilitySubjectKind: 'SOURCE',
        capabilitySubjectId: 'ac-source',
        sourceNameplateW: _r('120'),
      );

      expect(pipeline.charger.charger.chargingOutputW, _r('54'));
      expect(pipeline.charger.charger.combinedOutputW, _r('74'));
      expect(pipeline.charger.charger.upstreamInputW, _r('94.5'));
      expect(pipeline.parentDemand.outputDemandW, _r('94.5'));
      expect(pipeline.parentDemand.upstreamInputW, _r('94.5'));
      expect(
        pipeline.parentDemandEvidence.dependencies.single,
        pipeline.chargerEvidence.evaluation.nodeKey,
      );
    });
  });
}

DcEvidenceContext _dcContext({String domainId = 'dc-domain'}) =>
    DcEvidenceContext(
      projectId: 'project',
      revisionId: 'revision',
      scenarioId: 'normal',
      segmentId: 'segment-1',
      domainId: domainId,
    );

DcConstantCurrentDomainInput _ccInput() => DcConstantCurrentDomainInput(
      domainId: 'dc-domain',
      tree: DcTreeInput(
        sourceNodeId: 'source',
        sourceVoltage: _dcEnvelope('24', '24', '24'),
        sections: [
          DcSection.loopTotal(
            sectionId: 's1',
            parentNodeId: 'source',
            childNodeId: 'load-node',
            loopResistanceOhm: _r('1'),
            currentRatingA: _r('3'),
            evidenceRef: 'fixture:s1',
          ),
        ],
        loads: [
          DcConstantCurrentLoad(
            loadId: 'lock',
            nodeId: 'load-node',
            currentA: _r('2'),
            allowedMinV: _r('20'),
            allowedMaxV: _r('25'),
          ),
        ],
      ),
    );

DcSectionPhysicalEvidence _completePhysical(String sectionId) =>
    DcSectionPhysicalEvidence(
      sectionId: sectionId,
      allocationId: 'allocation-$sectionId',
      cableRunId: 'run-$sectionId',
      traversalRef: 'traversal-$sectionId',
      resourceRefs: ['resource-$sectionId'],
      terminationRefs: ['term-a-$sectionId', 'term-b-$sectionId'],
    );

PowerEvaluationEvidence _currentDemandEvidence({
  required String loadId,
  required PowerRational currentA,
  required String segmentId,
}) {
  final demand = aggregatePowerDemand([
    PowerDemandContribution(
      originId: loadId,
      componentId: loadId,
      inputPortId: '$loadId-in',
      stateCode: 'NORMAL',
      demand: DcConstantCurrentDemand(currentA),
    ),
  ]);
  return buildPowerDemandEvidence(
    evaluationId: 'demand-$loadId',
    revisionId: 'revision',
    scenarioId: 'normal',
    segmentId: segmentId,
    subjectKind: 'LOAD',
    subjectId: loadId,
    demand: demand,
  );
}

PowerEvaluationEvidence _wattDemandEvidence({
  required String subjectId,
  required PowerRational watts,
  required String segmentId,
  String scenarioId = 'normal',
}) {
  final demand = aggregatePowerDemand([
    PowerDemandContribution(
      originId: subjectId,
      componentId: subjectId,
      inputPortId: '$subjectId-in',
      stateCode: 'ACTIVE',
      demand: DcConstantPowerDemand(watts),
    ),
  ]);
  return buildPowerDemandEvidence(
    evaluationId: 'demand-$subjectId-$segmentId',
    revisionId: 'revision',
    scenarioId: scenarioId,
    segmentId: segmentId,
    subjectKind: 'LOAD',
    subjectId: subjectId,
    demand: demand,
  );
}

BatteryBankBinding _bank() {
  final unit = BatteryUnitDefinition(
    definitionRef: _ref(PowerDefinitionKind.battery, 'BATTERY_12V_7AH'),
    technology: 'VRLA',
    nominalV: _r('12'),
    capacityBasis: BatteryCapacityBasis.ampHour,
    ratedCapacity: _r('7'),
    usableFraction: _r('0.8'),
    maxSeriesCount: 4,
    maxParallelCount: 2,
    arrangementCodes: const ['SERIES'],
  );
  return BatteryBankBinding(
    componentId: 'bank-1',
    unitDefinition: unit,
    seriesCount: 2,
    parallelCount: 1,
    arrangementCode: 'SERIES',
    socMin: _r('0.2'),
    socMax: _r('1'),
    endOfDischargeVoltagePerUnit: _r('10.5'),
  );
}

BatteryWhAvailabilityModel _availability() => BatteryWhAvailabilityModel(
      modelVoltageV: _r('24'),
      bankAh: _r('7'),
      initialSocFraction: _r('1'),
      minimumSocFraction: _r('0.2'),
      temperatureFactor: _r('1'),
      agingFactor: _r('1'),
      rateFactor: _r('1'),
    );

PowerChargerDefinition _charger() => PowerChargerDefinition(
      definitionRef: _ref(PowerDefinitionKind.transfer, 'CHARGER_2S'),
      outputVoltage: _dcEnvelope('24', '27', '30'),
      maxChargeCurrentA: _r('5'),
      lossDefinition: PowerLossDefinition(
        efficiency: _r('0.8'),
        idleW: _r('2'),
        idleAccounting: PowerIdleAccounting.excludesSeparateIdle,
      ),
      supportedBatteryTechnologies: const ['VRLA'],
    );

PowerDefinitionRef _ref(PowerDefinitionKind kind, String code) =>
    PowerDefinitionRef(
      catalogId: 'catalog',
      catalogVersion: '1',
      definitionKind: kind,
      definitionCode: code,
      definitionVersion: '1',
      definitionSchema: 'electra.fixture.v1',
      contentSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      sourceRef: 'fixture:$code',
    );

PowerVoltageEnvelope _dcEnvelope(String minV, String nominalV, String maxV) =>
    PowerVoltageEnvelope(
      currentKind: PowerCurrentKind.dc,
      minV: _r(minV),
      nominalV: _r(nominalV),
      maxV: _r(maxV),
    );

PowerRational _r(String value) => PowerRational.fromWireDecimal(value);
