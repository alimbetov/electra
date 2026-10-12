import 'package:electra_mobile/features/editor/editor_command_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('execute undo redo preserves deterministic command order', () {
    var value = 0;
    final history = EditorCommandHistory();

    history.execute(_DeltaCommand(() => value += 5, () => value -= 5));
    history.execute(_DeltaCommand(() => value += 3, () => value -= 3));

    expect(value, 8);
    expect(history.canUndo, isTrue);
    expect(history.canRedo, isFalse);

    history.undo();
    expect(value, 5);
    expect(history.canRedo, isTrue);

    history.undo();
    expect(value, 0);
    expect(history.canUndo, isFalse);

    history.redo();
    history.redo();
    expect(value, 8);
    expect(history.canRedo, isFalse);
  });

  test('executing a new command invalidates redo history', () {
    var value = 0;
    final history = EditorCommandHistory();

    history.execute(_DeltaCommand(() => value++, () => value--));
    history.undo();
    expect(history.canRedo, isTrue);

    history.execute(_DeltaCommand(() => value += 10, () => value -= 10));

    expect(value, 10);
    expect(history.canRedo, isFalse);
  });
}

final class _DeltaCommand implements EditorCommand {
  _DeltaCommand(this._execute, this._undo);

  final void Function() _execute;
  final void Function() _undo;

  @override
  void execute() => _execute();

  @override
  void undo() => _undo();
}
