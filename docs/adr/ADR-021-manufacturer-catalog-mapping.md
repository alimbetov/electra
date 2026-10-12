# ADR-021: Manufacturer catalogs map engineering roles to concrete products

## Status
Accepted

## Context

Panel generation and circuit protection logic must remain standards/ruleset-driven, but real projects ultimately need concrete purchasable components from manufacturers such as Schneider Electric, ABB, Siemens, Legrand and others.

Embedding manufacturer part numbers directly into engineering rules would couple safety logic to commercial catalogs and make projects difficult to migrate between brands.

## Decision

Separate three concerns:

```text
Engineering requirement
        ↓
Functional device role
        ↓
Manufacturer catalog matching
        ↓
Concrete product variant
```

Rulesets produce functional requirements. Catalogs resolve those requirements to compatible commercial products.

## Functional device role

Examples:

```text
MCB
RCBO
RCD
MCCB
SPD
MAIN_ISOLATOR
CONTACTOR
MOTOR_PROTECTION_BREAKER
OVERLOAD_RELAY
24V_POWER_SUPPLY
PLC_CPU
PLC_DI
PLC_DO
PLC_AI
PLC_AO
TERMINAL_BLOCK
VFD
SOFT_STARTER
```

A role may carry required attributes such as:

```text
poles
ratedCurrentA
ratedVoltageV
breakingCapacityKa?
tripCurve?
residualCurrentMa?
residualCurrentType?
moduleWidthUnits?
mountingType?
```

## Manufacturer catalog

```text
ManufacturerCatalog
- manufacturer
- catalogVersion
- region?
- effectiveDate?
- products[]
```

Example manufacturers may include Schneider Electric, ABB, Siemens and Legrand, but the core domain does not hardcode any brand-specific logic.

## Product variant

```text
ManufacturerProductVariant
- manufacturer
- series
- sku
- displayName
- functionalRole
- technicalAttributes
- dimensions
- moduleWidthUnits
- lifecycleStatus
- regionAvailability?
```

A product may be imported from a vendor source or created manually in a user/company catalog.

## Matching

`ManufacturerProductMatcher` receives a functional requirement and returns compatible product candidates.

```text
ProtectionRequirement
        +
ManufacturerCatalog
        ↓
compatible candidates
        ↓
engineer selection / preferred brand policy
```

The matcher must not silently substitute a product whose technical characteristics fail the engineering requirement.

## Preferred manufacturer policy

A project may optionally define preferences:

```text
preferredManufacturers[]
allowedManufacturers[]
preferredSeriesByRole{}
```

These preferences influence product ranking, not the engineering requirement itself.

## Product lifecycle

Catalog products may become obsolete or unavailable. Therefore the project must retain the selected product identity and technical snapshot used at design time.

Possible states:

```text
ACTIVE
OBSOLETE
REPLACED
UNKNOWN
```

A newer catalog version may propose replacements but must not silently rewrite an approved project.

## BOM integration

Once a concrete manufacturer product is selected:

```text
PanelGenerationProposal
→ functional device role
→ selected ManufacturerProductVariant
→ PanelAssembly placement
→ BOM
```

The BOM can then contain:

- manufacturer;
- series;
- SKU/article number;
- quantity;
- technical description;
- optional replacement candidates.

Pricing and distributor availability are future integrations and remain separate from engineering selection.

## Consequences

Positive:

- rules remain vendor-neutral;
- the same design can be regenerated for Schneider, ABB, Siemens, Legrand or another catalog;
- concrete BOM and panel layouts remain realistic;
- manufacturer migrations can be reviewed explicitly;
- obsolete product handling becomes deterministic.

Trade-offs:

- manufacturer catalog data requires maintenance and versioning;
- technical matching needs strict attribute validation;
- product-series compatibility may require vendor-specific metadata while keeping generic rules vendor-neutral.
