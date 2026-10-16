# ELV5 — Typed process API for all 27 discipline calculations

Status: DESIGN FROZEN / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`  
Authority: [implementation binding hardening](implementation-binding-hardening-v1.md), [27 process contracts](process-contracts.md), [process registry](process-registry.json), [engineering primitives](engineering-primitives-contract.md), [code-level runtime contract](code-level-runtime-contract.md).

This document defines the minimum typed Dart boundary for every ELV5 process. It does not replace the formulas in `process-contracts.md`; it removes ambiguity about what a pure kernel receives and what it is allowed to return.

Public process symbols, semantic input/output fields, identity rules, claim boundaries and layer ownership are normative. Exact filenames are tracked implementation coordinates rather than engineering semantics; a layout-only rename is permitted only with synchronized implementation-binding registry and authority-manifest update, while preserving the same module/layer ownership and public contracts.

## 1. Shared typed API

`engineering_core` process definitions are pure. They never resolve repositories, Drift rows, UI state or platform services.

```dart
abstract interface class Elv5TypedProcessDefinition<I, O> {
  Elv5ProcessCode get code;
  Elv5Discipline get discipline;
  Elv5ProcessVersions get versions;
  Set<Elv5ScopeKind> get legalScopes;
  Set<String> get requiredDimensionCodes;

  O calculate(I input);

  Elv5EvaluationDraft evaluate(I input, O output);
}
```

Repository-aware input assembly belongs to the application layer under `apps/mobile/lib/application/elv5/calculation/resolvers/`. Its schematic boundary is:

```dart
abstract interface class Elv5InputResolver<I> {
  Future<Elv5InputResolution<I>> resolve(
    Elv5CapturedProjectContext context,
    Elv5ProcessRequest request,
  );
}
```

The resolver MUST bulk-load the declared dependency closure, resolve exact immutable editions/evidence, capture dependency markers and upstream evaluation identities, enforce resource limits, canonicalize order-invariant sets, preserve physical order where significant, and return an immutable sendable typed input before worker execution. `Elv5TypedProcessDefinition` MUST NOT delegate repository access back into `engineering_core`.

```dart
final class Elv5ProcessVersions {
  final String algorithmVersion;
  final String inputSchemaVersion;
  final String outputSchemaVersion;
  final String numericBackendVersion;
}

final class Elv5SubjectRef {
  final String kind;
  final String id;
}

final class Elv5ScopeRef {
  final Elv5ScopeKind kind;
  final String scopeId;
  final String scenarioKey;
}
```

Every input includes, directly or through a shared base object:

```dart
final class Elv5InputHeader {
  final String projectId;
  final String designRevisionId;
  final Elv5ScopeRef scope;
  final Elv5SubjectRef subject;
  final Elv5OperatingCaseRef operatingCase;
  final List<Elv5PolicyEditionRef> policies;
  final List<Elv5ConsumedEvidenceRef> evidence;
  final String inputFingerprint;
}
```

No process receives a generic property bag instead of its typed payload. Extension data may be carried only as code-owned typed unions with a versioned discriminator.

## 2. Shared scalar aliases

The aliases below are semantic shorthand for exact quantities from `engineering-primitives-contract.md`.

```dart
typedef Length = Elv5Quantity<LengthDim>;
typedef Duration = Elv5Quantity<DurationDim>;
typedef Voltage = Elv5Quantity<VoltageDim>;
typedef Current = Elv5Quantity<CurrentDim>;
typedef Resistance = Elv5Quantity<ResistanceDim>;
typedef Power = Elv5Quantity<PowerDim>;
typedef Energy = Elv5Quantity<EnergyDim>;
typedef BitRate = Elv5Quantity<BitRateDim>;
typedef ByteCapacity = Elv5Quantity<ByteCapacityDim>;
typedef Ratio = Elv5Quantity<RatioDim>;
typedef LossDb = Elv5Quantity<AttenuationDbDim>;
typedef LevelDbm = Elv5Quantity<OpticalLevelDbmDim>;
typedef AngleRad = Elv5Quantity<AngleRadDim>;
```

## 3. CCTV-01 — camera coverage geometry

```dart
enum CctvCoverageClaimMode { geometryOnly, geometryAndPixelDensity }

final class Cctv01Input {
  final Elv5InputHeader header;
  final String cameraId;
  final Elv5FrameRef frame;
  final Elv5Point3 opticalCenter;
  final Elv5Rotation3 cameraToFrame;
  final Length sensorWidth;
  final Length sensorHeight;
  final Length focalLength;
  final Elv5Plane3 targetPlane;
  final Elv5Polygon2 targetZone;
  final CctvCoverageClaimMode claimMode;
  final BigInt? activePixelsHorizontal;
  final BigInt? activePixelsVertical;
  final String lensModelCode; // RECTILINEAR_PINHOLE for v1
  final String obstructionModelCode; // NONE_SUPPORTED for v1
}

final class Cctv01Output {
  final Elv5Interval<AngleRad> horizontalFov;
  final Elv5Interval<AngleRad> verticalFov;
  final Elv5BoundedPolygon footprint;
  final Elv5BoundedPolygon zoneIntersection;
  final Elv5Interval<Elv5Rational>? pixelsPerMetreHorizontal;
  final Elv5Interval<Elv5Rational>? pixelsPerMetreVertical;
  final bool modelApplicable;
}
```

Rules:

- v1 accepts only the declared rectilinear pinhole model;
- mixed coordinate frames are illegal without a captured transform chain;
- pixel-density outputs are permitted only when active pixel counts are supplied and `claimMode` requests them;
- pixel density is a technical density only. Recognition/identification/DORI compliance is not inferred by ELV5;
- obstruction, distortion and fisheye models remain unsupported until separately versioned.

## 4. CCTV-02 — stream and network bandwidth

```dart
enum CctvRateEvidenceKind {
  expectedEstimate,
  configuredTarget,
  measuredWindow,
  guaranteedWindowUpperBound,
  guaranteedPointwiseUpperBound,
}

final class CctvRateEvidence {
  final CctvRateEvidenceKind kind;
  final Elv5ResolvedField<Duration> averagingWindow;
  final String rateBoundary; // closed PAYLOAD or WIRE enum in production
  final Elv5SourceRef exactEvidence;
  final String applicabilityHash; // stream settings + supported time/model domain
}

final class CctvEncodedStream {
  final String cameraId;
  final String encodedStreamId;
  final Elv5EngineeringValue<BitRate> expectedPayloadBitRate;
  final Elv5EngineeringValue<BitRate>? peakPayloadBitRate;
  final Elv5ResolvedField<CctvRateEvidence> peakRateEvidence;
  final String codecProfileRef;
}

final class CctvTransportOverheadModel {
  final String modelCode;
  final String version;
  final Ratio payloadToWireMultiplier;
  final Elv5SourceRef source;
}

final class CctvFlowSubscription {
  final String streamId;
  final String receiverId;
  final List<String> orderedNetworkEdgeIds;
  final String deliveryMode; // UNICAST or registered multicast mode
}

final class CctvNetworkEdgeCapacity {
  final String edgeId;
  final BitRate? declaredUsableCapacity;
  final Ratio? maxUtilizationPolicy;
}

final class Cctv02Input {
  final Elv5InputHeader header;
  final List<CctvEncodedStream> streams;
  final List<CctvFlowSubscription> subscriptions;
  final List<CctvNetworkEdgeCapacity> edgeCapacities;
  final CctvTransportOverheadModel? overheadModel;
}

final class CctvEdgeBandwidthResult {
  final String edgeId;
  final BitRate expectedPayload;
  final BitRate? peakPayload;
  final BitRate? expectedWireRate;
  final BitRate? peakWireRate;
  final BitRate? usableCapacity;
  final BitRate? peakMargin;
}

final class Cctv02Output {
  final List<CctvEdgeBandwidthResult> edges;
  final Map<String, BitRate> recorderIngressPayload;
}
```

Wire-rate/capacity comparison is evaluated only when an exact overhead/capacity basis exists. Missing overhead MUST NOT be silently replaced by a universal percentage. The canonical required dimensions remain those declared by `process-registry.json`; extra capacity fields are supplementary until a registry version promotes them to required dimensions.

### Bitrate claim boundary

A non-null `peakPayloadBitRate`, an MBR/CBR name, or a configured device target is
not proof of a guaranteed peak. `peakRateEvidence` is captured from the exact
selected evidence/profile; it is not inferred from the numeric field or accepted
as an unverified caller assertion. Its kind, window, rate boundary, evidence hash
and settings applicability participate in the input fingerprint and frozen
capture. Missing evidence remains an explicit `Elv5Missing` value.

- `expectedEstimate` / `configuredTarget` never qualify a guaranteed capacity claim.
- `measuredWindow` describes observations only; it does not bound future scenes.
- `guaranteedWindowUpperBound` requires a known positive averaging window and an
  exact statement of the windows/settings to which the guarantee applies. Only
  an identical supported comparison window may use it. A longer-window average
  cannot be used to pass a shorter-window peak, nor infer absence of packet loss.
- `guaranteedPointwiseUpperBound` requires explicit evidence supporting that
  stronger bound; a configuration label is insufficient. `averagingWindow` is
  explicitly `Elv5NotApplicable`, not silently zero.
- A PAYLOAD bound cannot be compared to WIRE capacity without the exact transport
  model. Buffer/queue/loss-free delivery is outside the initial scalar rate model.

CCTV-03's initial guaranteed `rate * recordedDuration` integration accepts a
qualified pointwise upper bound. A window-only bound cannot cover arbitrary
recording start/stop intervals without a separately versioned burst/integration
model; return UNRESOLVED for guaranteed retention. Expected sizing may still be
shown as an estimate. Do not invent a burst allowance or multiply a long-term
average into a purported guaranteed storage figure.

Counterexample for acceptance: two consecutive 1 s intervals carry 8 Mbit/s and
0 Mbit/s. Their 2 s average is 4 Mbit/s. A 4 Mbit/s configured/2 s bound must not
qualify a 5 Mbit/s link's 1 s peak claim; recording only the first second needs
1,000,000 bytes rather than the 500,000-byte average estimate. Required tests:
missing window, mismatched window, target-as-guarantee, measured-as-guarantee,
payload/wire mismatch, and propagation through CCTV-02 → CCTV-03/05.

Public source supporting the configuration/peak distinction: Axis,
[Bitrate control for IP video](https://whitepapers.axis.com/en-us/bitrate-control-for-ip-video),
March 2023, MBR section (reviewed 2026-10-16). It describes temporary overshoot;
this specification's fail-closed evidence rules are our implementation contract,
not a manufacturer-provided universal burst bound.

## 5. CCTV-03 — recording storage

```dart
enum CctvStorageSizingBasis { expectedEstimate, guaranteedUpperBound }

enum CctvCopyRole { primary, mirror, archive, projectDefined }

final class CctvRecordingAssignment {
  final String encodedStreamId;
  final String poolId;
  final String copyRoleCode;
  final Elv5EngineeringValue<BitRate> recordingBitRate;
  final Elv5ResolvedField<CctvRateEvidence> recordingRateEvidence;
}

final class CctvRecordingScheduleSegment {
  final String segmentId;
  final Elv5UtcWindow? absoluteWindow;
  final Elv5RecurrenceRule? recurrence;
}

final class CctvStorageRedundancyModel {
  final String modelCode;
  final Ratio usableFraction;
  final Elv5SourceRef source;
}

final class Cctv03Input {
  final Elv5InputHeader header;
  final String poolId;
  final Elv5UtcWindow horizon;
  final Elv5TemporalPolicy temporalPolicy;
  final CctvStorageSizingBasis sizingBasis;
  final List<CctvRecordingAssignment> assignments;
  final List<CctvRecordingScheduleSegment> schedule;
  final Ratio reserveMultiplier;
  final CctvStorageRedundancyModel? redundancy;
}

final class Cctv03Output {
  final Duration uniqueRecordedTime;
  final ByteCapacity usableBytesCeil;
  final ByteCapacity? rawBytesCeil;
  final Elv5Assessment retentionGuaranteeAssessment;
}
```

Pool-level aggregation is exact rational before one declared ceil. Duplicate `(streamId,poolId,copyRole)` identity is invalid.

## 6. CCTV-04 — CCTV PoE context

```dart
final class Cctv04Input {
  final Elv5InputHeader header;
  final String pseContextId;
  final List<String> cctvConsumerIds;
  final Elv4PowerEvidenceRef pwr06;
}

final class Cctv04Output {
  final Power globalDemand;
  final Power globalAvailable;
  final Power globalMargin;
  final Power cctvContribution;
  final String elv4EvaluationId;
}
```

The contribution is informational context over the same immutable physical result. It is not a second source calculation.

## 7. CCTV-05 — recorder/VMS capacity

```dart
enum CctvRecorderAccountingBasis { device, encodedStream, licenseChannel }

final class CctvRecorderAssignment {
  final String recorderId;
  final String cameraId;
  final String encodedStreamId;
  final String licenseChannelId;
}

final class CctvRecorderLimits {
  final BigInt? deviceChannels;
  final BigInt? encodedStreamChannels;
  final BigInt? licenseChannels;
  final BitRate? maxIngress;
  final BitRate? maxEgress;
  final ByteCapacity? usableStorage;
  final Set<String> codecProfiles;
}

final class Cctv05Input {
  final Elv5InputHeader header;
  final String recorderId;
  final CctvRecorderAccountingBasis accountingBasis;
  final List<CctvRecorderAssignment> assignments;
  final CctvRecorderLimits limits;
  final Elv5EvidenceRef cctv02;
  final Elv5EvidenceRef cctv03;
  final BitRate? declaredConcurrentEgress;
}

final class Cctv05Output {
  final BigInt consumedChannels;
  final BitRate ingress;
  final BitRate? egress;
  final ByteCapacity requiredUsableStorage;
  final Map<String, Elv5Assessment> constraintAssessment;
}
```

Ingress, egress, channel/license grouping, codec compatibility and storage are independent constraints. An absent egress limit never becomes a PASS for egress; it is outside the selected claim unless policy requires it.

## 8. CCTV-06 — cable/link basis

```dart
final class Cctv06Input {
  final Elv5InputHeader header;
  final String linkId;
  final List<Elv5RealizedLinkSectionRef> orderedSections;
  final Elv5PolicyEditionRef linkPolicy;
  final List<Elv4PowerEvidenceRef> applicablePowerSegments;
}

final class Cctv06Output {
  final Length realizedLength;
  final String mediumCode;
  final String interfaceCode;
  final Elv5Assessment linkCompositionAssessment;
  final Elv5Assessment physicalPathAssessment;
}
```

No estimated room distance is permitted when realized route evidence is required.

## 9. LAN-01 — permanent link and channel length

```dart
enum LanSectionRole { permanent, patch, explicitAllowance }

final class LanLinkSection {
  final String sectionId;
  final LanSectionRole role;
  final Elv5EngineeringValue<Length> installedLength;
  final bool allowanceAlreadyIncluded;
}

final class Lan01Input {
  final Elv5InputHeader header;
  final String linkId;
  final List<LanLinkSection> orderedSections;
  final Elv5PolicyEditionRef cablingPolicy;
}

final class Lan01Output {
  final Length permanentLength;
  final Length patchLength;
  final Length channelLength;
  final Length explicitNotYetIncludedAllowance;
}
```

A section identity may not be counted twice unless the registered physical route explicitly models a repeated traversal.

## 10. LAN-02 — switch port capacity

```dart
final class LanPortInventoryEntry {
  final String portId;
  final String mediaCode;
  final Set<String> speedModes;
  final bool administrativelyReserved;
}

final class LanPortAssignment {
  final String endpointId;
  final String portId;
  final String selectedSpeedMode;
}

final class Lan02Input {
  final Elv5InputHeader header;
  final String switchId;
  final List<LanPortInventoryEntry> inventory;
  final List<LanPortAssignment> assignments;
  final Ratio spareRatio;
}

final class Lan02Output {
  final BigInt occupiedCompatiblePorts;
  final BigInt requiredSparePorts;
  final BigInt availableCompatiblePorts;
  final BigInt marginPorts;
  final List<String> incompatibleAssignmentIds;
}
```

Spare count uses the exact policy-defined ceiling. Reserved inventory is represented as inventory state, not duplicated demand.

## 11. LAN-03 — LAN PoE context

```dart
final class Lan03Input {
  final Elv5InputHeader header;
  final String pseContextId;
  final List<String> lanConsumerIds;
  final Elv4PowerEvidenceRef pwr06;
}

final class Lan03Output {
  final Power globalDemand;
  final Power globalAvailable;
  final Power globalMargin;
  final Power lanContribution;
  final String elv4EvaluationId;
}
```

Same physical evidence rule as CCTV-04.

## 12. LAN-04 — copper compatibility basis

```dart
final class LanPassiveSectionCapability {
  final String sectionId;
  final String mediumCode;
  final String connectorCode;
  final String categoryCode;
  final String shieldingCode;
  final Set<String> supportedSpeedModes;
}

final class Lan04Input {
  final Elv5InputHeader header;
  final String linkId;
  final String requiredSpeedMode;
  final List<LanPassiveSectionCapability> orderedPath;
  final Elv5PolicyEditionRef compatibilityPolicy;
  final Elv5EvidenceRef lan01;
}

final class Lan04Output {
  final String limitingSectionId;
  final Set<String> pathSupportedSpeedModes;
  final Elv5Assessment interfaceAssessment;
  final Elv5Assessment shieldingEvidenceAssessment;
}
```

A matching main cable category cannot override an incompatible patch cord, connector or section.

## 13. LAN-05 — bidirectional fiber loss budget

```dart
final class LanOpticalDirectionInput {
  final String directionCode;
  final String txOpticRef;
  final String rxOpticRef;
  final Elv5EngineeringValue<LevelDbm> txMin;
  final Elv5EngineeringValue<LevelDbm> txMax;
  final Elv5EngineeringValue<LevelDbm> receiverSensitivity;
  final Elv5EngineeringValue<LevelDbm> receiverOverload;
  final List<Elv5FiberSection> fiberSections;
  final List<Elv5OpticalLossEvent> lossEvents;
  final LossDb requiredSensitivityMargin;
  final String wavelengthCode;
  final Elv5OpticalReachProfile? reachProfile;
}

final class Lan05Input {
  final Elv5InputHeader header;
  final String opticalLinkId;
  final LanOpticalDirectionInput forward;
  final LanOpticalDirectionInput reverse;
}

final class LanOpticalDirectionOutput {
  final Elv5Interval<LossDb> physicalLoss;
  final Elv5Interval<LevelDbm> receivedPower;
  final LossDb sensitivityMargin;
  final LossDb overloadMargin;
  final Elv5Assessment? reachCompatibility;
}

final class Lan05Output {
  final LanOpticalDirectionOutput forward;
  final LanOpticalDirectionOutput reverse;
}
```

Physical loss and design sensitivity margin remain separate. Optional reach/dispersion compatibility may be reported only from an exact registered reach profile; a passing optical power budget alone does not imply transmission reach at the selected rate.

## 14. LAN-06 — rack demand/capacity basis

```dart
enum LanRackCapacityBasis { grossWithExclusions, netUsable }

final class LanEquipmentEnvelope {
  final String equipmentId;
  final Elv5EngineeringValue<Elv5Rational> ruDemand;
  final Elv5EngineeringValue<Length>? depth;
  final Elv5EngineeringValue<Elv5Rational>? weightKg;
}

final class Lan06Input {
  final Elv5InputHeader header;
  final String rackId;
  final LanRackCapacityBasis capacityBasis;
  final List<LanEquipmentEnvelope> equipment;
  final Elv5Rational declaredRuCapacity;
  final Elv5Rational explicitExcludedRu;
  final Elv5Rational? declaredWeightCapacityKg;
  final Length? declaredDepthEnvelope;
}

final class Lan06Output {
  final Elv5Rational equipmentRuDemand;
  final Elv5Rational usableRuCapacity;
  final Elv5Rational freeRu;
  final Elv5Rational? totalWeightKg;
  final Length? maxEquipmentDepth;
  final Elv5Assessment layoutFit; // always NOT_ASSESSED in ELV5
}
```

RU basis is the ELV5 claim. Weight/depth may be carried as demand evidence for ELV6, but actual slot/depth/thermal/cable-management fit remains `NOT_ASSESSED` unless a future process version explicitly extends the claim.

## 15. LAN-07 — patch-panel utilization

```dart
final class LanPatchPort {
  final String portId;
  final String interfaceCode;
  final bool reserved;
}

final class LanPatchAssignment {
  final String endpointId;
  final String panelPortId;
  final String destinationRef;
}

final class Lan07Input {
  final Elv5InputHeader header;
  final String panelId;
  final List<LanPatchPort> ports;
  final List<LanPatchAssignment> assignments;
  final Ratio spareRatio;
}

final class Lan07Output {
  final BigInt occupied;
  final BigInt free;
  final BigInt requiredSpare;
  final BigInt freeAfterReserve;
  final List<String> invalidMappings;
}
```

## 16. ACS-01 — door role completeness

```dart
final class AcsRoleAlternative {
  final String alternativeId;
  final List<AcsRequiredRole> requiredRoles;
}

final class AcsRequiredRole {
  final String roleCode;
  final int minCount;
  final int maxCount;
  final bool shareable;
}

final class AcsRoleAssignment {
  final String componentId;
  final String roleCode;
  final String slot;
}

final class Acs01Input {
  final Elv5InputHeader header;
  final String doorAssemblyId;
  final List<AcsRoleAlternative> allowedAlternatives;
  final List<AcsRoleAssignment> assignments;
}

final class Acs01Output {
  final String? satisfiedAlternativeId;
  final List<String> missingRoleCodes;
  final List<String> overAssignedRoleCodes;
}
```

Role satisfaction is explicit and multiplicity-aware; human labels never imply roles.

## 17. ACS-02 — controller resource capacity

```dart
enum AcsResourceKind { reader, relay, supervisedInput, genericInput, genericOutput }

final class AcsControllerResource {
  final String resourceId;
  final AcsResourceKind kind;
  final Set<String> supportedModes;
}

final class AcsResourceClaim {
  final String doorAssemblyId;
  final String resourceId;
  final String roleCode;
}

final class Acs02Input {
  final Elv5InputHeader header;
  final String controllerId;
  final List<AcsControllerResource> resources;
  final List<AcsResourceClaim> claims;
  final Map<AcsResourceKind, Ratio> sparePolicy;
}

final class Acs02Output {
  final Map<AcsResourceKind, BigInt> occupied;
  final Map<AcsResourceKind, BigInt> requiredSpare;
  final Map<AcsResourceKind, BigInt> margin;
}
```

Each resource kind is assessed separately; one passing kind cannot mask another failing kind.

## 18. ACS-03 — lock demand and terminal voltage

```dart
enum AcsLockState { holding, active, startup, released }

final class AcsLockStateLoad {
  final AcsLockState state;
  final Elv5EngineeringValue<Current> current;
  final Duration? pulseDuration;
}

final class Acs03Input {
  final Elv5InputHeader header;
  final String lockId;
  final List<AcsLockStateLoad> stateLoads;
  final AcsLockState selectedState;
  final Elv4PowerEvidenceRef pwr01;
  final Elv4PowerEvidenceRef pwr03;
}

final class Acs03Output {
  final Current selectedLockDemand;
  final Voltage terminalVoltage;
  final Current sharedTrunkCurrent;
}
```

Dry-contact control adjacency is never treated as a conductive power source.

## 19. ACS-04 — ACS supply requirement

```dart
final class Acs04Input {
  final Elv5InputHeader header;
  final String sourceRequirementContextId;
  final Elv4PowerEvidenceRef pwr01;
  final Elv4PowerEvidenceRef pwr02;
}

final class Acs04Output {
  final Power globalDemand;
  final Power requiredCapability;
  final Power availableCapability;
  final Power margin;
}
```

The source-owned requirement set composes applicable requirements once per physical source.

## 20. ACS-05 — ACS backup requirement

```dart
final class Acs05Input {
  final Elv5InputHeader header;
  final String protectedSequenceId;
  final Elv4PowerEvidenceRef pwr04;
  final List<Elv5SequenceContributionRef> acsContributions;
}

final class Acs05Output {
  final Energy globalRequiredEnergy;
  final Energy availableUsableEnergy;
  final Energy globalMargin;
  final Energy acsContribution;
}
```

Contribution reporting never removes concurrent non-ACS protected loads.

## 21. ACS-06 — door control/supply/release topology

```dart
enum AcsLockSafetyMode { failSafe, failSecure, projectDefined }
enum AcsReleaseCause { normalAccess, requestToExit, fireRelease, emergencyBreakGlass, powerFailure }

enum AcsExpectedLockOutcome { energized, deEnergized, unlocked, locked, projectDefined }

final class AcsReleaseTruthRow {
  final AcsReleaseCause cause;
  final AcsExpectedLockOutcome expectedOutcome;
  final Set<String> requiredEvidenceRoles;
}

final class Acs06Input {
  final Elv5InputHeader header;
  final String doorAssemblyId;
  final AcsLockSafetyMode safetyMode;
  final List<AcsReleaseTruthRow> releaseTruthTable;
  final List<Elv5TypedPathRef> dataControlPaths;
  final List<Elv5TypedPathRef> powerFeedPaths;
  final List<Elv5TypedPathRef> monitoringPaths;
  final List<Elv5TypedPathRef> releasePaths;
}

final class Acs06Output {
  final Elv5Assessment controlPath;
  final Elv5Assessment requiredFeed;
  final Elv5Assessment releasePolicy;
  final List<AcsReleaseCause> unprovenReleaseCases;
}
```

The release truth table is a technical topology contract only. It does not certify legal egress/fire compliance; ELV7 owns verified rule applicability. A device name such as `EMERGENCY` or `FIRE` never proves release behavior.

## 22. FA-01 — fire loop device/address capacity

```dart
final class FaAddressDomain {
  final String domainId;
  final Set<BigInt> allowedAddresses;
  final Set<BigInt> reservedAddresses;
}

final class FaAddressAssignment {
  final String deviceId;
  final String expansionProfileRef;
  final Set<BigInt> expandedAddresses;
}

final class Fa01Input {
  final Elv5InputHeader header;
  final String loopId;
  final FaAddressDomain domain;
  final List<FaAddressAssignment> assignments;
  final BigInt deviceLimit;
  final BigInt addressLimit;
}

final class Fa01Output {
  final BigInt physicalDeviceCount;
  final BigInt consumedAddressCount;
  final BigInt deviceMargin;
  final BigInt addressMargin;
  final Set<BigInt> collisions;
}
```

Full address sets are compared; start-address uniqueness alone is insufficient.

## 23. FA-02 — standby/alarm current

```dart
enum FaDeviceState { standby, alarm, active, startup, projectDefined }

final class FaDeviceStateCurrent {
  final String deviceId;
  final FaDeviceState state;
  final Elv5EngineeringValue<Current> current;
}

final class Fa02Input {
  final Elv5InputHeader header;
  final String electricalContextId;
  final List<FaDeviceStateCurrent> currents;
  final List<Elv5StateSelection> selectedStates;
  final List<String> requiredMembershipIds;
}

final class Fa02Output {
  final Map<String, Current> currentByCase;
  final List<String> missingLoadIds;
}
```

A known subtotal remains explicitly partial when required members are missing.

## 24. FA-03 — fire electrical basis

```dart
final class Fa03Input {
  final Elv5InputHeader header;
  final String electricalDomainId;
  final String electricalModelCode;
  final Elv4PowerEvidenceRef pwr03;
  final Elv5PolicyEditionRef electricalLimitPolicy;
}

final class Fa03Output {
  final Voltage terminalVoltage;
  final String supportedModelCode;
  final Elv5Assessment declaredLimitAssessment;
}
```

A closed signal loop is not automatically a supported dual-fed power network.

## 25. FA-04 — fire supply requirement

```dart
final class Fa04Input {
  final Elv5InputHeader header;
  final String sourceRequirementContextId;
  final Elv5EvidenceRef fa02;
  final Elv4PowerEvidenceRef pwr01;
  final Elv4PowerEvidenceRef pwr02;
}

final class Fa04Output {
  final Power globalDemand;
  final Power requiredCapability;
  final Power availableCapability;
  final Power margin;
}
```

All concurrent non-fire loads on a shared source remain in the physical total.

## 26. FA-05 — standby/alarm backup

```dart
final class FaSequencePhase {
  final String phaseId;
  final String stateCaseId;
  final Duration duration;
}

final class Fa05Input {
  final Elv5InputHeader header;
  final String protectedSequenceId;
  final List<FaSequencePhase> orderedPhases;
  final Elv5EvidenceRef fa02;
  final Elv4PowerEvidenceRef pwr04;
}

final class Fa05Output {
  final Energy requiredSequenceEnergy;
  final Energy availableUsableEnergy;
  final Energy margin;
  final List<String> uncoveredPhaseIds;
}
```

Durations are explicit policy facts. Illustrative hours are never defaults.

## 27. FA-06 — notification circuit capacity

```dart
final class FaNotificationDeviceAssignment {
  final String deviceId;
  final String outputId;
  final Elv5EngineeringValue<Current> activeCurrent;
  final Elv5EngineeringValue<Current>? startupCurrent;
}

final class Fa06Input {
  final Elv5InputHeader header;
  final String circuitId;
  final List<FaNotificationDeviceAssignment> devices;
  final Current outputCurrentLimit;
  final Elv4PowerEvidenceRef pwr01;
  final Elv4PowerEvidenceRef pwr03;
}

final class Fa06Output {
  final BigInt activeDeviceCount;
  final Current activeCurrent;
  final Current? startupCurrent;
  final Current outputCurrentMargin;
  final Voltage worstTerminalVoltage;
}
```

No sound-pressure or visual-coverage conclusion is emitted by this process version.

## 28. FA-07 — fire signal topology integrity

```dart
final class FaSignalEdge {
  final String edgeId;
  final String fromPortId;
  final String toPortId;
  final String edgeKind;
}

final class Fa07Input {
  final Elv5InputHeader header;
  final String loopId;
  final String sourcePortId;
  final String returnPortId;
  final List<FaSignalEdge> directedEdges;
  final Set<String> memberDeviceIds;
  final Elv5EvidenceRef fa01;
  final Elv5PolicyEditionRef topologyPolicy;
}

final class Fa07Output {
  final bool returnClosed;
  final List<String> illegalBranchEdgeIds;
  final Elv5Assessment addressTopologyMatch;
}
```

Presence of isolator components is not proof of short-circuit survivability without a separately supported model.

## 29. FA-08 — fire cable policy/evidence basis

```dart
final class FaRouteEnvironmentEvidence {
  final String routeId;
  final Set<String> environmentCodes;
  final List<Elv5SourceRef> sources;
}

final class Fa08Input {
  final Elv5InputHeader header;
  final List<Elv5CableEditionRef> cableEditions;
  final List<FaRouteEnvironmentEvidence> routeEvidence;
  final Elv5PolicyEditionRef selectedPolicy;
}

final class Fa08Output {
  final Elv5Assessment cablePolicyMatch;
  final Elv5Assessment routeEvidenceCompleteness;
  final Elv5Assessment verifiedCompliance; // normally UNRESOLVED/NOT_ASSESSED in ELV5
}
```

A fictional or project-authored policy can support technical policy matching but cannot produce verified jurisdictional compliance.

## 30. Process output envelope

Typed outputs are converted to the common immutable evaluation only after the typed kernel returns.

```dart
final class Elv5EvaluationDraft {
  final Elv5EngineeringNodeKeyV3 nodeKey;
  final String inputFingerprint;
  final String policyFingerprint;
  final Elv5Execution execution;
  final Elv5Completion completion;
  final Elv5Assessment assessment;
  final List<Elv5DimensionResult> dimensions;
  final List<Elv5CalculationStep> steps;
  final List<Elv5Finding> findings;
  final List<Elv5ConsumedEvidenceRef> consumedEvidence;
  final String deterministicOutputHash;
}
```

The common envelope is not permission to erase typed output semantics. Process-specific output codecs must round-trip every field needed to explain and re-verify the result.

## 31. Required code-generation/registry invariants

Implementation MUST make the 27 registrations explicit and statically reviewable. Recommended construction:

```dart
final definitions = <Elv5ProcessCode, Elv5TypedProcessDefinition<Object, Object>>{
  Elv5ProcessCode.cctv01: Cctv01Definition(),
  // ... exactly one entry for every remaining code ...
  Elv5ProcessCode.fa08: Fa08Definition(),
};
```

CI rejects:

- a process in `process-registry.json` with no typed definition;
- a typed definition with no registered process code;
- disagreement in legal scopes or required dimension codes;
- a typed input containing free-form executable expression/formula fields;
- an output field that affects assessment but is omitted from deterministic output hashing;
- an engineering value whose basis/applicability is discarded by the application-layer resolver;
- any repository, Drift, UI or platform access from `Elv5TypedProcessDefinition.calculate/evaluate`.

## 32. Implementation package recommendation

```text
packages/engineering_core/lib/src/elv5/processes/
  cctv/
    cctv_01.dart
    cctv_02.dart
    ...
  lan/
    lan_01.dart
    ...
  acs/
    acs_01.dart
    ...
  fire_alarm/
    fa_01.dart
    ...
  registry.dart
```

Application-layer resolvers/adapters live outside the pure kernel package. Drift rows and JSON maps must be converted to typed inputs before entering `calculate()`. These paths are the default tracked production layout; a layout-only rename requires synchronized registry/manifest updates but does not change engineering semantics when public symbols and dependency direction remain unchanged.

## 33. Acceptance rule

A process is not implemented merely because its formula unit test passes. Runtime acceptance for each code requires:

1. strict public-command setup of its ELV5-owned inputs;
2. capture from real file SQLite plus canonical ELV3/ELV4 evidence;
3. application-layer typed resolution into the input type in this document;
4. pure deterministic calculation;
5. complete dimension/status aggregation;
6. guarded publication to immutable evaluation + current pointer;
7. restart/readback preserving typed semantics and hashes;
8. both registered positive and negative/unsupported oracle through the production dispatcher.

This document is specification only and creates no runtime PASS by itself.
