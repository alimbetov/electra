import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/adaptive_layout.dart';
import '../../app/providers.dart';
import '../calculations/project_recalculation_screen.dart';
import '../calculations/protection_screen.dart';
import '../calculations/manufacturer_screen.dart';
import '../calculations/panel_generation_screen.dart';
import '../calculations/engineering_systems_screen.dart';

class ProjectWorkspaceScreen extends ConsumerWidget {
  const ProjectWorkspaceScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));
    final floors = ref.watch(floorsProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/projects'),
        ),
        title: project.when(
          data: (value) => Text(value?.name ?? 'Project'),
          loading: () => const Text('Project'),
          error: (_, __) => const Text('Project'),
        ),
      ),
      persistentFooterButtons: [
        OutlinedButton.icon(
          icon: const Icon(Icons.hub_outlined),
          label: const Text('Engineering systems'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EngineeringSystemsScreen(projectId: projectId),
            ),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.view_module_outlined),
          label: const Text('Generate panel'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PanelGenerationScreen(projectId: projectId),
            ),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Manufacturer catalogs'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ManufacturerScreen(projectId: projectId),
            ),
          ),
        ),

        OutlinedButton.icon(
          icon: const Icon(Icons.shield_outlined),
          label: const Text('Protection / Normatives'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProtectionScreen(projectId: projectId),
            ),
          ),
        ),

        OutlinedButton.icon(
          icon: const Icon(Icons.calculate),
          label: const Text('Recalculate / What changed?'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProjectRecalculationScreen(projectId: projectId),
            ),
          ),
        ),
      ],
      body: ElectraAdaptiveBuilder(
        builder: (context, layout) {
          final width = layout.isExpanded ? 1100.0 : 760.0;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: floors.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Unable to load floors: $error')),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('No floors yet. Add the first floor.'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final floor = items[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.layers_outlined),
                          title: Text(floor.name),
                          subtitle: Text(
                            floor.code.isEmpty
                                ? 'Order ${floor.sortOrder}'
                                : '${floor.code} · order ${floor.sortOrder}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go(
                            '/projects/$projectId/floors/${floor.id}',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/projects/$projectId/floors/new'),
        icon: const Icon(Icons.add),
        label: const Text('New floor'),
      ),
    );
  }
}
