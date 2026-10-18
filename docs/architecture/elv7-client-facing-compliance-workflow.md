# ELV7 — Client-Facing Compliance Workflow

Status: normative product/design contract  
Branch: `feat/flutter-elv7-normative-validation-design`

## 1. Product intent

ELV7 SHALL preserve rigorous normative evidence while presenting compliance in a client-oriented way around real project objects such as `DistributionNode`, circuits, routes, assemblies and selected equipment.

The user SHALL NOT need to understand rule-pack internals to identify what requires action.

Normal workflow:

```text
open MAIN/NODE
  -> see compliance state
  -> see concrete issue
  -> understand affected object
  -> see remediation options
  -> optionally drill into exact rule/evidence/reference
```

## 2. Two-layer presentation

The normal project UI SHALL expose compact states:

```text
READY
ATTENTION
CRITICAL
NEEDS_DATA
STALE
```

The engineering/compliance detail SHALL retain exact ELV7 outcomes:

```text
PASS
FAIL
WARNING
NOT_APPLICABLE
INDETERMINATE
```

The compact state is a presentation projection only. It MUST NOT replace or rewrite normative evidence.

## 3. Node-centric compliance summary

A `DistributionNode` MAY aggregate its dependent ELV7 outcomes for navigation and triage.

Example:

```text
NODE-F2
Compliance: ATTENTION

2 blocking issues
1 engineer decision required
3 warnings

- insufficient verified evidence for selected protection device
- required service clearance not satisfied
- battery documentation requires review
```

Aggregation SHALL preserve links to the exact subject/rule/evidence and SHALL NOT convert an unknown or indeterminate condition into PASS.

## 4. Action-oriented findings

Primary wording SHOULD explain the action or engineering consequence.

Preferred:

```text
"The selected device does not have verified evidence for the required breaking capacity."
```

rather than only:

```text
RULE-KZ-XXXX FAIL
```

Every user-facing finding SHALL still retain internally:

- stable finding/rule code;
- exact affected subject IDs;
- profile/rule-pack version;
- observed facts;
- required constraint;
- evidence references;
- remediation code;
- override policy.

## 5. Remediation guidance

ELV7 MAY provide deterministic remediation categories such as:

- provide missing evidence;
- change project assumption/policy where legally permitted;
- select a different equipment candidate;
- change physical layout;
- change protection/source configuration;
- request documented engineer decision;
- remove a non-compliant configuration.

ELV7 SHALL NOT silently modify the project.

If remediation requires product substitution, ELV8 owns candidate generation. If remediation requires physical changes, ELV6 owns fit. If remediation requires changed engineering demand, ELV5/ELV4 own recalculation.

## 6. Compliance around MAIN/NODE topology

The user-facing tree MAY show compliance badges on MAIN/NODE objects, but authoritative applicability SHALL follow the exact rule scope and project topology.

A node-level green summary SHALL NOT imply every downstream object is compliant unless all applicable blocking dimensions are resolved.

Multiple feeds, generator/UPS/PV/ESS operating cases and redundant network/power paths SHALL remain explicit when a rule depends on operating mode.

## 7. Unknown data

Missing mandatory evidence SHALL appear as `NEEDS_DATA` to the user and `INDETERMINATE` in the normative engine.

The UI SHALL provide the missing fact/evidence category, for example:

```text
Need data:
- certificate/declaration evidence
- environmental rating
- conductor installation evidence
- fault-current basis
```

The product SHALL NOT hide missing information behind a generic warning if it blocks a compliance verdict.

## 8. Override UX

Where an override is legally/policy permitted, the UI SHALL make the decision explicit and auditable.

The user SHALL see:

- what is being overridden;
- why an override is permitted;
- what evidence remains unresolved;
- what warning remains after override.

Non-overridable blocking rules SHALL not present an enabled "accept anyway" path.

## 9. Automatic re-evaluation

Changes to any dependent upstream artifact SHALL stale only the affected compliance outcomes.

Examples:

```text
ELV5 demand changed -> affected ELV7 evaluations stale
ELV6 placement changed -> clearance/thermal/layout-related evaluations stale
ELV8 product changed -> product/evidence-related evaluations stale
rule pack/profile changed -> dependent normative results stale
```

Unrelated node results SHALL remain current.

## 10. Acceptance criteria

1. the user can understand node/project compliance without knowing rule IDs;
2. every compact status drills down to exact ELV7 evidence;
3. `NEEDS_DATA` maps to explicit missing evidence and never to fabricated PASS;
4. blocking failures cannot be hidden by warnings or ranking;
5. remediation is actionable but never silently applied;
6. MAIN/NODE summaries preserve exact affected subjects and operating cases;
7. permitted overrides are explicit and audited;
8. non-overridable rules cannot be bypassed in UI;
9. stale propagation follows real dependency changes only;
10. ELV7 remains a deterministic compliance engine while the client experience stays simple.
