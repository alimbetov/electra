abstract interface class EditorCommand {
  void execute();

  void undo();
}

final class EditorCommandHistory {
  final List<EditorCommand> _undoStack = [];
  final List<EditorCommand> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void execute(EditorCommand command) {
    command.execute();
    _undoStack.add(command);
    _redoStack.clear();
  }

  void undo() {
    if (!canUndo) {
      return;
    }
    final command = _undoStack.removeLast();
    command.undo();
    _redoStack.add(command);
  }

  void redo() {
    if (!canRedo) {
      return;
    }
    final command = _redoStack.removeLast();
    command.execute();
    _undoStack.add(command);
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
