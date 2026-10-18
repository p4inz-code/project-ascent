# Sprint plan: 2026-10-20 (morning)

Branch: `v2-redesign` (last commit `075f9f9`, tutorial). Nothing here ships until the owner has tested and says so. Every item below ends with a test or a gate check, and every new test needs a negative control and goes into `tools/run_all_tests.ps1`.

Rules carried over: per-suite APPDATA isolation; hazard fairness doctrine; audit gate before any ship; no cheat codes in public copy.

---

## 0. First hour: unblock and verify what is already built

| # | Item | Done when |
|---|------|-----------|
| 0.1 | Tutorial shaft: the wall-jump bot still cannot climb it (reaches ~y589 of a ~y426 target). Trace why: kick arc vs. shaft width (now 90px inner), wall height, or bot timing. Fix the course or the bot, not both blindly. | `test_tutorial` passes with a bot that climbs on the real controller, and a human check says it feels fair |
| 0.2 | Tutorial TUTORIAL button: web check opened Level 1, not level 0. Confirm `start_tutorial()` -> `level_changed(0)` reaches `game_scene._on_level_changed` | click TUTORIAL from the title -> level 0 loads, guide visible; test covers it |
| 0.3 | Run the full gate on current code (stale logs only) | every failure is either fixed or on a signed allowlist |
| 0.4 | Reachability sweep failures L16/19/20/21/25 | each is a real defect (fixed) or a documented harness limit with a bot proof by hand |
| 0.5 | Climbability / no-wall audit across all 26 levels: no step or wall on the route taller than a jump, no dead-end shaft | one test, all levels, with a negative control |

## 1. Tutorial in 5 sets (all basics covered)

Each set = a short zone, one-line PIP instruction using the player's own bindings, a practice area with no lethal hazards, and a completion event. Sets are replayable from the menu and never saved as progress.

| Set | Name | Teaches | Completion event |
|-----|------|---------|------------------|
| 1 | MOVE | run, stop, turn, facing; camera; the HUD (timer, attempt, orbs) | run a set distance both ways |
| 2 | JUMP | tap jump, hold for height, coyote time, buffered jump, mantle/ledge grab, fall control | clear a gap, then a high step |
| 3 | DASH & SLIDE | dash (air and ground), dash across a wide gap, slide under a low gap, slide jump | cross the dash gap, then slide through |
| 4 | WALLS | wall-slide, wall-jump shaft, wall-run (if kept), ground pound, spin | climb the shaft to the ledge |
| 5 | THE WORLD | checkpoints, orbs, pause/restart/help keys, one harmless sample of each hazard class (blade, gate, pipe vent, lava edge with safe rail) and the goal door | step through the door; "TUTORIAL COMPLETE" |

Work items:
- Restructure `CourseGen.tutorial_level()` into five zones with clear rests between them (currently 6 lessons in one strip).
- Extend `TutorialGuide.LESSONS` to a set -> lessons structure; add a set title card and progress pips (1/5).
- Gamepad text: show button names when a pad was last used.
- Skip / repeat controls, and a "tutorial done" flag (already `GameSettings.tutorial_done`); suggest the tutorial once on first launch (skippable).
- Tests: per-set bot proof on the real controller, text uses current bindings after a rebind, progress never saved, set order enforced.

## 2. More settings and customization

Current pages: CONTROLS / AUDIO / VIDEO / GAMEPLAY / CHARACTER / ACCESS (search, rebinding, 6 fonts, pixel mode, accessories, colors).

Proposed additions, in priority order:
1. **Gameplay assists** (opt-in, never default): extra coyote time, jump buffer length, auto-dash direction, slower hazards (timed gates/pipes), hazard telegraph strength, "ghost" checkpoint markers, infinite death-line grace.
2. **Display**: window mode (windowed / borderless / fullscreen), resolution scale, VSync, FPS cap, UI scale, HUD opacity, screen shake slider (already partial), flash reduction.
3. **Accessibility**: colorblind palettes for hazards (lava/acid/water already distinct shapes: verify), high-contrast outlines for platforms, reduced motion, larger text, hold-to-toggle for dash/slide, one-handed layout preset, subtitle size/background.
4. **Audio**: per-bus mute, "focus" mix (ducking music during boss warning), audio test buttons, output-device note for web.
5. **Controls**: separate gamepad rebinding page, per-action deadzone, button prompt style (Xbox / PlayStation / Switch / keyboard glyphs), hold-vs-tap for jump height, sensitivity curve.
6. **Character**: more suits/trims/visors/trails, preset slots (3), randomize, unlockable-by-orbs cosmetics (ties to the 99-orb ending), preview with idle/run/jump animation loop.
7. **Profile**: reset-settings-to-default per page, export/import settings (JSON text, web-safe), "clear tutorial flag".
8. **Quality-of-life**: confirm dialogs for destructive actions (already on ending), remember last page/tab, search covers all pages.

Rules: every setting persists, has a default, is reachable in 2 clicks via search, and has a test (round-trip + effect where observable).

## 3. Story polish and cutscene improvement

Files: `scripts/cutscene.gd` (566 lines, opening), `scripts/ending_screen.gd` (395, cinematic ending + 3 choices), `scripts/coming_soon.gd`, `docs/STORY_AND_ORBS.md`.

1. **Audit first (read-only, ~45 min)**: play both cutscenes at 60 and 144 fps, windowed/fullscreen/web, with and without rebinding, with gamepad. Log every defect into the bug table (section 4).
2. Audit checklist: skip works at every beat (key, click, pad); no double-fire of `finished`; text fits at all window sizes and UI scales; audio cues present and not stacked; pause during a cutscene; focus loss on web; reduced-motion respected; replay from STORY does not change `intro_seen`; ending reachable after 99 orbs only via the intended path; "RESET PROGRESS" confirm cannot be hit by accident; "HOME" returns to the title with correct state.
3. **Story pass**: tighten the opening to a clear 3-beat arc (who, what's wrong, why climb), give the five acts one intro line each (airlock, heat, frost, warp, dawn), give PIP a consistent voice (short, dry, never explains the key presses twice), and add one callback line in the ending to the opening.
4. **Act transitions** (planned earlier): Airlock / heat flash / frost wipe / warp streak / dawn ascent, with `Player.lock_input()` from goal touch until the next level's fade-in ends. Test that no input moves the player during a transition.
5. **Cutscene tooling**: a single `CutsceneRunner` contract (beats, skippable, `finished` once), so the opening, act cards and ending share it.
6. Tests: skip at each beat, single `finished`, text fit across sizes, input locked during transitions.

## 4. App-wide bug bounty

Method: a time-boxed, adversarial pass over every surface, by category, logged to `docs/BUG_BOUNTY_2026-10.md` with ID, severity, repro, fix, test. A bug is closed only when a test fails before the fix and passes after.

| Category | What to attack |
|----------|----------------|
| Save / progress | corrupted/missing/future-version save file; quit mid-write; two instances; reset during level; tutorial never writes; web storage unavailable (private window) |
| Input | every action on keyboard, gamepad, rebinding conflicts, rebinding to reserved keys, held keys across scene changes and pauses, focus loss, simultaneous dash+slide+jump, input during transitions |
| Menus | every page reachable, back/escape on every page, focus order, mouse + keyboard + pad, search edge cases (empty, symbols), rapid clicking, opening settings during cutscene |
| Gameplay | death in every hazard class, respawn state (timers, orbs, abilities), checkpoint after death, boss timer edge cases, rising floor, goal while dead, double completion, level skip via menu |
| Physics | very low/high frame rates, 120/144 Hz monitors, hitches (alt-tab), window resize, moving platforms and crumble plates under the player |
| Audio | missing buses, mute + volume persistence, stacked loops after restart, web audio unlock on first gesture |
| Visual | pixel filter at odd resolutions, UI scale extremes, text overflow with every font, shader compile failures on compatibility renderer, z-order of hazards vs. platforms |
| Content | every level start-to-goal reachable, no stacked/overlapping hazards, no unfair spawn kills, no wall without a way past |
| Security / hygiene | no cheat sequence in public docs or UI, debug flags ignored in release builds, no absolute paths or user names in builds |

Use the existing gate suites as the net; add one **fuzz suite**: random input sequences (seeded) on random levels for N seconds, assert no script errors, no NaN positions, no stuck state (player not outside level bounds without dying).

## 5. Platform compatibility

Targets: Windows, macOS, Linux, Web (itch). Steam Deck via the Linux/Windows build. Consoles (PlayStation, Xbox, Switch) are out of scope: they need a third-party porting studio and platform-holder dev kits. Mobile excluded by decision.

| Platform | Checks |
|----------|--------|
| Web | fresh export loads and plays (verified once locally on 2026-10-19); first-gesture audio unlock; focus and canvas resize; no thread/SharedArrayBuffer need (export is no-threads); storage failure handled; QUIT hidden (already); fonts that need SystemFont fall back sensibly; WebGL warnings (`bufferSubData: no buffer`) investigated; load time and download size noted; test on Chrome, Firefox, Safari, Edge; hosted on itch to confirm. |
| Windows | clean install run, no console, high-DPI, Windows Defender/SmartScreen note, controllers (Xbox, DualSense, Switch Pro via Steam Input) |
| macOS | zip + Gatekeeper/notarization note, retina scaling, Cmd-key conflicts, controllers |
| Linux | x86_64 run on a clean distro, Wayland/X11, Steam Deck: 1280x800 layout, gamepad-only navigation of every menu, glyph prompts |
| All | gamepad-only play from title to goal, window sizes 16:9/16:10/ultrawide/4:3, 60/120/144 Hz, keyboard layouts (AZERTY/QWERTZ: default bindings use physical keys?) |

Tasks:
- `tools/ship_gate.ps1`: compile preflight, full suite with per-suite APPDATA, fail on any FAIL / SCRIPT ERROR, allowlist file with human sign-off, cheat-sequence scan of README/docs/itch/UI, `version.txt` consistency, release build ignores debug flags, all four exports succeed, web smoke test (headless browser load, no console errors).
- Gamepad parity audit: every menu and the tutorial usable without keyboard; prompts switch by last-used device.
- Evaluate 120 Hz physics: run the suite at 120, record impact, implement only if safe.
- Docs: update ITCH_PAGE, README, and ART docs; note platform support and the console answer in the FAQ.

## 6. Tomorrow's sprint order (execute directly)

1. **0.x** unblock: tutorial shaft, menu path, full gate, reachability, climbability audit.
2. **Tutorial into 5 sets** (section 1) with bot proofs.
3. **Act transitions + input lock**, then the cutscene audit (read-only) feeding the bug table.
4. **Boss formats**: L20 lightning, L25 collapsing; per-attempt jitter for non-road levels.
5. **Controls matrix test** + gamepad parity audit.
6. **Settings batch 1**: assists, display, accessibility (items 1-3 of section 2), with tests.
7. **Bug bounty pass** + fuzz suite; fix everything critical/high.
8. **Platform pass**: ship_gate.ps1, web smoke, docs, sounds (door, vent hiss, boss siren, ending), 120 Hz evaluation.
9. **Full clean gate**, relaunch the game for the owner. Do not tag or publish until the owner approves.

## Decisions (owner, 2026-10-19 night)

1. **Fonts: approved.** Download open-licence (OFL) pixel fonts and bundle them, so the unique fonts also work on web. Record each font's licence file in the repo.
2. **First launch: automatic, always skippable.** Order: title -> PLAY -> story cutscene (skippable) -> tutorial offered (skippable, with a clear SKIP) -> level 1. Each step sets its own seen/done flag so a returning player never sees it again. Story and tutorial stay replayable from the menu. Test the full first-launch chain, including skipping at each step and quitting midway.
3. **Settings: go broad and detailed.** Accessibility first, then everything else in section 2. A detailed, well-kept settings panel signals a serious project, so every setting gets a default, persistence, search, a reset, and a test.
