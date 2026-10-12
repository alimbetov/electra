import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/adaptive_layout.dart';
import '../../app/providers.dart';

class FloorWorkspaceScreen extends ConsumerWidget {
  const FloorWorkspaceScreen({
    super.key,
    required this.projectId,
    required this.floorId,
  });

  final String projectId;
  final String floorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floor = ref.watch(floorProvider(floorId));
    final rooms = ref.watch(roomsProvider(floorId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/projects/$projectId'),
        ),
        title: floor.when(
          data: (value) => Text(value?.name ?? 'Floor'),
          loading: () => const Text('Floor'),
          error: (_, __) => const Text('Floor'),
        ),
      ),
      body: ElectraAdaptiveBuilder(
        builder: (context, layout) {
          final width = layout.isExpanded ? 1100.0 : 760.0;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: rooms.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, _) =>
                        Center(child: Text('Unable to load rooms: $error')),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('No rooms yet. Add the first room.'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final room = items[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.crop_square_outlined),
                          title: Text(room.name),
                          subtitle: Text(
                            '${room.type.name} · ${room.category.name} · '
                            '${room.widthMm} × ${room.depthMm} mm',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap:
                              () => context.go(
                                '/projects/$projectId/floors/$floorId/'
                                'rooms/${room.id}',
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
        onPressed:
            () => context.go('/projects/$projectId/floors/$floorId/rooms/new'),
        icon: const Icon(Icons.add),
        label: const Text('New room'),
      ),
    );
  }
}
