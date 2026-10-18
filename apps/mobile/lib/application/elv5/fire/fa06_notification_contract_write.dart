import 'fa06_notification_contract.dart';

final class ReplaceFa06NotificationContractCommand {
  const ReplaceFa06NotificationContractCommand({
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
  final Fa06NotificationContract contract;
}

abstract interface class Fa06NotificationContractWriter {
  Future<void> replace(ReplaceFa06NotificationContractCommand command);
}
