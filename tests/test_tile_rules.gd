extends SceneTree
## Random crumbling tiles: a different few every load, never where a pause is needed, never
## changing the geometry, and never on the early levels.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _kinds(def) -> Dictionary:
	var out := {}
	for p in def.platforms:
		out[String(p.name)] = String(p.kind)
	return out


func _geometry(def) -> String:
	var parts: Array = []
	for p in def.platforms:
		parts.append("%s@%s/%s" % [p.name, p.position, p.size])
	return "|".join(parts)


func _run() -> void:
	await physics_frame
	_check("the early acts stay plain", TileRules.count_for(1) == 0 and TileRules.count_for(5) == 0)
	_check("later levels change more tiles", TileRules.count_for(6) == 1 and TileRules.count_for(25) == 4)
	var geometry_same := true
	var rules_ok := true
	var varied := 0
	var changed_levels := 0
	var no_neighbours := true
	var plain_untouched := true
	for lvl in range(1, 26):
		if CourseGen.is_road(lvl):
			continue
		var base := LevelData.get_level(lvl)
		var base_kinds := _kinds(base)
		var base_geo := _geometry(base)
		var seen := {}
		for sd in 30:
			var d := LevelData.get_level(lvl, sd)
			geometry_same = geometry_same and _geometry(d) == base_geo
			var k := _kinds(d)
			var changed: Array = []
			for n in k:
				if k[n] != base_kinds.get(n, k[n]):
					changed.append(n)
					if not (k[n] == "crumble" and base_kinds[n] == "solid"):
						rules_ok = false
			if lvl < TileRules.FIRST_LEVEL and not changed.is_empty():
				plain_untouched = false
			if changed.size() > TileRules.count_for(lvl):
				rules_ok = false
			# Nothing near a hazard, gate, pipe or checkpoint.
			for n in changed:
				var plat = null
				for p in d.platforms:
					if String(p.name) == n:
						plat = p
				for b in d.spinning_blades:
					if absf(b.position.x - plat.position.x) < TileRules.CLEAR_FROM_HAZARD:
						rules_ok = false
				for c in d.checkpoints:
					if absf(c.position.x - plat.position.x) < TileRules.CLEAR_FROM_CHECKPOINT:
						rules_ok = false
				for g in d.gates:
					if absf((g[0] as Vector2).x - plat.position.x) < TileRules.CLEAR_FROM_HAZARD:
						rules_ok = false
			changed.sort()
			seen[str(changed)] = true
		if lvl >= TileRules.FIRST_LEVEL:
			changed_levels += 1
			if seen.size() >= 3:
				varied += 1
	_check("the platforms never move or resize, so every jump is still possible", geometry_same)
	_check("only solid tiles become crumble, never more than the budget, never near a hazard, gate or checkpoint", rules_ok)
	_check("levels 1-5 are never touched", plain_untouched)
	_check("most later levels get a different set each time (%d of %d)" % [varied, changed_levels], varied * 10 >= changed_levels * 7)
	var det_a := _kinds(LevelData.get_level(12))
	var det_b := _kinds(LevelData.get_level(12))
	_check("with randomness off a level is identical every time", str(det_a) == str(det_b))
	print("[test_tile_rules] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
