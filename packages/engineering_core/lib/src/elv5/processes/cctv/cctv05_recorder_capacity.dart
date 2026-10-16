import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Cctv05AssessmentStatus { pass, fail, unresolved, blocked }
enum Cctv05ChannelAccountingBasis { device, encodedStream, licenseChannel }
enum Cctv05StorageClaimBasis { expectedEstimate, guaranteedUpperBound }
enum Cctv05GoverningDimension { channel, ingress, codec, storage }

final class Cctv05RecorderCapability {
  Cctv05RecorderCapability({
    required this.channelLimit,
    required this.peakIngressCapacity,
    required this.usableStorageCapacity,
    required this.supportedCodecProfiles,
  }) {
    if (channelLimit < 0 ||
        peakIngressCapacity.value < Elv5Rational.zero ||
        usableStorageCapacity.value < Elv5Rational.zero) {
      throw ArgumentError('CCTV05 recorder capacities must be nonnegative.');
    }
  }

  final int channelLimit;
  final BitRate peakIngressCapacity;
  final ByteCapacity usableStorageCapacity;
  final Set<String> supportedCodecProfiles;
}

final class Cctv05RecorderAssignment {
  Cctv05RecorderAssignment({
    required this.assignmentId,
    required this.deviceId,
    required this.encodedStreamId,
    required this.licenseChannelId,
    required this.codecProfile,
  }) {
    if (assignmentId.isEmpty || deviceId.isEmpty || encodedStreamId.isEmpty || licenseChannelId.isEmpty) {
      throw ArgumentError('CCTV05 assignment identities must not be empty.');
    }
  }

  final String assignmentId;
  final String deviceId;
  final String encodedStreamId;
  final String licenseChannelId;
  final String? codecProfile;
}

final class Cctv05IngressEvidence {
  Cctv05IngressEvidence({
    required this.scopeFingerprint,
    required this.peakIngress,
  }) {
    if (scopeFingerprint.isEmpty || peakIngress.value < Elv5Rational.zero) {
      throw ArgumentError('CCTV05 ingress evidence is invalid.');
    }
  }

  final String scopeFingerprint;
  final BitRate peakIngress;
}

final class Cctv05StorageEvidence {
  Cctv05StorageEvidence({
    required this.scopeFingerprint,
    required this.basis,
    required this.requiredUsable,
  }) {
    if (scopeFingerprint.isEmpty || requiredUsable.value < Elv5Rational.zero) {
      throw ArgumentError('CCTV05 storage evidence is invalid.');
    }
  }

  final String scopeFingerprint;
  final Cctv05StorageClaimBasis basis;
  final ByteCapacity requiredUsable;
}

final class Cctv05Input {
  Cctv05Input({
    required this.recorderId,
    required this.capability,
    required this.accountingBasis,
    required this.assignments,
    required this.expectedIngressScopeFingerprint,
    required this.expectedStorageScopeFingerprint,
    required this.ingressEvidence,
    required this.storageEvidence,
    required this.requireGuaranteedStorage,
  }) {
    if (recorderId.isEmpty ||
        expectedIngressScopeFingerprint.isEmpty ||
        expectedStorageScopeFingerprint.isEmpty) {
      throw ArgumentError('CCTV05 recorder/scope identities must not be empty.');
    }
    final seen = <String>{};
    for (final assignment in assignments) {
      if (!seen.add(assignment.assignmentId)) {
        throw ArgumentError('CCTV05 duplicate assignmentId: ${assignment.assignmentId}');
      }
    }
  }

  final String recorderId;
  final Cctv05RecorderCapability capability;
  final Cctv05ChannelAccountingBasis accountingBasis;
  final List<Cctv05RecorderAssignment> assignments;
  final String expectedIngressScopeFingerprint;
  final String expectedStorageScopeFingerprint;
  final Cctv05IngressEvidence ingressEvidence;
  final Cctv05StorageEvidence storageEvidence;
  final bool requireGuaranteedStorage;
}

final class Cctv05CodecResult {
  const Cctv05CodecResult({
    required this.streamId,
    required this.status,
  });

  final String streamId;
  final Cctv05AssessmentStatus status;
}

final class Cctv05Result {
  const Cctv05Result({
    required this.status,
    required this.consumedChannels,
    required this.channelMargin,
    required this.peakIngress,
    required this.ingressMargin,
    required this.requiredUsable,
    required this.storageMargin,
    required this.codecResults,
    required this.governingDimension,
    required this.blockingReason,
  });

  final Cctv05AssessmentStatus status;
  final int consumedChannels;
  final int channelMargin;
  final BitRate peakIngress;
  final BitRate ingressMargin;
  final ByteCapacity requiredUsable;
  final ByteCapacity storageMargin;
  final List<Cctv05CodecResult> codecResults;
  final Cctv05GoverningDimension? governingDimension;
  final String? blockingReason;
}

final class Cctv05RecorderCapacityKernel {
  const Cctv05RecorderCapacityKernel();

  Cctv05Result evaluate(Cctv05Input input) {
    if (input.ingressEvidence.scopeFingerprint != input.expectedIngressScopeFingerprint) {
      return _blocked(input, 'CCTV05_INGRESS_SCOPE_MISMATCH');
    }
    if (input.storageEvidence.scopeFingerprint != input.expectedStorageScopeFingerprint) {
      return _blocked(input, 'CCTV05_STORAGE_SCOPE_MISMATCH');
    }
    if (input.requireGuaranteedStorage &&
        input.storageEvidence.basis != Cctv05StorageClaimBasis.guaranteedUpperBound) {
      return _blocked(input, 'CCTV05_GUARANTEED_STORAGE_CLAIM_REQUIRED');
    }

    final units = <String>{};
    for (final assignment in input.assignments) {
      units.add(switch (input.accountingBasis) {
        Cctv05ChannelAccountingBasis.device => assignment.deviceId,
        Cctv05ChannelAccountingBasis.encodedStream => assignment.encodedStreamId,
        Cctv05ChannelAccountingBasis.licenseChannel => assignment.licenseChannelId,
      });
    }
    final consumedChannels = units.length;
    final channelMargin = input.capability.channelLimit - consumedChannels;
    final ingressMargin = input.capability.peakIngressCapacity - input.ingressEvidence.peakIngress;
    final storageMargin = input.capability.usableStorageCapacity - input.storageEvidence.requiredUsable;

    final assignments = [...input.assignments]
      ..sort((a, b) => a.encodedStreamId.compareTo(b.encodedStreamId));
    final codecResults = <Cctv05CodecResult>[];
    for (final assignment in assignments) {
      final profile = assignment.codecProfile;
      codecResults.add(Cctv05CodecResult(
        streamId: assignment.encodedStreamId,
        status: profile == null
            ? Cctv05AssessmentStatus.unresolved
            : (input.capability.supportedCodecProfiles.contains(profile)
                ? Cctv05AssessmentStatus.pass
                : Cctv05AssessmentStatus.fail),
      ));
    }

    if (channelMargin < 0) {
      return _result(input, consumedChannels, channelMargin, ingressMargin, storageMargin,
          codecResults, Cctv05AssessmentStatus.fail, Cctv05GoverningDimension.channel);
    }
    if (ingressMargin.value < Elv5Rational.zero) {
      return _result(input, consumedChannels, channelMargin, ingressMargin, storageMargin,
          codecResults, Cctv05AssessmentStatus.fail, Cctv05GoverningDimension.ingress);
    }
    final codecFail = codecResults.any((e) => e.status == Cctv05AssessmentStatus.fail);
    if (codecFail) {
      return _result(input, consumedChannels, channelMargin, ingressMargin, storageMargin,
          codecResults, Cctv05AssessmentStatus.fail, Cctv05GoverningDimension.codec);
    }
    if (storageMargin.value < Elv5Rational.zero) {
      return _result(input, consumedChannels, channelMargin, ingressMargin, storageMargin,
          codecResults, Cctv05AssessmentStatus.fail, Cctv05GoverningDimension.storage);
    }
    final codecUnresolved = codecResults.any((e) => e.status == Cctv05AssessmentStatus.unresolved);
    if (codecUnresolved) {
      return _result(input, consumedChannels, channelMargin, ingressMargin, storageMargin,
          codecResults, Cctv05AssessmentStatus.unresolved, Cctv05GoverningDimension.codec);
    }

    return _result(input, consumedChannels, channelMargin, ingressMargin, storageMargin,
        codecResults, Cctv05AssessmentStatus.pass, null);
  }

  Cctv05Result _result(
    Cctv05Input input,
    int consumedChannels,
    int channelMargin,
    BitRate ingressMargin,
    ByteCapacity storageMargin,
    List<Cctv05CodecResult> codecResults,
    Cctv05AssessmentStatus status,
    Cctv05GoverningDimension? governing,
  ) =>
      Cctv05Result(
        status: status,
        consumedChannels: consumedChannels,
        channelMargin: channelMargin,
        peakIngress: input.ingressEvidence.peakIngress,
        ingressMargin: ingressMargin,
        requiredUsable: input.storageEvidence.requiredUsable,
        storageMargin: storageMargin,
        codecResults: List.unmodifiable(codecResults),
        governingDimension: governing,
        blockingReason: null,
      );

  Cctv05Result _blocked(Cctv05Input input, String reason) => Cctv05Result(
        status: Cctv05AssessmentStatus.blocked,
        consumedChannels: 0,
        channelMargin: input.capability.channelLimit,
        peakIngress: input.ingressEvidence.peakIngress,
        ingressMargin: input.capability.peakIngressCapacity - input.ingressEvidence.peakIngress,
        requiredUsable: input.storageEvidence.requiredUsable,
        storageMargin: input.capability.usableStorageCapacity - input.storageEvidence.requiredUsable,
        codecResults: const [],
        governingDimension: null,
        blockingReason: reason,
      );
}
