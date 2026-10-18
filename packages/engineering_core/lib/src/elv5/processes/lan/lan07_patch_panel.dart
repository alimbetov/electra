import '../../numeric/rational.dart';

enum Lan07AssessmentStatus { pass, fail, unresolved }

enum Lan07SpareCombiner { max, sum }

final class Lan07PhysicalPort {
  Lan07PhysicalPort({required this.portId}) {
    if (portId.isEmpty) throw ArgumentError('LAN07 portId must not be empty.');
  }
  final String portId;
}

final class Lan07PatchAssignment {
  Lan07PatchAssignment({
    required this.assignmentId,
    required this.portId,
    required this.sourceEndpointId,
    this.destinationEndpointId,
  }) {
    if (assignmentId.isEmpty || portId.isEmpty || sourceEndpointId.isEmpty) {
      throw ArgumentError('LAN07 assignment identities must not be empty.');
    }
  }
  final String assignmentId;
  final String portId;
  final String sourceEndpointId;
  final String? destinationEndpointId;
}

final class Lan07SparePolicy {
  Lan07SparePolicy({
    required this.absoluteMinimum,
    required this.ratio,
    required this.combiner,
  }) {
    if (absoluteMinimum < 0 || ratio < Elv5Rational.zero) {
      throw ArgumentError('LAN07 spare policy must be nonnegative.');
    }
  }
  final int absoluteMinimum;
  final Elv5Rational ratio;
  final Lan07SpareCombiner combiner;
}

final class Lan07Input {
  Lan07Input({
    required this.panelId,
    required this.ports,
    required this.assignments,
    required this.unavailablePortIds,
    required this.requiredSourceEndpointIds,
    required this.sparePolicy,
  }) {
    if (panelId.isEmpty)
      throw ArgumentError('LAN07 panelId must not be empty.');
    _unique(ports.map((e) => e.portId), 'port');
    _unique(assignments.map((e) => e.assignmentId), 'assignment');
  }
  final String panelId;
  final List<Lan07PhysicalPort> ports;
  final List<Lan07PatchAssignment> assignments;
  final Set<String> unavailablePortIds;
  final Set<String> requiredSourceEndpointIds;
  final Lan07SparePolicy sparePolicy;

  static void _unique(Iterable<String> values, String label) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) {
        throw ArgumentError('LAN07 duplicate $label identity: $value');
      }
    }
  }
}

final class Lan07MappingResult {
  const Lan07MappingResult({
    required this.sourceEndpointId,
    required this.status,
    required this.destinationEndpointIds,
  });
  final String sourceEndpointId;
  final Lan07AssessmentStatus status;
  final List<String> destinationEndpointIds;
}

final class Lan07Result {
  const Lan07Result({
    required this.status,
    required this.occupied,
    required this.free,
    required this.requiredSpare,
    required this.spareHeadroom,
    required this.mappings,
    required this.conflictingAssignmentIds,
  });
  final Lan07AssessmentStatus status;
  final int occupied;
  final int free;
  final int requiredSpare;
  final int spareHeadroom;
  final List<Lan07MappingResult> mappings;
  final List<String> conflictingAssignmentIds;
}

final class Lan07PatchPanelKernel {
  const Lan07PatchPanelKernel();

  Lan07Result evaluate(Lan07Input input) {
    final knownPorts = input.ports.map((e) => e.portId).toSet();
    final occupied = <String>{};
    final assignmentsByPort = <String, List<Lan07PatchAssignment>>{};
    final conflicts = <String>{};
    final destinationsBySource = <String, Set<String>>{};

    for (final assignment in input.assignments) {
      if (!knownPorts.contains(assignment.portId) ||
          input.unavailablePortIds.contains(assignment.portId)) {
        conflicts.add(assignment.assignmentId);
        continue;
      }
      assignmentsByPort
          .putIfAbsent(assignment.portId, () => <Lan07PatchAssignment>[])
          .add(assignment);
      occupied.add(assignment.portId);
      final destination = assignment.destinationEndpointId;
      if (destination != null && destination.isNotEmpty) {
        destinationsBySource
            .putIfAbsent(assignment.sourceEndpointId, () => <String>{})
            .add(destination);
      }
    }
    // A termination and its passive continuation share one physical port.
    // Exclusive relationships still conflict when they claim different sources
    // or duplicate the termination/patch role on that port.
    for (final assignments in assignmentsByPort.values) {
      final sources = assignments.map((a) => a.sourceEndpointId).toSet();
      final patches = assignments
          .where(
            (a) => a.destinationEndpointId?.isNotEmpty ?? false,
          )
          .length;
      final terminations = assignments.length - patches;
      if (sources.length > 1 || patches > 1 || terminations > 1) {
        conflicts.addAll(assignments.map((a) => a.assignmentId));
      }
    }
    final sortedConflicts = conflicts.toList()..sort();

    final mappings = <Lan07MappingResult>[];
    var mappingFailure = false;
    var mappingUnresolved = false;
    final requiredSources = [...input.requiredSourceEndpointIds]..sort();
    for (final source in requiredSources) {
      final destinations = [
        ...(destinationsBySource[source] ?? const <String>{}),
      ]..sort();
      final status = destinations.isEmpty
          ? Lan07AssessmentStatus.unresolved
          : (destinations.length == 1
              ? Lan07AssessmentStatus.pass
              : Lan07AssessmentStatus.fail);
      if (status == Lan07AssessmentStatus.fail) mappingFailure = true;
      if (status == Lan07AssessmentStatus.unresolved) mappingUnresolved = true;
      mappings.add(
        Lan07MappingResult(
          sourceEndpointId: source,
          status: status,
          destinationEndpointIds: List.unmodifiable(destinations),
        ),
      );
    }

    final available = input.ports
        .where((p) => !input.unavailablePortIds.contains(p.portId))
        .length;
    final free = available - occupied.length;
    final ratioSpare =
        (Elv5Rational.integer(occupied.length) * input.sparePolicy.ratio)
            .ceil()
            .toInt();
    final requiredSpare = switch (input.sparePolicy.combiner) {
      Lan07SpareCombiner.max => ratioSpare > input.sparePolicy.absoluteMinimum
          ? ratioSpare
          : input.sparePolicy.absoluteMinimum,
      Lan07SpareCombiner.sum => ratioSpare + input.sparePolicy.absoluteMinimum,
    };
    final spareHeadroom = free - requiredSpare;

    final status =
        sortedConflicts.isNotEmpty || mappingFailure || spareHeadroom < 0
            ? Lan07AssessmentStatus.fail
            : (mappingUnresolved
                ? Lan07AssessmentStatus.unresolved
                : Lan07AssessmentStatus.pass);
    return Lan07Result(
      status: status,
      occupied: occupied.length,
      free: free,
      requiredSpare: requiredSpare,
      spareHeadroom: spareHeadroom,
      mappings: List.unmodifiable(mappings),
      conflictingAssignmentIds: List.unmodifiable(sortedConflicts),
    );
  }
}
