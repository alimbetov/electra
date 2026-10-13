# Electra — ELV Normative Standards Matrix

Status: Draft 0.1  
Branch: `docs/elv-engineering-systems-spec`  
Purpose: define the normative baseline and standard-profile model for ELV design, validation, calculation, equipment selection, routing, commissioning evidence, and reporting.

## 1. Core rule

Electra must not apply all standards globally at the same time. Standards are selected through an explicit `NormativeProfile` bound to the project and versioned in the project reference snapshot.

Priority order for a jurisdictional profile:

1. mandatory law / technical regulation of the project jurisdiction;
2. mandatory national construction rules and national standards;
3. adopted interstate / nationalized IEC/ISO standards;
4. IEC/ISO international baseline where local rules are silent;
5. EN / IEEE / TIA / NFPA or other industry profiles only when explicitly selected, contractually required, or accepted by the authority having jurisdiction;
6. manufacturer requirements, which may be stricter but may not weaken mandatory rules.

A lower-priority rule must never silently override a higher-priority rule.

## 2. Standard profile model

Required model:

```text
NormativeProfile
├── jurisdiction
├── edition
├── effectiveFrom
├── effectiveTo
├── StandardReference[]
├── precedence rules
├── discipline bindings
└── project overrides with rationale
```

Every `StandardReference` must contain at least:

- issuer;
- standard code;
- title;
- edition/year;
- status: ACTIVE / SUPERSEDED / WITHDRAWN / DRAFT / PROJECT;
- jurisdiction;
- applicability scope;
- mandatory/contractual/advisory classification;
- effective date;
- source metadata;
- supersedes / supersededBy relation;
- rule packs derived from the standard.

Project calculations and validation findings must record the exact standard/profile edition used.

## 3. Kazakhstan baseline profile

Canonical default profile for projects in Kazakhstan:

`KZ-ELV-BASELINE`

The profile must support national technical regulations, construction norms, national standards and adopted ISO/IEC standards. International standards can supplement the national profile only where they do not conflict with mandatory Kazakhstan requirements.

Initial standards and regulatory families to track:

### 3.1 Structured cabling / LAN

- `СТ РК ISO/IEC 11801-2-2019` — generic cabling for office premises; active national adoption.
- applicable additional parts of the `СТ РК ISO/IEC 11801` family where adopted for the project building type.
- `ISO/IEC 11801-1:2017` plus current amendments/corrigenda — international generic-cabling baseline.
- `ISO/IEC 14763-2:2019` — planning and installation of customer-premises cabling.
- `ISO/IEC 14763-3` — testing of optical fibre cabling where applicable.
- `ISO/IEC 14763-4` — measurement/testing of balanced copper cabling where applicable.
- selected IEEE 802.3 clauses for Ethernet and remote powering/PoE where relevant.

### 3.2 CCTV / video surveillance

- `СТ РК 4031-2026` — national requirements for types and placement of cameras, effective from 2026-09-01.
- future/current Kazakhstan VSS standards issued from the 2026 national standardization programme must be represented as separate versioned references, not merged into a generic CCTV rule pack.
- `IEC 62676-1-1:2013` — general system requirements.
- `IEC 62676-1-2:2013` — video transmission performance requirements.
- `IEC 62676-4:2025` — current application guidelines for planning, design, installation, testing, commissioning and maintenance.
- relevant `IEC 62676-2-x` interoperability/transmission standards where applicable.
- `IEC 62676-6:2026` only when intelligent video analytics grading/testing is in project scope.

### 3.3 Access control / security

- `IEC 60839-11-1:2013` — electronic access control systems, system and component requirements.
- applicable `IEC 60839-11-x` application/interoperability parts according to the project scope.
- `IEC 62642` family for intrusion and hold-up alarm systems where security alarm functions are included.
- local Kazakhstan security requirements and authority-specific rules must be represented in the KZ profile when applicable.

### 3.4 Fire detection and alarm

Kazakhstan mandatory fire-safety technical regulations and construction norms take precedence.

Track at minimum:

- current Kazakhstan technical regulation governing automatic fire suppression, fire alarm and evacuation warning/control systems;
- current Kazakhstan construction norms for automatic fire suppression and fire alarm design;
- `ISO 7240-1:2025` — fire detection and alarm terminology and functions;
- `ISO 7240-14:2013` — design, installation, commissioning and service; confirmed current in 2025;
- applicable `ISO 7240` product/system parts for control equipment, power supplies, audible/visual alarm devices, detectors, radio paths and other components;
- `EN 54` family may be supported as an optional European profile or where product/project requirements explicitly invoke it, but it must not be silently substituted for Kazakhstan mandatory rules.

### 3.5 Power supply, electrical safety, earthing and EMC

Track at minimum:

- applicable Kazakhstan electrical-installation rules and adopted IEC requirements;
- `IEC 60364` family for low-voltage electrical installations;
- `IEC 60364-4-44:2024` for voltage and electromagnetic disturbances;
- relevant `IEC 60364-5-52` requirements for wiring systems;
- relevant `IEC 60364-5-54` requirements for earthing/protective bonding;
- `IEC 62368-1:2023` for safety of AV/ICT equipment where equipment falls in scope;
- `IEC 61000` EMC family as required by equipment/environment profile;
- `IEC 62305` lightning protection family where surge/lightning coordination affects ELV design.

### 3.6 Cable management and pathways

- `IEC 61537:2023` — cable tray and cable ladder systems.
- applicable IEC/EN/national standards for conduits, trunking, ducting, penetrations and fire stopping.
- pathway fill, segregation and support rules must be selected by normative profile, not hard-coded globally.

## 4. International baseline profile

Provide a non-jurisdiction-specific profile:

`IEC-ISO-ELV-BASELINE`

It is suitable for conceptual design, international projects and as a fallback where a jurisdiction has not yet provided a stricter rule.

Minimum families:

| Discipline | Baseline families |
|---|---|
| Generic cabling | ISO/IEC 11801, ISO/IEC 14763 |
| Ethernet / PoE | IEEE 802.3 |
| CCTV/VSS | IEC 62676 |
| Access control | IEC 60839-11 |
| Intrusion alarm | IEC 62642 |
| Fire detection/alarm | ISO 7240 |
| LV power integration | IEC 60364 |
| Equipment safety | IEC 62368-1 |
| EMC | IEC 61000 |
| Lightning/surge | IEC 62305 |
| Cable trays/ladders | IEC 61537 |
| Information security | ISO/IEC 27001/27002 where system cybersecurity is in scope |

## 5. Optional regional profiles

The architecture must permit additional profiles without changing the domain model.

### 5.1 European profile

Potential families:

- EN 50173 — generic cabling;
- EN 50174 — cabling installation;
- EN 54 — fire detection and fire alarm systems;
- EN 50131 — intrusion and hold-up systems;
- EN 60839 / harmonized IEC 60839 references for access-control systems;
- CPR/fire-reaction requirements for cables where legally applicable;
- local national implementations of these EN standards.

### 5.2 North American profile

Potential families:

- ANSI/TIA-568 — telecommunications cabling;
- TIA-569 — pathways and spaces;
- TIA-606 — administration/labeling;
- TIA-607 — bonding and grounding;
- NFPA 70 / NEC — electrical installation;
- NFPA 72 — fire alarm and signaling;
- UL/product certifications where required.

These are separate profiles and must not be mixed into the Kazakhstan default automatically.

## 6. Discipline-to-standard binding

Every discipline-specific reference-data entity and calculation process must declare its normative dependencies.

Example:

```text
LanPermanentLinkCalculation
├── ISO/IEC 11801 profile
├── national adoption/profile
├── cable category reference
├── connector category reference
└── test/acceptance profile
```

```text
FireBatteryAutonomyCalculation
├── KZ fire regulation profile
├── applicable ISO 7240 part(s)
├── equipment manufacturer limits
└── project safety margin
```

```text
CctvCameraPlacementValidation
├── ST RK 4031-2026
├── IEC 62676-4:2025 guidance
└── project operational requirements
```

## 7. Rule classes

Normative rules must be classified so calculations and UI can treat them correctly.

Required rule classes:

- `LEGAL_MANDATORY`
- `NATIONAL_STANDARD`
- `ADOPTED_INTERNATIONAL`
- `CONTRACTUAL`
- `MANUFACTURER_MANDATORY`
- `ENGINEERING_RECOMMENDATION`
- `PROJECT_POLICY`

A validation finding must expose its rule class and precedence.

## 8. Standards lifecycle

Electra must never represent a standard code as timeless.

Required lifecycle behavior:

1. store edition and effective dates;
2. preserve superseded standards for old projects;
3. warn when a project uses a superseded or withdrawn standard;
4. never auto-migrate an existing project to a newer standard without explicit action;
5. provide impact analysis before profile upgrade;
6. retain calculation/result reproducibility after a standards upgrade;
7. allow a new project template to select the current jurisdictional baseline by default.

## 9. Rule provenance

Every implemented rule must be traceable:

```text
Rule
├── code
├── standardReferenceId
├── clauseReference (metadata only)
├── engineering interpretation
├── parameters
├── units
├── severity
├── applicability predicate
├── effective version
└── validation/calculation handlers
```

Electra must store clause identifiers and engineering interpretations, but it must not embed copyrighted full standards text unless licensing permits it.

## 10. Required standard-driven validations

The normative engine must support, at minimum:

### Routing / pathways
- power/ELV segregation;
- tray/duct fill;
- bend radius;
- support/pathway compatibility;
- penetration/fire-stopping requirements;
- environmental classification;
- grounding/bonding where applicable.

### LAN
- channel/permanent-link length;
- component/category compatibility;
- copper/fibre link class;
- PoE compatibility and power budget;
- fibre optical loss budget;
- labeling/administration profile;
- test acceptance profile.

### CCTV
- camera role/type compatibility;
- placement constraints required by selected national profile;
- field-of-view/coverage evidence where defined by project/standard profile;
- transmission capacity;
- storage/retention policy;
- power availability/backup;
- interoperability requirements where selected.

### Access control
- door assembly completeness;
- reader/controller interface compatibility;
- controller capacity;
- supervised input/output rules;
- lock power and fail-safe/fail-secure behavior;
- backup power/autonomy;
- emergency/fire integration rules according to jurisdiction.

### Fire alarm
- topology integrity;
- control-panel/loop capacity;
- device compatibility;
- line/loop electrical limits;
- power-supply capacity;
- battery autonomy;
- alarm-device circuit capacity;
- cable/fire-performance requirements;
- fault isolation/supervision where required;
- commissioning/test evidence.

## 11. Required standard-driven calculation metadata

Every calculation result affected by standards must contain:

- `normativeProfileId`;
- `standardReferenceIds[]`;
- `calculationProfileVersion`;
- input snapshot hash;
- result;
- units;
- engineering trace;
- warnings;
- timestamp;
- engine version.

## 12. Documentation and commissioning evidence

The standards layer must support generation/recording of:

- equipment schedules;
- cable schedules;
- port/termination schedules;
- labeling schedules;
- route/pathway schedules;
- as-designed and as-built states;
- test results;
- commissioning checks;
- nonconformities and waivers;
- rule/standard references;
- project standard profile declaration.

## 13. Cybersecurity scope

Cybersecurity is not a substitute for electrical/security-system standards but is required for IP-connected ELV systems.

Architecture must support optional cybersecurity profiles based on:

- ISO/IEC 27001/27002 organization/project controls;
- vendor hardening requirements;
- network segmentation policies;
- credential/certificate requirements;
- secure protocol requirements;
- firmware lifecycle requirements;
- audit/logging requirements.

Industrial/BMS extensions should additionally support IEC 62443 profiles when that scope is introduced.

## 14. Acceptance criteria for normative completeness

The ELV specification is not considered implementation-ready until:

1. every supported discipline has a declared standards family;
2. Kazakhstan has an explicit jurisdictional profile;
3. standard editions and lifecycle metadata are modeled;
4. national rules can override international defaults deterministically;
5. every calculation can report its normative sources;
6. every validation can report source, severity and remediation;
7. conflicting profiles cannot silently coexist;
8. project snapshots preserve historical reproducibility;
9. copyrighted standard text is not copied into the product without licensing;
10. a standards-regression test suite exists for all implemented rules.

## 15. Important limitation

This matrix is the architecture and standards inventory baseline. It must not be interpreted as a legal declaration that every listed publication is mandatory for every project. Applicability depends on jurisdiction, building use, authority requirements, contract, equipment scope, project date and the exact edition legally adopted. Each production `NormativeProfile` must therefore be verified against the official register/source before release.
