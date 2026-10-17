import 'fa07_topology_contract.dart';

final class ReplaceFa07TopologyContractCommand {
  const ReplaceFa07TopologyContractCommand({required this.projectId,required this.designRevisionId,required this.bindingId,required this.expectedBindingRevision,required this.expectedDesignRevision,required this.contract});
  final String projectId; final String designRevisionId; final String bindingId; final int? expectedBindingRevision; final int expectedDesignRevision; final Fa07TopologyContract contract;
}
abstract interface class Fa07TopologyContractWriter {Future<void> replace(ReplaceFa07TopologyContractCommand command);}
