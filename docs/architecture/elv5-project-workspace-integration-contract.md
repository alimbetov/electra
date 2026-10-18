# ELV5 — Project Workspace Integration Contract

Status: normative ELV5 product/application integration contract  
Branch: `feat/flutter-elv5-power-topology-design`  
Related: [Distribution Node Client Workflow](elv5-distribution-node-user-workflow.md), [Equipment Demand Contract](elv5-equipment-demand-contract.md)

## 1. Purpose

This contract binds the client-oriented Electra Project Workspace to the existing hardened ELV5 runtime without creating a second calculation architecture.

The workspace SHALL be object-first:

```text
project / floor / room / node / equipment / cable
```

ELV5 SHALL remain process/evidence-first internally:

```text
project mutation
 -> dependency invalidation
 -> application InputResolver
 -> immutable typed input
 -> one or more of the canonical 27 process kernels
 -> immutable evaluation/evidence
 -> guarded publication
 -> workspace projections
 -> EquipmentDemand projection
```

The workspace MUST NOT introduce a 28th ELV5 process, a second power topology, a second finding engine or a second source of engineering truth.

## 2. Primary application boundary

The UI SHALL consume ELV5 through application-level query/projection ports.

Conceptual interfaces:

```dart
abstract interface class Elv5WorkspaceProjectionService {
  Future<DistributionNodeEngineeringProjection> nodeProjection(String nodeId);
  Future<ProjectEngineeringProjection> projectProjection(String projectId);
  Future<List<ActionableEngineeringIssue>> issues(String projectId);
  Future<EngineeringDrillDown> drillDown(String evaluationId);
}
```

```dart
abstract interface class EquipmentDemandProjectionQuery {
  Future<List<EquipmentDemand>> forNode(String nodeId);
  Future<List<EquipmentDemand>> forProject(String projectId);
}
```

These are read/query boundaries. They SHALL NOT recalculate formulas inside presentation code.

## 3. Node projection

Canonical node projection:

```dart
final class DistributionNodeEngineeringProjection {
  final String nodeId;
  final String projectRevisionId;
  final EngineeringProjectionFreshness freshness;
  final WorkspaceObjectState userState;
  final List<NodeEngineeringMetric> metrics;
  final List<ActionableEngineeringIssue> issues;
  final List<String> evaluationRefs;
  final String semanticFingerprint;
}
```

Typical metrics MAY include, where applicable:

- connected endpoint count;
- cable/link count;
- power/load contribution;
- PoE power demand;
- used/required/reserved network ports;
- uplink bandwidth;
- recorder ingress/storage requirement;
- ACS channel/interface demand;
- fire address/current resources;
- source/PSU requirement;
- backup/autonomy requirement.

A metric SHALL only be emitted when it is technically applicable and backed by current/accepted evidence. Missing mandatory information SHALL produce explicit unknown/needs-data state rather than a zero.

## 4. User-state projection

Workspace state is a projection over exact engineering evidence, never a replacement for it.

```dart
enum WorkspaceObjectState {
  ready,
  attention,
  critical,
  stale,
  needsData,
}
```

Mapping SHALL be deterministic and versioned.

Recommended precedence:

```text
blocking FAIL / safety blocker        -> CRITICAL
mandatory UNKNOWN/BLOCKED             -> NEEDS_DATA
superseded dependency/current pointer  -> STALE
warning/non-blocking finding           -> ATTENTION
all applicable current dimensions pass -> READY
```

The mapping MUST preserve links to exact ELV5 evaluations/findings.

## 5. Automatic process applicability

The workspace SHALL never maintain a hard-coded independent list of processes to run.

Applicability MUST derive from the same canonical process registry, topology facts and dependency selectors used by ELV5.

Examples:

```text
camera/stream facts -> applicable CCTV-* processes
Ethernet/fiber facts -> applicable LAN-* processes
ACS assembly facts -> applicable ACS-* processes
fire loop/device facts -> applicable FA-* processes
shared power evidence -> exact ELV4 dependencies required by wrappers/processes
```

A UI change such as moving an icon without engineering semantic change MUST NOT trigger unrelated recalculation.

## 6. Workspace mutation flow

Canonical sequence:

```text
user command
 -> authoritative application/domain mutation
 -> revision-aware persistence
 -> dependency closure marked stale
 -> affected ELV5 inputs resolved
 -> affected kernels executed
 -> immutable evaluations persisted
 -> guarded CURRENT pointers published
 -> node/project workspace projections rebuilt
 -> downstream EquipmentDemand semantic diff emitted
```

Projection rebuild MUST NOT be the authority for deciding what calculations are affected.

## 7. Batch connect behavior

Batch endpoint connection is required for practical field/engineering work.

Example:

```text
12 cameras -> Connect to NODE-F2
```

The application SHALL:

1. validate the batch command shape;
2. generate deterministic connection identities;
3. persist all successful mutations under one user intent/command history boundary where supported;
4. compute one affected dependency closure instead of 12 full-project recalculations;
5. report partial failures explicitly if all-or-nothing semantics are not available;
6. publish node/upstream projections only after authoritative mutation/recalculation rules complete.

No batch UI loop may execute one point SQL query per member when bulk repository contracts exist.

## 8. Actionable issues

ELV5 findings SHALL be projected into user language without losing exact codes.

```dart
final class ActionableEngineeringIssue {
  final String issueId;
  final String subjectId;
  final WorkspaceObjectState state;
  final String messageKey;
  final Map<String, Object?> messageArgs;
  final List<EngineeringActionRef> actions;
  final List<String> findingRefs;
  final List<String> evaluationRefs;
}
```

Example projection:

```text
Finding: insufficient port reserve
User: NODE-F2 requires 4 additional PoE-capable ports.
```

The localized sentence is presentation data. The stable finding/evaluation references remain authoritative for tests, automation and drill-down.

## 9. Progressive disclosure

ELV5 SHALL expose enough information for three UX levels.

```text
L1  user message/action
L2  engineering metric + required/available/margin
L3  evaluation/process/version/input/evidence/provenance
```

No L1 simplification may fabricate certainty that L3 evidence does not support.

## 10. MAIN aggregation

MAIN aggregation SHALL reuse canonical origin identities and dependency evidence.

The workspace MAY present:

```text
total downstream connected demand
critical/backup contribution
network/uplink totals
node count
unresolved child dependencies
```

but ELV5 MUST NOT sum values that are not semantically additive.

Examples:

- duplicate shared physical loads MUST count once;
- reserve MUST be applied at its owning policy level only;
- multicast traffic MUST follow declared flow semantics;
- fire addresses are scope/domain resources, not arbitrary additive totals;
- battery/backup truth remains owned by the exact shared physical model/evidence.

## 11. EquipmentDemand handoff

Workspace presentation and EquipmentDemand use the same current engineering basis but serve different purposes.

```text
ELV5 evaluations
   -> Workspace projection (human decision support)
   -> EquipmentDemand projection (ELV8 machine selection input)
```

The UI SHALL NOT reverse-engineer EquipmentDemand from rendered metric strings.

`EquipmentDemand` remains vendor-neutral and SHALL NOT contain:

```text
manufacturer
SKU
price
stock
lead time
```

## 12. Staleness semantics

A project mutation that affects an evaluation SHALL immediately make prior dependent workspace projections non-current.

The UI MAY continue to show the previous value for continuity only when it is explicitly marked stale.

Example:

```text
PoE demand: 286 W  (recalculating / stale)
```

It MUST NOT show the old value as current PASS while the new dependency closure is unresolved.

## 13. Configuration proposal boundary

ELV5 may expose engineering remediation requirements but SHALL NOT select concrete catalog products.

Example ELV5 result:

```text
Required network ports >= 28
PoE budget >= 336 W
required uplink capability >= X
```

ELV8 owns:

```text
48-port switch candidate
alternative candidate
price/availability ranking
```

Applying an ELV8 proposal may mutate project equipment, after which ELV5 recalculates affected engineering truth normally.

## 14. Flutter feature mapping

Recommended incremental integration:

```text
apps/mobile/lib/features/projects
  opens ProjectWorkspace for selected project

apps/mobile/lib/features/editor
  canvas + object selection + contextual mutation intents
  consumes workspace projection/controller

apps/mobile/lib/features/calculations
  advanced ELV5 drill-down / diagnostics
  not the primary calculate workflow

apps/mobile/lib/features/reports
  consumes frozen/current evidence for issue/report surfaces
```

Application and data layers SHALL host resolvers/repositories/projection builders. `engineering_core` remains Flutter/Drift/UI independent.

## 15. Controller/ViewModel boundary

Conceptual controller:

```dart
abstract interface class ProjectWorkspaceController {
  ProjectWorkspaceState get state;

  Future<void> openProject(String projectId);
  Future<void> selectObject(String objectId);
  Future<void> dispatch(WorkspaceIntent intent);
  Future<void> openEngineeringDetail(String evaluationId);
}
```

The controller SHALL coordinate application commands and projection refresh; it SHALL NOT implement discipline formulas.

## 16. Performance obligations

- one mutation recalculates exact affected dependency closure, not all 27 processes globally;
- batch connection uses bulk capture/resolution;
- projection queries are bounded and index-backed;
- large issue/tree lists are virtualized/lazy;
- medium/large kernels remain off the Flutter UI isolate according to the existing performance contract;
- widget rebuild frequency/order MUST NOT affect engineering hashes or result ordering;
- project reopen uses persisted evaluations/current pointers/projections rather than replaying the whole project solely to render the first frame.

## 17. Acceptance scenarios

ELV5 workspace integration is ready when:

1. a project can be edited and recalculated without the user opening the Calculations feature;
2. creating MAIN/NODE does not create a new ELV5 process identity;
3. batch connecting 12 cameras causes one bounded affected recalculation workflow;
4. node summaries are derived from current immutable evaluation evidence;
5. a mandatory unknown becomes `NEEDS_DATA`, never user-facing READY;
6. stale values are visibly stale until guarded publication of new current results;
7. opening engineering detail reaches exact process/evaluation/provenance;
8. MAIN aggregation proves no double counting for shared power, reserve and flow identities;
9. workspace metrics and EquipmentDemand are independent projections over the same engineering evidence;
10. an ELV8 concrete selection can be applied and then re-enter normal ELV5 dependency/recalculation flow without bypasses;
11. widgets contain no discipline calculation formulas;
12. `engineering_core` retains no Flutter/Drift/UI dependency.

## 18. Non-goals

This contract does NOT introduce:

- a new ELV5 process;
- a new public ELV5 wire command family by itself;
- a generic workflow engine;
- a second finding taxonomy;
- catalog/SKU selection inside ELV5;
- physical enclosure placement inside ELV5;
- normative compliance verdicts inside ELV5;
- a duplicate project/revision/history model.

The intent is to make the existing engineering system feel simple to the user without weakening its deterministic architecture.
