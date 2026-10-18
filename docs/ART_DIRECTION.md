# Project ascent: locked art direction

## 1. Final art direction: "neon ascent"

Dark futuristic precision platformer. Clean vector/procedural art. No pixel art.
The visual identity is defined by:

- Dark backgrounds with atmospheric depth (gradient skies, parallax ridges, stars)
- Clean geometric platforms with bright edge highlights for readability
- Cyan/blue player as the focal point against dark environments
- Amber/gold goals as clear visual targets
- Red enemies (boss/minions) as danger signals
- Minimal decoration: every visual element serves gameplay

The game should look like a polished indie precision platformer, not a greybox prototype
or an asset-flip. The existing procedural art is the foundation. We enhance it,
not replace it.

## 2. Player visual style

- Shape: Stylized silhouette (polygon-based, not sprite-based)
- Color: Cyan blue (#6CC4E8) body with white visor
- States: Idle (breathing bob), Run (lean + step bob), Fall (lean), Wall-slide (pressed flat), Dash (stretch + afterimages)
- Afterimages: Cyan ghost trail during dash (pool of 8)
- Readability: Player must be visible against ALL level backgrounds
- No sprites for now: The polygon player reads cleanly at all zoom levels

## 3. Platform/Environment style

- Body: Dark slate blue (varies per level theme)
- Edge: Bright edge highlight on top face (the "landing surface" cue)
- Edge color: Brighter than body, typically cool blue/cyan for playable surfaces
- Wall-jump surfaces: Same dark walls, no edge highlight (indicates "not a landing surface")
- Ground platforms: Darker, solid, grounding
- Size variation: Platforms range from 80px to 220px wide; narrower = harder

## 4. Background style

- Sky: Procedural gradient (4 color stops, top-to-bottom)
- Stars: Procedural multimesh star field (one draw call)
- Ridges: 3-layer parallax procedural ridges (far/mid/near)
- Per-level palettes: Each level has unique sky/ridge/star colors
- No image backgrounds: The procedural system is lightweight and consistent

## 5. Hazard style

- Kill depth: Invisible death plane below the level
- Pits: Dark wall pairs creating visual "wells" (atmospheric, not mechanical hazards)
- No spikes/moving hazards in Levels 1-5: Keep it clean
- Danger communicated through: platform spacing, height, and (in L5) boss/minions

## 6. Goal/Exit style

- Amber/gold color (#FFD478)
- Pulsing glow effect (subtle, 0.03→0.12 alpha)
- Core: Bright inner rectangle
- Outer: Semi-transparent glow rectangle
- Position: Always sits on the TopLedge platform
- Readability: Must be the brightest object in the scene

## 7. Boss style (level 5)

- Body: Dark red silhouette with shoulders (imposing, not cute)
- Inner core: Darker red detail
- Eyes: Bright yellow-orange with white glow core
- Aura: Pulsing red danger indicator
- Shadow: Subtle dark shadow underneath
- Size: ~60x70px (larger than player's 28x52px)

## 8. Minion style (level 5)

- Body: Smaller angular shape (40x40px)
- Color: Darker red than boss
- Eyes: Orange with glow
- Shadow: Subtle
- Distinct from boss: Smaller, angular, no shoulders

## 9. UI/HUD style

- Font: Default Godot font (clean, readable at all sizes)
- Color scheme: Cool blue text on dark semi-transparent panels
- Timer: Large (30px), top-right, cool white
- Attempts: Smaller (15px), below timer, muted blue
- Level name: Top-left (18px), muted blue
- Controls panel: Bottom-left, dark panel with grid layout
- Completion banner: Large amber text (58px), center screen
- Pause menu: Centered panel, dark background, amber title
- Cyberpunk assets: Available for future HUD upgrades but NOT used in current vertical slice

## 10. Color progression (levels 1-5)

| Level | Sky Top | Sky Bottom | Ridge | Stars | Platform | Edge | Mood |
|---|---|---|---|---|---|---|---|
| 1 | Deep indigo | Slate blue | Dark blue-grey | Cool white | Slate | Cyan | Welcoming |
| 2 | Deep indigo | Slate blue | Dark blue-grey | Cool white | Slate | Cyan | Building |
| 3 | Dark blue | Slate blue | Dark blue | Cool white | Slate | Cyan | Focused |
| 4 | Dark blue | Warm slate | Dark warm | Warm white | Warm slate | Cyan | Tense |
| 5 | Deep purple | Dark rose | Dark purple | Warm pink | Dark rose | Cyan | Dangerous |

## 11. Lighting/Glow rules

- Player: Self-illuminated (cyan body is always visible)
- Goal: Pulsing amber glow (the brightest object)
- Boss eyes: Glowing yellow
- Platform edges: Subtle bright edge (readability cue)
- No dynamic lighting: Everything is flat/polygon-based for performance
- Vignette: Subtle screen-edge darkening for atmosphere

## 12. Scale/Pixel-Density rules

- Player: 28x52px collision, ~30px visual
- Platforms: 80-220px wide, 20-36px tall
- Walls: 40px wide, variable height
- Boss: ~60x70px
- Minions: ~40x40px
- Goal: 56x96px collision, visual extends with glow
- No pixel art sprites: All visuals are vector/polygon-based

## 13. Animation rules

- Player: Procedural (squash/stretch, lean, bob). No frame animation
- Boss/Minions: Procedural (facing, eye glow pulse)
- Goal: Procedural (glow pulse)
- Transitions: Tween-based (fade, scale, modulate)
- No sprite sheets needed: Everything is code-driven

## 14. Level-to-Level visual progression (25 levels)

### ACT I: levels 1-5: foundation
- Clean, readable, welcoming → progressively darker
- Level 5: danger-tinted (dark rose/purple)

### ACT II: levels 6-10: mastery
- Brighter skies, more environmental contrast
- Mechanical/structural elements introduced
- Level 10: dramatic chase arena lighting

### ACT III: levels 11-15: challenge
- Darker, more hostile palettes
- Orange/amber hazard lighting
- Level 15: trap-lit, mechanical danger

### ACT IV: levels 16-20: ordeal
- Storm/night palettes
- Deep indigo/purple skies
- Lightning-flash effects (procedural)
- Level 20: destruction-themed

### ACT V: levels 21-25: apex
- Final escalation: dawn breaking through storm
- Level 25: golden dawn: triumphant
- Visual journey from darkness to light

## 15. Asset integration rules

**USED from Cyberpunk pack:**
- Font file (available for future HUD upgrades)
- UI number sprites (available for future timer upgrades)

**NOT USED (yet):**
- Frame sprites, bars, buttons, cursors, skill icons
- These are pixel art (32x32) and clash with the vector art direction

**NOT USED from other packs:**
- Graveyard backgrounds (wrong theme)
- Cloud backgrounds (procedural sky is better)
- Vampire backgrounds (wrong resolution and style)

**Rule**: If an asset doesn't match the "Neon Ascent" vector aesthetic, it stays unused.
