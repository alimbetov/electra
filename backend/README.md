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
sharing
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
- project sharing via QR/share tokens
- published project snapshots
- document metadata
- object-storage access
- collaboration and permissions
- audit trail

## Non-responsibilities

The backend must not be required for geometry editing, routing calculations, electrical calculations, labels or PDF generation needed for offline use.
