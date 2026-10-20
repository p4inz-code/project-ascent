# Project Ascent: v2 BIG RUN plan (written 2026-10-20, end of chat 1)

Status: planning is done, EXECUTION HAS NOT STARTED. Branch `v2-redesign` (HEAD at the time: docs commits after `8932f30`). Nothing is tagged or published; never tag or publish without the owner's approval.

How to read this file: Part 1 (below) is the AUTHORITATIVE summary of final decisions. Part 2 is the full chronological planning log (rounds 1-12 + appendix); later rounds supersede earlier ones, and Part 1 already applies that. Taunt lines for owner review: `docs/TAUNT_LINES_review.md`. Day-to-day status: `docs/ROADMAP_STATUS.md`.

---

# PART 1: AUTHORITATIVE SUMMARY

## Goal
A 3-5 USD "rage" platformer: frustrate the player so beating it boosts their ego, super addictive, torture but NEVER impossible (may take 100 tries). Levels and obstacles are random on every death so nothing can be practised, while every roll is proven passable. Identity line: ONLY THE MENTALLY STRONG FINISH THIS GAME.

## Order of work (the big run)
0. Run the full gate on HEAD (`tools/ship_gate.ps1 -SkipBuild`, about 25+ min; `test_all_levels_reachable` alone takes 10+ min). The previous run died with the session and left no result. `test_level` fails on main too (old harness issue; allowlist entry is UNSIGNED: owner decides).
1. Attack (M1) + HP systems, light version, with a test arena launch flag (first owner playtest).
2. Machine framework + validator bot (lanes, conveyors, jets, humps, spikes, trap routes, scares, checkpoint calm zones, seed display).
3. Rebuild levels 5-19 and 21-25 (20 levels) as random multi-route "machine" levels, act by act, with the biome tile sets and boss formats; owner playtests after each act. (Levels 1-4 unchanged.)
4. THEN the 15 new levels 26-40 (Acts VI-VIII), new mechanics, bosses L30/L35/L40.
5. Add-ons: seed replay/share, endless mode, daily seed.
6. Tutorial: attack set + HP note; the post-tutorial briefing; docs; teaser rebuild.
7. Gate + live verification (real window with real mouse; web in real Chrome). Tester builds: Windows + web zips, separate `tester-N` branches cut from `v2-redesign`, which stays the main branch containing everything; tester-mode flag with telemetry + copy-report button.
The owner manages time; the assistant keeps working autonomously, committing at every checkpoint (explicit `git add` including project.godot/shaders/audio/assets/docs).

## Game identity decisions
- ONE difficulty switch: STRONG (default: pure torture, PIP trolls, no hints, nothing helps) or WEAK (only the text changes: no trolling, no taunts, no brag text; same difficulty, no hints). Picking WEAK asks "ARE YOU SURE YOU ARE WEAK?" and adds a WEAK tag. Changeable in Settings > Gameplay.
- POST-TUTORIAL BRIEFING (first-launch chain: PLAY -> story -> tutorial -> briefing -> level 1; shown before level 1 even if the tutorial is skipped; re-readable in Settings): the two modes + the STRONG/WEAK pick; "every 5th level is a boss, far harder, a different format, every attempt re-rolls" (no solving hints); content notice (strong language aimed at you, crude insults, sudden scares and loud sounds, flashing) with Language (strong / bleeped) and Spooky effects (Full / Reduced / Off) toggles. Boss levels get a BOSS card (reuse `BossWarning`).
- NO HINTS anywhere (tutorial text only).
- Escalating taunts (5 tiers by deaths per level session; thresholds shift down on harder levels; tier 5 keeps climbing forever). Swears allowed from tier 4. Banned (CI scan): motherfucker, son of a bitch, any mother/family reference, slurs, gendered insults, bastard, real people, self-harm. Each tier has its own unique lines. Owner reviews the lines (`TAUNT_LINES_review.md`) before testers see them.
- Memes on death: original pixel reaction cards only (about 40-60). NO third-party memes (copyright research: Success Kid lost 2024, Grumpy Cat $710k, Pepe takedowns). Cards pop up non-blocking; respawn stays <= 0.5 s with no blocking death screen.
- Jump scares: harmless, cued, fired on mistakes (and a few safe-place feints), 20-30 s apart, about 6 per level max, never during precision sections. FIXED safety limits: at most 3 flashes per second, one flash pair per scare, no saturated-red flashes, no strobes/stripes, sting true-peak <= -1 dBTP and about 6 LU above music, music ducks about 6 dB; web audio starts only after a gesture and Godot web Sample playback has no bus effects (pre-limit stings or use Stream playback). Settings: Spooky effects Full / Reduced / Off.
- Store/ratings: expect ESRB Mature (Strong Language) / about PEGI 16; honest questionnaires; itch.io mature classification; keep thumbnails/store art free of swearing; no data collection; asset provenance log + licence checklist + takedown plan in the ship gate.
- Ego payoffs: result card + rank vs par, roll labels (verifiable effects + a LUCKY/BRUTAL tag computed from the validator pass rate), trap-route bonus, seed card to share/replay (8-char seed, game version baked in, copy button with fallback), clear-screen swarm of attempts, daily seed (UTC date) with LOCAL best only.

## Health + attack
- M1 = melee slash toward the cursor (about 70 px arc; kills small enemies, deflects darts, hits switches, down-strike pogo). Keyboard-only: L key (aims along held direction, default facing). Pad: RT, aim with right stick else left stick. Rebindable; optional aim assist. LIGHT use in the rebuilt machine levels, full use in the 15 new levels. Chase minions: stun only.
- HP: 3 cells; chip damage 1 HP (1 s invulnerability, knockback) from enemies, spikes, jets, shooters, steam; lava, acid, crush, void, black hole, drowning stay instant death. Full heal on respawn and on core (orb) collection (nothing if full). HP applies everywhere. Art: suit-energy cells with cracking glass in a pixel visor frame, top-left under the level-name text; cyan, cracks/flickers on hit, amber on the last cell. Art upgrade this run: HUD + player (sprite, slash) + the new biome tile sets for the 25 levels.

## Difficulty curve and maths (targets; the tester telemetry replaces them)
- 100-tries rule: per-attempt clear probability p of the median skilled human-like bot >= 3% (1-(1-p)^100 >= 95%); novice bot >= 1%; bosses floor 4.5%. Obstacle budget: sum(-ln q_i) <= 3.51 per roll (HP-aware: kill hazards count fully, chip hazards count the third hit).
- GRADUAL curve (log-linear anchors on p): L1 0.72, L10 0.40, L15 0.20, L25 0.08, L40 0.045; bosses x0.8 at L5/L10, x0.55-0.7 later. L1-10 chill, 11-14 ramp, torture from L15, change noticeable but never sudden.
- Totals: levels 1-25 about 1.9 h and about 121 deaths; 1-40 about 6.1 h and about 396 deaths; with a 0.8% quit-per-death hazard about 40% finish 1-25 and about 5% finish all 40 (target 3-10%, like Getting Over It 9.3%, Jump King 9.7%). Levels 1-25 alone are under 2.5 h: lengthen levels about 25% or add content before selling at 3 USD.
- Level length: pixels about 166 x T (T = clear time in seconds). Formulas: expected time = T(1 + f(1-p)/p), f = 0.5.
- Pricing: do not sell until the 15 new levels exist (or sell 25 levels at 2.99); target 4.99 USD (3.99 if about 3 h). Net per sale at 5 USD: about 3.50 Steam (30%), about 4.06 itch.io. Steam refunds under 2 h of play (games under 5 USD about 8% refunds; rage games can reach 20%+); risk peaks at L15 (about 31 min in): free web demo of levels 1-10, honest store page.
- Proof of "never impossible" (all enforced in the gate): (1) frame-stepped search finds a route in every roll, re-checked with +-3 frame / +-2 px jitter; (2) Monte-Carlo with the noisy human-like bot (simple reaction N(230,40) ms, choice N(330,60) ms, input noise sigma 20/40/60 ms = expert/median/novice) meets the p floors; (3) at most 2 simultaneous threats, tells >= 0.8 s, safe window >= 0.35 s at torture, an escape action every frame, no hidden hazards, sightline >= reaction + travel; (4) per-biome proofs (maze route, black-hole margin, storm overlap, chaser never catches a slowed player); (5) determinism: same seed = same roll. Generator: constructive within about 70-80% of max reach, re-roll up to 50 times then fall back to an authored template. Tests: stacking, blind jumps, generator bias histograms, perfect-bot over-approval, hazard sizes vs jump height.

## The "machine" level (from the owner's sketch)
A start platform, then one long tube like a conveyor machine: floor lane (belt, spike rows, hills, air/flame jet grate, ends in a furnace), roof lane (hanging spikes, ramp to a tower, the End door), jets and gaps lift you between lanes, many routes, some of them traps (with tells). Every roll keeps at least one bot-proven route; trap routes are allowed, never the only visible way; hinge platforms bracket machine segments. Checkpoints get a calm zone (fewer hazard tiles); the WHOLE level re-rolls on every death (owner), including with checkpoints. Harmless jump scares fire when the player does something wrong. Plus walls with hazards where it fits (Scrapyard).

## Biomes and bosses (final)
| Act / biome | Levels | Boss level and format |
|---|---|---|
| I CINDER (volcano, fog, lava floor) | 5 | L5 THE BORER (gentle): runner over floating tiles on a lava lake that pulses every 1 s (heartbeat), geysers every 4-6 s from fixed lanes after a rumble tell; the Borer surfaces behind you |
| II SCRAPYARD (junkyard, dusk) | 6-10 | L10 THE COMPACTOR (gentle): vertical climb up a wreck tower, rising flood/compactor, junk dropped from a crane (shadow tell), magnet cranes yank ledges, walls with hazards; tiles: car roofs, containers, tyres (bounce), crates (crumble), chains |
| III FREEZER (fully ice) | 11-15 | L15 WARDEN'S MILE (first torture): stealth hunt on ice; slippery tiles only (NO speed cap, no dash rules, just environment variables); sprinting is loud; hiding spots; light M1 stuns |
| IV STORM LINE | 16-19 (+20) | L20 TEMPEST: reactor arena, ground-pound 4 conductor rods while lightning hits where you stood 1.25 s ago; live storm event deck all level (lightning, gust lanes, hail, debris, rain-slick, flicker blackouts with faint tile outlines, tornado pulls, thunder scares), at most 2 events at once |
| V SUMMIT FORGE | 21-25 | L25 DAWN: floating tiles over lava, flame vents from BELOW tiles slow you -30% for about 1.5 s on a timer (1 s orange glow tell), collapse front behind you; slowed player speed >= chaser/collapse speed x 1.15 always; tile-hopping rhythm |
| VI UNDERWORKS (new) | 26-30 | L30 THE MAZE: industrial tunnel maze, FIXED topology and correct route per level (visible wrong paths, e.g. fork 1: 1 wrong / 1 right; fork 2: 3 wrong / 2 right), content re-rolled each death (obstacles, acid surges every 5-6 s random with a 1 s hiss tell, tiles, enemies); timer calibrated from tester data (limit = tester median + 1:20 when testers clear under 60 s); Hive-Mother drones killable by M1 |
| VII RIFT (new) | 31-35 | L35 THE BLACK HOLE: floating tiles drift on currents, a black hole chases at about 85% of best-route speed, one mistake and it eats you, in the last 10 s it eats hazards only (not platforms) |
| VIII CORE (new) | 36-40 | L40 THE ECHO EXAM: 5 phases each remixing one biome rule (cinder heartbeat lava, ice, storm, black hole, maze doors), reactor re-skins per phase, then strike 3 Core nodes with M1; phase checkpoints are the ONLY exception to whole-level re-roll; zero-g can appear here; triggers the 100-core ending logic |
Machine levels (5-19, 21-25) per-level recipes are in Part 2 (Round 7). Boss rewards: core + boss-only cosmetic + rank card. Level 20 changed from the old chaser boss to the reactor arena (owner confirmed).

## Other decisions
- Tester build: logs attempts, deaths, times, seeds, cause of death, quit points, p estimates; copyable report; Windows + web.
- Music: one loop per biome + boss tracks from the synth scripts; art and audio are the assistant's call, owner reviews contact sheets.
- Levels 1-25 stay at the same level numbers (saves keyed by level number: append only); `TOTAL_LEVELS` 25 -> 40 later; ORB_GOAL 100 is for the planned 100-level game (door not gated today).
- Fairness doctrine from earlier sessions still applies (every timed hazard has a safe window and a telegraph; no stacking; no ragebait on the only route; assists only lengthen windows).

## Known repo facts (so the next chat does not re-explore)
- 18 of the 25 current levels are the same rightward staircase, 7 are flat roads (`course_gen.gd` ROADS 3,5,8,13,15,18,23). Per-level code: `level_data.gd`, `course_gen.gd`, `road_course.gd` (cells/tiers/fairness rules, per-attempt reroll), `main_scene.gd` builds everything and `_respawn()` is where new objects need a `reset()`.
- Nothing can be killed today; hazards are `Area2D` (layer 0 / mask 1) -> `player_hit` -> `MainScene._on_hazard_hit()`. Chasers `minion.gd`/`boss.gd` (CharacterBody2D layer 4 / mask 2). Input map comes from `tools/setup_input.gd` into `project.godot`; rebinding in `input_bindings.gd`; controls panel `hud.gd ROWS`; right stick is currently peek/look. Player sheet has no attack row: 4 variants `player_sheet*.png` built by `tools/gen_pixel_art.py` (append rows).
- Hard-coded 25 in `game_scene.gd`, `transition_fx.gd`, `death_plane.gd`, `tile_rules.gd`, `hud.gd` and many tests (`test_save`, `test_checkpoints`, `test_climbability`, `test_goal_gate`, `test_menu_pages`, ...).
- Unused but built: fake platforms, plate gates, trap groups; wind in 2 levels, zero-g in 2.
- Tooling gotchas: Godot exe `C:\Users\Admin\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`; headless tests need an isolated APPDATA; bash heredocs with apostrophes break (use the Write tool); `python` works, `python3` does not on this machine; launching the windowed game with PowerShell Start-Process needs the project path QUOTED inside the argument (`'"F:\PROJECT ASCENT\project-ascent"'`); the gate runs test suites one by one (output appears only at the end of the suite section).

---

# PART 2: FULL PLANNING LOG (chronological; later rounds supersede earlier ones)

# Project Ascent: M1 combat, 15 new random levels, new mechanics (DRAFT, planning still open)

Status: DRAFT v1. Owner has NOT said planning is over. Do not implement until they do.

## Context
Players are bored of the same 25 levels (18 are the same rightward staircase, 7 are flat generated roads;
L2/L7, L21/22/24, L18/23 are near-duplicates). The tutorial teaches wall-jump, slide, pound, grapple but no
level needs them. Nothing in the game can be killed and the mouse is only used in menus. The owner wants:
M1 (left click) attack, new acts of levels that are unique, MORE mechanics, trickier, and everything spawning
randomly so levels cannot be practised.

## Decisions made by the owner (this session)
- M1 = melee slash toward the cursor (kills small enemies, deflects darts, hits switches, down-strike pogo).
- Combat: full M1 in the NEW acts; a LIGHT version (deflect darts, hit switches, spike pogo, a few stunnable enemies) in the rebuilt machine levels (owner, round 6); levels 1-4 and 20 unchanged; old chase minions can be stunned, not killed.
- 15 new levels, 3 acts (26-40), each act = own look + gimmick + an M1 boss at 30 / 35 / 40.
- Mechanics: wall-jump shafts + slide tunnels, rift portals, gravity flip zones, descent + auto-scroll levels.
  PLUS "more of them", trickier, and everything randomly spawning (also lantern/darkness and switch-and-gate rooms are candidates).

## More owner decisions (round 2)
- Re-roll: the WHOLE level is re-rolled on every death (no learnable layout). Consequence: new-act levels stay SHORT (6-9 chunks, about 60-90 s to clear), no long runs to lose; checkpoints are not used in Acts VI-VIII.
- Difficulty: hard but fair + per-attempt random modifiers (shown on the level card before the roll; e.g. low gravity, fog, faster hazards, extra enemies, mirrored); every modifier proven by the same bot sweep.
- Attack input: Mouse1 / L key (aims along held direction, default facing) / pad RT (aim = right stick else left stick); rebindable; optional aim-assist setting.
- Cores: 1 per level, in a random optional reward nook per roll.

## More owner decisions (round 3)
- Bosses: 30 THE HIVE-MOTHER (spawns drones to slash while dodging), 35 THE RIFT WARDEN (portals + gravity flips mid-fight, vulnerable only when it phases in), 40 THE CORE (three phases using wall shafts, auto-scroll, everything learned). Arena re-rolled each death.
- Add-ons accepted: (a) seed display on the pause menu + replay/share a roll (optional practice mode), (b) endless/survival mode on the same generator, (c) rework near-duplicate old levels (L2/L7, L21/22/24, L18/23) with new chunk recipes or visuals.

## More owner decisions (round 4)
- First playable: M1 combat in a test arena (launch flag), so the owner tunes the feel before level content builds on it.
- Story: descent into the Spire's machinery. Act VI THE UNDERWORKS (the Spire's workers fight back; combat intro, wall shafts, slide tunnels), Act VII THE RIFT (portals open inside the Spire; portals + gravity flips), Act VIII THE CORE (what the 100 cores power; descent, auto-scroll, everything). New PIP lines per act; the 100-core ending stays the true finale.

## Facts that shape the design (from code, verified)
- Existing per-attempt random system: `scripts/road_course.gd` (cells, tiers, fairness rules) + `scripts/course_gen.gd`; random placement of gates/pipes/tiles (`gate_rules.gd`, `pipe_rules.gd`, `tile_rules.gd`, `level_data.gd get_level(number, seed)`).
- Hazards are `Area2D` (layer 0 / mask 1) calling `player_hit` -> `MainScene._on_hazard_hit()` -> `_respawn()`. Chasers: `minion.gd`, `boss.gd` (CharacterBody2D layer 4 / mask 2; reset by `_deactivate_boss_chase()`).
- Player (`scripts/player.gd`, 1016 lines): exclusive-state chain in `_physics_process`; `reset_state()`, `apply_external_launch(vy)` (use for pogo), no attack action. Mouse aim: `get_global_mouse_position()` already respects Camera2D zoom/shake/peek.
- Input map is written by `tools/setup_input.gd` into `project.godot`; rebinding in `scripts/input_bindings.gd` (keyboard only); controls panel `hud.gd ROWS`; `controls_page.gd`. Right stick is currently "peek".
- Player sheet has no attack row; 4 sheet variants (`player_sheet*.png`), built by `tools/gen_pixel_art.py` (`ANIMS` list: append rows).
- Reset pattern for new objects: keep refs in `main_scene.gd`, call `reset()` in the non-COMPLETE branch of `_respawn()`.
- Adding levels: `LevelData.TOTAL_LEVELS` (25) + `_legacy_level()` match; saves are keyed by level number, so APPEND only. Hard-coded 25 in: `game_scene.gd` (subtitle match, palettes, sky, "25 OF 100" text), `transition_fx.gd`, `death_plane.gd`, `tile_rules.gd`, `hud.gd`, many tests (`test_save`, `test_checkpoints`, `test_climbability`, `test_goal_gate`, `test_menu_pages` ...), docs.
- Level select is the pause-menu grid (5 columns). Ending: 100 cores by design is for the planned 100-level game; door is not gated.
- Built but unused: fake platforms, plate gates, trap groups, wind (2 levels), zero-g (2 levels).

## Core idea: "hinge chunks" (how random levels stay provably fair)
New-act levels are assembled at run time from authored CHUNKS. Every chunk starts and ends on a flat, wide
"hinge" platform (>= 320 px, grounded, stationary). Because the player is standing and in control at every hinge,
chunks are independent: if each chunk is solvable hinge-to-hinge, ANY order is solvable (induction).
- Each chunk declares: family/mechanic, tier, width, exit height delta, hazard budget, tell requirements.
- Generator (like `RoadCourse.choose_layout`): picks chunks per tier, never repeats a family back-to-back, <= 2 hard in a row, rewards/checkpoints at hinges, enemies placed in declared slots.
- Validation: the real-controller bot (as in `tests/test_all_levels_reachable.gd`) must clear EVERY chunk from hinge to hinge, many seeds each, with a negative control. Then composition tests over thousands of seeds check only the generator's rules.
- Roll policy (decided): whole level re-rolled on every death; levels are short; no checkpoints.

## Phases (REVISED after round 6; each ends committed; nothing tagged/published without owner approval)
0. Housekeeping: re-run the full gate on HEAD (earlier run died with the session; no result); decide `test_level` allowlist.
1. M1 core, LIGHT version first (needed by the machine levels): `attack` action (Mouse1 + L + pad RT), `PlayerAttack` (cooldown ~0.3 s, arc toward cursor, hitstop), slash effect + `attack` sheet row (all 4 sheets), sfx, HUD/controls row, rebinding, accessibility (aim assist, no-mouse path), reset hook; first targets: darts deflect, switches, spike pogo, stunnable minions. Test arena launch flag = first owner playtest. Tests incl. fuzz action list.
2. Machine framework: lane model (floor / roof / tower), conveyor floor (belt speed < run speed), piece catalogue from the sketch (spike row, flame+air jet grate, hump, roof spikes, roof gap, ramp, floating thin platforms, furnace end, End-door box), route generator with tiers, trap routes with tells, bait, harmless jump scares, checkpoint calm zones, seed display. Bot validator: every machine has >= 1 bot-proven route; piece-by-piece bot sweeps with negative controls; composition tests over thousands of seeds.
3. Rebuild levels 5-19 and 21-25 (20 levels) as machines, act by act, each with its biome look; boss levels 5, 10, 15, 25 as fully enclosed tunnels with the chaser (L20 storm unchanged; 1-4 unchanged). Update the tests that assume staircases (`test_climbability`, `test_all_levels_reachable`, `test_geometry`, `test_level_rhythm` ...) to the machine contract. Owner playtests after each act.
4. New mechanic families + 15 new levels (26-40): wall-jump shafts, slide tunnels, rift portals, gravity-flip zones, descent, auto-scroll, lantern/dark rooms, switch-and-gate rooms, modifiers; three M1 bosses (30 Hive-Mother, 35 Rift Warden, 40 The Core) in biome tunnels (Underworks dry, Rift crystal, Core underwater pipe with `SwimZone`).
5. Add-ons: seed replay/share, endless mode, refresh of near-duplicate old levels (largely covered by phase 3).
6. Tutorial set 6 (COMBAT) + machine/jet notes, PIP/story lines per act, docs (README, ITCH_PAGE, design bible, LEVEL_DESIGN, ROADMAP_STATUS), rebuild teaser zips.
7. Gate + live verification (real window with real mouse; web in real Chrome), then wait for the owner to say ship.

## Fairness rules for "trickier + random"
- Every hazard keeps a visible tell and a safe window (existing doctrine); trickier = more chunk families, tighter combos, more enemies, faster auto-scroll, never hidden instakills.
- Per-attempt randomness never changes what is possible, only what is next.
- Assists that lengthen windows (hazard speed, grace) keep working; attack must have an aim-assist option and a no-mouse path.

## Verification (end to end)
- Full gate (`tools/ship_gate.ps1`), new suites added to `tools/run_all_tests.ps1`, every new test with a negative control.
- Chunk bot sweep: all chunks x seeds; composition sweep: thousands of seeds; fuzz including `attack`.
- Live: windowed run with real mouse clicks (`tools/live_verify.gd`), web build in real Chrome via `tools/cdp.mjs`.
- Owner playtest of each act before moving on.

## Round 5 (owner): branching traps, jets, jump scares, boss tunnels (REFINING; owner is sending screenshots of the trap style they want)

### Level flow grammar ("player > ? > ? > death or reward")
Each chunk is a short STORY of beats, not a flat obstacle. Proposed beat grammar (to be matched to the owner's screenshots):
1. ENTER (hinge, safe, a quiet tell is planted: a sound, a light, a crack).
2. BAIT (something tempting: a core, a shortcut, a ledge that looks safe).
3. FORK (2-3 routes, never one way): HIGH route (skill: walls/pogo/gravity), LOW route (slower, tunnel/slide), RISKY shortcut (fast, one trap, pays off a bonus). Every route is hinge-to-hinge solvable and bot-proven.
4. TRIGGER (stepping on / near something arms it: plate, tripwire, crumble, sensor).
5. SPRING (the trap fires: jets, crushers, drones bursting out of vents, floor dropping, lights cut).
6. PAYOFF: the player either reads the tell and passes, or dies/misses the bonus.
7. RECOVER (hinge).
The generator picks bait, fork shape, trigger and spring independently from catalogues, so combinations differ every roll.

### Mechanic placement rules (refined)
- A chunk has at most ONE spring beat and at most one active hazard family at a time; a fork never offers two routes with the same hazard.
- Triggers are placed so the tell is visible >= 1.0 s before the spring and the first safe window opens >= 0.6 s after the spring fires; assists only lengthen.
- Mechanics are introduced in order inside an act: act-first level shows each new mechanic alone, later levels combine them (max 2 families per chunk, 3 in Act VIII).
- Portals/gravity zones only in chunks whose exit hinge is fixed; entry/exit speed is clamped at the hinge so momentum can't carry past it.
- Enemy slots are declared per chunk (ground, ceiling vent, wall); spawns are randomised among valid slots, never inside a jump arc's landing zone.

### Jets and jump scares (fairness-safe definitions, to confirm against the screenshots)
- JETS: vents/pipes that blast gas, steam or flame in a line with a 1.0 s hiss+glow tell, a repeating safe window, and sometimes used as a launcher (a ride, not a kill) depending on direction. Reuses `pipe_tube.gd` gust code and `ShooterTrap` telegraph code.
- JUMP SCARES: startling events that are cued (lights flicker, audio sting, a shadow) and then lethal only if the player ignores the cue: drone crashing out of a wall panel, a face-hugger drops from the ceiling, floor panel flips, lights-out followed by a flash. Never an unseen instant kill; the startle comes from sound/visual surprise with ~0.5 s of reaction room. Reduce Motion and flash settings apply to the visual part.

### Boss levels: the whole level becomes a TUNNEL (per biome)
- Boss levels (30, 35, 40; old bosses untouched) are enclosed: a ceiling and floor tile the whole arena into a tube; the boss lives inside it.
- Biome variants (one per act, more variants possible later):
  - Act VI THE UNDERWORKS: industrial service tunnel (pipes, steam jets, vents spawn drones); dry.
  - Act VII THE RIFT: crystal/rift conduit with gravity flips and portal windows in the walls.
  - Act VIII THE CORE: flooded reactor conduit = UNDERWATER PIPE TUNNEL: swim physics (buoyancy, drag, jump = stroke, dash = jet burst), no breath timer, currents act as wind zones. Supersedes the old "no swim" note in MOVEMENT_DESIGN.md; needs a `SwimZone` plus tests.
- Technical consequences: tunnel levels need a ceiling rule (the current `test_climbability` forbids walls/ceilings on the route; add a "tunnel" contract with minimum clearance >= 240 px so a full jump never bonks), camera clamped to the tube, tunnel tile art per biome, boss movement/attacks adapted to a tube (charge lanes, wall-crawl, gas jets).
- Hinge rule still holds inside tunnels (flat safe segments between boss phases).
- Biome-by-biome plan is to be written per act once the owner's screenshots arrive.

## Round 6 (owner sketch): the "MACHINE" level, and a NEW ORDER OF WORK
Owner's sketch (saved at ...\images
.webp, a hand drawing): a start platform on the left, then one long TUBE like a conveyor machine.
My reading (to confirm with the owner):
- Two wheels at the ends with an arrow: the floor is a CONVEYOR belt moving right, a machine, not a normal road.
- Lower lane (inside the tube): spike rows, a grate with up-arrows labelled "air" (jets that lift or burn), humps/hills to jump, and the lane ends in FLAMES at the right end (the belt carries you into the furnace).
- The tube roof is a second lane (upper deck) with a platform on it, roof spikes hanging at one stretch, a ramp up to a tall tower box, and a big box on the right with "End" (the door). Thin floating platforms far right.
- Several drawn paths cross each other: many routes (low lane, high lane, jet lifts through gaps in the roof, ramp); not one way. Dead-end/trap routes exist ("then death or what").
- Owner words: "tricky like this and random every time, for every difficulty and level"; "some jump scare, no harm, just to make sure the user is scared and did something wrong"; "for checkpoints keep less hazard tiles".

### New order of work (owner)
A. FIRST rebuild levels 5-18 and 22-25 (18 levels) as random multi-route machine levels in this style.
B. THEN the 15 new levels (26-40), M1 combat, new mechanics (as already planned).
Machine levels = 5-19 and 21-25 (owner confirmed: 19 and 21 are machines too). 1-4 and 20 (storm boss) unchanged.

### Design: the lane model ("machine")
- A machine level = START platform + a corridor made of 2-3 LANES stacked vertically: floor lane, roof lane (upper deck), optional tower lane. Lane links are optional shortcuts and also hazards: jets (air lift), roof gaps, ramps, one-way drops.
- Solvability contract (replaces the pure hinge rule): (1) at least one route is fully passable and proven by the bot; (2) usually two routes; (3) extra "trap routes" are allowed but always show a tell (flame glow, hiss, lit warning) and never are the only visible path; (4) every lane link has an entry and a landing that are safe to read. Hinges (wide safe platforms) still bracket the whole machine and sit between machine segments, so segments stay independent.
- The conveyor floor has a belt speed below run speed so you can always move against it; the lower lane's far end is a furnace (flames) = the pressure to leave the lower lane before the end. Tiers change belt speed, density, hazard family mix and number of lanes.
- Catalogue from the sketch (each a reusable piece with its own tell + safe window + bot test): spike row, jet/flame grate (jets lift = ride; flames = lethal, alternating), hump (hill), roof spikes, roof gap, ramp/stair up to tower, floating thin platforms, furnace end, belt reverse zones, end-door box.
- Every roll: which lanes exist, where the roof gaps and jets are, which hazards sit where (within slot constraints), belt speed, bait/reward positions, jump-scare slots. Tier 1-3 (and a 4th for Act V) controls the mix.
- Per-biome machines (act look): Act I cinder furnace belt, Act II scrapyard (crushers, magnets), Act III cryo freezer (ice belt, frost jets), Act IV storm line (lightning rails, wind jets), Act V summit forge. Boss levels (5, 10, 15, 25) are fully enclosed tunnels (belt) with the chaser behind; L20 storm stays as is.

### Jump scares (owner: harmless, to make the player feel they did something wrong)
- Harmless scare events: shadow flash, a face in a vent, a loud sting, lights-out, a fake "ROAR" from the wall, a fake drone burst that misses. No damage, no stun, only a quick flash (Reduce Motion/flash settings respect them) and a sound.
- They fire when the player does something "wrong" (takes a trap route, steps on a fake tile, triggers a plate, lingers too long) and sometimes at random. A real hazard is never hidden behind one; the real trap always has its own tell.
- Option to turn them down ("Spooky effects: full / reduced / off"), default full; accessibility.

### Checkpoints
- Calm zone around every checkpoint: a hinge and at least one neighbouring segment have fewer or no hazard tiles (density x0.3 within ~1 segment each side), no springs, no jump scares for 3 s after respawn.
- Owner decision: the WHOLE level re-rolls on every death even with checkpoints (a flag only moves the respawn; the part before it re-rolls too). Calm zones stay.

## Round 7: RAGEBAIT DESIGN (the heart of the game) and BIOME PLAN

Owner goal: frustrate the player so beating it boosts their ego, while being super addictive. Owner rule from before: ragebait must be FAIR. Lesson already paid for: v0.12.1 shipped "ragebait platforms on the only route" and they were unbeatable. So the rule is: rage that points at the player's own mistake, never at the game cheating.

### The loop we are building (what makes it addictive)
1. Attributable death: every death must make the player say "I misread / I mistimed", never "that was cheap". Tools: a consistent visual grammar (orange glow + hiss = harmful; cyan = safe/interactive; purple/white flash + sting = harmless scare), a 0.3 s freeze-frame outline on the killer, "died at 63%" shown on respawn.
2. Instant retry: respawn in well under a second, no menu between death and try (measure the current respawn; target <= 0.6 s). Short levels (60-90 s) = "one more try".
3. Near-miss engineering: hazard sizes and windows tuned so most deaths are "SO close". Show best progress marker and "so close" lines.
4. Bait and punish (the ragebait itself): a tempting wrong choice that is obviously wrong in hindsight: a core on a trap route, a free-ride lower lane that ends in the furnace, a fake End door, a platform that looks solid but is fake (always flickers at the same rate, learnable), a roof lane that looks safe but has hanging spikes. Rule: every bait has at least one reliable tell, and bait is never the only route.
5. PIP as an unreliable narrator (character-fit): PIP gives hints with a confidence: "SAFE. 97 PERCENT SURE." and is sometimes wrong. Pure decoration (the real tells still exist), so fair. Controlled by the STRONG/WEAK switch (WEAK = no trolling).
6. Harmless jump scares = psych-out: they fire when the player does something wrong or at random in SAFE places, using a different visual+sound grammar from real hazards, so skilled players learn to ignore them (ego), new players panic and make mistakes (ragebait).
7. Variable reward from random rolls: every attempt is a new puzzle. Show roll labels ("LUCKY ROLL", "BRUTAL ROLL", rare ones like "ALL JETS") so an easy roll feels like a gift and a brutal roll is a boast. Rare-roll badges.
8. Ego payoff: big finish juice, a result card (time, deaths, route taken e.g. "ROOF LANE, NO JETS", rank, "TRAP ROUTE CLEARED" bonus), personal best per level, seed card to flex/replay; clearing a trap route pays extra (cosmetics or bonus). Random layouts mean mastery = skill, not memorisation, so bragging is honest.
9. (REJECTED by owner: no anti-tilt hint valve. See round 7/8.)
10. Pacing: calm hinges and checkpoint calm zones between spikes of difficulty; music/colour shift at the breather.

### Hard guardrails (so "ragebait" never becomes "broken")
- At least one bot-proven route per roll; trap routes always carry a tell; never ragebait on the only route; no unseen instakill; scares never hide a real hazard.
- Fairness bar is a HUMAN-LIKE bot (reaction delay about 200 ms, aim/timing jitter), not a perfect bot: "possible" must also mean "doable by a person". Per-piece target failure rates by tier measured by that bot (tier 1 about 10-15 percent first-try failure, tier 3 about 35-50 percent, brutal pieces above that only on optional trap routes). Pieces outside their target band are retuned before shipping.
- Dev-only death heatmap per piece (flag-gated, local) to tune intensity from real playtests.
- Intensity: ONE STRONG/WEAK switch (see the owner decisions below); assists keep working in both.

### Biome plan (look, machine variant, signature pieces, signature ragebait, boss tunnel)
| Act / biome | Levels | Existing look | Machine variant and signature pieces | Signature ragebait | Boss tunnel |
|---|---|---|---|---|---|
| I CINDER FURNACE (dawn, no weather, acid floor at L5) | 5 only (1-4 unchanged) | amber/navy, low sun | belt tube; flame+air jet grates, spike rows, humps | free-ride floor lane that ends in the furnace | L5 THE BORER: fully enclosed belt tunnel, Borer chaser behind, fast belt |
| II SCRAPYARD (dusk, snow, water floor) | 6-10 | purple, big moon | crusher lines, magnet cranes that yank platforms (blue hum tell), belts that alternate direction, pressure vents, sparks | "magnet" yank at the last second; a crusher with a late safe slot | L10 MASTER ESCAPE: enclosed tunnel that FLOODS from below (existing rising water) |
| III CRYO FREEZER (night, snow, ice floor) | 11-15 | near-black + cyan | ice belts (belt + low friction), frost jets (leave slippery patches), stalactites that drop on a shimmer tell, cold vents, fog | stalactite drop where the "safe" ledge is; ice on the exact landing | L15 WARDEN'S MILE: freezer tunnel, Warden hunts, breath fog visuals |
| IV STORM LINE (rain, lava floor) | 16-19 (20 unchanged) | blue-grey, bruised planet | sideways wind jets, lightning rails (existing storm code), shooters, belts that reverse mid-level | lightning marks where you WERE 1.25 s ago (punishes camping, never random) | none (L20 stays storm boss) |
| V SUMMIT FORGE (embers, huge sun, lava floor) | 21-25 | dark to golden | forge: crushers, pendulums, collapsing tiles, zero-g pockets, rising lava | fake End door; roof lane that collapses behind you | L25 DAWN: the tube COLLAPSES behind you with light at the end |
| VI UNDERWORKS (new) | 26-30 | industrial grey/teal | dry service tunnels, steam jets, vents spawn killable drones, wall-jump shafts, slide tunnels, valves/switches (M1) | steam jet that is a ride only if you jump on the hiss | L30 HIVE-MOTHER |
| VII RIFT (new) | 31-35 | violet crystal | portals (momentum), gravity flips, glitchy reality scares | a portal that returns you to a worse place, but never trapping you | L35 RIFT WARDEN |
| VIII CORE (new) | 36-40 | white/gold reactor | descent, auto-scroll wall of light, flooded pipe tunnels with swim physics | the light wall speeds up exactly when you stop to loot | L40 THE CORE |

### Per-level machine recipes (levels 5-19, 21-25; tier 1-4; lanes 2 or 3; BOSS = enclosed tunnel)
5 BORER boss, t2, 2 lanes tunnel, fast belt | 6 ENDURANCE t1 2 lanes, first jets | 7 CINDER RUN t2 flame grates + furnace end | 8 SCRAPYARD t2 crushers, alt belts | 9 PRESSURE t2 pipe vents as launchers, 3 lanes | 10 MASTER ESCAPE boss flood tunnel, t3 | 11 TRAVERSE t2 ice belts | 12 RISING t2 3 lanes, rising floor | 13 CRYO LANE t3 frost jets + stalactites | 14 GAUNTLET t3 3 lanes, moving platforms | 15 WARDEN boss freezer tunnel, t3 | 16 STORMFRONT t3 wind jets | 17 PRECIPICE t3 3 lanes, shooters | 18 STORM LANE t3 reversing belts + lightning rails | 19 THRESHOLD t4 wind + pendulums | 21 SUMMIT APPROACH t3 zero-g pockets | 22 APEX t4 forge crushers | 23 APEX RUN t4 collapsing roof lane | 24 FINAL PUSH t4 3 lanes, rising lava | 25 DAWN boss collapsing tunnel t4.
Each level also has its own unique PIECE (not just tier numbers) so no two levels play alike; recipes are tuned during phase 3 with owner playtests.

### Owner decisions on ragebait (round 7 answers)
- ONE setting only, no dial: STRONG or WEAK. Default STRONG ("you are strong"): pure torture, PIP trolls, NO hints, nothing helps. WEAK ("you are weak"): ONLY the text changes: no PIP trolling, no taunts, no rank/flex brag text. Level difficulty is identical to STRONG and there are still no hints (owner confirmed). Owner's reasoning: nobody will pick weak because it hits their ego; that is the point.
- So the earlier PIP-trolling setting and CHILL/STANDARD/RAGEBAIT dial are replaced by this single STRONG/WEAK switch.
- Anti-tilt hint valve: REJECTED (no hints in STRONG, ever).
- Ego-payoff features accepted: result card + rank, roll labels + rare rolls, trap-route bonus, seed card to flex/replay. In WEAK the taunts and flex text are off (the cards stay plain).
- Choice UX (confirmed; PLACEMENT UPDATED in round 9b: the pick is shown in the briefing AFTER the tutorial, not at first launch; also in Settings > GAMEPLAY): show "I AM STRONG / I AM WEAK"; picking WEAK asks "ARE YOU SURE YOU ARE WEAK?" (confirm) and shows a small "WEAK" tag on the HUD/result card.
- Because difficulty is identical in both modes, there is ONE balance target (STRONG); the human-like bot fairness bar applies to every roll in both.
- Guardrails unchanged: fair means a human-like bot can clear at least one route in every roll; STRONG is brutal but never unfair.

## Round 8: owner additions + RESEARCH FINDINGS (7 researchers; findings folded in here, no files written)

### Owner additions (this round)
- Escalating, EXTREME trolling: after enough deaths on a hard level (10+) the trolling keeps climbing, up to crude profanity at the extreme tier ("fuck you, ripped your ass between those traps" is fine). HARD LINE: no attacks on the player's family, protected classes (race, gender, sexuality, religion, disability), real people, self-harm or slurs. Mock the PLAY, never the person.
- Memes and reaction images on death, to mock the player.
- Hints: none for anyone; the owner also wrote "1 to 10 lvl is fine" (CONFIRM: none at all, or plain hints only in levels 1-10?).
- Deep research requested (done, below). Next planning section = boss levels per biome (first draft in Round 9).

### Research: what the evidence says, and what changes in the plan
1. Rage-platformer psychology (McMillen/Game Developer, Clark et al. 2009 Neuron, Juul, Steam stats)
   - Super Meat Boy: near-instant respawn, short levels, no death screen; "penalty equals frustration". Its clear screen replays all your attempts at once (the swarm). Celeste: coyote 0.1 s in the source; non-judgmental Assist Mode. Hard-game completion is low and normal: Getting Over It 9.3% reached the summit once, SMB 7.0% beat the game, Celeste 34.6%.
   - Near-misses raise the urge to retry only when the player felt in control; persistence peaks around ~30% near-miss frequency (inverse U; slot-machine data, weak analogy). Players prefer games where they feel responsible for failure.
   - "Fair" = a first-time player can attribute the death to their own input from what is on screen. Hidden traps and off-screen spawns read as cheap (I Wanna Be The Guy is the deliberate exception).
   - Changes: respawn <= 0.5 s (my target; no source gives a number), NO blocking death screen, cause-of-death marker and "died at X%", short levels, a replay swarm of attempts on clear, every real hazard visible before the first death.
2. Escalating taunts (Getting Over It, Stanley Parable, Hades, Dark Souls, Celeste)
   - Foddy started sarcastic, then softened to mostly encouraging because players were already frustrated; players split and some muted him. Hades reacts to cause of death with ~21,000 voiced lines (one character has 75 death-cause responses); specificity beats generic insults. Pitfalls: repeated lines become noise; mocking deaths that FEEL cheap reads as agreeing with the cheat; pure sadism fatigues; a WEAK mode that only mutes audio is not enough (text must be off too).
   - Ladder (deaths per level session, resets on clear or a long break; thresholds shift DOWN on harder levels): T1 deaths 1-2 dry quip, no profanity, speaks ~1 in 3 deaths. T2 3-5 teasing, names the cause or position, mild words. T3 6-9 roast, rule-of-three bits, running gags. T4 10-14 on hard levels (15+ on easy): harsh, full profanity aimed at the play and PIP's own pride (the owner's example style), at most 1 in 2 deaths. T5 15+ or a long streak on one hazard: keeps climbing (owner); research suggests ONE backhanded grudging-respect line after the heaviest roasts as a pressure valve (proposal; owner may keep pure escalation).
   - Controls: no two lines within ~4 s; no repeat within ~20 deaths; 8-12 lines per tier per cause (spikes, fall, jet, furnace/belt, crusher, timer, enemy) plus a generic pool = about 150+ lines; conditional lines (same-spot streak, "so close", first-try clear after a streak = praise callback); lines never delay the respawn.
   - Safety: allowlist/banlist scan of ALL taunt text in CI (family, protected classes, slurs, real people, self-harm); STRONG default; WEAK turns every taunt and flex line off (text, not only audio); a Language toggle strong/bleeped for streamers.
3. Memes on death (ABA Journal, Loeb on Griner v. King 2024, IPWatchdog, NBC, Kotaku on Steam Pepe purge)
   - Famous memes are copyrighted photos/art owned by someone (Success Kid: 8th Cir. 2024, commercial use not fair use; Grumpy Cat $710k; Nyan/Keyboard Cat v. Warner/5th Cell settled; Pepe DMCA purge on Steam; Distracted Boyfriend is a licensed stock photo). Formats/ideas are not copyrightable; specific images are. UK/EU parody exceptions are narrower than people think; Steam/itch can pull a page on a DMCA notice before any merits review. "Everyone uses it" is not a defence.
   - DECISION (recommended): ZERO third-party meme images. Draw our own pixel reaction cards (PIP faces, Trevor faces, original gags in generic formats: reaction panels, caption bars, our own arrows and catchphrases), a library of ~40-60. No film stills, real-person photos, cartoon-character likenesses, captions lifted from known memes, or brand names.
   - Process: asset provenance log (file, author, date, source/licence, proof of creation), licence checklist in the ship gate, takedown readiness (source files kept, quick art-swap patch, second host).
   - Design rule: a reaction card NEVER blocks the respawn; it pops up non-blocking (corner overlay ~1-1.5 s) while the player is already back in control.
4. Ratings and platform rules (ESRB, itch.io docs, Steamworks, YouTube ad rules)
   - Frequent f-words aimed at the player => assume ESRB MATURE (Strong Language) / about PEGI 16 (Super Meat Boy is Teen with Language + Crude Humor; Hotline Miami is M). Answer every questionnaire honestly (Google Play removes for misrepresentation).
   - itch.io: mark mature/adult classification (the profanity rule is unclear; labelling is cheap), say strong language in the description; its guidelines warn that flashing or loud noises may be delisted; HTML5 is click-to-play. Steam: honest Content Survey, gameplay-only screenshots, describe language and scares, accurate AI disclosure. YouTube demonetises strong profanity in titles/thumbnails: keep store art clean.
   - Add: first-launch CONTENT NOTICE (strong language, crude insults aimed at you, sudden scares and loud sounds, flashing) with the STRONG/WEAK pick on the same screen, a Language toggle (strong/bleeped) and a scare toggle. Collect no data (keeps COPPA exposure low).
   - Verify manually before launch (researchers could not load): current Steam hate/harassment rules, the IARC questionnaire, PEGI wording, Twitch rules.
5. Jump scares and safety (W3C WCAG 2.3.1/2.3.2, Epilepsy Foundation review, EBU R128/IESD, Godot web docs)
   - Habituation is fast: vary the form and keep them rare. Startle comes from sudden onset more than loudness. Each scare traces to a player mistake and is signalled by a distinct cue, so players learn it is harmless.
   - FIXED safety limits: at most 3 flashes per second, aim for one flash pair per scare and none repeated within 1 s; prefer cuts to dark or sprite swaps to bright full-screen flashes; no saturated-red flashes; no strobes or stripe/checker patterns; count combined effects (shake + flash + vignette) together; test captures with a photosensitivity analyser (Harding FPA or equivalent) before shipping.
   - Audio: sting true-peak <= -1 dBTP; short-term loudness no more than ~6 LU above the music (my untested guess); duck music ~6 dB for ~300 ms; game mix near -16 LUFS for web. Web: audio starts only after a gesture; Godot 4.3+ web defaults to Sample playback which does not support AudioEffects, so a bus limiter would not work: pre-limit sting files offline or set Stream playback for that bus.
   - Settings: Spooky effects Full / Reduced (no flash, 150 ms+ fade, softer sting, no shake) / Off; Reduce Motion links to it. Cooldown (research says >= 60 s apart, ~3 per level; owner wants more): proposal 20-30 s gap, cap ~6 per level, never during a precision section, always cued.
6. Procedural generation, validator, bots (Kazemi on Spelunky, Yu, Smith/Whitehead Launchpad+Tanagra, Bénard Dead Cells, Isaksen AIIDE 2015, Otaki 2019)
   - Spelunky: guaranteed solution path first, hazards added after by LOCAL rules that do not change topology. Launchpad/Tanagra: rhythm groups joined by rest platforms, sizes clamped to the physics envelope, hazard sizes must be validated against jump height. Dead Cells: constraint matching alone gives no solvability guarantee, so do not rely on it for jets and conveyors.
   - Validator pipeline (adopted): (1) constructive generation inside ~70-80% of max reach; (2) deterministic frame-stepped search over the REAL physics (left/right/jump/dash, quantised holds; state includes jet/belt/trap phase because hazards are time-dependent) = the proven safe route; (3) robustness replay with +-3 frames and +-2 px jitter; (4) human-like noisy bot 300-1000 runs per roll for hazard rates; (5) static lints: stacking cap per screen, sightline >= reaction time + travel, telegraph > 14 frames; (6) re-roll up to 50 times, then fall back to an authored template.
   - Bot model: simple reaction N(230, 40) ms (~14 frames), choice reaction N(330, 60) ms, plan-ahead for predictable timing with input noise sigma 20/40/60 ms = expert/median/novice. Every roll needs a route a NOVICE bot clears >= 50% first try; no single hazard with median-bot failure > 40%. First-attempt pass-rate bands (starting values to tune with human telemetry): Easy >= 97%, Medium 90-97%, Hard 75-90%, Brutal 55-75% (whole room within 5 attempts >= 99/95/85/60%). Timing windows: Easy >= 12 frames, Medium 6-11, Hard 3-5, under 3 only on Brutal and only when predictable.
   - Tests adopted from the pitfalls: stacking across pieces, blind jumps, generator bias (re-run expressive-range histograms after every tuning change), perfect-bot over-approval, "valid but unlucky" rolls (bound the safe route's worst-case first-attempt failure), determinism (same seed = same roll, two-run equality test).
7. Result cards, seeds, labels (Spelunky/Slay the Spire dailies, Isaac/Balatro seeds, Wordle share, Hades heat, MDN/Godot web docs)
   - Seeds: 8 characters, no confusable letters, game version baked in; copy button in try/catch with a manual fallback (web clipboard can fail); daily seed from the UTC date, LOCAL best only (no server; local data can be edited or evicted; Safari clears script data after 7 days; say plainly the boards are local).
   - Result card: time, deaths, route taken, rank vs a par time (par = the bot's route time), personal-best marker; avoid winner-take-all scoring; swarm replay of the attempts on clear.
   - Roll labels: only labels with a visible, verifiable effect (ALL JETS, NO ROOF SPIKES, FAST BELT) plus a LUCKY/BRUTAL tag COMPUTED from the validator's measured pass rate for that roll, so it is honest (research found nothing on how invented luck labels affect engagement). Mutators stay trade-off style (Slay the Spire rework) and are marked on the share string.
   - Optional risk routes: clearly optional, small reward, quick retry (Celeste golden berries), risk visible before committing.

### Decisions to add to the plan from the research
- Respawn <= 0.5 s, non-blocking reaction cards, clear-screen swarm, near-miss target about 30% of deaths.
- 5-tier taunt ladder + conditional lines + 150+ original lines + CI language scan + Language (strong/bleeped) toggle.
- Original reaction-card art only; provenance log and takedown plan in the ship gate.
- First-launch content notice (language, scares, flashing) with STRONG/WEAK; expect M / PEGI 16; honest store questionnaires and tags.
- Scare safety limits fixed (flash, loudness, Reduced/Off); cooldown to agree.
- Validator pipeline + noisy-bot bands as the fairness bar; hazard sizes validated against jump height; determinism test per seed.
- Seed / daily / result card features as above, local-only on web.

### What the owner may be missing (checklist)
Music and sfx identity per biome; accessibility alongside ragebait (scare opt-out, Reduce Motion, aim assist, remappable attack); web audio gesture and Sample-playback limits; test-runtime budget (reachability already takes 10+ min, so bot sweeps need a fast/slow split); level-select tiles for random levels (par, best, seed); Steam achievements (no-death biome, trap routes); streamer mode (bleep + music we own); local death heatmap telemetry (flag-gated); English-only taunts; cosmetics as trap-route rewards; seed versioning; web performance of many tiles and lanes.

## Round 9b (owner): POST-TUTORIAL BRIEFING + BOSS LEVELS MUST PLAY VERY DIFFERENTLY
This supersedes the earlier "first launch" placement of the STRONG/WEAK pick and the tunnel-only boss table below (kept for the biome look).

### Post-tutorial briefing (first-launch chain becomes)
PLAY -> story (skippable) -> TUTORIAL (offered, skippable) -> TUTORIAL COMPLETE -> BRIEFING SCREEN -> level 1. If the player skips the tutorial the briefing still shows before level 1. Returning players never see it again (re-readable from Settings > Gameplay > "How this game works").
The briefing is PIP talking, one skippable screen with 3 short parts:
1. THE TWO MODES: "STRONG (default): pure torture. No hints, no mercy, PIP will roast you, and the more you die the worse it gets. WEAK: no trolling, no taunts, no brag cards. Same levels, same difficulty." Pick: [I AM STRONG] pre-selected, [I AM WEAK] -> "ARE YOU SURE YOU ARE WEAK?" confirm -> WEAK tag.
2. BOSS LEVELS: "Every 5th level is a BOSS. Bosses are NOT normal levels: different rules, different format, far harder. Every attempt re-rolls." (A statement of how bosses work, not a hint about solving them.)
3. CONTENT NOTICE (store-rules requirement from the research): strong language aimed at you, crude insults, sudden scares and loud sounds, flashing; with Language (strong/bleeped) and Spooky effects (Full/Reduced/Off) toggles on the same screen.
The briefing is skippable only by choosing (so the mode is always an explicit choice). Mode is changeable any time in Settings. WEAK/STRONG choice also stored in the settings registry, backup/export and test_settings_integrity.
Each boss level also gets a pre-level BOSS CARD (reuse `BossWarning`): level name + format name + "BOSS" (no solving hints) so the player always knows they are in a different kind of level.

### Boss doctrine: every boss is a DIFFERENT GAME, and far harder than a normal level
- Difficulty bar (owner chose 'Hard, but kinder'): normal machine levels use the Hard band (median-bot per-obstacle first-attempt pass 75-90%). Bosses are clearly harder than normal levels but kinder than Brutal: per-obstacle pass about 65-80%, whole-boss median-bot clear within 5 attempts about 75%; novice bot (sigma 60 ms) within 5 attempts >= 30% (human-passable); the whole level re-rolls every death (owner rule); no checkpoints inside a boss. What makes them feel 'very different' is FORMAT, not only raw difficulty.
- Distinct FORMAT per boss (side-scroll runner, vertical climb, stealth hunt, arena, zero-g drift, M1 duels), distinct controls emphasis, distinct camera, distinct music, a pre-level BOSS CARD, and its own ragebait gag.
- Rewards: boss clears pay the core as usual plus a boss-only cosmetic and a rank card; in STRONG a bigger flex card.

| Boss | Format (what the player DOES differently) | Camera / space | Core loop and ragebait | Fairness proof |
|---|---|---|---|---|
| L5 THE BORER | RUNNER: forced auto-run through the furnace belt tunnel with a drill behind you; you only choose jump / slide / dash / lane | side-scroll, tunnel | belt pushes against you, flame+air jets, spike rows; bait: free-ride lower lane into the furnace; 85 s limit = berserk | machine validator + noisy bot over the whole tube |
| L10 MASTER ESCAPE | FLOOD CLIMB: a vertical shaft, rising water, wall-jumps and crushers; no ground to rest on, only ledges | vertical-follow camera | water rises in surges with a visible gauge/hiss tell; crusher and magnet timings re-roll; bait: a safe-looking ledge that a crusher owns | vertical machine validator (wall-jump + ledge chains) + bot |
| L15 WARDEN'S MILE | HUNT: a freezer hall arena; collect 3 cryo cores while the Warden stalks by sight cone and footstep noise; slide under shelves to hide; light M1 stuns it 1.5 s | single-screen-ish hall, wide | sprinting is loud, hiding spots re-roll, cores re-roll, ice floors; bait: a core in plain sight of the Warden's patrol; exit opens at 3 | arena validator: every core reachable without entering the live cone; noisy bot stealth model |
| L20 TEMPEST | REACTOR ARENA: climb to and ground-pound 4 conductor rods while lightning strikes where you stood 1.25 s ago (owner confirmed: replaces the old L20) | one arena, fixed camera | the storm only punishes camping; rods re-roll in valid slots; bait: the central safe platform that is the strike centre | strike geometry reuse (`storm_director.gd`) + bot |
| L25 DAWN | ZERO-G DRIFT: the whole level is weightless; steer with jets and dash, momentum is the enemy; a collapse front chases | wide, slow drifting camera | momentum overshoot into forge crushers, pendulums, fake End door, roof falls; bait: the fast route is a momentum trap | zero-g physics validator (search over thrust inputs) + bot |
| L30 HIVE-MOTHER | M1 DUEL: arena fight, HP bar, 3 phases; slash drones from vents, expose and hit 3 weak points | arena, fixed camera | steam jets as rides, vent slots re-roll; bait: the "free hit" window that is a spit tell | pattern table vs noisy bot with slash model |
| L35 RIFT WARDEN | PORTAL DUEL: hit it only when it phases in near a portal; gravity flips with a 1.0 s tell | arena with portals | flips re-roll; bait: the portal that returns you to the wrong side | pattern table + portal/gravity validator |
| L40 THE CORE | THREE-GAME FINALE: descent (light wall auto-scroll) -> flooded swim tunnel with current arms -> arena with every mechanic | changes per phase | the light wall speeds up exactly when you stop to loot | per-phase validators; whole-boss bands |

Open for the owner: L20 as the reactor arena; whether bosses should get a unique hint-free "rules card" wording; boss-only cosmetics.

## Round 9: BOSS LEVELS PER BIOME (first draft; owner to react)
Common tunnel rules: boss levels are enclosed tubes (ceiling + floor), clearance >= 240 px so a full jump never bonks; camera clamped to the tube; safe flat segments between phases; arena layout and pattern order re-roll on every death (owner rule); every pattern has a >= 1.0 s tell and a >= 0.6 s safe window after; a novice bot clears each boss >= 20% within 5 attempts and a median bot >= 50%; chase bosses keep the existing time limit and berserk rules.

| Boss | Biome tunnel | Format | Core mechanic and ragebait | Finish |
|---|---|---|---|---|
| L5 THE BORER | Cinder furnace belt tunnel (acid floor) | CHASE (existing auto-run + 4 sparks), enclosed | belt pushes against you, flame+air jet grates, spike rows; bait: free-ride lower lane into the furnace; roof lane has hanging spikes | burst out of the exit shaft before the Borer's drill catches you (85 s limit = berserk) |
| L10 MASTER ESCAPE | Scrapyard tunnel that FLOODS (existing rising water) | CHASE (existing, 5 sparks) | crushers and magnet cranes in time with the rising water; pipes burst as vents; bait: a crusher with a late safe slot | climb the vertical exit shaft above the waterline |
| L15 WARDEN'S MILE | Cryo freezer tunnel | CHASE (existing, 5 sparks) | ice belts, frost jets leave slippery patches, stalactites drop on a shimmer tell; fog only BEHIND you, never hiding what is ahead | the freezer door |
| L20 TEMPEST | open-air storm line (unchanged) | existing lightning boss | lightning aimed where you stood 1.25 s ago | unchanged |
| L25 DAWN | Summit forge tube that COLLAPSES behind you | CHASE (collapse front, 6 sparks) | forge crushers, pendulums, collapsing tiles, zero-g pockets; bait: fake End door, roof lane that falls | the light at the end |
| L30 HIVE-MOTHER | Underworks dry service tunnel | M1 ARENA fight (HP bar, 3 phases) | vents spawn drones to slash; she spits to expose 3 weak points; steam jets as rides; arena slots re-roll | she bursts; the tunnel opens |
| L35 RIFT WARDEN | Rift crystal conduit | M1 fight | portals + gravity flips; it phases in near a portal and is vulnerable only then; flip tell 1.0 s | the portal to the Core |
| L40 THE CORE | Core flooded pipe tunnel (swim) + descent shaft | M1 fight, 3 phases | phase 1 descent with an auto-scroll light wall, phase 2 swim tunnel with current arms, phase 3 arena using every mechanic; the light wall speeds up exactly when you stop to loot | the Core goes dark; the 100-core ending stays the true finale |

Boss validation: chase bosses use the machine validator (route proven + noisy bot over the whole tube); M1 bosses use a scripted attack-pattern table with fixed tells and windows, simulated against the noisy bot with the slash model. Boss taunts (STRONG only): extra callouts on phase change, near-win chokes ("so close"), and defeat.

## Risks to watch
- Bot validation of lane transfers (jet lifts, roof gaps) and conveyor motion is harder than flat chunks: build the validator and piece tests before any level content.
- Rebuilding 20 levels invalidates many staircase-specific tests and the level-specific orb placement (`LevelData.orbs_for`): orbs move to reward nooks; saves are unaffected (keyed by level number).
- Scale: machine framework first, then levels act by act with owner playtests, so a wrong direction is caught early.

## Round 10 (owner): PER-BIOME BOSS DIRECTION. This SUPERSEDES the boss rows of rounds 9 and 9b (L30/L35 are no longer HP-bar duels)

### Global rules from the owner
- Difficulty curve: levels 1-10 let the player chill; ramp through 11-14; from level 15 on it is TORTURE. Marketing/identity line (store page, loading tips, STRONG-mode PIP): "ONLY THE MENTALLY STRONG FINISH THIS GAME." (To sell it, if it is ever sold.)
- HARD RULE: torture but NEVER impossible, in any aspect. It may take 100 tries, but it must be passable.
- Making the rule testable ("100-tries rule"): per-attempt clear probability p of the median human-like bot must satisfy 1-(1-p)^100 >= 95%, i.e. p >= about 3% on every torture level and boss; novice bot p >= about 1% (about 63% within 100 tries); on top of the existing "at least one proven route per roll". Measured by Monte-Carlo bot runs per level/boss, in the gate. Also: at most 2 simultaneous environmental threats; every threat has a tell >= 0.8 s and a safe window (torture floor 0.35 s); at every frame an escape action exists (no forced unavoidable hit). L5 and L10 bosses stay gentle (the "hard but kinder" bar); L15+ use the torture bar.
- Every boss level's theme, tiles AND way of playing must match its biome (each biome has its own tile set and its own movement rules).

### Per-biome design (owner direction + my fill-ins; each is a machine/boss spec)
1. CINDER (L5 THE BORER, gentle): the WHOLE level is over lava under a foggy, full-volcano sky. A lava lake that REACTS every second (a visible heartbeat: bulge + glow, like a volcano about to erupt), eruption cycle with a rumble tell then geysers in fixed lanes; FLOATING tiles on the lava (basalt slabs, obsidian rafts that sink if you linger). Format: runner (auto-run) across the tiles with the Borer surfacing from the lava behind you. Tiles: basalt, obsidian, ember-crack. Play style: rhythm-reading of the heartbeat.
2. SCRAPYARD (L10 THE COMPACTOR, gentle; theme was mine to decide): junkyard mountains, cranes, sparks, gulls in the BG. Tiles: car roofs, shipping containers, tyres (bounce), crates (crumble), chain/grapple points, steel plates a magnet crane yanks. Format: vertical climb up a stacked-wreck tower while a rising flood/compactor and dropped junk (shadow tell) chase you; magnet pulls move ledges. Play style: vertical route-picking, grapple, wall-jump on container sides.
3. FREEZER (L15 WARDEN'S MILE, first torture level): FULLY ice. Ice rules: low friction, top speed is CAPPED at run speed; spamming jump + dash/shift can NOT build extra speed (dash on ice has a longer cooldown and its speed bleeds off, no bunny-hopping); the only way to go faster is visible BOOST tiles (chevron pads). Tiles: ice slabs, snow drifts (slow), cracked ice, frozen pipes, icicles. Format: stealth hunt with the Warden on the ice (it also cannot speed away); sprinting is loud; hiding spots; light M1 stuns. Play style: momentum planning, not twitch.
4. STORM (levels 16-19 + L20 TEMPEST, the owner's favourite): a LIVE STORM director that interrupts the player with an event deck, always passable: lightning (aimed where you stood 1.25 s ago), gust lanes (streamers tell), hail (shadow tell), flying debris (trajectory shown), rain-slick traction loss, flicker blackouts (lightning-lit and tiles keep a faint outline, never invisible), tornado columns with a bounded pull, thunder scares. Intensity ramps over the level; at most 2 events at once; tells >= 0.8 s. Boss L20: reactor arena, 4 conductor rods to ground-pound, the storm at full strength.
5. FORGE (L25 DAWN): like cinder but HEAVY and slow: the whole level is over lava on floating tiles; FLAME VENTS fire from BELOW the tiles on a timer and SLOW you (about -40% speed for ~1.5 s while heated; tile glows orange 1 s before); slowing alone never kills, but with collapsing tiles and crushers it does. Format: tile-hopping rhythm puzzle with a collapse front behind you. (Zero-g drift is dropped from L25; candidate for the Core.)
6. UNDERWORKS (L30 THE MAZE): the boss level is a MAZE of industrial tunnels (pipes, vents), the floor is acid/industrial waste that SURGES at random every 5-6 s (1.0 s hiss tell), a TIMER to escape. Many routes: a fork offers 2 ways to one target; one way can be a lethal trap room (owner: choosing wrong is the player's problem, not the developer's) but EVERY fork carries a readable tell (airflow streamers blowing toward the exit fan, light colour, scorch marks, hiss, sound of the exit). A new maze is generated on every death, guaranteed solvable (spanning-tree maze with a proven route, bot checks the route fits the timer comfortably), with decoy branches (lethal trap rooms and harmless dead ends). Hive-Mother drones in the vents (M1 kills them). Timer: set from tester data: if testers clear in under 60 s, limit = tester time + 1:20 (owner; I will make the formula tunable). Play style: bravery and reading, not execution.
7. RIFT (L35 THE BLACK HOLE): space and black hole; floating tiles drift on CURRENTS (river-style); a black hole chases and keeps coming closer; one mistake and it eats you; in the LAST 10 s it also eats the obstacles (the path clears but the time pressure peaks), freeze for 1 s and you die. Fairness: its speed is capped below the player's best-route speed, the pull is bounded and indicated, the proven route keeps a margin. Tiles: crystal platforms, asteroid rafts, light bridges. M1 breaks debris in the way.
8. CORE (L40 THE ECHO EXAM; owner: figure it out): my proposal, a finale that tests everything learned: five short phases, each REMIXING one biome's rule (cinder heartbeat lava, freezer ice with no speed, storm interruptions, rift black hole chase, underworks maze doors), the reactor chamber re-skinning per phase, PIP's final lines, then the three Core nodes you strike with M1 (slash/pogo) to end it, which triggers the 100-core door logic. Long (about 3-4 min) so I propose phase checkpoints as the ONLY exception to "whole level re-rolls every death" (each phase re-rolls on its own).

### M1's role in bosses (changed)
No HP-bar duels. M1 = drones in the Underworks, debris in the Rift, the three nodes of the Core, stuns in the Freezer, and light use elsewhere.

### Tile sets
Each biome gets its own tile art and behaviour set (listed above) so tiles teach the biome; rule changes (ice cap, forge slow, storm slick, rift drift) are properties of the tile type, not global.

## Round 11 (owner): THE MATHS, "PROVE IT IS NOT IMPOSSIBLE", AND IS IT WORTH 3-5 USD
Owner goals: calculate each level's length and time with maths; prove it is never impossible; only skilled, focused people finish; sell for 3-5 USD, so it must be worth at least 3 USD. All numbers below are DESIGN TARGETS from my model (assumptions marked); the tester build's telemetry replaces them with measured values.

### Model
- T = clear time of one successful attempt (s). p = per-attempt clear probability of a MEDIAN SKILLED HUMAN. f = average fraction of a level completed on a failed attempt (assumed 0.5; whole level re-rolls each death).
- Expected attempts N = 1/p. Expected time to clear = T x (1 + f x (1-p)/p).
- 100-tries rule: P(clear within 100 tries) = 1-(1-p)^100 >= 95% needs p >= 2.95% (about 3%).
- Obstacle budget: for a level with n independent obstacles each passed with prob q_i, p = product of q_i. Requirement p >= 0.03 means sum of -ln(q_i) <= 3.51 ("difficulty budget"; 4.61 for p >= 1%). With 8 obstacles q >= 0.645 each; 12: 0.747; 16: 0.803; 20: 0.839; 24: 0.864. So a long torture level cannot use Brutal-band obstacles (55-75%) throughout: long levels need 80%+ per obstacle, short boss arenas can be nastier per obstacle. The generator spends the budget; the gate rejects any roll above it.
- Level length in pixels (run speed 320 px/s, about 35% of T is waiting/climbing/timing): length_px = 0.65 x T x 256 = about 166 x T. A 55 s level = about 9.1k px (like the old L10), 80 s = 13.3k, 95 s = 15.8k, 120 s = 20k; at 520 px per cell that is 17-38 cells.

### Per-level targets (T, p, expected attempts, expected time incl. failures, P(clear within 100))
| Levels | Kind | T | p | attempts | expected min each | within 100 tries |
|---|---|---|---|---|---|---|
| 1-4 | intro | 45 s | 0.70 | 1.4 | 0.9 | 100% |
| 5 | boss, gentle | 70 s | 0.35 | 2.9 | 2.3 | 100% |
| 6-9 | chill | 55 s | 0.50 | 2.0 | 1.4 | 100% |
| 10 | boss, gentle | 80 s | 0.30 | 3.3 | 2.9 | 100% |
| 11-14 | ramp | 65 s | 0.22 | 4.5 | 3.0 | 100% |
| 15 | boss, torture | 95 s | 0.07 | 14.3 | 12.1 | 99.93% |
| 16-19 | torture | 80 s | 0.10 | 10 | 7.3 | 100% |
| 20 | boss, torture | 110 s | 0.05 | 20 | 19.2 | 99.4% |
| 21-24 | torture | 90 s | 0.08 | 12.5 | 10.1 | 99.98% |
| 25 | boss, torture | 120 s | 0.05 | 20 | 21.0 | 99.4% |
| 26-29 | torture | 85 s | 0.08 | 12.5 | 9.6 | 99.98% |
| 30 | boss maze | 75 s | 0.06 | 16.7 | 11.0 | 99.8% |
| 31-34 | torture | 90 s | 0.07 | 14.3 | 11.5 | 99.93% |
| 35 | boss black hole | 85 s | 0.05 | 20 | 14.9 | 99.4% |
| 36-39 | torture | 95 s | 0.07 | 14.3 | 12.1 | 99.93% |
| 40 | boss echo exam | 210 s (5 phases, phase checkpoints) | 0.04 (whole) | 25 | 45.5 | 98.3% |
Totals (median skilled player, no quitting): levels 1-25 about 2.5 h and about 157 deaths; levels 1-40 about 5.9 h and about 368 deaths. P(clear every level within 100 tries) about 95.6%. By the 2-hour mark a median skilled player is around level 24, so the first 2 hours show lots of content (refund window).

### "Only skilled, focused people finish" (completion model)
Model: after each death a player quits with small probability h (tilt). Chance to finish a level = p / (p + h(1-p)); the game = product over levels. h = 0.2% per death: 73% finish 1-25, 48% finish 1-40. h = 0.5%: 47% / 17%. h = 1%: 22.5% / 3.1%. Real hard games finish about 7-10% of owners (Getting Over It 9.3%, Jump King 9.7%, SMB 7%), so the intended h is about 0.8-1% (finish rate about 3-10% of buyers), which matches "only the mentally strong". Calibrate h from tester data.

### How "never impossible" is PROVEN (all must hold, enforced in the gate)
1. Existence: every roll has a route found by frame-stepped search over the real physics (constructive proof), re-checked with +-3 frame / +-2 px jitter.
2. Probability: Monte-Carlo with the human-like bot (reaction N(230, 40) ms) gives p >= 3% for the median bot and >= 1% for the novice bot on every torture level and boss (the 100-tries rule); sum(-ln q_i) <= 3.51 per roll.
3. Local safety: at most 2 simultaneous threats; tells >= 0.8 s; safe window >= 0.35 s (torture floor); an escape action exists every frame; no hidden hazards.
4. Per-biome extra proofs: maze solvable (spanning-tree route) with the route time <= 60% of the timer; black hole speed < best-route speed with a margin; storm event overlap bounded; ice speed cap applied uniformly.
5. Determinism: same seed, same roll (two-run equality test), so any claim can be replayed.

### Is it worth 3-5 USD? (pricing research summary, URLs in the researcher's notes)
- Benchmarks: VVVVVV about 2.5 h (about 5 USD); Jump King about 10-11 h main (12.99 USD MSRP, low 4.41); Getting Over It median 5 h (8 USD); Pogostuck about 6.99 USD. Heuristic of about 1 h per USD for 3-5 USD games, "too short" is the most common complaint but does little damage to the score.
- Our model: 25 levels about 2.5 h (borderline for 3 USD); 40 levels about 5.9 h (fine for 4-5 USD); plus replay (random rolls, ranks, seeds, daily, endless) extends it. CONCLUSION: do not sell until the 15 new levels exist (or sell at 2.99 USD); target 4.99 USD (3.99 if content lands near 3 h).
- Net per sale (before refunds): Steam 30% cut: 2.10 / 2.80 / 3.50 USD at 3 / 4 / 5 USD (less with VAT inside the price: 1.75 / 2.33 / 2.92). itch.io default 10% + processor: 2.31 / 3.18 / 4.06. Steam Direct fee 100 USD, recouped at 1,000 USD revenue (about 200 sales at 5 USD).
- Refunds: Steam refunds within 14 days AND under 2 hours; games under 5 USD average about 8% refunds, average playtime under 2 h about 12.6%, rage-viral Paddle Paddle Paddle about 21%. Risk: the torture onset at L15 (about 40-60 min in) is where rage-quitters refund. Mitigations: a free web demo/itch build of levels 1-10, an honest store page about difficulty, strong first hour, plan for about 8-15% refunds.
- Marketing: rage games spread through streamers (Jump King, Only Up); no data that "only the strong finish" taglines raise conversion, treat as a hook, not a plan. Platform risk: Only Up was delisted.

### Telemetry the tester build must capture (to replace the model)
Per level and boss: attempts, deaths, time per attempt, clear time, seeds, cause of death, quit points, p estimates; export as a copyable report. This also calibrates the Underworks timer and the h (quit) parameter.

## Round 12 (owner answers to the 15-question list) - SUPERSEDES conflicting items above
1. Cinder heartbeat/eruption cadence: confirmed.
2. Scrapyard compactor/flood tower: confirmed; ADD walls with hazards (wall spikes, saw/steam walls on the container and car-stack faces; wall-jump surfaces that can bite).
3. Freezer: NO speed cap and NO dash/jump special rules (supersedes the cap in round 10). Ice is just slippery tiles: low friction, long slides, dashing on ice can send you off an edge. Environment variables only (friction, acceleration, snow drag, crack ice), applied by tile type to all ice tiles.
4. Storm event deck: confirmed. NEW: because M1 exists the player gets a HEALTH BAR (see "Health system" below), drawn in a corner under the level-name text, with creative pixel art, and the current pixel art gets an upgrade pass.
5. Forge: -30% speed (supersedes -40%) for ~1.5 s on a heated tile. RULE: heat slow must never let a chaser catch the player: slowed player speed >= chaser/collapse-front speed x 1.15 everywhere in the validator (or chasers get slowed by the same heat). Zero-g goes to the Core.
6. Underworks maze, CLARIFIED: the maze TOPOLOGY and the correct route are FIXED per level (authored): e.g. fork 1: 1 wrong, 1 right; fork 2: 3 wrong, 2 right (the owner's example), identical every attempt, no matter how often you die. Every wrong path is VISIBLE (you can see where it leads). What re-rolls on each death is the rooms' content: obstacles, hazards, acid surge timing, tile variants, enemy positions. The validator proves that the fixed correct route is passable with every rolled content (and that wrong routes are lethal or time-wasting but fair). So knowledge carries between deaths (bravery and memory), execution is re-rolled. Timer stays tester-calibrated (limit = tester median + 1:20 when testers clear in under 60 s; tunable).
7. Rift black hole: confirmed (about 85% of best-route speed; last 10 s eats hazards only).
8. Core Echo Exam with phase checkpoints: confirmed.
9. Difficulty curve: GRADUAL, noticeable but never sudden: a smooth per-level difficulty parameter (log-linear anchors on the per-attempt clear probability p of the median skilled player: L1 0.72, L10 0.40, L15 0.20, L25 0.08, L40 0.045; bosses x0.8 at L5/L10 and x0.55-0.7 later, floor 4.5% so every boss clears within 100 tries about 99%). The step between any two consecutive levels is small (about 3-12%), bosses are the only visible bumps. Recomputed totals with this curve: levels 1-25 about 1.9 h and about 121 deaths, levels 1-40 about 6.1 h and about 396 deaths; time at L15 about 31 min in, at L25 about 1 h 52 min; quit hazard h = 0.8% per death gives about 40% finishing 1-25 and about 5% finishing all 40 (target 3-10%). (The old step table in round 11 is replaced by this curve; to keep levels 1-25 above ~2.5 h I may lengthen T by about 25% or add content per level.)
10. Taunts: the owner WILL review the extreme tier lines (one file before testers). Each tier has its OWN unique lines. Extreme tier: swears allowed (fuck, shit, ass, damn, hell...), mocking and teasing aimed at the player's play in a fun way. BANNED outright in the CI scan: "motherfucker", "son of a bitch", any mother/family/parent reference, any slur or protected-class insult, gendered insults (bitch, cunt), real people, self-harm. Tone = teasing, not abuse.
11. Art and audio: my call (pixel art via the Python generators, synthesised audio); the owner reviews contact sheets.
12. Tester build: logging + copyable report, Windows AND web.
13. Order: the 25-level rebuild (5-19, 21-25 as machines, plus systems) is today's job; then the 15 new levels. I keep working autonomously; the owner manages time.
14. Branches: tester builds may live on separate branches (tester-N branched from v2-redesign); v2-redesign stays the main branch containing everything.
15. Gate first: approved ("ok run"), done as step 0 when execution starts.

### Health system DECISIONS (owner, round 12b)
- 3 HP cells; chip damage (1 HP, 1 s invulnerability, knockback) from enemies, spikes, jets, shooters, steam and similar; lava, acid, crush, void, black hole and drowning stay INSTANT death.
- Healing: FULL HEAL on respawn and FULL HEAL when a core (orb) is collected; if HP is already full, nothing happens. Orbs sit in optional reward nooks, so healing is a risk/reward bait.
- HP applies everywhere (old machine levels and new acts), tutorial included in a gentle form.
- Art: "suit-energy cells with cracking glass" in a pixel visor frame, in the top-left corner under the level-name text: cyan glowing cells that crack/flicker when hit, amber on the last cell.
- Art upgrade scope for this run: HUD + player (sprite, attack slash) + the new biome tile sets for the 25 levels; backgrounds and UI icons get a lighter pass.
- Maths impact: a chip hazard now needs 2-3 hits to kill, so its per-obstacle failure is not one hit: the validator models HP (the bot may take up to 2 chip hits), the budget sum(-ln q) is computed on instant-kill and 3rd-hit events; kill hazards count fully. Chip hazards give more room for ragebait on stacking (3 jets in a row) while staying passable. Targets p in the table above are for the HP-enabled game.

### Health system (original draft, kept for reference)
M1 plus enemies needs player HP. Draft: HP shown as a pixel-art bar/cells in the top-left corner just under the level-name text (creative art: e.g. suit-energy cells with cracking glass), damage from enemies and some hazards (chip damage with 1 s invulnerability and knockback), instant-kill hazards stay instant (lava, acid, black hole, crush, void). Fairness maths changes: each chip hazard now has a second chance, so its q goes up; the validator must model HP (the bot may take N hits). Open: how many HP, which hazards chip vs kill, regen/pickups, whether HP applies to machine levels or only M1 acts, how this interacts with ragebait feel and the 3% budget.

## APPENDIX A: PIP TAUNT LINES FOR OWNER REVIEW (STRONG mode only; WEAK shows none)
Rules: mock the PLAY in a fun teasing way; swears allowed from tier 4; BANNED: motherfucker, son of a bitch, any mother/family/parent reference, slurs, gendered insults (bitch, cunt), bastard, real people, self-harm. {n}=deaths this level session, {pct}=progress at death. Each tier has its own pool; final game needs about 150+ (this is the review sample, about 90).

T1 deaths 1-2 (dry, no profanity, speaks about 1 in 3):
- Noted. / That was a choice. / The floor remains undefeated. / Interesting. Wrong, but interesting. / Respawning. Dignity not included. / One. / I will pretend I did not see that.

T2 deaths 3-5 (teasing, mild words, names the cause):
- generic: Death number {n}. I am keeping a spreadsheet. / You and this spot are becoming close friends. / Bold strategy. Let us see if it pays off. (It did not.) / Have you tried not dying? Just an idea.
- spikes: The spikes did not even move. That is the part that hurts.
- fall: Gravity: 1. You: still 0.
- jets/fire: It was literally glowing. Literally.
- lava/acid: That is lava. It is hot. Everyone knows this.
- crusher: It went down. You were under it. Physics is not a mystery.
- timer/chase: The thing behind you is better at being behind you than you are at being ahead.
- enemy: Beaten by something with no legs. Hm.
- storm: Lightning has a schedule. You were not on it.
- ice: Ice is slippery. Shocking, I know.

T3 deaths 6-9 (roast, rule of three, running gags, mild swears "ass/hell/damn"):
- generic: {n} deaths. At this point the level is just a pet that bites you. / I have seen toasters with better timing. / You are not stuck. You are committing to the bit. / My sensors say skill issue. My sensors never lie. / You jumped early, you jumped late, and you jumped like you hate your own thumbs. / Is your controller plugged in, or is that on purpose?
- spikes: Spikes. Stationary. Same place as last time. Damn.
- fall: You walked off the edge like it owed you money.
- jets/fire: Orange. Loud. Hissing. You saw it, right? Right?
- lava/acid: Swan dive into the hot stuff, take {n}. Judges say: ten out of ten for commitment.
- crusher: Crushing is its entire job and you let it have it.
- enemy: Killed by a drone. I am putting that in your biography.
- ice: The ice did not push you. You did the sliding. You did that.

T4 deaths 10-14 on hard levels (15+ on easy) (harsh, full profanity, aimed at the play and PIP's pride):
- generic: {n} deaths. Holy shit, that is actually impressive. / Damn. You died to that? A toddler would have dodged that out of spite. / You are fucking up this section with real dedication. / I have seen ass-kickings with more dignity than this. / That was not a mistake, that was a performance. Standing ovation, for fuck's sake. / Your thumbs are filing a complaint. Against you.
- progress: {pct} percent and you ate shit. Beautiful.
- spikes: Spikes. Not moving. Exactly where they were. And still, shit.
- fall: You stepped off the edge like gravity needed the help. Fuck.
- jets/fire: Fire. Orange. Loud. Fuck me, you walked into it.
- lava/acid: Face first into the hot shit again. Bravo.
- crusher: It crushes. That is its whole job. You were the job.
- timer: Time ran out because you spent it dying. Efficient as hell.
- enemy: Killed by a fucking drone. I am framing this.
- storm: Lightning telegraphs. You stood there like a lightning rod. Fucking lightning rod.
- ice: Slippery tiles. Shocking. Slide, slide, shit.
- maze: You picked the wrong door. There were so few doors. Fuck.
- black hole: The black hole ate you. It does not even have a mouth. Think about that.

T5 deaths 15+ or a long streak on one hazard (keeps climbing; swears, teasing, never about family or the person):
- generic: {n}. Fucking {n}. I stopped counting at twelve and kept counting anyway. / You have reached the part of the game where I have no shits left to give and you have no tries left to waste. / The level is not hard. You are just consistently, creatively, spectacularly wrong. Every. Fucking. Time. / Do you want this, or do you want to feed the spikes? I cannot tell, and neither can the spikes. / That death was so bad I am sending it to the other AIs for fun. / Go ahead, try again. I am not mad. I am recording this for science. Shitty science. / This spot has your name on it. Not literally. Yet. / Stubborn idiot. Keep going. / Absolute disaster. Beautiful. Again. / Holy fuck, you got further. I am as surprised as you are. Do not get cocky.
- same-spot streak: Same spot. Again. The spot loves you. / If this was a relationship, the spot would have a restraining order.
- so close ({pct} >= 90): {pct} percent. So close it is insulting. / {pct} percent and you fucked it. That is a special kind of talent.

Callbacks (STRONG only):
- clear after a streak (T3): ...Fine. That was clean. / (T4-T5): Holy shit, you did it. Do not tell anyone I was impressed.
- level clear: Cleared. In {n} tries. I will allow it.
- boss phase change: Phase two. You thought phase one was the hard part. Cute.
- boss near-win: So close to winning. Please do not choke. ...You choked.
- boss defeated: The boss is dead. Your dignity? Debatable.
- level start on torture levels (loading tip / briefing): ONLY THE MENTALLY STRONG FINISH THIS GAME.

Reaction card concepts (original pixel art, shown non-blocking after a death, tier-matched): PIP smug, PIP bored, PIP shocked, PIP facepalm, PIP slow clap, PIP glitch-laugh, tiny violin, skull with sunglasses, NEXT banner, SKILL ISSUE banner, Trevor crying visor, Trevor rage shake, a lone tombstone with a participation ribbon, "{n} DEATHS" scoreboard flip, a slideshow of your last attempts (swarm).

## Decided in round 8 (owner)
- Hints: NONE at all (no hints in any level; tutorial text only).
- Memes: original pixel meme-style reaction cards only (~40-60); no third-party images.
- Jump scares: 20-30 s apart, ~6 per level cap, only on mistakes (and a few safe-place feints), never during a precision section, always cued; flash/loudness safety limits fixed; Spooky effects Full/Reduced/Off.
- Taunt ladder top tier: keep escalating forever (no pressure-valve line).

## Open questions
None blocking. Decided in round 9b: briefing after the tutorial (confirmed), L20 becomes the reactor arena, boss difficulty = hard but kinder than Brutal (about 75% median-bot clear within 5 attempts).
Planning is not over until the owner says so.
