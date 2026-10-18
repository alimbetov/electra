# P3 — CCTV calculation implementation

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P1/P2 and relevant ELV3/ELV4 kernels.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [typed process API](typed-process-api.md); [engineering primitives](engineering-primitives-contract.md); [CCTV code-level dossiers](process-specifications/cctv-processes.md); [Flutter performance contract](flutter-performance-contract.md).

Inherited implementation and mandatory new extensions: [baseline contract P3](implemented-baseline.md#p3); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P3-001 | Implement CCTV-01 rectilinear plane geometry with explicit frame/transform identity, model applicability and bounded FOV/footprint outputs | P3-T01 |
| ELV5-P3-002 | Implement CCTV-02 unique encoded streams, directed subscriptions, expected/peak payload bitrate and explicit physical wire-rate model when claimed | P3-T02 |
| ELV5-P3-003 | Implement CCTV-03 deterministic recording interval expansion/union, exact byte integration and explicit estimate/guarantee/reserve/redundancy basis | P3-T03 |
| ELV5-P3-004 | Implement CCTV-04 contextual PoE over one complete shared physical source/PWR-06 evidence identity | P3-T04 |
| ELV5-P3-005 | Implement CCTV-05 independent channels/licenses/ingress/egress/codec/usable-storage constraints using canonical recorder definition evidence | P3-T05 |
| ELV5-P3-006 | Implement CCTV-06 realized link/media/power applicability without duplicate path/resource ownership | P3-T06 |
| ELV5-P3-007 | Emit structured exact steps/findings/provenance/claim scope and precise old/new dependencies for all CCTV outputs | P3-T07 |
| ELV5-P3-008 | Qualify positive/negative/boundary, restart/history, timezone/frame and shared LAN/PSE cases through public commands | P3-T08 |

## Normative code-level binding

The package descriptions below remain the package-level summary. Runtime implementation MUST follow the matching CCTV-01…06 entries in [process-specifications/cctv-processes.md](process-specifications/cctv-processes.md) for all 25 required sections. In particular, P3 may not locally reinterpret:

```text
applicability
operating cases
exact equations / interval endpoints
rounding/ceil boundary
worst-case selection
requirement composition
comparison/margin convention
governing/limiting logic
missing/unsupported semantics
dependency set
trace equation codes
complexity/resource model
Dart semantic surface
positive/boundary/negative/adversarial/cross-discipline vectors
```

Implementation priority inside P3 is **CCTV-02 then CCTV-03**, because flow accounting and storage/time integration stress the reusable exact/set/time/performance primitives first.

## CCTV-01 — camera coverage geometry

Kernel receives typed geometry only; storage/UI maps are resolved before calculation.

Mandatory engineering inputs include:

```text
camera optical centre in an explicit Elv5FrameRef
camera-to-frame rotation / exact transform-chain fingerprint
sensor width/height
focal length
flat target plane
project target zone polygon
lens model discriminator
obstruction-model discriminator
optional active horizontal/vertical pixel count
```

The first runtime model is rectilinear pinhole + flat target plane. Ray/plane denominator, behind-camera and horizon/near-parallel cases are explicit model outcomes. General rotations use captured frame transforms; two coordinates with different frame IDs cannot be combined implicitly.

Required outputs include horizontal/vertical FOV bounded intervals, bounded footprint, zone intersection and model applicability. Optional technical pixel density may be produced only from explicit active pixel counts. It does not imply DORI recognition/identification, facial identification, legal evidence quality or visibility through obstructions.

Unsupported fisheye/distortion/occlusion model is BLOCKED/UNRESOLVED according to the process contract; it cannot inherit a geometry PASS from the pinhole footprint.

## CCTV-02 — bandwidth and network copies

Encoded stream identity, forwarding subscription identity and recording assignment identity are distinct.

Each stream carries expected payload bitrate and optional guaranteed/peak payload bitrate with evidence basis. Each subscription declares receiver, delivery mode and ordered network-edge path. Two unicast receivers sharing one edge create two copies on that edge. Multicast de-duplication occurs only under an explicitly registered multicast distribution model/tree.

`bitrate payload` is not automatically `physical wire rate`. A physical edge-capacity comparison requires a versioned transport overhead model and exact capacity evidence. Missing overhead model never triggers a hidden universal +5%/+10% assumption.

Expected and peak outputs remain independent. Expected storage planning cannot silently substitute for peak link capacity; peak cannot silently replace expected recording bitrate.

The production implementation follows the dossier’s O(F) keyed flow-edge accounting model. It must not scan every stream against every network edge. Governing capacity is the exact edge/recorder case with smallest signed headroom; multicast tree de-duplication is identity-based and explicit.

## CCTV-03 — storage and retention basis

One recording pool aggregate captures together:

```text
explicit UTC horizon
temporalPolicy: IANA timeZoneId + captured timezone rules evidence + DST gap/overlap rule
recording assignments keyed by (stream,pool,copyRole)
schedule segment set
sizingBasis EXPECTED_ESTIMATE or GUARANTEED_UPPER_BOUND
exact reserveMultiplier
optional exact redundancy model/ref
policy edition/ref/hash
```

Recurrence is expanded under the pinned temporal policy and converted to half-open UTC intervals `[start,end)`. Interval union is computed before integration so overlaps are counted once. Host timezone and device tzdb defaults do not participate in results.

For each unique assignment:

```text
exactBytes = bitrateBitsPerSecond × uniqueRecordedSeconds / 8
```

Pool algorithm:

```text
sum exact rational bytes for all unique assignments
apply reserve once
ceil once to required usable bytes
if an exact redundancy model applies:
  divide usable requirement by declared usable fraction
  apply declared final raw-byte ceil once
```

An expected/typical bitrate may support an estimate only. A guaranteed retention claim requires the process-declared guaranteed upper-bound evidence; reserve does not upgrade evidence certainty.

The O(N log N) interval union executes as a medium/large pure kernel under the performance executor; it may not hold an SQLite transaction open while sorting/merging 10,000 schedule segments.

## CCTV-04 — shared PoE context

CCTV-04 references the exact immutable global PWR-06 evaluation used for the physical PSE/source context. It reports:

```text
global physical demand
global available budget
global margin
selected CCTV contribution
same ELV4 evaluation identity/hash
```

LAN or other concurrent loads do not disappear under a CCTV filter. CCTV contribution is an explanatory breakdown, never a separate source calculation.

## CCTV-05 — recorder/VMS capacity

Recorder accounting basis is explicit:

```text
DEVICE
ENCODED_STREAM
LICENSE_CHANNEL
```

Channel/license count, ingress, optional egress, codec compatibility and usable storage are evaluated independently. One camera with two encoded streams intentionally produces different channel usage under DEVICE and ENCODED_STREAM accounting while ingress remains the sum of actual incoming streams.

Recorder/VMS capability data resolves from an exact immutable canonical catalog/component definition edition. ELV5 does not own an independently editable copy of recorder limits.

Storage claim scope propagates from CCTV-03: estimate-based storage cannot be relabelled guaranteed merely because recorder usable bytes are large enough.

## CCTV-06 — realized cable/link basis

CCTV-06 consumes realized route/link sections and selected policy. No room-centre distance or schematic straight-line fallback is allowed where realized path evidence is required.

Powered-link context references exact applicable PWR-06 segment evidence. Fiber/non-powered media cannot satisfy PoE merely because endpoints are CCTV devices. Physical route, media/interface compatibility and power applicability remain separate dimensions.

## Dependencies and invalidation

At minimum, dependency identity distinguishes:

```text
camera pose/frame/transform
intrinsics/lens definition
stream profile and stream-membership set
subscription set and ordered edge paths
recording pool/assignment/schedule sets
temporal policy/timezone rules evidence
reserve/redundancy/policy refs
recorder definition/accounting assignment set
realized link section set
exact upstream PWR evaluation/pointer generation
MISSING markers for absent required evidence
```

Replacement invalidates `union(oldClosure,newClosure)`. Changing a camera bitrate invalidates exact bandwidth/storage/recorder consumers; it does not invalidate an unrelated ACS door-role process. Moving a subscription from one edge to another invalidates both the removed and added edge dependants.

## Public-command and persistence path

Primary P3 qualification uses the production path:

```text
REPLACE_CAMERA_STREAMS / REPLACE_RECORDING_ASSIGNMENTS /
REPLACE_RECORDER_ASSIGNMENTS / REPLACE_LINK_COMPOSITION
  -> schema-24 file SQLite
  -> CALCULATE_DISCIPLINE_PROCESS
  -> production capture + typed resolver
  -> Elv5CalculationExecutor when workload requires off-main execution
  -> CCTV typed kernel
  -> guarded publication
  -> targeted workspace projection
  -> close/reopen verification
```

P3 tests do not populate internal repositories directly as their only acceptance setup.

## Required adversarial/engineering cases

P3 qualification includes the complete five-class vector inventory from the CCTV dossiers. At minimum:

- mixed coordinate frames without transform → reject/block;
- horizon/behind-plane camera ray → not complete PASS;
- unsupported fisheye/occlusion → no borrowed pinhole PASS;
- one stream / two unicast receivers on common edge → two edge copies;
- multicast de-dup only with exact multicast model;
- payload bitrate present but required wire-overhead evidence absent → physical capacity dimension unresolved;
- exact edge-capacity boundary and +1 bit/s overflow;
- overlapping recording intervals → counted once;
- equivalent interval split/merge → same canonical result;
- one-bit-second storage fixture proves pool-level ceil;
- DST transition fixture under captured temporal policy;
- EXPECTED_ESTIMATE large disk → no guaranteed-retention PASS;
- missing upper bitrate bound under guarantee basis → unresolved;
- duplicate `(stream,pool,copyRole)` → deterministic rejection;
- DEVICE vs ENCODED_STREAM recorder accounting divergence;
- shared PSE retains non-CCTV loads;
- unknown realized route → no room-distance estimate;
- close/reopen preserves hashes/provenance and frozen historical result.

## Performance obligations

P3 must satisfy [flutter-performance-contract.md](flutter-performance-contract.md):

- CCTV-02 flow accounting is keyed by canonical flow-edge identity and meets dossier complexity;
- CCTV-03 schedule expansion/union runs off UI isolate for medium/large native workloads;
- rapid bitrate/schedule edits coalesce obsolete pending recalculation;
- exact input-fingerprint reuse may avoid duplicate pure work but cannot publish stale CURRENT;
- capture uses bounded bulk stream/subscription/schedule loads;
- visible workspace cards update without rebuilding hidden stream/trace rows.

## Exit

P3 runtime acceptance requires P3-T01…T08, both primary POS/NEG entries for CCTV-01…06, all CCTV boundary/adversarial/cross-discipline dossier vectors and required L0–L6/performance coverage at the same accepted source SHA and authority fingerprint.

This document is a hardened design contract, not proof of source implementation.

## Rate evidence qualification

CCTV-02/03/05 MUST implement the `CctvRateEvidence` claim/window/boundary rules in
`typed-process-api.md`. A configured limit or measured/window average is not a
guaranteed peak; a window bound is not a pointwise bound for arbitrary recording
intervals. Acceptance includes the 8/0 Mbit/s two-second counterexample and
propagation of missing or incompatible evidence to every downstream claim.
