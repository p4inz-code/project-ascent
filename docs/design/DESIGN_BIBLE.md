# Project Ascent v2 — design bible

This is the plan every phase is built and tested against. Nothing here is
aspirational filler: each section ends in something that can be checked. Change
this document *first* if the design changes.

**Fixed decisions** (from the owner): sci-fi + pixel art, strictly · desktop and
web only, no mobile · the v2 branch keeps v0.14.x shipped until v2 is ready ·
story first, then everything else one phase at a time · placeholder art is
generated now and replaced later without code changes.

## 1. Pillars

1. **Instant, honest controls.** Every press does something visible, or says why not.
2. **One world, strictly sci-fi pixel art.** UI, world, story and sound all belong to THE SPIRE.
3. **Fair randomness.** Random never means unfair: every random outcome is provably passable.
4. **Every boss is a different game.** No two share a mechanic.
5. **Teach by doing.** No wall of text; the first minutes teach through play and PIP.

## 2. The world: THE SPIRE

A tower-station outside time. Five acts = five zones, climbed bottom to top.

| Act | Levels | Zone | Look | Hazard focus | Level-complete transition |
|---|---|---|---|---|---|
| I | 1–5 | **Dock** | steel hangar, amber lamps | gaps, wall-jump basics | **Airlock cycle** |
| II | 6–10 | **Foundry** | forges, pipes, lava | lava, blades, timing | **Heat-flash dissolve** |
| III | 11–15 | **Cryo Lab** | ice, glass, cold blue | ice, slick, crumble | **Frost wipe** |
| IV | 16–20 | **Storm Array** | antenna forests, lightning | wind, shock, pendulums | **Warp-streak jump** |
| V | 21–25 | **Apex** | open sky, dawn | everything, tight | **Dawn ascent** |

Difficulty curve (owner): levels 1–5 easy; 6–15 climb 5–10% per level; 16+ "very
violent" but always possible. Verified by the reachability + rhythm suites.

## 3. The hero: Trevor + PIP

Astronaut, white suit with the player-colour ramp, visor, amber scarf-cable,
backpack. **PIP**: a small amber diamond drone-light that hovers near his helmet
and speaks in captions.

**Animation set** (frames @ fps), all required before Phase 2 is done:
idle (6 @ 6) · breathe-look (4 @ 6, plays after 4 s idle) · run (8 @ 14) ·
skid (2 @ 10) · jump-rise (2 @ 8) · apex (1) · fall (2 @ 8) · land (3 @ 16) ·
wall-slide (2 @ 8) · wall-jump (3 @ 14) · dash (3 @ 20) · slide (2 @ 12) ·
ground-pound (3 @ 14) · spin (6 @ 24) · grapple (2 @ 10) · ledge-grab (3 @ 10) ·
hurt (2 @ 12) · death (8 @ 14) · respawn (6 @ 14).

## 4. Feel ("highest sensitivity")

Reference (Celeste source, MIT): time-to-max-run ≈ 0.09 s, stop ≈ 0.225 s, air
control 65%, jump grace 0.1 s, variable jump 0.2 s, dash 0.15 s.
Ours today: accel 0.08 s, **stop 0.06 s** (abrupt), air accel 0.12 s, coyote 0.10,
buffer 0.10.

Delivered in Phase 1:
- **120 Hz physics** with interpolation (half the input-to-motion latency).
- **Feel presets** in Settings: *Precise* (Celeste-like stop), *Snappy* (default),
  *Instant* (zero-ramp turn, widest buffers).
- Buffers widened (coyote 0.12, jump buffer 0.14), **corner correction** on jump
  bonks, **wall-jump grace**, instant turn-around option.
- **Rebinding** (it was promised and never built) and gamepad dead-zone control.
- Test: input→motion latency is asserted in frames, per preset.

## 5. Tiles

Each special tile has a **colour and a pattern** so it reads without colour:

| Tile | Look | Rule |
|---|---|---|
| Stone | brick, act-tinted | solid |
| Crumble | cracked, dust motes | falls after 0.4 s |
| Ice | pale blue, glint stripes | low friction |
| Sticky | green-brown, drips | slows |
| Conveyor | chevrons, animated | pushes |
| Bounce | spring coils | launches |
| One-way | dotted top | pass from below |
| Timed | hazard-striped, blinks before change | on/off cycle |
| Shock | blue arcs | lethal on contact, telegraphed |
| Trap-slot (armed/safe) | see §6 | random per attempt |

## 6. Random traps that are always passable

A **trap group** is authored with N **slots** (positions on safe footing) and a
rule *"arm K of N each attempt"*. The armed set is re-rolled every respawn.

Guarantee (by construction + test):
1. A group is only valid if the level is passable under **every** K-subset of N.
2. A test **enumerates all subsets** of every group and runs the reachability
   check for each. A group that fails any subset fails the build.
3. N is small (≤ 5) so exhaustive checking is cheap.

Slots are telegraphed: unarmed slots look like plain tiles with a faint
rivet pattern; armed slots show their pattern only on approach (so the player
reads the room, not the die roll).

## 7. Lava and the void

**Lava** becomes a pool, not a pillar: dark crust rim, a waving bright surface
(sine-offset top rows), rising bubbles that pop, embers drifting up, a pulsing
glow that lights nearby tile edges, and heat shimmer. Pixel-quantised.

**The void.** Today one death floor sits at the level's lowest platform. v2:
- a **local death line** ~2 player-heights (~110 world units) below the nearest
  platforms under the player, so a fall never lasts long;
- the visible "floor" is drawn at that line;
- long empty horizontal stretches between platforms are shortened in the level
  pass; the reachability + rhythm suites re-verify every change.

## 8. Bosses — five different games

| Level | Name | Mechanic |
|---|---|---|
| 5 | **The Borer** | *Cave run:* auto-run, flat plain platforms, jump/slide/dash obstacles, a drill machine chasing |
| 10 | **Breach** | *Flood climb:* forced upward scroll, rising coolant, route choices |
| 15 | **Warden** | *Gravity arena:* flip gravity on pads, dodge a sweeping sentinel beam |
| 20 | **Storm Core** | *Reactor:* rotating platforms, ground the core by reaching its nodes in order |
| 25 | **Dawn Gate** | *Collapsing spire:* every verb, collapsing route, the story's finish |

Each boss level gets its own tutorial beat from PIP and its own music layer.

## 9. Level-complete transitions

Per act (see §2). Rules: **input is locked from the moment the goal is touched
until the next level is live**, the transition is ≥ 1.2 s and ≤ 2.5 s, it can't be
skipped into a stuck state, and a test asserts no gameplay input moves the player.

## 10. Tutorial

A short opening level (before Level 1) taught by PIP: run, jump, variable jump,
dash, slide (with the "run first" rule shown), wall-jump. Each beat waits for the
action, praises it, and moves on. Skippable. Replayable from the title.

## 11. UI/UX architecture

- **Title:** a live, playable pixel scene behind a framed logo and menu
  (PLAY · TUTORIAL · STORY · SETTINGS · ABOUT · QUIT-on-desktop-only).
- **Pages, not overlays.** SETTINGS, ABOUT and STORY each open a full page
  (Minecraft-style): textured backdrop, centred column of wide controls, a DONE
  button, tabs for Controls / Audio / Video / Gameplay.
- **Pause menu:** its own design, a "suit computer" panel that dims but does not
  hide the action. **Controls page:** keyboard and gamepad diagrams with rebinding.
- **Style:** one pixel grid (PX = 3 UI units), 1-px bevels for button states,
  nine-slice panels, small palette, no smoothing, optional scanline/CRT with an
  **off switch** (accessibility).
- **Every screen** is reachable and operable by keyboard and gamepad.

## 12. Definition of done, per phase

| Phase | Done when |
|---|---|
| 0 Story + bible | storyboard and this bible committed |
| 1 Foundation | feel presets + latency test pass · pages for Settings/About/Story · rebinding works · pause + controls redesigned |
| 2 Hero | all animations in §3 exist and are selected by state, tests cover state→animation |
| 3 World | lava, void line, tiles, trap slots (with the exhaustive-subset test) |
| 4 Levels + bosses | levels reshaped, five distinct boss levels, full reachability + rhythm gate green |
| 5 Story + transitions | cutscene matches the storyboard, per-act transitions lock input |
| 6 Audit | full gate green, playtest notes triaged, copy/docs corrected (incl. rebinding claim) |

**Release plan:** publish a playable v2 alpha on itch after Phase 3 with a
devlog; ship v2.0 after Phase 6. `main` keeps v0.14.x until then.
