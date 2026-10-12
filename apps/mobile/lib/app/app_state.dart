import 'package:flutter/foundation.dart';

import '../domain/models.dart';

class ElectraAppState extends ChangeNotifier {
  final List<ProjectDraft> _projects = [];

  List<ProjectDraft> get projects => List.unmodifiable(_projects);

  void addProject(ProjectDraft project) {
    _projects.add(project);
    notifyListeners();
  }

  void addRoom(String projectId, RoomDraft room) {
    final project = _projects.firstWhere((item) => item.id == projectId);
    project.rooms.add(room);
    notifyListeners();
  }
}
