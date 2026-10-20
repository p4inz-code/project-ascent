extends SceneTree
## The machine generator: every roll is passable, fair by construction, and reproducible.
##
## Over thousands of rolls (several levels x many seeds):
##   * determinism: the same (level, seed) is the same machine
##   * the 100-tries rule: the best route's pass probability for a median player is >= 3% and for a
##     novice >= 1%
##   * the difficulty curve: the average median-player odds fall from level to level, near the target
##   * construction rules: calm first cell and tower, jets where the deck is reached, at most two
##     obstacles in a row per lane, nothing waiting under a gap, obstacles inside their cell
## Negative controls: a spec that breaks each rule is caught by the same checker.

var _failures: int = 0

const LEVELS := [6, 9, 12, 15, 20, 25]
const SEEDS := 120


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _boot() -> void:
	await physics_frame
	_determinism()
	_rules_over_many_rolls()
	_curve()
	_nook_reachable()
	_biomes_show_up()
	_rule_controls()
	_fallback()
	print("[test_machine_gen] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _determinism() -> void:
	var a := MachineGen.roll(15, 424242)
	var b := MachineGen.roll(15, 424242)
	_check("the same level and seed give the same machine", str(a["cells"]) == str(b["cells"]) and str(a["odds"]) == str(b["odds"]))
	var c := MachineGen.roll(15, 424243)
	_check("a different seed gives a different machine", str(a["cells"]) != str(c["cells"]))
	_check("a different level gives a different machine", str(MachineGen.roll(16, 424242)["cells"]) != str(a["cells"]))


## Returns a list of rule violations for a spec (empty = fine).
func _violations(spec: Dictionary) -> Array:
	var out: Array = []
	var cells: Array = spec["cells"]
	var n := cells.size()
	if cells[0]["L"]["k"] != "plain" or cells[0]["U"]["k"] != "none":
		out.append("first cell is not calm")
	for i in [n - 1, n - 3]:
		var c: Dictionary = cells[i]
		if c["L"]["k"] != "plain" or (c["U"]["k"] != "deck" and c["U"]["k"] != "none"):
			out.append("tower approach cell %d is not calm" % i)
	if cells[n - 2]["L"]["k"] != "jet":
		out.append("no final jet before the tower")
	var first_jet := -1
	for i in n:
		if cells[i]["L"]["k"] == "jet":
			first_jet = i
			break
	if first_jet < 2 or first_jet > 3:
		out.append("first jet at %d" % first_jet)
	var run_l := 0
	var run_u := 0
	for i in n:
		var c: Dictionary = cells[i]
		var cx: float = float(c["x"])
		var l: Dictionary = c["L"]
		var u: Dictionary = c["U"]
		# deck exists exactly from the first jet on
		if (i >= first_jet) != (u["k"] != "none"):
			out.append("deck presence wrong in cell %d" % i)
		if l["k"] != "plain" and l["k"] != "jet":
			run_l += 1
			if run_l > int(spec["recipe"]["max_run"]):
				out.append("too many floor obstacles in a row at %d" % i)
		else:
			run_l = 0
		if u["k"] != "deck" and u["k"] != "none":
			run_u += 1
			if run_u > int(spec["recipe"]["max_run"]):
				out.append("too many deck obstacles in a row at %d" % i)
		else:
			run_u = 0
		for p in MachinePieces.cell_pieces(c):
			if p.has("x"):
				var span := MachinePieces.span_of(p)
				if span[0] < cx + 60.0 or span[1] > cx + MachinePieces.CELL_W - 60.0:
					out.append("piece %s leaves its cell %d" % [p["k"], i])
		if u["k"] == "gap" or u["k"] == "rspike_gap":
			if l["k"] != "plain":
				out.append("hazard under a gap in cell %d" % i)
		if l["k"] == "jet" and u["k"] != "deck":
			out.append("jet without a deck above in cell %d" % i)
		# biome pieces
		if l["k"] == "crusher" and u["k"] == "none":
			out.append("a piston with no deck to hang from in cell %d" % i)
		if l["k"] in ["flame", "crusher"] and (c.get("belt") != null or String(c.get("surface", "")) != ""):
			out.append("a timed piece on a belt or slippery floor in cell %d" % i)
		if String(c.get("surface", "")) != "" and c.get("belt") != null:
			out.append("a belt and a slippery floor together in cell %d" % i)
		if String(c.get("surface", "")) != "" and l["k"] not in ["plain", "spikes", "hump", "pit"]:
			out.append("an odd piece on a slippery floor in cell %d" % i)
		if u["k"] == "hail" and String(u.get("lane", "U")) != "U":
			out.append("hail on the wrong lane in cell %d" % i)
	return out


## Every piece on the roll must have a window of at least MIN_WINDOW_FRAMES at the speed it is crossed at.
func _tight_pieces(spec: Dictionary) -> Array:
	var out: Array = []
	for cell in spec["cells"]:
		for p in MachinePieces.cell_pieces(cell):
			if p["k"] == "plain" or p["k"] == "deck" or p["k"] == "none":
				continue
			var belt = cell.get("belt") if p["lane"] == "L" else null
			if MachineProbe.window_frames(p, belt) < MachineGen.MIN_WINDOW_FRAMES:
				out.append("%s %s" % [p["k"], str(p.get("w"))])
	return out


## The core's nook must be reachable by one full jump from the deck and clear of hazards.
func _nook_problems(spec: Dictionary) -> Array:
	var out: Array = []
	if not spec.has("nook"):
		return ["no nook"]
	var r: Rect2 = spec["nook"]["rect"]
	var rise := MachinePieces.DECK_Y - r.position.y
	if rise > 90.0 or rise < 40.0:
		out.append("nook rise %.0f is outside what one jump reaches" % rise)
	if r.size.x < 90.0:
		out.append("nook too narrow")
	var cell: int = int(spec["nook"]["cell"])
	var u: Dictionary = spec["cells"][cell]["U"]
	if u["k"] != "deck":
		out.append("nook over a deck obstacle in cell %d" % cell)
	if spec["cells"][cell]["L"]["k"] == "jet":
		out.append("nook over a jet")
	# the ledge sits inside its own cell and clear of the roof (spikes hang at most 90 px from it)
	var cx: float = float(spec["cells"][cell]["x"])
	if r.position.x < cx or r.end.x > cx + MachinePieces.CELL_W:
		out.append("nook leaves its cell")
	if r.position.y < MachinePieces.CEIL_Y + 100.0:
		out.append("nook too close to the roof")
	return out


func _rules_over_many_rolls() -> void:
	var rolls := 0
	var bad: Array = []
	var below_floor := 0
	var novice_bad := 0
	var fallbacks := 0
	var nan_odds := 0
	for level in LEVELS:
		for s in SEEDS:
			var spec := MachineGen.roll(level, 1000 + s)
			rolls += 1
			var v := _violations(spec)
			for np in _nook_problems(spec):
				v.append(np)
			var tight := _tight_pieces(spec)
			if not tight.is_empty():
				v.append("window under %.0f frames: %s" % [MachineGen.MIN_WINDOW_FRAMES, str(tight)])
			if not v.is_empty() and bad.size() < 5:
				bad.append("L%d s%d: %s" % [level, s, str(v)])
			var odds: Dictionary = spec["odds"]
			if float(odds["median"]) < MachineGen.P_FLOOR_MEDIAN:
				below_floor += 1
			if float(odds["novice"]) < MachineGen.novice_floor(level):
				novice_bad += 1
			if odds.has("fallback"):
				fallbacks += 1
			if is_nan(float(odds["median"])) or is_nan(float(odds["novice"])):
				nan_odds += 1
	print("[test_machine_gen] %d rolls, %d fallbacks" % [rolls, fallbacks])
	_check("no roll breaks a construction rule %s" % str(bad), bad.is_empty())
	_check("every roll clears the 3%% floor for a median player (%d below)" % below_floor, below_floor == 0)
	_check("every roll clears the novice floor (1%% to level 14, 0.2%% after) (%d below)" % novice_bad, novice_bad == 0)
	_check("the odds are real numbers", nan_odds == 0)
	_check("the fallback template is rare (<= 5%% of rolls)", float(fallbacks) / float(rolls) <= 0.05)


func _curve() -> void:
	var means: Array = []
	for level in LEVELS:
		var total := 0.0
		for s in 60:
			total += float(MachineGen.roll(level, 5000 + s)["odds"]["median"])
		means.append(total / 60.0)
	print("[test_machine_gen] mean median-player odds per level: ", str(means))
	var falling := true
	for i in range(1, means.size()):
		if means[i] > means[i - 1] * 1.15:
			falling = false
	_check("the average odds fall (or hold) as levels rise", falling)
	_check("the first machine level is clearly gentler than the last (%.2f vs %.2f)" % [means[0], means[means.size() - 1]],
		means[0] > means[means.size() - 1] * 1.5)
	_check("the curve target itself is monotone", MachineGen.p_target(5) > MachineGen.p_target(15) and MachineGen.p_target(15) > MachineGen.p_target(25) and MachineGen.p_target(25) > MachineGen.p_target(40))
	_check("the anchors are hit exactly (L10 0.40, L25 0.08)", absf(MachineGen.p_target(10) - 0.40) < 0.001 and absf(MachineGen.p_target(25) - 0.08) < 0.001)


func _rule_controls() -> void:
	# Each broken spec must be flagged by the checker above.
	var good := MachineGen.roll(12, 77)
	_check("(control) a normal roll has no violations", _violations(good).is_empty())
	var s1: Dictionary = good.duplicate(true)
	s1["cells"][0]["L"] = {"k": "spikes", "lane": "L", "w": 80.0, "x": float(s1["cells"][0]["x"]) + 200.0}
	_check("(control) an obstacle in the first cell is caught", not _violations(s1).is_empty())
	var s2: Dictionary = good.duplicate(true)
	var last: int = s2["cells"].size() - 2
	s2["cells"][last]["L"] = {"k": "plain"}
	_check("(control) a missing final jet is caught", not _violations(s2).is_empty())
	var s3: Dictionary = good.duplicate(true)
	for i in range(4, 9):
		if s3["cells"][i]["L"]["k"] != "jet":
			s3["cells"][i]["L"] = {"k": "spikes", "lane": "L", "w": 80.0, "x": float(s3["cells"][i]["x"]) + 200.0}
	_check("(control) a long run of floor obstacles is caught", not _violations(s3).is_empty())
	var s4: Dictionary = good.duplicate(true)
	var idx := -1
	for i in range(4, s4["cells"].size() - 3):
		if s4["cells"][i]["L"]["k"] != "jet":
			idx = i
			break
	s4["cells"][idx]["U"] = {"k": "gap", "lane": "U", "w": 100.0, "x": float(s4["cells"][idx]["x"]) + 200.0}
	s4["cells"][idx]["L"] = {"k": "spikes", "lane": "L", "w": 80.0, "x": float(s4["cells"][idx]["x"]) + 200.0}
	_check("(control) spikes waiting under a gap are caught", not _violations(s4).is_empty())
	var s5: Dictionary = good.duplicate(true)
	var k5 := -1
	for i in range(4, s5["cells"].size() - 3):
		if s5["cells"][i]["L"]["k"] == "plain" and s5["cells"][i]["U"]["k"] == "deck":
			k5 = i
			break
	s5["cells"][k5]["L"] = {"k": "crusher", "lane": "L", "w": 110.0, "period": 2.4, "active": 0.8, "tell": 0.9, "phase": 0.0, "x": float(s5["cells"][k5]["x"]) + 200.0}
	s5["cells"][k5]["belt"] = {"dir": 1.0, "speed": 100.0}
	_check("(control) a piston on a belt is caught", not _violations(s5).is_empty())
	var s6: Dictionary = good.duplicate(true)
	s6["cells"][k5]["surface"] = "ice"
	s6["cells"][k5]["belt"] = {"dir": 1.0, "speed": 100.0}
	_check("(control) a belt on ice is caught", not _violations(s6).is_empty())


## A person running along the deck can land on the nook's ledge with one jump (tried at every takeoff).
func _nook_reachable() -> void:
	var failed := 0
	var total := 0
	for level in [6, 15, 25]:
		for sd in 12:
			var spec := MachineGen.roll(level, 800 + sd)
			var world := MachinePieces.build_world(spec)
			var r: Rect2 = spec["nook"]["rect"]
			total += 1
			var landed := false
			for off in range(-170, 60, 3):
				var cell_x: float = float(spec["cells"][int(spec["nook"]["cell"])]["x"])
				var sim := MachineSim.new(world, Vector2(cell_x + 20.0, MachinePieces.DECK_Y - MachineSim.HALF.y - 0.01), 320.0)
				sim.on_floor = true
				var trigger := r.get_center().x + float(off)
				var jumped := false
				for f in 240:
					var jp := false
					if not jumped and sim.pos.x >= trigger:
						jumped = true
						jp = true
					sim.step(1.0, jp, jumped and f < 60, false)
					if jumped and sim.on_floor and absf(sim.pos.y + MachineSim.HALF.y - r.position.y) < 2.0 							and sim.pos.x > r.position.x and sim.pos.x < r.end.x:
						landed = true
						break
				if landed:
					break
			if not landed:
				failed += 1
	_check("the core's nook can be landed on from the deck in every sampled roll (%d of %d)" % [total - failed, total], failed == 0)
	# Control: a ledge 130 px above the deck is out of a jump's reach.
	var spec2 := MachineGen.roll(15, 800)
	var rr: Rect2 = spec2["nook"]["rect"]
	rr.position.y = MachinePieces.DECK_Y - 130.0
	spec2["nook"]["rect"] = rr
	var world2 := MachinePieces.build_world(spec2)
	var reached := false
	for off in range(-170, 60, 3):
		var cell_x2: float = float(spec2["cells"][int(spec2["nook"]["cell"])]["x"])
		var sim2 := MachineSim.new(world2, Vector2(cell_x2 + 20.0, MachinePieces.DECK_Y - MachineSim.HALF.y - 0.01), 320.0)
		sim2.on_floor = true
		var trig := rr.get_center().x + float(off)
		var jmp := false
		for f in 240:
			var jp2 := false
			if not jmp and sim2.pos.x >= trig:
				jmp = true
				jp2 = true
			sim2.step(1.0, jp2, jmp and f < 60, false)
			if jmp and sim2.on_floor and absf(sim2.pos.y + MachineSim.HALF.y - rr.position.y) < 2.0:
				reached = true
				break
	_check("(control) a ledge 130 px up cannot be landed on, so the check can fail", not reached)


## Every biome actually uses its own pieces somewhere across a batch of rolls.
func _biomes_show_up() -> void:
	var seen := {"scrapyard": 0, "freezer": 0, "storm": 0, "forge": 0}
	for level in [8, 13, 18, 23]:
		var biome := MachineGen.biome_of(level)
		for sd in 30:
			var spec := MachineGen.roll(level, 600 + sd)
			for cell in spec["cells"]:
				if biome == "scrapyard" and cell["L"]["k"] == "crusher":
					seen[biome] += 1
				if biome == "freezer" and String(cell.get("surface", "")) == "ice":
					seen[biome] += 1
				if biome == "storm" and (cell["U"]["k"] == "hail" or String(cell.get("surface", "")) == "slick"):
					seen[biome] += 1
				if biome == "forge" and cell["L"]["k"] in ["crusher", "flame"]:
					seen[biome] += 1
	_check("scrapyard rolls carry pistons (%d)" % seen["scrapyard"], seen["scrapyard"] > 20)
	_check("freezer rolls carry ice (%d)" % seen["freezer"], seen["freezer"] > 20)
	_check("storm rolls carry hail and rain-slick (%d)" % seen["storm"], seen["storm"] > 20)
	_check("forge rolls carry pistons and flames (%d)" % seen["forge"], seen["forge"] > 20)
	# (control) no flames or pistons on freezer ice levels
	var bad := 0
	for sd in 30:
		for cell in MachineGen.roll(13, 700 + sd)["cells"]:
			if cell["L"]["k"] in ["flame", "crusher"]:
				bad += 1
	_check("(control) freezer levels never roll flames or pistons (%d)" % bad, bad == 0)


func _fallback() -> void:
	for level in LEVELS:
		var f := MachineGen.fallback(level, 31)
		var med := MachineGen.best_route(f, MachineBot.SIGMA_MEDIAN)
		var ok := float(med["p"]) >= MachineGen.P_FLOOR_MEDIAN and _violations(f).is_empty()
		_check("the authored fallback for level %d is itself passable and rule-abiding (p = %.2f)" % [level, float(med["p"])], ok)
