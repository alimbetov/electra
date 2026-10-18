# Electra — ELV5 Discipline Calculation Design Specification

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent: ELV4 `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`
Entry: [authoritative index](elv5-authoritative-spec-index.md).

Merged implementation and mandatory P0–P9 deltas: [baseline contract](elv5-implementation/implemented-baseline.md). Mandatory runtime contracts are split by concern: [base runtime](elv5-implementation/code-level-runtime-contract.md), [engineering primitives](elv5-implementation/engineering-primitives-contract.md), [typed 27-process API](elv5-implementation/typed-process-api.md), [Drift schema 24](elv5-implementation/persistence-schema-contract.md), [hardening amendments](elv5-implementation/code-level-hardening-amendments.md) and [executable qualification](elv5-implementation/qualification-contract.md). Where a later hardening amendment conflicts with older detailed runtime/persistence wording, the amendment governs.

## 1. Scope and ten-package responsibility

ELV5 implements stable CCTV-01…06, LAN-01…07, ACS-01…06 and FA-01…08 (**27 process codes**). It adds typed discipline inputs/policies, reproducible calculations, explicit selected reference evidence and engineer explanations. ELV4 retains shared physical power processes; ELV3 retains physical cable/resource/run facts. No process is inferred from a product label and no arbitrary formula/property editor replaces a registered discipline process.

P0 reconciles entry capabilities; P1 defines typed engineering primitives/profiles/registry; P2 implements schema 24, commands/snapshots; P3 CCTV; P4 LAN; P5 ACS; P6 Fire; P7 targeted recalculation/workspace; P8 executable qualification; P9 exact-head closure/handoff. P7 dependency design and P8 fixture design begin at P1/P2. Runtime follows package dependencies while all package contracts are designed together.

## 2. Reuse and nonduplication

| Foundation | ELV5 use / explicit extension |
|---|---|
| Components, ports, connections, assemblies, memberships | Same canonical identities; record non-owning assignments and exact definition/policy refs |
| ELV2 exact immutable catalogs and explicit adoption | Add discipline calculation definition editions; no latest-ref fallback |
| ELV3 cables/resources/runs/installed lengths | Read exact realized path evidence; no second length/cable allocation |
| ELV4 PWR-01…06 and scenario/source graph | Consume immutable evidence or execute the same pure kernel with exact scoped inputs; never copy formulas |
| RM01 result ownership | Preserve dedicated ELV4 power records/pointers and legacy results; add isolated discipline records/pointers and explicit read dispatch |
| RM04 segment/sequence scopes | Keep `PowerNodeKeyV2` unchanged; introduce owner-isolated ELV5 DESIGN/SEGMENT/SEQUENCE key |
| RM08 history / RM07 remapping / RM10 allocator | Same coordinated revision/session/cursor and typed identity mapping; no second ELV5 history platform |
| RM09 numeric foundation | Extend exact decimal/rational arithmetic with dimension-safe quantities and separately versioned bounded geometry/transcendental backend |
| RM13 facts and RM14 freeze | Exact consumed-input projection and nonblocking committed-evidence capture; no durable RUNNING cache state |

New result key: `["engineering-node-v3", owner, revisionId, scenarioKey, scopeKind, scopeId, processCode, subjectKind, subjectId]` within project. `owner=ELV5`; DESIGN uses `scenarioKey=NONE`; SEGMENT requires actual scenario/segment; SEQUENCE uses actual scenario with ordered segments. Existing ELV4 v2 keys remain readable and unchanged, not rewritten by migration.

ELV5 cannot insert CCTV/LAN/ACS/FA values into the ELV4-only evaluation schema. New discipline evaluation storage and owner/schema dispatch remain isolated from existing power/legacy records. Migration does not move or retag historical evidence.

Canonical ownership prohibition is strict: ELV5 never becomes a second owner of project revisions, cables, ports, components, power sources, battery banks, command ledger/history or immutable device capabilities. Recorder/VMS limits, for example, resolve from one exact immutable catalog/component definition; ELV5 owns the selected accounting basis and non-owning assignments, not a second editable capability record.

## 3. Engineering primitives, inputs and policy ownership

Every discipline input identifies project/revision, process/subject, scope, operating case, exact policy edition/hash, canonical technical facts, evidence basis/applicability and consumed upstream evaluation IDs/fingerprints. Output stores canonical units, exact/bounded quantities, per-dimension completion/assessment, structured calculation steps, stable finding codes and exact provenance.

### 3.1 Dimension-safe exact values

Production kernels use dimension-safe exact values equivalent to `Elv5Quantity<D>`. At minimum the type system/closed value objects distinguish:

```text
length / duration / voltage / current / resistance / power / energy
bitrate / byte capacity / ratio
attenuation dB / optical level dBm
angle / temperature / integer count
```

A generic exact number is not sufficient if units/dimensions can be confused. In particular `dB != dBm` and `bit/s != byte capacity`.

Exact rational/decimal normalization is canonical. NaN/infinity/negative-zero and locale-formatted numerics never cross the engineering kernel boundary.

### 3.2 Evidence basis and uncertainty

Every verdict-relevant engineering value declares provenance/basis such as guaranteed manufacturer limit, typical value, measurement, project-specified fact, exact/bounded derivation or estimate. A typical/estimated nominal cannot satisfy a dimension that explicitly requires a guaranteed worst-case bound.

Uncertainty/evidence quality is independent from design reserve. Applying reserve does not turn an estimate into guaranteed evidence.

### 3.3 Operating cases

Expected, peak, startup, holding, standby, alarm, emergency release, backup and other project cases are explicit captured identities. A kernel cannot combine values from incompatible operating cases unless a code-owned composition rule expressly allows it.

CCTV expected storage bitrate, peak network bitrate, lock startup current and fire standby/alarm durations therefore remain separate engineering dimensions/cases rather than anonymous averages.

### 3.4 Deterministic time

Recurrence expansion records IANA timezone, exact tzdb version, DST gap/overlap rule and half-open `[start,end)` semantics. Expansion yields UTC evidence. Host timezone defaults cannot affect storage/autonomy results or hashes.

### 3.5 Geometry frames

Camera/geometry coordinates include explicit frame identity, handedness/axis convention and transform-chain fingerprint. Mixed frames fail closed unless an exact captured transform is supplied.

### 3.6 Status axes

Freshness CURRENT/STALE is on the pointer; completion COMPLETE/PARTIAL/BLOCKED, assessment PASS/FAIL/UNRESOLVED/NOT_ASSESSED and execution SUCCEEDED/FAILED remain separate. Workspace RUNNING/CANCELLED is transient.

A completed engineering violation is SUCCEEDED/COMPLETE/FAIL, not execution failure. Missing model/input may be BLOCKED/PARTIAL/UNRESOLVED. ELV6/7/8-owned dimensions remain NOT_ASSESSED where the process contract says so.

Missing policy is unresolved. Numeric zero is explicit. Immutable policy fields include applicability, units, supported modes, required thresholds/reserves/durations and source status. A fictional/project-authored policy can qualify arithmetic/policy matching but never verified jurisdictional compliance; ELV7 owns that claim.

## 4. Shared physical sources and requirement composition

Discipline wrappers resolve the complete physical source/capacity/protected-load closure. They display a system contribution alongside the full project total from the **same immutable evidence**. Independent discipline subtotals are never summed as if shared physical sources were separate.

A source-owned requirement set combines all applicable policies with explicit provenance: each capability dimension uses the strongest applicable requirement on the same physical demand, without repeated reserve/derating multiplication. Conflicting modes/durations/coverage policies block composition until explicit project policy/scenario data resolves them.

A battery shared by systems evaluates one composed ordered protected sequence, including concurrent non-calling-system loads. ACS/fire/CCTV/LAN wrappers may expose discipline contribution but may not calculate a standalone smaller bank/source and call the shared context PASS.

## 5. Calculation architecture and 27 typed process APIs

[Process contracts](elv5-implementation/process-contracts.md) define math, dimensions, dependencies and claim boundaries. [Typed process API](elv5-implementation/typed-process-api.md) defines the minimum process-specific Dart input/output surfaces for all 27 codes. [Engineering primitives](elv5-implementation/engineering-primitives-contract.md) define shared numeric/evidence/time/frame/hash semantics.

Runtime registry is code-owned. Every definition exposes:

```text
stable process code + discipline
algorithm/input/output/numeric versions
legal scope kinds
required dimensions
upstream typed dependency bindings
process-specific typed input/output
```

Dynamic `Map<String,Object?>` is allowed at strict JSON/storage/projection boundaries only; it cannot be the semantic API of a production calculation kernel.

PWR wrappers preserve global immutable evidence identity. Compatible upstream evidence can be reused only when scope, physical inputs, policy applicability and algorithm/numeric versions match. Missing physical realization is BLOCKED, not estimated from room distance.

### CCTV

CCTV coverage v1 supports declared rectilinear pinhole intrinsics and flat target plane in an explicit captured frame. Ray-plane intersections and numeric bounds are explicit; obstructions/distortion/fisheye/RF/DORI/legal-identification claims are unsupported unless a later exact model is selected. Optional technical pixel density does not imply DORI/compliance.

Bandwidth distinguishes expected payload, peak payload, directed network copies and optional physical wire-rate capacity model. No universal hidden overhead percentage exists.

Storage uses unique recorded time over one horizon, deterministic temporal policy, selected estimate/guaranteed sizing basis, reserve once and redundancy once. Pool-level rational aggregation performs the declared final ceil once.

Recorder capacity independently evaluates accounting basis, channels/licenses, ingress/egress/codec/storage where those dimensions are in claim scope. Device capabilities resolve from immutable catalog evidence.

### LAN

Permanent/channel sections, patch sections and explicit allowances are not double counted. Port/panel occupancy uses canonical physical port identity.

Optical budget is bidirectional and separates signed dBm levels from nonnegative dB loss/design margin. Sensitivity and overload are independent. Passing optical power budget does not imply dispersion/reach unless an exact registered reach profile/model is also evaluated.

LAN-06 provides rack demand/capacity basis; RU/weight/depth evidence may be handed to ELV6 but does not claim actual slot/depth/thermal/cable-management fit.

### ACS

Door role alternatives/multiplicities, controller resources and lock power states are explicit. A relay/control relation is not a conductive supply edge.

ACS-06 includes selected lock safety mode and technical release truth table for at least normal access, request-to-exit, fire release, emergency break-glass and power failure. Control/feed/monitoring/release paths are separate. This validates technical project behavior only; ELV7 owns verified egress/fire-code applicability/compliance.

### Fire alarm

Physical-device capacity and complete expanded address claims are independent. Standby/alarm state currents, explicit autonomy sequence, notification current/terminal-voltage and signal topology are separate dimensions. Signal-loop closure does not magically create a supported electrical mesh. Policy/evidence match is not certified compliance.

## 6. Commands, replay and storage

### 6.1 Public command authority

ELV5 uses one strict public family:

```text
electra.elv5-discipline-command.v1
payloadSchemaVersion = 1
```

The exact top-level envelope is:

```text
schema
operation
payloadSchemaVersion
projectId
designRevisionId
commandId
expectedDesignRowRevision
expectedRows
reviewedImpactFingerprint
payload
```

Unknown or missing fields fail closed.

The initial registry remains exactly **16 operations**:

```text
BIND_DISCIPLINE_POLICY
ADOPT_DISCIPLINE_POLICY
RELEASE_DISCIPLINE_POLICY
REPLACE_CAMERA_STREAMS
REPLACE_RECORDING_ASSIGNMENTS
REPLACE_RECORDER_ASSIGNMENTS
REPLACE_LINK_COMPOSITION
REPLACE_PORT_CAPACITY_ASSIGNMENTS
REPLACE_OPTICAL_LINK_ASSIGNMENTS
REPLACE_RACK_CAPACITY_BASIS
REPLACE_PATCH_PANEL_ASSIGNMENTS
REPLACE_DOOR_ROLE_ASSIGNMENTS
REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS
REPLACE_FIRE_LOOP_ASSIGNMENTS
REPLACE_NOTIFICATION_CIRCUIT_ASSIGNMENTS
CALCULATE_DISCIPLINE_PROCESS
```

Exact key sets are governed by [command-registry.json](elv5-implementation/command-registry.json). [Command examples](elv5-implementation/command-examples.json) must match it. Hardened semantics for camera subscriptions, recording temporal/reserve/redundancy basis and ACS release truth table are normative in [code-level hardening amendments](elv5-implementation/code-level-hardening-amendments.md).

ELV4 revision freeze/create-next remains the only public revision boundary. ELV5 extends the same transaction/snapshot/remapping services and does not register competing revision commands.

### 6.2 Replay and history

Replay order is mandatory: strict decode/canonical request hash → transaction → command ledger lookup → same-hash replay or different-hash conflict → only then mutable preconditions/CAS → server-side old/new impact → mutation → union(old,new) invalidation → complete forward/inverse shared history → ledger response → commit.

`reviewedImpactFingerprint` and dependencies are resolved server-side; client dependency sets are never authoritative.

### 6.3 Schema 24

The accepted inherited DB schema is 23. ELV5 additive target is frozen as **schema 24**. [Persistence schema contract](elv5-implementation/persistence-schema-contract.md) fixes semantic roots/members, PK/FK/index rules, immutable evaluations/pointers, dependency reverse index and discipline snapshot section.

Schema 24 includes, among other aggregates, policy bindings, camera streams/subscriptions, recording pool+assignment+schedule state, recorder accounting assignments, link/port/optical/rack/panel aspects, ACS door release truth table/controller resources, fire loop devices/full address claims and notification assignments.

ELV5 reuses existing `ElvCommandLedgerStore` and revision-history/cursor infrastructure. It does not create a separate ELV5 ledger/undo platform.

### 6.4 Canonical hashing

All request/input/output/snapshot hashes use `electra.canonical-json.v1`. Object keys/set members are canonicalized; semantically ordered paths/sequences preserve order. Exact decimal/rational encodings are stable. Unknown fields are rejected rather than silently omitted from hash.

Deterministic process output hash includes engineering statuses/dimensions/steps/findings/provenance but excludes volatile `evaluationId` and completion timestamp.

### 6.5 Capture → pure run → guarded coherent publish

Long calculation holds no DB write transaction. Capture records exact root/member/set markers, policy hashes, canonical facts, upstream immutable evidence/pointer generations and target pointer generations. Pure kernel has no wall-clock/random/locale/host-timezone/latest-ref dependency.

Publish revalidates every consumed identity/version/generation and the canonical input fingerprint. For one multi-node calculate request, publication is **all-or-nothing**: immutable inserts + pointer CAS + reverse-index update commit atomically only if all requested nodes still match captured preconditions. A single conflicting target/dependency prevents any requested node from becoming CURRENT.

Freeze wins over late publication. Create-next remaps revision-owned state but never retags old immutable evaluations.

## 7. Dependencies, workspace and stage boundaries

Dependency keys distinguish:

```text
FACT
SET
POLICY
EVAL
POINTER generation
MISSING expected identity
```

Mutations invalidate `union(oldClosure,newClosure)`. Creation of a previously missing fact invalidates nodes that consumed a `MISSING/...` marker. Registry validation rejects unknown upstream nodes, illegal scope bindings and feedback cycles.

Workspace shows process/subject/scope/operating case, current/stale state, dimensions, actual/required/margin values, calculation steps, stable findings, policy edition/hash, source provenance, upstream immutable evidence and claim limitations. A stale prior PASS remains visibly stale evidence, never current success.

Stage boundaries remain strict:

- **ELV6** owns actual rack/cabinet U-position, clearance, thermal/ventilation and cable-management/layout fit;
- **ELV7** owns normative applicability and verified jurisdictional compliance/certification;
- **ELV8** owns concrete commercial SKU/BOM/quotes/procurement deliverables.

ELV5 may provide technical demand/evidence to those stages but cannot claim their conclusions.

## 8. Qualification and closure gates

P8 is governed by [qualification-contract.md](elv5-implementation/qualification-contract.md) and uses L0–L6:

```text
L0 engineering primitives/canonical hash
L1 typed pure process kernels
L2 strict 16-command codecs/adversarial semantics
L3 schema 24 migration/persistence/restart
L4 UoW/replay/history/failure injection
L5 public-command process verticals
L6 concurrency/freeze/historical matrix
```

The machine-readable qualification manifest must contain exactly **54 primary entries**: POS and NEG/unsupported for each of 27 process codes. Every primary oracle executes through production public setup/dispatcher, real file SQLite, production capture resolver, typed registry/kernel, guarded publication, projection and close/reopen verification.

Qualification includes explicit no-false-PASS sentinels preventing unsupported/missing/stale/fictional evidence or later-stage basis from being displayed as current technical/compliance/layout success.

Schema 24 migration is tested fresh, 23→24 and from every supported historical origin through the accepted migration chain. Failure rollback/reopen, response-loss replay, undo/redo restart safety, multi-connection races, publish-vs-freeze and R1→R2 immutability are mandatory.

P9 closes only at one exact source SHA after design guards, Drift generation/migrations, format/analyzers, complete core/mobile tests and all L0–L6 evidence pass. A merge event is not runtime acceptance.

## 9. Audit status

The [initial technical audit](../audit/elv5-technical-audit.md) resolved **8** discipline-contract findings in specification.

The [second-pass engineering/architecture hardening audit](../audit/elv5-engineering-architecture-hardening-audit.md) resolved **14** additional design findings: 10 HIGH and 4 MEDIUM, covering dimensional typing, canonical hashing, evidence basis/uncertainty, operating cases, deterministic time/frames, process-specific APIs, concrete schema ownership, coherent batch publication, ACS release semantics, CCTV wire-rate basis, optical reach scope, executable qualification and scale behavior.

Current design total:

```text
8 initial findings
+ 14 hardening findings
= 22 specification findings resolved
```

This is design hardening only. Runtime remains `NOT STARTED` until Dart/Drift implementation and executable P8/P9 evidence exist.

## 10. Implementation entry verdict

ELV5 is now sufficiently specified to start implementation in P1/P2 without reopening foundational choices for units, hash semantics, public operation inventory, migration number, persistence ownership, process inputs/outputs, concurrency publication or acceptance strategy.

Implementation MUST treat any divergence among governing design, hardening amendment, machine registries/examples, typed process definitions, schema 24 and qualification manifest as a blocking architecture defect—not as local developer discretion.
