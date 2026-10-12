# ADR-008: Measurement units and canonical geometry

## Status
Accepted

## Context

Electra must support users working in metric and imperial systems without allowing unit selection to corrupt geometry, routing or collaboration data.

## Decision

All persisted geometric lengths use canonical integer millimetres. Measurement-system selection is an input/output concern, not a storage concern.

```text
Persisted geometry -> integer millimetres
UI input/output     -> METRIC | IMPERIAL
```

Initial measurement systems:

- `METRIC`
- `IMPERIAL`

A project stores its preferred display/input measurement system so different projects can use different conventions. A user may also have an account/device default used when a new project is created.

## Metric presentation

Initial display/input units may include:

- millimetres;
- centimetres;
- metres.

## Imperial presentation

Initial display/input modes may include:

- decimal inches;
- feet + inches;
- configurable fractional-inch precision.

For example, a persisted value of `4200 mm` may be presented as approximately `4.20 m` or `13 ft 9 3/8 in` depending on project preferences.

## Grid and snapping

Editor grid spacing is selected in the user's display system but converted to canonical millimetres before geometry operations. The same applies to typed dimensions and offsets.

## Non-goals

- persisting formatted strings such as `4.2 m` or `13' 9\"`;
- storing mixed unit systems inside route geometry;
- duplicating metric and imperial values in persistence.

## Consequences

- geometry/routing calculations remain deterministic;
- switching display systems is reversible within formatting precision;
- sync never requires unit migration;
- reports can render in the project's preferred system without changing source geometry.
