# ADR-018: Engineering results are explainable and ruleset-driven

## Status
Accepted

## Context
Electra will recommend cable sizes, protective devices, circuit grouping, phase allocation, routing constraints and other engineering decisions.

A professional engineer must be able to understand why a recommendation was produced, what inputs were used and which engineering rules were applied. Hard-coded universal thresholds or opaque recommendation logic would reduce trust and create safety and maintainability risks.

## Decision
All non-trivial engineering recommendations must be produced under an explicit versioned ruleset and expose an explanation record.

```text
Engineering input
    +
ElectricalRuleset
    ↓
Calculation / planner
    ↓
EngineeringDecision
```

### ElectricalRuleset
A ruleset is versioned and identifies the regulatory/engineering context used by a calculation.

Representative fields:

```text
ElectricalRuleset
- id
- jurisdiction
- standardCode
- version
- effectiveFrom?
- effectiveTo?
- sourceReference?
```

Ruleset data may include conductor ampacity tables, installation methods, correction factors, minimum sections, voltage-drop limits, protection coordination constraints, RCD requirements and related parameters.

The engineering core must not embed unexplained numeric regulatory constants in UI code.

### EngineeringDecision
A calculated or recommended result must be able to expose:

```text
EngineeringDecision
- id
- decisionType
- subjectId
- result
- inputs[]
- reasons[]
- warnings[]
- rulesetId
- rulesetVersion
- calculationVersion
- createdAt
```

Example:

```text
Selected cable: 4 mm²

Reasons:
- ampacity requirement
- voltage-drop requirement
- protection coordination

Ruleset:
- <standard / jurisdiction / version>

Warnings:
- grouping correction applied
```

## Recommendation lifecycle
Automatic engineering output is a proposal, not an invisible irreversible decision.

```text
PROPOSED
  -> USER_CONFIRMED
  -> MANUALLY_MODIFIED
  -> VALIDATED
```

Manual override must preserve the original recommendation and record the override reason where appropriate.

## Scope boundary
Electra electrical-first MVP focuses on practical low-voltage design and field engineering. It must not claim to replace specialized power-system analysis suites for capabilities such as:

- advanced load-flow studies;
- arc-flash studies;
- transient stability;
- detailed MV/HV system analysis;
- advanced protection discrimination studies beyond explicitly implemented rulesets.

## Consequences
Positive:

- engineers can audit and trust recommendations;
- calculations remain testable and reproducible;
- regulatory updates can be versioned without rewriting UI code;
- reports can include calculation basis and warnings;
- project history retains the basis for previous decisions.

Trade-offs:

- ruleset governance becomes a product capability;
- calculations require stronger test fixtures and provenance;
- standards data must be sourced and validated before numerical engines are declared production-ready.
