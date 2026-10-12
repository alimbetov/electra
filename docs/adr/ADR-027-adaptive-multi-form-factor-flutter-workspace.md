# ADR-027: Adaptive Multi-Form-Factor Flutter Workspace

## Status
Accepted

## Context

Electra is a local-first engineering application that must remain useful on phones, tablets and desktop operating systems. The product must not become three separate applications with divergent workflows or data models.

The engineering domain, commands, persistence model and project files must remain identical across form factors. What changes is workspace composition, interaction density and input affordance.

A phone is best for field capture and focused operations. A tablet is the primary engineering workstation in the field. Desktop is best for large project review, routing, panel layout, reporting and dense editing.

## Decision

Electra uses one Flutter application with one domain model and one local SQLite/Drift project model across mobile, tablet and desktop.

The UX strategy is:

```text
Tablet-first engineering workspace
        +
Desktop-enhanced productivity
        +
Mobile field-optimized compact UX
```

The UI adapts to available window width and input capabilities rather than relying only on platform or device-class detection.

## Adaptive size classes

Initial application size classes:

```text
COMPACT   < 700 logical px
MEDIUM    700..1099 logical px
EXPANDED  >= 1100 logical px
```

These thresholds are product defaults and may be calibrated after usability testing. Layout code must consume a semantic size class rather than scattering raw breakpoint values throughout feature widgets.

## Compact workspace

Typical targets:

- phones;
- narrow desktop windows;
- split-screen tablet windows.

Composition:

```text
Canvas / primary content
+ bottom navigation or compact workspace switcher
+ tool bar / floating tool palette
+ contextual bottom sheet
```

Compact mode prioritizes:

- measurements;
- field issue capture;
- equipment placement;
- installation/test status;
- QR/document viewing;
- focused room edits;
- simple routing operations.

Dense multi-panel editing is intentionally reduced.

## Medium workspace

Typical target: tablets and medium-width windows.

Composition:

```text
Tool Rail | Engineering Canvas | Context Panel
```

Medium is the principal field-engineering layout and must fully support:

- Room Editor;
- Floor Routing;
- equipment placement;
- cable routing;
- junction editing;
- Panel Builder;
- installation;
- commissioning.

Only one primary context panel is normally visible at a time.

## Expanded workspace

Typical targets:

- Windows;
- macOS;
- Linux;
- very large tablets / external monitors.

Composition may expand to:

```text
Project Navigator | Tool Rail | Engineering Canvas | Inspector
```

Expanded mode may expose secondary information simultaneously when it materially improves productivity, for example:

- project/floor/room tree;
- layer tree;
- selected-object inspector;
- validation/issues;
- panel circuit list;
- BOM/estimate preview.

Expanded mode must still follow progressive disclosure and must not become a permanently overloaded CAD interface.

## Shared workspace model

All form factors use the same logical workspaces:

```text
Projects
Room
Floor Routing
Panels
Installation
Commissioning
Reports
```

A workspace owns commands and context semantics. Layout composition is adaptive.

Example:

```text
Route command
  phone   -> compact toolbar + bottom sheet
  tablet  -> tool rail + context panel
  desktop -> tool rail + inspector + shortcuts
```

The command and domain operation are the same.

## Input model

Electra supports multiple input modalities.

### Touch

- tap selection;
- drag placement;
- pinch zoom;
- two-finger pan where appropriate;
- large touch targets;
- contextual sheets rather than hover-only affordances.

### Mouse / trackpad

- wheel/trackpad zoom;
- pan;
- hover feedback;
- context menus;
- precise point placement;
- drag selection / multi-select where appropriate.

### Keyboard

Desktop and hardware-keyboard use must support an explicit shortcut layer. Initial expected commands include:

```text
Ctrl/Cmd+Z           Undo
Ctrl/Cmd+Shift+Z     Redo
Delete/Backspace     Delete selection
Escape               Cancel active command
Enter                Confirm active command
Space + pointer      Pan canvas
```

Additional shortcuts are assigned by command registry rather than hardcoded independently in feature widgets.

## Responsive principles

1. Adapt composition, not just dimensions.
2. Never maintain separate mobile and desktop domain models.
3. Never fork persistence schemas by platform.
4. Commands remain platform-neutral.
5. Canvas coordinates and engineering geometry are identical across form factors.
6. Selection and active tool state survive reasonable layout changes and window resizing.
7. Phone layouts must not expose controls that require hover.
8. Desktop layouts must not waste keyboard/mouse productivity by emulating a stretched phone UI.

## Primary platform roles

### Mobile

Optimized for field operations and quick edits.

### Tablet

Primary engineering workstation and reference UX for editor workflows.

### Desktop

Enhanced workspace for complex routing, panel layout, large projects, bulk editing, reports and documentation.

## Persistence and project portability

A project created on any supported form factor uses the same persisted model.

```text
Electra project model
      ↓
SQLite / Drift
      ↓
Android / iOS / Windows / macOS / Linux
```

Future cloud synchronization operates on the same project entities and must not translate between mobile and desktop schemas.

## Acceptance criteria

A feature is not considered complete if it works only on one form factor without an explicit adaptive behavior.

For core engineering workspaces, acceptance should cover at least:

- compact layout;
- medium/tablet layout;
- expanded/desktop layout;
- touch interaction where applicable;
- mouse/keyboard interaction where applicable;
- window resize without loss of canonical project state.

## Consequences

Positive:

- one engineering product instead of three divergent applications;
- shared local persistence and project portability;
- tablet remains first-class rather than an enlarged phone;
- desktop receives professional productivity affordances;
- mobile remains useful for field work without forcing dense CAD layouts onto small screens.

Trade-offs:

- feature UI must be designed adaptively from the start;
- automated layout and interaction testing becomes more important;
- some workspaces require structurally different compositions across size classes.