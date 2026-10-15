import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P1 canonical power bindings', () {
    test('projection ownership rejects multiple owners for one field', () {
      expect(
        () => PowerProjectionOwnership([
          PowerProjectionClaim(
            field: PowerProjectionField.voltageEnvelope,
            ownerKind: PowerProjectionOwnerKind.elv2,
            ownerRef: 'legacy-profile',
          ),
          PowerProjectionClaim(
            field: PowerProjectionField.voltageEnvelope,
            ownerKind: PowerProjectionOwnerKind.elv4,
            ownerRef: 'power-profile',
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('port binding round-trips exact canonical ownership and terminals',
        () {
      final binding = PowerPortBinding(
        portId: 'port-1',
        profileRef: _ref(PowerDefinitionKind.port, 'DC_INPUT'),
        role: PowerPortRole.consumer,
        voltageEnvelope: _dcEnvelope(),
        terminalRoles: const ['minus', 'plus'],
        ownership: _dcOwnership(),
      );

      final decoded = PowerPortBinding.fromMap(binding.toMap());
      expect(
        canonicalEngineeringJsonV1(decoded.toMap()),
        canonicalEngineeringJsonV1(binding.toMap()),
      );
      expect(decoded.terminalRoles, ['MINUS', 'PLUS']);
    });

    test('active transfer requires loss and unique idle contribution identity',
        () {
      expect(
        () => PowerTransferBinding(
          id: 'psu-main',
          componentId: 'component-psu',
          definitionRef: _ref(PowerDefinitionKind.transfer, 'PSU'),
          kind: PowerTransferKind.psu,
          inputPortIds: const ['ac-in'],
          outputPortIds: const ['dc-out'],
          enabledStateCodes: const ['normal'],
          inputAccountingOrigin: 'upstream-input',
        ),
        throwsArgumentError,
      );

      final loss = PowerLossDefinition(
        efficiency: _r('0.9'),
        idleW: _r('2'),
        idleAccounting: PowerIdleAccounting.excludesSeparateIdle,
      );
      expect(
        () => PowerTransferBinding(
          id: 'psu-main',
          componentId: 'component-psu',
          definitionRef: _ref(PowerDefinitionKind.transfer, 'PSU'),
          kind: PowerTransferKind.psu,
          inputPortIds: const ['ac-in'],
          outputPortIds: const ['dc-out'],
          enabledStateCodes: const ['normal'],
          inputAccountingOrigin: 'upstream-input',
          lossDefinition: loss,
        ),
        throwsArgumentError,
      );

      final transfer = PowerTransferBinding(
        id: 'psu-main',
        componentId: 'component-psu',
        definitionRef: _ref(PowerDefinitionKind.transfer, 'PSU'),
        kind: PowerTransferKind.psu,
        inputPortIds: const ['ac-in'],
        outputPortIds: const ['dc-out'],
        enabledStateCodes: const ['normal'],
        inputAccountingOrigin: 'upstream-input',
        lossDefinition: loss,
        idleContributionId: 'psu_idle',
      );
      expect(transfer.idleContributionId, 'PSU_IDLE');
    });

    test('capacity group keeps W A VA independent and rejects duplicates', () {
      final group = PowerCapacityGroup(
        id: 'shared-output',
        ownerComponentId: 'psu',
        memberOutputPortIds: const ['out-2', 'out-1'],
        limits: [
          PowerCapacityLimit(
            dimension: PowerCapacityDimension.watt,
            limit: _r('120'),
          ),
          PowerCapacityLimit(
            dimension: PowerCapacityDimension.ampere,
            limit: _r('5'),
          ),
          PowerCapacityLimit(
            dimension: PowerCapacityDimension.voltAmpere,
            limit: _r('150'),
          ),
        ],
        applicabilityStateCodes: const ['backup', 'normal'],
        deratingFactor: _r('0.8'),
      );
      expect(group.memberOutputPortIds, ['out-1', 'out-2']);
      expect(group.limits, hasLength(3));

      expect(
        () => PowerCapacityGroup(
          id: 'invalid',
          ownerComponentId: 'psu',
          memberOutputPortIds: const ['out-1'],
          limits: [
            PowerCapacityLimit(
              dimension: PowerCapacityDimension.watt,
              limit: _r('10'),
            ),
            PowerCapacityLimit(
              dimension: PowerCapacityDimension.watt,
              limit: _r('20'),
            ),
          ],
          applicabilityStateCodes: const ['normal'],
        ),
        throwsArgumentError,
      );
    });
  });

  group('P1 explicit operating scenarios', () {
    test(
        'selection cannot use unavailable source and bank directions interlock',
        () {
      expect(
        () => PowerScenarioSegment(
          segmentId: 'backup',
          ordinal: 1,
          selectedSourceBySupplySet: const {'MAIN': 'mains'},
          unavailableSourceIds: const ['mains'],
        ),
        throwsArgumentError,
      );
      expect(
        () => PowerScenarioSegment(
          segmentId: 'backup',
          ordinal: 1,
          chargingBankIds: const ['bank-1'],
          dischargingBankIds: const ['bank-1'],
        ),
        throwsArgumentError,
      );
    });

    test('scenario fingerprint is insensitive to unordered map/set input', () {
      final scenarioA = PowerOperatingScenario(
        scenarioId: 'backup-day',
        role: PowerScenarioRole.backup,
        rowRevision: 1,
        segments: [
          PowerScenarioSegment(
            segmentId: 's1',
            ordinal: 1,
            durationSeconds: _r('3600'),
            componentStates: const {
              'switch': PowerDeviceState.normal,
              'ups': PowerDeviceState.discharging,
            },
            selectedSourceBySupplySet: const {
              'LAN': 'ups',
              'ACS': 'battery',
            },
            unavailableSourceIds: const ['mains', 'generator'],
            dischargingBankIds: const ['bank-b', 'bank-a'],
          ),
        ],
      );
      final scenarioB = PowerOperatingScenario(
        scenarioId: 'backup-day',
        role: PowerScenarioRole.backup,
        rowRevision: 1,
        segments: [
          PowerScenarioSegment(
            segmentId: 's1',
            ordinal: 1,
            durationSeconds: _r('3600'),
            componentStates: const {
              'ups': PowerDeviceState.discharging,
              'switch': PowerDeviceState.normal,
            },
            selectedSourceBySupplySet: const {
              'ACS': 'battery',
              'LAN': 'ups',
            },
            unavailableSourceIds: const ['generator', 'mains'],
            dischargingBankIds: const ['bank-a', 'bank-b'],
          ),
        ],
      );
      expect(scenarioA.fingerprintSha256, scenarioB.fingerprintSha256);
    });

    test('scenario segment order is explicit and gap-free', () {
      expect(
        () => PowerOperatingScenario(
          scenarioId: 'invalid',
          role: PowerScenarioRole.startup,
          rowRevision: 1,
          segments: [
            PowerScenarioSegment(segmentId: 's2', ordinal: 2),
            PowerScenarioSegment(segmentId: 's1', ordinal: 1),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('P1 PoE and battery definitions', () {
    test('series raises voltage while Ah capacity scales only with parallel',
        () {
      final unit = BatteryUnitDefinition(
        definitionRef: _ref(PowerDefinitionKind.battery, 'BAT_12V'),
        technology: 'vrla',
        nominalV: _r('12'),
        capacityBasis: BatteryCapacityBasis.ampHour,
        ratedCapacity: _r('7.2'),
        usableFraction: _r('0.8'),
        maxSeriesCount: 4,
        maxParallelCount: 4,
        arrangementCodes: const ['S2P3'],
      );
      final bank = BatteryBankBinding(
        componentId: 'bank-component',
        unitDefinition: unit,
        seriesCount: 2,
        parallelCount: 3,
        arrangementCode: 'S2P3',
        socMin: _r('0.2'),
        socMax: _r('1'),
        endOfDischargeVoltagePerUnit: _r('10.5'),
      );
      expect(bank.nominalBankV, _r('24'));
      expect(bank.ratedBankCapacity, _r('21.6'));
    });

    test('charger and PoE definitions reject unsupported physical assumptions',
        () {
      final charger = PowerChargerDefinition(
        definitionRef: _ref(PowerDefinitionKind.transfer, 'CHARGER'),
        outputVoltage: _dcEnvelope(),
        maxChargeCurrentA: _r('5'),
        lossDefinition: PowerLossDefinition(
          efficiency: _r('0.9'),
          idleW: PowerRational.zero,
          idleAccounting: PowerIdleAccounting.includesIdle,
        ),
        supportedBatteryTechnologies: const ['vrla'],
      );
      final unit = BatteryUnitDefinition(
        definitionRef: _ref(PowerDefinitionKind.battery, 'BAT_24V'),
        technology: 'vrla',
        nominalV: _r('24'),
        capacityBasis: BatteryCapacityBasis.ampHour,
        ratedCapacity: _r('10'),
        usableFraction: _r('0.8'),
        maxSeriesCount: 1,
        maxParallelCount: 2,
      );
      expect(charger.supports(unit), isTrue);

      expect(
        () => PoeDeliveryDefinition(
          definitionRef: _ref(PowerDefinitionKind.poe, 'POE_BAD'),
          guaranteedPdPowerW: _r('25'),
          psePortLimitW: _r('26'),
          maxChannelLossW: _r('2'),
          compatibleResourceKinds: const ['COPPER_PAIR'],
          supportsMidspan: true,
        ),
        throwsArgumentError,
      );
    });
  });

  group('P1 reviewed legacy adoption', () {
    test('missing typed fact stays unresolved and exact mismatch conflicts',
        () {
      final preview = PowerLegacyAdoptionPreview.compare(
        subjectId: 'port-1',
        legacy: {
          LegacyPowerField.nominalVoltage: PowerEvidenceValue(
            value: '24',
            provenance: 'legacy-port',
          ),
          LegacyPowerField.demand: PowerEvidenceValue(
            value: '10',
            provenance: 'legacy-profile',
          ),
        },
        typed: {
          LegacyPowerField.demand: PowerEvidenceValue(
            value: '12',
            provenance: 'power-definition',
          ),
        },
      );
      expect(preview.canCommit, isFalse);
      expect(preview.hasUnresolved, isTrue);
      expect(
        preview.fields
            .singleWhere(
              (field) => field.field == LegacyPowerField.nominalVoltage,
            )
            .disposition,
        LegacyAdoptionDisposition.unresolved,
      );
      expect(
        preview.fields
            .singleWhere(
              (field) => field.field == LegacyPowerField.demand,
            )
            .disposition,
        LegacyAdoptionDisposition.conflict,
      );
    });

    test('equal reviewed evidence is preserved without inferred fields', () {
      final preview = PowerLegacyAdoptionPreview.compare(
        subjectId: 'port-1',
        legacy: {
          LegacyPowerField.limit: PowerEvidenceValue(
            value: '20',
            provenance: 'legacy-port',
          ),
        },
        typed: {
          LegacyPowerField.limit: PowerEvidenceValue(
            value: '20',
            provenance: 'power-definition',
          ),
        },
      );
      expect(preview.canCommit, isTrue);
      expect(preview.hasUnresolved, isFalse);
      expect(
        preview.fields.single.disposition,
        LegacyAdoptionDisposition.preserved,
      );
    });
  });
}

PowerRational _r(String value) => PowerRational.fromWireDecimal(value);

PowerVoltageEnvelope _dcEnvelope() => PowerVoltageEnvelope(
      currentKind: PowerCurrentKind.dc,
      minV: _r('23'),
      nominalV: _r('24'),
      maxV: _r('25'),
    );

PowerProjectionOwnership _dcOwnership() => PowerProjectionOwnership([
      for (final field in const [
        PowerProjectionField.currentKind,
        PowerProjectionField.voltageEnvelope,
        PowerProjectionField.powerDirection,
        PowerProjectionField.terminalRoles,
      ])
        PowerProjectionClaim(
          field: field,
          ownerKind: PowerProjectionOwnerKind.elv4,
          ownerRef: 'power-profile',
        ),
    ]);

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
