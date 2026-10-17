# FA-08 ampacity hardening amendment

Status: **AUTHORITATIVE PROCESS-DOSSIER AMENDMENT**  
Base dossier: `fire-processes.md`, section `FA-08 — Fire cable/environment policy evidence basis`.  
Shared contract: `../ampacity-engineering-contract.md`.

This amendment adds cable allowable continuous current `Iz` to the FA-08 technical-policy basis without creating a new ELV5 process.

## 1. Physical meaning — amendment

FA-08 may verify that a realized cable/route section has sufficient technical ampacity evidence. `Iz` is a cable thermal/current-carrying capability dimension and remains independent from connected load, voltage drop, protection coordination and verified compliance.

## 2. Applicability matrix — amendment

Ampacity dimension is applicable only when the selected policy requires it and exact evidence exists for section, material, insulation/temperature system, installation method, loaded conductors, ambient temperature, grouping and all applicable correction factors.

Missing any mandatory driver => affected ampacity dimension BLOCKED.

## 3. Exact typed inputs — amendment

Add optional per-section:

```text
Elv5AmpacityInput
```

with mandatory physical drivers:

```text
conductorCrossSectionMm2
conductorMaterialCode
insulationSystemCode
referenceAmbientTemperatureC
installationMethodCode
loadedConductors
baseAllowableCurrentA
actualAmbientTemperatureC
temperatureFactor
groupedCableOrCircuitCount
arrangementCode
groupingFactor
additionalCorrections[]
```

## 4. Evidence requirements — amendment

Reference row, temperature factor, grouping factor and every additional factor carry immutable `evidenceRef + evidenceContentHash`. Raw `double` values or UI defaults cannot qualify Iz.

## 5. Operating cases — amendment

Add technical dimension:

```text
AMPACITY_IZ_A
```

It is section-scoped and evaluated independently for every realized route section where the policy requires it.

## 6. Mathematical model — amendment

```text
Iz = Iref * kT * kG * product(kAdditional)
```

Reference-row selection is external evidence resolution, not a hidden lookup inside FA-08.

## 7. Equations — amendment

For a minimum ampacity technical requirement:

```text
Miz = Iz - IzRequired
```

`Miz >= 0` => technical dimension PASS when comparison is inclusive.

## 8. Exact/bounded arithmetic — amendment

`Iref`, factors, `Iz`, threshold and margin use exact `Elv5Rational`. Binary float must not decide the result.

## 9. Worst-case selection — amendment

Across route sections, the smallest signed `Miz` is the limiting ampacity section for the ampacity dimension. It is not compared numerically with margins expressed in different units.

## 10. Requirement composition — amendment

Ampacity requirements compose only with compatible current-unit requirements. Do not merge Iz with voltage, fire class, environment-tag or compliance dimensions into one scalar margin.

## 11. Comparison equations — amendment

```text
Iz >= IzRequired
```

is the only v1 ampacity technical comparison exposed by FA-08. Connected-load/protective-device inequalities are outside this amendment.

## 12. Margin equation — amendment

```text
Miz[A] = Iz[A] - IzRequired[A]
```

## 13. Governing-case algorithm — amendment

Evaluate each section independently, retain all results and select the first worst ampacity margin by signed value then canonical section identity for ties. Cross-unit dimensions remain independently governing.

## 14. Limiting-factor algorithm — amendment

Report the exact route section and the evidence driver/factor set used to produce Iz. Missing evidence reports the missing driver, not a fabricated zero or factor 1.

## 15. Missing/unsupported behavior — amendment

Forbidden defaults include copper, 30 C, installation method, loaded-conductor count, grouping count and correction factor 1.0. Unsupported reference-table/interpolation model is BLOCKED.

## 16. Dependency set — amendment

Add:

```text
cable/reference edition
section identity
cross-section/material evidence
installation-method evidence
loaded-conductor profile
temperature evidence edition
grouping membership selector
ampacity reference edition
factor editions
```

Grouping membership is selector-aware: adding/removing another grouped cable invalidates Iz.

## 17. Calculation trace — amendment

Add trace stages:

```text
FA08_BIND_AMPACITY_REFERENCE_ROW_V1
FA08_BIND_TEMPERATURE_FACTOR_V1
FA08_BIND_GROUPING_FACTOR_V1
FA08_COMPUTE_IZ_V1
FA08_COMPARE_MINIMUM_IZ_V1
```

## 18. Complexity/resource bounds — amendment

Pure Iz arithmetic is O(F) for bounded factor count F. Grouping membership resolution occurs in the application resolver with bulk reads; N+1 route/member queries are forbidden.

## 19. Pseudocode — amendment

```text
if policy.requires(AMPACITY_IZ_A):
  ampacity = requireExactAmpacityInput(section)
  iz = AmpacityKernel.evaluate(ampacity)
  compare iz.allowableCurrentIzA with policy.minimumIzA
```

## 20. Dart interfaces — amendment

```text
Fa08RouteSection.ampacityInput : Elv5AmpacityInput?
Fa08RouteSection.ampacityIzPropertyCode = AMPACITY_IZ_A
```

Caller-supplied `Fa08NumericFact(propertyCode=AMPACITY_IZ_A)` is rejected.

## 21. Positive reference vector — amendment

```text
Iref = 40 A
kT = 0.91
kG = 0.80
Iz = 29.12 A
required = 29 A
margin = +0.12 A
PASS
```

## 22. Boundary vector — amendment

`Iz == required Iz` => zero-margin technical PASS for inclusive policy.

## 23. Negative vector — amendment

`Iz=28.5 A`, required `29 A` => `-0.5 A` technical FAIL even if voltage drop separately passes.

## 24. Adversarial vector — amendment

A caller attempts to inject raw `AMPACITY_IZ_A=999 A` without the shared ampacity contract. Construction must reject it. A grouping change must invalidate previously published Iz.

## 25. Cross-discipline vector — amendment

The same physical Iz evidence may be consumed by other ELV5 disciplines. Fire does not own a separate physical ampacity calculation. FA-08 technical PASS does not imply ELV7 verified regulatory compliance.
