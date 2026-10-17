import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/environment/ampacity_section_contract.dart';
import 'package:electra_mobile/application/elv5/environment/environment_profile_persistence.dart';
import 'package:electra_mobile/application/elv5/fire/fa08_policy_contract.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_ampacity_section_contract_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_runtime.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_environment_profile_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa08_invalidation_coordinator.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa08_policy_contract_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv5_f2_qualification_harness.dart';

void main() {
  test(
    'F2 FA-08 production Q6/Q7/Q8 survives invalidation, restart and freeze',
    () async {
      const harness = Elv5F2QualificationHarness();
      final directory = await Directory.systemTemp.createTemp(
        'electra-f2-fa08-production-',
      );
      final file = File('${directory.path}/qualification.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      await _seedTopology(db);
      var environmentStore = _environmentStore(db);
      var ampacityStore = _ampacityStore(db);
      var policyStore = _policyStore(db);

      await environmentStore.replace(
        ReplaceElv5EnvironmentProfileCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 1,
          bindingId: 'env-room',
          expectedBindingRevision: null,
          scopeKind: 'ROOM',
          scopeId: 'room-1',
          profile: _environment(
            editionId: 'env-normal',
            maximumTemperatureC: '40',
            evidenceSeed: 'a',
          ),
        ),
      );
      final normalEnvironment = await _activeEnvironment(environmentStore);
      await ampacityStore.replace(
        ReplaceElv5AmpacitySectionContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 2,
          bindingId: 'ampacity-section',
          expectedBindingRevision: null,
          contract: _ampacityContract(
            environment: normalEnvironment,
            factor: '0.90',
            evidenceSeed: 'b',
          ),
        ),
      );
      await policyStore.replace(
        ReplaceFa08CablePolicyContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 3,
          bindingId: 'fa08-policy',
          expectedBindingRevision: null,
          contract: _policy(),
        ),
      );

      var runtime = _runtime(db);
      final firstCommand = _command(
        commandId: 'fa08-production-1',
        expectedDesignRevision: 4,
        expectedPointerGeneration: 0,
      );
      final first = await runtime.service.execute(firstCommand);
      expect(first.replayed, isFalse);
      final firstSnapshot = await _snapshot(db, first.logicalResultJson);
      harness.assertQ6Initial('FA-08', firstSnapshot);
      await _expectDependencies(db);

      final oldEnvironmentEvidenceRef = normalEnvironment.profile.evidenceRef;
      await environmentStore.replace(
        ReplaceElv5EnvironmentProfileCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 4,
          bindingId: 'env-room',
          expectedBindingRevision: 1,
          scopeKind: 'ROOM',
          scopeId: 'room-1',
          profile: _environment(
            editionId: 'env-hot',
            maximumTemperatureC: '45',
            evidenceSeed: 'c',
          ),
        ),
      );
      expect(
        await DriftFa08InvalidationCoordinator(
          db,
          originDeviceId: 'f2-fa08-production',
          nowUtc: _now,
        ).environmentEditionChanged(
          projectId: 'p',
          designRevisionId: 'd',
          oldEvidenceRef: oldEnvironmentEvidenceRef,
        ),
        1,
      );
      await _expectPointer(db: db, freshness: 'STALE', generation: 2);

      final hotEnvironment = await _activeEnvironment(environmentStore);
      await ampacityStore.replace(
        ReplaceElv5AmpacitySectionContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 5,
          bindingId: 'ampacity-section',
          expectedBindingRevision: 1,
          contract: _ampacityContract(
            environment: hotEnvironment,
            factor: '0.70',
            evidenceSeed: 'd',
          ),
        ),
      );

      final secondCommand = _command(
        commandId: 'fa08-production-2',
        expectedDesignRevision: 6,
        expectedPointerGeneration: 2,
      );
      final second = await runtime.service.execute(secondCommand);
      expect(second.replayed, isFalse);
      final secondSnapshot = await _snapshot(db, second.logicalResultJson);
      harness.assertQ6Republished('FA-08', firstSnapshot, secondSnapshot);

      await harness.expectQ7StaleWriter('FA-08', () async {
        await runtime.service.execute(
          _command(
            commandId: 'fa08-stale-writer',
            expectedDesignRevision: 6,
            expectedPointerGeneration: 2,
          ),
        );
      });

      await db.close();
      db = AppDatabase(NativeDatabase(file));
      runtime = _runtime(db);
      environmentStore = _environmentStore(db);
      ampacityStore = _ampacityStore(db);
      policyStore = _policyStore(db);
      final replay = await runtime.service.execute(secondCommand);
      expect(replay.replayed, isTrue);
      final restartedSnapshot = await _snapshot(db, replay.logicalResultJson);
      harness.assertQ7Replay('FA-08', secondSnapshot, restartedSnapshot);

      await db.customUpdate(
        "UPDATE project_design_revisions SET state = 'FROZEN', revision = revision + 1 "
        "WHERE project_id = 'p' AND id = 'd'",
      );
      final frozenReplay = await runtime.service.execute(secondCommand);
      expect(frozenReplay.replayed, isTrue);
      final frozenSnapshot = await _snapshot(db, frozenReplay.logicalResultJson);
      harness.assertQ8Replay('FA-08', secondSnapshot, frozenSnapshot);

      await harness.expectQ8ReadOnly('FA-08', () async {
        await runtime.service.execute(
          _command(
            commandId: 'fa08-after-freeze',
            expectedDesignRevision: 7,
            expectedPointerGeneration: 3,
          ),
        );
      }, operation: 'new calculation');
      await expectLater(
        policyStore.replace(
          ReplaceFa08CablePolicyContractCommand(
            projectId: 'p',
            designRevisionId: 'd',
            expectedDesignRevision: 7,
            bindingId: 'fa08-policy',
            expectedBindingRevision: 1,
            contract: _policy(minimumIz: '22'),
          ),
        ),
        throwsStateError,
      );

      expect(
        (await _activeEnvironment(environmentStore)).profile.editionId,
        'env-hot',
      );
      expect(
        (await policyStore.loadActiveForCableRun(
          projectId: 'p',
          designRevisionId: 'd',
          cableRunId: 'run-1',
        ))?.bindingRevision,
        1,
      );
      expect(
        (await ampacityStore.loadActiveForSection(
          projectId: 'p',
          designRevisionId: 'd',
          routeSectionId: 'section-1',
        ))?.bindingRevision,
        2,
      );
    },
  );
}

DriftElv5CalculationRuntime _runtime(AppDatabase db) =>
    DriftElv5CalculationRuntime.create(
      db,
      originDeviceId: 'f2-fa08-production',
      nowUtc: _now,
    );

DriftElv5EnvironmentProfileStore _environmentStore(AppDatabase db) =>
    DriftElv5EnvironmentProfileStore(
      db,
      originDeviceId: 'f2-fa08-production',
      nowUtc: _now,
    );

DriftElv5AmpacitySectionContractStore _ampacityStore(AppDatabase db) =>
    DriftElv5AmpacitySectionContractStore(
      db,
      originDeviceId: 'f2-fa08-production',
      nowUtc: _now,
    );

DriftFa08CablePolicyContractStore _policyStore(AppDatabase db) =>
    DriftFa08CablePolicyContractStore(
      db,
      originDeviceId: 'f2-fa08-production',
      nowUtc: _now,
    );

Future<Elv5EnvironmentProfileSnapshot> _activeEnvironment(
  DriftElv5EnvironmentProfileStore store,
) async {
  final snapshot = await store.loadActiveForScope(
    projectId: 'p',
    designRevisionId: 'd',
    scopeKind: 'ROOM',
    scopeId: 'room-1',
  );
  expect(snapshot, isNotNull);
  return snapshot!;
}

Elv5WireCommandEnvelope _command({
  required String commandId,
  required int expectedDesignRevision,
  required int expectedPointerGeneration,
}) => Elv5WireCommandEnvelope(
  operation: 'CALCULATE_DISCIPLINE_PROCESS',
  projectId: 'p',
  designRevisionId: 'd',
  commandId: commandId,
  expectedDesignRowRevision: expectedDesignRevision,
  expectedRows: const <String, int>{},
  reviewedImpactFingerprint: _hash('9'),
  payload: <String, Object?>{
    'scope': <String, Object?>{
      'kind': 'DESIGN',
      'scopeId': 'd',
      'scenarioKey': 'NONE',
    },
    'processCodes': <String>[Elv5ProcessCode.fa08.wireCode],
    'subjects': const <Object?>[
      <String, Object?>{'kind': 'CABLE_RUN', 'id': 'run-1'},
    ],
    'expectedPointerGenerations': <String, Object?>{
      _nodeSha(): expectedPointerGeneration,
    },
  },
);

String _nodeSha() => const Elv5CanonicalJsonV1().sha256(
  Elv5EngineeringNodeKeyV3(
    designRevisionId: 'd',
    scope: Elv5ScopeRef(
      kind: Elv5ScopeKind.design,
      scopeId: 'd',
      scenarioKey: 'NONE',
    ),
    processCode: Elv5ProcessCode.fa08,
    subject: Elv5SubjectRef(kind: 'CABLE_RUN', id: 'run-1'),
  ).toCanonicalValue(),
);

Future<Elv5F2PublicationSnapshot> _snapshot(
  AppDatabase db,
  String logicalResultJson,
) async {
  final pointer =
      await db
          .customSelect(
            'SELECT freshness, generation, evaluation_id, input_fingerprint '
            'FROM discipline_evaluation_pointers '
            'WHERE project_id = ? AND design_revision_id = ? '
            'AND logical_node_key_sha256 = ?',
            variables: <Variable>[
              Variable.withString('p'),
              Variable.withString('d'),
              Variable.withString(_nodeSha()),
            ],
          )
          .getSingle();
  final evaluation =
      await db
          .customSelect(
            'SELECT execution, completion FROM discipline_evaluation_records '
            'WHERE project_id = ? AND evaluation_id = ?',
            variables: <Variable>[
              Variable.withString('p'),
              Variable.withString(pointer.read<String>('evaluation_id')),
            ],
          )
          .getSingle();
  return Elv5F2PublicationSnapshot(
    generation: pointer.read<int>('generation'),
    evaluationId: pointer.read<String>('evaluation_id'),
    freshness: pointer.read<String>('freshness'),
    execution: evaluation.read<String>('execution'),
    completion: evaluation.read<String>('completion'),
    inputFingerprint: pointer.read<String>('input_fingerprint'),
    logicalResultJson: logicalResultJson,
  );
}

Future<void> _expectPointer({
  required AppDatabase db,
  required String freshness,
  required int generation,
}) async {
  final row =
      await db
          .customSelect(
            'SELECT freshness, generation FROM discipline_evaluation_pointers '
            'WHERE project_id = ? AND design_revision_id = ? '
            'AND logical_node_key_sha256 = ?',
            variables: <Variable>[
              Variable.withString('p'),
              Variable.withString('d'),
              Variable.withString(_nodeSha()),
            ],
          )
          .getSingle();
  expect(row.read<String>('freshness'), freshness);
  expect(row.read<int>('generation'), generation);
}

Future<void> _expectDependencies(AppDatabase db) async {
  final rows =
      await db
          .customSelect(
            'SELECT dependency_key FROM discipline_dependency_index '
            'WHERE project_id = ? AND design_revision_id = ? '
            'AND logical_node_key_sha256 = ?',
            variables: <Variable>[
              Variable.withString('p'),
              Variable.withString('d'),
              Variable.withString(_nodeSha()),
            ],
          )
          .get();
  final joined = rows
      .map((row) => row.read<String>('dependency_key'))
      .join('\n');
  expect(joined, contains('CABLE_RUN_ROUTE'));
  expect(joined, contains('FA08_CABLE_POLICY_CONTRACT'));
  expect(joined, contains('ELV5_ENVIRONMENT_PROFILE'));
  expect(joined, contains('AMPACITY_REFERENCE_ROW'));
  expect(joined, contains('AMPACITY_TEMPERATURE_CORRECTION'));
  expect(joined, contains('AMPACITY_GROUPING_CORRECTION'));
}

Elv5EnvironmentProfile _environment({
  required String editionId,
  required String maximumTemperatureC,
  required String evidenceSeed,
}) => Elv5EnvironmentProfile(
  profileId: 'ENV-ROOM-1',
  editionId: editionId,
  profileCode: 'ROOM_STANDARD',
  temperatureC: Elv5RationalRange(
    minimum: Elv5Rational.integer(10),
    maximum: Elv5Rational.parseDecimal(maximumTemperatureC),
  ),
  relativeHumidityPercent: Elv5RationalRange(
    minimum: Elv5Rational.integer(20),
    maximum: Elv5Rational.integer(80),
  ),
  condensationRisk: Elv5CondensationRisk.none,
  exposure: Elv5EnvironmentExposure.indoor,
  evidenceRef: 'ENV:$editionId',
  evidenceContentHash: _hash(evidenceSeed),
);

Elv5AmpacitySectionContract _ampacityContract({
  required Elv5EnvironmentProfileSnapshot environment,
  required String factor,
  required String evidenceSeed,
}) => Elv5AmpacitySectionContract(
  routeSectionId: 'section-1',
  cableRunId: 'run-1',
  cableId: 'cable-1',
  expectedEnvironmentProfileId: environment.profile.profileId,
  expectedEnvironmentEditionId: environment.profile.editionId,
  expectedEnvironmentContentHash: environment.contentHash,
  referenceRow: Elv5AmpacityReferenceRow(
    conductorCrossSectionMm2: Elv5Rational.parseDecimal('2.5'),
    conductorMaterialCode: 'CU',
    insulationSystemCode: 'FE180',
    referenceAmbientTemperatureC: Elv5Rational.integer(30),
    installationMethodCode: 'TRAY',
    loadedConductors: 2,
    baseAllowableCurrentA: Elv5Rational.integer(30),
    evidenceRef: 'ROW:$evidenceSeed',
    evidenceContentHash: _hash('1'),
  ),
  temperatureCorrection: Elv5AmpacityTemperatureCorrection(
    actualAmbientTemperatureC: environment.profile.temperatureC.maximum,
    factor: Elv5Rational.parseDecimal(factor),
    evidenceRef: 'TEMP:$factor',
    evidenceContentHash: _hash('2'),
  ),
  groupingCorrection: Elv5AmpacityGroupingCorrection(
    groupedCableOrCircuitCount: 1,
    arrangementCode: 'SINGLE',
    factor: Elv5Rational.one,
    evidenceRef: 'GROUP:1',
    evidenceContentHash: _hash('3'),
  ),
);

Fa08CablePolicyContract _policy({String minimumIz = '20'}) =>
    Fa08CablePolicyContract(
      cableRunId: 'run-1',
      policyId: 'fire-cable-policy',
      requirements: <Fa08Requirement>[
        Fa08Requirement.cableClass(
          code: 'FIRE_CLASS',
          expectedClass: 'PH120',
        ),
        Fa08Requirement.numeric(
          code: 'MIN_IZ',
          kind: Fa08RequirementKind.numericMinimum,
          propertyCode: Fa08RouteSection.ampacityIzPropertyCode,
          unitCode: 'A',
          threshold: Elv5Rational.parseDecimal(minimumIz),
        ),
      ],
    );

CableDefinition _definition() => CableDefinition(
  code: 'FIRE-CABLE',
  label: 'Fire resistant cable',
  mediaCode: 'COPPER_POWER',
  conductorMaterialCode: 'CU',
  firePerformanceCode: 'PH120',
  resourceDefinitions: <CableResourceDefinition>[
    CableResourceDefinition(
      identity: '__WHOLE_CABLE__',
      kind: CableResourceKind.wholeCable,
      allocatable: true,
      atomic: true,
      terminationPolicy: TerminationPolicy(
        mode: TerminationPolicyMode.bothEnds,
        terminalRequired: true,
      ),
    ),
  ],
);

EngineeringReferenceCatalog _catalog() => EngineeringReferenceCatalog(
  id: 'catalog-fire',
  code: 'ELV-FIRE-CABLES',
  version: '2026.1',
  source: 'F2_FA08_PRODUCTION',
  cableDefinitions: <CableDefinition>[_definition()],
);

Future<void> _seedTopology(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  final now = DateTime.utc(2026, 10, 17, 12);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'p',
          name: 'F2 FA-08 production qualification',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
  await db
      .into(db.projectDesignRevisions)
      .insert(
        ProjectDesignRevisionsCompanion.insert(
          id: 'd',
          projectId: 'p',
          code: 'R1',
          sequence: 1,
          state: 'WORKING',
          revision: const Value(1),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
  await db.customStatement(
    "INSERT INTO rooms (id,floor_id,name,room_type,room_category,width_mm,depth_mm,structural_height_mm_override,finished_ceiling_height_mm_override,revision,created_at,updated_at,deleted_at,origin_device_id) VALUES ('room-1','floor-x','Electrical room','technical','technical',4000,4000,NULL,NULL,1,'${now.millisecondsSinceEpoch ~/ 1000}','${now.millisecondsSinceEpoch ~/ 1000}',NULL,'f2-fa08-production')",
  );
  await db.customStatement(
    "INSERT INTO cable_routes (id,room_id,name,revision,created_at,updated_at,deleted_at,origin_device_id) VALUES ('route-1','room-1','Fire route',1,'${now.millisecondsSinceEpoch ~/ 1000}','${now.millisecondsSinceEpoch ~/ 1000}',NULL,'f2-fa08-production')",
  );
  await db.customStatement(
    "INSERT INTO cable_route_segments (id,route_id,sequence,from_node_id,to_node_id,surface_patch_id,laying_method,physical_channel_id,revision,created_at,updated_at,deleted_at,origin_device_id) VALUES ('section-1','route-1',1,'node-a','node-b','patch-x','TRAY',NULL,1,'${now.millisecondsSinceEpoch ~/ 1000}','${now.millisecondsSinceEpoch ~/ 1000}',NULL,'f2-fa08-production')",
  );

  final catalog = _catalog();
  final definitionRef = catalog.cableDefinitionRef('FIRE-CABLE');
  await db
      .into(db.engineeringReferenceCatalogs)
      .insert(
        EngineeringReferenceCatalogsCompanion.insert(
          id: catalog.id,
          projectId: 'p',
          code: catalog.code,
          catalogVersion: catalog.version,
          payloadJson: canonicalEngineeringJsonV1(catalog.toMap()),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
  await db
      .into(db.elvCables)
      .insert(
        ElvCablesCompanion.insert(
          id: 'cable-1',
          projectId: 'p',
          label: 'FC-1',
          normalizedLabel: 'FC-1',
          name: 'Fire cable',
          definitionCatalogId: definitionRef.catalogId,
          definitionCatalogVersion: definitionRef.catalogVersion,
          definitionCode: definitionRef.definitionCode,
          definitionContentHash: definitionRef.definitionContentHash,
          lifecycleState: 'ACTIVE',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
  await db
      .into(db.canonicalCableRuns)
      .insert(
        CanonicalCableRunsCompanion.insert(
          id: 'run-1',
          projectId: 'p',
          cableId: 'cable-1',
          designRevisionId: 'd',
          lifecycleState: 'ACTIVE',
          reservePercent: const Value(0),
          terminationAllowanceMm: const Value(0),
          revision: const Value(1),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
  await db
      .into(db.cableRunTraversals)
      .insert(
        CableRunTraversalsCompanion.insert(
          id: 'traversal-1',
          cableRunId: 'run-1',
          sequence: 1,
          routeSegmentId: 'section-1',
          direction: 'FORWARD',
          revision: const Value(1),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa08-production',
        ),
      );
  await db.customStatement('PRAGMA foreign_keys = ON');
}

DateTime _now() => DateTime.utc(2026, 10, 17, 14);
String _hash(String char) => List<String>.filled(64, char).join();
