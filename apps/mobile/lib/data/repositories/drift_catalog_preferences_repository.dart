import 'package:drift/drift.dart';

import '../../application/catalog_preferences_repository.dart';
import '../database/app_database.dart';

final class DriftCatalogPreferencesRepository
    implements CatalogPreferencesRepository {
  DriftCatalogPreferencesRepository(this.database);

  final AppDatabase database;
  static const recentLimit = 8;

  void _validate(String id) {
    if (id.trim().isEmpty)
      throw ArgumentError('Definition id must be non-empty.');
  }

  @override
  Future<CatalogPreferences> load() async {
    final rows = await database
        .select(database.componentCatalogPreferences)
        .get();
    final recent = rows.where((row) => row.useOrder != null).toList()
      ..sort((a, b) => b.useOrder!.compareTo(a.useOrder!));
    return CatalogPreferences(
      recentIds: List.unmodifiable(
        recent.take(recentLimit).map((row) => row.definitionId),
      ),
      favoriteIds: Set.unmodifiable(
        rows.where((row) => row.favorite).map((row) => row.definitionId),
      ),
    );
  }

  @override
  Future<void> recordUse(String definitionId) async {
    _validate(definitionId);
    await database.transaction(() async {
      final rows = await database
          .select(database.componentCatalogPreferences)
          .get();
      final next =
          rows.fold<int>(
            0,
            (value, row) => (row.useOrder ?? 0) > value ? row.useOrder! : value,
          ) +
          1;
      await database
          .into(database.componentCatalogPreferences)
          .insert(
            ComponentCatalogPreferencesCompanion.insert(
              definitionId: definitionId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await (database.update(database.componentCatalogPreferences)
            ..where((row) => row.definitionId.equals(definitionId)))
          .write(ComponentCatalogPreferencesCompanion(useOrder: Value(next)));
      final ordered =
          await (database.select(database.componentCatalogPreferences)
                ..where((row) => row.useOrder.isNotNull())
                ..orderBy([(row) => OrderingTerm.desc(row.useOrder)]))
              .get();
      for (final row in ordered.skip(recentLimit)) {
        await (database.update(
          database.componentCatalogPreferences,
        )..where((item) => item.definitionId.equals(row.definitionId))).write(
          const ComponentCatalogPreferencesCompanion(useOrder: Value(null)),
        );
      }
    });
  }

  @override
  Future<void> setFavorite(String definitionId, bool favorite) async {
    _validate(definitionId);
    await database.transaction(() async {
      await database
          .into(database.componentCatalogPreferences)
          .insert(
            ComponentCatalogPreferencesCompanion.insert(
              definitionId: definitionId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await (database.update(
        database.componentCatalogPreferences,
      )..where((row) => row.definitionId.equals(definitionId))).write(
        ComponentCatalogPreferencesCompanion(favorite: Value(favorite)),
      );
    });
  }
}
