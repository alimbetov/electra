import 'acs06_topology_contract.dart';

final class ReplaceAcs06TopologyContractCommand {
  ReplaceAcs06TopologyContractCommand({
    required this.projectId,
    required this.designRevisionId,
    required this.expectedDesignRevision,
    required this.bindingId,
    required this.expectedBindingRevision,
    required this.contract,
  }) {
    if (projectId.trim().isEmpty ||
        designRevisionId.trim().isEmpty ||
        bindingId.trim().isEmpty) {
      throw ArgumentError('ACS06 topology command identity is required.');
    }
    if (expectedDesignRevision < 1) {
      throw ArgumentError('expectedDesignRevision must be >= 1.');
    }
    if (expectedBindingRevision != null && expectedBindingRevision! < 1) {
      throw ArgumentError('expectedBindingRevision must be >= 1 when supplied.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Acs06TopologyContract contract;
}

abstract interface class Acs06TopologyContractWriter {
  Future<void> replace(ReplaceAcs06TopologyContractCommand command);
}
