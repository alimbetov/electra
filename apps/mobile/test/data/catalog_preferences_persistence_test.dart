import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_catalog_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'favorites and bounded deduplicated recents survive SQLite reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'electra-catalog-',
      );
      final file = File('${directory.path}/catalog.sqlite');
      var database = AppDatabase(NativeDatabase(file));
      var repository = DriftCatalogPreferencesRepository(database);
      await repository.setFavorite('component-0', true);
      for (var i = 0; i < 10; i++) {
        await repository.recordUse('component-$i');
      }
      await repository.recordUse('component-5');
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      repository = DriftCatalogPreferencesRepository(database);
      final preferences = await repository.load();
      expect(preferences.favoriteIds, {'component-0'});
      expect(preferences.recentIds, [
        'component-5',
        'component-9',
        'component-8',
        'component-7',
        'component-6',
        'component-4',
        'component-3',
        'component-2',
      ]);
      await repository.setFavorite('component-0', false);
      expect((await repository.load()).favoriteIds, isEmpty);
      expect((await repository.load()).recentIds, preferences.recentIds);
      await database.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'v3 migration creates preferences without changing component rows',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'electra-catalog-migration-',
      );
      final file = File('${directory.path}/catalog.sqlite');
      var database = AppDatabase(NativeDatabase(file));
      await database.customSelect('SELECT 1').get();
      await database.customStatement('DROP TABLE panel_generation_configs');
      await database.customStatement('DROP TABLE circuit_product_selections');
      await database.customStatement('DROP TABLE manufacturer_policies');
      await database.customStatement('DROP TABLE manufacturer_products');
      await database.customStatement('DROP TABLE manufacturer_catalogs');
      await database.customStatement('DROP TABLE circuit_protection_settings');
      await database.customStatement('DROP TABLE protection_rulesets');
      await database.customStatement('DROP TABLE normative_documents');
      await database.customStatement('DROP TABLE project_derived_results');
      await database.customStatement('DROP TABLE floor_panel_feeds');
      await database.customStatement('DROP TABLE floor_routing_handoffs');
      await database.customStatement('DROP TABLE floor_routing_panels');
      await database.customStatement('DROP TABLE junction_connections');
      await database.customStatement('DROP TABLE routing_junctions');
      await database.customStatement('DROP TABLE cable_runs');
      await database.customStatement('DROP TABLE cable_route_segments');
      await database.customStatement('DROP TABLE cable_route_nodes');
      await database.customStatement('DROP TABLE cable_routes');
      await database.customStatement('DROP TABLE physical_channels');
      await database.customStatement('DROP TABLE circuit_load_assignments');
      await database.customStatement('DROP TABLE electrical_circuits');
      await database.customStatement('DROP TABLE equipment_electrical_loads');
      await database.customStatement('DROP TABLE consumption_groups');
      await database.customStatement(
        'DROP TABLE component_catalog_preferences',
      );
      await database.customStatement('PRAGMA user_version = 3');
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      final repository = DriftCatalogPreferencesRepository(database);
      expect((await repository.load()).recentIds, isEmpty);
      await repository.setFavorite('socket', true);
      expect((await repository.load()).favoriteIds, {'socket'});
      expect(await database.select(database.componentInstances).get(), isEmpty);
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
