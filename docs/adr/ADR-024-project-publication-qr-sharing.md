# ADR-024: Project publication, immutable snapshots and QR sharing

## Status
Accepted

## Context

Electra projects are edited locally first and may later be synchronized to the backend. A QR code should allow a customer, installer or reviewer to access a project report without embedding the entire project in the QR code and without exposing the mutable working project directly.

## Decision

Separate three concepts:

```text
Working Project
Live Shared Project
Published Project Snapshot
```

### Working project
The editable local project and its synchronized cloud replica.

### Live share
An authorized view of the current synchronized project for collaboration use cases.

### Published snapshot
An immutable version used for customer delivery, reports and QR access.

Publication flow:

```text
Working Project
   ↓ validate publish scope
Canonical Project Snapshot
   ↓ freeze content
PublishedProjectSnapshot
   ↓
Report jobs / documents
   ↓
Share record
   ↓
Opaque QR token
```

## Snapshot requirements

A published snapshot records at least:

```text
snapshot_id
project_id
project_revision
content_hash
created_at
created_by
ruleset_versions
manufacturer_catalog_versions
price_book_version?
report_template_version?
```

The snapshot cannot be modified after creation.

## Share token

The QR code contains only an opaque URL/token. It does not embed engineering data.

Share configuration may contain:

```text
snapshot_id
permissions
expires_at?
password_required?
download_allowed
revoked_at?
```

The share must be revocable.

## Public delivery page

A resolved QR share may expose:

- project title and revision;
- report preview/download;
- floor/room report navigation;
- drawings;
- BOM/estimate when allowed;
- validation/report metadata.

Client PII remains governed by a separate sharing policy.

## Consequences

Positive:
- reports are reproducible;
- customer QR links do not drift when the working project changes;
- links can be revoked or expired;
- published documentation is auditable.

Trade-offs:
- publication creates additional immutable data/storage;
- new project edits require a new publication when documentation must change.
