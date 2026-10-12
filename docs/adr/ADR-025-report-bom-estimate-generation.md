# ADR-025: Deterministic PDF, BOM and estimate generation

## Status
Accepted

## Context

Electra must generate useful customer and engineering documentation from the same engineering model used for design. Reports must include drawings and schedules without becoming detached manual documents. BOM quantities must come from engineering data, while commercial prices may vary independently.

The same project may need both local offline export and server-generated published documents delivered through QR sharing.

## Decision

Use a canonical report model generated from an immutable project snapshot.

```text
PublishedProjectSnapshot
       ↓
ReportAssembler
       ↓
ReportModel
       ├── project summary
       ├── floor routing drawings
       ├── room drawings
       ├── circuit schedules
       ├── panel schedules
       ├── DIN rail layouts
       ├── single-line diagrams
       ├── terminal plans
       ├── I/O schedules
       ├── cable schedules
       ├── BOM
       ├── estimate
       ├── issues / validation
       └── engineering decisions
       ↓
PDF Renderer
       ↓
Document artifact
```

## Quantity takeoff

Quantities are derived from engineering objects:

```text
Equipment / routes / panels / supports / terminals
                 ↓
QuantityTakeoff
                 ↓
BOM
```

A BOM line must retain its source references so every aggregate quantity can drill down to floor, room and engineering object.

## Estimate

Pricing is a separate layer:

```text
BOM
 ↓
Manufacturer/SKU mapping where available
 ↓
PriceBook
 ↓
Estimate
```

Representative estimate data:

```text
item code
manufacturer / SKU?
quantity
unit
unit material price?
material total?
installation rate?
installation total?
price source
price book version
price date
```

Changing prices does not alter engineering geometry or circuit logic.

## Drawings

Generated drawings use the same dry engineering visual language as the editor:

- floor routing maps;
- room plans / surface drawings;
- routing junction details;
- panel front/DIN layouts;
- simplified single-line diagrams;
- terminal and I/O schedules.

## Determinism

A generated report records:

```text
snapshot_id
snapshot_content_hash
ruleset_versions
manufacturer_catalog_versions
price_book_version/date
report_template_version
```

The same inputs must produce equivalent engineering content.

## Local and server rendering

Electra supports two paths:

### Local export
Useful when offline. The mobile application assembles a report from the local project/snapshot and renders a PDF locally.

### Published server export
The backend renders from an immutable published snapshot and stores the PDF in S3-compatible object storage for QR delivery.

The server path is not required for normal engineering work.

## Consequences

Positive:
- project model and documentation remain synchronized;
- BOM is traceable to engineering sources;
- estimates can be refreshed without redrawing the project;
- published PDFs are stable and auditable;
- QR delivery is straightforward.

Trade-offs:
- canonical report model and renderer require versioning;
- drawing generation needs deterministic layout algorithms;
- local and server rendering must be contract-tested for equivalent content.
