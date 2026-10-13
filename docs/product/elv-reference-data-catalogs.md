# Electra — Canonical ELV Reference Data Catalogs

Status: Draft 0.1  
Branch: `docs/elv-engineering-systems-spec`  
Scope: canonical low-voltage reference data used by design, validation, calculation, selection and reporting

## 1. Purpose

Electra must treat low-voltage engineering (ELV) as a first-class engineering discipline with its own canonical reference data, not merely as generic components with ad-hoc properties.

The common engineering kernel remains shared across power and ELV systems, but ELV disciplines receive dedicated dictionaries, calculation profiles and normative profiles.

The key design rule is:

> **Shared geometry and connectivity kernel; discipline-specific engineering semantics.**

This means that `EngineeringComponent`, `Port`, `Connection`, `Cable`, `CableRun`, `Route`, `Enclosure`, dependency tracking and reporting infrastructure are generic, while CCTV, LAN, access control and fire alarm use typed reference data that describes their own engineering rules.

## 2. Reference-data hierarchy

Reference data is divided into five layers.

### L0 — Common engineering reference data

Shared by electrical and ELV disciplines:

- manufacturers
- product families
- product models
- units of measure
- voltage classes
- current classes
- conductor materials
- mounting types
- enclosure types
- route carriers
- environmental classes
- IP/IK protection classes
- fire-reaction/fire-resistance classifications
- connector families
- project normative profiles

### L1 — ELV common reference data

Shared by several ELV systems:

- ELV system families
- ELV topology types
- signal/media types
- cable media types
- port/interface families
- communication protocols
- power-supply methods
- redundancy classes
- reserve factors
- battery technologies
- cable-separation classes
- ELV routing classes
- supervision classes
- availability classes

### L2 — Discipline reference data

Dedicated dictionaries per discipline:

- CCTV
- LAN / structured cabling
- access control
- fire alarm
- intrusion alarm
- intercom
- public address / voice alarm
- BMS / automation

### L3 — Manufacturer catalog data

Concrete products and vendor attributes:

- cameras
- switches
- NVRs
- patch panels
- access controllers
- readers
- detectors
- fire panels
- modules
- PSUs
- UPSs
- batteries
- cables
- racks
- cabinets

### L4 — Project overrides

Project-level values and approved equivalents:

- preferred manufacturers
- forbidden manufacturers
- accepted product substitutions
- project derating
- reserve coefficients
- allowed cable classes
- approved topology patterns
- local normative rules

Project overrides must never mutate the global catalog; they form a project-specific overlay.

## 3. Canonical identity and versioning

Every reference entity must have:

- stable technical `code`
- immutable semantic identity
- human-readable names
- lifecycle status (`ACTIVE`, `DEPRECATED`, `RETIRED`)
- validity interval where relevant
- source / provenance
- version
- optional normative reference

Example:

```text
code: POE_IEEE_802_3AT
name: IEEE 802.3at PoE+
status: ACTIVE
version: 1
```

Existing projects must preserve the reference version used at design time unless an explicit migration/recalculation is requested.

## 4. ELV common catalogs

### 4.1 System family

Suggested codes:

- `CCTV`
- `LAN`
- `WIFI`
- `ACS`
- `FIRE_ALARM`
- `INTRUSION_ALARM`
- `INTERCOM`
- `PA_VOICE_ALARM`
- `TELEPHONY`
- `TV_RF`
- `BMS`
- `AUTOMATION`
- `IOT`

### 4.2 Topology type

Examples:

- `POINT_TO_POINT`
- `STAR`
- `TREE`
- `BUS`
- `LOOP`
- `RING`
- `RADIAL`
- `DAISY_CHAIN`

The topology catalog stores not just a label but constraints such as whether a closed loop is required, whether branching is allowed and whether node order matters.

### 4.3 Interface / port family

Examples:

- Ethernet copper
- Ethernet fiber
- RS-485
- RS-232
- OSDP
- Wiegand
- dry contact
- relay contact
- supervised input
- analog input
- 12 VDC power
- 24 VDC power
- 48 VDC power
- PoE
- audio line
- RF coax
- fire loop

An interface family describes compatibility semantics; a physical connector such as RJ45 is a separate attribute.

### 4.4 Protocol catalog

Examples:

- Ethernet
- IPv4 / IPv6
- ONVIF
- RTSP
- Modbus RTU
- Modbus TCP
- BACnet
- KNX
- DALI
- OSDP
- Wiegand
- SNMP
- SIP

Protocol compatibility and physical-interface compatibility are validated separately.

### 4.5 Power method catalog

Examples:

- direct DC
- transformer-fed AC
- central PSU
- local PSU
- PoE
- PoE+
- PoE++
- UPS-backed AC
- battery-backed DC
- loop-powered

This dictionary is used by both topology and calculation engines.

## 5. CCTV catalogs

CCTV receives dedicated reference data for at least:

- camera form factor
- camera sensor/resolution class
- lens type
- focal length / field-of-view data
- IR range
- codec
- stream profiles
- frame-rate profile
- bitrate profile
- ONVIF profile
- storage retention profile
- recording mode
- NVR channel class
- PoE class
- camera environment/mounting class

Calculation-relevant fields must be separated from descriptive marketing fields.

## 6. LAN / structured cabling catalogs

LAN receives dedicated reference data for:

- permanent-link class
- channel class
- cable category
- shielding type
- pair count
- fiber type (`OS1`, `OS2`, `OM3`, `OM4`, `OM5`, etc.)
- connector class
- patch-panel type
- outlet type
- switch-port media
- switch speed
- PoE capability
- rack-unit form factor
- copper/fiber length limits
- loss-budget profiles

A cable category is not a free-form product attribute; it is canonical reference data used by validation and selection.

## 7. Access-control catalogs

ACS receives dedicated reference data for:

- reader technology
- credential technology
- reader interface
- door topology type
- lock type
- fail-safe/fail-secure behavior
- lock current profile
- controller input/output type
- supervised input type
- door sensor type
- request-to-exit type
- emergency-release integration type
- access-point assembly role
- battery/autonomy profile

A door assembly must reference these dictionaries rather than carrying opaque strings.

## 8. Fire-alarm catalogs

Fire alarm receives dedicated reference data for:

- fire system architecture
- loop type
- detector type
- manual call point type
- sounder / beacon type
- isolator type
- input/output module type
- control panel family
- loop-device addressing mode
- loop capacity profile
- current-consumption profile
- standby/alarm operating mode
- cable fire-resistance class
- battery autonomy profile
- monitored circuit type
- supervision/end-of-line type

Fire-alarm catalogs are versioned independently because normative changes can be safety-critical.

## 9. Cable catalog model

The cable catalog must support both generic classification and manufacturer products.

Canonical cable attributes include:

- purpose / media class
- conductor count
- pair count
- fiber count
- conductor cross-section
- conductor material
- characteristic impedance where relevant
- DC resistance
- capacitance / inductance where relevant
- shielding
- outer diameter
- minimum bend radius
- pulling constraints
- voltage rating
- fire performance
- installation environment
- category / standard profile

Manufacturer cable products bind to canonical classes while adding exact technical values.

## 10. Calculation profiles as reference data

Calculation behavior must be driven by versioned profiles rather than constants hidden in source code.

Examples:

- `CCTV_STORAGE_PROFILE`
- `POE_POWER_PROFILE`
- `FIRE_BATTERY_AUTONOMY_PROFILE`
- `LAN_CHANNEL_LIMIT_PROFILE`
- `ACS_LOCK_POWER_PROFILE`
- `VOLTAGE_DROP_PROFILE`
- `ROUTE_FILL_PROFILE`

A profile contains:

- code
- discipline
- calculation type
- input schema version
- parameters
- normative source
- default reserve factors
- effective date
- lifecycle status

Algorithms remain code, but coefficients, thresholds and policy values belong in reference data.

## 11. Normative profiles

Normative rules must be grouped into named/versioned profiles.

Example:

```text
ELV-NORM-KZ-2026
  ├── power/data separation rules
  ├── fire cable rules
  ├── route fill rules
  ├── voltage-drop policy
  ├── battery reserve policy
  └── documentation requirements
```

A project explicitly selects its normative profile(s).

No project should silently change behavior because a global rule was edited later.

## 12. Reference-data governance

Reference data must support:

- import/export
- audit history
- deprecation without destructive deletion
- manufacturer supersession
- project pinning
- validation before activation
- localization
- unit normalization
- provenance
- effective dates

The application must distinguish:

1. canonical reference data;
2. manufacturer catalog data;
3. project-local data;
4. calculated project data.

Mixing these categories in one generic key/value table is prohibited.

## 13. UI requirements

The ELV catalog UI should expose discipline-specific sections.

Example:

```text
Reference Data
├── Common Engineering
├── ELV Common
├── CCTV
├── LAN / Structured Cabling
├── Access Control
├── Fire Alarm
├── Intrusion Alarm
├── Intercom
├── BMS / Automation
└── Manufacturer Catalogs
```

An engineer must be able to inspect which reference value and which version caused a calculation or validation result.

## 14. Acceptance criteria

The reference-data layer is acceptable when:

1. CCTV storage parameters are resolved from CCTV catalogs/profiles, not hard-coded UI fields.
2. LAN maximum link length is resolved from a structured-cabling profile.
3. ACS lock current and autonomy calculations use typed lock and battery profiles.
4. Fire-alarm loop capacity and standby/alarm consumption use fire-specific catalogs.
5. A project can pin catalog/profile versions and produce deterministic recalculation later.
6. Manufacturer products map to canonical engineering classes.
7. Deprecated reference data remains readable for existing projects.
8. Reports can state the reference profile/version used for each critical calculation.
