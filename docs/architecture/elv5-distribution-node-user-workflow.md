# ELV5 — Distribution Node Client Workflow

Status: normative product/design contract  
Branch: `feat/flutter-elv5-power-topology-design`

Canonical workspace/runtime binding: [Project Workspace Integration Contract](elv5-project-workspace-integration-contract.md).

## 1. Product intent

ELV5 SHALL support the primary field-engineering workflow in the same terms an electrician/ELV engineer uses on site:

```text
create project
  -> place main or node distribution cabinet
  -> route cables to/from that node
  -> connect loads/endpoints
  -> Electra resolves applicable calculations automatically
  -> show actionable engineering state
  -> publish vendor-neutral EquipmentDemand downstream
```

The user SHALL NOT be required to select CCTV/LAN/ACS/Fire calculation process codes manually for normal work.

Process codes remain engineering/runtime evidence, not the main navigation model.

## 2. Canonical logical node

The common logical entity SHALL be a `DistributionNode`, not a vendor-specific panel class.

```dart
enum DistributionNodeRole {
  main,
  node,
}

enum DistributionNodeKind {
  electricalPanel,
  elvCabinet,
  telecomRack,
  fireCabinet,
  mixed,
}

final class DistributionNode {
  final String id;
  final String projectId;
  final String name;
  final DistributionNodeRole role;
  final DistributionNodeKind kind;
  final String? organizationalParentNodeId;
}
```

`main` and `node` are roles, not separate entity classes. A node may later become the main node for a building/zone without data-model migration.

`kind` is descriptive and SHALL NOT prohibit a technically valid mixed discipline configuration.

## 3. Engineering topology comes from connections

The authoritative engineering topology SHALL be derived from explicit connections/cables, not only from `organizationalParentNodeId`.

`organizationalParentNodeId` MAY support tree navigation in the UI, while actual engineering connectivity SHALL support multiple incoming sources, redundant uplinks, generator/UPS feeds and other non-tree topologies.

Conceptual boundary:

```dart
final class CableConnection {
  final String cableId;
  final ConnectionEndpoint from;
  final ConnectionEndpoint to;
}
```

Examples:

```text
Camera-201 -> Cable-001 -> NODE-F2
MAIN-01 -> Fiber-001 -> NODE-F2
Generator -> ATS -> MAIN-01
UPS -> backup connection -> NODE-F2
```

ELV5 MUST NOT infer a physical connection only because two objects share the same zone or parent node.

## 4. DistributionNode as calculation scope

A distribution node SHALL be a first-class user-facing calculation scope.

The system MAY aggregate applicable engineering dimensions such as:

- connected loads;
- design power/current contribution;
- PoE demand;
- Ethernet/fiber port demand;
- bandwidth/uplink demand;
- recorder/storage contribution;
- ACS controller channel demand;
- fire address/current/notification contribution;
- source/PSU requirements;
- backup/autonomy requirements;
- reserve requirements;
- upstream/downstream dependencies.

Not every dimension applies to every node. Non-applicable dimensions remain explicit and MUST NOT be fabricated as zero-valued engineering facts.

## 5. Automatic process activation

Normal user actions SHALL determine applicable process execution through topology and discipline facts.

Examples:

```text
camera membership -> CCTV processes as applicable
Ethernet/structured cabling -> LAN processes as applicable
ACS door/controller facts -> ACS processes as applicable
fire devices/loops -> Fire processes as applicable
power/source dependency -> accepted ELV4 power evidence
battery/autonomy requirement -> applicable autonomy processes
```

This rule changes UX only. The canonical ELV5 inventory remains exactly 27 processes and the public command family remains unchanged unless separately revised by its authority contract.

## 6. Bottom-up aggregation

Node-level demand SHALL aggregate deterministically from connected subjects and child/linked nodes where the corresponding engineering policy permits aggregation.

Example:

```text
Camera/Access point/Door loads
        -> NODE-F2 discipline results
        -> NODE-F2 EquipmentDemand projection
        -> MAIN-01 upstream contribution
```

Aggregation MUST preserve origin identity and SHALL NOT double-count the same physical load, stream, port claim, battery contribution or reserve.

Shared-source calculations owned by ELV4 SHALL remain shared-source calculations; ELV5 MUST NOT create a reduced discipline-only physical source truth.

## 7. Change propagation

Changes SHALL invalidate only the affected dependency closure.

Example:

```text
add camera to NODE-F2
  -> CCTV bandwidth/PoE/storage dependencies change
  -> node demand projection changes
  -> affected MAIN-01 aggregate changes
  -> relevant ELV6/ELV7/ELV8 downstream snapshots become stale
```

Unrelated nodes SHALL remain valid unless connected through a real shared dependency.

## 8. User-facing state vs engineering state

The normal UI SHALL show a compact product state:

```text
READY
ATTENTION
CRITICAL
STALE
NEEDS_DATA
```

The engineering view MAY expose exact runtime evidence:

```text
PASS
FAIL
WARNING
BLOCKED
UNKNOWN
STALE
NOT_APPLICABLE
```

User-facing wording SHALL be action-oriented. For example:

```text
"NODE-F2 requires 4 more PoE-capable ports"
```

is preferred over exposing only a code such as `INSUFFICIENT_PORT_CAPACITY`.

Stable finding codes remain mandatory internally for tests, persistence and automation.

## 9. EquipmentDemand at node boundary

ELV5 SHALL derive vendor-neutral demand from accepted/current engineering evidence and node topology.

Typical node-scoped demands include:

- switch port/media/throughput/PoE capabilities;
- recorder/VMS capacity;
- patch-panel/termination capacity;
- controller channels/interfaces;
- PSU/source envelope;
- backup/autonomy requirement;
- protection/interface capabilities;
- uplink/media requirement.

`EquipmentDemand` SHALL remain a derived projection, not a 28th ELV5 calculation process and not a second power-topology model.

## 10. Client-oriented acceptance

ELV5 client workflow is acceptable when:

1. a user can create a MAIN or NODE distribution node without choosing an engineering process;
2. explicit cable/connection endpoints determine real engineering connectivity;
3. adding/removing/reconnecting an endpoint recalculates only the correct dependency closure;
4. applicable 27-process calculations are selected automatically from project facts;
5. node-level status is understandable without process-code knowledge;
6. engineering drill-down still exposes process/version/evidence/provenance;
7. node aggregation does not duplicate shared physical loads or reserve;
8. MAIN nodes can aggregate downstream node requirements where policy allows;
9. redundant/multiple source connections are representable without abandoning the user-facing tree;
10. vendor-neutral `EquipmentDemand` can be produced for downstream ELV6/ELV7/ELV8 without SKU, price or brand fields.
