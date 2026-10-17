import 'acs03_electrical_contract.dart';

final class ReplaceAcs03ElectricalContractCommand {
  ReplaceAcs03ElectricalContractCommand({
    required String projectId,
    required String designRevisionId,
    required String bindingId,
    required this.expectedBindingRevision,
    required this.expectedDesignRevision,
    required this.contract,
  }) : projectId = _text(projectId, 'projectId'),
       designRevisionId = _text(designRevisionId, 'designRevisionId'),
       bindingId = _text(bindingId, 'bindingId') {
    if (expectedBindingRevision != null && expectedBindingRevision! < 1) {
      throw ArgumentError('ACS03 expected binding revision must be positive.');
    }
    if (expectedDesignRevision < 1) {
      throw ArgumentError('ACS03 expected design revision must be positive.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final String bindingId;
  final int? expectedBindingRevision;
  final int expectedDesignRevision;
  final Acs03ElectricalContract contract;
}

abstract interface class Acs03ElectricalContractWriter {
  Future<void> replace(ReplaceAcs03ElectricalContractCommand command);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
