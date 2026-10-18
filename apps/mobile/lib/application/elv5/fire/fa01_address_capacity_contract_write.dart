import 'fa01_address_capacity_contract.dart';

final class ReplaceFa01AddressCapacityContractCommand {
  const ReplaceFa01AddressCapacityContractCommand({
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
  final Fa01AddressCapacityContract contract;
}

abstract interface class Fa01AddressCapacityContractWriter {
  Future<void> replace(ReplaceFa01AddressCapacityContractCommand command);
}
