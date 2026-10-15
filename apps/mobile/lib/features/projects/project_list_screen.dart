import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/adaptive_layout.dart';
import '../../app/providers.dart';

class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: ElectraAdaptiveBuilder(
        builder: (context, layout) {
          final horizontalPadding = layout.isCompact ? 16.0 : 24.0;
          final maxWidth = layout.isExpanded ? 1100.0 : 760.0;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: projects.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Center(child: Text('Unable to load projects: $error')),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'No local projects yet. Create the first engineering project.',
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.all(horizontalPadding),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final project = items[index];
                      return Card(
                        child: ListTile(
                          title: Text(project.name),
                          subtitle: Text(
                            '${project.reference.isEmpty ? 'No reference' : project.reference} · '
                            '${project.measurementSystem.name.toUpperCase()}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/projects/${project.id}'),
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
        onPressed: () => context.go('/projects/new'),
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
    );
  }
}
