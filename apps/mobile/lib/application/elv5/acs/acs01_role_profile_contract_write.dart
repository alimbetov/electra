import 'acs01_role_profile_contract.dart';

final class ReplaceAcs01RoleProfileContractCommand {
  ReplaceAcs01RoleProfileContractCommand({
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
      throw ArgumentError('ACS01 contract command identity is required.');
    }
    if (expectedDesignRevision < 1 ||
        (expectedBindingRevision != null && expectedBindingRevision! < 1)) {
      throw ArgumentError('ACS01 expected revisions must be positive.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Acs01RoleProfileContract contract;
}

abstract interface class Acs01RoleProfileContractWriter {
  Future<void> replace(ReplaceAcs01RoleProfileContractCommand command);
}
