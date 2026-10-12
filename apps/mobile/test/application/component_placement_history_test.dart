import 'package:electra_mobile/application/component_instance_repository.dart';
import 'package:electra_mobile/application/component_placement_history.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failed undo or redo preserves its history for retry', () async {
    final repository = _Repository();
    final history = ComponentPlacementHistory(repository);
    const instance = ComponentInstance(
      id: 'one',
      definitionId: 'socket',
      definitionVersion: 1,
      roomId: 'room',
      hostSurfacePatchId: 'wall',
      localPosition: Point2Mm(1, 2),
    );
    history.record(instance);
    repository.fail = true;
    await expectLater(history.undo(), throwsStateError);
    expect(history.canUndo, isTrue);
    expect(history.canRedo, isFalse);
    repository.fail = false;
    await history.undo();
    repository.fail = true;
    await expectLater(history.redo(), throwsStateError);
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isTrue);
    repository.fail = false;
    await history.redo();
    expect(history.canUndo, isTrue);
  });
}

final class _Repository implements ComponentInstanceRepository {
  bool fail = false;
  @override
  Future<void> removeComponent(String instanceId) async {
    if (fail) throw StateError('disk failure');
  }

  @override
  Future<void> saveComponent(ComponentInstance instance) async {
    if (fail) throw StateError('disk failure');
  }

  @override
  Future<List<ComponentInstance>> loadRoomComponents(String roomId) async => [];
  @override
  Stream<List<ComponentInstance>> watchRoomComponents(String roomId) =>
      const Stream.empty();
  @override
  Future<void> replaceRoomComponents({
    required String roomId,
    required Iterable<ComponentInstance> instances,
  }) async {}
}
