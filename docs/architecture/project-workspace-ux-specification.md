# Electra — Project Workspace UX Specification

Status: target product/implementation specification  
Branch: `target/electra-professional-electrical-platform`  
Parent product contract: [Client-Oriented Engineering Workflow](client-oriented-engineering-workflow.md)

## 1. Product objective

Electra SHALL present one coherent engineering workspace centered on the real project, not on internal ELV stages or calculation codes.

Primary user loop:

```text
Project
  -> structure the object
  -> place MAIN/NODE distribution points
  -> place end equipment
  -> connect cables/routes/sources
  -> Electra recalculates automatically
  -> review actionable issues
  -> review proposed configuration/remediation
  -> explicitly Apply decisions
  -> qualify
  -> Freeze
  -> issue deliverables
```

ELV1–ELV8 remain internal engineering architecture. The normal user SHALL NOT need to know which stage owns a result.

## 2. Information architecture

The current application capabilities map naturally to one workspace:

```text
projects
  -> workspace
       -> structure       (floors / rooms / zones / nodes)
       -> design          (equipment / cables / routes / sources)
       -> issues          (cross-domain actionable findings)
       -> configure       (recommendations / alternatives / fit)
       -> issue           (freeze / reports / schedules / BOM)
```

Existing `calculations` remains an engineering drill-down/diagnostic surface, not the primary workflow entry point.
Existing `reports` becomes the issue/deliverables surface after freeze/qualification.

## 3. Primary navigation

The canonical project navigation SHALL expose four primary destinations:

```text
PROJECT | ISSUES | CONFIGURE | ISSUE
```

### PROJECT
Model and inspect the object.

### ISSUES
Show engineering blockers, warnings, stale results and missing data across the project.

### CONFIGURE
Show deterministic remediation proposals and ELV8 equipment/configuration proposals. Nothing is applied silently.

### ISSUE
Show readiness, freeze/revision controls and deliverables.

A separate advanced `Engineering` or `Calculations` entry MAY expose raw process/evidence detail but SHALL NOT be required for normal work.

## 4. Workspace layout

### 4.1 Tablet/desktop

```text
+----------------------------------------------------------------+
| Project name                         Revision / maturity / status |
+------------------+----------------------------+------------------+
| Project tree     | Canvas / topology / plan   | Inspector        |
|                  |                            |                  |
| Building         | selected floor/zone/node   | selected object  |
|  Floor 1         | routes/connections         | engineering      |
|   MAIN-01        | equipment                  | summary/actions  |
|   NODE-F1        |                            |                  |
+------------------+----------------------------+------------------+
| PROJECT             ISSUES          CONFIGURE          ISSUE      |
+----------------------------------------------------------------+
```

### 4.2 Phone

Use the same information architecture as a navigation stack:

```text
Project tree/list
  -> object/editor
  -> inspector bottom sheet
  -> issue/configuration detail
```

Do not create separate domain semantics for mobile and tablet/desktop.

## 5. Project tree

Navigation hierarchy MAY be:

```text
Project
  -> Building
     -> Floor
        -> Room/Zone
           -> DistributionNode
              -> equipment
```

The hierarchy is for orientation only. Engineering topology comes from explicit connections.

Required tree behavior:

- expand/collapse;
- status badge aggregation;
- search/filter;
- jump to canvas object;
- multi-select where safe;
- drag/reassign organizational location without silently changing engineering connectivity;
- show `MAIN`/`NODE` role;
- show stale/critical/needs-data state without exposing raw process codes.

## 6. DistributionNode interaction

A distribution node is the central user-facing distribution object.

Normal summary example:

```text
NODE-F2
Floor 2 / Telecom room

State              ATTENTION
Connected devices  26
Cables              28

Network             18 / 24 ports
PoE                 286 / 370 W
Uplink               1.42 Gbit/s
Power                612 W
Backup               31 / 45 min
Physical capacity    estimated 21U / available 18U
```

The summary MUST be projection-based. The UI SHALL NOT recompute engineering truth independently.

## 7. Create/add interaction

Contextual `+ Add` SHALL use engineer vocabulary:

```text
Equipment
Distribution node
Cable / connection
Power source
Route
Room / zone
```

The UI SHALL NOT offer process-code creation such as `CCTV-03` or `LAN-05`.

Creating a node requires only minimal fields:

```text
name
role = MAIN | NODE
organizational location
optional descriptive kind
```

Physical enclosure, exact SKU and normative profile-specific details MAY be resolved progressively later.

## 8. Connection workflow

The preferred interaction is endpoint-to-endpoint connection.

Example:

```text
Camera-201
  -> Connect
  -> NODE-F2
```

Electra MAY propose a connection intent from device capabilities:

```text
Medium: Ethernet
Power: PoE
Discipline: CCTV
```

The proposal is editable before Apply.

### 8.1 Batch connection

Professional workflows SHALL support multi-select:

```text
select Camera-201...Camera-212
  -> Connect to NODE-F2
  -> preview 12 connections
  -> Apply
```

Batch operations MUST preserve deterministic identity, undo/redo and partial-failure reporting.

## 9. Automatic engineering execution

After a design mutation, Electra SHALL determine applicable recalculation from dependency facts.

```text
edit
 -> persist project mutation
 -> mark affected dependency closure stale
 -> resolve immutable calculation inputs
 -> execute applicable kernels
 -> guarded publish
 -> rebuild user-facing projections
```

The normal user SHALL NOT press a separate Calculate button after every mutation.

A manual `Recalculate`/`Refresh engineering state` MAY exist for recovery/diagnostics, but automatic incremental recalculation is canonical.

## 10. User-facing state model

Canonical simplified states:

```dart
enum WorkspaceObjectState {
  ready,
  attention,
  critical,
  stale,
  needsData,
}
```

Engineering states remain richer internally.

Projection priority SHALL be deterministic. Recommended severity ordering for user display:

```text
CRITICAL > NEEDS_DATA > STALE > ATTENTION > READY
```

A `NEEDS_DATA` result SHALL NOT be presented as PASS.

## 11. Progressive disclosure

Every engineering finding SHALL support three levels.

### Level 1 — User

```text
NODE-F2 needs 4 additional PoE-capable ports.
```

### Level 2 — Engineering summary

```text
Required: 28
Available: 24
Reserve policy: 25%
Affected node: NODE-F2
```

### Level 3 — Evidence

```text
process/evaluation IDs
algorithm/schema/rule versions
input fingerprint
observed facts
margin/governing case
provenance
finding codes
```

The simple surface MUST NOT discard Level 3 evidence.

## 12. Issues workspace

An issue is a user projection over engineering findings, not a second source of truth.

Required grouping:

```text
Blocking / critical
Requires attention
Missing data
Stale
```

Each issue SHALL contain:

```text
issueId
projectRevision
subjectRef
userTitle
userExplanation
state/severity
requiredValue? / availableValue?
actionRefs[]
engineeringEvidenceRefs[]
```

Every actionable issue SHOULD offer the next safe action, for example:

```text
Open node
Enter missing data
Show alternatives
Evaluate automatic fix
```

No issue remediation may mutate the design until an explicit Apply command.

## 13. Configuration workspace

Configuration proposals SHALL use a two-phase interaction:

```text
EVALUATE -> PROPOSAL -> USER REVIEW -> APPLY
```

Proposal card example:

```text
Replace current switch with 48-port PoE class

Why
- satisfies 28 required ports
- preserves 25% reserve
- satisfies PoE budget
- passes normative candidate checks
- fits selected enclosure

Alternatives: 2
Commercial data age: 3h

[Apply] [Alternatives] [Engineering details]
```

`Apply` is a project mutation and MUST participate in command history/undo where technically safe.

## 14. Physical-capacity remediation

If ELV6 determines that a logical node cannot fit into the current enclosure, the UX SHOULD present actionable options without splitting the logical topology automatically.

Example:

```text
NODE-F2 requires about 21U; current enclosure provides 18U.

Options
1. use 24U enclosure
2. realize NODE-F2 as Cabinet A + Cabinet B
3. choose a more compact accepted configuration
```

A logical `DistributionNode` remains stable while `PhysicalNodeRealization` may use 1..N enclosures.

## 15. MAIN aggregation

Opening a MAIN node SHALL provide a deterministic project/branch summary where aggregation is valid:

```text
child nodes
connected/design power
critical/backup load
UPS-backed load
generator-backed load
uplinks
network/fiber demand
unresolved dependencies
status aggregation
```

Aggregation MUST preserve origin identity and prevent double counting.

## 16. External-source workflow

Adding sources SHALL use the same interaction model:

```text
+ Power source
  -> Grid / Generator / UPS / Battery / PV / Inverter / ESS
  -> place
  -> connect endpoints
```

The user does not select a special calculation module. Operating cases and affected engineering calculations derive from the resulting graph.

## 17. Project maturity

Expose project maturity separately from pass/fail state.

Recommended maturity:

```dart
enum ProjectMaturity {
  concept,
  engineering,
  configuration,
  readyToIssue,
  frozen,
}
```

A concept-stage project may legitimately contain unknown catalog/physical facts without being labelled globally failed. Mandatory unknowns still block the specific downstream action that requires them.

## 18. Freeze / Issue workflow

The `ISSUE` workspace SHALL present a readiness gate:

```text
Topology              READY
Engineering           READY
Physical layout       READY
Normative checks      READY
Equipment resolution  READY
Blocking issues       0
Missing mandatory     0
Stale accepted state  0
```

Only then may the user execute an explicit freeze/issue command according to project policy.

Frozen revision output MAY include:

- BOM;
- cable schedule;
- equipment schedule;
- panel/node schedule;
- rack/enclosure layout;
- calculation report;
- normative report;
- issue/deviation list;
- topology/single-line diagrams;
- project summary.

Live catalog/rule changes MUST NOT silently rewrite frozen output.

## 19. Canonical application commands

The UI SHOULD dispatch application commands rather than mutate repositories directly.

Conceptual commands:

```dart
sealed class WorkspaceCommand {}

final class CreateDistributionNode extends WorkspaceCommand {}
final class MoveObjectInNavigationTree extends WorkspaceCommand {}
final class PlaceEquipment extends WorkspaceCommand {}
final class CreateConnection extends WorkspaceCommand {}
final class CreateConnectionsBatch extends WorkspaceCommand {}
final class RemoveConnection extends WorkspaceCommand {}
final class AddPowerSource extends WorkspaceCommand {}
final class ApplyConfigurationProposal extends WorkspaceCommand {}
final class RecordEngineeringDecision extends WorkspaceCommand {}
final class FreezeProjectRevision extends WorkspaceCommand {}
```

Existing authoritative ELV command boundaries remain authoritative. Workspace commands are product/application intents and MUST delegate to existing domain command handlers instead of duplicating engineering mutation semantics.

## 20. ViewModel contracts

Widgets SHALL consume read models/projections, not query engineering repositories ad hoc.

```dart
final class ProjectWorkspaceVm {
  final String projectId;
  final String projectName;
  final String revisionLabel;
  final ProjectMaturity maturity;
  final WorkspaceObjectState state;
  final List<ProjectTreeNodeVm> tree;
  final WorkspaceSelectionVm? selection;
  final ProjectIssueSummaryVm issues;
  final ProjectConfigurationSummaryVm configuration;
  final IssueReadinessVm issueReadiness;
}
```

```dart
final class DistributionNodeVm {
  final String nodeId;
  final String name;
  final DistributionNodeRole role;
  final WorkspaceObjectState state;
  final int connectedDeviceCount;
  final int cableCount;
  final List<EngineeringMetricVm> metrics;
  final List<ActionableIssueVm> issues;
  final List<ContextActionVm> actions;
}
```

```dart
final class ActionableIssueVm {
  final String issueId;
  final String subjectId;
  final String title;
  final String explanation;
  final WorkspaceObjectState state;
  final List<ContextActionVm> actions;
  final EngineeringDrillDownRef drillDown;
}
```

ViewModels SHALL contain already localized/display-ready summaries where appropriate, while exact typed quantities remain available for formatting and drill-down.

## 21. State management boundary

Recommended flow:

```text
Widget
 -> WorkspaceController / feature controller
 -> application command/query port
 -> domain/application services
 -> repositories + engineering kernels
 -> projection/read model
 -> WorkspaceController state
 -> Widget
```

Forbidden:

```text
Widget -> Drift table
Widget -> ELV kernel directly
Widget computes PASS/FAIL
Widget merges ELV5/6/7/8 truth itself
```

## 22. Mapping to current Flutter feature structure

Adopt incrementally; do not rewrite the application at once.

```text
features/projects
  owns project entry/list/create and opens ProjectWorkspace

features/floors
features/rooms
  remain structure/editor projections used inside workspace

features/editor
  remains canvas and object interaction foundation
  add workspace shell, selection inspector and contextual actions

features/calculations
  reposition as advanced engineering drill-down and diagnostics
  process codes/evidence remain available here

features/reports
  evolve toward ISSUE/deliverables workspace after freeze
```

Existing component catalog, electrical loads/circuits, placement preview, junction editor and power workspace SHOULD be integrated as focused inspectors/tools rather than duplicated.

## 23. Performance and offline behavior

The workspace SHALL remain responsive for professional-size projects.

- projection queries must be bounded/batched;
- tree/canvas lists must be virtualized where large;
- long engineering calculations execute off the UI isolate where required;
- stale state should appear immediately after mutation while recalculation continues synchronously/asynchronously within the application execution model;
- offline project editing remains possible against local authoritative state;
- commercial/catalog freshness is displayed independently from engineering validity;
- worker completion order MUST NOT affect engineering result ordering/fingerprints.

## 24. Acceptance scenarios

Minimum product acceptance scenarios:

1. create project, floors/rooms, MAIN and NODE without opening Calculations;
2. batch-connect 12 cameras to NODE and automatically obtain CCTV/LAN/PoE affected state;
3. add ACS devices and see only affected node/upstream dependency closure refresh;
4. add generator/UPS source and obtain operating-case dependent engineering state without special module selection;
5. show a node issue in user wording and drill through to exact process evidence;
6. evaluate a switch upgrade, see alternatives and apply only after explicit confirmation;
7. detect 18U enclosure vs 21U requirement and propose 24U / multi-cabinet / compact configuration alternatives;
8. disconnect/reconnect one endpoint and verify unaffected nodes remain current;
9. close/reopen app and reproduce workspace state from persisted projections/evidence;
10. freeze a ready revision and generate stable deliverables;
11. change live catalog/rule data after freeze and prove frozen output remains unchanged;
12. complete the normal project flow without exposing ELV process codes unless the user enters engineering detail.

## 25. Product success criterion

A competent engineer unfamiliar with Electra SHALL be able to understand the primary workflow from the object model alone:

> place the real objects -> connect them -> inspect what Electra found -> resolve issues -> approve the configuration -> issue the project.

The system may be complex internally, but no internal complexity may leak into the primary workflow unless it materially improves an engineering decision.
