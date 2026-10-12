# ADR-011: Engineering Drafting Visual Language

## Status
Accepted

## Context

The room editor must behave and look like a professional engineering drafting workspace. Photorealistic interiors, decorative textures, scenic backgrounds and lifestyle imagery add visual noise, reduce contrast for measurements and routes, and are not useful to the engineer while editing.

The preferred visual baseline is a dry technical drawing of room surfaces, openings, structural features, equipment, routes, dimensions and annotations.

## Decision

Electra uses an engineering-drafting visual language for the room editor.

The primary canvas is a neutral technical surface, not a rendered room photograph.

### Required canvas characteristics

- white or very light neutral drafting background;
- subtle metric/imperial grid controlled by project display units;
- thin architectural linework for walls, floor, ceiling, openings and structural features;
- clear dimension lines, extension lines, elevation markers and labels;
- engineering symbols for sockets, switches, luminaires, panels, motors, pumps, sensors and other equipment;
- routes rendered as simplified technical polylines with line style and labels;
- selected objects use a clear accent outline/handles;
- adjacent surfaces may be shown through linework/folded preview without material textures;
- visual hierarchy must remain legible when exported or printed in monochrome.

### Explicit non-goals

The editing canvas must not use:

- photorealistic wall/floor/ceiling textures;
- decorative furniture or scenery unless imported intentionally as reference geometry;
- sky, city views or environmental backgrounds;
- lighting/shadow rendering intended for visualization rather than engineering interpretation;
- visual effects that obscure dimensions, snap points, routes or object symbols.

A future presentation/export mode may support richer visualization, but it is separate from the engineering editing mode.

## Visual hierarchy

Recommended hierarchy:

```text
1. Active selection / active route
2. Engineering objects and routes
3. Dimensions and snap guides
4. Architectural geometry
5. Grid / reference guides
6. Inactive context
```

The canvas should use color sparingly. Engineering meaning must not rely on color alone.

## Surface representation

Wall, ceiling and floor views use the same drafting language.

Examples:

```text
Wall A
  -> boundary linework
  -> Window opening
  -> Door opening
  -> Beam / soffit projection
  -> sockets / switches / equipment
  -> route segments
  -> dimensions / elevations

Ceiling
  -> ceiling patch boundaries
  -> luminaires
  -> ducts / trays / cable routes
  -> beams / soffits
  -> transition edges

Floor
  -> floor patch boundaries
  -> steps / platforms / shafts
  -> floor boxes / equipment footprints
  -> underfloor routes where visible
```

## Contextual UI compatibility

This visual language works together with ADR-010. The canvas remains visually quiet while contextual controls appear only for the active tool or selection.

The persistent shell should never compete visually with the drawing itself.

## Mobile and tablet

The same drafting model is used on phone and tablet. Compact layouts may reduce annotation density, but they must not switch to a photorealistic representation.

## Acceptance criteria

The editor visual baseline is accepted when:

- an engineer can identify wall/floor/ceiling geometry without textures;
- dimensions and elevations remain readable at normal working zoom;
- a selected object is immediately distinguishable from unselected geometry;
- route paths remain understandable in color and monochrome;
- openings and structural features are visually clear;
- the drawing remains usable on tablet and phone;
- the UI contains no decorative scene imagery in normal engineering editing mode.
