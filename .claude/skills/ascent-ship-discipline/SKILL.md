---
name: ascent-ship-discipline
description: Working rules for Project Ascent (the Godot rage platformer in F:\PROJECT ASCENT\project-ascent), learned from mistakes that reached the owner in a test build. Use this skill BEFORE building, changing or handing over anything in this project - new levels, bosses, hazards, cores, tiles, transitions, visuals, tests, builds, release candidates - and whenever the owner reports bugs, asks for an audit, a fix round, "launch the game" or "ship". Also use it before any edit made through a shell heredoc and before starting any Godot process.
---

# Project Ascent: ship discipline

The owner tested a build and was "ragebaited by bugs, not by the game". The player must be annoyed by the CHALLENGE and never by sloppy levels, because a sloppy level makes players blame the developer. Every rule below exists because breaking it put a visible defect in front of the owner. The full history, with root causes, is in `docs/BUGS_round1.md`; add to it every round.

## 1. Nothing is "done" until it has been looked at in the real game

Passing a test proves the logic, not the look or the feel. Level 20 passed its suite while it was covered in stray pipes, a flag pole and debris.

- After building or changing anything a player sees, look at it: a captured frame of the real scene, or a headless node audit (`tools/audit_nodes.gd -- <levels>` lists every node class and def extra a level builds). Compare against what the design says should be there, and look for what should NOT be there.
- When the owner sends a screenshot, find the root cause for everything in it, then audit the whole class of that bug across all levels, and re-check the same view after the fix.
- Say plainly what was only tested and what was actually seen. Never hand over a build described as fixed if nobody looked.

## 2. New level kinds must opt out of the classic pipeline

`LevelData.get_level` runs gate placement, vent pipes, crumbling-tile jitter, hazard repair and the old storm on every def that is not `machine` or `scripted`. Any level built by its own director (Tempest, Warden, Hive, and anything new) sets `def.scripted = true`. `tests/test_level_looks.gd` loads the scripted levels six times and fails if anything was added; extend its level list when adding one.

## 3. Depth before breadth

A small room with one mechanic is not a boss, and four levels from one recipe are not four levels. Before calling content finished, check it against the owner's standing complaints:

- Bosses are long, multi-section, and escalate (the Tempest is three sealed sections and eight rods; the Hive is five parts ending in the Mother).
- The four levels of an act are four KINDS with ONE difficulty (`MachineGen.style_for`: RUN, CLIMB, GAPS, TIMING; `p_target` is flat inside an act) and each wears its own tile surface, tint and back wall (`MachineRuntime.tile_for`, `SLOT_LOOK`). New acts need their own tile pattern and transition cover, not a reused one.
- Cores are never in the same spot twice, most of them move, and some sit over hazards. Every one is still provably catchable (`tests/test_orb_motion.gd`).
- No hazard kind spammed; a mix. No stray obstacles.

## 4. Honest visuals

A thing must look like what it does. Frost that looked like ice but was not slippery, and a trap tile with a faint tell, both read as "broken tiles". Give every trap a tell a new player can read, every special surface its own look, and keep art on the pixel grid (3 px art pixels, stepped colour ramps, ticking motion). Smooth shaders and sliding rectangles look pasted on.

## 5. Fair by proof, with a negative control

Torture, never impossible. Every random roll and every fixed arena needs a proof (simulator window, safe-window arithmetic, or a careful-player run) and every test needs a control that shows the check can fail. Hazards chip unless they are lava, acid, crushers or the void; every hazard has a tell of about a second and a safe window. Be exact in claims: "lightning never hits a moving player" was false at turn-arounds; say what is true.

## 6. Do not heat the owner's PC

- One Godot process at a time, headless, at idle priority (`tools/run_some.ps1`). Before starting one, check nothing else is running; kill stale ones.
- No windowed or GPU capture runs unless the owner asked to see something or a visual check is the only way to verify; keep them to a few frames.
- The full gate runs once, on a snapshot copy, on the release candidate, when the owner says the PC is free. Never run the gate on the live tree while editing: it reads the files being changed.

## 7. Editing safely on this machine

- Shell heredocs break on apostrophes and backslash-n, and a failed heredoc can silently apply nothing. Write edit scripts and any file containing apostrophes with the Write tool, run them, delete them.
- After adding a `class_name` script, run `--headless --editor --quit` before any suite, and read its output for "Parse Error": one broken script makes every suite that touches it fail with a misleading message. A duplicate dictionary key once broke compilation of the whole branch.
- Headless tests need `APPDATA` pointed at a temp folder or they write to the owner's real save.
- When changing a shared system (level count, level kinds, save fields), grep the tests for the old assumption and update them in the same change.

## 8. Handing over

- Commit and push at every checkpoint with explicit paths; never tag, release or publish without the owner's explicit approval in that conversation.
- A build goes to the owner only after: the touched suites pass one at a time, the changed things were looked at, and `docs/BUGS_round1.md` (or the current round's file) and `docs/ROADMAP_STATUS.md` say what is done, what is only tested, and what is open.
- Report in plain words, worst news first. If something was cut or is unverified, say so before the owner finds it.
