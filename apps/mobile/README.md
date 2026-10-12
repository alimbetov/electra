# Electra Mobile

Flutter application for iOS, Android and tablets.

## Foundation status

`feat/platform-foundation` now contains the first source-level product skeleton. It intentionally uses in-memory draft state before Drift persistence is introduced.

Current flow:

```text
Projects
  -> Create Project
  -> Rooms
  -> Create Room
  -> Room Editor
      -> surface navigation shell
      -> discipline selector
      -> architectural feature selector
      -> Calculations (deferred)
      -> Reports (deferred)
```

## Planned stack

- Flutter / Dart
- Riverpod (state migration after domain contracts stabilize)
- go_router (routing migration after first flow stabilizes)
- SQLite + Drift
- CustomPainter
- InteractiveViewer initially, custom viewport abstraction as editor complexity grows
- vector_math

## Editor model

The preferred navigation model is edge-driven rather than a separate Plan/Wall/Ceiling/Floor navigator. Named views may remain shortcuts or export views.

The user edits one active `SurfacePatch`. Approaching/tapping a valid edge reveals or activates an adjacent patch. During route drawing the same action creates a `SURFACE_TRANSITION` and continues the route.

Surface-bound construction objects include doors, windows, technical openings, beams, columns, soffits, niches, shafts, steps, platforms, recesses and protrusions.

## Units

All persisted geometry is canonical millimetres. Project preferences control metric/imperial input and display only.

## Current deliberate limitations

- no Drift persistence yet;
- no engineering calculations yet;
- no final PDF/report generation yet;
- edge proximity/fold animation is documented but not implemented in the initial canvas shell;
- geometry kernel and exact `SurfacePatch` topology are the next implementation gate.
