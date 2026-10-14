import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('allocation lifecycle allows only forward P2 transitions', () {
    expect(
      CableAllocationStateMachine.canTransition(
        CableAllocationState.draft,
        CableAllocationState.reserved,
      ),
      isTrue,
    );
    expect(
      CableAllocationStateMachine.canTransition(
        CableAllocationState.reserved,
        CableAllocationState.active,
      ),
      isTrue,
    );
    expect(
      CableAllocationStateMachine.canTransition(
        CableAllocationState.active,
        CableAllocationState.draft,
      ),
      isFalse,
    );
  });

  test('termination set rejects duplicate allocation/resource/end mapping', () {
    final mappings = [
      CableTerminationMapping(
        id: 'term-1',
        allocationId: 'alloc-1',
        resourceIdentity: 'core-1',
        end: CableTerminationEnd.a,
        endpointPortId: 'port-a',
      ),
      CableTerminationMapping(
        id: 'term-2',
        allocationId: 'alloc-1',
        resourceIdentity: 'CORE-1',
        end: CableTerminationEnd.a,
        endpointPortId: 'port-a',
      ),
    ];

    expect(validateTerminationSet(mappings), isNotEmpty);
  });

  test('reserved and active allocations consume physical resources', () {
    CableAllocation allocation(CableAllocationState state) => CableAllocation(
          id: 'alloc-1',
          projectId: 'project-1',
          engineeringConnectionId: 'connection-1',
          cableId: 'cable-1',
          state: state,
          revision: 1,
        );

    expect(allocation(CableAllocationState.draft).consumesResources, isFalse);
    expect(allocation(CableAllocationState.reserved).consumesResources, isTrue);
    expect(allocation(CableAllocationState.active).consumesResources, isTrue);
    expect(allocation(CableAllocationState.released).consumesResources, isFalse);
  });
}
