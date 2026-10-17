final class CctvRecorderAssignmentRef {
  CctvRecorderAssignmentRef({
    required this.bindingId,
    required this.bindingRevision,
    required this.recorderId,
    required this.assignmentId,
    required this.cameraId,
    required this.encodedStreamId,
    required this.licenseChannelId,
    required this.storagePoolId,
  }) {
    if (<String>[bindingId,recorderId,assignmentId,cameraId,encodedStreamId,licenseChannelId,storagePoolId]
        .any((value)=>value.trim().isEmpty)) {
      throw ArgumentError('CCTV recorder assignment identities must not be empty.');
    }
    if (bindingRevision < 1) throw ArgumentError('Recorder binding revision must be >= 1.');
  }

  final String bindingId;
  final int bindingRevision;
  final String recorderId;
  final String assignmentId;
  final String cameraId;
  final String encodedStreamId;
  final String licenseChannelId;
  final String storagePoolId;
}

abstract interface class CctvRecorderAssignmentSource {
  Future<List<CctvRecorderAssignmentRef>> loadForCamera({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
  });
}
