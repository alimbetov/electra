# ELV5 CCTV — production code-level process dossiers

Status: DESIGN HARDENING / RUNTIME NOT STARTED  
Parent: `process-code-level-specification.md`, `process-contracts.md`, `calculation-engine-contract.md`.

All reference-vector values are fictional product-neutral fixtures. They prove arithmetic and semantics only.

---

## CCTV-01 — Camera coverage geometry

### 1. Physical meaning
Computes the geometrically projected footprint of a rectilinear camera model on a declared target plane/zone and bounded horizontal/vertical field of view. It proves geometric basis only: not visibility through obstacles, DORI, recognition, legal identification, illumination or normative compliance.

### 2. Applicability matrix
| Condition | Result |
|---|---|
| Rectilinear pinhole intrinsics, rigid captured frame, planar target | APPLICABLE |
| Supported transform chain with bounded uncertainty | APPLICABLE_WITH_BOUNDS |
| Fisheye/panoramic/warped lens without explicit model | UNSUPPORTED |
| Target ray parallel to plane or intersection behind camera | UNRESOLVED for affected ray |
| Occlusion requested but no supported occlusion model | NOT_ASSESSED / unsupported claim |
| Mixed frames without captured transform | BLOCKED |

### 3. Exact typed inputs
`CameraId`, `FrameRef cameraFrame`, `Point3<Length> opticalCenter`, `Rotation3 cameraToProject`, `Length sensorWidth`, `Length sensorHeight`, `Length focalLength`, `Plane3 targetPlane`, ordered `Polygon2 targetZone`, optional bounded pose/intrinsic intervals, `GeometryModelEditionRef`, and explicit obstruction-model declaration.

### 4. Evidence requirements
Intrinsics require exact catalog/manufacturer/project-specified edition; pose/target geometry require captured project geometry with frame fingerprint; any measurement uncertainty is retained as an interval. Typical focal metadata may support an estimate but cannot satisfy a guaranteed geometric bound when policy requires guaranteed evidence.

### 5. Operating cases
`GEOMETRY_CAPTURED` is mandatory. If bounded pose/intrinsic uncertainty is present, the same case carries conservative input intervals; it is not replaced by a nominal-only second result.

### 6. Mathematical model
Use a calibrated pinhole camera. Sensor corner coordinates in camera coordinates are `(±sensorWidth/2, ±sensorHeight/2, focalLength)`. Transform rays into project frame, intersect each with the target plane, order intersections consistently, then clip the footprint polygon against the target zone.

### 7. Equations
For sensor dimension `s` and focal length `f`:
`FOV = 2 * atan(s/(2f))`.
For ray `r(t)=o+t*d` and plane `n·x=c`:
`t=(c-n·o)/(n·d)`; valid only when denominator excludes zero and `t>0`.
Footprint area uses deterministic polygon shoelace arithmetic after projection into target-plane coordinates. Optional zone ratio is `A(intersection)/A(targetZone)` only when a policy explicitly asks for it.

### 8. Exact/bounded arithmetic
Lengths and transforms are exact or conservative intervals. `atan` uses `pinhole-angle-bounds.v1`; no floating midpoint decides PASS. Polygon clipping preserves deterministic vertex order and interval envelopes. Near-parallel denominators whose interval contains zero remain unresolved rather than forcing a huge finite intersection.

### 9. Worst-case selection
For requirement comparisons, select the adverse bound: minimum guaranteed covered area/ratio and maximum required excursion outside a constrained zone. If uncertainty can change topology/order of the polygon so a conservative bound cannot be proven, return unresolved rather than approximate.

### 10. Requirement composition
Compose only explicit project technical geometry requirements applicable to the camera/zone. DORI, obstruction, lighting and jurisdictional requirements are separate models/stages and cannot be inferred from footprint PASS.

### 11. Comparison equations
For minimum required zone ratio `Rmin`, `margin = RguaranteedLower - Rmin`. For maximum allowed footprint excursion `Emax`, `margin = Emax - Eupper`. Pure footprint/FOV dimensions may be informative with no PASS threshold when no such policy exists.

### 12. Margin equation
All numeric geometry margins use `positive = acceptable headroom`; angular/area/ratio margins remain in their own dimensions. No synthetic scalar combines unrelated geometry dimensions.

### 13. Governing-case algorithm
Evaluate model applicability, all four ray intersections, FOV bounds and requested zone comparisons. The governing dimension is the failed/unresolved mandatory geometry dimension; otherwise the smallest normalized policy headroom among dimensions that actually have a policy threshold.

### 14. Limiting-factor algorithm
Canonical priority: `MODEL_APPLICABILITY` → `FRAME_TRANSFORM` → `RAY_INTERSECTION` by corner order → explicit policy comparison with smallest signed margin. Record corner/edge ID where relevant.

### 15. Missing/unsupported behavior
Missing focal length, sensor dimension, target frame/plane or transform blocks affected mandatory dimensions. Unsupported lens/occlusion never falls back to pinhole. A nominal footprint may be exposed as non-qualifying diagnostic only if the contract explicitly marks it estimate-only.

### 16. Dependency set
Camera/intrinsics edition, pose/frame transform chain, target plane/zone geometry, geometry policy edition and all set/selector markers that determine those inputs. No ELV4 power dependency.

### 17. Calculation trace
Required equation codes include `CCTV01_FOV_BOUND_V1`, `CCTV01_SENSOR_CORNER_RAY_V1`, `CCTV01_PLANE_INTERSECTION_V1`, `CCTV01_POLYGON_CLIP_V1`, `CCTV01_AREA_V1`, and any policy comparison code. Trace stores exact operand refs and bounded outputs.

### 18. Complexity/resource bounds
Four primary rays are O(1). Polygon clipping is O(Vf*Vz) for the selected deterministic convex/simple clipping backend; shipping resource limits must bound zone vertices and transform-chain length before allocation. Qualification requires at least 256 target-zone vertices without UI jank.

### 19. Pseudocode
```text
requireSupportedPinhole(input)
frame = resolveTransform(cameraFrame, targetFrame)
for corner in canonicalSensorCorners:
  ray = transform(frame, pinholeRay(corner))
  hit = boundedPlaneIntersection(ray, targetPlane)
  requireForwardFinite(hit)
footprint = canonicalPolygon(hits)
clipped = clip(footprint, targetZone)
fovH = boundedFov(sensorWidth, focalLength)
fovV = boundedFov(sensorHeight, focalLength)
return evaluateGeometryDimensions(footprint, clipped, fovH, fovV)
```

### 20. Dart interfaces
```dart
final class Cctv01Input {
  final CameraId cameraId;
  final Elv5FrameRef cameraFrame;
  final Elv5Point3 opticalCenter;
  final Elv5Rotation3 orientation;
  final Elv5EngineeringValue<LengthQ> sensorWidth;
  final Elv5EngineeringValue<LengthQ> sensorHeight;
  final Elv5EngineeringValue<LengthQ> focalLength;
  final Elv5Plane3 targetPlane;
  final Elv5Polygon2 targetZone;
  final Elv5DefinitionRef geometryModel;
}
final class Cctv01Output { final Elv5Polygon2 footprint; final Elv5Polygon2 intersection; final Elv5Interval<AngleQ> hFov; final Elv5Interval<AngleQ> vFov; }
```

### 21. Positive reference vector
Camera normal to plane, distance 3 m, sensor 6×4 mm, focal 6 mm. Expected footprint 3×2 m, area 6 m²; horizontal FOV bounded around 0.927295218 rad and vertical around 0.643501109 rad. Geometry basis passes when target zone contains that footprint.

### 22. Boundary vector
One corner ray produces a denominator interval touching zero. Expected: that ray `UNRESOLVED`, overall required footprint dimension not PASS; no finite clamp. Separately, exact zone-ratio equality to an inclusive requirement yields margin 0 and PASS.

### 23. Negative vector
Valid pinhole geometry but required minimum zone ratio is 0.90 and guaranteed lower ratio is 0.84. Expected completed FAIL with margin -0.06; execution succeeds.

### 24. Adversarial vector
Same points supplied with shuffled polygon order, duplicated closing vertex, or a transform from the wrong frame. Canonical valid polygon reorder must hash identically where semantically unordered; wrong-frame transform must BLOCK rather than produce coordinates.

### 25. Cross-discipline vector
Camera uses the same canonical ELV3 mount/location geometry consumed by cable routing. Changing the mount invalidates CCTV-01 and route-dependent processes through dependency keys; CCTV-01 itself must not mutate ELV3 geometry or claim cable feasibility.

---

## CCTV-02 — Stream bandwidth and directed flow accounting

### 1. Physical meaning
Computes expected and peak encoded traffic carried by each realized directed network edge and recorder ingress from explicit stream/subscription topology. It is the authoritative ELV5 flow accounting basis; codec labels never synthesize bitrate unless a separately versioned model is explicitly selected.

### 2. Applicability matrix
| Condition | Expected | Peak | Wire rate |
|---|---|---|---|
| Explicit expected+peak payload bitrate and explicit paths | assess | assess | if overhead model exists |
| Expected only | assess | UNRESOLVED | derived only for expected if model allows |
| Unicast copies | one copy per receiver/path | same rule | same rule |
| Multicast with declared distribution tree | deduplicate shared tree edge per stream/group | same rule | same rule |
| “Multicast” label without tree/group semantics | BLOCKED | BLOCKED | BLOCKED |
| Codec/resolution/fps but no bitrate model | BLOCKED | BLOCKED | BLOCKED |

### 3. Exact typed inputs
`EncodedStreamId`, expected/peak `BitRateQ`, `CameraId`, `SubscriptionId`, source/receiver endpoint IDs, `DeliveryMode {unicast,multicast}`, ordered directed `NetworkEdgeId` paths or multicast tree edges, recorder assignment role, optional `TransportOverheadModelRef`, and optional edge capacity facts for technical headroom display.

### 4. Evidence requirements
Bitrate carries basis (`manufacturerGuaranteed`, measured, projectSpecified, estimated, etc.). Guaranteed capacity qualification requires a guaranteed/upper-bound peak basis when the policy demands it. Paths come from captured realized network topology; membership sets and multicast group/tree definitions are fingerprinted.

### 5. Operating cases
At minimum `EXPECTED_PAYLOAD` and `PEAK_PAYLOAD`. `WIRE_RATE_EXPECTED`/`WIRE_RATE_PEAK` exist only when a compatible explicit overhead model is applicable. Recorder ingress is evaluated for expected and peak where both are known.

### 6. Mathematical model
Build a canonical flow-copy set. Unicast identity is `(streamId, subscriptionId, edgeId)`; multicast identity on a shared tree edge is `(streamId, multicastGroupId, edgeId)` so multiple receivers downstream of the same branching edge do not duplicate upstream traffic. Sum bitrates by edge and case. Recorder ingress sums unique incoming recording flow identities assigned to that recorder.

### 7. Equations
For edge `e` and case `c`:
`PayloadLoad(e,c)=Σ_s bitrate(s,c)*copies(s,e,c)`.
For explicit rational overhead `h>=1` applicable to edge/media:
`WireLoad(e,c)=PayloadLoad(e,c)*h`.
Recorder ingress `Ingress(r,c)=Σ_f bitrate(stream(f),c)` for canonical unique recording flows terminating at `r`.
If capacity `C(e)` is supplied: `utilization=load/C`; `margin=C-load`.

### 8. Exact/bounded arithmetic
Bitrates and overhead factors are exact rationals; sums do not use binary floating point. Multiplication uses bounded exact arithmetic resource limits from hardening v2. Conversion to display Mbps occurs after verdict. No integer truncation of bit/s.

### 9. Worst-case selection
Peak and expected are never merged. For capacity risk, governing traffic case is the case with the smallest signed capacity margin among required cases, ordinarily peak when both are comparable. If peak is missing, expected may still be reported but cannot stand in for peak.

### 10. Requirement composition
Edge capacity, oversubscription or wire-overhead requirements apply only through explicit project/network policy editions. If LAN supplies an exact realized edge capacity, it is consumed as evidence; CCTV-02 does not invent Ethernet line-rate capability from a label.

### 11. Comparison equations
Upper-capacity comparison: `margin(e,c)=C(e)-Load(e,c)`. Inclusive PASS iff conservative lower margin >=0. Optional maximum-utilization policy `Umax`: `marginRatio=Umax-Load/C`.

### 12. Margin equation
Primary numeric margin is bit/s headroom. Utilization percentage is a derived projection, not the comparison primitive. When no capacity fact is in scope, load dimensions can be COMPLETE without a capacity PASS claim.

### 13. Governing-case algorithm
Evaluate all required edge/case loads, then choose the smallest signed capacity headroom; ties break by canonical `(edgeId, caseRank)`. Recorder ingress is independently assessed and can govern if it has a stricter capacity margin.

### 14. Limiting-factor algorithm
Return exact `edgeId` or `recorderId`, stream/group contributors sorted by descending contribution then canonical ID, and case. If blocked, limiting factor identifies the first missing peak bitrate, path, multicast tree or incompatible overhead model in canonical ID order.

### 15. Missing/unsupported behavior
Missing peak bitrate makes only peak-dependent dimensions unresolved. Missing one subscription path does not permit a subtotal PASS for that edge set; emit known subtotal plus unresolved remainder. Duplicate subscription IDs or paths are semantic errors, not extra traffic. Unknown overhead model never defaults to a percentage.

### 16. Dependency set
Stream/profile editions, expected/peak bitrate values, subscription set marker, realized directed path refs, multicast group/tree set, recorder assignment set, optional transport-overhead policy and optional exact edge-capacity refs.

### 17. Calculation trace
`CCTV02_FLOW_IDENTITY_V1`, `CCTV02_UNICAST_COPY_V1`, `CCTV02_MULTICAST_EDGE_DEDUP_V1`, `CCTV02_EDGE_PAYLOAD_SUM_V1`, `CCTV02_WIRE_OVERHEAD_V1`, `CCTV02_RECORDER_INGRESS_V1`, `CCTV02_CAPACITY_COMPARE_V1`.

### 18. Complexity/resource bounds
With `F` canonical flow-edge incidences, accounting is O(F) expected using typed hash maps and O(F log F) only for canonical trace/output ordering. No subscription×all-edge scan. Qualification minimum: 1000 streams, 10,000 subscriptions and paths up to 64 edges; hard shipping limits are code-owned and authority-fingerprinted.

### 19. Pseudocode
```text
validateUnique(streams, subscriptions)
flowEdges = resolveCanonicalFlowEdges(subscriptions, multicastTrees)
for case in [EXPECTED, PEAK]:
  edgeLoad = Map<EdgeId, RationalBitRate>()
  recorderIngress = Map<RecorderId, RationalBitRate>()
  for flowEdge in flowEdges:
    rate = requireRate(flowEdge.streamId, case)
    edgeLoad[flowEdge.edgeId] += rate
  for recordingFlow in canonicalRecordingFlows:
    recorderIngress[target] += requireRate(streamId, case)
  compareOptionalCapacities(edgeLoad, recorderIngress)
selectGoverningSmallestMargin()
```

### 20. Dart interfaces
```dart
final class Cctv02Input {
  final List<CctvEncodedStream> streams;
  final List<CctvSubscription> subscriptions;
  final List<CctvMulticastTree> multicastTrees;
  final Elv5Field<TransportOverheadModel> overheadModel;
  final Map<NetworkEdgeId, Elv5EngineeringValue<BitRateQ>> capacities;
}
final class Cctv02Output {
  final Map<NetworkEdgeId, CctvEdgeTraffic> edges;
  final Map<RecorderId, CctvIngressTraffic> recorderIngress;
}
```

### 21. Positive reference vector
One stream expected 4 Mb/s, peak 6 Mb/s; two unicast receivers share edge E1 and diverge after it. E1 expected=8 Mb/s, peak=12 Mb/s. One recorder subscription receives one copy: recorder expected ingress=4 Mb/s, peak=6 Mb/s.

### 22. Boundary vector
Peak E1 load exactly equals explicit 12 Mb/s fixture capacity. Inclusive requirement => margin 0 bit/s and PASS. Adding one 1 bit/s flow => margin -1 bit/s and FAIL without display rounding ambiguity.

### 23. Negative vector
Two streams produce 14 Mb/s peak on 12 Mb/s capacity. Expected case remains within capacity. Overall required peak capacity dimension FAIL; expected dimension PASS; governing case PEAK/E1 with -2 Mb/s.

### 24. Adversarial vector
Duplicate receiver membership and reordered subscription JSON must not create extra copies. A multicast label without a declared tree must BLOCK multicast dedup rather than magically reduce load. A repeated stream ID with conflicting bitrate is rejected.

### 25. Cross-discipline vector
CCTV-02 consumes a LAN-realized path/capacity if supplied but does not own ports/cables. Changing LAN path membership invalidates affected CCTV-02 edge loads; it must not invalidate unrelated camera streams. CCTV-03 consumes the recording-flow bitrate basis from the exact CCTV-02 evaluation/hash.

---

## CCTV-03 — Recording storage/time integration

### 1. Physical meaning
Computes required usable and, when a declared redundancy model applies, raw storage capacity over an explicit horizon by integrating unique recording assignments over exact UTC intervals. It distinguishes expected estimate from guaranteed upper-bound retention.

### 2. Applicability matrix
| Input basis | Estimate | Guaranteed retention |
|---|---|---|
| Expected bitrate + exact schedule | APPLICABLE | NOT_ASSESSED |
| Guaranteed upper bitrate + exact/bounded schedule | APPLICABLE | APPLICABLE |
| Event recording without duty/schedule model | BLOCKED | BLOCKED |
| Recurrence with captured timezone rules | APPLICABLE | as evidence allows |
| Host-local timezone lookup only | UNSUPPORTED | UNSUPPORTED |
| Redundancy model absent | usable requirement only | raw requirement NOT_ASSESSED |

### 3. Exact typed inputs
`RecordingPoolId`, horizon `[startUtc,endUtc)`, captured `TemporalPolicy` including zone and exact rules hash, `RecordingAssignment(streamId,poolId,copyRole,scheduleRef)`, canonical half-open schedule intervals/recurrence definitions, sizing basis enum, bitrate evidence refs, exact reserve multiplier `>=1`, optional `RedundancyModel(usableFraction)`, and optional available usable/raw capacity facts.

### 4. Evidence requirements
Stream bitrate comes from exact CCTV-02 basis or captured equivalent. Guaranteed sizing requires a guaranteed upper bound for every recorded stream/case. Schedule recurrence expansion must be reproducible from captured timezone rules; host tzdb drift is forbidden. Redundancy fraction is a versioned technical model, not inferred from RAID marketing text.

### 5. Operating cases
`EXPECTED_ESTIMATE` and `GUARANTEED_UPPER_BOUND` are separate claim scopes. One calculation request selects the required sizing basis but may expose the other only if fully evidenced and clearly labeled.

### 6. Mathematical model
Expand schedules to UTC half-open intervals over the horizon, clip to horizon, union overlaps for each recording identity so time is not double counted, integrate `bitrate * seconds / 8`, sum exact rational bytes across all unique assignments in the pool, apply reserve exactly once to the pool total, then ceil once to integer usable bytes. If redundancy applies, divide the rounded usable requirement by usable fraction and ceil raw bytes.

### 7. Equations
For assignment `a`: `Ba = b_a * T_a / 8` bytes. Pool exact base: `Bbase=Σ Ba`. Reserved exact: `Bres=Bbase*R`. Required usable integer: `U=ceil(Bres)`. If usable fraction `f` with `0<f<=1`: `Raw=ceil(U/f)`. Capacity margin: `Musable=AvailableUsable-U`; optional `Mraw=AvailableRaw-Raw`.

### 8. Exact/bounded arithmetic
Durations are integer micro/nanosecond-derived exact rational seconds; bitrate is rational bit/s; bytes remain rational until one pool-level ceil. Never ceil each stream/day separately unless a storage model explicitly requires allocation granularity. Recurrence expansion has bounded occurrence/segment limits.

### 9. Worst-case selection
Guaranteed basis selects upper bitrate/effective-recorded-duration bounds. Estimate basis uses expected values and cannot govern a guarantee claim. Where multiple storage pools/copies exist, each pool is assessed independently; overall design governing factor is the smallest required pool headroom.

### 10. Requirement composition
Reserve multiplier belongs to the selected storage-sizing policy and is applied once. Redundancy usable fraction is separate from reserve. Retention horizon/schedule requirement and capacity requirement compose by explicit policy applicability; no default “30 days” or motion factor exists.

### 11. Comparison equations
`marginUsable=availableUsable-requiredUsable`. `marginRaw=availableRaw-requiredRaw` only when both raw requirement and raw capacity have compatible basis. Guaranteed retention PASS additionally requires every contributing bitrate/schedule bound to satisfy guaranteed evidence requirements.

### 12. Margin equation
Bytes headroom is the primary margin. Retention days are not back-solved and used as a substitute verdict unless a separately defined what-if query requests maximum achievable horizon.

### 13. Governing-case algorithm
Within a pool, assess claim-scope evidence, recorded time, usable capacity and raw capacity if applicable. Governing dimension is first FAIL/UNRESOLVED mandatory dimension; otherwise smallest byte headroom. Across requested pools, choose smallest headroom with canonical pool ID tie-break.

### 14. Limiting-factor algorithm
Identify pool, copy role and top contributing recording assignments. For evidence blockage, identify first stream lacking required upper bound or first schedule rule that cannot reproduce. For capacity failure, limiting factor is pool usable/raw boundary, not an arbitrary stream.

### 15. Missing/unsupported behavior
Missing event-duty model, timezone rules, bitrate upper bound or assignment identity blocks only affected claim scope; known subtotal may be exposed but never PASS. Duplicate `(streamId,poolId,copyRole)` is invalid. Overlapping intervals are unioned, not summed.

### 16. Dependency set
Exact CCTV-02 recorded-stream evaluation refs/hashes, recording assignment root+members, schedule/temporal policy including rules hash, reserve policy, redundancy model, pool capacity facts and selector markers for streams assigned to the pool.

### 17. Calculation trace
`CCTV03_EXPAND_SCHEDULE_V1`, `CCTV03_CLIP_HORIZON_V1`, `CCTV03_UNION_INTERVALS_V1`, `CCTV03_INTEGRATE_BITS_V1`, `CCTV03_BITS_TO_BYTES_V1`, `CCTV03_POOL_SUM_V1`, `CCTV03_APPLY_RESERVE_ONCE_V1`, `CCTV03_CEIL_USABLE_BYTES_V1`, `CCTV03_REDUNDANCY_RAW_V1`, `CCTV03_CAPACITY_COMPARE_V1`.

### 18. Complexity/resource bounds
For `N` expanded intervals, union is O(N log N); integration is O(N+A). Do not expand recurrence beyond the clipped horizon. Qualification requires 10,000 schedule segments without unbounded allocations. A code-owned occurrence cap must fail typed before expansion explosion.

### 19. Pseudocode
```text
requireHorizonAndCapturedTimeRules()
for assignment in canonicalAssignments:
  rate = resolveRateForSizingBasis(assignment.streamId)
  intervals = expandAndClip(scheduleRef, horizon, capturedRules)
  unique = unionHalfOpen(intervals)
  seconds = exactDuration(unique)
  baseBytes += rate * seconds / 8
reserved = baseBytes * reserveMultiplier
usable = ceil(reserved)
raw = redundancy == null ? NA : ceil(usable / usableFraction)
compareCapacities(usable, raw)
```

### 20. Dart interfaces
```dart
final class Cctv03Input {
  final RecordingPoolId poolId;
  final Elv5UtcWindow horizon;
  final Elv5TemporalPolicy temporalPolicy;
  final List<CctvRecordingAssignment> assignments;
  final List<CctvRecordingSchedule> schedules;
  final CctvStorageSizingBasis sizingBasis;
  final Elv5Rational reserveMultiplier;
  final Elv5Field<CctvRedundancyModel> redundancy;
}
final class Cctv03Output { final ByteCapacityQ requiredUsable; final Elv5Field<ByteCapacityQ> requiredRaw; final DurationQ recordedTime; final CctvStorageClaimScope claimScope; }
```

### 21. Positive reference vector
8,000,000 bit/s continuously for `30*86400` s => 2,592,000,000,000 B exact. Reserve 1.1 => 2,851,200,000,000 B usable. Mirror usable fraction 0.5 => 5,702,400,000,000 B raw.

### 22. Boundary vector
One stream at 1 bit/s recorded for 1 second, reserve 1, no redundancy. Exact base `1/8 B`, single pool ceil => 1 B. Available usable 1 B => margin 0 and PASS; 0 B => -1 B FAIL.

### 23. Negative vector
Required usable 2,851,200,000,000 B, available usable 2,800,000,000,000 B. Completed FAIL with -51,200,000,000 B. Calculation execution remains SUCCEEDED.

### 24. Adversarial vector
Two overlapping schedule intervals `[00:00,01:00)` and `[00:30,01:30)` must yield 1.5 h, not 2 h. Reordered segments hash equivalently if schedule semantics are set-like. Missing DST overlap policy must not use host default. Repeating `retentionDays` multiplication after horizon expansion is forbidden by test.

### 25. Cross-discipline vector
CCTV-03 must consume exactly the recorded stream bitrate identities from CCTV-02. CCTV-05 uses this result for recorder storage capacity. A change to unrelated LAN port capacity must not invalidate storage unless it changes a consumed flow/path fact.

---

## CCTV-04 — CCTV PoE shared-source context

### 1. Physical meaning
Projects the CCTV contribution and discipline policy context onto the exact global ELV4 `ELV-PWR-06` PoE/PSE physical evaluation. It does not calculate a CCTV-only power budget.

### 2. Applicability matrix
Applicable only when an exact current PWR-06 evaluation exists for every required scenario/segment and its captured membership includes the same physical PSE closure. Stale, partial or mismatched evidence blocks the wrapper.

### 3. Exact typed inputs
CCTV subject set, selected CCTV requirement refs, PSE/source identity, required scenario/segment set, exact `PowerEvaluationRef`/output hash/pointer generation, and CCTV contribution membership identities.

### 4. Evidence requirements
Only immutable accepted ELV4 physical evidence with matching source, segment, scenario, revision and membership fingerprint. Discipline contribution must map to canonical ELV4 load identities.

### 5. Operating cases
`UPSTREAM_PWR06_CASE_SET`; all upstream cases required by the calling policy are retained, including any global governing case.

### 6. Mathematical model
No independent power-flow arithmetic. Resolve CCTV contribution from canonical upstream contributors and expose upstream global requirement, available capability and margin unchanged.

### 7. Equations
`GlobalMargin := upstream.PWR06.margin`. `CctvContribution := Σ upstreamContributorValue` for contributor IDs classified as CCTV in the captured membership. No reserve/loss term is applied again.

### 8. Exact/bounded arithmetic
Reuse upstream exact values/hashes. Contribution sum uses the same power dimension and exact numeric backend; it is explanatory, not a replacement total.

### 9. Worst-case selection
Use upstream global governing case over the required scenario set. Do not select a friendlier CCTV-only case.

### 10. Requirement composition
Discipline policy may require stricter capability through the source-owned requirement merger, but physical demand/reserve ownership remains ELV4. Conflicts are explicit.

### 11. Comparison equations
Wrapper assessment mirrors the applicable upstream technical result plus any additional compatible discipline requirement comparison performed against the same global demand/capability.

### 12. Margin equation
Primary margin is reused upstream margin; CCTV contribution has no “margin” by itself.

### 13. Governing-case algorithm
Verify evidence closure first, then adopt upstream governing case. If an additional discipline requirement is stricter, the deterministic requirement merger may make that requirement the governing comparison while retaining same global physical demand.

### 14. Limiting-factor algorithm
Upstream PSE/source/segment limiting factor is preserved. A CCTV policy conflict is identified separately as requirement limiting factor.

### 15. Missing/unsupported behavior
Missing or stale PWR-06 evidence => BLOCKED. Never recalculate with only CCTV loads. Never treat CCTV contribution as total.

### 16. Dependency set
Exact PWR-06 evaluation ID/hash/generation, PSE closure set marker, CCTV contributor membership set and policy edition.

### 17. Calculation trace
`CCTV04_VERIFY_PWR06_SCOPE_V1`, `CCTV04_SELECT_CCTV_CONTRIBUTORS_V1`, `CCTV04_SUM_CONTRIBUTION_V1`, `CCTV04_REUSE_GLOBAL_MARGIN_V1`.

### 18. Complexity/resource bounds
O(K) over upstream contributor list with keyed membership lookup; no graph solve. Bound by accepted ELV4 evaluation contributor cardinality.

### 19. Pseudocode
```text
e = requireExactCurrentPwr06(scope, scenarios)
requireSamePhysicalClosure(e)
contribution = sum(e.contributors where id in cctvMembers)
return project(e.globalDemand, e.available, e.margin, contribution, e.governingCase)
```

### 20. Dart interfaces
```dart
final class Cctv04Input { final PseId pseId; final Set<LoadId> cctvLoads; final Elv4Pwr06Evidence evidence; final Elv5PolicyEditionRef policy; }
final class Cctv04Output { final PowerQ globalDemand; final PowerQ cctvContribution; final PowerQ globalMargin; final Elv4EvidenceRef physicalEvidence; }
```

### 21. Positive reference vector
Global demand/reservation 30 W, available budget 35 W, CCTV contribution 12 W, LAN contribution 18 W. Output global margin 5 W and contribution 12 W.

### 22. Boundary vector
Global demand exactly 35 W against inclusive 35 W capability => upstream margin 0 W and wrapper PASS if all other dimensions pass.

### 23. Negative vector
Upstream PWR-06 global demand 37 W, available 35 W => wrapper completed FAIL with -2 W; CCTV contribution may still be 12 W.

### 24. Adversarial vector
Caller attempts to filter out LAN loads and recompute 12 W vs 35 W. Guard must reject because physical closure fingerprint differs from accepted global evidence.

### 25. Cross-discipline vector
CCTV-04 and LAN-03 consuming the same PSE evaluation must report identical global demand/margin and different discipline contributions whose canonical union equals the upstream classified contributors without double counting.

---

## CCTV-05 — Recorder/VMS capacity

### 1. Physical meaning
Checks recorder/VMS technical capacity across independent channel/license accounting, peak ingress, declared codec/profile compatibility and usable storage requirement. A recorder can pass one dimension and fail another.

### 2. Applicability matrix
Applicable when recorder capability edition, exact assignment set and required CCTV-02/03 evidence are available. Missing channel accounting basis or codec capability is unresolved; raw disk marketing capacity cannot substitute usable capacity.

### 3. Exact typed inputs
Recorder ID/definition ref, accounting basis enum `DEVICE|ENCODED_STREAM|LICENSE_CHANNEL`, grouping key rules, assigned stream IDs, license/channel claims, supported codec/profile predicates, peak ingress capacity, usable storage capacity, exact CCTV-02 ingress evidence and CCTV-03 selected storage-claim evidence.

### 4. Evidence requirements
Recorder limits must be immutable catalog/component definition evidence with basis. Assignments are revision-scoped ELV5 facts. Ingress/storage refs must match the same stream/pool scope.

### 5. Operating cases
`CHANNEL_ACCOUNTING`, `PEAK_INGRESS`, `CODEC_PROFILE`, `STORAGE_CLAIM`; optional expected ingress is informational if peak is required.

### 6. Mathematical model
Canonicalize assignments by selected accounting basis; count distinct consumed capacity units; separately sum/use upstream peak ingress; evaluate every assigned stream against explicit compatibility profile; compare required usable storage from CCTV-03 against recorder usable storage.

### 7. Equations
`channelMargin = channelLimit - consumedChannels`; `ingressMargin = ingressCapacity - peakIngress`; `storageMargin = usableCapacity - requiredUsable`. Codec compatibility is boolean per stream with deterministic failing-stream order.

### 8. Exact/bounded arithmetic
Counts are exact integers; bitrates/bytes are exact quantities from upstream results. No float percentages decide verdict.

### 9. Worst-case selection
Governing dimension is smallest required signed numeric headroom or first deterministic compatibility FAIL/UNRESOLVED. Guaranteed storage policy requires guaranteed CCTV-03 claim; estimate cannot silently qualify it.

### 10. Requirement composition
Recorder catalog capabilities and project reserve/license policy are merged only when compatible. Do not apply storage reserve again if CCTV-03 already produced required usable bytes including reserve.

### 11. Comparison equations
All capacities use `available-required`. Codec predicate must explicitly match each assigned stream’s captured codec/profile properties; missing property => unresolved, not false compatibility.

### 12. Margin equation
Per-dimension margins remain separate. UI may show normalized utilization, but there is no mathematically meaningful sum of channel, bit/s and byte margins.

### 13. Governing-case algorithm
Evaluate channel, ingress, codec, storage in fixed dimension order for status completeness, then select FAIL over unresolved over pass according to overall status algebra; among numeric FAIL/PASS candidates select smallest normalized utilization headroom only for display ranking, retaining physical margin.

### 14. Limiting-factor algorithm
Exact recorder dimension plus stream/license/pool ID causing the constraint. For channel accounting, return grouping key and members contributing to the final consumed unit.

### 15. Missing/unsupported behavior
Unknown accounting basis blocks channel assessment. Missing codec support evidence is unresolved. Missing guaranteed storage claim blocks guarantee dimension even if numeric estimate fits.

### 16. Dependency set
Recorder immutable capability ref/hash, assignments root+members, CCTV-02 recorder-ingress evaluation, CCTV-03 pool result, license policy and selector markers for streams assigned to recorder.

### 17. Calculation trace
`CCTV05_CANONICAL_CHANNEL_UNITS_V1`, `CCTV05_CHANNEL_COUNT_V1`, `CCTV05_INGRESS_COMPARE_V1`, `CCTV05_CODEC_MATCH_V1`, `CCTV05_STORAGE_COMPARE_V1`.

### 18. Complexity/resource bounds
O(S) assignments and compatibility checks using keyed definitions; O(S log S) only for canonical output ordering. Qualification must handle at least 1000 streams distributed across recorders.

### 19. Pseudocode
```text
units = canonicalAccountingUnits(assignments, basis)
channel = compare(limit.channels, units.length)
ingress = compare(limit.ingress, cctv02.peakIngress(recorder))
codec = every(assignments, stream => profile.supports(stream))
storage = compare(cap.usableBytes, cctv03.requiredUsable(pool))
return aggregateIndependentDimensions(channel, ingress, codec, storage)
```

### 20. Dart interfaces
```dart
final class Cctv05Input { final RecorderId recorderId; final RecorderCapability capability; final CctvChannelAccountingBasis basis; final List<CctvRecorderAssignment> assignments; final Cctv02Evidence ingress; final Cctv03Evidence storage; }
final class Cctv05Output { final CountQ channelsUsed; final BitRateQ peakIngress; final ByteCapacityQ requiredUsable; final List<StreamCompatibilityResult> streamCompatibility; }
```

### 21. Positive reference vector
2 consumed channels <=4; peak ingress 8 Mb/s <=20 Mb/s; required usable 2,851,200,000,000 B <=3,000,000,000,000 B; all stream profiles supported => PASS.

### 22. Boundary vector
Consumed channels exactly 4 of 4 and storage exactly equals available. Inclusive limits yield zero margins and PASS.

### 23. Negative vector
Channels/ingress pass, storage required 3.2 TB >3.0 TB usable => completed storage FAIL with -0.2 TB exact byte margin.

### 24. Adversarial vector
Same physical stream appears twice under different UI rows but same encoded-stream identity. `ENCODED_STREAM` basis counts once; `LICENSE_CHANNEL` may count according to explicit license assignment, never row count. Raw disk sum cannot be substituted for usable bytes.

### 25. Cross-discipline vector
Recorder ingress must equal the exact relevant CCTV-02 result and storage must equal selected CCTV-03 pool claim. A LAN path change that changes recorder ingress flow invalidates CCTV-02 then CCTV-05 through typed dependency propagation.

---

## CCTV-06 — CCTV cable/link technical basis

### 1. Physical meaning
Checks that the realized ELV3 physical link composition, media/interface/category facts and applicable powered-path evidence satisfy the selected CCTV technical link policy. It does not own cabling, routing or normative certification.

### 2. Applicability matrix
Copper/fiber/other media are evaluated only against an explicit supported policy profile. Powered links additionally require scoped PWR-06 evidence. Unknown route or medium blocks affected dimensions.

### 3. Exact typed inputs
Ordered realized link section IDs, media/interface/category/shield facts, exact installed lengths, selected technical link policy, endpoint interface facts, powered flag/media-converter facts, required PWR-06 evidence refs where applicable.

### 4. Evidence requirements
All physical sections come from ELV3 canonical route/link realization. Policy edition is explicit and versioned. Power evidence is exact ELV4 result matching required powered segments.

### 5. Operating cases
`REALIZED_LINK`; conditional `POWERED_PATH_WHEN_APPLICABLE`.

### 6. Mathematical model
Fold the ordered path through policy predicates, evaluate each section/interface, compute numeric path totals only where policy defines them, and attach power evidence for powered sections. Weakest/incompatible section governs compatibility.

### 7. Equations
If policy defines max length `Lmax`, `Lreal=Σ installedSectionLength`; `margin=Lmax-Lreal`. Other predicates are typed boolean/enum matches; no category ranking is inferred unless the policy defines an ordered capability relation.

### 8. Exact/bounded arithmetic
Installed lengths are exact/interval values inherited from ELV3; sums preserve bounds. No room-distance approximation. Do not add service loop/allowance already included upstream.

### 9. Worst-case selection
Use upper installed-length bound for maximum-limit checks and first incompatible ordered path element for categorical checks. Powered scenario follows upstream global governing case.

### 10. Requirement composition
CCTV technical link policy may require a subset/superset of LAN technical properties but cannot override canonical physical facts. Normative cable/fire requirements remain ELV7 where applicable.

### 11. Comparison equations
Numeric limit uses `limit-realized`; categorical/interface checks require explicit compatible relation from the policy matrix.

### 12. Margin equation
Length headroom is optional numeric margin. Categorical compatibility has no fake numeric score.

### 13. Governing-case algorithm
First mandatory unsupported/mismatched path dimension governs; else smallest numeric path headroom; else powered-path upstream margin when it is the only constrained dimension.

### 14. Limiting-factor algorithm
Return exact section/interface ID or upstream PSE segment that constrains the link, with policy requirement code.

### 15. Missing/unsupported behavior
Unknown route/section length/media/interface => affected dimension unresolved. Fiber endpoint with PoE requirement and no powered media converter => required-feed FAIL/BLOCKED according to complete evidence, never assume PoE over fiber.

### 16. Dependency set
ELV3 realized ordered sections, endpoint interfaces, installed lengths, media converter membership, CCTV link policy and required PWR-06 evidence generations.

### 17. Calculation trace
`CCTV06_PATH_FOLD_V1`, `CCTV06_MEDIA_MATCH_V1`, `CCTV06_INTERFACE_MATCH_V1`, `CCTV06_LENGTH_SUM_V1`, `CCTV06_LENGTH_COMPARE_V1`, `CCTV06_POWER_EVIDENCE_BIND_V1`.

### 18. Complexity/resource bounds
O(P) in path sections; no graph search because the path is already realized by ELV3. Bound ordered sections per link through shared resource limits.

### 19. Pseudocode
```text
path = requireElv3RealizedPath(linkId)
for section in path.orderedSections:
  evaluatePolicyPredicates(section)
length = exactSum(path.installedLengths)
compareOptionalLengthLimit(length)
if powered: requireExactPwr06ForRequiredSegments(path)
return aggregateLinkBasis()
```

### 20. Dart interfaces
```dart
final class Cctv06Input { final LinkId linkId; final List<RealizedLinkSection> orderedSections; final CctvLinkPolicy policy; final Elv5Field<Elv4Pwr06EvidenceSet> powerEvidence; }
final class Cctv06Output { final LengthQ realizedLength; final List<PathCompatibilityResult> sections; final Elv5Field<PowerEvidenceProjection> poweredPath; }
```

### 21. Positive reference vector
Policy max 30 m; realized permanent/patch sections total exactly 30 m with compatible interfaces. Length margin 0, PASS; powered evidence matches all required segments.

### 22. Boundary vector
Installed upper-bound interval ends exactly at 30 m => inclusive PASS with zero worst-case margin. If upper bound is 30.000001 m => FAIL even if displayed rounded length is 30.0 m.

### 23. Negative vector
One patch section has explicitly incompatible interface/category. Length passes, compatibility dimension FAIL; overall completed FAIL identifies that section.

### 24. Adversarial vector
Duplicate section ID in path is rejected rather than counted twice; room straight-line distance is ignored; stale PWR evidence from a prior path generation cannot satisfy powered path.

### 25. Cross-discipline vector
Same ELV3 path is consumed by LAN-01/LAN-04 where applicable; CCTV-06 must agree on realized section identity/length while applying CCTV-specific policy. It must never create a second cable/path record.