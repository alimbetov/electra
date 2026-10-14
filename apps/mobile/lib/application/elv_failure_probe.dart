abstract interface class ElvFailureProbe {
  Future<void> hit(String point);
}

final class NoopElvFailureProbe implements ElvFailureProbe {
  const NoopElvFailureProbe();

  @override
  Future<void> hit(String point) async {}
}

abstract final class ElvFailurePoints {
  static const p1CreateCableAfterInsert = 'P1_CREATE_CABLE_AFTER_INSERT';
  static const p2ReserveAfterFirstClaim = 'P2_RESERVE_AFTER_FIRST_CLAIM';
  static const p2ReplaceTerminationAfterDelete =
      'P2_REPLACE_TERMINATION_AFTER_DELETE';
  static const p2ActivateBeforeStateUpdate = 'P2_ACTIVATE_BEFORE_STATE_UPDATE';
  static const p3FreezeAfterSnapshotInsert = 'P3_FREEZE_AFTER_SNAPSHOT_INSERT';
  static const p3CreateNextAfterRevisionInsert =
      'P3_CREATE_NEXT_AFTER_REVISION_INSERT';
  static const p3RerouteAfterDeleteOldChain =
      'P3_REROUTE_AFTER_DELETE_OLD_CHAIN';
  static const p4AttachCarrierAfterTraversalUpdate =
      'P4_ATTACH_CARRIER_AFTER_TRAVERSAL_UPDATE';
  static const p3AdoptAfterCableCreate = 'P3_ADOPT_AFTER_CABLE_CREATE';
}
