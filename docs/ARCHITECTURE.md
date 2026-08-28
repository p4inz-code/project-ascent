# Project Ascent — Technical Notes

Concise engineering reference for the completed First Playable. Updated when
the actual repository state changes.

## Runtime layout

- `scenes/main_scene.tscn` — the game entry scene (`run/main_scene`). Root
  `Main` (Node2D, `scripts/main_scene.gd`) owns, in draw order: a `Backdrop`
  instance, a `Terrain` group of greybox platforms, one `Player`, the `Goal`
  Area2D, a `Vignette` CanvasLayer, and the `Hud`.
- `scenes/player.tscn` — `CharacterBody2D` player (`scripts/player.gd`) with a
  greybox `Polygon2D` body, a `CollisionShape2D`, a `Visuals` feedback node
  (`scripts/player_visuals.gd`), and a smoothed `Camera2D`. Its root is pinned to
  `z_index = 2`; see Presentation for why that number is load-bearing.
- `scenes/platform.tscn` — reusable greybox solid (`scripts/platform.gd`,
  `GreyboxPlatform`). `@tool`; set `size`/`color`/`edge_thickness`/`edge_color`
  per instance and the collider, body and lit top strip resize together. Each
  instance builds its own `RectangleShape2D` in `_ready()` so instances never
  share/clobber a collider.
- `scenes/backdrop.tscn` — the parallax sky (see Presentation).
- `scenes/hud.tscn` — controls panel, run clock, attempt counter, completion
  banner (see Presentation).

The optional `addons/godot_mcp_toolkit/` is not enabled in the public project
configuration. It remains available as local development tooling, but a fresh
clone does not start a localhost MCP runtime or require the per-user bridge
configuration.

## Presentation

Everything on screen is procedural — polygons, gradients and one shader, no
image assets. That is a deliberate staging decision for this demo: the visual
direction is coherent without introducing an art pipeline that would expand
scope. A production-art pass is intentionally outside the current milestone.

**Palette rule.** The world is cool (dark indigo → slate blue); the *only* warm
element in the game is the goal and its ledge highlight. A player who has never
seen the level can find the win condition by looking for the one amber thing.

**`scenes/backdrop.tscn`.** Four depth layers behind the play space:

- `Sky` — a `CanvasLayer` at `layer = -100` holding a full-rect `TextureRect`
  with a `GradientTexture2D`. A CanvasLayer, not a world node, so it can never
  scroll off the edge of the world no matter how far the camera travels.
- `Stars` — a `Parallax2D` (`scroll_scale` 0.06/0.03) holding a `StarField`
  (`scripts/star_field.gd`): a `MultiMeshInstance2D` whose `MultiMesh`
  (`TRANSFORM_2D`, `use_colors = true`, over a hand-built unit-quad `ArrayMesh`)
  places 430 stars in **one draw call**. Not child nodes — 430 `Polygon2D`s would
  dominate the scene's node count for something that never moves within its
  layer. And not a `_draw()` loop either: that was the first implementation, and
  `tools/probe_perf.gd` measured it issuing ~430 of the frame's ~472 draw calls,
  because `draw_circle()` is one draw command each no matter how cheap the circle
  is. 90% of the frame's draw calls for static background dressing is a real cost
  on the WebGL2 target, where per-call overhead dominates. The multimesh instance
  buffer is built once on rebuild, never per frame. Density is squared-distributed
  toward the top and alpha fades toward the horizon, so the field dissolves into
  the ridges instead of ending on a line.
- `FarRidge` / `MidRidge` / `NearRidge` — `Parallax2D` layers (`scroll_scale`
  0.10/0.26/0.48) each holding a `ParallaxRidge` (`scripts/parallax_ridge.gd`):
  an `@tool` `Polygon2D` that generates a seeded, box-smoothed skyline and skirts
  it down to `depth` so it fills the frame below. One wide non-tiling polygon per
  layer rather than a repeating one, which sidesteps `repeat_size` seams.

Ridge colours are *darker* than the platform fill on purpose. Playable geometry
must never be ambiguous with scenery, and the lit top strip on every platform
(`edge_thickness`, default 5 px) is the strongest readability cue in the game: it
says "you can land here" at a glance and separates a slab from the ridge behind
it. Walls that cannot be landed on set `edge_thickness = 0.0`.

**`shaders/vignette.gdshader`.** A `canvas_item` shader on a full-rect
`ColorRect` in the `Vignette` CanvasLayer (`layer = 50`, above the world, below
the HUD). Darkens the frame corners so the eye settles on the player. `mouse_filter = 2`
on the rect so it never eats input.

**`scripts/player_visuals.gd`** (`PlayerVisuals`) — non-authoritative feedback,
deliberately a separate node from the controller. It reads the player through its
public `is_dashing()` / `facing()` / `landed` API and only ever scales and
recolours the *visual* `Body` polygon, never the `CollisionShape2D`. A bug in
here can make the game look wrong; it cannot make the game play wrong.

- Squash on landing, scaled by impact speed, decaying over `recover_time`.
- Stretch in flight, scaled by vertical speed.
- Dash signature: the body flashes to near-white (`dash_tint`) and goes wide and
  flat, trailing a pool of afterimages.

The afterimage pool is pre-allocated in `_ready()` and reused round-robin, so
node count stays flat during play (the Performance section depends on that). Two
non-obvious properties, both regression-tested in `tests/test_presentation.gd`
because both fail *invisibly*:

- The ghosts are `z_as_relative = false`, `z_index = 1`. A *relative* `-1`
  (the first implementation) put them behind the backdrop's ridge polygons, which
  fill the lower frame at z 0 — the trail worked perfectly and was never once
  visible. The player scene root is `z_index = 2` so it still draws over its own
  trail. Terrain is z 0. Those three numbers are one contract.
- A dash covers only ~90 px, so eight un-stretched 28 px-wide images sit almost
  on top of each other and read as nothing. `ghost_stretch` (1.6) widens them
  into a single streak.

**`scenes/hud.tscn` + `scripts/hud.gd`** (`Hud`) — a `CanvasLayer` at
`layer = 100`, added as a child of `Main` (it reads `get_parent()` for `run_time`,
`attempts`, `last_run_time` and the `level_completed` signal, so it must stay a
direct child of the level root).

The controls panel is **generated from the live `InputMap`**, not from a
hand-written list of key names. This is the whole reason it is built this way: a
printed control list is the first thing to rot when a binding changes, and a
platformer that lies about its own controls is worse than one that shows none.
Each row renders the primary key, the alternate key, and the gamepad button,
resolved via `InputMap.action_get_events()` and
`OS.get_keycode_string(physical_keycode)` — physical, because the bindings are
physical and `keycode` is 0 on those events. `tests/test_presentation.gd` asserts
every row resolves to a real, bound action that renders a non-empty label, and
that every gameplay action appears somewhere in the panel.

The panel shows on start, auto-hides after `auto_hide_delay` (8 s), and toggles
on `toggle_help`. Once the player has toggled it by hand the countdown is
cancelled and their choice sticks. A small "TAB — controls" hint cross-fades in
whenever the panel is hidden, so the panel is always rediscoverable.

`Hud` is the one script in the project that implements `_process` (it polls the
level's clock and attempt count, and reads `toggle_help`).

**The clock holds the finishing time while the banner is up.** Touching the goal
respawns the player in the same frame, which zeroes `run_time` — so a clock read
straight from `run_time` blanked to `0:00.00` at the exact moment the player had
earned a time, directly above a banner announcing that time. Both numbers were
individually correct and the pair read as a bug. `_refresh_stats()` therefore
reads `last_run_time` whenever `Banner.visible`, and `tests/test_presentation.gd`
pins it. This is also why the level keeps `last_run_time` at all.

## Level geometry (greybox route)

The proving ground is a left-to-right ascent:
`Ground → P1 → P2 → P3 → P4 → LaunchPad → DashPad → TopLedge`, with the goal
sitting on `TopLedge` and `ShaftWall` closing the right edge. Only one gap
(`LaunchPad → DashPad`, 260 px) is beyond the flat running jump, so the dash is
the single skill gate; everything else is a plain jump. `tests/test_level.gd`
also guards the 70 px opening gap between the shortened spawn ground and P1, so
the first jump is part of the route rather than a flat-ground bypass. It then
enforces the geometry contracts that are easy to miss in a screenshot:

- **Standing headroom.** Any slab overhanging a landable surface must leave at
  least the body height (52 px) of clearance. Less than that and the collider
  intersects the ceiling: the player is squeezed into the floor *and the jump is
  eaten on its first frame*, so the button silently does nothing. `TopLedge`
  originally hung 46 px above `DashPad` and overlapped it — the strip the player
  lands in after the hardest jump in the level was a dead zone with the goal
  directly overhead. `TopLedge` now sits beside `DashPad` (70 px gap, 48 px rise)
  instead of over it. `P1` was likewise a slab floating 24 px above `Ground`,
  sealing an unreachable void; it remains a solid step resting on the same
  vertical surface, while the spawn ground now ends 70 px before it so the
  opening jump is intentional.
- **The goal rests on a platform.** `Goal` is a sibling of `Terrain`, so moving
  the final ledge without moving the goal leaves the win condition floating in
  mid-air. Both moves are now checked together.

**The world must not show its own edges.** `Ground`, `LeftWall` and `ShaftWall`
are sized far past the frame (`Ground` is 620 px deep, the two walls run
y −400 → 1360) rather than being trimmed to the geometry that matters. Sized to
fit, all three ended their fill mid-screen with backdrop visible beyond: the
floor read as a slab hovering over the mountains, and each wall as a grey column
stopping in the sky. Nothing about that is a gameplay bug and no assertion could
see it — it just made a finished level look unfinished in every screenshot. Two
constraints bound how far they can grow: the kill plane must stay below every
platform's bottom (`test_level` checks this, so `Ground` stops at 1360 under a
`kill_depth` of 1400), and the walls must clear the camera's highest reach at
`TopLedge`.

These three also carry a darker fill than the platforms
(`0.145, 0.161, 0.216` vs `0.212, 0.231, 0.302`). They are structural mass rather
than things you aim at, and at full-frame size the platform tone made the floor
compete with the small slabs the player is actually reading. The value still sits
well clear of the near ridge (`0.043, 0.051, 0.090`), so mass never reads as
scenery, and the walls keep `edge_thickness = 0.0` because they are not landable.

## Player controller (`scripts/player.gd`)

Precision-platformer feel via tunable `@export` values (pixels/seconds):

- Run: `max_speed` with separate ground/air accel + decel *times* (converted to
  per-frame rates), giving snappy grounded control and lighter air steering.
- Jump: height + rise/fall *times* drive derived jump velocity and asymmetric
  gravity (`h = ½gt²`), so tuning is done in intuitive units.
- Feel affordances: `coyote_time`, `jump_buffer_time`, a short
  `dash_buffer_time` at the landing refresh edge, and variable jump height
  (`jump_release_damping` trims upward velocity on early release).
- Wall movement: sliding down a wall caps fall speed at `wall_slide_speed` while
  pressing into it; a wall jump launches up and away (`wall_jump_push`,
  `wall_jump_up_scale`) with a brief `wall_jump_lock_time` so input can't cancel
  the push. Ground/coyote jumps take priority over wall jumps.
- Dash: one fixed-speed horizontal dash (`dash_speed` for `dash_time`),
  refreshed on landing. A press held in the short `dash_buffer_time` window
  before that refresh is consumed on the next grounded frame; expired inputs do
  not create a later dash. It ends early on wall contact and bleeds excess speed
  back to `max_speed` so it grants no permanent momentum.
- Emits `landed(fall_speed)` for future feedback (dust/squash/sfx).

The per-frame order is: timers → dash (owns velocity while active) → gravity →
wall slide → jump → horizontal → `move_and_slide` → landing detection.

## Level controller (`scripts/main_scene.gd`)

Remembers the player spawn, respawns on falls below `kill_depth`, and offers an
instant `restart` action. Fall-death and manual restart share one code path, and
that path also clears the player's visual state — so a new life never resumes a
dash, a squash, or a trail from the old one. A `Goal` Area2D emits
`level_completed` and loops the player back to spawn when reached.

It also owns the run state the HUD displays: `run_time` (starts on the player's
*first input*, not on scene load, so the clock does not punish reading the
controls panel), `last_run_time` (frozen at completion, because the respawn zeroes
`run_time` before the banner can read it), and `attempts`.

`level_completed` is deliberately zero-argument. Four separate consumers connect
zero-arg lambdas to it (`tests/test_loop.gd`, `tests/test_level.gd`,
`tools/probe_reach.gd`, `tools/capture_run.gd`); the finishing time is published
via `last_run_time` instead of as a signal parameter.

Completion calls the same reset path as a retry, so the player returns to spawn
and `attempts` advances to the next current attempt while the HUD banner remains
visible. This is intentional greybox loop behavior, not a results-screen system.

## Input

Actions defined in `project.godot` (keyboard + controller):

| Action      | Keyboard        | Controller            |
|-------------|-----------------|-----------------------|
| move_left   | A / Left        | Left stick X (−)      |
| move_right  | D / Right       | Left stick X (+)      |
| jump        | Space / W       | A (south button)      |
| dash        | Shift / J       | X (west button)       |
| restart     | R               | Back/Select           |
| toggle_help | Tab / F1        | Start                 |

Keys bind by **physical** keycode (layout-independent). Re-generate with
`tools/setup_input.gd` (see Validation) if actions need to change — hand-editing
the serialized `InputEvent` objects is error-prone. Close any running instance of
the game first; it holds `project.godot` open and the write will be lost.

Adding an action here is only half the job: add it to `Hud.ROWS` too, or
`tests/test_presentation.gd` will fail on "panel documents every gameplay
action". That coupling is intentional — an undiscoverable control is a bug.

## Validation

No editor required; run with Godot 4.7.2 on `PATH`, or pass the installed
executable path to the commands below. The project does not depend on a
machine-specific Godot location.

- Parse/import + boot check:
  `Godot --headless --path <proj> --quit-after 120`
- Movement/respawn regression test (exit 0 = pass):
  `Godot --headless --path <proj> --script res://tests/test_movement.gd`
- Game-feel regression test (exit 0 = pass):
  `Godot --headless --path <proj> --script res://tests/test_feel.gd`
- Gameplay-loop regression test (exit 0 = pass):
  `Godot --headless --path <proj> --script res://tests/test_loop.gd`
- Level-integrity + completability test (exit 0 = pass):
  `Godot --headless --path <proj> --script res://tests/test_level.gd`
- Presentation/HUD-truthfulness test (exit 0 = pass):
  `Godot --headless --path <proj> --script res://tests/test_presentation.gd`
- Full regression wrapper (exit 0 only when all five suites pass):
  `pwsh -File tools/run_all_tests.ps1 -GodotPath <godot-executable>`
  (`-GodotPath` can be omitted when `godot` is on `PATH`.)
- Rewrite input actions:
  `godot --headless --path <proj> --script res://tools/setup_input.gd`
- Movement-envelope measurement (tuning aid, prints numbers, always exit 0):
  `Godot --headless --path <proj> --script res://tools/probe_envelope.gd`
- Level solvability probe (per-gap reachability on the intended route):
  `Godot --headless --path <proj> --script res://tools/probe_reach.gd`
- Visual playthrough capture (needs a real window — omit `--headless`):
  `Godot --path <proj> --script res://tools/capture_run.gd`
- Frame-cost + node-count probe (needs a real window — the headless server does
  not render, so every render monitor would read zero):
  `Godot --path <proj> --script res://tools/probe_perf.gd`

`tests/test_movement.gd` drives the real physics engine and asserts on run
acceleration, jump arc, floor detection, key-binding matching, respawn, dash
(triggering / speed / momentum bleed), and wall slide + wall jump.

`tests/test_loop.gd` additionally checks that repeated goal entries emit the
completion signal, advance the attempt counter, and reset the current timer;
this protects the short demo loop from stale Area2D or state bugs.

`tests/test_feel.gd` covers the feel affordances that fail silently: fast speed
pickup, coyote time (jump fires just after leaving a real ledge, and does *not*
after the window expires), jump buffering (a press just before touchdown
auto-fires on landing), dash buffering (a near-landing press fires after the
refresh and an expired airborne press does not fire later), and variable jump
height (a full hold climbs meaningfully higher than a tap). Session 3's
rendered audit found the existing movement tuning already responsive, so no
controller values were changed; the 90%-of-cap speed guard protects the
intentionally quick pickup profile. Synthetic key presses can register a frame
late under the headless input pump, so timing-sensitive checks scan a few frames
rather than asserting on a single one.

`tests/test_presentation.gd` guards the two presentation properties a screenshot
flatters. A controls panel built from a stale list still *looks* like a controls
panel, and a dash trail hidden behind the backdrop looks exactly like a trail
that was never written — so this suite asserts on node state instead of pixels:
every panel row resolves to a real bound action and renders a non-empty key
label, every gameplay action is documented somewhere in the panel, the clock
holds at zero until first input and then runs, and the dash afterimages actually
become visible, at a legible alpha, on the right draw layer relative to both the
terrain and the player, and clear themselves on both dash-end and respawn. It
also checks that the documented Tab/F1 toggle hides and restores the controls
panel, drives the player onto the goal, and asserts the completion banner appears
with the HUD clock still showing the finishing time.

The two `probe_*.gd` tools are tuning aids (not pass/fail tests): they drive the
real physics to answer "how far can the player actually go" and "is each gap on
the route clearable". Measured envelope on flat ground: running jump ≈ 181 px
horizontal / ≈ 92 px peak rise; dash-jump ≈ 309 px horizontal. `probe_reach.gd`
walks the intended route platform-by-platform and classifies each transition as
trivial / DASH-required / unreachable (overlapping "hop up" pairs are handled
separately, since a right-run model doesn't fit them). This is how the greybox's
solvability is checked against the real controller instead of guessed. Touching
the goal counts as arrival for the last transition — the goal sits on the final
platform, so a clean final hop trips it in mid-air and the level respawns the
player, which would otherwise read as a miss.

`tests/test_loop.gd` covers the session-spanning systems that fail quietly:
goal completion (`level_completed` fires on entry and the player loops back to
spawn), the manual restart action, repeated fall-respawn staying anchored to
spawn with clean state, and the "one dash per grounding" refresh rule (an
airborne dash consumes availability, a second mid-air dash is refused, landing
refreshes it).

`tests/test_level.gd` guards the level itself: the geometry contract above
(headroom, goal resting on a platform, spawn clear of terrain with ground under
it, kill plane below everything) plus the load-bearing question — an autopilot
drives the real controller from spawn to the goal in one continuous run, holding
"run right", jumping near each lip, and spending the dash on the one gap too wide
to clear flat. It finishes in a deterministic 395 frames (6.6 s). Per-gap
probing cannot replace this: `probe_reach.gd` teleports the player to a clean
takeoff spot for every jump, so it is blind to composition failures such as
landing too close to the next edge to get a run-up, or arriving with the dash
already spent. Verified to fail (3 checks) when `TopLedge` is put back where it
was, so it is not a test that can only pass.

All five suites use real synthetic key events where bindings matter; the
autopilot and the probes drive `Input.action_press` instead, because a synthetic
`InputEventKey` can register a frame late or be dropped under the headless input
pump. That was not a theoretical concern: it made `probe_reach.gd`
non-deterministic, silently turning "ran off the edge without jumping" into a
false `UNREACHABLE` and nearly prompting a redesign of a level that was fine.

`tools/capture_run.gd` closes the gap the headless suites structurally cannot:
they prove the course is completable but render nothing, so a slab could be
mispositioned, mis-sized, or invisible and every assertion would still pass. It
*extends* `tests/test_level.gd` and reuses the same autopilot rather than copying
it — the trick is starting `_autopilot()` without awaiting it, so it suspends on
its own `physics_frame` awaits while a second coroutine grabs
`root.get_texture().get_image()` every 12th `RenderingServer.frame_post_draw`.
Frames land in `build/shots/` (git-ignored, and `.gdignore`d so they are never
re-imported), one per ~0.2 s of play, and each is logged with the player's world
position so a frame can be tied to a spot on the route. It must run *without*
`--headless`: the headless display server draws nothing, so the tool refuses
rather than writing 32 blank PNGs.

`tools/probe_perf.gd` closes the *other* gap a screenshot cannot: cost. It reuses
the same un-awaited-autopilot trick, and per rendered frame samples
`TIME_PROCESS`, `TIME_PHYSICS_PROCESS`, a wall-clock delta, and
`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, plus a full node count for the peak. It also
refuses to run headless, for the same reason `capture_run` does — the render
monitors would all read zero and the output would look like a clean bill of
health. Two of its checks are pass/fail rather than informational: node count
must not grow and must not spike mid-run. That is what turns "no per-frame
spawning" from a claim in this document into something that breaks the build.

## Web export / playtest pipeline

The game targets the browser (`gl_compatibility` renderer, single-threaded web
build), and the exported build is how the rendered frame is actually inspected.

- **Export preset:** `export_presets.cfg` defines one `Web` preset —
  single-threaded (`variant/thread_support=false`, so no SharedArrayBuffer /
  cross-origin-isolation requirement) and no GDExtension. Output goes to
  `build/web/` (git-ignored). `exclude_filter` keeps dev-only content out of the
  player payload (`addons/godot_mcp_toolkit/*`, `tests/*`, `tools/*`, `docs/*`):
  with binary-token script export the built-in GDScript exporter compiles addon
  scripts to `.gdc` *before* the toolkit's own strip plugin runs, so without the
  filter the whole addon shipped as inert dead weight. Trimming it took the
  `.pck` from 737 KB to 23 KB. The toolkit is disabled in the public project
  configuration, so excluding it is safe (verified: the trimmed build still
  boots and takes input).
- **`build/.gdignore`:** the export writes inside the project, so without this
  the engine's filesystem scanner re-imports the exported PNGs (`.import` files
  appear in `build/web/`) and those imported resources get packed into the *next*
  export — a loop that grows the `.pck` on every build. `.gitignore` tracks this
  one file (`build/*` + `!build/.gdignore`) so the guard survives a fresh clone.
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

Verified in-browser on the freshly exported build: the engine boots on WebGL2,
the greybox and HUD render, and the browser console is clean. The in-app browser
automation's synthetic keyboard injection did not move the canvas player
reliably, so this check does not claim a full browser completion run; the full
route was completed through the real controller in the native suite/capture.

## Performance

Two different measurements, because they answer two different questions.

**Web frame time.** A historical pre-presentation measurement exists below, but
it is not a current-build claim. The current browser check verified load,
rendering, input, and a clean console; browser frame timing was not sampled in
this finishing pass because the in-app preview does not provide a reliable
continuous rAF measurement surface.

| historical build | avg | median | p95 | worst | fps |
|-------|------|--------|------|-------|-----|
| greybox (pre-presentation) | 16.67 ms | 16.64 ms | 17.26 ms | 18.01 ms | 60.0 |

A historical locked-60-fps measurement with no stutter, the worst single frame
overrunning the 16.7 ms budget by 1.3 ms. **This row has not been re-measured
since the presentation layer landed, and the number above is not a claim about
the current build.** It remains here as historical context only; current-build
browser timing is intentionally left unmeasured rather than guessed at.

**Native probe.** `tools/probe_perf.gd` plays the full autopilot route in a real
window and reports percentiles plus node counts. Final v0.1.0 release run: 384
sampled frames, warm-up discarded:

| metric | avg | median | p95 | worst |
|--------|------|--------|------|-------|
| engine process frame | 25.264 ms | 16.913 ms | 71.478 ms | 71.478 ms |
| engine physics frame | 3.502 ms | 0.512 ms | 16.199 ms | 16.199 ms |
| wall frame time (vsync-locked) | 16.667 ms | 16.666 ms | 17.003 ms | 17.180 ms |
| draw calls | 42.443 | 42 | 46 | 52 |

`TIME_PROCESS` includes managed-environment scheduling outliers, while the wall
delta remains on the 16.67 ms vsync interval. The metrics that reflect the
presentation layer's cost remain healthy: draw calls stay low and node count is
flat at 107 across the route.

- **The presentation layer is one draw call per layer, not per element.** The
  star field's first implementation issued a `draw_circle()` per star, and the
  probe caught it at **~472 draw calls per frame — ~430 of them stars**. Rewriting
  `StarField` as a `MultiMeshInstance2D` took the frame to **43 draw calls, a 91%
  reduction**, with no visual change (verified against fresh `capture_run` frames).
  That is the whole reason the probe exists: the backdrop *looks* expensive, and
  the claim that it is not has to be measured, not asserted.
- **Per-frame work is scalar.** `Player._physics_process` is float math plus one
  `move_and_slide()`. No `get_node()` lookups, string building, or container
  allocation on the hot path (`Vector2` is a value type). `Main._physics_process`
  is one float compare and one input poll.
- **One render-rate script.** `Hud._process` is the only `_process` in the
  project: two `Object.get()` calls, two `String` formats and one input poll per
  drawn frame. Everything else per-draw is the engine's `Camera2D` smoothing. The
  ridges are three static polygons and `Parallax2D` scrolling is engine-side.
- **Node count is flat.** Measured across the full 395-frame route:
  `start=107 peak=107 end=107`. Ten static greybox bodies, the backdrop's four
  layers, the player (one collider, one polygon, one camera, eight pooled
  afterimages), one `Area2D` goal, and the HUD. The dash trail reuses its pool
  round-robin, so the tree never grows during play. This is asserted, not just
  described — two `probe_perf` checks fail if anything spawns per frame, which is
  a one-line regression the moment someone writes `add_child()` in a feedback path.
- **Restarts are O(1).** `_respawn()` assigns a position and clears scalars — no
  scene reload, instancing, or `queue_free`. That is what makes the "instant
  retry" goal actually instant, and it is why respawn cost cannot drift with
  level size.
- **`GreyboxPlatform` rebuilds nothing at runtime.** `_apply()` runs on property
  set and in `_ready()` only (it is an `@tool` convenience), never per frame. The
  same is true of `ParallaxRidge._rebuild()` and `StarField._rebuild()`.

## Known limitations

- Human-in-the-loop *feel* judgement (does it play well, not just render) still
  benefits from a person at the keyboard. The owner has already reported that
  the first real browser playtest felt good; the final browser check reconfirmed
  load, rendering, HUD presence, and a clean console.
- Level *solvability* is no longer a judgement call: `test_level.gd` runs the
  course end-to-end every time the suite runs, and `probe_reach.gd` reports each
  gap against the measured envelope (that is how the LaunchPad→DashPad gap was
  caught at 330 px — beyond the 309 px dash-jump — and pulled in to 260 px, and
  how the dead landing strip under `TopLedge` was found). What neither can judge
  is whether the route is *fun* or well-paced; that still needs a human playtest.
- The wall-jump mechanic (built + regression-tested) is not yet exercised on the
  critical path — `ShaftWall` is currently a right-side boundary. Turning the
  finish into a wall-jump climb is a deliberate, feel-sensitive level-design pass
  (a forced wall-jump requires the player to gain height *on* the wall, which is
  a skill gate worth tuning with a person in the loop), tracked as a next step
  rather than rushed here.
