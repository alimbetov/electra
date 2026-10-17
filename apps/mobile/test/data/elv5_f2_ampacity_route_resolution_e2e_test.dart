import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/environment/ampacity_route_resolver.dart';
import 'package:electra_mobile/application/elv5/environment/ampacity_section_contract.dart';
import 'package:electra_mobile/application/elv5/environment/environment_profile_persistence.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_cable_run_repository.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_ampacity_section_contract_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_environment_profile_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_environment_scope_resolver.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'F2 AMPACITY_ROUTE_IZ resolves persisted route, fails closed on environment drift and survives restart/freeze',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'electra-f2-ampacity-route-e2e-',
      );
      final file = File('${directory.path}/qualification.sqlite');
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      var db = AppDatabase(NativeDatabase(file));
      await _seedTopology(db);
      var environmentStore = _environmentStore(db);
      var ampacityStore = _ampacityStore(db);

      // Q6: persist the environment basis used by the real route resolver.
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
      final normalEnvironment = await _activeRoomEnvironment(environmentStore);

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

      var resolver = _resolver(
        db: db,
        environmentStore: environmentStore,
        ampacityStore: ampacityStore,
      );
      final firstInput = await resolver.resolve(
        projectId: 'p',
        designRevisionId: 'd',
        cableRunId: 'run-1',
      );
      final first = const Elv5RouteAmpacityKernel().evaluate(firstInput);
      expect(first.governingSectionId, 'section-1');
      expect(first.allowableCurrentIzA, Elv5Rational.integer(27));
      expect(first.sections.single.profileEditionId, 'env-normal');
      expect(
        first.sections.single.maximumAmbientTemperatureC,
        Elv5Rational.integer(40),
      );

      // Q6 invalidation witness: changing the active environment edition makes
      // the old ampacity evidence unusable immediately. The resolver must not
      // silently reuse the previous correction factors.
      await environmentStore.replace(
        ReplaceElv5EnvironmentProfileCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 3,
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

      await expectLater(
        resolver.resolve(
          projectId: 'p',
          designRevisionId: 'd',
          cableRunId: 'run-1',
        ),
        throwsA(
          isA<Elv5AmpacityRouteResolutionException>().having(
            (error) => error.code,
            'code',
            'ELV5_AMPACITY_SECTION_ENVIRONMENT_IDENTITY_MISMATCH',
          ),
        ),
      );

      // Republishing exact section evidence against the new environment basis
      // restores calculability and produces a new deterministic Iz.
      final hotEnvironment = await _activeRoomEnvironment(environmentStore);
      await ampacityStore.replace(
        ReplaceElv5AmpacitySectionContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 4,
          bindingId: 'ampacity-section',
          expectedBindingRevision: 1,
          contract: _ampacityContract(
            environment: hotEnvironment,
            factor: '0.70',
            evidenceSeed: 'd',
          ),
        ),
      );

      final secondInput = await resolver.resolve(
        projectId: 'p',
        designRevisionId: 'd',
        cableRunId: 'run-1',
      );
      final second = const Elv5RouteAmpacityKernel().evaluate(secondInput);
      expect(second.governingSectionId, 'section-1');
      expect(second.allowableCurrentIzA, Elv5Rational.integer(21));
      expect(second.sections.single.profileEditionId, 'env-hot');
      expect(
        second.sections.single.maximumAmbientTemperatureC,
        Elv5Rational.integer(45),
      );
      final canonicalBeforeRestart = second.toCanonicalValue();

      // Q7/Q8 restart witness: reconstruct every production dependency from the
      // same durable SQLite file rather than retaining in-memory fixture state.
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      environmentStore = _environmentStore(db);
      ampacityStore = _ampacityStore(db);
      resolver = _resolver(
        db: db,
        environmentStore: environmentStore,
        ampacityStore: ampacityStore,
      );

      final restartedInput = await resolver.resolve(
        projectId: 'p',
        designRevisionId: 'd',
        cableRunId: 'run-1',
      );
      final restarted = const Elv5RouteAmpacityKernel().evaluate(
        restartedInput,
      );
      expect(restarted.toCanonicalValue(), canonicalBeforeRestart);

      // Q8: historical reads remain reproducible after freeze while both source
      // contracts become immutable.
      await db.customUpdate(
        "UPDATE project_design_revisions SET state = 'FROZEN' "
        "WHERE project_id = 'p' AND id = 'd'",
      );
      final frozenInput = await resolver.resolve(
        projectId: 'p',
        designRevisionId: 'd',
        cableRunId: 'run-1',
      );
      final frozen = const Elv5RouteAmpacityKernel().evaluate(frozenInput);
      expect(frozen.toCanonicalValue(), canonicalBeforeRestart);

      await expectLater(
        environmentStore.replace(
          ReplaceElv5EnvironmentProfileCommand(
            projectId: 'p',
            designRevisionId: 'd',
            expectedDesignRevision: 5,
            bindingId: 'env-room',
            expectedBindingRevision: 2,
            scopeKind: 'ROOM',
            scopeId: 'room-1',
            profile: _environment(
              editionId: 'env-forbidden',
              maximumTemperatureC: '50',
              evidenceSeed: 'e',
            ),
          ),
        ),
        throwsStateError,
      );
      await expectLater(
        ampacityStore.replace(
          ReplaceElv5AmpacitySectionContractCommand(
            projectId: 'p',
            designRevisionId: 'd',
            expectedDesignRevision: 5,
            bindingId: 'ampacity-section',
            expectedBindingRevision: 2,
            contract: _ampacityContract(
              environment: hotEnvironment,
              factor: '0.60',
              evidenceSeed: 'f',
            ),
          ),
        ),
        throwsStateError,
      );

      await db.close();
    },
  );
}

DriftElv5EnvironmentProfileStore _environmentStore(AppDatabase db) =>
    DriftElv5EnvironmentProfileStore(
      db,
      originDeviceId: 'f2-ampacity-e2e',
      nowUtc: () => DateTime.utc(2026, 10, 17, 13),
    );

DriftElv5AmpacitySectionContractStore _ampacityStore(AppDatabase db) =>
    DriftElv5AmpacitySectionContractStore(
      db,
      originDeviceId: 'f2-ampacity-e2e',
      nowUtc: () => DateTime.utc(2026, 10, 17, 13),
    );

Elv5AmpacityRouteResolver _resolver({
  required AppDatabase db,
  required DriftElv5EnvironmentProfileStore environmentStore,
  required DriftElv5AmpacitySectionContractStore ampacityStore,
}) => Elv5AmpacityRouteResolver(
  cableRuns: DriftElvCableRunRepository(db, originDeviceId: 'f2-ampacity-e2e'),
  environments: DriftElv5EnvironmentScopeResolver(
    database: db,
    profileSource: environmentStore,
  ),
  sectionEvidence: ampacityStore,
);

Future<Elv5EnvironmentProfileSnapshot> _activeRoomEnvironment(
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
    insulationSystemCode: 'PVC70',
    referenceAmbientTemperatureC: Elv5Rational.integer(30),
    installationMethodCode: 'B2',
    loadedConductors: 3,
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

Future<void> _seedTopology(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  final now = DateTime.utc(2026, 10, 17, 12);

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
          originDeviceId: 'seed',
        ),
      );
  await db.customStatement(
    "INSERT INTO rooms (id,floor_id,name,room_type,room_category,width_mm,depth_mm,structural_height_mm_override,finished_ceiling_height_mm_override,revision,created_at,updated_at,deleted_at,origin_device_id) "
    "VALUES ('room-1','floor-x','Electrical room','technical','technical',4000,4000,NULL,NULL,1,'${now.toIso8601String()}','${now.toIso8601String()}',NULL,'seed')",
  );
  await db.customStatement(
    "INSERT INTO cable_routes (id,room_id,name,revision,created_at,updated_at,deleted_at,origin_device_id) "
    "VALUES ('route-1','room-1','Main route',1,'${now.toIso8601String()}','${now.toIso8601String()}',NULL,'seed')",
  );
  await db.customStatement(
    "INSERT INTO cable_route_segments (id,route_id,sequence,from_node_id,to_node_id,surface_patch_id,laying_method,physical_channel_id,revision,created_at,updated_at,deleted_at,origin_device_id) "
    "VALUES ('section-1','route-1',1,'node-a','node-b','patch-x','TRAY',NULL,1,'${now.toIso8601String()}','${now.toIso8601String()}',NULL,'seed')",
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
          revision: const Value(1),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'seed',
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
          originDeviceId: 'seed',
        ),
      );
  await db.customStatement('PRAGMA foreign_keys = ON');
}

String _hash(String char) => List<String>.filled(64, char).join();
