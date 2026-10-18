import 'fa05_autonomy_contract.dart';

final class ReplaceFa05AutonomyContractCommand {
  const ReplaceFa05AutonomyContractCommand({
    required this.projectId,
    required this.designRevisionId,
    required this.bindingId,
    required this.expectedBindingRevision,
    required this.expectedDesignRevision,
    required this.contract,
  });

  final String projectId;
  final String designRevisionId;
  final String bindingId;
  final int? expectedBindingRevision;
  final int expectedDesignRevision;
  final Fa05AutonomyContract contract;
}

abstract interface class Fa05AutonomyContractWriter {
  Future<void> replace(ReplaceFa05AutonomyContractCommand command);
}
