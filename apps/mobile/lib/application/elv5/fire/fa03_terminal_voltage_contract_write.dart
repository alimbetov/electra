import 'fa03_terminal_voltage_contract.dart';

final class ReplaceFa03TerminalVoltageContractCommand {
  const ReplaceFa03TerminalVoltageContractCommand({
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
  final Fa03TerminalVoltageContract contract;
}

abstract interface class Fa03TerminalVoltageContractWriter {
  Future<void> replace(ReplaceFa03TerminalVoltageContractCommand command);
}
