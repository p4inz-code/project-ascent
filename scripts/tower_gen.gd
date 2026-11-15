# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name TowerGen
extends RefCounted
## THE COMPACTOR (level 10): a vertical climb up a scrapyard tower while the flood rises behind you.
## Rolled fresh on every attempt like every machine level, and built so that every roll is passable:
##  * every step is a jump the simulator measured with a timing window of at least MIN_WINDOW frames
##    (tests/test_tower.gd proves this on real geometry, ceilings included, for many seeds);
##  * turns at the walls use a wider leap, still inside the measured window;
##  * the flood is slower than a calm climb (FLOOD_MARGIN): it is a pace-setter, never a trap;
##  * junk drops are cyclic with a one second shadow tell, never cover a whole platform, and only chip.

const LEVEL := 10
const W := 1600.0                 # inner width of the shaft
const PLAT_T := 24.0
const FLOOR_Y := MachinePieces.FLOOR_Y
const STEPS := 30
const MIN_X := 90.0
const MAX_X := 1510.0
const DY_MIN := 64.0
const DY_MAX := 76.0
const GAP_MIN := 70.0
const GAP_MAX := 105.0
const WIDTH_MIN := 170.0
const WIDTH_MAX := 215.0
const OVERHANG := 90.0            # a turning platform covers this much of the platform two below
const SECONDS_PER_STEP := 0.95    # the calm climbing pace the flood is measured against
const FLOOD_MARGIN := 0.55        # the flood may be no faster than this share of the calm pace
const FLOOD_GRACE := 3.5
const MIN_WINDOW := 5             # jump timing frames every step must have
const JUNK_EVERY := 2
const JUNK_W := 84.0


static func is_tower(level: int) -> bool:
	return level == LEVEL and not MachineLevel.suspended


static func roll(level: int, seed: int, _boss_factor: float = 1.0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, level, 4242])
	var plats: Array = []          # {"rect": Rect2, "turn": bool}
	var dir := 1
	var y := FLOOR_Y
	# The first platform: right of the spawn, one step up from the floor.
	var x1 := 250.0
	var prev: Rect2 = Rect2()
	for i in STEPS:
		var dy := rng.randf_range(DY_MIN, DY_MAX)
		y -= dy
		var w := rng.randf_range(WIDTH_MIN, WIDTH_MAX)
		var gap := rng.randf_range(GAP_MIN, GAP_MAX)
		var r: Rect2
		var turn := false
		if i == 0:
			r = Rect2(x1, y, w, PLAT_T)
		else:
			var nx: float
			var below: Rect2 = plats[i - 2]["rect"] if i >= 2 else prev
			if dir > 0:
				nx = prev.end.x + gap
				if nx + w > MAX_X and i >= 2:
					# turn at the right wall: C goes back left and ends OVERHANG short of the right edge
					# of the platform below the one it leaps from, so that platform keeps a free takeoff
					dir = -1
					turn = true
					r = Rect2(below.end.x - OVERHANG - w, y, w, PLAT_T)
				else:
					r = Rect2(nx, y, w, PLAT_T)
			else:
				nx = prev.position.x - gap - w
				if nx < MIN_X and i >= 2:
					dir = 1
					turn = true
					r = Rect2(below.position.x + OVERHANG, y, w, PLAT_T)
				else:
					r = Rect2(nx, y, w, PLAT_T)
		plats.append({"rect": r, "turn": turn})
		prev = r
	# The turn rule: platform i (a turn) must not hang over the takeoff edge of the one two below.
	# Turning at the right wall means going left: it ends OVERHANG left of the takeoff platform's right
	# edge. The simulator window test in tests/test_tower.gd checks the result.
	var top_rect: Rect2 = plats[plats.size() - 1]["rect"]
	var goal_plat := Rect2(top_rect.position.x, top_rect.position.y, maxf(top_rect.size.x, 200.0), PLAT_T)
	plats[plats.size() - 1]["rect"] = goal_plat
	var height := FLOOR_Y - goal_plat.position.y
	var pace := SECONDS_PER_STEP * float(STEPS)
	var flood_speed := height * FLOOD_MARGIN / pace
	# junk drops
	var junk: Array = []
	var fakes: Array = []
	for i in plats.size():
		var r2: Rect2 = plats[i]["rect"]
		if i >= 3 and i < plats.size() - 2 and i % JUNK_EVERY == 0 and not bool(plats[i]["turn"]):
			# the crate lands on the half of the platform away from the way on, so a calm step
			# past it is always free; it is visible from a full platform away
			var nxt: Rect2 = plats[i + 1]["rect"]
			var side := -1.0 if nxt.get_center().x > r2.get_center().x else 1.0
			var cx := r2.get_center().x + side * (r2.size.x * 0.5 - JUNK_W * 0.5 - 8.0)
			junk.append({"x": cx, "y": r2.position.y, "period": rng.randf_range(3.2, 4.0), "tell": 1.0, "active": 0.45,
				"phase": rng.randf_range(0.0, 3.0), "w": JUNK_W})
		# a fake tile: a lookalike shortcut beside a platform, drops when stepped on
		if i >= 4 and i % 7 == 1 and not bool(plats[i]["turn"]):
			var fx := r2.end.x + 38.0 if plats[i]["rect"].end.x + 120.0 < MAX_X else r2.position.x - 38.0 - 90.0
			fakes.append(Rect2(fx, r2.position.y - 34.0, 90.0, PLAT_T))
	# three optional cores floating a short jump above platforms (never turn platforms)
	var cores: Array = []
	var spots: Array = [plats.size() / 4, plats.size() / 2, plats.size() * 3 / 4]
	for k in spots.size():
		var ci: int = spots[k]
		while ci < plats.size() - 2 and bool(plats[ci]["turn"]):
			ci += 1
		var cr: Rect2 = plats[ci]["rect"]
		cores.append({"index": k, "pos": Vector2(cr.get_center().x, cr.position.y - 58.0), "platform": ci})
	var spec := {
		"mode": "tower", "level": level, "seed": seed, "cells": [],
		"recipe": {"biome": "scrapyard", "cells": 0, "checkpoints": false},
		"end_x": W, "tower": {"plats": plats, "goal": goal_plat, "height": height, "flood_speed": flood_speed,
			"flood_start": FLOOR_Y + 260.0, "cores": cores, "grace": FLOOD_GRACE, "junk": junk, "fakes": fakes},
	}
	return spec


## The solid rects of a rolled tower: the base, the walls and every platform (fake tiles are not solid
## to the proof; they are decoys beside the real route).
static func solids_of(spec: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(-60.0, FLOOR_Y, W + 120.0, 60.0),
		Rect2(-60.0, FLOOR_Y - 5000.0, 60.0, 6000.0), Rect2(W, FLOOR_Y - 5000.0, 60.0, 6000.0)]
	for p in spec["tower"]["plats"]:
		out.append(p["rect"])
	return out
