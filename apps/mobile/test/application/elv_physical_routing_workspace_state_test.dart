import 'package:electra_mobile/application/elv_physical_routing_workspace_state.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workspace is read only when no WORKING design revision exists', () {
    const context = PhysicalDesignContext(
      projectId: 'PRJ-1',
      workingDesignRevisionId: null,
      latestFrozenRevisionId: 'REV-1',
      editingAllowed: false,
    );
    const state = PhysicalRoutingWorkspaceState(
      projectId: 'PRJ-1',
      designContext: context,
      activeStage: PhysicalRoutingStage.route,
      canEdit: false,
    );
    expect(state.isReadOnly, isTrue);
    expect(state.designContext.latestFrozenRevisionId, 'REV-1');
  });
}
