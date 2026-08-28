# Project Ascent — Technical Notes

Concise engineering reference. Updated as systems land.

## Runtime layout

- `scenes/main_scene.tscn` — the game entry scene (`run/main_scene`). Root
  `Main` (Node2D, `scripts/main_scene.gd`) owns a `Terrain` group of greybox
  platforms and one `Player` instance.
- `scenes/player.tscn` — `CharacterBody2D` player (`scripts/player.gd`) with a
  greybox `Polygon2D` body, a `CollisionShape2D`, and a smoothed `Camera2D`.
- `scenes/platform.tscn` — reusable greybox solid (`scripts/platform.gd`,
  `GreyboxPlatform`). `@tool`; set `size`/`color` per instance and the collider
  and visual resize together. Each instance builds its own `RectangleShape2D` in
  `_ready()` so instances never share/clobber a collider.

## Player controller (`scripts/player.gd`)

Precision-platformer feel via tunable `@export` values (pixels/seconds):

- Run: `max_speed` with separate ground/air accel + decel *times* (converted to
  per-frame rates), giving snappy grounded control and lighter air steering.
- Jump: height + rise/fall *times* drive derived jump velocity and asymmetric
  gravity (`h = ½gt²`), so tuning is done in intuitive units.
- Feel affordances: `coyote_time`, `jump_buffer_time`, and variable jump height
  (`jump_release_damping` trims upward velocity on early release).
- Emits `landed(fall_speed)` for future feedback (dust/squash/sfx).

## Level controller (`scripts/main_scene.gd`)

Remembers the player spawn, respawns on falls below `kill_depth`, and offers an
instant `restart` action. Fall-death and manual restart share one code path.

## Input

Actions defined in `project.godot` (keyboard + controller):

| Action      | Keyboard        | Controller            |
|-------------|-----------------|-----------------------|
| move_left   | A / Left        | Left stick X (−)      |
| move_right  | D / Right       | Left stick X (+)      |
| jump        | Space / W       | A (south button)      |
| dash        | Shift / J       | X (west button)       |
| restart     | R               | Back/Select           |

Keys bind by **physical** keycode (layout-independent). Re-generate with
`tools/setup_input.gd` (see Validation) if actions need to change — hand-editing
the serialized `InputEvent` objects is error-prone.

## Validation

No editor required; the Godot binary lives at
`F:/PROJECT ASCENT/Godot_v4.7.2-stable_win64_console.exe`.

- Parse/import + boot check:
  `Godot --headless --path <proj> --quit-after 120`
- Movement/respawn regression test (exit 0 = pass):
  `Godot --headless --path <proj> --script res://tests/test_movement.gd`
- Rewrite input actions:
  `Godot --headless --path <proj> --script res://tools/setup_input.gd`

`tests/test_movement.gd` drives the real physics engine and asserts on run
acceleration, jump arc, floor detection, key-binding matching, and respawn.

## Known limitations

- Visual/on-screen playtesting in the current automation environment is limited
  to headless boot (no errors) plus the behavioral test; no human-in-the-loop
  visual pass has been done on the rendered frame yet.
