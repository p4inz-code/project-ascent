# Roadmap status (v2 redesign branch)

Last updated: 2026-10-20 (end of chat 1). Branch `v2-redesign`. Nothing from v2 is tagged or published; `main` is v0.14.1.
A teaser build exists locally (`dist/Project-Ascent-v2-Teaser-*.zip`) for showing friends.

How to read this: **LIVE** = checked in a real window or real Chrome with real input. **TESTED** = automated suite in `tools/run_all_tests.ps1` passes, not yet seen live. **OPEN** = not done.
The full gate has NOT been run on the current code. Until it is, "TESTED" means the individual suite passed on its own.

## BIG RUN: live progress (updated as work lands; newest first)
Legend: [x] done and verified, [~] built, partly verified, [ ] not started. "Verified" names the suite or live check.

### Step 0: gate on HEAD 34811e0 (done)
- [x] Ran `tools/ship_gate.ps1 -SkipBuild` on a snapshot copy of HEAD (68 suites, about 1.5 h under CPU load). Result: every suite passed, including `test_all_levels_reachable` and `test_full_campaign`, EXCEPT the known `test_level` "the course can be completed from spawn (NEVER FINISHED)". Its allowlist entry is still UNSIGNED, so the gate reports FAILED until the owner signs it or the harness is fixed. Not signed by me.
- [x] The gate also reported "compile errors in the pre-flight": a gate bug. It matched the pre-flight's own line "no compile errors" case-insensitively. Fixed (`-CaseSensitive`); exports not run (-SkipBuild).

### Step 1: attack (M1) + 3-cell HP + test arena (commit 0a4efec)
- [x] M1 slash: mouse / L / pad RT, aims at cursor / held direction / right stick (`test_health_attack`: reach, arc, cooldown, locked input)
- [x] Targets: drones die, darts deflect, lever (slash switch) opens a gate, down-slash on raised spikes pogos, chase minions stunned not killed (`test_health_attack`, each with a negative control)
- [x] 3 HP cells, chip hazards (blades, pendulums, shooters, spikes, drones) cost 1 with 1 s invulnerability + knockback; lava/acid/crush/void/chasers stay instant; respawn and cores refill (`test_health_attack`)
- [x] HUD visor with cracking-glass cells, attack + hurt animation rows, slash/hit/hurt sfx, controls panel row, rebindable L
- [x] Test arena: `--dev-arena` (level 98, never saved). Captured and read (`tools/capture_arena.gd`). Owner playtest: [ ] pending
- [ ] Art upgrade pass (player sheet beyond the new attack row, HUD polish)

### Step 2: machine framework + validator bot
- [x] `MachineSim`: scene-free mirror of the player, matches the real controller to under 0.1 px on run, jumps (hold 3..25 frames), air dash, ground dash (`test_machine_sim`, with negative control)
- [x] Kit: lower lane + deck lane, spikes, humps, lava pits, deck gaps, roof spikes over gaps, flame jets, belts, air jets between lanes (`MachineKit`, `MachinePieces`)
- [x] Probe table: every kit piece's window found by sweeping the physics, pass probability measured with the noisy bot (expert 20 / median 40 / novice 60 ms), generated into `scripts/machine_table_data.gd` (`tools/gen_machine_table.gd`; `test_machine_pieces` fails if stale or incomplete)
- [x] Generator: seeded, deterministic, 50 re-rolls then an authored fallback, calm hinges every 6 cells, checkpoints on hinges, no window narrower than 5 frames (`test_machine_gen`: 720 rolls, 0 fallbacks, all rules, all floors, curve falls with level)
- [x] Proof: a perfect bot clears the best route of 100 rolls with no hit; shifting every decision +-2 frames still clears 38 of 40; real-player replay of sim inputs ends within 3 px on 10 piece types (`test_machine_routes`, `test_machine_replay`)
- [x] Runtime: whole level re-rolls on every death, 8-char seed code and LUCKY/BRUTAL tag on the HUD, tube back wall (`test_machine_build`)
- [x] Preview any level as a machine: `--dev-machine=N`
- [ ] Trap routes with tells / bait, harmless cued jump scares (spooky setting), orb nooks
- [ ] Biome pieces: crushers, ice, storm events, forge heat

### Step 3: rebuild levels 5-19, 21-25 act by act
- [ ] Act I Cinder: L5 THE BORER (lava lake runner)
- [ ] Act II Scrapyard: L6-9 machines, L10 THE COMPACTOR (vertical climb)
- [ ] Act III Freezer: L11-14 machines, L15 WARDEN'S MILE (stealth hunt)
- [ ] Act IV Storm: L16-19 machines, L20 TEMPEST (reactor arena)
- [ ] Act V Forge: L21-24 machines, L25 DAWN (slow-vent tile hop)

### Steps 4-7 (not started)
- [ ] 15 new levels 26-40 (Underworks maze, Rift black hole, Core echo exam)
- [ ] Add-ons (seed share, endless, daily), tutorial attack set, STRONG/WEAK briefing + taunts (taunt lines need owner review first)
- [ ] Tester builds on tester-N branches (telemetry + copy-report), final gate, live checks

### Findings worth knowing
- With a Gaussian timing error, a novice's pass rate is about the median's rate to the power 2.6, so the plan's "novice >= 1%" floor would cap the median at about 17%. The generator uses novice >= 1% up to level 14 and >= 0.2% after (the 3% median floor, the 100-tries rule, is untouched).
- First-pass machine difficulty is gentler than the plan's anchors (mean median-player odds now about 0.86 at L6, 0.23 at L16, 0.13 at L25 vs targets 0.52 / 0.18 / 0.08). The kit needs tighter pieces (stepping stones, crushers) and tester telemetry to calibrate.

## Done

| Area | What | State |
|------|------|-------|
| Tutorial | Level 0, five sets (MOVE, JUMP, DASH AND SLIDE, WALLS, THE WORLD), ten lessons, set cards, PIP voice, never saved as progress | LIVE (played start to finish with real keys) |
| First launch | PLAY, story (skippable), PIP offer (skippable), tutorial, level 1. Returning players are never asked again. Skip from the pause menu | LIVE |
| Controls | Pause is its own action: pad B (Slide) no longer pauses; START pauses; D-pad Up opens the controls panel; explicit menu accept/back on a pad | LIVE |
| Controls | Ground dash re-arms after a cooldown (was one dash until you jumped) | LIVE |
| Controls | Controls matrix test: every action, key and pad binding table, rebinding, dead zone | TESTED |
| Transitions | Five per-act covers (airlock, heat flash, frost wipe, warp streak, dawn ascent) | LIVE for airlock, frost, dawn; heat and warp captured, not reviewed |
| Transitions | Real input lock from goal touch until the next level is clear (old code let you run under the banner) | LIVE |
| Cutscene audit | Held key from PLAY no longer skips the film; back and pause also skip; flashes and shake respect Reduce Motion | TESTED (skip path seen live) |
| Story | PIP intro line on the first level of each act; ending callback line | TESTED, not seen live |
| Camera | Zoom presets (close, default, wide), hold-to-peek look (keys and right stick), follow speed. Wide and peek are off in boss chases | TESTED |
| Settings framework | Declarative registry: defaults, limits, per-page reset, search, platform filtering; one generic test covers all | TESTED |
| Accessibility | Text size, high-contrast platforms, colour-blind correction (3 types), extra ledge grace, extra jump buffer, hazard speed, fixed jump height | TESTED (text size LIVE) |
| Graphics | Quality presets (low, medium, high), AUTO measured from frame times, one-time offer to lower on sustained low fps | TESTED |
| Display | Window mode, window size, vsync, frame cap (desktop); fullscreen toggle only on web | window size LIVE; rest TESTED |
| Gamepad | Vibration strength, button-prompt style (auto, keyboard, Xbox, PlayStation, Switch), glyph families, last-device tracking | TESTED |
| Backup | Copy and paste all settings (works on web) | TESTED |
| Fonts | Nine choices; four open-licence pixel fonts bundled with licences and credits, so web matches desktop | LIVE (rendered) |
| Platform rules | One `Platform` helper; web hides quit, window options, file export | TESTED; web title and menu seen in real Chrome |
| Roads | Road levels got hints and the right boss minion counts (fixed two failing suites) | TESTED |
| Random per load | Gates and pipes in a different valid set of gaps every level load; a few ordinary platforms crumble (a different few each time; many more on level 25) | TESTED (760 random layouts) |
| Storm | Level 20 lightning: warned for 1.25 s, room to step aside, one at a time, quiet after respawn; a dodging bot took 0 hits | TESTED |
| Reachability | Harness now retries run-ups and hazard kills, jumps at the lip, tries without a wall kick, reloads before failing: levels 16, 19, 20, 21, 25 pass | TESTED |
| Climbability | Contract over all 25 levels (no step above a full jump, no walls on the route, spawn and goal on platforms) | TESTED |
| Fuzz | Seeded random play on 14 levels with settings changing underneath: no errors, finite positions, no stuck lock | TESTED |
| Settings integrity | No dead settings (every one is read by code) and every one survives save and reload | TESTED |
| Ship gate | `tools/ship_gate.ps1`: versions, assets, secrecy scan, full suite with signed allowlist, exports, release-flag check | secrecy scan proven on a planted leak; full run pending |
| Regression fixed | v2 timing gates had taken the `TimedGate` name from the plate-linked gate; restored as `PlateGate` (a test hung on it) | TESTED |
| Story (opening film) | Survey ship now flies nose-first left to right with trailing exhaust; new Trevor bust, cockpit, Spire and dock art; telemetry readouts; caption padding; no windows across the Spire seam. All 30 frames reviewed | TESTED (`test_story_direction`, `test_cutscene`); frames reviewed in a real window capture |
| Story (ending) | Floor line for Trevor, larger PIP lines, final line lands after the flash (12 s total, any key skips) | TESTED, frames reviewed |
| Tooling | `tools/live_verify.gd` (real-input window run), `tools/cdp.mjs` (real Chrome driver), gate now imports assets first | working |

## Open

| Item | Notes |
|------|-------|
| Full gate on current code | Running on HEAD 8932f30 (tests only; `dist/gate_run.log`). Exports not re-run. |
| Live failures to re-check by hand | Frame-cap click, BORDERLESS click and LOW-preset click did not take effect in the live script (unit tests pass; the script probably mis-clicks after the window resizes). Level 2 release after a transition passed when traced by hand. |
| `test_level` | "course can be completed" fails; it also fails on `main` v0.14.1, so it is an old harness or level issue. |
| Bug bounty | `docs/BUG_BOUNTY` not written. The fuzz suite exists (`test_fuzz`, seeded); more seeds still to run. |
| Docs and copy | README, itch page and AUDIO docs updated; design bible and ART docs still to update. |
| 120 Hz physics | **Evaluated, decision: keep 60 Hz physics.** Measured with `tests/probe_physics_rate.gd`: at 120 Hz a full jump is 2.3% lower (100.6 px to 98.3 px), a running jump reaches 2.4% less, a dash 3.4% less. Levels are tuned at 60, and several steps (rise 96, gap 195) sit on the edge of what the player can do, so a 120 Hz simulation would make them harder. Smooth motion on 120/144 Hz screens needs physics interpolation instead (visuals only), which must reset on every teleport (respawn, checkpoint, transition): deferred, not required for a release. |
| Render-scale slider | Not built: there is no clean render-scale path for a 2D game in Godot. Decide: drop it or restructure rendering into a sub-viewport. |
| Web re-check | Re-export and play-test in real Chrome after the latest changes (the Chrome window stopped drawing frames today). |
| Gamepad-only play | Title to goal on a pad has not been run; no pad was available. |
| Settings still on the wish list | More audio options, more gameplay options, more character options, settings presets. |
| Release | Version label still says 0.14.1; no tag, itch upload or GitHub release until you approve. |

## NEXT: the big run (planned, not started)
The whole next phase is planned in `docs/PLAN_v2_big_run_2026-10-20.md` (Part 1 = authoritative summary): attack (M1) + 3-cell HP, machine levels (random multi-route conveyor tubes) replacing levels 5-19 and 21-25, eight distinct biome boss levels, a STRONG/WEAK mode with escalating taunts (lines for owner review in `docs/TAUNT_LINES_review.md`), harmless jump scares, original reaction cards, a validator bot that proves every random roll passable (100-tries rule), then 15 new levels (26-40). Pricing target 4.99 USD once 40 levels exist.

Order: (0) run the full gate on HEAD (a previous run died with the session; `test_level` allowlist still unsigned), (1) attack + HP + test arena, (2) machine framework + validator, (3) rebuild levels 5-19 and 21-25 act by act with owner playtests, (4) the 15 new levels, (5) add-ons, tutorial/briefing/docs, (6) gate + live checks + tester builds (separate `tester-N` branches; `v2-redesign` keeps everything).

Older "Next, in order" items still open: re-check frame-cap / BORDERLESS / LOW-preset clicks by hand, re-export and test web in real Chrome, bug bounty doc, gamepad-only play-through, design bible and ART docs, rebuild teaser zips.
