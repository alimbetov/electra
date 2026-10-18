import 'package:engineering_core/engineering_core_elv5.dart';

final class Fa08RouteCableFact {
  const Fa08RouteCableFact({
    required this.sectionId,
    required this.cableId,
    required this.cableEditionId,
    required this.cableClass,
    required this.numericFacts,
  });

  final String sectionId;
  final String cableId;
  final String cableEditionId;
  final String? cableClass;
  final List<Fa08NumericFact> numericFacts;
}

abstract interface class Fa08RouteCableFactSource {
  Future<List<Fa08RouteCableFact>> loadForCableRun({
    required String projectId,
    required String designRevisionId,
    required String cableRunId,
  });
}
