# ELV7 — Protection and classification contract

Status: DESIGN CONTRACT; no implemented protection or compliance qualification.
Owner: ELV7 applicability/assessment; electrical fact producers retain their existing ownership.

## 1. Independent classification namespaces

The requested B/C/D groups mean breaker time-current characteristics in this
contract. Other similarly named classifications remain independent:

| Typed namespace | Supported design vocabulary | Required discrimination |
|---|---|---|
| `OVERCURRENT_TRIP_CURVE` | B, C, D; K, Z, MA and manufacturer-declared extensions | Product standard/edition, device family, release technology, AC/DC and complete envelope |
| `RESIDUAL_WAVEFORM_TYPE` | AC, A, F, B; additional declared variants | Residual waveform/frequency/DC response, not breaker curve |
| `RESIDUAL_TIME_BEHAVIOUR` | instantaneous, delayed, selective and verified product-specific variants | Time envelope independent of waveform type |
| `FUSE_UTILIZATION` | gG, gM, aM and registered standard-specific classes | Full-range versus partial-range protection and overload partner |
| `SPD_TEST_TYPE` | Type 1, Type 2, Type 3, declared combined devices | Never infer from a legacy marketing B/C/D label |
| `CABLE_REACTION_TO_FIRE` | EU-profile Aca, B1ca, B2ca, Cca, Dca, Eca, Fca | Separate smoke, droplets and acidity dimensions; national applicability explicit |
| `BUILDING_FIRE_CATEGORY` | Source-defined national categories | No transliteration mapping to breaker characteristics |
| `SUPPLY_RELIABILITY_CATEGORY` | Source-defined national categories | Independent of load circuit labels and breaker ratings |
| `ENCLOSURE_PROTECTION` | IP, IK and exact test/declaration contexts | Assembly after modifications is not an empty-enclosure certificate |
| `CIRCUIT_PURPOSE_GROUP` | lighting, sockets, motor, ICT, CCTV, ACS, FIRE, emergency and project extensions | Purpose informs applicability; it does not select curve automatically |

`ClassificationRef = (namespace, schemeEditionId, code, sourceHash)`.
Do not persist a bare `group: "B"`. Unknown classes are preserved as typed
unresolved input, never silently coerced to C or a supposedly safer class.
Manufacturer extensions require exact provenance and checker capability;
registration of a label does not prove a normative interpretation.

## 2. Existing-code reconciliation

- `ProtectionRuleset.tripCurves`, `residualTypes` and `CircuitProtectionInputs`
  in `packages/engineering_core/lib/src/protection_requirements.dart` remain
  the project-authored proposal foundation. An existing proposed/validated
  engineering decision is not a statutory compliance finding.
- `NormativeDocument`, `NormativeCriterion` and the existing `NormativeDocuments`
  persistence remain canonical source identity. Add immutable source-edition
  and rule-proof relations; do not create a competing document catalogue.
- `ElectricalRulesetRef`, manufacturer `tripCurve` strings and historical
  payloads remain readable. Migration needs an explicit classification mapping
  record; ambiguous old strings stay `UNRESOLVED`.
- ELV7 consumes protection proposals and adopted product facts. It does not
  change nominal ratings, choose a SKU, resize cables or run ELV8 selection.
- Missing AC protective-device/TCC/short-circuit producer facts are P0 gaps.
  ELV4 PWR DC/PoE evidence is not a substitute for an AC fault study.

## 3. Proposed typed inputs

```dart
enum ProtectiveDeviceKind { mcb, mccb, acb, fuse, rccb, rcbo, motorProtector }
enum SupplyWaveform { acSinusoidal, dc, rectified, inverter, unknown }
enum CurrentMeaning { continuousRms, startingRms, instantaneousPeak, faultRms }
enum CurveEvaluation { noTripProven, tripByTimeProven, uncertain, outOfDomain }

final class TripEnvelopeRef {
  final String definitionEditionId, productVariantHash;
  final String standardEditionId, curveCode, envelopeHash, algorithmVersion;
  final SupplyWaveform supply;
  final String voltageRangeRef, frequencyRangeRef, ambientRangeRef;
  final String mountingDeratingRef, preconditioningRef;
  // Inclusive/exclusive bounds and coverage of every domain segment explicit.
  final String timeCurrentEnvelopeRef;
}

final class ProtectionAssessmentInput {
  final String circuitId, designRevisionId, adoptedDeviceEvidenceRef;
  final String earthingArrangementRef, sourceModeRef;
  final String loadCurrentIntervalRef, correctedAmpacityEvidenceRef;
  final String minFaultCurrentEvidenceRef, maxFaultCurrentEvidenceRef;
  final String inrushWaveformEvidenceRef, loopImpedanceEvidenceRef;
  final String conductorThermalEvidenceRef, requiredDisconnectTimeRuleRef;
  final TripEnvelopeRef tripEnvelope;
}
```

These are design signatures. Required/optional facts are resolved per rule;
an RCD-only rule need not demand a motor inrush waveform. Inputs are finite,
dimensioned rational intervals, with source definition, scenario, temperature,
uncertainty, projection version and consumed generation. No float epsilon
decides a boundary. No unchecked string-to-double or A/kA/mA coercion.

## 4. B/C/D and manufacturer envelopes

Common AC classification examples are B approximately 3–5 × In, C 5–10 × In
and D 10–20 × In; these are explanatory ranges, **not executable production
constants**. A reviewed Schneider family FAQ gives D 10–14 × In, while an ABB
technical publication depicts D 10–20 × In. See [source review](source-review-notes.md).
The actual adopted product/standard envelope and conditions govern.

The engine must retain both:

1. the product-standard classification evidence;
2. the exact product/release setting envelope including tolerances.

Do not replace the upper guaranteed trip boundary by the midpoint or lower
magnetic boundary. Do not treat crossing the lower boundary as proof of
disconnection. Do not export an AC curve to DC. K/Z/MA thresholds are never
guessed from a global table. Adjustable releases include Ir/tr/Isd/tsd/Ii,
ground-fault settings, units and actual adopted setting revisions.

An instantaneous-region test only establishes one sufficient mechanism under
its proven time limit. If it cannot prove that mechanism, run an available
complete TCC check; otherwise return `NOT_EVALUABLE`. Absence of an
instantaneous-trip guarantee is not by itself proof of excessive total trip time.
Missing thermal-region data cannot be filled by connecting diagram pixels.

Digitized curves need an approved extraction/uncertainty record and an explicit
interpolation law. Outside supported segments: `OUT_OF_DOMAIN`, not extrapolated
PASS. In a conservative proof, enlarge uncertainty bounds; never smooth away
overlap. A loose upper envelope failing a limit is not a demonstrated violation
unless the evidence also proves actual required-time failure.

## 5. Separate checks and numeric contracts

| Rule family | Conservative proof basis | Prohibited shortcut |
|---|---|---|
| Overload | upper Ib ≤ selected In ≤ lower corrected Iz; I2 ≤ α·Iz when the adopted clause defines α and conditions | Assume α is a universal constant or ignore fuse partial-range duty |
| Disconnection | worst-case trip-time upper bound over the entire admissible fault-current interval ≤ adopted time limit | Use only maximum fault current or the lower magnetic threshold |
| Interrupting capacity | rated capacity at actual voltage/poles/AC/DC/test standard ≥ upper prospective fault current | Infer kA capacity from B/C/D or compare Ics/Icu/Icn interchangeably |
| Inrush ride-through | complete startup current/time envelope inside a proven non-trip region for the applicable initial thermal state | Compare one peak to an RMS threshold or select D from load name |
| Conductor short-circuit withstand | worst-case let-through ∫i²dt ≤ lower k²S² within the adopted adiabatic/material/time validity domain | Treat continuous ampacity as fault-energy proof |
| Selectivity | exact upstream/downstream pair, settings, voltage and operating domain, supported coordination table or permitted full-envelope proof | Assume higher upstream In or B-before-C is selective |
| Cascading/backup | explicit tested pair/conditions/table edition covering the maximum fault level | Treat two individually rated devices as a certified combination |
| RCD suitability | waveform/DC/frequency and earthing context within adopted device response/limitation evidence | Equate an overcurrent B curve with Type B residual protection |
| TT/TN/IT protection | arrangement-specific adopted criterion and required fault modes with valid PE/loop/earth/monitoring evidence | Apply TN loop formula to all earthing arrangements |
| Voltage drop | actual source mode, allowable profile limit and owner-produced worst-case drop | Treat a valid terminal voltage result as every jurisdictional drop criterion |

`Icn`, `Icu`, `Ics`, peak making current, rms fault current and let-through
energy remain different dimensions/semantics. Series/current-limiting effects
need evidence, not numeric subtraction. AC and DC source modes, normal/mains,
generator, inverter, UPS bypass and battery operation are distinct scenarios.
The admissible worst case may differ by rule: minimum fault current governs
disconnection; maximum prospective current governs interruption.

For every inequality evaluate intervals conservatively:
`SATISFIED` only when every supported value satisfies it; `VIOLATED` only when
the evidence proves violation; overlap/insufficient precision yields
`NOT_EVALUABLE`. A provable counterexample in a complete mandatory scenario
set is sufficient for a violation. Missing required scenarios block a PASS.

## 6. Reference example, not a production ruleset

Hypothetical imported cold-AC 16 A profiles with guaranteed fast-region upper
bounds 5 × In and 20 × In give 80 A and 320 A respectively. An available
90–110 A fault interval lies above 80 A but not 320 A. The first profile can
support the declared fast-region proof if its time bound suffices; the second
needs the complete time-current envelope or remains not evaluable. Both still
need breaking-capacity, cable protection, earthing and applicability checks.

This fixture is `FICTIONAL_TEST`: neither its values nor a green isolated
inequality are a national compliance approval.

## 7. RCD, fuses, SPD, cable fire and room categories

- RCD AC/A/F/B definitions, residual sensitivity, delay/selectivity and rated
  short-circuit coordination have separate evidence. B+ or other extended
  labels require their own scheme. RCCB has no inferred overload protection;
  RCBO combines separately assessed functions. Do not infer permissible DC
  components from a marketing label alone.
- gG/gM/aM duties and a separate overload partner are explicit. An aM fuse
  alone cannot manufacture a complete overload-protection proof.
- SPD needs matching system/earthing/voltage/polarity context, test type,
  Uc/Up and source-declared discharge/current impulse capabilities; it is not
  selected from breaker curve or a universal three-letter translation.
- Fire cable classification is a vector with a scheme edition and tested
  assembly/installation context. CPR reaction-to-fire does not prove functional
  circuit integrity, LSZH properties, egress suitability or KZ applicability.
- National fire/explosion room categories, external influences, supply
  reliability, life-safety duty and network availability remain independent
  context facts. Explicit scope/date/source data is mandatory.

## 8. Engineer workflow

Show adopted device/curve/standard and actual source mode; display minimum and
maximum fault evidence separately; explain required and guaranteed trip times,
uncertainty and the limiting rule. Compare B/C/D alternatives as read-only
what-if results, each with missing facts and assumptions. A candidate does not
modify the design or become CURRENT compliance. No “increase breaker rating”
one-click fix. Applying an engineering change uses its existing owner command,
impact preview and subsequent revalidation.

## 9. Required regression oracles

Plan at least: B/C/D same-In different envelopes; D 10–14 versus 10–20 contexts;
K/Z absent envelope; AC envelope on DC; lower/upper/open/exact boundary;
thermal fallback; minimum/maximum Ik swapped; 6 kA versus 7 kA fault; Ics/Icu
confusion; adjustable-setting change; short/long duration inrush; peak/RMS
mismatch; ambient/preheated device; RCD B versus MCB B; unsupported residual
waveform; aM without overload partner; missing selectivity table; invalid
cascading pair; IT second fault omitted; kA/A and mA/A conversions; cable fire
versus circuit integrity; two same-code classifications in different namespaces.

Every case needs a complete input vector, exact adopted hypothetical or
reviewed source, expected raw result/reason and an independent numerical oracle.
The [qualification plan](qualification-plan.json) records planned cases only.
