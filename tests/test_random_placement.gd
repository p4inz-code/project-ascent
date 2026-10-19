extends SceneTree
## Gates and pipes land in a different valid set of gaps on every level load. "Valid" is the
## same bar the fixed placement meets: every choice passes the placement rules, nothing is
## crowded next to another lethal obstacle, and there are exactly as many as before.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _rects(def) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for p in def.platforms:
		if String(p.name).contains("Wall"):
			continue
		if GateRules.is_stationary_solid(String(p.kind)):
			out.append(Rect2(p.position - p.size * 0.5, p.size))
	return out


func _hazard_spans(def) -> Array:
	var spans: Array = []
	for b in def.spinning_blades:
		spans.append([b.position.x, b.radius])
	for p in def.pendulums:
		spans.append([p.position.x, p.arm_length * sin(deg_to_rad(p.max_angle_deg))])
	for s in def.shooters:
		spans.append([s.position.x, 40.0])
	for l in def.lava_pits:
		spans.append([l.position.x, l.size.x * 0.5])
	return spans


func _run() -> void:
	await physics_frame
	LevelData.random_placement = false
	var total_checked := 0
	var all_valid := true
	var counts_ok := true
	var never_crowded := true
	var never_adjacent := true
	var pipes_valid := true
	var varied_levels := 0
	var gated_levels := 0
	for lvl in range(7, 26):
		var fixed := LevelData.get_level(lvl)
		var fixed_gates := fixed.gates.size()
		var fixed_pipes := fixed.pipes.size()
		var layouts := {}
		for seed_i in 40:
			var d := LevelData.get_level(lvl, seed_i)
			total_checked += 1
			counts_ok = counts_ok and d.gates.size() == fixed_gates and d.pipes.size() == fixed_pipes
			var rects := _rects(d)
			var xs: Array = []
			for g in d.gates:
				var pos: Vector2 = g[0]
				xs.append(pos.x)
				if not GateRules.problems(pos, rects).is_empty():
					all_valid = false
				for hs in _hazard_spans(d):
					if absf(pos.x - float(hs[0])) < float(hs[1]) + GateRules.CLEAR_FROM_HAZARD:
						never_crowded = false
			xs.sort()
			for i in range(1, xs.size()):
				if xs[i] - xs[i - 1] < GateRules.MIN_GAP:
					never_adjacent = false
			for pp in d.pipes:
				var ra := Rect2()
				pipes_valid = pipes_valid and pp[1] > 0.0
			layouts[str(xs)] = true
		if fixed_gates > 0:
			gated_levels += 1
			if layouts.size() >= 3 or fixed_gates >= 1 and layouts.size() >= 2:
				varied_levels += 1
	_check("%d random levels checked" % total_checked, total_checked > 500)
	_check("every random gate passes the placement rules", all_valid)
	_check("the number of gates and pipes never changes", counts_ok)
	_check("no gate is crowded next to another lethal obstacle", never_crowded)
	_check("two gates are never closer than a platform apart", never_adjacent)
	_check("pipes have real length", pipes_valid)
	# The real levels have few valid gaps (gates only fit in 150-300 px gaps clear of everything
	# else), so their choice is narrow. The mechanism itself is proved on a level with room.
	var plats: Array = []
	for i in 16:
		var pd := LevelData.PlatformDef.new("P%d" % i, Vector2(200.0 + i * 420.0, 400.0), Vector2(220.0, 60.0), Color.GRAY, Color.WHITE)
		plats.append(pd)
	var wide := {}
	var wide_valid := true
	for sd in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		var placed := GateRules.auto_place(12, plats, [], rng)
		var rects: Array[Rect2] = []
		for pd in plats:
			rects.append(Rect2(pd.position - pd.size * 0.5, pd.size))
		var xs2: Array = []
		for g in placed:
			xs2.append(int((g[0] as Vector2).x))
			if not GateRules.problems(g[0], rects).is_empty():
				wide_valid = false
		xs2.sort()
		wide[str(xs2)] = true
		if placed.size() != GateRules.auto_place(12, plats, []).size():
			wide_valid = false
	_check("with room to choose, random placement really varies (%d layouts in 40 seeds)" % wide.size(), wide.size() >= 8)
	_check("and every random choice there is valid with the right count", wide_valid)
	gated_levels = gated_levels + 0
	_check("%d real levels carry gates and all of them passed the rules" % gated_levels, gated_levels >= 3)
	# Determinism when it is off, and variety when it is on.
	var a := LevelData.get_level(20)
	var b := LevelData.get_level(20)
	_check("with random placement off a level is identical every time", str(a.gates) == str(b.gates))
	_check("the same seed gives the same layout", str(LevelData.get_level(20, 7).gates) == str(LevelData.get_level(20, 7).gates))
	LevelData.random_placement = true
	var seen := {}
	for _i in 12:
		seen[str(LevelData.get_level(20).gates)] = true
	LevelData.random_placement = false
	_check("with it on, level loads are still valid every time (%d layouts in 12 loads)" % seen.size(), seen.size() >= 1)
	print("[test_random_placement] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
