# Machine levels (levels 6-9, 11-14, 16-19, 21-24)

A machine level is one long tube like a conveyor machine. It is rolled again from a new seed on **every
death**, and every roll is **proven passable** before it is built. This file explains how, and where
the proof lives. Planning context: `docs/PLAN_v2_big_run_2026-10-20.md`.

## Shape of a machine

```
 ceiling  y 400  ===========================================  roof spikes hang from here
          deck    ........ deck slab (y 600) with gaps and air-jet holes ........
 floor    y 800  start hinge | cell | cell | cell | ... | jet | tower with the door
```

* The **floor lane** is the conveyor lane: spike rows, humps, lava pits, flame jets, belts.
* The **deck lane** is 200 px above it. You reach it with an **air jet** (the deck has a hole above
  it) and leave it by dropping through a gap. Roof spikes hang over some gaps (a low jump is needed).
* **Cells** are 520 px wide. Every 6th cell is a **calm hinge** in both lanes (same cells in every
  roll, so a checkpoint flag on a hinge is always on safe ground even though the machine re-rolls).
* A **core nook** (a small ledge 85 px above the deck) holds the level's core; collecting it refills the
  health cells. It is optional, so the core is a risk/reward bait.
* **Harmless cued jump scares** follow mistakes (`ScareDirector`, `ScareRules`).

## Where things live

| What | File |
|---|---|
| Player mirror (run, jump, dash, belts, jets, chip damage) | `scripts/machine_sim.gd`, `scripts/machine_world.gd` |
| Piece geometry, one definition for sim and game | `scripts/machine_pieces.gd` |
| The parameter grid the generator draws from | `scripts/machine_kit.gd` |
| Window finding + measured pass probabilities | `scripts/machine_probe.gd`, `scripts/machine_table_data.gd` (generated) |
| The noisy human-like bot | `scripts/machine_bot.gd` |
| Level roll (seeded, constructive, re-roll up to 50x, fallback) | `scripts/machine_gen.gd` |
| Real nodes for a roll | `scripts/machine_runtime.gd`, `spike_row.gd`, `flame_jet.gd`, `air_jet.gd` |
| LevelDef of a machine level | `scripts/machine_level.gd` |

## How "never impossible" is proven

1. **The sim matches the game.** `tests/test_machine_sim.gd` drives the real `Player` and `MachineSim`
   with the same inputs: they agree to under 0.1 px on runs, jumps of every hold length and dashes.
   `tests/test_machine_replay.gd` replays a bot's sim inputs on the real player in the real hazard
   nodes (spikes, flames, jets, pits, belts, gaps, roof spikes): it ends within 3 px with no hit.
2. **Every kit piece has a window.** `MachineProbe` sweeps the physics to find when to jump / how long
   to hold / when to cross a flame / where to stand in a jet. The width of the window is the piece's
   difficulty. No piece used by the generator has a window under 5 frames at the speed it is crossed at.
3. **Pass probability is measured, not guessed.** For each piece the table stores the clean-clear rate
   of the noisy bot (timing error sigma 20 / 40 / 60 ms = expert / median / novice, plus 4 px of
   perception error), 400 seeded runs each. `tools/check_q_model.gd` compares that with direct
   simulation.
4. **The roll's odds.** `MachineGen.best_route` runs a dynamic programme over lane choices and the hit
   counts (3 cells: the third chip hit is death, kill pieces end the run when failed) with those q's.
   A roll is accepted only if the median player clears it at least 3% of the time (the 100-tries rule)
   and a novice clears it at least 1% (0.2% from level 15: see below).
5. **A real route exists.** `tests/test_machine_routes.gd`: a perfect bot runs the chosen best route in
   the sim for 100 rolls across levels 6-25 and reaches the door with no hit; shifting every decision by
   +-2 frames still clears 38 of 40; the noisy bot's measured clear rate is at or above the table's
   prediction (the prediction is slightly pessimistic: it does not credit the invulnerable second after
   a hit).
6. **Determinism.** The same level and seed always give the same machine.

Every behavioural check has a negative control (an impossible piece, a plan outside the window, a
spec that breaks each construction rule).

## Difficulty

`MachineGen.CURVE` holds the recipe curves (density, piece mix, hardness). `MachineGen.p_target` is the
plan's difficulty curve (L1 0.72, L10 0.40, L15 0.20, L25 0.08, L40 0.045). Each roll aims at its own
odds scattered around the target, so some rolls are LUCKY and some BRUTAL (shown on the HUD with the
8-character roll code). `tools/tune_machine.gd` prints mean odds per level.

Findings:

* With Gaussian timing error a novice's odds are roughly the median's odds to the power 2.6, so a flat
  "novice >= 1%" floor would cap the median at about 17%. The floor is 1% up to level 14 and 0.2% after.
* Current first-pass difficulty is gentler than the plan's anchors at the high end (about 0.13 median
  odds at level 25 vs 0.08). Tighter pieces and tester telemetry will calibrate it.

## Regenerating the table

After changing the kit, the sim, or the piece geometry:

```
Godot --headless --path <project> --script res://tools/gen_machine_table.gd
```

`tests/test_machine_pieces.gd` fails while the table is incomplete or stale.
