extends SceneTree
## No two levels of an act look or open alike: each of the four wears its own tile surface, tint and back wall and
## opens its own way, while sharing one difficulty; and the scripted boss levels are never touched by the classic
## placement pipeline (the "obstacle soup" regression).

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _opening(level: int, seed_value: int) -> String:
	var s := MachineGen.roll(level, seed_value)
	var out := ""
	for i in range(1, 4):
		var c: Dictionary = s["cells"][i]
		out += "%s/%s%s " % [c["L"]["k"], c["U"]["k"], "+belt" if c.get("belt") != null else ""]
	return out


func _run() -> void:
	for act_first in [11, 36]:
		var looks := {}
		var walls := {}
		var tints := {}
		var base := Color(0.3, 0.4, 0.5)
		for lv in range(act_first, act_first + 4):
			looks[MachineRuntime.tile_for(MachineGen.biome_of(lv), lv)] = true
			walls[String(MachineRuntime.SLOT_LOOK[MachineRuntime.slot_of(lv)]["wall"])] = true
			tints[MachineRuntime.tinted(base, lv).to_html()] = true
		_check("levels %d-%d: four different back walls (%d) and four different tints (%d)" % [act_first, act_first + 3, walls.size(), tints.size()], walls.size() == 4 and tints.size() == 4)
		_check("levels %d-%d wear at least three different tile surfaces (%d)" % [act_first, act_first + 3, looks.size()], looks.size() >= 3)
		var openings := {}
		for lv in range(act_first, act_first + 4):
			openings[lv] = _opening(lv, 4242)
		var distinct := {}
		for k in openings:
			distinct[openings[k]] = true
		_check("levels %d-%d open four different ways %s" % [act_first, act_first + 3, str(openings.values())], distinct.size() == 4)
		_check("and share one difficulty target", MachineGen.p_target(act_first) == MachineGen.p_target(act_first + 3))
	_check("CLIMB opens on a jet, GAPS on a pit", _opening(12, 9).begins_with("jet/") and _opening(13, 9).begins_with("pit/"))
	_check("the rift and the core have their own surfaces (crystal, circuit)",
		MachineRuntime.BIOME_TILE["rift"] == "crystal" and MachineRuntime.BIOME_TILE["core"] == "circuit" and TileDecor.has_pattern("crystal") and TileDecor.has_pattern("circuit"))
	# the scripted boss levels: the classic pipeline must not add anything
	for lv in [15, 20, 30]:
		var soup := 0
		for i in 6:
			LevelData.random_placement = true
			var d := LevelData.get_level(lv)
			soup += d.pipes.size() + d.gates.size() + (1 if d.storm else 0)
			for p in d.platforms:
				if p.kind in ["crumble", "fake", "timed", "bounce", "sticky", "moving", "conveyor"]:
					soup += 1
		_check("level %d (scripted): six loads add no pipes, gates, storm or trick tiles (%d)" % [lv, soup], soup == 0 and LevelData.get_level(lv).scripted)
	LevelData.random_placement = false
	_check("(control) a classic level still gets the pipeline (level 2 is not scripted)", not LevelData.get_level(2).scripted)
	print("[test_level_looks] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
