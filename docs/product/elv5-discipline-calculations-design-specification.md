# Electra — ELV5 Discipline Calculation Design Specification

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent: ELV4 `4c35840bf1453df8adc49cce18d937fe20a52801`
Entry: [authoritative index](elv5-authoritative-spec-index.md).

## 1. Scope and ten-package responsibility

ELV5 implements stable CCTV-01…06, LAN-01…07, ACS-01…06 and FA-01…08 (27 codes). It adds typed discipline inputs/policies, reproducible calculations, explicit selected reference evidence and engineer explanations. ELV4 retains six ELV-PWR processes; ELV3 retains physical cable/resource/run facts. No code is inferred from a product label and no arbitrary formula/property editor replaces a discipline process.

P0 reconciles entry capabilities; P1 defines typed profiles/registry; P2 integrates persistence/snapshots; P3 CCTV; P4 LAN; P5 ACS; P6 Fire; P7 targeted recalculation/workspace; P8 integrated acceptance; P9 closure/handoff. P7 dependency design and P8 fixture design start at P1/P2. Runtime follows package dependencies while all package contracts are designed together.

## 2. Reuse and nonduplication

| Foundation | ELV5 use / explicit extension |
|---|---|
| Components, ports, connections, assemblies, memberships | Same canonical identities; record non-owning assignments and policy refs |
| ELV2 exact immutable catalogs and explicit adoption | Add discipline calculation definition editions; no latest-ref fallback |
| ELV3 cables/resources/runs/installed lengths | Read exact realized path evidence; no second length/cable allocation |
| ELV4 PWR-01…06 and scenario/source graph | Consume immutable evidence or execute the same pure kernel with exact scoped inputs; never copy formulas |
| RM01 result ownership | Extend resultOwner enum with ELV5; pointer/evaluation kinds remain shared; old clients filter their own owner before decode/retirement |
| RM04 segment/sequence scopes | Extend shared node codec by registered discipline namespace; add DESIGN scope for geometry/inventory independent of scenario |
| RM08 history / RM07 remapping / RM10 allocator | Same coordinated revision/session/cursors and typed identity mapping; no project-only history fallback |
| RM09 numeric v2 | Exact decimal/rational scalar math; conservative bounded geometry/transcendental backend must be separately versioned |
| RM13 facts and RM14 freeze | Exact consumed-input projection and nonblocking committed-evidence capture; no durable RUNNING cache state |

New result key: `["engineering-node-v3", owner, revisionId, scenarioKey, scopeKind, scopeId, processCode, subjectKind, subjectId]` within project. owner=ELV5; DESIGN uses scenarioKey=`NONE` and explicit subject/design scope; SEGMENT requires actual scenario/segment; SEQUENCE actual scenario with ordered segments. Existing ELV4 v2 keys remain readable and unchanged, not rewritten by migration. Registry selects exact scope(s) and codec versions; numerical requests cannot omit scope.

The existing ELV4 evaluation schema enumerates only ELV-PWR codes. ELV5 cannot insert CCTV/LAN/ACS/FA values into that schema illegally. A shared registered engineering evaluation v3 envelope adds ELV5 codes and DESIGN scope through explicit owner/schema dispatch, retaining old v1/v2 decoders and immutable hashes. Input/output payloads remain process-specific. P1/P2 must supply concrete schema/examples before implementation acceptance.

## 3. Inputs and policy ownership

Every discipline input identifies project/revision, process and subject, exact policy edition/hash, canonical technical facts, selected scenario/segment where needed, and consumed upstream evaluation IDs/fingerprints. Output stores units, quantities/intervals, per-dimension completion/assessment, structured steps, findings and exact provenance.

Freshness CURRENT/STALE is on pointer; completion COMPLETE/PARTIAL/BLOCKED, assessment PASS/FAIL/UNRESOLVED and execution SUCCEEDED/FAILED remain separate. Workspace RUNNING/CANCELLED is transient. Overall required-positive PASS cannot be inferred from one subtotal. Policy-match is distinct from verified jurisdictional compliance.

Missing policy is unresolved. Numeric zero is explicit. Immutable policy fields include applicability, units, supported modes, required thresholds/reserves/durations and source status FICTIONAL/PROJECT_AUTHORED/VERIFIED_EXTERNAL. ELV5 records source status; ELV7 owns verified jurisdictional compliance and rule-pack certification. A fictional policy can qualify arithmetic/policy matching, never a national compliance claim.

### Shared physical sources

Discipline wrappers resolve the complete project source/capacity/protected-load closure. Display a system contribution alongside the full project total. Never sum independent discipline PoE/UPS/battery totals as if sources were distinct. A source-owned requirement set combines all applicable policies with explicit provenance: for each dimension the required capability is the maximum applicable requirement on the same physical demand, not repeated reserve multiplications. A conflict in modes/durations/coverage policy blocks composition until an explicit project scenario/requirement set resolves it. Common demand/loss inputs and policy-requirement outputs are separate quantities.

A battery shared by systems evaluates one composed ordered protected sequence, including concurrent non-calling-system loads. Wrappers reference the global evidence and contribution breakdown. They do not compute a standalone smaller bank requirement while showing the shared bank as passing.

## 4. Calculation architecture and scopes

[27 process contracts](elv5-implementation/process-contracts.md) define typed inputs, math, output dimensions, dependencies and positive/negative oracles. Process registry is code-owned; users select typed profile data, not executable expressions. Engine execution is a dependency DAG over exact versioned definitions.

PWR wrappers preserve global evidence identity. A discipline result records its policy/context and immutable consumed PWR evidence ID/fingerprint. Compatible evidence may be reused only when scope, physical inputs, policy applicability and algorithm/numeric versions match. A process requiring missing physical realization is BLOCKED rather than estimating length from room distance.

CCTV bandwidth distinguishes expected/peak, encoded streams, network copies and recordings. Storage uses unique recorded time over one horizon; no retention factor is applied twice. LAN channel sections count installed/patch/reserve facts once. Optical budget checks receiver sensitivity and overload in both directions using signed dBm/dB arithmetic. ACS counts resource assignments, not repeated system memberships. Fire signal-loop topology is not assumed to be a supported power mesh.

CCTV coverage first supports declared rectilinear pinhole intrinsics and a flat target plane in the captured project frame. Ray-plane intersections and numeric bounds are explicit; obstructions/distortion/fisheye/RF/DORI claims remain unsupported unless a later exact model version is selected. Unoccluded geometric coverage never implies visibility through walls.

## 5. Commands, storage and freeze

Proposed public command families: Bind/Adopt/ReleaseDisciplinePolicy; ReplaceCameraStreams; ReplaceRecordingAssignments; ReplaceLinkComposition; ReplacePortCapacityAssignments; ReplaceDoorRoleAssignments; ReplaceFireLoopAssignments; CalculateDisciplineProcess. Existing assembly/topology/catalog writers remain owners of their existing canonical entities; these commands store typed calculation aspects/non-owning assignments and participate in the same UoW.

Every mutation uses commandId, explicit revision/token, aggregate expected revisions and reviewed impact where shared. Replay precedes mutable preconditions; state/projection/old+new closure invalidation/history/ledger commit atomically. Full forward/inverse payloads are durable for reversible edits; no schema/hash-only redo.

Persist scoped roots with composite revision/logical IDs and explicit FK-bearing members: DisciplinePolicyBindings, CameraStreamBindings, RecordingAssignments/ScheduleSegments, LinkSectionAssignments, PortCapacityAssignments, DoorCalculationAssignments, FireLoopDeviceAssignments and derived definition/provenance refs. Enclosure topology stays non-owning. Actual schema number depends on implemented parent migrations, not current design numbering.

Owner ELV5 POINTER/EVALUATION shares ProjectDerivedResults after RM01 isolation. Immutable evaluations and guarded pointer generations use capture → pure run → revalidated publication. Batch publication includes exact consumed versions. Coordinated freeze adds a versioned discipline section and manifest extension under the same revision ID; retain existing physical/power hashes and verify captured content. Historical pre-ELV5 returns ELV5_NOT_CAPTURED, never empty/pass or latest-row fallback. Create-next remaps every revision-owned assignment/physical reference; DESIGN/SEGMENT/SEQUENCE keys are regenerated while original evidence stays provenance.

## 6. Dependencies, UI and boundaries

Each process has a canonical consumed-facts map exactly matching dependency keys, including missing definitions/member sets. Mutations invalidate union(old,new) closures. Bitrate change affects stream/bandwidth/storage/recorder capacity, not door completeness; physical route change affects relevant link/electrical/optical consumers, not unrelated recording schedules. Shared source/bank change fans out across all calling disciplines and frozen history remains immutable.

One progressive calculation side panel in the existing editor: selected discipline/subject → process summary → inputs/policy → affected path/equipment → how-calculated → findings → comparison. Revision/scenario/scope are explicit; inactive cards collapse; shared source cards show project total. Preview/stale conflict retains draft; frozen view is read-only; compact/keyboard/back behavior uses the shared editor conventions.

ELV6 owns actual rack/cabinet layout/fit; LAN-06 provides a demand/capacity basis only. ELV7 owns verified compliance; FA-08 provides explicit policy matching and missing-evidence findings. ELV8 owns commercial selection/BOM/quotes; raw storage/capacity requirement estimates do not select products.

## 7. Qualification and entry gates

All 27 codes have a planned positive technical oracle and a negative/unsupported case. Core qualification covers four disciplines in one FK-valid public-command project with shared source, change isolation, migration/restart, frozen R1/R2, replay, rollback and publication/freeze races. Required dimensions are declared per process; unsupported future dimensions cannot be passed silently. Explicit basis-only processes display that scope and do not claim later-stage completeness.

P0 requires evidenced ELV4 capabilities (RM01–RM15, six PWR kernels, exact numeric/physical models, scoped snapshots and accepted qualified verticals). The inherited branch contains designs and specification probes, not that runtime evidence. No merge or SPEC_RESOLVED label closes this gate.

## 8. Technical audit refinements

The [initial technical audit and remediation](../audit/elv5-technical-audit.md) resolved eight design findings. Pool-level integer byte ceilings, explicit estimate/guarantee retention basis, declared recorder channel accounting key, full address sets, physical-versus-reserve optical separation, gross/net RU basis and typed upstream scope/subject bindings are mandatory refinements to the above process contracts. Runtime and baseline gates remain open.

CCTV-01 qualification requires both bounded FOV angles and footprint/model applicability; process-contracts.md fixes the bounded rational pinhole-angle backend. An unavailable backend produces a partial/blocked result, not complete coverage PASS.
