# Project Ascent — Session Handoff

Authoritative continuation document for the frozen First Playable. This file
describes the repository as independently audited on 2026-08-28. Reconcile it
against the actual files and git history before making any future changes.

## Project Vision

Project Ascent is an offline-first, browser-first 2D precision platformer built
around responsive movement, fast retries, readable traversal, atmospheric
presentation, and strong game feel. The current goal is a small, credible First
Playable demo—not a feature-complete game or a production-art pipeline.

## Current First Playable

The game currently launches into one procedural greybox proving ground. It is
completable from spawn with running, jumping, coyote time, jump buffering,
variable jump height, wall slide, wall jump, and one air dash. Dash input has a
short landing buffer so a press just before touchdown can use the refreshed dash.
The intended route starts with a deliberate opening gap before S1_1, is
regression-tested end to end, and is rendered in a real window. The goal is an amber Area2D on the
final ledge; touching it records the run, shows a completion
banner with the finishing time, and immediately returns the player to spawn for
the next attempt.

S2–S7 is complete. The project is frozen at this compact demo milestone; future
work requires a deliberate decision to reopen the freeze.

The repository is prepared for a v0.1.0 public-release checkpoint. The tracked
per-user `.mcp.json` bridge configuration was removed; the optional development
addon and its template remain available. No root project license has been
selected, and GitHub visibility still requires an owner-side setting change.

Presentation is procedural: a cool indigo-to-slate sky, stars, parallax ridges,
lit platform tops, a readable cyan player (a stylized standing silhouette with a
cool ice-white visor), an amber goal, a subtle vignette, dash afterimages, a
generated controls panel, a timer, and an attempt counter.

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
  It refreshes on landing, accepts a short `dash_buffer_time` input window at
  that refresh edge, ends on wall contact, and bleeds back to normal speed.
- Landing emits the pre-collision impact speed for visual feedback.
- Player visuals are separate from authoritative movement: landing squash,
  flight stretch, dash tint, and a fixed pool of dash afterimages. The body also
  gets a lightweight presentation pose (idle breathing bob, run step-bob and
  lean, fall lean, wall-slide flatten) and flips to face movement direction;
  the visor accent stays cool ice-white, never amber.

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
slate with bright cool top edges; the player is cyan with a cool ice-white visor
accent (the only warm element remains the amber goal); the goal and final ledge
are the only warm amber elements. Stars and three parallax ridge layers provide
depth without image assets. Keep hierarchy, contrast, spacing, and platform
readability ahead of decorative detail.

Do not replace the aesthetic, add a large art system, or introduce final-art
production work during this milestone. The procedural visuals are an intentional
demo staging choice.

## Scene Structure

- `scenes/main_scene.tscn` — entry scene and level root. Owns backdrop, terrain,
  player, goal, vignette, and HUD.
- `scenes/player.tscn` — `CharacterBody2D` with a stylized character silhouette
  (Polygon2D `Body` plus a `Visor` accent child), collider, visual feedback node,
  and smoothed camera.
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
  the pooled ghosts, facing flip, and the presentation pose states
  (idle/run/fall/wall-slide). It never changes the collision shape.
- `scripts/hud.gd` builds its controls panel from the live `InputMap`, polls the
  level clock/attempt state, and presents completion feedback.
- `scripts/star_field.gd` builds one MultiMesh draw for the stars.
- `scripts/parallax_ridge.gd` generates seeded skyline polygons in the editor or
  at runtime.
- `shaders/vignette.gdshader` provides the restrained edge vignette.

## Testing

Run from the repository root with Godot 4.7.2 on `PATH`, or pass the full path
to the installed Godot 4.7.2 executable:

```text
Godot --headless --path . --quit-after 120
Godot --headless --path . --script res://tests/test_movement.gd
Godot --headless --path . --script res://tests/test_feel.gd
Godot --headless --path . --script res://tests/test_loop.gd
Godot --headless --path . --script res://tests/test_level.gd
Godot --headless --path . --script res://tests/test_presentation.gd
# Or run all five suites through the project-local wrapper. Omit -GodotPath
# when the executable is already on PATH.
pwsh -File tools/run_all_tests.ps1 -GodotPath "C:\path\to\Godot_v4.7.2-stable_console.exe"
```

Expected current results: all commands exit 0 with 85 PASS assertions and 0
failures in total (movement 28, feel 7, loop 15, level 8, presentation 27).
The presentation/HUD checks include live bindings, dash ghosts, clock start, and
completion-banner finishing-time truthfulness.

Session 1 additionally verifies that a dash pressed just before landing fires
after the refresh, while an expired airborne dash press does not fire later.

Additional probes:

```text
Godot --headless --path . --script res://tools/probe_envelope.gd
Godot --headless --path . --script res://tools/probe_reach.gd
Godot --path . --script res://tools/capture_run.gd
Godot --path . --script res://tools/probe_perf.gd
```

The measured envelope is approximately 181 px for a running jump and 309 px
with a dash. The thirteen-platform route completes in 633 physics frames. The
real-window performance probe sampled 622 frames, held node count flat at 163,
and reported 42.6 average draw calls with a 16.666 ms wall-frame average.

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

## Windows Standalone Distribution

A reproducible Windows x86_64 standalone build is configured so the First
Playable can be shared as a self-contained program that runs without the Godot
editor, the repository, or any development tooling.

1. Ensure the matching Godot 4.7.2 **Windows** export templates are installed
   alongside the web templates in
   `%APPDATA%\Godot\export_templates\4.7.2.stable\` (files
   `windows_release_x86_64.exe`, `windows_debug_x86_64.exe`, and their console
   variants).
2. The committed `Windows Desktop` preset in `export_presets.cfg` exports to
   `build/windows/ProjectAscent.exe` plus `ProjectAscent.pck` (external PCK),
   x86_64, Compatibility renderer, with the same exclude filter as the Web
   preset (MCP addon, tests, tools, docs omitted).
3. Rebuild everything reproducibly with:

   ```text
   powershell -ExecutionPolicy Bypass -File tools/build_release.ps1 -Godot "C:\path\to\Godot_v4.7.2-stable_console.exe"
   ```

   The script exports the Windows standalone and the HTML5 build, then packages
   `dist/Project-Ascent-v0.1.0-Windows.zip`. It never hard-codes the Godot path:
   it resolves `-Godot`, then `$env:GODOT_BIN`, then `godot`/`godot.exe` on
   `PATH`. `build/` and `dist/` are git-ignored, so the artifacts are never
   committed.

The distribution ZIP contains only `ProjectAscent.exe`, `ProjectAscent.pck`, and
a player-facing `README.txt` (tracked as `PLAYER_README.txt` in the repo). The
archive was validated end-to-end this session: extracted to a clean folder
outside the repository, launched the real EXE, and confirmed it ran with no
errors and no dependency on any repository-relative file. Both `ProjectAscent.exe`
and `ProjectAscent.pck` must stay side by side, because the EXE loads the
external PCK.

## Current Repository State

The repository root is the directory containing `project.godot`. Important
tracked content is under `scenes/`, `scripts/`, `tests/`, `tools/`, `shaders/`,
and `docs/`. `addons/godot_mcp_toolkit` is optional development tooling,
disabled in the public project configuration and excluded from the web and
Windows exports. Generated `.godot/`, `build/`, and `dist/` content is ignored
except for `build/.gdignore`.

## Git History

Recent checkpoints, newest first:

- `95a6872` — add the reproducible `tools/build_release.ps1` build script and the
  tracked player-facing `PLAYER_README.txt` for the standalone distribution.
- `a30484a` — add the `Windows Desktop` export preset (x86_64, external PCK) for
  the v0.1.0 standalone build.
- `584a537` — record final v0.1.0 release metrics and refreshed presentation
  captures.
- `1e4d003` — prepare public v0.1.0 onboarding, release notes, security policy,
  screenshots, and portable documentation.
- `df07f20` — remove the machine-local MCP bridge configuration and make the
  test wrapper portable.
- `dabc05a` — cover repeated completion state and add the all-tests wrapper.
- `a5f282f` — guard controls discovery flow and first-time HUD UX.
- `b1e6d52` — record the Session 4 visual audit.
- `ae36d9a` — protect fast movement pickup with a feel regression.
- `20e1125` — record the Session 2 route checkpoint and current test totals.
- `3f84b60` — make the opening jump intentional and guard its route spacing.
- `aabe03d` — record the Godot tool evaluation and selection decision.
- `597a740` — buffer dash input through landing and add feel regressions.

- `c902d71` — preserve completion feedback and frame the level.
- `99a0fc8` — reduce the star field to one draw call.
- `77d1d8c` — add parallax backdrop, dash feedback, and InputMap HUD.
- `3a49480` — update README for the validated First Playable.
- `785da57` — capture the autopilot playthrough to PNGs.
- `d614e48` — remove dead landing strips and regression-test completability.
- `dd3132e` — record web timing and performance audit findings.
- `9075d40` — trim development tooling from the web payload.

The final freeze documentation checkpoint is kept as a separate coherent commit
after validation.

The public-release preparation commits sit above the S7 freeze. The annotated
`v0.1.0` release tag, when present, is the release checkpoint for this frozen
source state; inspect it with `git show v0.1.0`.

## Independently Verified State (post-release re-audit)

A clean re-audit of the v0.1.0 source state with Godot 4.7.2.stable produced
the following live measurements, all of which reconcile against this document
and the rest of the tracked docs:

- Git: branch `main`, working tree clean, 9 commits ahead of `origin/main`
  (the public-release preparation layer and the standalone-build work). `origin`
  is `https://github.com/p4inz-code/project-ascent.git`. At the time of this
  re-audit the `v0.1.0` git tag and GitHub release did not yet exist; they were
  created in the subsequent public-release pass (see below).
- Test suites: 85 PASS / 0 FAIL across the five suites
  (`test_movement` 28, `test_feel` 7, `test_loop` 15, `test_level` 8,
  `test_presentation` 27). The total is 85, not the previously documented 84,
  because the `time formats as m:ss.cc` HUD-format assertion in
  `test_presentation.gd` was already present in commit `77d1d8c` but the
  documented 84 was never updated to include it. This is a documentation drift,
  not a test or code change — all four documents have been reconciled.
- Headless boot: `Godot --headless --path . --quit-after 60` exits 0.
- Route reachability (`tools/probe_reach.gd`): the thirteen-platform route is
  classified transition-by-transition, with wider gaps between later platforms
  requiring dashes; the controller drives the route to the goal.
- Fresh HTML5 export: re-exported with the local Godot 4.7.2 binary against
  the committed `Web` preset. The exclude filter continues to strip
  `addons/godot_mcp_toolkit/*`, `tests/*`, `tools/*`, and `docs/*`. The
  shipped `index.pck` is approximately 50 KB and the bundled `index.wasm` is
  approximately 36 MB; the preset is single-threaded and dev-tool-free as
  documented. The 23 KB pck figure quoted in the architecture notes was a
  snapshot from the first export-trim pass (commit `9075d40`); the current
  measurement reflects all runtime content shipped since.
- Release dist artifact: `dist/Project-Ascent-v0.1.0-web.zip` is present at
  the documented 10,374,057 bytes (SHA-256
  `7BF3FF63857C2F224DFAEA90CEB4899F0A697D22EC7DD2D4B4C2360D9D4B2887`) and
  remains ignored from source.
- Windows standalone build: the Windows export templates were installed (the
  default template set only shipped web templates), the `Windows Desktop` preset
  was added, and the reproducible `tools/build_release.ps1` produced
  `build/windows/ProjectAscent.exe` (109,168,640 bytes) plus
  `ProjectAscent.pck` (50,356 bytes) and packaged
  `dist/Project-Ascent-v0.1.0-Windows.zip` (38,089,989 bytes, SHA-256
  `CBD8D465EDEB6AEAC95619B19932524D6D54649AE7AEE5B3B82ECE326F46F42C`). The ZIP
  contains only the EXE, the PCK, and a player `README.txt`. The EXE was
  launched **from a clean extracted folder outside the repository** and ran with
  no errors and no dependency on the Godot editor, the repository, or any
  development tooling. A string scan of the packaged PCK found no secrets, no
  local filesystem paths, and no dev-tooling markers.
- Test suites after the standalone work: the full five-suite regression still
  passes 85 / 0, and the headless boot still exits 0, so the added export preset
  and build script did not perturb the frozen gameplay.
- Local filesystem paths: no tracked file under `docs/`, `README.md`, or
  `SECURITY.md` references the original development machine path. The MCP
  autoload, `[editor_plugins]` enable, and `[mcp_toolkit]` section are all
  absent from the public `project.godot`, and `.mcp.json` is git-ignored.
- Tests not re-run in this session: `tools/capture_run.gd` and
  `tools/probe_perf.gd` (both require a real window and are not safe to drive
  in a non-interactive shell); the previously recorded native numbers in
  `ARCHITECTURE.md` → Performance remain the source of truth for those.

## Public GitHub Release (v0.1.0)

The public release is complete and was verified end to end from the actual
uploaded GitHub asset:

- Repository: **public** at `https://github.com/p4inz-code/project-ascent`.
- Tag: annotated `v0.1.0` pushed to `origin` (points at commit `34b63be`).
- Release: `Project Ascent v0.1.0 — First Playable`
  (`https://github.com/p4inz-code/project-ascent/releases/tag/v0.1.0`), published
  (not draft/prerelease), with the single asset
  `Project-Ascent-v0.1.0-Windows.zip`.
- Asset: `dist/Project-Ascent-v0.1.0-Windows.zip`, 38,089,989 bytes, SHA-256
  `CBD8D465EDEB6AEAC95619B19932524D6D54649AE7AEE5B3B82ECE326F46F42C`. The
  uploaded asset was re-downloaded from GitHub and its hash matched exactly.
- Stranger flow verified: the GitHub asset was downloaded, extracted to a
  directory **outside the repo**, and `ProjectAscent.exe` launched and ran with
  the game window open and no errors, with no Godot/repository/development
  dependency.
- All validated commits are pushed to `origin/main` (working tree clean).
- License: **none selected** — the owner must still choose a root license before
  the project can be represented as open source. No license was invented.

## Completed Milestones

- M1 core movement and level loop: run, acceleration/deceleration, air control,
  jump physics, coyote, buffer, variable height, spawn, respawn, restart, and
  greybox terrain.
- M2 advanced movement and goal: wall slide, wall jump, lockout, air dash, dash
  refresh, momentum handling, goal Area2D, and completion/restart loop.
- Hardening: movement, feel, loop, level, and presentation regression suites;
  headless boot; route reachability; rendered capture; and native performance
  probe.
- Session 1 gameplay feel: add an 80 ms dash-input buffer at the landing refresh
  edge, with expiry and one-dash-per-airborne-cycle coverage. The route geometry
  and dash skill gate are unchanged.
- Session 2 level traversal: shorten the spawn ground so the first jump is a
  deliberate 70 px opening gap, and add a regression assertion for that route
  contract. The existing fast route, dash gate, and finish geometry are kept.
- Session 3 movement feel audit: replay the route in a rendered window and
  preserve the existing responsive controller values. Add a regression guard
  requiring 90% of max speed within eight frames so future tuning does not
  accidentally slow the opening pickup.
- Session 4 visual presentation audit: inspect the fresh native capture and Web
  render across the opening, traversal, goal, and completion states. The cool
  star/parallax composition, cyan player, slate platforms, amber goal, camera
  framing, and restrained HUD were already coherent, so no visual redesign or
  decorative dependency was added.
- Session 5 player-journey audit: verify launch help, the Tab/F1 controls toggle,
  first-input clock start, repeated reset behavior, goal feedback, and truthful
  completion time. Add regression coverage for hiding and restoring controls;
  no menu system or gameplay feature was added.
- Session 6 engineering hardening: verify repeated goal/timer/attempt state,
  add `tools/run_all_tests.ps1` as a dependency-free suite wrapper, rerun the
  native performance probe, refresh the Web export, and inspect the browser
  console/render. No gameplay architecture rewrite was needed.
- Session 7 final audit and freeze: independently re-run the suite, headless
  boot, native route capture, Web export, browser render/console check, and
  performance probe; reconcile all documentation; classify remaining issues;
  and stop feature work.
- Presentation pass: parallax ridge backdrop, star field, vignette, readable
  platform edges, dash ghosts, InputMap-driven HUD, completion banner, and
  finishing-time clock preservation.
- HTML5 pipeline: 4.7.2 templates, Web preset, local server, fresh export, and
  browser render/console verification; native rendered capture covers gameplay
  input and route completion.
- Post-release independent re-audit (this session): ran the full five-suite
  regression from the local Godot 4.7.2 binary against the S7+frozen state;
  reconciled the documented assertion total (84 → 85, presentation 26 → 27)
  across README, RELEASE_NOTES_v0.1.0, FINAL_DEMO_REPORT, and this handoff;
  re-ran a fresh HTML5 export; ran the headless boot check; ran the route
  reachability probe; verified the release dist artifact is present with the
  documented size and SHA-256; confirmed the test wrapper, exclude filter,
  portable docs, and removed `.mcp.json` are in the documented state. No
  gameplay, movement, route, visual, HUD, or Web changes were made.
- Standalone packaging (this session): installed the Godot 4.7.2 Windows export
  templates, added the `Windows Desktop` preset, added the reproducible
  `tools/build_release.ps1`, exported and launched the standalone EXE from a
  clean folder outside the repository, packaged
  `dist/Project-Ascent-v0.1.0-Windows.zip`, scanned the shipped payload for
  secrets/dev material, re-ran the 85-assertion regression and headless boot,
  and re-verified the HTML5 export. No gameplay, movement, route, visual, HUD,
  or input change was made to the frozen demo.
- Player character presentation (later session): added a stylized standing
  silhouette (Body polygon) with a cool ice-white Visor accent to `scenes/player.tscn`,
  and extended `scripts/player_visuals.gd` with a movement-direction facing flip
  and lightweight presentation pose states (idle breathing bob, run step-bob and
  forward lean, fall lean, wall-slide flatten) driven only by the existing public
  movement API. Movement physics, collision, camera, ghost pool, dash tint, and
  the test contract in `test_presentation.gd::_lit()` were untouched.Verified with the full 85/85 regression, a real-window route capture, and the
  native performance probe.
- Audio foundation (later session): added one procedural music loop, core one-shot
  SFX, a looping wall-slide hiss, and keyboard volume control via a level-owned
  `Audio` node, plus the `tools/probe_audio.gd` real-window harness (19/19 checks).
  Verified with the full 85/85 regression, a clean headless boot, andthe real-window perf probe. See
  "## Audio Foundation (Part 2)" below and `docs/AUDIO.md`. No gameplay, movement,
  route, visual, HUD, or Web change was made.
- Designed ascent level (Part 3): replaced the greybox with the deliberate
  13-node ascent described in "## Designed Ascent Level (Part 3)" below, plus
  three pit wells (6 wall segments) for wall-slide/jump practice. Updated
  `ROUTE` in `tests/test_level.gd`/`tools/probe_reach.gd` and made wall/coyote
  tests locate walls/platforms dynamically so they survive geometry changes.
  Verified with `probe_reach` (12 gaps, only S4_A→S4_B is DASH), `probe_envelope`
  (flat 187 px / dash 283 px), full 85/85 regression, headless boot, and the
  633-frame autopilot. No new movement mechanic, no checkpoint, no hazard
  beyond pits/kill plane. See level section below.

## Audio Foundation (Part 2)

A procedural audio foundation is now part of the demo: one cohesive music loop
that sits quietly under the action, a core set of one-shot SFX, a continuous
looping wall-slide hiss, and discoverable keyboard volume control. It is scoped
explicitly to "audio-only" — no gameplay, level, movement-physics, or mechanic
changes were made.

### Architecture

- **Not an autoload.** `Audio` is a child of `Main` (`scenes/main_scene.tscn`),
  so it is owned by the level and freed with it. It does not persist globally
  because this demo has a single level.
- **Buses.** `Master` (Godot default), `Music`, and `SFX` are registered once via
  a guarded `_bus_or_create`. Note `AudioServer.get_bus_name_list()` does not
  exist in Godot 4; use `get_bus_count()` / `get_bus_name()`. Defaults: Master
  0 dB, Music −20 dB, SFX −8 dB — music stays well under the one-shots.
- **Music.** `audio/music/music_loop.ogg` (16 s seamless loop, 22050 Hz stereo,
  62 KB) via a single looping `AudioStreamPlayer` on the `Music` bus.
- **SFX.** A fixed pool of 8 `AudioStreamPlayer`s, reused round-robin, so nothing
  is spawned per frame and node count stays flat. WAV imports switched to PCM
  (`compress/mode=0`) for instant, lossless one-shots.
- **Wall-slide hiss.** A dedicated `AudioStreamPlayer` that re-plays a 0.6 s
  loop-seamless noise one-shot on `finished` while the player is still sliding.
  `AudioStreamWAV.LOOP_FORWARD` proved unreliable on this environment's audio
  backend (it silently produced `playing == false`), so the loop is driven in
  software through the same verified one-shot path instead.
- **Web autoplay.** Nothing plays until `unlock_audio()`, called on the first real
  input — the browser-activation-safe moment. Music, SFX, and the hiss all start
  only after interaction.
- **Volume controls** (physical keys, committed to `project.godot`): `audio_master_down` =
  `-`, `audio_master_up` = `=`, `audio_music_down` = `[`, `audio_music_up` = `]`,
  `audio_sfx_down` = `;`, `audio_sfx_up` = `'`, `audio_mute` = `M` (toggles Master on/off).
  Keys step the relevant bus in ~2 dB steps; the master and the two sub-buses are
  adjusted independently.

### Signal mapping

| Player/level event | SFX |
|---|---|
| `landed` | `land` (volume scaled with fall speed) |
| `jumped` | `jump` |
| `wall_jumped` | `walljump` |
| `dashed` | `dash` |
| `wall_slide_started` → `_wall_player.play()` | `wallslide` (looping hiss) |
| `wall_slide_ended` | stop hiss |
| level `_respawn(cause)` FALL | `death` |
| level `_respawn(cause)` MANUAL | `restart` |
| level `_respawn(cause)` COMPLETE | `goal` |
| `toggle_help` (Tab/F1) | `ui` |

Non-physics-only changes to `player.gd` added the `jumped` / `wall_jumped` /
`dashed` / `wall_slide_started` / `wall_slide_ended` signals and a
`_is_wall_slide_active()` helper; movement variables, physics, collision, and
the `test_presentation.gd::_lit()` contract (which only counts visible Polygon2D
children of `Visuals`) are untouched.

### Asset provenance & licensing

Every asset is **procedurally synthesized** by `tools/generate_audio.py` (pure
NumPy; no network, no samples, no third-party audio). It is idempotent and is
the original-work source of truth and provenance record for every stream, so
there is no license burden beyond the project's own. The large PCM master files
(`audio/music/*.wav` and their `.import`) are gitignored; the OGG and WAV
payload assets are tracked. See `docs/AUDIO.md` for the full provenance and
validation table.

### Validation

`tools/probe_audio.gd` drives real input through an open window and verifies all
19 checks: bus existence/order, default music<sfx volumes, the autoplay gate
(no music before input → music on first input), every SFX trigger through the
pool or stream identity, the wall-slide loop start **and** its re-arm past the
one-shot duration, the stop on leaving the wall, volume keys, mute toggle, and
the UI blip. A perceptive/balance listen is not possible from this harness and
remains a documented limitation (the probe verifies wiring and state, not
perceptual quality). The real-window perf probe holds node count flat at
163 and completes the route in 633 frames.

## Designed Ascent Level (Part 3)

The greybox proving ground has been replaced by one compact, intentional
ascent that uses the existing moveset without adding a new mechanic.

**Route (13 landable nodes, left to right):**
`Ground → S1_1 → S1_2 → S2_1 → S2_2 → S2_3 → S3_1 → S4_A → S4_B → S5_1 → S6_1 → S6_2 → TopLedge`
with `ShaftWall`/`LeftWall` as boundaries and three pit wells for wall practice.
`S4_A → S4_B` (240 px) is the single dash-gate (`probe_reach` reports `DASH`);
every other gap is `trivial` (70–125 px, rise 0–78 px, within the measured
flat 187 px / 92 px envelope). The wall-jump and wall-slide verbs are taught in
the pits: each pit is a pair of dark `edge_thickness = 0` walls (40×400) forming
a 60 px well 140–180 px below the main line. Falling in is not blocked from
above — the jump over the gap goes above the well — but a miss drops you
between the walls where you can slide and wall-jump to recover. This keeps the
critical path completable by the flat autopilot (633 frames, ~10.5 s) while
making walls discoverable.

**Progression:**
- S1_1–S1_2 — run/jump, no punishment.
- S2_1–S2_3 — tighter 95–115 px gaps, naturally rewards coyote/buffer/variable height.
- S3_1 — vertical step (rise 40) with PitA below for wall recovery.
- S4_A (safe) → S4_B (dash gate) — dash introduced safely then required.
- S5_1 — post-dash recovery, dash refresh.
- S6_1–S6_2 — final ascent, 120–125 px gaps at 62–78 px rise, hardest but still trivial.
- TopLedge/Goal — amber ledge at 3800,200 with ShaftWall at 3920.

**Hazards:** No new spike movers. Pits plus `kill_depth = 1400` are the hazard
vocabulary — visually the dark wells read as danger, and falling in uses the
existing O(1) respawn (attempt++, timer reset, audio `death`). No extra hazard
tests needed beyond the existing headroom/goal/spawn/kill checks.

**Checkpoints:** Not added. Level is 633 physics frames; instant restart is fast
enough that a checkpoint would add state and UI complexity without clear benefit.

**Visuals:** Dark atmospheric palette preserved, player cyan dominant. Traversal
platforms keep slate `0.212` with bright cool top edges; pits/walls use the
darker structural `0.145` so playable vs mass is unambiguous. No asset pipeline.

**Validation:** `probe_reach` 12/12 gaps trivial/DASH as designed, `probe_envelope`
flat 187 px / dash 283 px, `test_level` completes in 633 frames, full 85/85
regression passes, headless boot passes, wall/movement tests updated to locate
walls/platforms dynamically so they survive geometry changes.

## Known Issues

- Godot runs in this managed environment emit global log/MCP registry permission
  warnings because the sandbox cannot write the normal user data directories.
  They are outside the project and do not fail the game tests or web runtime.
- Wall-jump and wall-slide are now discoverable in the three pit wells; the
  rightmost ShaftWall remains the final boundary. Pits are not hard-gated, so a
  player who never falls never needs walls, but the affordance is present.
- Browser frame timing was not re-measured in this pass. Native rendered timing
  and the full route were verified instead. The in-app browser rendered the
  fresh export and reported no console warnings/errors, but its synthetic
  keyboard injection did not move the canvas player; this is a test-harness
  limitation, not evidence of a game input defect.
- The root project has no selected license yet. The bundled MCP addon has its
  own MIT license and attribution file; that does not license Project Ascent.
- The repository is now **public** on GitHub (`p4inz-code/project-ascent`), the
  `v0.1.0` annotated tag and GitHub release exist, and the Windows ZIP is
  attached to the release. The remaining licensee decision is the only
  outstanding public-release owner action.
- The Windows standalone ships x86_64 only and is unsigned, so Windows
  SmartScreen may warn about an unknown publisher on first run. This is
  expected for a standard, un-signed Godot export and is not a defect.

## Intentional Limitations

There is one designed ascent (13 landable nodes, ~10.5 s) and one amber goal.
There are no accounts, backend, online services, monetization, saves,
inventory, multiplayer, procedural level generation, adaptive/dynamic music,
final-art pipeline, or large menu system. A procedural audio foundation is
present (see "Audio Foundation" below). There is deliberately no on-screen
settings menu (documented as future UX work). The completion loop is a
lightweight banner plus respawn, not a results screen. Hazards are limited to
pits and the kill plane; no moving hazards or spikes were added. Checkpoints
were evaluated and deliberately omitted.

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

The Windows standalone, distribution ZIP, public GitHub repository, `v0.1.0`
tag, and `v0.1.0` GitHub release are complete and verified. All documentation
has been reconciled with the thirteen-platform ascent level. The only remaining
public-release owner action is choosing the root project license (owner must
decide; none was invented). If development resumes later, make a human-led
creative decision before changing stable movement, route, visual, HUD, or Web
systems. The only reasonable future work is authored art/audio or a deliberately
designed wall-jump section; do not expand the feature list by default.

## Part 4 Finishing Pass (2026-08-29)

Documentation was reconciled with the actual thirteen-platform ascent level
(commit `5b3018c`). All four docs (README.md, ARCHITECTURE.md, FINAL_DEMO_REPORT.md,
SESSION_HANDOFF.md) now reference the correct platform names, route description,
performance numbers, and frame counts.

### What changed
- README.md: route description updated from old 8-node to 13-platform ascent.
- ARCHITECTURE.md: level geometry section rewritten for 13-platform route;
  stale performance numbers updated (163 nodes, 633 frames, 42.6 avg draw
  calls, 16.666 ms wall frame).
- FINAL_DEMO_REPORT.md: route references updated to S1–S6 naming.
- SESSION_HANDOFF.md: route references, performance numbers, and milestone
  entries updated.

### What was verified (all PASS)
- Full regression: 85/85 assertions, 0 failures (movement 28, feel 7, loop 15,
  level 8, presentation 27).
- Headless boot: exit 0.
- Real-window capture_run: route completed successfully with 40+ captured frames.
- Real-window probe_perf: 622 sampled frames, node count flat at 163, avg
  42.6 draw calls, wall frame 16.666 ms avg.
- probe_reach: all 12 gaps classified, only S4_A→S4_B is DASH (240 px).
- Audio: music, SFX, and wall-slide loop all wired through `GameAudio` node;
  verified in prior sessions.

### What was not changed
- No gameplay, movement, route, visual, or code changes.
- No new features, mechanics, or audio architecture.
- No test modifications.

### Current commit
- HEAD: `8f992a3` (same as `origin/main`).
- Working tree: clean.

## Fresh-Agent Startup Procedure

1. Read this document completely, then read `README.md`,
   `docs/FINAL_DEMO_REPORT.md`, `docs/ARCHITECTURE.md`, `docs/TOOLS.md`,
   `docs/RELEASE_NOTES_v0.1.0.md`, and `SECURITY.md`.
2. Inspect `git status`, `git log --oneline -20`, and the current diff.
3. Inspect the relevant repository files: `project.godot`,
   `export_presets.cfg`, `scenes/`, `scripts/`, `tests/`, `tools/`, and
   `docs/ARCHITECTURE.md`.
4. Run the five regression suites and the headless boot check.
5. Run the game in a real window and, when relevant, export and open the HTML5
   build through `tools/serve_web.py`, and rebuild the Windows standalone with
   `tools/build_release.ps1`.
6. Reconcile this handoff against the actual repository state and current git
   history; do not blindly trust old notes.
7. Continue only from the documented next milestone, and preserve the scope
   limits above.
