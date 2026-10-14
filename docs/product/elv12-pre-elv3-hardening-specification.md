# Electra — ELV1/ELV2 Pre-ELV3 Hardening Specification

Status: READY FOR IMPLEMENTATION  
Baseline: `main@f05b1e558a93b40928429ca86d91f4daa0cf4ef0`  
Branch: `feat/flutter-elv12-pre-elv3-hardening`  
Scope: small post-merge hardening only; **no ELV3 domain implementation in this branch**

## 1. Purpose

ELV1 and ELV2 are accepted and merged. The post-merge audit found no open domain blocker in the connectivity, profile, placement, revision-preview or adoption models. Before opening ELV3, this branch closes a small set of repository/documentation/governance issues that would otherwise reduce traceability or CI quality.

The objective is not to reopen ELV1/ELV2. The objective is to create a clean, explicit baseline from which ELV3 can start.

## 2. Non-goals

This hardening branch MUST NOT introduce:

- `CableDefinition`, `Cable`, or `CableAllocation`;
- ELV connection-to-cable allocation;
- new ELV physical-channel ownership semantics;
- route compatibility calculations;
- tray/conduit fill calculations;
- segregation or bend-radius rules;
- PoE/PSU/UPS/battery calculations;
- discipline-specific ELV calculations;
- a replacement for the existing ELV1/ELV2 domain model.

The existing `CableRun.circuitId` electrical-routing assumption is intentionally left for **ELV3-P0 design**. It MUST NOT be patched ad hoc in this branch.

## 3. Accepted baseline

The branch starts from the merged ELV1/ELV2 baseline:

```text
main
└── f05b1e558a93b40928429ca86d91f4daa0cf4ef0
    └── Merge PR #7 — ELV2 profile constraints and Round-2 remediation
```

The post-merge `Flutter Local Foundation` workflow on this merge commit must remain the reference baseline for regression comparison.

ELV1 and ELV2 domain status at branch start:

```text
ELV1  Ports / Connections / Topology                  ACCEPTED
ELV2  Profiles / Constraints / Placement / Adoption   ACCEPTED
```

No implementation in this branch may weaken the accepted ELV1/ELV2 invariants.

---

# H1 — Synchronize ELV roadmap and specification metadata

## 4. Problem

Several product documents still describe an earlier development state even though ELV2 is merged.

Examples include:

```text
Status: ELV1 baseline merged; ELV2 ... in progress
Implementation branch: feat/flutter-elv2-reference-catalogs
```

and foundational documents that still identify the old design branch or draft status even though their architecture is now implemented and relied upon by `main`.

This does not affect runtime correctness, but it makes the documentation cease to be a reliable source of project state.

## 5. Required changes

At minimum review and synchronize:

- `docs/product/elv-delivery-plan.md`;
- `docs/product/elv-canonical-discipline-model.md`;
- other ELV overview documents only where their status/branch metadata is demonstrably stale.

The updated roadmap header MUST identify:

```text
ELV1  CLOSED
ELV2  CLOSED
ELV3  READY FOR DESIGN / ANALYSIS
Accepted baseline: main@f05b1e558a93b40928429ca86d91f4daa0cf4ef0
```

Historical implementation SHAs MAY remain inside closure/audit documents. Historical audit evidence MUST NOT be rewritten as if it occurred on the new hardening branch.

## 6. Acceptance criteria H1

- no active roadmap text says ELV2 is still in progress;
- no active roadmap identifies an obsolete ELV2 implementation branch as current;
- ELV1 and ELV2 are marked accepted/closed;
- ELV3 is identified as the next design stage, not as already implemented;
- existing P1–P7 and Round-2 audit evidence remains unchanged except for explicit metadata corrections where necessary.

---

# H2 — Repository governance for the accepted baseline

## 7. Problem

The post-merge audit found that `main` is not protected and no required status checks are enforced by branch protection.

The engineering process already relies on exact-SHA CI gates, but repository settings currently do not enforce that discipline.

## 8. Required governance policy

Before ELV3 implementation begins, repository governance SHOULD enforce the following for `main` where the repository/account permissions allow it:

```text
Pull request required before merge
        ↓
Flutter Local Foundation required
        ↓
branch must be up to date / exact reviewed head
        ↓
no force-push to main
        ↓
no branch deletion of main
```

Recommended minimum controls:

1. require pull request before merging;
2. require the `Flutter Local Foundation` status check;
3. require conversation resolution when code review comments exist;
4. block force pushes to `main`;
5. block deletion of `main`;
6. preserve admin bypass only if consciously required for repository recovery.

If the connected GitHub integration cannot modify repository administration settings, implementation evidence for H2 is a documented manual repository-setting checklist with a verified final state.

## 9. Exact-SHA rule

The existing engineering rule remains normative:

```text
final branch SHA
   -> required CI GREEN
   -> PR review/approval
   -> merge
   -> post-merge main CI GREEN
```

No documentation-only commit may be added after the final branch gate without rerunning the final gate on the new SHA.

## 10. Acceptance criteria H2

Either:

- `main` protection/ruleset is verified to enforce the agreed controls;

or, if administration cannot be changed through the current integration:

- a repository-admin action checklist is committed;
- the missing setting is explicitly classified as external governance work, not silently ignored;
- ELV3 may start only after the repository owner confirms the protection state.

---

# H3 — Remove Drift relationship-generation warnings

## 11. Problem

The accepted build is GREEN but Drift generation emits repeated warnings similar to:

```text
Duplicate orderings/filters detected for field
"engineeringTopologyGroupsRefs"
on "$EngineeringPortInstancesTable"

Duplicate orderings/filters detected for field
"engineeringPortConnectionsRefs"
on "$EngineeringPortInstancesTable"

Duplicate orderings/filters detected for field
"engineeringInternalMappingsRefs"
on "$EngineeringPortInstancesTable"
```

The warnings arise because multiple foreign-key columns in the same table point to `EngineeringPortInstances` without distinct `@ReferenceName` annotations.

Current examples:

```text
EngineeringTopologyGroups.startPortId -> EngineeringPortInstances.id
EngineeringTopologyGroups.endPortId   -> EngineeringPortInstances.id

EngineeringPortConnections.fromPortId -> EngineeringPortInstances.id
EngineeringPortConnections.toPortId   -> EngineeringPortInstances.id

EngineeringInternalMappings.fromPortId -> EngineeringPortInstances.id
EngineeringInternalMappings.toPortId   -> EngineeringPortInstances.id
```

The schema is valid and tests pass, so this is not a data-integrity defect. It is a generated-API ambiguity and CI-noise issue that should be removed before ELV3 adds more routing relationships.

## 12. Required changes

Add stable explicit `@ReferenceName` values to each ambiguous foreign-key relation.

Recommended semantic naming pattern:

```text
EngineeringTopologyGroups
  startPortId -> topologyGroupsStartingAtPort
  endPortId   -> topologyGroupsEndingAtPort

EngineeringPortConnections
  fromPortId  -> outgoingEngineeringPortConnections
  toPortId    -> incomingEngineeringPortConnections

EngineeringInternalMappings
  fromPortId  -> outgoingEngineeringInternalMappings
  toPortId    -> incomingEngineeringInternalMappings
```

Exact names may be adjusted to existing Drift naming conventions, but they MUST:

- be stable;
- be unique per relationship;
- describe direction/role rather than generic table ownership;
- not change persisted column names;
- not require a database migration solely for generated relation naming.

## 13. Regression requirements H3

After the change:

```text
dart run build_runner build
```

must complete without the six duplicate-reference warnings identified above.

Existing ELV1/ELV2 persistence tests MUST remain green, especially:

- topology persistence/restart;
- atomic placement;
- P5 revision impact;
- P6 adoption;
- four-discipline restart acceptance.

## 14. Acceptance criteria H3

- no duplicate relationship-name warnings for `EngineeringPortInstances`;
- generated Drift code compiles without manual edits;
- no schema-version increment solely because of `@ReferenceName` annotations;
- no change to persisted data semantics;
- full mobile and engineering-core suites remain green.

---

# H4 — Establish the formal ELV3 entry gate

## 15. Purpose

Once H1–H3 are complete, record a single pre-ELV3 accepted baseline.

The final hardening evidence MUST include:

```text
exact hardening SHA
tracked generated-artifact guard PASS
Drift generation PASS with no targeted duplicate-reference warnings
mobile format PASS
mobile analyze PASS
mobile tests PASS
engineering_core format PASS
engineering_core analyze PASS
engineering_core tests PASS
```

A post-merge `main` run MUST also be GREEN before ELV3 implementation begins.

## 16. ELV3 design handoff

The first ELV3 activity after this branch is **ELV3-P0 — physical-routing domain audit and contract**, not implementation-by-refactor.

ELV3-P0 must explicitly decide ownership and cardinality for:

```text
EngineeringConnection
        ↓
CableAllocation
        ↓
Cable
        ↓
CableRun
        ↓
Route
        ↓
PhysicalChannel / Pathway
```

It must also resolve the existing electrical-specific assumption:

```text
CableRun.circuitId
```

without forcing ELV connections to masquerade as electrical circuits.

That decision belongs to ELV3 and is deliberately outside this hardening branch.

---

# 17. Execution order

```text
H1  documentation/status synchronization
 ↓
H2  repository governance verification
 ↓
H3  Drift relation-name cleanup
 ↓
H4  exact-SHA hardening gate
 ↓
merge to main
 ↓
post-merge main GREEN
 ↓
ELV3-P0 design/audit branch
```

H1 and H3 may be implemented in the same pull request. H2 may require a repository-admin action outside the code tree, but its verification result must still be documented before closure.

# 18. Definition of Done

This pre-ELV3 hardening is complete when:

1. ELV1/ELV2 roadmap metadata matches the merged reality;
2. branch-protection expectations are either enforced or explicitly confirmed by repository administration;
3. Drift generation no longer emits the identified duplicate relationship warnings;
4. no ELV1/ELV2 runtime/domain behavior has changed unintentionally;
5. final exact-SHA CI is green;
6. post-merge `main` CI is green;
7. ELV3-P0 can start from a clean, documented, governed baseline.

Final readiness state after closure:

```text
ELV1  CLOSED / ACCEPTED
ELV2  CLOSED / ACCEPTED
PRE-ELV3 HARDENING  CLOSED
ELV3  READY FOR P0 DESIGN
```
