# Electra Backend

Spring Boot modular monolith for cloud capabilities that cannot or should not be required for offline engineering work.

## Planned stack

- Java 21+
- Spring Boot
- Spring Security / OIDC
- PostgreSQL
- Liquibase
- REST/JSON
- S3-compatible object storage
- Docker

## Modules

```text
auth
subscription
project-sync
project-query
sharing
publication
reporting
pricing
documents
storage
collaboration
audit
```

## Backend responsibilities

- authentication and devices
- subscription / entitlements
- optional technical project synchronization
- revision and conflict tracking
- idempotent sync processing
- project sharing via QR/share tokens
- immutable published project snapshots
- server-side report jobs from published snapshots
- PDF/report document metadata
- BOM/estimate publication metadata
- optional price books and manufacturer/SKU mapping
- object-storage access
- collaboration and permissions
- audit trail

## Non-responsibilities

The backend must not be required for geometry editing, routing calculations, electrical calculations, panel generation, labels or normal engineering work.

Local offline PDF export remains a mobile capability. Server-side PDF/report generation is an additional publication/delivery path used for immutable snapshots, QR sharing and centralized document storage.

## Publication principle

Reports are generated from immutable published snapshots rather than from a moving live project.

```text
Working Project
  -> synchronize if enabled
  -> publish immutable snapshot
  -> report job
  -> PDF / schedules / BOM / estimate
  -> S3-compatible storage
  -> QR/share token delivery
```

Each published document records the project snapshot, ruleset versions, manufacturer catalog versions, price-book version/date when applicable, and report-template version so the delivered document can be reproduced and audited.
