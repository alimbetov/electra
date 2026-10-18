import 'acs05_autonomy_contract.dart';

final class ReplaceAcs05AutonomyContractCommand {
  const ReplaceAcs05AutonomyContractCommand({
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
  final Acs05AutonomyContract contract;
}

abstract interface class Acs05AutonomyContractWriter {
  Future<void> replace(ReplaceAcs05AutonomyContractCommand command);
}
