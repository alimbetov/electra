import 'fa04_source_requirement_contract.dart';

final class ReplaceFa04SourceRequirementContractCommand {
  const ReplaceFa04SourceRequirementContractCommand({
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
  final Fa04SourceRequirementContract contract;
}

abstract interface class Fa04SourceRequirementContractWriter {
  Future<void> replace(ReplaceFa04SourceRequirementContractCommand command);
}
