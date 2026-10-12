import 'package:engineering_core/engineering_core.dart';

import 'component_instance_repository.dart';

/// Session history; each operation changes one persisted instance only.
final class ComponentPlacementHistory {
  ComponentPlacementHistory(this.repository);

  final ComponentInstanceRepository repository;
  final List<ComponentInstance> _undo = [];
  final List<ComponentInstance> _redo = [];
  bool _busy = false;

  bool get canUndo => !_busy && _undo.isNotEmpty;
  bool get canRedo => !_busy && _redo.isNotEmpty;

  void record(ComponentInstance instance) {
    if (_busy) throw StateError('History operation already in progress.');
    _undo.add(instance);
    _redo.clear();
  }

  Future<void> undo() async {
    if (!canUndo) return;
    _busy = true;
    try {
      final instance = _undo.last;
      await repository.removeComponent(instance.id);
      _undo.removeLast();
      _redo.add(instance);
    } finally {
      _busy = false;
    }
  }

  Future<void> redo() async {
    if (!canRedo) return;
    _busy = true;
    try {
      final instance = _redo.last;
      await repository.saveComponent(instance);
      _redo.removeLast();
      _undo.add(instance);
    } finally {
      _busy = false;
    }
  }
}
