# Electra Architecture

Electra is a local-first engineering application for field professionals.

## Core principles

1. Mobile-first and offline-first.
2. SQLite/Drift is the local operational source of truth.
3. Backend is used for authentication, subscriptions, synchronization, sharing, collaboration and cloud backup.
4. Engineering calculations must not depend on network availability.
5. The graphical editor is 2D, but the engineering model is height-aware (2.5D / x-y-z aware).
6. Heavy files are stored outside the relational database and referenced by metadata.
7. The system starts as a modular monolith, not microservices.

## High-level structure

```text
Flutter Mobile
    |
    +-- UI / Editor
    +-- SQLite / Drift
    +-- Sync Outbox
    |
    +--> Pure Dart Engineering Core
          +-- Geometry
          +-- Routing
          +-- Electrical Rules
          +-- Equipment
          +-- BOM
          +-- Labels
          +-- Document Models

Optional Network
    |
    v
Spring Boot Backend
    |
    +-- PostgreSQL
    +-- Object Storage (S3-compatible)
    +-- Auth / Subscription
    +-- Project Sync
    +-- Sharing / QR
    +-- Collaboration / Audit
```

## Project hierarchy

```text
Project
  -> Floor
    -> Room
      -> Wall
      -> Opening
      -> PointItem / EquipmentItem
      -> Route / RouteSegment
```

A room has an effective height resolved from project/floor defaults and an optional room override.

## Editor views

The same room model can be presented using multiple engineering views:

- Plan
- Ceiling
- Floor
- Wall elevation

These are views over the same domain objects, not duplicated project data.
