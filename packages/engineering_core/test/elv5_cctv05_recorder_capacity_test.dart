import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  Elv5Rational q(String value) => Elv5Rational.parseDecimal(value);
  BitRate b(String value) => BitRate(q(value));
  ByteCapacity bytes(String value) => ByteCapacity(q(value));

  Cctv05RecorderCapability capability({
    int channels = 4,
    String ingress = '20000000',
    String storage = '3000000000000',
  }) =>
      Cctv05RecorderCapability(
        channelLimit: channels,
        peakIngressCapacity: b(ingress),
        usableStorageCapacity: bytes(storage),
        supportedCodecProfiles: {'h264-main', 'h265-main'},
      );

  Cctv05RecorderAssignment assignment(
    String id,
    String device,
    String stream,
    String license, {
    String? codec = 'h264-main',
  }) =>
      Cctv05RecorderAssignment(
        assignmentId: id,
        deviceId: device,
        encodedStreamId: stream,
        licenseChannelId: license,
        codecProfile: codec,
      );

  Cctv05Input input({
    Cctv05RecorderCapability? cap,
    List<Cctv05RecorderAssignment>? assignments,
    Cctv05ChannelAccountingBasis basis = Cctv05ChannelAccountingBasis.encodedStream,
    String peakIngress = '8000000',
    String storage = '2851200000000',
    Cctv05StorageClaimBasis storageBasis = Cctv05StorageClaimBasis.guaranteedUpperBound,
    bool requireGuaranteed = true,
  }) =>
      Cctv05Input(
        recorderId: 'rec-1',
        capability: cap ?? capability(),
        accountingBasis: basis,
        assignments: assignments ?? [
          assignment('a1', 'cam-1', 's1', 'lic-1'),
          assignment('a2', 'cam-2', 's2', 'lic-2'),
        ],
        expectedIngressScopeFingerprint: 'ingress-v1',
        expectedStorageScopeFingerprint: 'storage-v1',
        ingressEvidence: Cctv05IngressEvidence(
          scopeFingerprint: 'ingress-v1',
          peakIngress: b(peakIngress),
        ),
        storageEvidence: Cctv05StorageEvidence(
          scopeFingerprint: 'storage-v1',
          basis: storageBasis,
          requiredUsable: bytes(storage),
        ),
        requireGuaranteedStorage: requireGuaranteed,
      );

  test('reference vector passes all independent dimensions', () {
    final result = const Cctv05RecorderCapacityKernel().evaluate(input());
    expect(result.status, Cctv05AssessmentStatus.pass);
    expect(result.consumedChannels, 2);
    expect(result.channelMargin, 2);
    expect(result.ingressMargin, b('12000000'));
    expect(result.storageMargin, bytes('148800000000'));
  });

  test('encoded stream basis deduplicates duplicate UI rows for same stream', () {
    final result = const Cctv05RecorderCapacityKernel().evaluate(input(
      assignments: [
        assignment('a1', 'cam-1', 'stream-1', 'lic-1'),
        assignment('a2', 'cam-1', 'stream-1', 'lic-2'),
      ],
    ));
    expect(result.consumedChannels, 1);
    expect(result.status, Cctv05AssessmentStatus.pass);
  });

  test('storage failure governs when channels and ingress pass', () {
    final result = const Cctv05RecorderCapacityKernel().evaluate(input(
      storage: '3200000000000',
    ));
    expect(result.status, Cctv05AssessmentStatus.fail);
    expect(result.governingDimension, Cctv05GoverningDimension.storage);
    expect(result.storageMargin, bytes('-200000000000'));
  });

  test('missing codec evidence is unresolved rather than assumed compatible', () {
    final result = const Cctv05RecorderCapacityKernel().evaluate(input(
      assignments: [assignment('a1', 'cam-1', 'stream-1', 'lic-1', codec: null)],
    ));
    expect(result.status, Cctv05AssessmentStatus.unresolved);
    expect(result.governingDimension, Cctv05GoverningDimension.codec);
  });

  test('expected storage estimate cannot qualify guaranteed storage requirement', () {
    final result = const Cctv05RecorderCapacityKernel().evaluate(input(
      storageBasis: Cctv05StorageClaimBasis.expectedEstimate,
      requireGuaranteed: true,
    ));
    expect(result.status, Cctv05AssessmentStatus.blocked);
    expect(result.blockingReason, 'CCTV05_GUARANTEED_STORAGE_CLAIM_REQUIRED');
  });
}
