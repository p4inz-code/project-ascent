# Project Ascent — Final Demo Report

Date: 2026-08-28

## Starting State

The repository was on `main`, based on `origin/main`, with five pre-existing
uncommitted files from the previous presentation pass: `docs/ARCHITECTURE.md`,
`scenes/main_scene.tscn`, `scripts/hud.gd`, `tests/test_presentation.gd`, and
`tools/capture_run.gd`. The game already had the M1/M2 movement kit, a
completable greybox route, procedural star/parallax presentation, a working local
web build, and regression tooling. `README.md` still described an earlier
milestone and no authoritative session handoff or final report existed.

## Changes Made

- Validated and checkpointed the inherited completion-feedback/level-framing
  polish as `c902d71`.
- Confirmed the inherited HUD fix keeps the finishing time visible while the
  completion banner is shown after the immediate respawn.
- Confirmed the inherited geometry changes keep the route completable and give
  the structural floor/walls full-frame coverage within the level constraints.
- Updated `README.md` from active-development milestone language to the actual
  completed First Playable state.
- Updated `docs/ARCHITECTURE.md` to remove stale next-step/performance/browser
  claims, document the intentional completion→next-attempt behavior, and record
  the finishing-pass native performance probe.
- Corrected stale scope comments in `scripts/main_scene.gd` and
  `scripts/player.gd` so source documentation matches the implemented M1/M2
  controller and completion loop.
- Created `docs/SESSION_HANDOFF.md` as the authoritative continuation document.
- Created this final report.

No new gameplay feature or visual system was added during the finishing pass.

## Bugs Found

The main reproduced issue was the completion HUD truthfulness case already
present in the inherited working tree: goal entry records a finishing time and
immediately resets `run_time`, so a HUD that reads only `run_time` displays
`0:00.00` beside a completion banner showing a non-zero time. The fix was already
implemented before takeover and was validated here.

The level framing issue addressed by the inherited working tree was also
confirmed visually: the structural ground/wall geometry needed to extend beyond
the camera frame so it did not appear to end in mid-screen. The geometry changes
were validated by the level integrity tests and fresh rendered capture.

No additional runtime defect was reproduced in movement, jump timing, wall
interaction, dash, landing, respawn, restart, goal entry, HUD timing, or browser
loading during this session. The apparent `ATTEMPT 2` during a completion banner
is intentional: goal completion starts the next attempt immediately while the
banner preserves the previous run's time.

## Visual Improvements

The validated presentation now includes:

- cool indigo/slate sky with depth from a single-draw star field and three
  parallax ridge layers;
- readable platform top-edge highlights and a darker structural floor/wall tone;
- a bright cyan player that remains legible against the background;
- amber-only goal and final ledge accents for clear visual hierarchy;
- restrained vignette, landing squash, flight stretch, dash tint, and dash ghosts;
- a compact InputMap-driven controls panel, timer, attempt counter, and completion
  banner with the finishing time.

The current visual direction was preserved. No final-art pipeline or unnecessary
decorative system was introduced.

## Gameplay Improvements

The current validated game loop includes responsive acceleration/deceleration,
air control, derived jump physics, coyote time, jump buffering, variable jump
height, wall slide, wall jump with input lockout, a single air dash with landing
refresh and momentum handling, fall/manual restart, goal completion, and the
completion→respawn loop.

The route remains compact and the dash is the only large-gap skill gate. The
wall-jump mechanic is implemented and tested but remains off the critical path.

## Testing Results

Final headless boot and all five suites exited 0. The final suite run produced 74
PASS assertions and 0 failures:

| Suite | Assertions | Result |
|---|---:|---|
| `test_movement.gd` | 28 | pass |
| `test_feel.gd` | 4 | pass |
| `test_loop.gd` | 11 | pass |
| `test_level.gd` | 7 | pass |
| `test_presentation.gd` | 24 | pass |

Covered behavior includes input bindings, movement, acceleration/deceleration,
jump arc, coyote, buffering, variable height, wall slide, wall jump, dash,
landing impact, respawn, restart, goal signal, completion loop, live HUD binding
labels, clock start, dash trail visibility/clearing, and finishing-time display.

Supporting probes passed:

- flat running jump envelope: approximately 181 px horizontal and 92 px rise;
- dash jump envelope: approximately 309 px horizontal;
- route reachability: every transition clear, with only `LaunchPad → DashPad`
  classified as dash-required;
- continuous route completion: 395 physics frames;
- rendered capture: 39 frames, including the completion banner;
- native performance: 376 samples, 108 start/peak/end nodes, approximately 43.3
  average draw calls, and a vsync-locked wall frame average of 16.668 ms.

## Browser Playtest Results

The freshly exported build was served from `http://127.0.0.1:8060/` and opened in
the in-app browser. The canvas rendered correctly, the HUD controls panel
appeared and auto-hid, Tab rediscovered it, keyboard input started the run clock,
and movement/jump input visibly affected the game. The browser console contained
no warning or error entries during the check.

The full route was verified in the headless gameplay suite and real-window
autopilot/capture. This session did not claim a complete manual browser clear;
that distinction is intentional and recorded in the handoff.

## HTML5 Status

Fresh export succeeded with the installed Godot 4.7.2 templates:

```text
Godot --headless --path . --export-debug "Web" build/web/index.html
EXIT 0
```

The Web preset remains single-threaded, Compatibility-renderer based, and
excludes development-only addon/tests/tools/docs content. The local server
continues to provide the correct WASM MIME type and development headers.

## Architecture Audit

The controller, level root, reusable platform, visual feedback, HUD, backdrop,
scenes, tests, and tools have clear responsibilities. No duplicated gameplay
logic, dead runtime path, fragile new reference, or per-frame node spawning was
found. The player visual system remains non-authoritative, the HUD remains a
direct child of the level root, and the star field remains a one-draw MultiMesh.

The only source-level changes in this pass beyond the inherited checkpoint were
documentation comments. No architecture rewrite was warranted.

## Documentation Created/Updated

- `README.md` — current First Playable status and links.
- `docs/ARCHITECTURE.md` — actual runtime, validation, web, performance, and
  limitation state.
- `docs/SESSION_HANDOFF.md` — authoritative future-agent continuation guide.
- `docs/FINAL_DEMO_REPORT.md` — this report.

## Git Commits

- `c902d71 polish: preserve completion feedback and frame the level`
- final documentation checkpoint: contains the README/source-comment accuracy
  updates and `SESSION_HANDOFF.md`.
- final report checkpoint: contains this report.

The final state is intended to be pushed to `origin/main` after the last clean
status/diff review.

## Known Limitations

- The project has one short greybox route and no audio or authored art assets.
- Wall jump is built and tested but not required on the critical path.
- Browser frame timing was not re-measured; the browser load/input/console check
  and native rendered performance probe were completed.
- Godot commands in the managed environment may print global user-directory and
  MCP registry permission warnings; these are environmental and do not fail the
  project tests or web build.

## Exact Current State

Project Ascent is a small, playable, visually coherent First Playable. It boots,
passes the full regression suite, completes the intended route, renders a clean
completion payoff, exports to HTML5, and runs in the local browser preview. The
working tree should be clean after the final documentation commits.

## Recommended Next Milestone

Stop here for this objective. If the project resumes later, make a human-led
creative decision about a small authored-art/audio pass or a deliberately tuned
wall-jump section before adding systems. Do not expand feature scope by default.
