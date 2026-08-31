# Project Ascent

Developed by **Atharva Patil** ([p4inz-code](https://github.com/p4inz-code)) under **Northbyte Studios**.

Project Ascent is a 25-level 2D precision platformer built around responsive
movement, fast retries, readable traversal, and a dark atmospheric Neon Ascent
visual identity.

## Current status

**v0.12.0 — Longer Levels, Abilities, Zero-G**

A full 25-level, 5-act campaign with boss encounters, save/checkpoint
progression, a shared cyberpunk UI theme applied across every surface,
player/accent colour personalisation, trauma-based camera shake, per-act
visual identity, procedural city silhouettes, and floating atmospheric
particles.
Offline-first with no accounts, backend, ads, or network runtime.

## Download and play (Windows)

> **PLAYER DOWNLOAD** — no Godot, no source, no tools required.

1. Download the [latest release](https://github.com/p4inz-code/project-ascent/releases/download/v0.12.0/Project-Ascent-v0.12.0-Windows.zip).
2. Download **`Project-Ascent-v0.12.0-Windows.zip`**.
3. Extract the ZIP anywhere (all files must stay together in the same folder).
4. Double-click **`ProjectAscentLauncher.exe`** — not `ProjectAscent.exe` directly — and click Play.

If Windows SmartScreen warns about an unknown publisher, choose **More info → Run anyway**
(the file is an unsigned standard Godot export).

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move left/right | A/D or Left/Right | Left stick X |
| Jump | Space or W | A / south button |
| Dash | Shift or J | X / west button |
| Spin (air mobility, brief i-frames) | Double-tap Jump | Double-tap A / south button |
| Slide | S / Ctrl / Down | B |
| Ground pound | Down + Jump (airborne) | B + A |
| Air dash | Dash while airborne | X |
| Wall run | Run into a wall with speed | — |
| Ledge grab | Automatic | — |
| Grapple | E / K | RB |
| Use ability | G / F | LB |
| Restart | R | Back / Select |
| Pause | Escape | Start |
| Show/hide controls | Tab or F1 | — |

## Features

- Responsive running with acceleration, deceleration, and air control
- Jumping with coyote time, jump buffering, and variable height
- Wall slide and wall jump
- Air dash with landing refresh and momentum handling
- Spin — double-tap jump, usable in mid-air, granting brief hazard
  invulnerability on a cooldown
- Six further movement verbs — slide, ground pound, air dash, wall run, ledge
  grab, grapple. Only three claim a key: the rest derive from inputs the player
  already knows, because eleven separately-bound verbs stops reading as depth
- Ledge grab is automatic — it rescues a jump that came up a few pixels short
- Moving platforms, conveyor belts, crumbling platforms, bounce pads, wind
  zones, and one-way platforms (solid from above, pass-through from below)
- Instant-death hazards: spinning blades, swinging pendulums, and lava pits
- Obby gauntlet levels (L2, L7) — flat treks over lava broken by jump, dash,
  and spin crossings, instead of pure platform-to-platform ascent
- Every level past 15 carries its own lethal hazard mix, escalating to Act V
- Fast fall respawn, manual restart, attempt counter, and run timer
- 25 handcrafted levels across 5 distinct visual acts, with mixed platform
  mechanics spread across every act (not siloed to a single act)
- Boss chase encounters at Levels 5, 10, 15, 20, and 25
- Smart boss AI with stuck detection, adaptive jumping, and ledge detection —
  chasers hold an edge or jump a gap they can clear, instead of walking off it
- Every level's jump geometry validated against a measured jump envelope, so no
  step demands more height than the player can actually reach
- Per-level save/checkpoint progression
- Level Select — replay any completed level from the pause menu
- Pause menu with neon panels, action icons, and a shared UI theme
- Cyberpunk pixel font across all UI — menus, HUD, run timer, and controls panel
- Personalisation: 6 player colours, 5 UI accents, and intensity dials for
  screen shake, parallax depth, and neon glow — all applied live, no reload
- Trauma-based camera shake on hard landings and deaths
- Every setting drives real behaviour, verified by a test that asserts an
  observable change in the running game rather than that the value saved
- Procedural city skylines, parallax ridges, star fields, floating particles,
  with per-level shape variation on top of per-act color identity
- Per-act visual identity (Dawn → Dusk → Night → Storm → Apex), each with its
  own sky landmark — a rising sun, a low moon, a banded planet — plus weather:
  snow, driving rain with lightning, and rising embers
- A foreground silhouette layer passing in front of the player for real depth
- Themes — named presets (Ascent, Ember, Frost, Vapor, Toxic, Mono) that
  recolour the player, UI, platform edges and backdrop together. Ascent stays
  the default identity, and the individual colour pickers remain as overrides
- Platform edge glow and atmospheric lighting
- Dash afterimages and player feedback
- Keyboard and controller bindings from Godot's InputMap
- One-charge ability pickups — super jump and glide, spent with the Ability key
- Zero-gravity fields where the player drifts (Act V)
- Every level ~50% longer, extended along its own measured rhythm
- Standalone launcher with update checking, bundled with every release

## Campaign

### Act I — Learn (L1–L5)
Introduction to movement. Jump, dash, precision. Ends with the first boss chase.

### Act II — Master (L6–L10)
Longer levels, tighter precision, movement combinations. Second boss encounter.

### Act III — Survive (L11–L15)
Environmental pressure, demanding routes. Shadow Chase boss.

### Act IV — Endure (L16–L20)
High difficulty, complex combinations. Tempest 2-phase boss.

### Act V — Ascend (L21–L25)
Maximum challenge, endurance, final escalation. Dawn 3-phase final boss.

## Boss encounters

| Level | Boss | Minions | Speed |
|---|---|---|---|
| L5 | First Chase | 4 | 170 px/s |
| L10 | Master Escape | 5 | 220 px/s |
| L15 | Shadow Chase | 5 | 200 px/s |
| L20 | Tempest | 6 | 250 px/s |
| L25 | Dawn (Final) | 6 | 300 px/s |

## Save system

- Automatic per-level checkpoint saving
- Progress persists between game sessions
- Reset Progress available from pause menu
- Corrupt save safely falls back to Level 1

## Screenshots

_Pending — owner is providing a fresh set of real screenshots for this section._

## Run locally

### Requirements

- Godot **4.7.2 stable**
- Git

Clone the repository, open it in Godot, and run:

```text
git clone <repository-url>
cd project-ascent
godot --editor --path .
godot --path .
```

On Windows, replace `godot` with the path to your Godot 4.7.2 executable.

## Testing

Run the complete test suite with the bundled wrapper (slowest suite —
the full 25-level reachability sweep — runs last):

```text
tools/run_all_tests.ps1
```

which runs, in order:

```text
# Game tests
godot --headless --path . --script res://tests/test_boot.gd
godot --headless --path . --script res://tests/test_movement.gd
godot --headless --path . --script res://tests/test_feel.gd
godot --headless --path . --script res://tests/test_loop.gd
godot --headless --path . --script res://tests/test_level.gd
godot --headless --path . --script res://tests/test_level3_route.gd
godot --headless --path . --script res://tests/test_presentation.gd
godot --headless --path . --script res://tests/test_save.gd
godot --headless --path . --script res://tests/test_new_mechanics.gd
godot --headless --path . --script res://tests/test_level_rhythm.gd
godot --headless --path . --script res://tests/test_chaser_ledges.gd
godot --headless --path . --script res://tests/test_new_verbs.gd
godot --headless --path . --script res://tests/test_dev_console.gd
godot --headless --path . --script res://tests/test_customization.gd
godot --headless --path . --script res://tests/test_hazard_placement.gd

# Route and reachability validation (25 levels)
godot --headless --path . --script res://tests/test_all_routes.gd
godot --headless --path . --script res://tests/test_full_campaign.gd
godot --headless --path . --script res://tests/test_all_levels_reachable.gd

# Launcher tests
python -m pytest launcher/tests/
```

All suites pass with zero failures as of the current build.

Two of these suites exist because an earlier gate proved the wrong thing:

- **`test_level_rhythm.gd`** checks that no jump demands more rise than the
  player can actually deliver, using an envelope *measured* from the real
  controller (`tests/probe_max_rise.gd`) rather than assumed from the
  `jump_height` export. The reachability suite passed Levels 9 and 10 despite
  both shipping impossible final jumps — it reached the ledge by wall-jumping
  off that ledge's own face, which proves a bot can get there, not that the
  jump is fair.
- **`test_chaser_ledges.gd`** asserts a chaser stops at a cliff instead of
  walking into it. Three previous fixes for "enemies falling" addressed
  collision layers and a recovery teleport; none of them checked whether there
  was ground ahead, which was the actual cause.
- **`test_new_verbs.gd`** asserts each movement verb produces a real effect —
  a verb that compiles and a verb that works are different claims.

The runner also fails a suite on any GDScript parse or compile error, not just
a non-zero exit code — a suite whose script fails to compile reports
`failures=0` while having asserted nothing at all.

## Architecture

- `scripts/player.gd` — movement state and physics, including dash and spin
- `scripts/player_visuals.gd` — non-authoritative squash/stretch/lean/spin visuals
- `scripts/game_scene.gd` — level loading, transitions, pause overlay
- `scripts/game_manager.gd` — game-wide state, progression, pause, level-select jump
- `scripts/main_scene.gd` — level controller, spawn, boss, completion
- `scripts/level_data.gd` — all 25 level definitions (data-driven)
- `scripts/save_system.gd` — file-based save/load
- `scripts/pause_menu.gd` — pause overlay with settings/progress/level-select
- `scripts/platform.gd` — reusable platform geometry
- `scripts/moving_platform.gd` — oscillating platform that carries the player
- `scripts/conveyor_belt.gd` — constant lateral push while grounded on it
- `scripts/crumble_platform.gd` — triggered one-shot collapsing platform
- `scripts/bounce_pad.gd` — vertical launch pad
- `scripts/wind_zone.gd` — directional force field
- `scripts/one_way_platform.gd` — solid from above, pass-through from below
- `scripts/spinning_blade.gd` — rotating instant-death hazard
- `scripts/pendulum.gd` — swinging instant-death hazard
- `scripts/lava.gd` — static instant-death pit
- `scripts/ui_theme.gd` — the shared UI Theme: palette, type, control styling
- `scripts/camera_shake.gd` — trauma-based camera shake
- `scripts/hud.gd` — controls, timer, attempts, completion UI
- `scripts/audio.gd` — music, SFX, procedural audio
- `scripts/city_silhouette.gd` — procedural background city skyline
- `scripts/floating_particles.gd` — atmospheric floating particles
- `scripts/boss.gd` — boss AI with stuck detection and adaptive jumping
- `scripts/minion.gd` — minion AI with tracking and jump behavior
- `launcher/` — Python launcher/updater, bundled with every release and the
  intended way players start the game (see Download and play above)

## Project structure

```text
scenes/        Godot scenes for levels, player, platforms, UI
scripts/       Runtime GDScript
assets/        UI frames, font, number sprites
tests/         Headless behavior, presentation, and route validation suites
tools/         Test wrapper, web server, probes, and capture scripts
shaders/       Presentation shaders
addons/        Development-only Godot MCP toolkit
docs/          Architecture, design, handoff, and release documentation
launcher/      Optional Python launcher with update checking
build/         Windows standalone build output
```

## License

Project Ascent's source, original game content, and branding are not granted
reuse rights by this repository. See [`LICENSE`](LICENSE) for full terms.

The bundled `addons/godot_mcp_toolkit/` is a separate development addon with its
own MIT `LICENSE`; that license does not license the game.
Godot and the Godot logo are trademarks of the Godot Foundation.

## Further reading

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — technical reference
- [`docs/LEVEL_DESIGN.md`](docs/LEVEL_DESIGN.md) — campaign design
- [`docs/SESSION_HANDOFF.md`](docs/SESSION_HANDOFF.md) — continuation guide
- [`CREDITS.md`](CREDITS.md) — credits and attribution
