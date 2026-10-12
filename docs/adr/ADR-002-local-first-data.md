# ADR-002: Local-First Data Architecture

## Status
Accepted

## Decision
Electra stores the working project locally first. SQLite/Drift is the mobile operational source of truth. Cloud synchronization is optional and asynchronous.

## Local data

Structured project data:

- Project
- Floor
- Room
- Wall
- Opening
- PointItem
- EquipmentItem
- Circuit
- Route
- RouteSegment
- ElectricalPanel
- PanelComponent
- Material / BOM
- SyncOutbox

Heavy artifacts are stored in the device filesystem and referenced by metadata:

- photos
- imported PDFs
- generated PDFs
- scans
- exported archives

## Synchronization

Writes are committed locally together with an outbox record in the same SQLite transaction.

```text
User edit
  -> SQLite transaction
      -> domain row change
      -> sync_outbox insert
  -> immediate UI update
  -> background sync when network is available
```

Cloud synchronization is project-scoped and revision-aware.

## Privacy

Technical project data may be synchronized only when enabled by the user. Client PII remains local by default and must have an explicit independent sharing policy.

## Sharing

A shared project QR contains an opaque share token or URL, not project data. The backend resolves the share token to an authorized live project or immutable published snapshot.
