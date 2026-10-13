import 'package:engineering_core/engineering_core.dart';

import 'component_instance_repository.dart';
import 'engineering_placement_repository.dart';

/// Session history; each operation changes one persisted instance only.
final class ComponentPlacementHistory {
  ComponentPlacementHistory(this.repository);

  final ComponentInstanceRepository repository;
  final List<_PlacementAction> _undo = [];
  final List<_PlacementAction> _redo = [];
  final Set<String> _engineeringOperations = {};
  bool _busy = false;

  bool get canUndo => !_busy && _undo.isNotEmpty;
  bool get canRedo => !_busy && _redo.isNotEmpty;

  void record(ComponentInstance instance) {
    if (_busy) throw StateError('History operation already in progress.');
    _undo.add(
      _PlacementAction(
        () => repository.removeComponent(instance.id),
        () => repository.saveComponent(instance),
      ),
    );
    _redo.clear();
  }

  void recordEngineering(
    EngineeringPlacementHistoryEntry entry,
    EngineeringPlacementRepository engineering,
  ) {
    if (_busy) throw StateError('History operation already in progress.');
    if (!_engineeringOperations.add(entry.result.operationId)) return;
    _undo.add(
      _PlacementAction(
        () => engineering.undo(entry.result.operationId),
        () => engineering.redo(entry),
      ),
    );
    _redo.clear();
  }

  Future<void> undo() async {
    if (!canUndo) return;
    _busy = true;
    try {
      final instance = _undo.last;
      await instance.undo();
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
      await instance.redo();
      _redo.removeLast();
      _undo.add(instance);
    } finally {
      _busy = false;
    }
  }
}

final class _PlacementAction {
  const _PlacementAction(this.undo, this.redo);
  final Future<void> Function() undo, redo;
}
