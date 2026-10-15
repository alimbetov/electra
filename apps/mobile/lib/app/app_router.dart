import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/editor/persisted_room_editor_screen.dart';
import '../features/floors/floor_create_screen.dart';
import '../features/floors/floor_workspace_screen.dart';
import '../features/projects/project_create_screen.dart';
import '../features/projects/project_list_screen.dart';
import '../features/projects/project_workspace_screen.dart';
import '../features/rooms/room_create_screen.dart';

GoRouter createElectraRouter() => GoRouter(
  initialLocation: '/projects',
  routes: [
    GoRoute(
      path: '/projects',
      builder: (context, state) => const ProjectListScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => const ProjectCreateScreen(),
        ),
        GoRoute(
          path: ':projectId',
          builder: (context, state) => ProjectWorkspaceScreen(
            projectId: state.pathParameters['projectId']!,
          ),
          routes: [
            GoRoute(
              path: 'floors/new',
              builder: (context, state) => FloorCreateScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'floors/:floorId',
              builder: (context, state) => FloorWorkspaceScreen(
                projectId: state.pathParameters['projectId']!,
                floorId: state.pathParameters['floorId']!,
              ),
              routes: [
                GoRoute(
                  path: 'rooms/new',
                  builder: (context, state) => RoomCreateScreen(
                    projectId: state.pathParameters['projectId']!,
                    floorId: state.pathParameters['floorId']!,
                  ),
                ),
                GoRoute(
                  path: 'rooms/:roomId',
                  builder: (context, state) => PersistedRoomEditorScreen(
                    projectId: state.pathParameters['projectId']!,
                    floorId: state.pathParameters['floorId']!,
                    roomId: state.pathParameters['roomId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('Navigation error: ${state.error}'))),
);
