final class CatalogPreferences {
  const CatalogPreferences({
    this.recentIds = const [],
    this.favoriteIds = const {},
  });

  final List<String> recentIds;
  final Set<String> favoriteIds;
}

abstract interface class CatalogPreferencesRepository {
  Future<CatalogPreferences> load();
  Future<void> recordUse(String definitionId);
  Future<void> setFavorite(String definitionId, bool favorite);
}
