# ELV5 — 27 canonical process contracts

Status: DESIGN DRAFT / RUNTIME NOT IMPLEMENTED. Parent: [design](../elv5-discipline-calculations-design-specification.md).

All thresholds/numbers below are fictional test data. Code names are stable; algorithm/schema versions are design targets, not registered runtime. Each required dimension must have explicit status. Numeric units are canonical SI/bytes; signed dBm and coordinate inputs extend decimal validation by quantity type, never relax nonnegative capacity/demand constraints.

## CCTV-01 — Camera coverage geometry

Scope: `DESIGN`; mode: `GEOMETRY`.

**Required inputs:** camera captured position/frame and rotation matrix; rectilinear sensor width/height and focal length; target plane/zone and supported-obstruction declaration.

**Algorithm/boundary:** Cast sensor corner rays through captured calibrated pinhole frame; intersect t=(planeOffset-dot(normal,origin))/dot(normal,direction), require positive finite intersection and supported model. Clip ordered footprint to zone. FOV=2*atan(sensorDimension/(2*focalLength)) uses separately versioned bounded backend; exact rational footprint may qualify independently of an unavailable angle display. Parallel/horizon/uncertain intersections remain unresolved. No DORI or occlusion success inferred.

**Required technical dimensions:** footprint-bounds, zone-intersection, model-applicability.

**Consumed dependencies:** camera pose, intrinsics edition, target geometry/frame.

**Positive oracle:** Fictional normal incidence: height=3m,sensor=6x4mm,focal=6mm,target parallel plane -> footprint 3x2m, area 6m2; unobstructed geometry basis only.

**Negative/unsupported case:** Unsupported fisheye/occlusion model or horizon-parallel ray -> BLOCKED; geometric footprint is not visible-through-wall coverage.

**Planned acceptance:** CCTV-01-POS, CCTV-01-NEG. Runtime: NOT_STARTED.

## CCTV-02 — Stream bandwidth

Scope: `DESIGN`; mode: `SCALAR`.

**Required inputs:** unique encoded stream IDs; explicit expected/peak bitrate in bit/s; directed forwarding/recorder subscriptions and unicast/multicast policy.

**Algorithm/boundary:** Sum encoded stream bitrate times explicit copies on each traversed network edge. Unicast subscriptions generate separate copies; multicast dedup requires declared distribution tree. Recorder ingress counts only assigned incoming streams. Expected/peak remain separate; codec/resolution/fps do not synthesize bitrate without a versioned model.

**Required technical dimensions:** edge-expected-bitrate, edge-peak-bitrate, recorder-ingress.

**Consumed dependencies:** stream profiles, flow membership sets, network path.

**Positive oracle:** One 4,000,000bit/s stream, two unicast receivers on common edge -> 8,000,000bit/s edge load; one recorded subscription -> 4,000,000bit/s recording ingress.

**Negative/unsupported case:** Missing peak bitrate leaves peak dimension unresolved; a repeated system membership does not create an extra encoded stream.

**Planned acceptance:** CCTV-02-POS, CCTV-02-NEG. Runtime: NOT_STARTED.

## CCTV-03 — Recording storage

Scope: `DESIGN`; mode: `SCALAR`.

**Required inputs:** recording assignment per encoded stream; expected recording bitrate basis; union of half-open recorded UTC intervals over explicit horizon; reserve multiplier and optional redundancy profile.

**Algorithm/boundary:** For each unique recording assignment integrate bitrateBitsPerSecond * uniqueRecordedSeconds / 8; sum and apply declared reserve once. Daily recurrence is expanded with pinned timezone/rules, then overlaps are unioned; do not multiply total horizon seconds by retentionDays again. Raw estimate=usableRequired/redundancyUsableFraction only if explicit model applies; no product selection.

**Required technical dimensions:** recorded-time, usable-bytes, reserve-accounting.

**Consumed dependencies:** CCTV-02 recorded stream basis, schedule/horizon, storage policy.

**Positive oracle:** 8,000,000bit/s continuous 30*86400s -> 2,592,000,000,000B; reserve1.1 -> 2,851,200,000,000B. Explicit mirror usable fraction .5 -> raw basis5,702,400,000,000B.

**Negative/unsupported case:** Overlapping intervals counted once; absent event duty or schedule/timezone policy blocks affected estimate, never assume 24h or a motion factor.

**Planned acceptance:** CCTV-03-POS, CCTV-03-NEG. Runtime: NOT_STARTED.

## CCTV-04 — CCTV PoE context

Scope: `SEGMENT`; mode: `POWER_WRAPPER`.

**Required inputs:** complete shared-source closure; CCTV policy binding; exact ELV-PWR-06 evidence.

**Algorithm/boundary:** Bind CCTV subject/policy and contribution to the global PWR-06 budget. Reuse exact matching physical evaluation; do not rerun a reduced CCTV-only source or add cable allowance/reserve again.

**Required technical dimensions:** global-budget, CCTV-contribution, physical-evidence.

**Consumed dependencies:** ELV-PWR-06, shared PSE membership, CCTV policy.

**Positive oracle:** Global shared reservation30W, budget35W, selected CCTV contribution12W -> global margin5W, contribution12W; exactly one physical budget evidence.

**Negative/unsupported case:** LAN contribution18W cannot disappear under CCTV filter; stale/mismatched physical evidence -> BLOCKED.

**Planned acceptance:** CCTV-04-POS, CCTV-04-NEG. Runtime: NOT_STARTED.

## CCTV-05 — Recorder/VMS capacity

Scope: `DESIGN`; mode: `SCALAR`.

**Required inputs:** recorded stream/channel assignments; recorder exact codec/resolution/ingress/usable capacity; CCTV-02/03 evidence.

**Algorithm/boundary:** Check distinct recorded channel count, peak ingress, declared stream compatibility and required usable storage independently. Selected usable capacity is not raw disk sum. Capacity failure is a completed FAIL, not an execution error.

**Required technical dimensions:** channels, ingress, codec-profile, usable-storage.

**Consumed dependencies:** CCTV-02, CCTV-03, recorder definition.

**Positive oracle:** 2 assigned channels, declared4-channel limit, ingress8Mbps<=20Mbps and required2,851,200,000,000B<=3,000,000,000,000 usable B -> PASS.

**Negative/unsupported case:** Enough channels with insufficient usable storage -> storage FAIL; missing codec support is unresolved, not compatible by label.

**Planned acceptance:** CCTV-05-POS, CCTV-05-NEG. Runtime: NOT_STARTED.

## CCTV-06 — CCTV cable/link basis

Scope: `DESIGN`; mode: `BASIS`.

**Required inputs:** exact realized media/category/path; selected link policy; applicable PoE path evidence.

**Algorithm/boundary:** Check medium/interface/category and installed link composition against explicit policy limits. If powered, reference matching scoped PWR-06 result; preserve per-segment power applicability. Never use room distance or duplicate cable allocations.

**Required technical dimensions:** link-composition, policy-match, physical-path.

**Consumed dependencies:** ELV3 installed path, LAN length/compatibility kernel where applicable, PWR-06 when powered.

**Positive oracle:** Fictional copper policy maximum30m, realized28m+2m patches=30m -> length basis PASS with exact profile provenance.

**Negative/unsupported case:** Fiber without powered media converter cannot satisfy PoE path; unknown route -> physical dimension BLOCKED.

**Planned acceptance:** CCTV-06-POS, CCTV-06-NEG. Runtime: NOT_STARTED.

## LAN-01 — Permanent-link and channel length

Scope: `DESIGN`; mode: `SCALAR`.

**Required inputs:** ordered unique installed sections; permanent versus patch classification; installed slack/termination accounting; exact cabling policy.

**Algorithm/boundary:** Sum permanent-link sections and patch cords separately; total channel is their union. Installed length already includes declared service loops/allowances, so add only explicit not-yet-included contributions. Compare independent permanent/channel limits from policy.

**Required technical dimensions:** permanent-length, channel-length, allowance-accounting.

**Consumed dependencies:** ELV3 installed lengths, link section membership, cabling policy.

**Positive oracle:** Permanent28m + explicit patches2m = channel30m; policy permanent<=28/channel<=30 -> PASS, no second service-loop addition.

**Negative/unsupported case:** Duplicate section membership or unknown length basis -> unresolved/invalid; no universal hardcoded 90/100m limit.

**Planned acceptance:** LAN-01-POS, LAN-01-NEG. Runtime: NOT_STARTED.

## LAN-02 — Switch port capacity

Scope: `DESIGN`; mode: `SCALAR`.

**Required inputs:** exact physical port inventory; endpoint assignments/media/speed; explicit spare-ratio policy.

**Algorithm/boundary:** Count distinct occupied compatible physical ports; spare requirement=ceil(occupied*ratio) under declared policy. Check occupied+requiredSpare<=available; pre-reserved physical ports are set members, not an extra duplicate load. Break down incompatible assignments.

**Required technical dimensions:** physical-count, media-speed, spare-capacity.

**Consumed dependencies:** port inventory, assignment set, spare policy.

**Positive oracle:** 6 occupied,8 available,ratio .25 -> ceil1.5=2 spare,required8,margin0 -> PASS.

**Negative/unsupported case:** 7 occupied with same policy -> 2 spare,required9>8 FAIL; same port assigned twice is not two available ports.

**Planned acceptance:** LAN-02-POS, LAN-02-NEG. Runtime: NOT_STARTED.

## LAN-03 — LAN PoE context

Scope: `SEGMENT`; mode: `POWER_WRAPPER`.

**Required inputs:** complete shared PSE closure; LAN policy; exact PWR-06 evidence.

**Algorithm/boundary:** Contextualize global PWR-06 evidence and LAN contribution without a second electrical source graph, repeated losses or reduced membership totals.

**Required technical dimensions:** global-budget, LAN-contribution, physical-evidence.

**Consumed dependencies:** ELV-PWR-06, PSE membership, LAN policy.

**Positive oracle:** Global30W, selected LAN18W,35W budget -> margin5W with same physical evidence as CCTV-04.

**Negative/unsupported case:** Conflicting source-owned reserve/mode policy -> explicit policy conflict; never choose a discipline default silently.

**Planned acceptance:** LAN-03-POS, LAN-03-NEG. Runtime: NOT_STARTED.

## LAN-04 — Copper compatibility basis

Scope: `DESIGN`; mode: `BASIS`.

**Required inputs:** exact cable/connector/shielding/media/speed definitions; all passive path sections; versioned supported-category matrix.

**Algorithm/boundary:** Evaluate every ordered path section against the selected speed/media/connector/shielding/category policy. Minimum path capability is the limiting section, not cable label alone. Keep declared technical policy matching separate from normative certification.

**Required technical dimensions:** ordered-interface-match, path-capability, policy-provenance.

**Consumed dependencies:** canonical interfaces, cable editions, LAN-01, compatibility matrix.

**Positive oracle:** Every section explicitly supports selected1Gb/s fixture profile and length policy -> technical policy-match PASS.

**Negative/unsupported case:** One incompatible patch/interface section -> FAIL despite a matching main cable category; missing shield continuity -> unresolved.

**Planned acceptance:** LAN-04-POS, LAN-04-NEG. Runtime: NOT_STARTED.

## LAN-05 — Bidirectional fiber loss budget

Scope: `DESIGN`; mode: `SCALAR`.

**Required inputs:** exact wavelength/fiber attenuation and installed lengths; mated connector pairs and splice events; Tx min/max dBm, receiver sensitivity/overload dBm; loss min/max and explicit reserve.

**Algorithm/boundary:** For each optical direction compute loss interval=sum(alpha_dB_per_km*length_m/1000 + matedPairLoss + spliceLoss + declared loss terms). RxMin=TxMin-lossMax must meet sensitivity; RxMax=TxMax-lossMin must not exceed overload. Signed dBm is allowed; dB losses nonnegative. Evaluate both directions with their exact optics.

**Required technical dimensions:** sensitivity-margin, overload-margin, both-directions.

**Consumed dependencies:** fiber paths, termination/splice sets, optical editions/wavelength.

**Positive oracle:** Tx=-3dBm,loss=2.5dB -> Rx=-5.5dBm; sensitivity=-15/overload=-1 -> margins9.5dB/4.5dB, both PASS for symmetric declared optics.

**Negative/unsupported case:** TxMax=-1,lossMin=0,receiverOverload=-3 -> overload FAIL even if sensitivity passes; connector ends must not double mated-pair count.

**Planned acceptance:** LAN-05-POS, LAN-05-NEG. Runtime: NOT_STARTED.

## LAN-06 — Rack demand/capacity basis

Scope: `DESIGN`; mode: `BASIS`.

**Required inputs:** declared equipment RU/weight/depth; non-owning rack membership; spare policy and available capacity if explicitly supplied.

**Algorithm/boundary:** Sum demand from distinct equipment; report RU/weight/depth requirements and comparison only for explicit available limits. No slot placement, clearance, thermal-layout or cabinet-fit certification; those belong to ELV6.

**Required technical dimensions:** RU-demand, membership-accounting, basis-scope.

**Consumed dependencies:** equipment dimensions, rack membership, reserve policy.

**Positive oracle:** Devices2RU+1RU and explicit1RU reserved -> demand4RU; declared6RU basis leaves2RU; layout status NOT_ASSESSED.

**Negative/unsupported case:** Unknown equipment depth prevents depth comparison, not an automatic fit; missing enclosure layout cannot be hidden as PASS.

**Planned acceptance:** LAN-06-POS, LAN-06-NEG. Runtime: NOT_STARTED.

## LAN-07 — Patch-panel utilization

Scope: `DESIGN`; mode: `SCALAR`.

**Required inputs:** panel physical port set; termination/patch mapping assignments; spare policy.

**Algorithm/boundary:** Count occupied/free/reserved physical ports with unique mapping identity; validate expected end-to-end mapping completeness. Passive continuation and termination evidence are separate relationships, not extra occupied ports.

**Required technical dimensions:** port-count, reserve, mapping-completeness.

**Consumed dependencies:** panel ports, termination/patch membership, spare policy.

**Positive oracle:** 8 ports,5 occupied,2 required spare ->3 free,1 free-after-reserve; complete declared mapping -> PASS.

**Negative/unsupported case:** Duplicate endpoint mapping or missing destination -> finding; do not count one port twice through internal and external links.

**Planned acceptance:** LAN-07-POS, LAN-07-NEG. Runtime: NOT_STARTED.

## ACS-01 — Door role completeness

Scope: `DESIGN`; mode: `TOPOLOGY`.

**Required inputs:** canonical door assembly; exact door-role requirement profile; non-owning role assignments.

**Algorithm/boundary:** Compare assigned canonical component roles/multiplicities with required alternatives: e.g. entry reader plus (exit reader OR exit button). Equipment may fill several roles only if explicitly allowed; do not infer emergency release from a device name.

**Required technical dimensions:** required-roles, role-multiplicity, scope-ownership.

**Consumed dependencies:** door assembly, door profile, role membership set.

**Positive oracle:** Profile reader+lock+(exitReader OR exitButton); exactly reader,lock,exitButton assigned -> PASS.

**Negative/unsupported case:** Missing required contact/release role under selected profile -> FAIL or BLOCKED when assignment unknown; no universal door template.

**Planned acceptance:** ACS-01-POS, ACS-01-NEG. Runtime: NOT_STARTED.

## ACS-02 — Controller channel capacity

Scope: `DESIGN`; mode: `SCALAR`.

**Required inputs:** physical reader/relay/input channel inventory; door/controller assignments; spare policy.

**Algorithm/boundary:** Count unique hardware resources per channel type; compare separate reader/relay/supervised-input limits and required spare. Sharing across doors requires an explicit supported channel multiplexing model, not duplicate memberships.

**Required technical dimensions:** reader-channels, relay-channels, input-channels.

**Consumed dependencies:** controller ports/resources, door assignments, capacity policy.

**Positive oracle:** Controller4 reader channels,3 used ->1 free;2 relay channels,2 used ->0 free; explicit zero spare -> PASS.

**Negative/unsupported case:** Third relay assignment -> relay FAIL while reader capacity still passes.

**Planned acceptance:** ACS-02-POS, ACS-02-NEG. Runtime: NOT_STARTED.

## ACS-03 — Lock demand and terminal voltage

Scope: `SEGMENT`; mode: `POWER_WRAPPER`.

**Required inputs:** lock holding/active/startup load profile; scenario duty and pulse policy; exact shared DC physical evidence.

**Algorithm/boundary:** Resolve selected lock mode and explicit peak model, then consume shared PWR-01/03 including trunk loads from other consumers. Relay control is not the lock power source. Unsupported electrical model propagates BLOCKED.

**Required technical dimensions:** lock-state-demand, terminal-voltage, shared-trunk-current.

**Consumed dependencies:** ELV-PWR-01, ELV-PWR-03, lock policy, control/feed separation.

**Positive oracle:** Shared trunk .3+.5A,24V,.5ohm and lock branch .3ohm -> lock23.45V; shared trunk .8A retained.

**Negative/unsupported case:** Control-only relay adjacency with no conductive feed -> power path unresolved; do not size by lock branch current alone.

**Planned acceptance:** ACS-03-POS, ACS-03-NEG. Runtime: NOT_STARTED.

## ACS-04 — ACS supply requirement

Scope: `SEGMENT`; mode: `POWER_WRAPPER`.

**Required inputs:** complete shared supply demand; source-owned applicable policy requirement set; PWR-02 evidence.

**Algorithm/boundary:** Apply calling ACS policy through source-owned requirement set; compare each dimension using the shared physical demand and reserve once. Source input demand remains distinct from capability selection margin.

**Required technical dimensions:** global-source-demand, policy-requirement, available-margin.

**Consumed dependencies:** ELV-PWR-01, ELV-PWR-02, source policy set.

**Positive oracle:** Demand30W,reserve1.2,50W rating,derating.8 ->required36,available40,margin4; actual output demand remains30W.

**Negative/unsupported case:** Incompatible policy requirement sets block composition; no per-door multiplication of source reserve.

**Planned acceptance:** ACS-04-POS, ACS-04-NEG. Runtime: NOT_STARTED.

## ACS-05 — ACS backup requirement

Scope: `SEQUENCE`; mode: `POWER_WRAPPER`.

**Required inputs:** composed protected sequence; explicit ACS autonomy/duty policy; exact bank/PWR-04 evidence.

**Algorithm/boundary:** Use complete global protected sequence and exact model applicability; expose ACS contribution plus global requirement. State durations and any extension policy are explicit. No nominal Ah/current shortcut for unsupported models.

**Required technical dimensions:** sequence-energy, bank-model, global-capacity-margin.

**Consumed dependencies:** ELV-PWR-04, protected membership, ACS policy.

**Positive oracle:** Shared constant-current source19.2W for3600s ->19.2Wh; usable134.4Wh ->115.2Wh margin for that explicit sequence.

**Negative/unsupported case:** Missing required duration or ignored non-ACS protected load -> BLOCKED; sequence margin alone does not imply indefinite autonomy.

**Planned acceptance:** ACS-05-POS, ACS-05-NEG. Runtime: NOT_STARTED.

## ACS-06 — Door control/supply topology

Scope: `DESIGN`; mode: `TOPOLOGY`.

**Required inputs:** door assembly/channel assignments; reader/controller/lock/control paths; selected release/supervision policy.

**Algorithm/boundary:** Validate typed path roles and selected door topology alternatives independently: data/control, feed, monitoring and required emergency-release dependency. Preserve non-owning assemblies; topology reachability is not electrical capacity.

**Required technical dimensions:** control-path, required-feed, release-policy.

**Consumed dependencies:** canonical graph, door roles/profile, controller assignments.

**Positive oracle:** Explicit reader-controller link,controller relay control,independent lock supply and required exit/release path -> topology basis PASS.

**Negative/unsupported case:** Lock connected only to dry contact without feed -> required-feed FAIL; missing selected release evidence blocks completeness.

**Planned acceptance:** ACS-06-POS, ACS-06-NEG. Runtime: NOT_STARTED.

## FA-01 — Fire loop device/address capacity

Scope: `DESIGN`; mode: `SCALAR`.

**Required inputs:** panel/module/loop inventory; device assignments and exact address/resource consumption; spare policy.

**Algorithm/boundary:** Count physical devices and consumed addresses separately, including modules occupying multiple addresses. Enforce declared uniqueness and scoped address domain. Compare independent device/address/panel limits.

**Required technical dimensions:** device-count, address-count, address-uniqueness.

**Consumed dependencies:** loop membership, device editions, panel policy.

**Positive oracle:** 3 devices with address consumption1,1,2 ->4 addresses; declared5-address limit ->margin1.

**Negative/unsupported case:** Duplicate loop-scoped address or exceeded module limit -> FAIL even if physical device count fits.

**Planned acceptance:** FA-01-POS, FA-01-NEG. Runtime: NOT_STARTED.

## FA-02 — Standby/alarm current

Scope: `SEGMENT`; mode: `SCALAR`.

**Required inputs:** device exact state-current profile; explicit standby/alarm/simultaneity policy; complete loop and auxiliary membership.

**Algorithm/boundary:** Aggregate each active state origin once; include module/panel own current at declared boundary and expose unsupported/missing load remainder. State labels do not supply current values; signal-return participation does not duplicate a physical load.

**Required technical dimensions:** state-current, own-load-accounting, membership-completeness.

**Consumed dependencies:** device profiles, state selection, loop/auxiliary membership.

**Positive oracle:** 2 detectors at .01A standby + module .02A ->.04A; alarm .03+.03+.02 ->.08A for declared simultaneous state.

**Negative/unsupported case:** One missing alarm current leaves alarm unresolved while standby known subtotal remains labelled.

**Planned acceptance:** FA-02-POS, FA-02-NEG. Runtime: NOT_STARTED.

## FA-03 — Fire electrical basis

Scope: `SEGMENT`; mode: `POWER_WRAPPER`.

**Required inputs:** supported electrical supply model; exact installed conductor/termination evidence; manufacturer/project electrical limit policy.

**Algorithm/boundary:** Consume PWR-03 for explicitly supported radial/one-CP domains and compare declared fire loop/module limits. Closed signal loop does not become a supported dual-fed power mesh. Unsupported manufacturer loop electrical model returns BLOCKED; no partial traversal masquerades as full loop solution.

**Required technical dimensions:** supported-electrical-model, terminal-voltage, declared-limit-match.

**Consumed dependencies:** ELV-PWR-03, physical path, fire electrical policy.

**Positive oracle:** Explicit radial notification/panel feeder24V,.5A,.2ohm ->23.9V, within declared22..26V ->physical basis PASS.

**Negative/unsupported case:** Unsupported dual-feed loop/shared return -> BLOCKED even when FA-07 signal topology passes.

**Planned acceptance:** FA-03-POS, FA-03-NEG. Runtime: NOT_STARTED.

## FA-04 — Fire supply requirement

Scope: `SEGMENT`; mode: `POWER_WRAPPER`.

**Required inputs:** panel/loop/module/notification/auxiliary demands; explicit fire policy requirement set; global PWR-01/02 evidence.

**Algorithm/boundary:** Compose all applicable source-owned requirement constraints on the same physical demand; include concurrent non-fire loads if source shared. Apply reserve/derating at capability boundary once with exact provenance.

**Required technical dimensions:** global-load-coverage, required-capability, available-margin.

**Consumed dependencies:** FA-02 where relevant, ELV-PWR-01, ELV-PWR-02, fire policy.

**Positive oracle:** Explicit total24W,reserve1.25,40W available ->required30W,margin10W; no second conversion/idle addition.

**Negative/unsupported case:** Missing auxiliary load or fire reserve policy prevents full sizing PASS.

**Planned acceptance:** FA-04-POS, FA-04-NEG. Runtime: NOT_STARTED.

## FA-05 — Fire standby/alarm backup

Scope: `SEQUENCE`; mode: `POWER_WRAPPER`.

**Required inputs:** explicit ordered standby/alarm duration policy; complete protected/global load sequence; exact bank and PWR-04 model evidence.

**Algorithm/boundary:** Use one composed protected sequence, including physical loss and selected bank factors once. Compare required/available energy or supported Ah basis. Policy source matching is not verified national fire compliance.

**Required technical dimensions:** required-duration-coverage, sequence-energy, bank-voltage-current, capacity-margin.

**Consumed dependencies:** FA-02, ELV-PWR-04, fire autonomy policy.

**Positive oracle:** Explicit source12W standby7200s +24W alarm1800s ->36Wh; usable134.4Wh ->98.4Wh margin. No default mandated hours.

**Negative/unsupported case:** Duration omitted or model outside discharge/EOD applicability -> BLOCKED; never insert illustrative hours as defaults.

**Planned acceptance:** FA-05-POS, FA-05-NEG. Runtime: NOT_STARTED.

## FA-06 — Notification circuit capacity

Scope: `SEGMENT`; mode: `POWER_WRAPPER`.

**Required inputs:** notification device/output assignment; state/inrush current and output limit policy; supported physical path.

**Algorithm/boundary:** Check distinct active devices, output current limit, peak applicability and terminal voltage using shared PWR evidence. Respect declared simultaneous notification policy; do not infer sound pressure/acoustic coverage.

**Required technical dimensions:** device-count, output-current, terminal-voltage.

**Consumed dependencies:** notification membership, ELV-PWR-01/03, output profile.

**Positive oracle:** 3 devices at .1A ->.3A <=declared .5A output, all terminals within provided voltage bounds ->basis PASS.

**Negative/unsupported case:** Count fits but startup or terminal voltage fails -> per-dimension FAIL; absent acoustic model yields no acoustic claim.

**Planned acceptance:** FA-06-POS, FA-06-NEG. Runtime: NOT_STARTED.

## FA-07 — Fire signal topology integrity

Scope: `DESIGN`; mode: `TOPOLOGY`.

**Required inputs:** signal graph and loop source/return ports; exact closure/branch/isolation/address policy; device membership.

**Algorithm/boundary:** Validate the selected directed/loop topology, required return closure, illegal branches and declared isolator placement policy on the signal layer. Isolator behavior/short-circuit survivability needs an explicit supported model; mere component presence is not proof.

**Required technical dimensions:** signal-closure, branch-policy, address-topology-match.

**Consumed dependencies:** canonical signal graph, loop policy, FA-01 address facts.

**Positive oracle:** Declared source->D1->D2->return path closed with no forbidden branch and unique addresses ->signal basis PASS.

**Negative/unsupported case:** Broken return/illegal branch ->FAIL; passing closure never overrides FA-03 unsupported power-loop finding.

**Planned acceptance:** FA-07-POS, FA-07-NEG. Runtime: NOT_STARTED.

## FA-08 — Fire cable policy/evidence basis

Scope: `DESIGN`; mode: `BASIS`.

**Required inputs:** exact cable edition/classes; route environment evidence; explicit selected policy/source status.

**Algorithm/boundary:** Compare declared cable/environment facts against exact selected project/profile requirements. Output policy-match and evidence completeness; verified compliance is separate and remains UNRESOLVED unless ELV7 verified applicability is actually supplied. No jurisdiction label or fictional class creates certification.

**Required technical dimensions:** cable-policy-match, route-evidence, claim-scope.

**Consumed dependencies:** cable editions, route environment, fire cable policy.

**Positive oracle:** Fictional policy requires TEST_CLASS_A, cable explicitly TEST_CLASS_A and applicable environment evidence ->policy-match PASS; verified compliance UNRESOLVED/not claimed.

**Negative/unsupported case:** Missing fire class or route evidence ->BLOCKED; fictional policy cannot produce VERIFIED_COMPLIANT.

**Planned acceptance:** FA-08-POS, FA-08-NEG. Runtime: NOT_STARTED.

