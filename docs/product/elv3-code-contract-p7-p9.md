# Electra — ELV3 Code-Level Implementation Contract P7–P9

Status: AUTHORITATIVE CODE DESIGN / P7–P9  
Branch: `feat/flutter-elv3-physical-routing-design`  
Parent authority: `docs/product/elv3-dual-review-process-hardening.md`

## 1. Purpose

Freeze the implementation shape for the engineer workspace, vertical restart/failure acceptance and final exact-SHA closure.

---

# P7 — Engineer Physical Routing workspace

## 2. Exact source-file plan

Application state/controller layer:

```text
apps/mobile/lib/application/elv_physical_routing_workspace_service.dart
apps/mobile/lib/application/elv_physical_routing_workspace_state.dart
apps/mobile/lib/application/elv_physical_trace_service.dart
```

Presentation layer follows the project's existing feature/widget structure. Exact widget filenames may vary, but the UI must expose one shared workspace and must not create per-discipline route editors.

Tests:

```text
apps/mobile/test/application/elv_physical_routing_workspace_service_test.dart
apps/mobile/test/presentation/elv_physical_routing_workspace_test.dart
apps/mobile/test/presentation/elv_physical_routing_undo_redo_test.dart
```

## 3. Workspace state contract

```dart
enum PhysicalRoutingStage {
  logicalConnection,
  cable,
  allocation,
  termination,
  route,
  carrier,
  findings,
}

final class PhysicalRoutingWorkspaceState {
  final String projectId;
  final PhysicalDesignContext designContext;
  final String? selectedConnectionId;
  final String? selectedCableId;
  final String? selectedAllocationId;
  final String? selectedCableRunId;
  final PhysicalRoutingStage activeStage;
  final bool canEdit;
  final List<PhysicalRoutingBlockingIssue> blockingIssues;
}
```

`canEdit` derives only from current `PhysicalDesignContext` + command permissions. Widgets do not infer writeability themselves.

## 4. Workspace service contract

```dart
abstract interface class ElvPhysicalRoutingWorkspaceService {
  Future<PhysicalRoutingWorkspaceState> load({
    required String projectId,
    String? connectionId,
  });

  Stream<PhysicalRoutingWorkspaceState> watch(String projectId);

  Future<CommandResult> execute(ElvWorkspaceCommand command);
  Future<TraceResult> traceConnection(String projectId, String connectionId);
  Future<TraceResult> traceCable(String projectId, String cableId);
}
```

The service coordinates repositories; it does not implement domain rules that belong in engineering_core.

## 5. Progressive flow

Exact UI progression:

```text
1 Connection
2 Cable
3 Allocation/resources
4 Terminations
5 Run/traversal
6 Carrier/pathway
7 Findings/calculations
```

Blocking progression examples:

```text
no Cable -> allocation stage read-only
DRAFT allocation -> termination may be prepared but activation unavailable
no ACTIVE allocation -> route may be drafted only if product UX explicitly allows, but commit CreateCableRun requires valid Cable identity + current WORKING revision
FROZEN/no WORKING -> all mutation controls disabled
```

UI always displays exact design revision context.

## 6. Trace result

```dart
final class PhysicalTraceResult {
  final String projectId;
  final String designRevisionId;
  final EngineeringPortConnection connection;
  final Cable? cable;
  final CableAllocation? allocation;
  final CableAllocationResourceSelectionEvidence? resourceSelection;
  final List<CableTerminationMapping> terminations;
  final CanonicalCableRun? run;
  final List<CableRunTraversal> traversals;
  final List<PhysicalCarrier> carriers;
  final List<PathwayContext> pathwayContexts;
  final List<PhysicalCompatibilityFinding> findings;
  final List<ElvPhysicalCalculationResult<Object?>> calculations;
}
```

Trace from frozen revision resolves snapshot/source evidence for that revision. Trace from WORKING resolves current canonical state.

## 7. Undo/redo service

```dart
enum ElvCommandUndoClass { reversible, irreversibleHistory }

abstract interface class ElvCommandHistoryService {
  Future<bool> canUndo(String projectId);
  Future<bool> canRedo(String projectId);
  Future<CommandResult> undo(String projectId);
  Future<CommandResult> redo(String projectId);
}
```

Reversible entries persist enough prior state to replay inverse logical command, plus precondition fingerprint.

Examples reversible:

```text
RerouteCableRun
ReplaceCableTerminationSet
AttachTraversalToCarrier
DetachTraversalFromCarrier
EditReusableRouteGeometry (only if shared impact set still matches)
```

Irreversible history:

```text
FreezeProjectDesignRevision
CreateNextWorkingDesignRevision
SupersedeProjectDesignRevision
ArchiveProjectDesignRevision
AdoptLegacyElectricalRoute
ReleaseCableResources
historical archive operations
```

UI must not show enabled Undo for irreversible entry.

---

# P8 — Restart / rollback / failure injection / idempotency verticals

## 8. Test infrastructure plan

Create reusable fixture builders:

```text
apps/mobile/test/support/elv_test_catalog.dart
apps/mobile/test/support/elv_test_project.dart
apps/mobile/test/support/elv_test_topology.dart
apps/mobile/test/support/elv_test_routing.dart
apps/mobile/test/support/elv_failure_injector.dart
apps/mobile/test/support/elv_database_reopen.dart
```

Vertical tests:

```text
apps/mobile/test/vertical/elv_cctv_vertical_test.dart
apps/mobile/test/vertical/elv_lan_vertical_test.dart
apps/mobile/test/vertical/elv_acs_vertical_test.dart
apps/mobile/test/vertical/elv_fire_vertical_test.dart
apps/mobile/test/vertical/elv_fiber_vertical_test.dart
apps/mobile/test/vertical/elv_failure_injection_test.dart
apps/mobile/test/vertical/elv_idempotency_restart_test.dart
apps/mobile/test/vertical/elv_frozen_revision_reconstruction_test.dart
```

## 9. Deterministic fixture IDs

Tests MUST use `FixedSequenceIdGenerator`; no UUID randomness in expected vertical fixtures.

Canonical fixture identity prefixes:

```text
PRJ-
REV-
SYS-
CMP-
PORT-
CONN-
CAT-
CABLE-
ALLOC-
RUN-
TRV-
ROUTE-
NODE-
SEG-
HANDOFF-
CARRIER-
CTX-
```

Fixtures compare domain values/ids, never database auto-generated ordering.

## 10. Five vertical fixtures

### CCTV

```text
camera ETH/PoE port
 -> EngineeringConnection
 -> Cat6 Cable WHOLE_CABLE allocation
 -> A/B termination
 -> CanonicalCableRun
 -> >=3 traversals across wall/corridor/telecom area
 -> at least one carrier assignment
```

Assertions:

```text
one Cable
one consuming allocation
one active run/current revision
installed length deterministic
restart exact ids/hash
no ELV4 PoE budget performed
```

### LAN

```text
outlet REAR -> patch panel REAR
whole Cat6 permanent-link Cable
InternalConnectivity remains separate/non-cable
```

### ACS

One 8-core Cable:

```text
Reader       1,2
Door contact 3,4
REX          5,6
Lock         7,8
```

Assertions:

```text
4 connections
4 allocations
8 unique conductor atoms
1 physical Cable
carrier occupancy counts 1 Cable
```

### Fire

ELV1 loop identity remains logical topology. Physical device-to-device sections use separate Cable identities only where explicit endpoints/connections exist. No ELV3 normative compliance result.

### Fiber

12-fiber Cable, two duplex allocations:

```text
A -> fibers 1,2
B -> fibers 3,4
```

Attempt overlapping fiber 2 must fail.

## 11. Failure injection interface

Production repositories should not depend on test-only globals. Use an optional injected boundary:

```dart
abstract interface class ElvFailureProbe {
  Future<void> hit(String point);
}

final class NoopElvFailureProbe implements ElvFailureProbe { ... }
```

Concrete repository accepts `ElvFailureProbe` with default no-op. Test probe throws deterministic exception at configured point.

Stable failure-point codes:

```text
P1_CREATE_CABLE_AFTER_INSERT
P2_RESERVE_AFTER_FIRST_CLAIM
P2_REPLACE_TERMINATION_AFTER_DELETE
P2_ACTIVATE_BEFORE_STATE_UPDATE
P3_FREEZE_AFTER_SNAPSHOT_INSERT
P3_CREATE_NEXT_AFTER_REVISION_INSERT
P3_REROUTE_AFTER_DELETE_OLD_CHAIN
P4_ATTACH_CARRIER_AFTER_TRAVERSAL_UPDATE
P3_ADOPT_AFTER_CABLE_CREATE
```

Never key tests to line numbers/private implementation details.

## 12. Failure test protocol

Every failure test executes:

```text
1 open DB
2 establish known canonical state
3 arm one failure point
4 execute command
5 assert command failed
6 inspect same open DB post-rollback
7 close DB
8 reopen DB
9 assert exact same canonical state
10 assert no CommandExecutionRecord claims success
```

## 13. Idempotency restart protocol

For each replayable command:

```text
execute command -> success
persist response identity
simulate caller losing response
close DB
reopen DB
execute exact same commandId/payload
assert same logical result
assert no duplicate canonical rows
```

Then reuse same commandId with one payload field changed -> `ELV_IDEMPOTENCY_CONFLICT`.

## 14. Frozen revision reconstruction protocol

```text
build WORKING state
freeze -> snapshot
record snapshot hash and reconstructed trace
create next WORKING
mutate route/carrier/allocation current state
read old FROZEN revision
assert old trace exactly matches snapshot baseline
assert old hash unchanged
```

Old snapshot must never consult current rows for missing fields. Schema-evolution absence is returned explicitly as not captured.

---

# P9 — Architecture-vs-code hard audit and final exact-SHA closure

## 15. Required code inventory

P9 must generate a machine/human-readable inventory listing:

```text
engineering_core ELV source files
application command/service/repository ports
Drift repositories
ELV Drift tables + indexes
migrations/schema versions per P1-P5
widget/workspace entry points
all ELV tests
all process codes
all stable error codes
all command failure points
```

Store under:

```text
docs/audit/elv3-implementation-inventory.md
```

## 16. Command contract audit

Create:

```text
docs/audit/elv3-command-contract-matrix.md
```

One row per P1-P8 command with:

```text
command name
input identity
expected revision fields
required lifecycle state
read set
validation set
write set
state transition
affected dependency keys
idempotency class
rollback postcondition
undo class
restart assertion
stable error codes
implementation file/test file
```

P9 fails if a public mutation command is missing from matrix.

## 17. Schema contract audit

P9 compares actual Drift schema against authoritative names/relations.

Hard failures include:

```text
missing project FK
Cable linked to room/circuit as owner
allocation selection evidence overwritten on release
claims retained after RELEASED
canonical CableRun using legacy circuitId
new second route geometry graph
RouteHandoff with run ownership
FROZEN snapshot missing embedded mutable facts
P5 latest-profile lookup
calculation key without designRevisionId
```

## 18. Runtime architecture assertions

Add targeted tests that fail on forbidden shortcuts:

```text
Connection cannot serialize as Cable
one connection second consuming Cable rejected
one Cable can serve ACS resource partitions
frozen revision is immutable/read-only
route geometry change fans out all dependent runs
carrier change fans out all dependent runs
bend radius never inferred from angle
occupancy deduplicates by Cable id
ELV3 findings contain no jurisdiction-compliance claim
legacy electrical route opens without canonical Cable migration
```

## 19. Exact-SHA evidence

P9 records:

```text
final branch SHA
commit date
workflow run identifiers/links if available
mobile format/analyze/test status
engineering_core format/analyze/test status
Drift generation status
generated-artifact guard status
five vertical fixtures status
failure injection status
idempotency/restart status
legacy electrical regression status
architecture audit status
```

No commit is allowed after this evidence without rerunning gate.

## 20. Final code-level Definition of Done

ELV3 code implementation is closed only if:

1. all authoritative code-level files/classes/tables exist or an explicitly audited equivalent exists;
2. every command uses application/service/repository transaction boundaries, never widget multi-table writes;
3. exact reference hashes reconstruct after restart;
4. resource claims cannot double-commit;
5. selection/termination history survives release;
6. design revision fork/freeze semantics are deterministic;
7. shared route/carrier edits have fan-out impact guards;
8. frozen snapshots remain reproducible after later edits;
9. P5/P6 results are revision-scoped and deterministic;
10. all five verticals pass restart;
11. all mandatory failure probes roll back exactly;
12. idempotent retry works across reopen;
13. P9 audit has zero open BLOCKER/HIGH implementation deviations;
14. exact final SHA is green.