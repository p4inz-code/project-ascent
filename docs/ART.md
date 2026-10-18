# Art pipeline (v2)

The v2 redesign moves the game to a pixel-art look. Everything currently in
`assets/pixel/` is **generated placeholder art**: it makes the game playable and
coherent in the new style end to end, and it is meant to be replaced by final art
without touching code.

## The grid

**1 art pixel = 3 world units.** The world is still authored in 1920x1080
coordinates (so none of the 25 levels needed re-authoring), and the player
collider is 28x52 world units, so a readable character is ~11x17 art pixels.

This number lives in three places and they must agree:

| Where | What |
|---|---|
| `PlayerVisuals.ART_SCALE` | sprite scale |
| `GreyboxPlatform.ART_SCALE` | stone tile UVs |
| `PixelFilter.ART_SCALE` | the screen-space snap grid |
| `UITheme.PX` | UI border/shadow unit (same grid, UI space) |

## How the look is produced

1. **Sprites and tiles** are real pixel art, drawn with nearest-neighbour
   filtering (`player_sheet.png`, `stone_tile.png`, `logo.png`, story sprites).
2. **`PixelFilter`** (a `CanvasLayer` at layer 10) re-samples the whole world to
   the art grid and applies a 4x4 ordered dither with a reduced colour depth
   (`shaders/pixelate.gdshader`). This is what turns the still-vector terrain,
   hazards and gradient backdrops into stippled, banded pixel art. It sits below
   the HUD (100), death flash (120) and pause menu (200), so UI stays crisp.
3. **`UITheme`** draws all menu chrome as hard-edged pixel boxes: square corners,
   `PX`-thick borders, a hard offset drop shadow, no anti-aliasing.

A real 640x360 viewport was rejected: it would have forced a rebuild of every UI
screen and bought little over the snap-and-dither pass.

## Regenerating

```
python tools/gen_pixel_art.py
```

Deterministic (fixed seeds): same output every run. Needs Pillow.

## Replacing placeholder art with final art

Drop in files with the same names and cell sizes:

- `player_sheet.png` + `player_sheet.json` — one row per animation, `cell` is the
  frame size in art pixels (currently 18x20, feet on row 18). Animation names are
  chosen by `PlayerVisuals._pick_animation()`: `idle run jump fall land slide wall
  dash dead`. The suit ramp is recoloured by `shaders/palette_swap.gdshader`, so
  final art must keep the suit in the two source colours (`src_suit`, `src_shade`)
  for the player-colour setting to keep working.
- `stone_tile.png` — 16x16, **grayscale**: it is multiplied by each level theme's
  platform colour, so one tile serves all five acts.
- `logo.png`, `rocket.png`, `rift.png`, `door.png`, `orb.png` — any size; the
  title and cutscene scale them by whole numbers only.

## Rules of thumb

- Never scale a sprite non-uniformly. Stretched pixels are the quickest way to
  break the look (squash/stretch was removed from the player for this reason).
- Scale by whole numbers only.
- Keep one outline colour (`#0b162e`) for sprites so they read against any act.
