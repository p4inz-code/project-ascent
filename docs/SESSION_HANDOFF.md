# Project Ascent — Session Handoff

Authoritative continuation document for the current First Playable. This file
describes the repository as validated on 2026-08-28. Reconcile it against the
actual files and git history before making new changes.

## Project Vision

Project Ascent is an offline-first, browser-first 2D precision platformer built
around responsive movement, fast retries, readable traversal, atmospheric
presentation, and strong game feel. The current goal is a small, credible First
Playable demo—not a feature-complete game or a production-art pipeline.

## Current First Playable

The game currently launches into one procedural greybox proving ground. It is
completable from spawn with running, jumping, coyote time, jump buffering,
variable jump height, wall slide, wall jump, and one air dash. The intended route
is regression-tested end to end and rendered in a real window. The goal is an
amber Area2D on the final ledge; touching it records the run, shows a completion
banner with the finishing time, and immediately returns the player to spawn for
the next attempt.

Presentation is procedural: a cool indigo-to-slate sky, stars, parallax ridges,
lit platform tops, a readable cyan player, an amber goal, a subtle vignette,
dash afterimages, a generated controls panel, a timer, and an attempt counter.

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Move left/right | A/D or Left/Right | Left stick X |
| Jump | Space or W | A / south button |
| Dash | Shift or J | X / west button |
| Restart | R | Back / Select |
| Show/hide controls | Tab or F1 | Start |

Bindings are stored in `project.godot` by physical keycode. If they need to be
regenerated, run `tools/setup_input.gd` with no game instance open.

## Current Gameplay Mechanics

- Horizontal movement uses a max speed with separate ground/air acceleration
  and deceleration timing.
- Jump velocity and asymmetric rising/falling gravity are derived from the
  exported jump height and timing values.
- Coyote time allows a jump shortly after walking off a ledge.
- Jump buffering remembers a press shortly before landing.
- Releasing jump early trims upward velocity for variable jump height.
- Wall slide caps downward speed while airborne and pressing into a wall.
- Wall jump launches away from the contacted wall and briefly locks horizontal
  input so the launch cannot be cancelled immediately.
- Dash is horizontal, fixed-speed, time-limited, and available once per flight.
  It refreshes on landing, ends on wall contact, and bleeds back to normal speed.
- Landing emits the pre-collision impact speed for visual feedback.
- Player visuals are separate from authoritative movement: landing squash,
  flight stretch, dash tint, and a fixed pool of dash afterimages.

## Gameplay Flow

1. The scene loads at spawn with the controls panel visible. The timer remains
   at `0:00.00` until the player gives movement/jump/dash input.
2. The player traverses the left-to-right route and may restart instantly with R.
3. Falling below `kill_depth` respawns at the saved spawn point, clears movement
   and visual transient state, resets the current timer, and increments attempts.
4. Touching the goal records `last_run_time`, emits `level_completed`, displays
   the completion banner, and uses the same reset path to start the next attempt.
5. While the banner is visible, the HUD clock intentionally shows the finishing
   time instead of the newly reset `run_time`. When the banner fades, the new
   attempt is back at zero until input starts it.

## Visual Direction

Preserve the current simple, cool, atmospheric presentation. Playable terrain is
slate with bright cool top edges; the player is cyan; the goal and final ledge
are the only warm amber elements. Stars and three parallax ridge layers provide
depth without image assets. Keep hierarchy, contrast, spacing, and platform
readability ahead of decorative detail.

Do not replace the aesthetic, add a large art system, or introduce final-art
production work during this milestone. The procedural visuals are an intentional
demo staging choice.

## Scene Structure

- `scenes/main_scene.tscn` — entry scene and level root. Owns backdrop, terrain,
  player, goal, vignette, and HUD.
- `scenes/player.tscn` — `CharacterBody2D` with body polygon, collider, visual
  feedback node, and smoothed camera.
- `scenes/platform.tscn` — reusable `GreyboxPlatform` static body whose visual,
  top edge, and unique runtime collider follow `size` and color properties.
- `scenes/backdrop.tscn` — CanvasLayer sky, MultiMesh star field, and three
  procedural parallax ridge polygons.
- `scenes/hud.tscn` — CanvasLayer controls panel, stats, hint, and completion
  banner.

## Code Architecture

- `scripts/player.gd` owns movement state and physics only. Its public feedback
  API is `is_dashing()`, `facing()`, `landed`, and `reset_state()`.
- `scripts/main_scene.gd` owns spawn, fall/manual restart, timer state, attempts,
  and goal completion.
- `scripts/platform.gd` is the `@tool` geometry/collider synchronizer.
- `scripts/player_visuals.gd` owns non-authoritative squash, stretch, dash tint,
  and pooled ghosts. It never changes the collision shape.
- `scripts/hud.gd` builds its controls panel from the live `InputMap`, polls the
  level clock/attempt state, and presents completion feedback.
- `scripts/star_field.gd` builds one MultiMesh draw for the stars.
- `scripts/parallax_ridge.gd` generates seeded skyline polygons in the editor or
  at runtime.
- `shaders/vignette.gdshader` provides the restrained edge vignette.

## Testing

Run from `F:\PROJECT ASCENT\project-ascent` with
`F:\PROJECT ASCENT\Godot_v4.7.2-stable_win64_console.exe`:

```text
Godot --headless --path . --quit-after 120
Godot --headless --path . --script res://tests/test_movement.gd
Godot --headless --path . --script res://tests/test_feel.gd
Godot --headless --path . --script res://tests/test_loop.gd
Godot --headless --path . --script res://tests/test_level.gd
Godot --headless --path . --script res://tests/test_presentation.gd
```

Expected finishing-pass results: all commands exit 0 with 74 PASS assertions and
0 failures in total (movement 28, feel 4, loop 11, level 7, presentation 24).
The presentation/HUD checks include live bindings, dash ghosts, clock start, and
completion-banner finishing-time truthfulness.

Additional probes:

```text
Godot --headless --path . --script res://tools/probe_envelope.gd
Godot --headless --path . --script res://tools/probe_reach.gd
Godot --path . --script res://tools/capture_run.gd
Godot --path . --script res://tools/probe_perf.gd
```

The measured envelope is approximately 181 px for a running jump and 309 px
with a dash. The intended route completes in 395 physics frames. The finishing
pass capture produced 39 frames; the real-window performance probe sampled 376
frames, held node count at 108, and reported about 43 average draw calls.

## HTML5/Web Workflow

1. Ensure matching Godot 4.7.2 web export templates are installed at
   `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
2. Export the configured `Web` preset:

   ```text
   Godot --headless --path . --export-debug "Web" build/web/index.html
   ```

3. Start the local static server:

   ```text
   python tools/serve_web.py 8060
   ```

   The server serves `build/web`, supplies `application/wasm`, and adds the
   local COOP/COEP headers. `.claude/launch.json` contains the same `web` entry.
4. Open `http://127.0.0.1:8060/` in the browser preview. Verify the canvas,
   controls panel, timer, movement response, and browser console.

The export preset is single-threaded, uses the Compatibility renderer, excludes
the MCP addon/tests/tools/docs from the shipped payload, and writes only to the
ignored `build/web` directory. `build/.gdignore` prevents the export from being
re-imported into the next export.

## Current Repository State

The game repository is `F:\PROJECT ASCENT\project-ascent`. Important tracked
content is under `scenes/`, `scripts/`, `tests/`, `tools/`, `shaders/`, and
`docs/`. `addons/godot_mcp_toolkit` is development tooling and is excluded from
the web export. Generated `.godot/`, `build/web/`, and `build/shots/` content is
ignored except for `build/.gdignore`.

## Git History

Recent checkpoints, newest first:

- `c902d71` — preserve completion feedback and frame the level.
- `99a0fc8` — reduce the star field to one draw call.
- `77d1d8c` — add parallax backdrop, dash feedback, and InputMap HUD.
- `3a49480` — update README for the validated First Playable.
- `785da57` — capture the autopilot playthrough to PNGs.
- `d614e48` — remove dead landing strips and regression-test completability.
- `dd3132e` — record web timing and performance audit findings.
- `9075d40` — trim development tooling from the web payload.

The documentation checkpoint that adds this handoff and the final report should
remain a separate coherent commit after validation.

## Completed Milestones

- M1 core movement and level loop: run, acceleration/deceleration, air control,
  jump physics, coyote, buffer, variable height, spawn, respawn, restart, and
  greybox terrain.
- M2 advanced movement and goal: wall slide, wall jump, lockout, air dash, dash
  refresh, momentum handling, goal Area2D, and completion/restart loop.
- Hardening: movement, feel, loop, level, and presentation regression suites;
  headless boot; route reachability; rendered capture; and native performance
  probe.
- Presentation pass: parallax ridge backdrop, star field, vignette, readable
  platform edges, dash ghosts, InputMap-driven HUD, completion banner, and
  finishing-time clock preservation.
- HTML5 pipeline: 4.7.2 templates, Web preset, local server, fresh export, and
  browser render/input verification.

## Known Issues

- Godot runs in this managed environment emit global log/MCP registry permission
  warnings because the sandbox cannot write the normal user data directories.
  They are outside the project and do not fail the game tests or web runtime.
- The wall-jump mechanic is implemented and tested but is not on the critical
  path; the right-side wall is currently a boundary around the final ledge.
- Browser frame timing was not re-measured in this pass. Native rendered timing
  and the full route were verified instead.

## Intentional Limitations

There is one short route and one goal. There are no accounts, backend, online
services, monetization, saves, settings, inventory, multiplayer, procedural
level generation, audio system, final-art pipeline, or large menu system. The
completion loop is a lightweight banner plus respawn, not a results screen.

## Decisions Already Made

- Preserve the procedural cool palette and amber-only goal accent.
- Keep the current greybox route compact and deterministic.
- Keep the dash as the single large-gap skill gate.
- Keep the HUD generated from the live InputMap.
- Keep `last_run_time` so the completion banner and clock agree after respawn.
- Keep restart and fall-death on one O(1) reset path that clears transient state.
- Keep pooled dash afterimages and the MultiMesh star field for flat node count and
  low draw-call cost.
- Keep the Web export single-threaded and dev-tool-free.

## Do Not Change Without Reason

Do not casually change movement tunables, jump timing, coyote/buffer behavior,
wall-jump lockout, dash availability, spawn/kill geometry, the goal placement,
platform top-edge contrast, player/ghost z ordering, the HUD InputMap generation,
the clock/banner relationship, the Web preset, or `build/.gdignore`. Any change
to these must be reproduced, regression-tested, and playtested in a rendered
window/browser before it is kept.

## Next Recommended Work

Stop at this milestone. If development resumes, the highest-value next work is a
human-led creative decision about whether to add a small amount of authored art,
audio, or a deliberately designed wall-jump section. Do not start that work by
adding systems or expanding the feature list.

## Fresh-Agent Startup Procedure

1. Read this document completely.
2. Inspect `git status`, `git log --oneline -10`, and the current diff.
3. Inspect the relevant repository files: `README.md`, `project.godot`,
   `export_presets.cfg`, `scenes/`, `scripts/`, `tests/`, `tools/`, and
   `docs/ARCHITECTURE.md`.
4. Run the five regression suites and the headless boot check.
5. Run the game in a real window and, when relevant, export and open the HTML5
   build through `tools/serve_web.py`.
6. Reconcile this handoff against the actual repository state and current git
   history; do not blindly trust old notes.
7. Continue only from the documented next milestone, and preserve the scope
   limits above.
