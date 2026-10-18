# ELV5 — Project Workspace Implementation Roadmap

Status: normative implementation roadmap  
Branch: `feat/flutter-elv5-power-topology-design`

## 1. Purpose

This roadmap assigns the client-oriented Project Workspace requirements to ELV5 without changing ELV5 ownership boundaries.

ELV5 owns:

- node-scoped engineering projections;
- automatic applicability of the fixed 27 discipline processes;
- dependency invalidation/recalculation;
- actionable engineering findings backed by exact evidence;
- vendor-neutral `EquipmentDemand` projection;
- workspace read projections over authoritative engineering state.

ELV5 does not own physical enclosure layout, jurisdictional compliance or SKU selection.

## 2. User journey owned by ELV5

```text
create/select MAIN or NODE
  -> connect endpoints/cables
  -> topology facts change
  -> resolve applicable processes automatically
  -> recalculate affected dependency closure
  -> publish node/project engineering projection
  -> show actionable issue + exact drill-down evidence
  -> rebuild EquipmentDemand when engineering semantics changed
```

The user is not required to select process codes.

## 3. Implementation packages

### W5-0 — authority and baseline reconciliation

Requirements:

- pin exact ELV5 source/runtime/schema versions;
- remove stale `RUNTIME NOT STARTED` wording where contradicted by source evidence;
- preserve 27 process codes and 16 public operations;
- register workspace projection contracts in the authority manifest;
- define one canonical mapping from runtime states to user-facing workspace states.

Exit gate:

- no active authority contradiction;
- source-backed lifecycle status per process/layer;
- workspace docs included in exact-head authority fingerprint.

### W5-1 — DistributionNode domain integration

Implement/adopt a canonical logical `DistributionNode` reference usable by workspace projections.

Minimum semantics:

```text
id
projectId
name
role = MAIN | NODE
kind/descriptive domains
organizational parent (navigation only)
engineering connections are authoritative
```

Rules:

- MAIN/NODE are roles, not different aggregate types;
- navigation parent is never treated as electrical/network connectivity;
- multiple incoming/backup connections remain representable.

Exit gate:

- MAIN/NODE can be created/queried without selecting a calculation process;
- connection graph remains authoritative.

### W5-2 — connection/topology projection

Requirements:

- canonical endpoint-to-endpoint connection identity;
- cable/link references preserve real route/media facts;
- node membership derives from explicit connectivity and declared ownership, not geometry proximity;
- support bulk endpoint assignment to one node;
- reconnect/remove operations invalidate old and new dependency closures correctly.

Performance:

- no N+1 repository loop while resolving a node;
- bulk capture before pure-core execution.

Exit gate:

- deterministic graph for a frozen revision;
- batch connect/reconnect tests pass.

### W5-3 — automatic process applicability

Create an application-layer applicability resolver over project facts.

Examples:

```text
camera membership -> relevant CCTV processes
Ethernet/fiber facts -> relevant LAN processes
ACS door/controller -> relevant ACS processes
fire loop/device -> relevant Fire processes
shared power/battery -> accepted ELV4 evidence + applicable wrappers
```

Rules:

- no 28th process;
- process registry remains canonical;
- applicability is deterministic and evidence-backed;
- `NOT_APPLICABLE` differs from missing data.

Exit gate:

- golden fixtures prove the exact applicable process set for CCTV/LAN/ACS/Fire mixed nodes.

### W5-4 — incremental dependency execution

Requirements:

- one project mutation computes the affected dependency closure;
- only affected nodes/processes become stale;
- unrelated nodes remain current;
- shared-source dependencies propagate upward only where real dependencies exist;
- cancellation/restart cannot publish stale worker results.

Golden mutation:

```text
add Camera-213 to NODE-F2
 -> CCTV bandwidth/storage/PoE dependent evaluations stale
 -> LAN/PoE node projections update where applicable
 -> MAIN aggregate updates
 -> unrelated NODE-F3 remains current
```

Exit gate:

- deterministic invalidation tests;
- race/restart tests;
- no false CURRENT publication.

### W5-5 — node engineering projection

Introduce a read projection conceptually equivalent to:

```dart
final class DistributionNodeEngineeringProjection {
  final String nodeId;
  final WorkspaceEngineeringState state;
  final List<NodeMetric> metrics;
  final List<ActionableEngineeringIssue> issues;
  final List<EvidenceRef> evidence;
  final String projectionFingerprint;
}
```

Typical metrics:

- power/load contribution;
- PoE demand/margin;
- Ethernet/fiber port demand;
- bandwidth/uplink demand;
- recorder/storage demand;
- ACS channels/interfaces;
- fire resources/current;
- source/PSU/autonomy requirements;
- engineering reserve;
- unresolved required evidence.

Rules:

- metrics are projections of authoritative evaluations, never UI calculations;
- non-applicable is not zero;
- unknown mandatory values remain explicit.

Exit gate:

- same frozen evidence => same projection fingerprint.

### W5-6 — actionable issues and progressive disclosure

Every user-facing issue must contain:

```text
stable issue/finding code
subject/node
short human message
severity/user state
required vs available when meaningful
primary remediation action code when safe
evidence references
process/evaluation drill-down references
```

Example:

```text
NODE-F2 requires 4 additional PoE-capable ports.
```

Drill-down preserves exact process ID, algorithm version, inputs, margins, evidence and provenance.

Exit gate:

- no opaque-code-only primary UX for supported issue classes;
- no user-facing message may fabricate missing values.

### W5-7 — EquipmentDemand projection by node

Requirements:

- derive demand from accepted/current ELV5 evidence;
- stable semantic identity independent of UI state;
- merge compatible constraints deterministically;
- reject/conflict incompatible mandatory constraints explicitly;
- apply reserve exactly once;
- emit enough typed capability/electrical/connectivity/reliability/environment information for downstream ELV8 resolution;
- no vendor/SKU/price data.

Exit gate:

- utility, UPS, generator and hybrid-source fixtures;
- unchanged recalculation preserves demand semantic hash;
- price/stock changes do not invalidate ELV5.

### W5-8 — Project Workspace application API

Required read ports:

```text
ProjectWorkspaceQuery
DistributionNodeQuery
ActionableIssueQuery
EngineeringEvidenceQuery
EquipmentDemandRepository
```

Required user commands should reuse existing domain/public command boundaries rather than introducing a parallel workspace command system.

The workspace layer orchestrates:

```text
user command
 -> domain mutation
 -> invalidation
 -> calculation execution
 -> guarded publication
 -> read-projection refresh
```

Exit gate:

- no direct UI -> Drift/SQLite engineering writes;
- no calculation formulas in widgets/controllers.

### W5-9 — first vertical slice

Mandatory golden journey:

```text
Project
 -> NODE-F2
 -> add 12 cameras
 -> batch-connect to NODE-F2
 -> auto-resolve applicable CCTV/LAN/PoE calculations
 -> node projection becomes current
 -> expose ports/PoE/bandwidth/storage metrics
 -> create one actionable insufficiency issue
 -> drill down to exact evidence
 -> produce EquipmentDemand
```

This is the first implementation milestone and must use production paths, not mocks replacing engineering behavior.

## 4. Flutter allocation

Existing feature folders are retained.

```text
features/projects       project entry/list
features/floors         structural navigation
features/rooms          structural navigation
features/editor         primary workspace/canvas/selection inspector
features/calculations   advanced engineering drill-down, not primary workflow
features/reports        downstream issue/export surface
```

New workspace presentation code should be composed around existing editor capabilities rather than copying electrical/cable/catalog logic into another screen.

## 5. Testing strategy

Minimum layers:

1. pure projection unit tests;
2. applicability resolver tests;
3. dependency invalidation tests;
4. repository/bulk-capture tests;
5. public-command vertical tests;
6. close/reopen persistence tests;
7. frozen historical revision tests;
8. workspace widget/view-model tests;
9. performance tests on large node/project fixtures.

## 6. Completion gate

ELV5 workspace implementation is complete when:

- a user can work through MAIN/NODE/cables/equipment without process-code knowledge;
- the correct subset of 27 processes executes automatically;
- node/project projections are deterministic and evidence-backed;
- issues are actionable and drill down to exact runtime evidence;
- incremental recalculation is precise;
- `EquipmentDemand` is stable and downstream-ready;
- no ELV6/ELV7/ELV8 authority is duplicated.
