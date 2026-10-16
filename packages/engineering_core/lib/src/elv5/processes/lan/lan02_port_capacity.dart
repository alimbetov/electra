import '../../numeric/rational.dart';

enum Lan02AssessmentStatus { pass, fail }
enum Lan02SpareCombiner { max, sum }

final class Lan02PhysicalPort {
  Lan02PhysicalPort({
    required this.portId,
    required this.media,
    required this.maxSpeedMbps,
  }) {
    if (portId.isEmpty || media.isEmpty || maxSpeedMbps <= 0) {
      throw ArgumentError('LAN02 invalid physical port definition.');
    }
  }
  final String portId;
  final String media;
  final int maxSpeedMbps;
}

final class Lan02PortAssignment {
  Lan02PortAssignment({
    required this.endpointId,
    required this.portId,
    required this.requiredMedia,
    required this.requiredSpeedMbps,
  }) {
    if (endpointId.isEmpty || portId.isEmpty || requiredMedia.isEmpty || requiredSpeedMbps <= 0) {
      throw ArgumentError('LAN02 invalid port assignment.');
    }
  }
  final String endpointId;
  final String portId;
  final String requiredMedia;
  final int requiredSpeedMbps;
}

final class Lan02SparePolicy {
  Lan02SparePolicy({
    required this.absoluteMinimum,
    required this.ratio,
    required this.combiner,
  }) {
    if (absoluteMinimum < 0 || ratio < Elv5Rational.zero) {
      throw ArgumentError('LAN02 spare policy must be nonnegative.');
    }
  }
  final int absoluteMinimum;
  final Elv5Rational ratio;
  final Lan02SpareCombiner combiner;
}

final class Lan02Input {
  Lan02Input({
    required this.switchId,
    required this.ports,
    required this.assignments,
    required this.unavailablePortIds,
    required this.sparePolicy,
  }) {
    if (switchId.isEmpty) throw ArgumentError('LAN02 switchId must not be empty.');
    _unique(ports.map((e) => e.portId), 'port');
    _unique(assignments.map((e) => e.endpointId), 'endpoint');
  }
  final String switchId;
  final List<Lan02PhysicalPort> ports;
  final List<Lan02PortAssignment> assignments;
  final Set<String> unavailablePortIds;
  final Lan02SparePolicy sparePolicy;

  static void _unique(Iterable<String> values, String label) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) throw ArgumentError('LAN02 duplicate $label identity: $value');
    }
  }
}

final class Lan02Result {
  const Lan02Result({
    required this.status,
    required this.occupied,
    required this.requiredSpare,
    required this.available,
    required this.headroomPorts,
    required this.incompatibleEndpointIds,
  });
  final Lan02AssessmentStatus status;
  final int occupied;
  final int requiredSpare;
  final int available;
  final int headroomPorts;
  final List<String> incompatibleEndpointIds;
}

final class Lan02PortCapacityKernel {
  const Lan02PortCapacityKernel();

  Lan02Result evaluate(Lan02Input input) {
    final ports = <String, Lan02PhysicalPort>{for (final port in input.ports) port.portId: port};
    final occupied = <String>{};
    final incompatible = <String>[];
    for (final assignment in input.assignments) {
      final port = ports[assignment.portId];
      if (port == null || input.unavailablePortIds.contains(assignment.portId)) {
        incompatible.add(assignment.endpointId);
        continue;
      }
      if (!occupied.add(assignment.portId)) {
        incompatible.add(assignment.endpointId);
        continue;
      }
      if (port.media != assignment.requiredMedia ||
          port.maxSpeedMbps < assignment.requiredSpeedMbps) {
        incompatible.add(assignment.endpointId);
      }
    }
    incompatible.sort();

    final ratioSpare = (Elv5Rational.integer(occupied.length) * input.sparePolicy.ratio).ceil().toInt();
    final requiredSpare = switch (input.sparePolicy.combiner) {
      Lan02SpareCombiner.max => ratioSpare > input.sparePolicy.absoluteMinimum
          ? ratioSpare
          : input.sparePolicy.absoluteMinimum,
      Lan02SpareCombiner.sum => ratioSpare + input.sparePolicy.absoluteMinimum,
    };
    final available = input.ports
        .where((p) => !input.unavailablePortIds.contains(p.portId))
        .length;
    final headroom = available - occupied.length - requiredSpare;
    final status = incompatible.isEmpty && headroom >= 0
        ? Lan02AssessmentStatus.pass
        : Lan02AssessmentStatus.fail;
    return Lan02Result(
      status: status,
      occupied: occupied.length,
      requiredSpare: requiredSpare,
      available: available,
      headroomPorts: headroom,
      incompatibleEndpointIds: List.unmodifiable(incompatible),
    );
  }
}
