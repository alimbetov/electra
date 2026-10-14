import 'elv_cable_reference.dart';
import 'elv_cable_resource.dart';

const String wholeCableResourceIdentity = '__WHOLE_CABLE__';

enum CableAllocationState { draft, reserved, active, released, archived }

final class CableAllocation {
  const CableAllocation({
    required this.id,
    required this.projectId,
    required this.engineeringConnectionId,
    required this.cableId,
    required this.state,
    required this.revision,
    this.transitionRef,
  });

  final String id;
  final String projectId;
  final String engineeringConnectionId;
  final String cableId;
  final CableAllocationState state;
  final int revision;
  final String? transitionRef;

  bool get consumesResources =>
      state == CableAllocationState.reserved ||
      state == CableAllocationState.active;

  List<String> validate() => [
        if (id.trim().isEmpty) 'Cable allocation id is required.',
        if (projectId.trim().isEmpty) 'Cable allocation projectId is required.',
        if (engineeringConnectionId.trim().isEmpty)
          'Cable allocation engineeringConnectionId is required.',
        if (cableId.trim().isEmpty) 'Cable allocation cableId is required.',
        if (revision < 1) 'Cable allocation revision must be >= 1.',
      ];

  CableAllocation copyWith({
    CableAllocationState? state,
    int? revision,
    String? transitionRef,
  }) =>
      CableAllocation(
        id: id,
        projectId: projectId,
        engineeringConnectionId: engineeringConnectionId,
        cableId: cableId,
        state: state ?? this.state,
        revision: revision ?? this.revision,
        transitionRef: transitionRef ?? this.transitionRef,
      );
}

final class CableAllocationResourceSelectionEvidence {
  CableAllocationResourceSelectionEvidence({
    required this.allocationId,
    required this.cableDefinitionRef,
    required this.selection,
    required Iterable<String> resolvedAtoms,
    required this.selectionSha256,
  }) : resolvedAtoms = List.unmodifiable(
         resolvedAtoms.map((value) => value.trim().toUpperCase()),
       );

  final String allocationId;
  final CableDefinitionRef cableDefinitionRef;
  final CableResourceSelection selection;
  final List<String> resolvedAtoms;
  final String selectionSha256;

  List<String> validate() => [
        if (allocationId.trim().isEmpty) 'Allocation id is required.',
        ...cableDefinitionRef.validate(),
        if (resolvedAtoms.isEmpty) 'Resolved resource atom set is required.',
        if (resolvedAtoms.any((value) => value.isEmpty))
          'Resolved resource atom identities must not be empty.',
        if (resolvedAtoms.toSet().length != resolvedAtoms.length)
          'Resolved resource atom identities must be unique.',
        if (selectionSha256.trim().length != 64)
          'Selection SHA-256 must be 64 characters.',
      ];
}

abstract final class CableAllocationStateMachine {
  static bool canTransition(
    CableAllocationState from,
    CableAllocationState to,
  ) => switch ((from, to)) {
        (CableAllocationState.draft, CableAllocationState.reserved) => true,
        (CableAllocationState.reserved, CableAllocationState.active) => true,
        (CableAllocationState.reserved, CableAllocationState.released) => true,
        (CableAllocationState.active, CableAllocationState.released) => true,
        (CableAllocationState.released, CableAllocationState.archived) => true,
        (CableAllocationState.draft, CableAllocationState.archived) => true,
        _ => false,
      };

  static void requireTransition(
    CableAllocationState from,
    CableAllocationState to,
  ) {
    if (!canTransition(from, to)) {
      throw StateError(
        'ELV_ALLOC_INVALID_STATE_TRANSITION:${from.name}->${to.name}',
      );
    }
  }
}

abstract final class CableResourceOverlap {
  static bool conflicts(Iterable<String> left, Iterable<String> right) {
    final a = left.toSet();
    final b = right.toSet();
    if (a.contains(wholeCableResourceIdentity) ||
        b.contains(wholeCableResourceIdentity)) {
      return a.isNotEmpty && b.isNotEmpty;
    }
    return a.intersection(b).isNotEmpty;
  }
}
