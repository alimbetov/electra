# ELV7 — Project Workspace Normative-Validation Roadmap

Status: normative implementation roadmap  
Branch: `feat/flutter-elv7-normative-validation-design`

## 1. Purpose

ELV7 turns structured engineering facts into deterministic, explainable normative qualification that can be surfaced in the Project Workspace without exposing raw rule IDs as the primary UX.

ELV7 owns:

- versioned normative profiles/rule packs;
- jurisdiction/project applicability;
- deterministic PASS/FAIL/WARNING/INDETERMINATE/NOT_APPLICABLE outcomes;
- evidence/reference traceability;
- override governance;
- user-facing compliance issue projection.

ELV7 does not own manufacturer catalog facts, ELV5 engineering calculations, ELV6 physical layout or ELV8 commercial ranking.

## 2. User journey owned by ELV7

```text
engineering/layout/configuration candidate exists
 -> resolve applicable normative profile/rules
 -> evaluate deterministic rules
 -> project results to actionable user issues
 -> provide engineer drill-down with exact evidence/reference
 -> permit only explicit, policy-allowed override
```

## 3. Implementation packages

### W7-0 — upstream/profile reconciliation

- pin accepted ELV5 technical projection and ELV6 physical-evidence contracts;
- pin normative profile/rule-pack versions per project;
- define stale behavior when rule pack, project facts or physical evidence changes;
- keep missing evidence distinct from non-compliance.

Gate: no verified compliance claim without pinned profile and complete required evidence.

### W7-1 — applicability resolver

Implement deterministic scope/applicability resolution over:

```text
project jurisdiction
project profile
subject/domain
operating mode/source type
component capabilities
physical context
```

Rules:

- a project-policy title alone never proves statutory applicability;
- unsupported/ambiguous applicability => `INDETERMINATE`, not PASS;
- non-applicable rules remain explicit and auditable.

### W7-2 — rule-evaluation kernel

Required pure boundary:

```text
NormativeRule + structured facts + profile -> verdict + evidence
```

Required outputs:

```text
ruleId
profile/rulePack version
subjectIds
observed facts
required constraint
verdict
severity
references
assumptions
remediation code
```

Gate: same pinned inputs => same verdict/fingerprint.

### W7-3 — candidate pre-commit evaluation

ELV8 must be able to evaluate a candidate/assembly before Apply.

Required behavior:

- side-effect free;
- blocking violation eliminates candidate;
- missing mandatory certification/fact => INDETERMINATE or blocker according to profile;
- lower price/availability never compensates for a normative blocker.

### W7-4 — workspace state projection

Map exact normative results into simple workspace state:

```text
READY
ATTENTION
CRITICAL
NEEDS_DATA
STALE
```

Example user message:

```text
The selected protective device cannot be confirmed: verified breaking-capacity evidence is missing.
```

Engineer drill-down reveals rule ID, profile edition, required/observed values and reference.

Gate: every simplified compliance issue maps back to exact machine evidence.

### W7-5 — remediation projection

Each supported rule should expose a stable remediation category, for example:

```text
SELECT_DIFFERENT_COMPONENT
ADD_REQUIRED_EVIDENCE
CHANGE_ENGINEERING_PARAMETER
CHANGE_LAYOUT
REQUEST_ENGINEER_DECISION
NO_OVERRIDE_ALLOWED
```

ELV7 does not itself select the replacement SKU; ELV8 may consume remediation constraints.

### W7-6 — overrides

Implement explicit audited override model:

```text
overrideId
ruleId
subjectId
projectRevision
reason
actor/identity reference
scope
createdAt
remaining warnings
```

Rules:

- no silent suppression;
- safety/life-safety profile rules may be non-overridable;
- override affects only declared scope;
- frozen revisions retain historical override evidence.

### W7-7 — source/operating-mode qualification

Generic capability-based handling for:

- grid;
- generator;
- UPS;
- battery/ESS;
- PV/inverter;
- ATS/transfer;
- islanded/parallel modes.

No separate rule engine per source type.

### W7-8 — issue/readiness integration

Provide project/node/configuration compliance projections suitable for `ISSUES` and `ISSUE` workspaces.

Readiness gate must distinguish:

```text
blocking non-compliance
engineer decision required
warning
missing evidence
stale qualification
fully qualified
```

### W7-9 — golden vertical

Mandatory scenario:

```text
NODE-F2 candidate equipment selected
 -> one candidate lacks mandatory verified technical/certification fact
 -> workspace shows NEEDS_DATA/CRITICAL as defined by profile
 -> alternative candidate passes
 -> engineer can inspect exact rule/evidence
 -> only passing candidate may proceed to Apply
```

## 4. Testing

Required:

- positive/negative/boundary rules;
- missing-evidence tests;
- applicability ambiguity tests;
- profile version pinning/replay;
- override allowed/forbidden tests;
- stale rule-pack tests;
- external-source operating-mode tests;
- candidate side-effect-free tests;
- UI projection-to-evidence trace tests.

## 5. Completion gate

ELV7 workspace implementation is complete when normative status is deterministic, profile-pinned, actionable for normal users, fully drillable for engineers/auditors, and impossible to bypass through ranking, UI shortcuts or silent overrides.
