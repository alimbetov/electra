import 'acs04_source_requirement_contract.dart';

final class ReplaceAcs04SourceRequirementContractCommand {
  const ReplaceAcs04SourceRequirementContractCommand({
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
  final Acs04SourceRequirementContract contract;
}

abstract interface class Acs04SourceRequirementContractWriter {
  Future<void> replace(ReplaceAcs04SourceRequirementContractCommand command);
}
