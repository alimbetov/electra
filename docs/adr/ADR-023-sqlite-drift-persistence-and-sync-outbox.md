# ADR-023: SQLite/Drift persistence and transactional sync outbox

## Status
Accepted

## Context

Electra must remain fully usable offline while also supporting optional project synchronization and sharing. The mobile database therefore cannot be treated as a disposable cache.

Engineering entities are relational and revision-sensitive. Geometry, routing, circuits, panels and field lifecycle records must survive application restarts and must support deterministic synchronization.

## Decision

SQLite managed with Drift is the mobile operational source of truth.

Every shareable mutation is persisted in the same SQLite transaction as a `sync_outbox` record.

```text
command
  ↓
SQLite transaction
  ├── domain mutation
  ├── revision update
  ├── dependent derived-record invalidation
  └── sync_outbox insert
COMMIT
  ↓
reactive UI update
  ↓
optional async sync
```

## Required entity metadata

Shareable mutable entities carry:

```text
id
project_id
revision
created_at
updated_at
deleted_at?
origin_device_id
```

IDs must be globally unique and suitable for offline creation. UUIDv7-compatible sortable identifiers are the preferred direction once the identifier contract is finalized.

## Outbox record

Representative `sync_outbox` fields:

```text
event_id
project_id
entity_type
entity_id
operation
base_revision
new_revision
payload
occurred_at
device_id
attempt_count
last_attempt_at?
acknowledged_at?
```

`event_id` is the server idempotency key.

## Checkpoints

Each synchronized project tracks a server checkpoint:

```text
project_id
server_checkpoint
last_successful_sync_at
```

Pull requests request changes after the latest checkpoint.

## Tombstones

Deletions of shareable data create tombstones using `deleted_at`. Physical purge occurs only after retention/synchronization policy allows it.

## Conflict handling

Conflicts are explicit records. Same-object conflicting edits to geometry, routing, circuit membership, panel layout or engineering decisions must not be silently merged.

## Consequences

Positive:
- complete offline functionality;
- deterministic recovery after restart;
- atomic sync intent;
- idempotent server processing;
- explicit conflict handling;
- no dependency on permanent connectivity.

Trade-offs:
- schema migration discipline is mandatory;
- normalization increases table count;
- conflict and tombstone retention require lifecycle management.
