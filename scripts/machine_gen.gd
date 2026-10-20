class_name MachineGen
extends RefCounted
## Rolls a machine level: a start hinge, a chain of cells with obstacles on a lower lane and an
## upper lane (the deck), air jets that lift you between lanes, belts under some floors, and a tower
## with the door at the end. Everything is drawn from MachineKit's parameter grid, so the proof is
## table lookups:
##
##   * the best route's pass probability for a MEDIAN person (sigma 40 ms) must sit near the level's
##     target (the difficulty curve) and never under the 3% floor of the 100-tries rule;
##   * a NOVICE (sigma 60 ms) must still clear it at least 1% of the time;
##   * the same seed always gives the same roll.
## A roll that misses is thrown away and redrawn (up to 50 times), then an authored calm template
## stands in. tests/test_machine_gen.gd checks all of this over thousands of seeds, and a perfect
## bot (tests/test_machine_routes.gd) actually runs the best route in the simulated physics.

const P_FLOOR_MEDIAN := 0.03
## The novice floor is softer than the median one: for a Gaussian timing error, a novice's odds fall about
## as the median's odds to the 2.6th power (see docs/MACHINE_LEVELS.md), so a 1% novice floor would cap the
## median at about 17% and the curve could never reach its late-game targets. Up to level 14 it is 1%.
const P_FLOOR_NOVICE := 0.01
const P_FLOOR_NOVICE_LATE := 0.002
const MAX_REROLLS := 50
## No piece may have a window narrower than this many frames at the speed it is crossed at.
const MIN_WINDOW_FRAMES := 5.0
## Every 6th cell is a calm hinge in both lanes: the same cells in every roll of a level, so a
## checkpoint flag on a hinge is always on calm ground even though the machine re-rolls.
const HINGE_EVERY := 6
## Per-attempt clear probability of the median player, log-linear between these anchors.
const ANCHORS := [[1, 0.72], [10, 0.40], [15, 0.20], [25, 0.08], [40, 0.045]]


## The target pass probability for a level number (before the boss factor).
static func p_target(level: int) -> float:
	var a := ANCHORS
	if level <= int(a[0][0]):
		return float(a[0][1])
	for i in range(1, a.size()):
		if level <= int(a[i][0]):
			var l0 := float(a[i - 1][0])
			var l1 := float(a[i][0])
			var p0 := log(float(a[i - 1][1]))
			var p1 := log(float(a[i][1]))
			return exp(p0 + (p1 - p0) * (float(level) - l0) / (l1 - l0))
	return float(a[a.size() - 1][1])


## The recipe curves: [value at level 5, value at level 25], interpolated by level.
const CURVE := {
	"density_l": [0.90, 1.00],
	"density_u": [0.80, 1.00],
	"hardness": [0.85, 1.30],
	"belt_p": [0.10, 0.40],
	"flame_w": [0.5, 1.4],
	"spikes_l": [0.55, 0.85],
	"hump_l": [0.08, 0.0],
	"pit_l": [0.15, 0.05],
	"gap_u": [0.20, 0.02],
	"rspike_u": [0.30, 0.40],
	"spikes_u": [0.35, 0.55],
	# the longest run of obstacle cells in one lane (a calm cell must follow)
	"max_run": [2.0, 3.99],
}
## Biome flavour of a level: which extra pieces and floors its machine uses.
##   crusher_l / flame_l: shares of floor pieces that are pistons / flames (the rest is spikes, humps, pits)
##   hail_u: share of deck pieces that are hail columns
##   surface: the slippery floor kind ("" none) and surface_p: the chance a floor run is slippery
##   no_flame: true removes flames entirely (a waiting player would slide into them on ice)
const BIOMES := {
	"cinder": {"crusher_l": 0.0, "flame_l": 0.20, "hail_u": 0.0, "surface": "", "surface_p": 0.0},
	"scrapyard": {"crusher_l": 0.30, "flame_l": 0.05, "hail_u": 0.0, "surface": "", "surface_p": 0.0},
	"freezer": {"crusher_l": 0.0, "flame_l": 0.0, "hail_u": 0.0, "surface": "ice", "surface_p": 0.60},
	"storm": {"crusher_l": 0.0, "flame_l": 0.0, "hail_u": 0.24, "surface": "slick", "surface_p": 0.40},
	"forge": {"crusher_l": 0.20, "flame_l": 0.22, "hail_u": 0.0, "surface": "", "surface_p": 0.0},
}


static func biome_of(level: int) -> String:
	if level <= 5:
		return "cinder"
	if level <= 10:
		return "scrapyard"
	if level <= 15:
		return "freezer"
	if level <= 20:
		return "storm"
	return "forge"


## Overrides of CURVE entries for tuning runs (tools/tune_machine.gd); empty in the game.
static var tuning: Dictionary = {}


static func _curve(key: String, u: float) -> float:
	var pair: Array = tuning.get(key, CURVE[key])
	return lerpf(float(pair[0]), float(pair[1]), u)


## Recipe for a level: how long it is, how dense, how nasty. A recipe is plain data.
static func recipe_for(level: int) -> Dictionary:
	var t_clear := 55.0
	if level >= 11:
		t_clear = 65.0
	if level >= 16:
		t_clear = 80.0
	if level >= 21:
		t_clear = 90.0
	var cells := int(round(166.0 * t_clear / MachinePieces.CELL_W)) + 2
	var u := clampf((float(level) - 5.0) / 20.0, 0.0, 1.0)      # 0 at level 5, 1 at level 25
	var r := {
		"level": level,
		"cells": cells,
		"p_target": p_target(level),
		"density_l": _curve("density_l", u),
		"density_u": _curve("density_u", u),
		"hardness": _curve("hardness", u),
		"belt_p": _curve("belt_p", u),
		"flame_w": _curve("flame_w", u),
		# floor piece mix: spikes, hump, pit, (rest flame)
		"mix_l": [_curve("spikes_l", u), _curve("hump_l", u), _curve("pit_l", u)],
		# deck piece mix: gap, roof spikes, spikes, (rest hump)
		"mix_u": [_curve("gap_u", u), _curve("rspike_u", u), _curve("spikes_u", u)],
		"hinge_every": HINGE_EVERY,
		"checkpoints": cells >= 26,
		"max_run": int(_curve("max_run", u)),
		"biome": biome_of(level),
		"geyser_share": 0.35,
	}
	if MachineLevel.is_runner(level):
		# an auto-running player covers 320 px/s, so about 60 s of it is 36 cells
		r["density_l"] = 0.75
		r["cells"] = 36
	return r


# --- cell drawing -----------------------------------------------------------------------------

static func _pick_width(rng: RandomNumberGenerator, options: Array, hardness: float) -> float:
	# Wider = tighter window = harder. Hardness picks near the top of the list with a spread.
	var n := options.size()
	var centre := hardness * float(n - 1)
	var i := int(round(centre + rng.randfn(0.0, 0.9)))
	return float(options[clampi(i, 0, n - 1)])


static func _pick_pair(rng: RandomNumberGenerator, options: Array, hardness: float) -> Array:
	var n := options.size()
	var i := int(round(hardness * float(n - 1) + rng.randfn(0.0, 0.9)))
	return options[clampi(i, 0, n - 1)]


static func _low_piece(rng: RandomNumberGenerator, recipe: Dictionary, belt: Variant = null,
		can_hang: bool = true, still_floor: bool = true) -> Dictionary:
	var h: float = recipe["hardness"]
	var m: Array = recipe["mix_l"]
	var bio: Dictionary = BIOMES[recipe["biome"]]
	var r0 := rng.randf()
	# Biome pieces first: pistons and flames only ever sit on a still floor (no belt, no ice).
	if belt == null and still_floor:
		if r0 < float(bio["crusher_l"]) and can_hang:
			return MachineKit.crusher(_pick_pair(rng, MachineKit.CRUSHERS, h), rng.randf_range(0.0, 2.4))
		if r0 < float(bio["crusher_l"]) + float(bio["flame_l"]):
			return MachineKit.flame(_pick_pair(rng, MachineKit.FLAMES, float(recipe["flame_w"]) * 0.7), rng.randf_range(0.0, 2.4))
	# the base mix, renormalised over spikes / hump / pit
	var total := float(m[0]) + float(m[1]) + float(m[2])
	var r := rng.randf() * total
	if r < float(m[0]):
		return _fit_spikes("L", _pick_width(rng, MachineKit.SPIKE_WIDTHS, h), belt)
	if r < float(m[0]) + float(m[1]):
		return MachineKit.hump("L", _pick_pair(rng, MachineKit.HUMPS, h))
	return MachineKit.pit(_pick_width(rng, MachineKit.PIT_WIDTHS, h))


## Spikes at the requested width, or the widest narrower row whose window is still at least
## MIN_WINDOW_FRAMES wide at the speed the player crosses it.
static func _fit_spikes(lane: String, width: float, belt: Variant) -> Dictionary:
	var widths: Array = MachineKit.SPIKE_WIDTHS
	var i := widths.find(width)
	while i > 0:
		var piece := MachineKit.spikes(lane, float(widths[i]))
		if MachineProbe.window_frames(piece, belt) >= MIN_WINDOW_FRAMES:
			return piece
		i -= 1
	return MachineKit.spikes(lane, float(widths[0]))


static func _up_piece(rng: RandomNumberGenerator, recipe: Dictionary) -> Dictionary:
	var h: float = recipe["hardness"]
	var m: Array = recipe["mix_u"]
	var bio: Dictionary = BIOMES[recipe["biome"]]
	if rng.randf() < float(bio["hail_u"]):
		return MachineKit.hail(_pick_pair(rng, MachineKit.HAILS, h), rng.randf_range(0.0, 2.4))
	var r := rng.randf()
	if r < float(m[0]):
		return MachineKit.gap(_pick_width(rng, MachineKit.GAP_WIDTHS, h))
	if r < float(m[0]) + float(m[1]):
		return MachineKit.rspike(_pick_pair(rng, MachineKit.RSPIKE, h))
	if r < float(m[0]) + float(m[1]) + float(m[2]):
		return _fit_spikes("U", _pick_width(rng, MachineKit.SPIKE_WIDTHS, h), null)
	return MachineKit.hump("U", _pick_pair(rng, MachineKit.HUMPS, h))


## Place a piece inside its cell: x is the left edge of the obstacle.
static func _place(rng: RandomNumberGenerator, cx: float, piece: Dictionary) -> Dictionary:
	var p := piece.duplicate()
	var w: float = float(p.get("w", 100.0))
	var lo := cx + 110.0
	var hi := cx + 410.0 - w
	if hi < lo:
		hi = lo
	var x := rng.randf_range(lo, hi)
	p["x"] = x
	if p["k"] == "rspike_gap":
		p["sx"] = x - 20.0
		p["sw"] = w + 40.0
	if p["k"] == "jet":
		p["x"] = cx + rng.randf_range(160.0, 290.0)
		p["hole_x"] = float(p["x"]) - 25.0
		p["hole_w"] = MachinePieces.HOLE_W
	return p


## Where the jets go. Jets avoid the calm hinge cells.
static func _jet_cells(rng: RandomNumberGenerator, n: int) -> Array:
	var jets: Array = []
	var j := rng.randi_range(2, 3)
	while j <= n - 4:
		# Hinge cells (every `hinge_every`) stay free of jets so a checkpoint flag always has calm ground.
		if j % HINGE_EVERY == 0:
			j += 1
		if j > n - 4:
			break
		jets.append(j)
		j += rng.randi_range(4, 6)
	jets.append(n - 2)
	return jets


## The Cinder runner (THE BORER): floating tiles over a lava lake, auto-run, geysers. Same pieces,
## same proofs, one lane and no tube.
static func candidate_runner(level: int, seed: int, variant: int) -> Dictionary:
	var recipe := recipe_for(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, variant, level, 5])
	var n: int = recipe["cells"]
	var cells: Array = []
	var h: float = float(recipe["hardness"])
	for i in n:
		var cx := MachinePieces.START_X + float(i) * MachinePieces.CELL_W
		var cell := {"x": cx, "L": {"k": "plain"}, "U": {"k": "none"}, "belt": null, "surface": ""}
		var calm := i < 2 or i >= n - 2 or (i % 9 == 0)
		if not calm and rng.randf() < float(recipe["density_l"]):
			var piece: Dictionary
			if rng.randf() < float(recipe["geyser_share"]):
				piece = MachineKit.gpit(_pick_pair(rng, MachineKit.GPITS, h))
			else:
				piece = MachineKit.pit(_pick_width(rng, MachineKit.PIT_WIDTHS, h))
			var placed := _place(rng, cx, piece)
			if placed["k"] == "gpit":
				placed["phase"] = MachineKit.geyser_phase(placed, float(placed["x"]), 200.0, 0.04)
			cell["L"] = placed
		cells.append(cell)
	var end_x := MachinePieces.START_X + float(n) * MachinePieces.CELL_W
	return {
		"level": level, "seed": seed, "variant": variant, "recipe": recipe, "mode": "runner",
		"cells": cells, "end_x": end_x,
		"goal": Rect2(end_x - 200.0, MachinePieces.FLOOR_Y - 96.0, 56.0, 96.0),
		"spawn": Vector2(200.0, MachinePieces.FLOOR_Y - 28.0),
	}


static func candidate(level: int, seed: int, variant: int) -> Dictionary:
	if MachineLevel.is_runner(level):
		return candidate_runner(level, seed, variant)
	var recipe := recipe_for(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, variant, level])
	var n: int = recipe["cells"]
	var cells: Array = []
	var jets := _jet_cells(rng, n)
	var first_jet: int = jets[0]
	var run_l := 0
	var run_u := 0
	var belt_left := 0
	var belt_now = null
	var surface_left := 0
	var surface_now := ""
	for i in n:
		var cx := MachinePieces.START_X + float(i) * MachinePieces.CELL_W
		var cell := {"x": cx, "L": {"k": "plain"}, "U": ({"k": "deck"} if i >= first_jet else {"k": "none"}), "belt": null}
		var calm := i == 0 or i >= n - 3 or (i % HINGE_EVERY == 0)
		if i in jets:
			cell["L"] = _place(rng, cx, MachineKit.jet())
			run_l = 0
			run_u = 0
			belt_left = 0
			cells.append(cell)
			continue
		if not calm:
			# belt first: a run of 2-3 floor cells moving one way
			var belt = null
			if belt_left > 0:
				belt = belt_now
				belt_left -= 1
			elif rng.randf() < float(recipe["belt_p"]):
				var speeds := [100.0, 160.0, -100.0, -160.0]
				belt_now = MachineKit.belt_of(speeds[rng.randi_range(0, 3)])
				belt_left = rng.randi_range(1, 2)
				belt = belt_now
			# slippery floor: a run of 1-2 cells (never together with a belt)
			var bio: Dictionary = BIOMES[recipe["biome"]]
			var surface := ""
			if belt != null:
				surface_left = 0
			elif surface_left > 0:
				surface = surface_now
				surface_left -= 1
			elif String(bio["surface"]) != "" and rng.randf() < float(bio["surface_p"]) * 0.5:
				surface_now = String(bio["surface"])
				surface_left = rng.randi_range(0, 1)
				surface = surface_now
			# floor lane
			if run_l < int(recipe["max_run"]) and rng.randf() < float(recipe["density_l"]):
				var piece := _low_piece(rng, recipe, belt, i >= first_jet, surface == "")
				if piece["k"] == "flame" or piece["k"] == "crusher":
					# timed pieces sit on a still floor: a belt or ice would carry a waiting player into them
					belt = null
					belt_left = 0
					surface = ""
					surface_left = 0
				elif surface != "":
					piece = MachineKit.on_surface(piece, surface)
				cell["L"] = _place(rng, cx, piece)
				run_l += 1
			else:
				run_l = 0
			cell["surface"] = surface
			# deck lane (only once the deck exists)
			if i > first_jet:
				if run_u < int(recipe["max_run"]) and rng.randf() < float(recipe["density_u"]):
					cell["U"] = _place(rng, cx, _up_piece(rng, recipe))
					run_u += 1
					# a gap leaves the floor below it clear: nothing may be waiting where you land
					if cell["U"]["k"] == "gap" or cell["U"]["k"] == "rspike_gap":
						cell["L"] = {"k": "plain"}
						run_l = 0
				else:
					run_u = 0
			cell["belt"] = belt
		else:
			run_l = 0
			run_u = 0
			belt_left = 0
		cells.append(cell)
	var end_x := MachinePieces.START_X + float(n) * MachinePieces.CELL_W
	var spec := {
		"level": level, "seed": seed, "variant": variant, "recipe": recipe,
		"cells": cells, "end_x": end_x,
		"goal": Rect2(end_x - 200.0, MachinePieces.DECK_Y - 96.0, 56.0, 96.0),
		"spawn": Vector2(200.0, MachinePieces.FLOOR_Y - 28.0),
	}
	_add_nook(rng, spec)
	return spec


## The core's reward nook: a small ledge floating above the deck in a plain deck cell, reachable by
## one full jump from the deck (85 px up, jump is about 100). It is optional and sits off the route;
## collecting the core refills the cells, so it is also a bait.
static func _add_nook(rng: RandomNumberGenerator, spec: Dictionary) -> void:
	var cells: Array = spec["cells"]
	var options: Array = []
	for i in range(3, cells.size() - 4):
		var c: Dictionary = cells[i]
		var u: Dictionary = c["U"]
		var l: Dictionary = c["L"]
		if u["k"] != "deck" or l["k"] == "jet":
			continue
		options.append(i)
	if options.is_empty():
		return
	var idx: int = options[rng.randi_range(0, options.size() - 1)]
	var cx: float = float(cells[idx]["x"]) + rng.randf_range(200.0, 320.0)
	var top := MachinePieces.DECK_Y - MachinePieces.NOOK_RISE
	spec["nook"] = {"rect": Rect2(cx - MachinePieces.NOOK_W * 0.5, top, MachinePieces.NOOK_W, MachinePieces.NOOK_THICK),
		"orb": Vector2(cx, top - 36.0), "cell": idx}


## The calm template used when 50 draws all miss: a level that is mostly jets and plain floor.
static func fallback(level: int, seed: int) -> Dictionary:
	var recipe := recipe_for(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, 999, level])
	var n: int = recipe["cells"]
	var cells: Array = []
	var jets := _jet_cells(rng, n)
	var first_jet: int = jets[0]
	for i in n:
		var cx := MachinePieces.START_X + float(i) * MachinePieces.CELL_W
		var cell := {"x": cx, "L": {"k": "plain"}, "U": ({"k": "deck"} if i >= first_jet else {"k": "none"}), "belt": null}
		if i in jets:
			cell["L"] = _place(rng, cx, MachineKit.jet())
		elif i > 2 and i < n - 3 and i % 3 == 0:
			cell["L"] = _place(rng, cx, MachineKit.spikes("L", 80.0))
		cells.append(cell)
	var end_x := MachinePieces.START_X + float(n) * MachinePieces.CELL_W
	return {"level": level, "seed": seed, "variant": -1, "recipe": recipe, "cells": cells, "end_x": end_x,
		"goal": Rect2(end_x - 200.0, MachinePieces.DECK_Y - 96.0, 56.0, 96.0),
		"spawn": Vector2(200.0, MachinePieces.FLOOR_Y - 28.0)}


# --- evaluation ------------------------------------------------------------------------------

## The best route through a spec for a person with timing sigma `sigma_t`. Returns
## {p, route (lane at the end of each cell), events}.
static func best_route(spec: Dictionary, sigma_t: float) -> Dictionary:
	var cells: Array = spec["cells"]
	# state per lane: {v: Array of 3 probs (hits 0..2), route: Array}
	var states := {"L": {"v": [1.0, 0.0, 0.0], "route": [], "ok": true}, "U": {"v": [0.0, 0.0, 0.0], "route": [], "ok": false}}
	for i in cells.size():
		var nxt := {"L": {"v": [0.0, 0.0, 0.0], "route": [], "ok": false}, "U": {"v": [0.0, 0.0, 0.0], "route": [], "ok": false}}
		for lane in ["L", "U"]:
			var st: Dictionary = states[lane]
			if not bool(st["ok"]):
				continue
			for opt in MachineBot.cell_options(cells[i], lane, i):
				var v: Array = _apply_events(st["v"], opt["events"], sigma_t)
				var out_lane: String = opt["lane_out"]
				var cur: Dictionary = nxt[out_lane]
				if (not bool(cur["ok"])) or _sum(v) > _sum(cur["v"]):
					var r: Array = (st["route"] as Array).duplicate()
					r.append(out_lane)
					nxt[out_lane] = {"v": v, "route": r, "ok": true}
		states = nxt
	var best_lane := "U"
	if bool(states["L"]["ok"]) and (not bool(states["U"]["ok"]) or _sum(states["L"]["v"]) > _sum(states["U"]["v"])):
		best_lane = "L"
	var best: Dictionary = states[best_lane]
	var route: Array = best["route"]
	var events := MachineBot.events_for(spec, route, "L")
	return {"p": _sum(best["v"]), "route": route, "events": events, "lane": best_lane}


static func _sum(v: Array) -> float:
	var t := 0.0
	for x in v:
		t += float(x)
	return t


static func _apply_events(v_in: Array, events: Array, sigma_t: float) -> Array:
	var v: Array = v_in.duplicate()
	for ev in events:
		var kind := String(ev["kind"])
		var cls := MachineProbe.risk_class("free" if kind == "drop" else kind)
		if cls == "free":
			continue
		var q := MachineProbe.q_piece(ev["piece"], ev.get("belt"), sigma_t)
		var nv: Array = [0.0, 0.0, 0.0]
		if cls == "kill":
			for i in 3:
				nv[i] = float(v[i]) * q
		else:
			for i in 3:
				nv[i] += float(v[i]) * q
				if i + 1 < 3:
					nv[i + 1] += float(v[i]) * (1.0 - q)
		v = nv
	return v


## Draw a level: re-roll until the median player's pass probability is inside the band around the
## level's target and the floors hold. Returns the spec plus its measured odds.
static func novice_floor(level: int) -> float:
	return P_FLOOR_NOVICE if level <= 14 else P_FLOOR_NOVICE_LATE


static func roll(level: int, seed: int, boss_factor: float = 1.0) -> Dictionary:
	var recipe := recipe_for(level)
	var target: float = float(recipe["p_target"]) * boss_factor
	# Each roll aims at its own odds, scattered around the target, so some rolls are kind and some
	# are brutal (the HUD says which). The level's average stays on the difficulty curve.
	var aim_rng := RandomNumberGenerator.new()
	aim_rng.seed = hash([seed, level, 77])
	var aim := target * clampf(exp(aim_rng.randfn(0.0, 0.42)), 0.4, 2.4)
	aim = clampf(aim, P_FLOOR_MEDIAN * 1.5, 0.97)
	var best: Dictionary = {}
	var best_gap := 1e9
	for variant in MAX_REROLLS:
		var spec := candidate(level, seed, variant)
		var med := best_route(spec, MachineBot.SIGMA_MEDIAN)
		var p_med: float = med["p"]
		if p_med < P_FLOOR_MEDIAN:
			continue
		var nov := best_route(spec, MachineBot.SIGMA_NOVICE)
		if float(nov["p"]) < novice_floor(level):
			continue
		var gap := absf(log(p_med / aim))
		if gap < best_gap:
			best_gap = gap
			best = spec
			best["odds"] = {"median": p_med, "novice": nov["p"], "expert": best_route(spec, MachineBot.SIGMA_EXPERT)["p"],
				"route": med["route"], "target": target, "aim": aim}
		# Close enough: within about 25% of the aim.
		if gap < 0.22:
			break
	if best.is_empty():
		best = fallback(level, seed)
		var med2 := best_route(best, MachineBot.SIGMA_MEDIAN)
		best["odds"] = {"median": med2["p"], "novice": best_route(best, MachineBot.SIGMA_NOVICE)["p"],
			"expert": best_route(best, MachineBot.SIGMA_EXPERT)["p"], "route": med2["route"], "target": target,
			"fallback": true}
	return best
