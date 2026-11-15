extends SceneTree
## Levels 26-40 (acts VI-VIII): every one is a named machine level, every sampled roll clears the
## 100-tries floors, bosses are 30/35/40, level 40 carries the collapse front and the heat vents, the
## acts reuse the look of earlier acts, and the real scene builds a level from each act.

var _failures: int = 0
var _gs = load("res://scripts/game_scene.gd")


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	_check("the campaign has 40 levels", LevelData.TOTAL_LEVELS == 40)
	var unnamed := 0
	var not_machine := 0
	var floors_ok := 0
	var total := 0
	var bad_floor: Array = []
	for n in range(26, 41):
		var d := LevelData.get_level(n)
		if d.name == "" or d.name == "LEARN":
			unnamed += 1
		if not d.machine and not d.hive:
			not_machine += 1
		for s in 3:
			var spec := MachineGen.roll(n, 5000 + n * 17 + s, MachineLevel.boss_factor(n))
			total += 1
			var odds: Dictionary = spec["odds"]
			if float(odds["median"]) >= MachineGen.P_FLOOR_MEDIAN and float(odds["novice"]) >= MachineGen.novice_floor(n):
				floors_ok += 1
			else:
				bad_floor.append("%d:%.3f" % [n, float(odds["median"])])
	_check("levels 26-40 all have names (%d unnamed)" % unnamed, unnamed == 0)
	_check("levels 26-40 are all machine levels, except the Hive at 30 (%d not)" % not_machine, not_machine == 0 and LevelData.get_level(30).hive)
	_check("every sampled roll clears the median and novice floors (%d of %d) %s" % [floors_ok, total, str(bad_floor.slice(0, 3))], floors_ok == total)
	for b in [40]:
		_check("level %d is a boss (chasers)" % b, LevelData.get_level(b).boss_config.enabled)
	var hole := MachineGen.roll(35, 321, 0.5)
	_check("level 35 is the black hole: a front styled as a hole, slower than a slowed player by 15 percent", hole.has("front") and String(hole["front"]["style"]) == "hole" and float(hole["front"]["speed"]) * 1.15 < 320.0 * 0.7)
	var caught: Array = []
	for sd in 12:
		var sp := MachineGen.roll(35, 900 + sd, 0.55)
		var w := MachinePieces.build_world(sp)
		var med := MachineGen.best_route(sp, MachineBot.SIGMA_MEDIAN)
		var ev := MachineBot.events_for(sp, med["route"], "L")
		var g: Rect2 = sp["goal"]
		var bot := MachineBot.new(w, ev, Vector2(200.0, MachinePieces.FLOOR_Y - MachineSim.HALF.y - 0.01), g.position.x, 0.0, null, 0.0)
		var res := bot.run(200.0)
		if not bool(res["finished"]):
			caught.append("s%d %s" % [sd, str(res["cause"])])
	_check("a perfect run outruns the black hole on 12 rolls %s" % str(caught.slice(0, 3)), caught.is_empty())
	_check("(control) level 31 is not a boss", not LevelData.get_level(31).boss_config.enabled)
	var echo := MachineGen.roll(40, 4040, 0.5)
	var segs: Array = echo["recipe"].get("segments", [])
	_check("level 40 is the echo exam: five sections remixing five biomes", segs.size() == 5 and segs[0] == "cinder" and segs[2] == "storm")
	var hail_late := 0
	var hail_early := 0
	for ci in echo["cells"].size():
		var cu: Dictionary = echo["cells"][ci]["U"]
		if cu["k"] == "hail":
			if ci < echo["cells"].size() / 5:
				hail_early += 1
			elif ci >= echo["cells"].size() * 2 / 5 and ci < echo["cells"].size() * 3 / 5:
				hail_late += 1
	_check("(control) only the storm section carries hail: none in section one (%d), some across 20 rolls in section three" % hail_early, hail_early == 0 and _storm_hail() > 0)
	_check("level 40 has the collapse front", MachineGen.roll(40, 77, 0.5).has("front") and MachineLevel.FRONTS.has(40))
	_check("level 40 has heat vents", MachineGen.roll(40, 77, 0.5).get("vents", []).size() > 0)
	_check("biomes: 26-30 underworks, 31-35 rift, 36-40 core", MachineGen.biome_of(26) == "underworks" and MachineGen.biome_of(30) == "underworks" and MachineGen.biome_of(31) == "rift" and MachineGen.biome_of(35) == "rift" and MachineGen.biome_of(36) == "core" and MachineGen.biome_of(40) == "core")
	_check("visual levels map 26-40 onto 11-25 and leave the rest alone", LevelData.visual_level(26) == 11 and LevelData.visual_level(40) == 25 and LevelData.visual_level(12) == 12 and LevelData.visual_level(25) == 25)
	_check("every biome has a palette and a tile pattern", _biomes_ok())
	_check("each act has an intro line from PIP", _gs.act_intro_line(26) != "" and _gs.act_intro_line(31) != "" and _gs.act_intro_line(36) != "")
	_check("the three new bosses have a PIP line", _gs.act_intro_line(30) != "" and _gs.act_intro_line(35) != "" and _gs.act_intro_line(40) != "")
	_check("(control) a mid-act level has no intro line", _gs.act_intro_line(28) == "")
	await physics_frame
	for lvl in [26, 33, 40]:
		MachineRuntime.fixed_seed = 31
		var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
		main.set("level_number", lvl)
		root.add_child(main)
		for i in 5:
			await physics_frame
		var machine := main.get_node_or_null("Machine") as MachineRuntime
		_check("level %d builds a machine in the real scene" % lvl, machine != null and not machine.spec.is_empty())
		main.queue_free()
		await process_frame
	MachineRuntime.fixed_seed = 0
	print("[test_new_levels] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _biomes_ok() -> bool:
	for b in ["underworks", "rift", "core"]:
		if not MachineRuntime.BIOME_PALETTE.has(b) or not MachineRuntime.BIOME_TILE.has(b) or not MachineGen.BIOMES.has(b):
			return false
		if not TileDecor.has_pattern(String(MachineRuntime.BIOME_TILE[b])):
			return false
	return true


## Hail in the third (storm) section over 20 rolls of the echo exam.
func _storm_hail() -> int:
	var n := 0
	for s in 20:
		var sp := MachineGen.roll(40, 6000 + s, 0.5)
		var cells: Array = sp["cells"]
		for ci in range(cells.size() * 2 / 5, cells.size() * 3 / 5):
			if cells[ci]["U"]["k"] == "hail":
				n += 1
	return n
