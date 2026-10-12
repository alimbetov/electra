# Electra Technical Specification

## Product
Professional mobile planner for electrical and engineering systems.

## Platform
Cross-platform Flutter application for iOS, Android and tablets.

## Product architecture
Local-first with optional privacy-preserving cloud synchronization and sharing.

## Initial commercial focus
Electrical installation workflow first. HVAC, low-voltage, plumbing and heating are future domain modules built on the same geometry/editor foundation.

## Core editor

The editor operates as a field-oriented CAD-lite tool:

- exact room dimensions;
- walls and complex room forms;
- doors and windows;
- metric units by default;
- snap/grid and precise object placement;
- undo/redo;
- autosave;
- project/floor/room hierarchy;
- plan, ceiling, floor and wall-elevation views;
- room default/custom heights;
- point installation height;
- mounting surface independent from cable routing plane.

## Engineering objects

### Points
- sockets;
- switches;
- dimmers;
- junction boxes;
- cable outlets;
- TV/network/low-voltage points.

### Lighting
- ceiling luminaires;
- spots;
- LED strips;
- wall lights;
- tracks;
- furniture lighting.

### Equipment
- hob;
- oven;
- dishwasher;
- refrigerator;
- extractor hood;
- microwave;
- air conditioner indoor/outdoor units;
- curtain/blind motors;
- underfloor heating;
- thermostats;
- boilers;
- pumps;
- fans;
- smart relays and sensors.

Equipment definitions must be extensible and user-customizable.

## Routing

Supported route concepts include:

- ceiling;
- floor screed;
- wall/chase;
- tray;
- conduit;
- custom routing.

Route geometry is stored as explicit route segments. Cable length includes horizontal path, vertical drops/rises and configurable reserve/termination allowance.

## Room height model

```text
Project default structural/ceiling height
  -> Floor default override
    -> Room custom override
```

The effective room height is resolved by inheritance. Structural height and finished ceiling height may diverge and should remain separate concepts.

## Electrical module

- circuits;
- connected loads;
- cable sizing;
- breaker/RCD selection;
- voltage-drop and routing-aware calculations;
- electrical panel design;
- bill of materials;
- QR/label generation;
- offline PDF documentation.

Calculation rules must be versioned and isolated from UI code.

## Local data

SQLite/Drift stores structured project information. Heavy files remain in the filesystem. A user may keep hundreds or thousands of local projects; project_id acts as the logical partition key and indexes are designed around project/floor/room access patterns.

## Cloud sharing

If the user enables technical-data sharing, the backend stores a cloud representation of the technical project plus document metadata. Heavy artifacts live in S3-compatible storage.

A project QR stores an opaque share URL/token. It may resolve to:

- a live read-only project;
- an authenticated share;
- an immutable published snapshot.

Project PII sharing is controlled separately from technical documentation sharing.

## MVP vertical slice

1. Create project.
2. Create floor and room with exact dimensions.
3. Add walls/openings and room height.
4. Add sockets/switches/lights/equipment with installation height.
5. Create a circuit.
6. Route cable through ceiling/floor/wall.
7. Calculate length and basic protection/cable recommendation.
8. Generate BOM.
9. Generate labels/QR.
10. Export professional PDF.
