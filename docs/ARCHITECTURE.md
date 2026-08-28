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
- Wall movement: sliding down a wall caps fall speed at `wall_slide_speed` while
  pressing into it; a wall jump launches up and away (`wall_jump_push`,
  `wall_jump_up_scale`) with a brief `wall_jump_lock_time` so input can't cancel
  the push. Ground/coyote jumps take priority over wall jumps.
- Dash: one fixed-speed horizontal dash (`dash_speed` for `dash_time`),
  refreshed on landing. Ends early on wall contact and bleeds excess speed back
  to `max_speed` so it grants no permanent momentum.
- Emits `landed(fall_speed)` for future feedback (dust/squash/sfx).

The per-frame order is: timers → dash (owns velocity while active) → gravity →
wall slide → jump → horizontal → `move_and_slide` → landing detection.

## Level controller (`scripts/main_scene.gd`)

Remembers the player spawn, respawns on falls below `kill_depth`, and offers an
instant `restart` action. Fall-death and manual restart share one code path. A
`Goal` Area2D emits `level_completed` and loops the player back to spawn when
reached (greybox completion; real feedback/UI is a later milestone).

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
- Game-feel regression test (exit 0 = pass):
  `Godot --headless --path <proj> --script res://tests/test_feel.gd`
- Rewrite input actions:
  `Godot --headless --path <proj> --script res://tools/setup_input.gd`

`tests/test_movement.gd` drives the real physics engine and asserts on run
acceleration, jump arc, floor detection, key-binding matching, respawn, dash
(triggering / speed / momentum bleed), and wall slide + wall jump.

`tests/test_feel.gd` covers the feel affordances that fail silently: coyote
time (jump fires just after leaving a real ledge, and does *not* after the
window expires), jump buffering (a press just before touchdown auto-fires on
landing), and variable jump height (a full hold climbs meaningfully higher than
a tap). Synthetic key presses can register a frame late under the headless
input pump, so the timing-sensitive checks scan a few frames rather than
asserting on a single one.

## Web export / playtest pipeline

The game targets the browser (`gl_compatibility` renderer, single-threaded web
build), and the exported build is how the rendered frame is actually inspected.

- **Export preset:** `export_presets.cfg` defines one `Web` preset —
  single-threaded (`variant/thread_support=false`, so no SharedArrayBuffer /
  cross-origin-isolation requirement) and no GDExtension. Output goes to
  `build/web/` (git-ignored).
- **Export templates:** the matching version's web templates must live in
  `%APPDATA%/Godot/export_templates/4.7.2.stable/` (`web_nothreads_*.zip` etc.).
  They are not bundled with the engine binary; install once from the official
  `Godot_v<ver>-stable_export_templates.tpz` release asset (extract the
  `templates/web*` files + `version.txt` into that folder).
- **Export:**
  `Godot --headless --path <proj> --export-debug "Web" build/web/index.html`
  A textless "completed with warnings" notice is emitted by the headless editor
  filesystem scan and is benign; a complete build is `index.{html,js,wasm,pck}`
  plus audio worklets.
- **Serve + preview:** `tools/serve_web.py [port]` (default 8060) serves
  `build/web/` with the correct `application/wasm` MIME type and COOP/COEP
  headers. `.claude/launch.json` wires this to the preview tooling under the
  name `web`.

Verified in-browser: the engine boots on WebGL2, the greybox renders, and
keyboard input drives the player (confirmed by running into the left wall). Two
classes of console noise are expected and benign on the Compatibility renderer
over WebGL2: a one-frame `Framebuffer is incomplete: Attachment has zero size`
at startup (canvas not yet sized) and repeated `bindBuffer ... different
target` / `bufferSubData: no buffer` `INVALID_OPERATION` warnings. Neither
affects rendering.

## Known limitations

- Human-in-the-loop *feel* judgement (does it play well, not just render) still
  benefits from a person at the keyboard; automated browser input confirms the
  controls respond but not that the tuning feels good.
- Level *solvability* (that the greybox layout is beatable and fun) is not
  automatically verified — the tests prove each mechanic works, not that the
  course is well-tuned. Needs a human playtest.
