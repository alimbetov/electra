# Electra — ELV3 P0.7 Cross-Discipline Walkthrough

Status: REMEDIATED DESIGN VALIDATION / P0-R10 INPUT  
Branch: `feat/flutter-elv3-physical-routing-design`  
Authoritative parent: `docs/product/elv3-p0-system-architecture-remediation.md`  
Implementation status: HOLD UNTIL FINAL AUDIT

## 1. Purpose

Validate the remediated ELV3 architecture against materially different physical-installation scenarios before persistence implementation.

Mandatory fixtures:

1. CCTV;
2. LAN / structured cabling;
3. access control (ACS);
4. fire alarm;
5. fiber backbone genericity.

Pass condition: all scenarios use the same common physical model without discipline-specific Cable/CableRun/Route persistence.

## 2. Canonical model under test

```text
EngineeringConnection
  -> CableAllocation
  -> Cable
  -> one active CableRun per design revision
  -> ordered CableTraversal[]
  -> reusable Route / geometry
  -> optional PhysicalCarrier
  -> PathwayContext
```

Resource realization:

```text
CableAllocation
  -> CableResourceSelection
  -> CableTerminationMapping[]
```

Reference identity:

```text
ELV2 ReferenceSnapshot/project binding
  -> exact CableDefinition/Profile edition
```

## 3. CCTV

### Scenario

```text
Camera ETH/PoE port
  -> EngineeringConnection
  -> CableAllocation WHOLE_CABLE
  -> Cable CCTV-C-001
  -> CableRun CR-001
      -> room wall traversal
      -> corridor tray traversal
      -> telecom-room conduit traversal
  -> PoE switch port
```

### Expected architecture

- one physical Cable;
- one active CableRun for the cable/revision;
- several spatial traversals, not several CableRuns;
- shared corridor tray is reusable route/carrier infrastructure;
- PoE budget remains ELV4/ELV5;
- ELV3 may validate physical geometry/carrier facts only.

### Verdict

PASS.

## 4. LAN permanent link

### Scenario

```text
Outlet.REAR
  -> EngineeringConnection
  -> WHOLE_CABLE allocation
  -> Cable LAN-C-001
  -> CableRun
  -> shared tray/conduit traversals
  -> PatchPanel.REAR

PatchPanel.REAR
  <-> InternalConnectivity
PatchPanel.FRONT
```

### Expected architecture

- permanent-link cable remains one Cable;
- rear/front patch-panel mapping does not create a Cable;
- patch cord, if modeled, is a separate physical connection/cable scope;
- LAN length/performance limits belong to later calculation/normative profiles;
- shared tray geometry is not duplicated per cable as canonical infrastructure.

### Verdict

PASS.

## 5. LAN/fiber backbone

### Scenario

```text
Cable F-001 / 12 fibers

Connection A -> allocation fibers 1,2
Connection B -> allocation fibers 3,4
```

Both logical links share one physical Cable and one CableRun path.

Termination mappings identify the exact fiber termination endpoints where modeled.

Expected failure:

```text
Connection C -> fibers 2,5
```

must fail with resource overlap because fiber 2 is already consumed.

### Verdict

PASS.

## 6. Access control multi-core cable

### Scenario

```text
Cable ACS-C-001 / 8 conductors

Reader        -> conductors 1,2
Door contact  -> conductors 3,4
REX           -> conductors 5,6
Lock          -> conductors 7,8
```

All allocations reference the same physical Cable.

```text
Cable ACS-C-001
  -> one CableRun
      -> several route traversals
```

### Critical invariants

- four allocations do not create four CableRuns;
- carrier occupancy counts one physical Cable;
- resource overlap is prohibited transactionally;
- conductor termination mapping may bind each conductor to exact terminals/ports;
- lock power calculation remains ELV4/ELV5.

### Verdict

PASS.

## 7. Fire alarm loop

### Logical topology

```text
FACP.L1-OUT
 -> DET-01
 -> DET-02
 -> MCP-01
 -> ISO-01
 -> FACP.L1-IN
```

Loop identity belongs to `TopologyGroup` / ELV1 semantics.

### Physical realization

A common installation may use separate cable sections between successive devices. Each physical section is its own `Cable` because there are explicit device terminations between sections.

Example:

```text
Connection FACP -> DET-01
  -> Cable FA-C-001

Connection DET-01 -> DET-02
  -> Cable FA-C-002

Connection DET-02 -> MCP-01
  -> Cable FA-C-003
```

Each Cable owns at most one active CableRun in the revision.

This is preferable to pretending one continuous cable passes through device terminations unless the actual installation definition proves that construction.

### Carrier/normative behavior

ELV3 can persist route/carrier/pathway facts and technical physical findings.

Formal claims such as mandatory fire separation or jurisdiction compliance require ELV7 versioned rule packs.

### Verdict

PASS.

## 8. Explicit multi-cable transition scenario

A single EngineeringConnection may use more than one physical cable only with a modeled physical transition.

Example:

```text
Port A
 -> Connection C1
 -> Cable A
 -> explicit splice/termination S1
 -> Cable B
 -> Port B
```

Without `S1`, two allocations with sequence numbers are insufficient and must be rejected as incomplete realization.

### Verdict

PASS WITH EXPLICIT TRANSITION REQUIREMENT.

## 9. Shared shaft/riser scenario

```text
PathwayContext SHAFT S-01
  -> tray T-01
  -> conduit C-01

Cable A CableRun traversal -> T-01
Cable B CableRun traversal -> T-01
Cable C CableRun traversal -> C-01
```

Shaft is spatial context; tray/conduit are carriers. No fake room ownership and no per-floor CableRun split.

### Verdict

PASS.

## 10. Electrical coexistence scenario

Legacy electrical route:

```text
CableRun.circuitId = EC-01
```

remains legacy routing evidence.

No canonical Cable is created until explicit adoption proves physical cable identity.

Canonical ELV cable routing coexists without fake electrical circuits.

### Verdict

PASS.

## 11. Cross-stage boundary validation

### ELV3 owns

- Cable physical identity;
- resource allocation/termination;
- CableRun/path traversal;
- carrier/pathway factual data;
- physical length/fill/bend/continuity basis;
- technical physical compatibility evidence.

### ELV4/ELV5 own

- PoE/power conversion;
- voltage drop;
- optical loss;
- LAN channel performance;
- CCTV bandwidth/storage;
- ACS power/autonomy;
- fire current/autonomy and discipline calculations.

### ELV7 owns

- jurisdiction-specific thresholds;
- formal normative/legal compliance;
- standards rule packs and exceptions.

### ELV8 owns

- manufacturer selection;
- BOM/schedules/deliverables consuming frozen engineering truth.

Boundary verdict: PASS.

## 12. Required invalid fixtures

The regression suite must eventually prove rejection or explicit unresolved state for:

```text
resource overlap
WHOLE_CABLE + partial allocation
multi-cable connection without transition
CableRun split only because room/floor changed
carrier in fake room for shaft/riser
legacy circuit auto-converted to invented Cable
ELV3 claiming jurisdiction compliance without ELV7 profile
cross-project references
stale design-revision update
```

## 13. P0.7 remediation acceptance

- [x] CCTV PASS.
- [x] LAN permanent link PASS.
- [x] fiber resource sharing PASS.
- [x] ACS multicore PASS.
- [x] Fire loop/section semantics PASS.
- [x] explicit multi-cable transition requirement PASS.
- [x] shaft/carrier layering PASS.
- [x] electrical coexistence PASS.
- [x] ELV3/4/5/7/8 boundary PASS.

P0.7 is synchronized with the remediation architecture and is ready as an input to P0-R10.