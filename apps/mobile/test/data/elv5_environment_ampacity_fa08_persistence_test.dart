import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/environment/ampacity_section_contract.dart';
import 'package:electra_mobile/application/elv5/environment/environment_profile_persistence.dart';
import 'package:electra_mobile/application/elv5/fire/fa08_policy_contract.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_ampacity_section_contract_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_environment_profile_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_environment_scope_resolver.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa08_policy_contract_store.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ROOM environment replacement is immutable and CAS guarded', () async {
    final db = await _database();
    addTearDown(db.close);
    final store = DriftElv5EnvironmentProfileStore(
      db,
      originDeviceId: 'test',
      nowUtc: _now,
    );

    await store.replace(
      ReplaceElv5EnvironmentProfileCommand(
        projectId: 'p',
        designRevisionId: 'd',
        expectedDesignRevision: 1,
        bindingId: 'env-room',
        expectedBindingRevision: null,
        scopeKind: 'ROOM',
        scopeId: 'room-1',
        profile: _environment('room-v1', '30'),
      ),
    );
    final v1 = await store.loadActiveForScope(
      projectId: 'p',
      designRevisionId: 'd',
      scopeKind: 'ROOM',
      scopeId: 'room-1',
    );
    expect(v1, isNotNull);
    expect(v1!.bindingRevision, 1);
    expect(v1.profile.temperatureC.maximum, Elv5Rational.integer(30));

    await store.replace(
      ReplaceElv5EnvironmentProfileCommand(
        projectId: 'p',
        designRevisionId: 'd',
        expectedDesignRevision: 2,
        bindingId: 'env-room',
        expectedBindingRevision: 1,
        scopeKind: 'ROOM',
        scopeId: 'room-1',
        profile: _environment('room-v2', '40'),
      ),
    );
    final v2 = await store.loadActiveForScope(
      projectId: 'p',
      designRevisionId: 'd',
      scopeKind: 'ROOM',
      scopeId: 'room-1',
    );
    expect(v2!.bindingRevision, 2);
    expect(v2.profile.temperatureC.maximum, Elv5Rational.integer(40));
    expect(
      await _count(
        db,
        'elv_revision_aggregate_evidence_records',
        "aggregate_kind = 'ELV5_ENVIRONMENT_PROFILE'",
      ),
      2,
    );

    await expectLater(
      store.replace(
        ReplaceElv5EnvironmentProfileCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 2,
          bindingId: 'env-room',
          expectedBindingRevision: 1,
          scopeKind: 'ROOM',
          scopeId: 'room-1',
          profile: _environment('stale', '50'),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('ROUTE_SECTION environment overrides ROOM profile', () async {
    final db = await _database(withRoute: true);
    addTearDown(db.close);
    final store = DriftElv5EnvironmentProfileStore(
      db,
      originDeviceId: 'test',
      nowUtc: _now,
    );
    final resolver = DriftElv5EnvironmentScopeResolver(
      database: db,
      profileSource: store,
    );

    await store.replace(
      ReplaceElv5EnvironmentProfileCommand(
        projectId: 'p',
        designRevisionId: 'd',
        expectedDesignRevision: 1,
        bindingId: 'env-room',
        expectedBindingRevision: null,
        scopeKind: 'ROOM',
        scopeId: 'room-1',
        profile: _environment('room', '30'),
      ),
    );
    final inherited = await resolver.resolveForRouteSection(
      projectId: 'p',
      designRevisionId: 'd',
      routeSectionId: 'section-1',
    );
    expect(inherited!.usedSectionOverride, isFalse);
    expect(
      inherited.binding.profile.temperatureC.maximum,
      Elv5Rational.integer(30),
    );

    await store.replace(
      ReplaceElv5EnvironmentProfileCommand(
        projectId: 'p',
        designRevisionId: 'd',
        expectedDesignRevision: 2,
        bindingId: 'env-section',
        expectedBindingRevision: null,
        scopeKind: 'ROUTE_SECTION',
        scopeId: 'section-1',
        profile: _environment('shaft', '45'),
      ),
    );
    final overridden = await resolver.resolveForRouteSection(
      projectId: 'p',
      designRevisionId: 'd',
      routeSectionId: 'section-1',
    );
    expect(overridden!.usedSectionOverride, isTrue);
    expect(overridden.binding.scopeKind, 'ROUTE_SECTION');
    expect(
      overridden.binding.profile.temperatureC.maximum,
      Elv5Rational.integer(45),
    );
  });

  test(
    'ampacity section editions are immutable and binding CAS guarded',
    () async {
      final db = await _database();
      addTearDown(db.close);
      final store = DriftElv5AmpacitySectionContractStore(
        db,
        originDeviceId: 'test',
        nowUtc: _now,
      );

      await store.replace(
        ReplaceElv5AmpacitySectionContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 1,
          bindingId: 'ampacity-section',
          expectedBindingRevision: null,
          contract: _ampacity('env-hash-1', '1.0'),
        ),
      );
      final v1 = await store.loadActiveForSection(
        projectId: 'p',
        designRevisionId: 'd',
        routeSectionId: 'section-1',
      );
      expect(v1!.bindingRevision, 1);

      await store.replace(
        ReplaceElv5AmpacitySectionContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 2,
          bindingId: 'ampacity-section',
          expectedBindingRevision: 1,
          contract: _ampacity('env-hash-2', '0.8'),
        ),
      );
      final v2 = await store.loadActiveForSection(
        projectId: 'p',
        designRevisionId: 'd',
        routeSectionId: 'section-1',
      );
      expect(v2!.bindingRevision, 2);
      expect(
        v2.contract.temperatureCorrection.factor,
        Elv5Rational.parseDecimal('0.8'),
      );
      expect(
        await _count(
          db,
          'elv_revision_aggregate_evidence_records',
          "aggregate_kind = 'ELV5_AMPACITY_SECTION_CONTRACT'",
        ),
        2,
      );

      await expectLater(
        store.replace(
          ReplaceElv5AmpacitySectionContractCommand(
            projectId: 'p',
            designRevisionId: 'd',
            expectedDesignRevision: 3,
            bindingId: 'ampacity-section',
            expectedBindingRevision: 1,
            contract: _ampacity('env-hash-3', '0.7'),
          ),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('FA-08 policy editions are immutable and CAS guarded', () async {
    final db = await _database();
    addTearDown(db.close);
    final store = DriftFa08CablePolicyContractStore(
      db,
      originDeviceId: 'test',
      nowUtc: _now,
    );

    await store.replace(
      ReplaceFa08CablePolicyContractCommand(
        projectId: 'p',
        designRevisionId: 'd',
        expectedDesignRevision: 1,
        bindingId: 'fa08-policy',
        expectedBindingRevision: null,
        contract: _policy('20'),
      ),
    );
    final v1 = await store.loadActiveForCableRun(
      projectId: 'p',
      designRevisionId: 'd',
      cableRunId: 'run-1',
    );
    expect(v1!.bindingRevision, 1);

    await store.replace(
      ReplaceFa08CablePolicyContractCommand(
        projectId: 'p',
        designRevisionId: 'd',
        expectedDesignRevision: 2,
        bindingId: 'fa08-policy',
        expectedBindingRevision: 1,
        contract: _policy('25'),
      ),
    );
    final v2 = await store.loadActiveForCableRun(
      projectId: 'p',
      designRevisionId: 'd',
      cableRunId: 'run-1',
    );
    expect(v2!.bindingRevision, 2);
    expect(
      v2.contract.policy.requirements.single.threshold,
      Elv5Rational.integer(25),
    );
    expect(
      await _count(
        db,
        'elv_revision_aggregate_evidence_records',
        "aggregate_kind = 'FA08_CABLE_POLICY_CONTRACT'",
      ),
      2,
    );

    await expectLater(
      store.replace(
        ReplaceFa08CablePolicyContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 3,
          bindingId: 'fa08-policy',
          expectedBindingRevision: 1,
          contract: _policy('30'),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

Future<AppDatabase> _database({bool withRoute = false}) async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.customStatement('PRAGMA foreign_keys = OFF');
  final now = _now().toIso8601String();
  await db.customStatement(
    "INSERT INTO projects (id,name,reference,measurement_system,default_structural_height_mm,default_finished_ceiling_height_mm,revision,created_at,updated_at,deleted_at,origin_device_id) VALUES ('p','P','','metric',3000,2700,1,'$now','$now',NULL,'test')",
  );
  await db.customStatement(
    "INSERT INTO project_design_revisions (id,project_id,code,sequence,state,based_on_revision_id,snapshot_schema_version,snapshot_hash,revision,created_at,updated_at,deleted_at,origin_device_id) VALUES ('d','p','R1',1,'WORKING',NULL,NULL,NULL,1,'$now','$now',NULL,'test')",
  );
  if (withRoute) {
    await db.customStatement(
      "INSERT INTO rooms (id,floor_id,name,room_type,room_category,width_mm,depth_mm,structural_height_mm_override,finished_ceiling_height_mm_override,revision,created_at,updated_at,deleted_at,origin_device_id) VALUES ('room-1','floor-x','Room','technical','technical',4000,4000,NULL,NULL,1,'$now','$now',NULL,'test')",
    );
    await db.customStatement(
      "INSERT INTO cable_routes (id,room_id,name,revision,created_at,updated_at,deleted_at,origin_device_id) VALUES ('route-1','room-1','Route',1,'$now','$now',NULL,'test')",
    );
    await db.customStatement(
      "INSERT INTO cable_route_segments (id,route_id,sequence,from_node_id,to_node_id,surface_patch_id,laying_method,physical_channel_id,revision,created_at,updated_at,deleted_at,origin_device_id) VALUES ('section-1','route-1',1,'node-a','node-b','patch-x','TRAY',NULL,1,'$now','$now',NULL,'test')",
    );
  }
  return db;
}

Elv5EnvironmentProfile _environment(String edition, String maxC) =>
    Elv5EnvironmentProfile(
      profileId: 'ENV',
      editionId: edition,
      profileCode: 'ENV',
      temperatureC: Elv5RationalRange(
        minimum: Elv5Rational.integer(10),
        maximum: Elv5Rational.parseDecimal(maxC),
      ),
      relativeHumidityPercent: Elv5RationalRange(
        minimum: Elv5Rational.integer(20),
        maximum: Elv5Rational.integer(80),
      ),
      condensationRisk: Elv5CondensationRisk.none,
      exposure: Elv5EnvironmentExposure.indoor,
      evidenceRef: 'ENV:$edition',
      evidenceContentHash: _hash('a'),
    );

Elv5AmpacitySectionContract _ampacity(String environmentSeed, String factor) =>
    Elv5AmpacitySectionContract(
      routeSectionId: 'section-1',
      cableRunId: 'run-1',
      cableId: 'cable-1',
      expectedEnvironmentProfileId: 'ENV',
      expectedEnvironmentEditionId: environmentSeed,
      expectedEnvironmentContentHash: _hash(
        environmentSeed.codeUnitAt(0).isEven ? 'e' : 'f',
      ),
      referenceRow: Elv5AmpacityReferenceRow(
        conductorCrossSectionMm2: Elv5Rational.parseDecimal('2.5'),
        conductorMaterialCode: 'CU',
        insulationSystemCode: 'PVC70',
        referenceAmbientTemperatureC: Elv5Rational.integer(30),
        installationMethodCode: 'B2',
        loadedConductors: 3,
        baseAllowableCurrentA: Elv5Rational.integer(30),
        evidenceRef: 'ROW',
        evidenceContentHash: _hash('b'),
      ),
      temperatureCorrection: Elv5AmpacityTemperatureCorrection(
        actualAmbientTemperatureC: Elv5Rational.integer(40),
        factor: Elv5Rational.parseDecimal(factor),
        evidenceRef: 'TEMP:$factor',
        evidenceContentHash: _hash('c'),
      ),
      groupingCorrection: Elv5AmpacityGroupingCorrection(
        groupedCableOrCircuitCount: 1,
        arrangementCode: 'SINGLE',
        factor: Elv5Rational.one,
        evidenceRef: 'GROUP:1',
        evidenceContentHash: _hash('d'),
      ),
    );

Fa08CablePolicyContract _policy(String minimumIz) => Fa08CablePolicyContract(
  cableRunId: 'run-1',
  policyId: 'fire-cable-policy',
  requirements: <Fa08Requirement>[
    Fa08Requirement.numeric(
      code: 'MIN_IZ',
      kind: Fa08RequirementKind.numericMinimum,
      propertyCode: Fa08RouteSection.ampacityIzPropertyCode,
      unitCode: 'A',
      threshold: Elv5Rational.parseDecimal(minimumIz),
    ),
  ],
);

Future<int> _count(AppDatabase db, String table, String where) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM $table WHERE $where')
      .getSingle();
  return row.read<int>('c');
}

DateTime _now() => DateTime.utc(2026, 10, 17, 10);
String _hash(String char) => List<String>.filled(64, char).join();
