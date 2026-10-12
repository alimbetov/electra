# Electra Mobile

Flutter application for iOS, Android and tablets.

## Planned stack

- Flutter / Dart
- Riverpod
- go_router
- SQLite + Drift
- CustomPainter
- InteractiveViewer initially, custom viewport abstraction as editor complexity grows
- vector_math

## Responsibilities

- project catalog
- room/floor editor
- plan / ceiling / floor / wall-elevation views
- local persistence
- autosave
- undo/redo
- engineering object inspectors
- offline PDF and QR generation
- sync orchestration

## Editor rule

The UI is 2D, but persisted engineering objects are height-aware. Screen coordinates must never be persisted as domain coordinates. Canonical geometric dimensions are stored in millimetres.
