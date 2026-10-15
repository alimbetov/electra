import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';

class ComponentCatalogSheet extends StatefulWidget {
  const ComponentCatalogSheet({
    super.key,
    required this.definitions,
    this.recentDefinitionIds = const [],
    this.favoriteDefinitionIds = const {},
    this.onSetFavorite,
  });

  final List<ComponentDefinition> definitions;
  final List<String> recentDefinitionIds;
  final Set<String> favoriteDefinitionIds;
  final Future<void> Function(String id, bool favorite)? onSetFavorite;

  static Future<ComponentDefinition?> show(
    BuildContext context, {
    required List<ComponentDefinition> definitions,
    List<String> recentDefinitionIds = const [],
    Set<String> favoriteDefinitionIds = const {},
    Future<void> Function(String id, bool favorite)? onSetFavorite,
  }) {
    return showModalBottomSheet<ComponentDefinition>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (context) => FractionallySizedBox(
            heightFactor: 0.78,
            child: ComponentCatalogSheet(
              definitions: definitions,
              recentDefinitionIds: recentDefinitionIds,
              favoriteDefinitionIds: favoriteDefinitionIds,
              onSetFavorite: onSetFavorite,
            ),
          ),
    );
  }

  @override
  State<ComponentCatalogSheet> createState() => _ComponentCatalogSheetState();
}

class _ComponentCatalogSheetState extends State<ComponentCatalogSheet> {
  var query = '';
  late final favorites = {...widget.favoriteDefinitionIds};
  bool savingFavorite = false;

  Future<void> toggleFavorite(String id) async {
    if (savingFavorite || widget.onSetFavorite == null) return;
    final favorite = !favorites.contains(id);
    setState(() => savingFavorite = true);
    try {
      await widget.onSetFavorite!(id, favorite);
      if (!mounted) return;
      setState(() {
        if (favorite) {
          favorites.add(id);
        } else {
          favorites.remove(id);
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save favorite: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => savingFavorite = false);
    }
  }

  _CatalogScope scope = _CatalogScope.system;

  List<ComponentDefinition> get visibleDefinitions {
    Iterable<ComponentDefinition> values = widget.definitions;
    switch (scope) {
      case _CatalogScope.system:
        values = values.where(
          (definition) => definition.source == ComponentDefinitionSource.system,
        );
      case _CatalogScope.recent:
        final order = {
          for (
            var index = 0;
            index < widget.recentDefinitionIds.length;
            index++
          )
            widget.recentDefinitionIds[index]: index,
        };
        values = values.where((definition) => order.containsKey(definition.id));
        final list = values.toList(growable: false)
          ..sort((a, b) => order[a.id]!.compareTo(order[b.id]!));
        values = list;
      case _CatalogScope.favorites:
        values = values.where(
          (definition) => favorites.contains(definition.id),
        );
    }

    final normalized = query.trim().toLowerCase();
    if (normalized.isNotEmpty) {
      values = values.where((definition) {
        return definition.displayName.toLowerCase().contains(normalized) ||
            definition.code.toLowerCase().contains(normalized) ||
            definition.category.toLowerCase().contains(normalized);
      });
    }
    return values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final definitions = visibleDefinitions;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Component catalog',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SearchBar(
              hintText: 'Search components',
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_CatalogScope>(
                segments: const [
                  ButtonSegment(
                    value: _CatalogScope.system,
                    label: Text('System'),
                    icon: Icon(Icons.electrical_services),
                  ),
                  ButtonSegment(
                    value: _CatalogScope.recent,
                    label: Text('Recent'),
                    icon: Icon(Icons.history),
                  ),
                  ButtonSegment(
                    value: _CatalogScope.favorites,
                    label: Text('Favorites'),
                    icon: Icon(Icons.star_outline),
                  ),
                ],
                selected: {scope},
                onSelectionChanged:
                    (value) => setState(() => scope = value.single),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  definitions.isEmpty
                      ? const Center(child: Text('No matching components'))
                      : ListView.separated(
                        itemCount: definitions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final definition = definitions[index];
                          return ListTile(
                            leading: _CatalogSymbol(
                              category: definition.category,
                            ),
                            title: Text(definition.displayName),
                            subtitle: Text(
                              '${definition.code} · ${definition.category}',
                            ),
                            trailing: IconButton(
                              tooltip:
                                  favorites.contains(definition.id)
                                      ? 'Remove favorite'
                                      : 'Add favorite',
                              icon: Icon(
                                favorites.contains(definition.id)
                                    ? Icons.star
                                    : Icons.star_outline,
                              ),
                              onPressed:
                                  savingFavorite || widget.onSetFavorite == null
                                      ? null
                                      : () => toggleFavorite(definition.id),
                            ),
                            onTap: () => Navigator.of(context).pop(definition),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CatalogScope { system, recent, favorites }

class _CatalogSymbol extends StatelessWidget {
  const _CatalogSymbol({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final icon = switch (category) {
      'SOCKET' => Icons.power,
      'SWITCH' => Icons.toggle_on_outlined,
      'LIGHTING' => Icons.lightbulb_outline,
      'JUNCTION_BOX' => Icons.hub_outlined,
      'DISTRIBUTION' => Icons.view_module_outlined,
      'MOTOR' => Icons.settings_outlined,
      'VARIABLE_FREQUENCY_DRIVE' => Icons.speed_outlined,
      _ => Icons.electrical_services,
    };
    return SizedBox.square(
      dimension: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }
}
