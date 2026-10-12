# Editor Foundation Scope

## Goal

Turn `feat/platform-foundation` into the first product skeleton while deliberately postponing engineering calculations.

## First user flow

```text
Projects
  -> Create Project
  -> Project Rooms
  -> Create Room
  -> Room Editor
      -> architecture/features
      -> discipline layer selection
      -> routing/editor tools
      -> Calculations placeholder
      -> Reports placeholder
```

## Project form

Initial fields:

- project name (required);
- optional reference/code;
- measurement system (`METRIC` or `IMPERIAL`);
- default structural room height;
- default finished ceiling height.

## Room form

Initial fields:

- room name;
- room type;
- width/depth for the first rectangular-room creation path;
- optional room-specific structural height override;
- optional finished ceiling height override.

The rectangular form is only a fast-start workflow. The spatial model remains polygonal/piecewise-planar and must not be constrained to rectangular rooms.

## Room editor

The first editor shell exposes:

- active surface/patch identity;
- project measurement system;
- discipline layer selector;
- Select / Point / Route / Measure / Architectural Feature tools;
- edge-driven navigation hints;
- surface-bound architectural features (`Door`, `Window`, `Beam`, `Column`, `Niche`, `Shaft`, `Opening`, `Custom`);
- object/room inspector area;
- Calculations and Reports entry points.

## Calculations

The Calculations screen exists in the navigation model but intentionally performs no engineering calculations in this phase. It defines future categories such as route length, cable sizing, protection, ventilation/hydraulic calculations and validation results.

## Reports

The Reports screen exists as a product surface but does not generate final engineering documents yet. It reserves report types such as project summary, room plan, routes, BOM, labels/QR and published package.

## Acceptance for this phase

- source scaffold for Flutter application exists;
- user can navigate Project list -> Create Project -> Rooms -> Create Room -> Room Editor in the prototype state model;
- metric/imperial preference is represented;
- doors/windows/beams/etc. appear as editor feature choices;
- Calculations and Reports are visible but explicitly marked deferred;
- no fake engineering result is produced.
