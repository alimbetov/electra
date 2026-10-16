import 'elv_physical_routing_workspace_service.dart';

/// P7 reviewed-mutation contract. The UI may only apply the exact payload that
/// produced the reviewed preview fingerprint and for the exact design revision
/// currently shown in the power workspace.
abstract interface class ElvReviewedWorkspaceCommand
    implements ElvWorkspaceCommand {
  String get designRevisionId;
  String get reviewedFingerprint;
}
