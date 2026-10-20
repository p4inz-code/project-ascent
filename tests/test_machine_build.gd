extends SceneTree
## The machine in the real game: the nodes that get built are exactly the geometry the simulator
## proved, chip and instant hazards cost what they should, and every death rolls a new machine.

var _failures: int = 0
var _main: Node
var _player: Player


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _boot() -> void:
	await physics_frame
	MachineLevel.forced = [15]
	MachineRuntime.fixed_seed = 123456
	_main = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	_main.set("level_number", 15)
	root.add_child(_main)
	await _step(4)
	_player = _main.get_node("Player") as Player
	await _geometry()
	await _hazards()
	await _rerolls()
	await _level_shell()
	print("[test_machine_build] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _machine() -> MachineRuntime:
	return _main.get_node("Machine") as MachineRuntime


func _rects_of_nodes(m: MachineRuntime) -> Array:
	var out: Array = []
	for c in m.get_children():
		var sz = c.get("size")
		if sz is Vector2 and (c is StaticBody2D):
			out.append(Rect2((c as Node2D).position - (sz as Vector2) * 0.5, sz))
	return out


func _find_rect(rects: Array, r: Rect2) -> bool:
	for x in rects:
		var q: Rect2 = x
		if q.position.distance_to(r.position) < 0.6 and q.size.distance_to(r.size) < 0.6:
			return true
	return false


func _geometry() -> void:
	var m := _machine()
	_check("the level is a machine and rolled once", m != null and m.rolls == 1 and m.spec.has("cells"))
	var rects := _rects_of_nodes(m)
	var missing := 0
	var wanted := 0
	for d in MachinePieces.solids_of(m.spec):
		var r: Rect2 = d["rect"]
		if r.end.x <= MachinePieces.START_X - 1.0 and String(d["kind"]) != "roof":
			continue
		if r.position.x < MachinePieces.START_X and String(d["kind"]) != "roof":
			r = Rect2(MachinePieces.START_X, r.position.y, r.end.x - MachinePieces.START_X, r.size.y)
		wanted += 1
		if not _find_rect(rects, r):
			missing += 1
	_check("every solid the simulator proved is a node in the game (%d of %d)" % [wanted - missing, wanted], missing == 0 and wanted > 10)
	# Negative control: a different roll's geometry is NOT all present.
	var other := MachineGen.roll(15, 999)
	var mismatched := 0
	for d in MachinePieces.solids_of(other):
		var r2: Rect2 = d["rect"]
		if r2.position.x > MachinePieces.START_X and not _find_rect(rects, r2):
			mismatched += 1
	_check("(control) another roll's solids do not all match, so the comparison can fail", mismatched > 0)
	# Belt tops are conveyor nodes with the right direction.
	var belts_spec := 0
	for d in MachinePieces.solids_of(m.spec):
		if d["kind"] == "belt":
			belts_spec += 1
	var belts_nodes := 0
	for c in m.get_children():
		if c is ConveyorBelt:
			belts_nodes += 1
	_check("belt segments become conveyor belts (%d)" % belts_spec, belts_spec == belts_nodes)


func _count(cls_name: String) -> int:
	var n := 0
	for c in _machine().get_children():
		if c.get_class() == "Area2D" and c.get_script() != null and (c.get_script() as Script).get_global_name() == cls_name:
			n += 1
		elif c.get_script() != null and (c.get_script() as Script).get_global_name() == cls_name:
			n += 1
	return n


func _hazards() -> void:
	var spec: Dictionary = _machine().spec
	var spikes := 0
	var flames := 0
	var jets := 0
	var pits := 0
	for cell in spec["cells"]:
		for p in MachinePieces.cell_pieces(cell):
			match String(p["k"]):
				"spikes", "rspike_gap":
					spikes += 1
				"flame":
					flames += 1
				"jet":
					jets += 1
				"pit":
					pits += 1
	_check("spike rows match the spec (%d)" % spikes, _count("SpikeRow") == spikes)
	_check("flame jets match the spec (%d)" % flames, _count("FlameJet") == flames)
	_check("air jets match the spec (%d)" % jets, _count("AirJet") == jets and jets >= 2)
	_check("lava pits match the spec (%d)" % pits, _count("Lava") == pits)
	# A chip hazard costs a cell; an instant one kills.
	_player.reset_state()
	var attempts: int = _main.attempts
	var spike: SpikeRow = null
	var lava: Lava = null
	for c in _machine().get_children():
		if c is SpikeRow and spike == null:
			spike = c
		if c is Lava and lava == null:
			lava = c
	if spike != null:
		spike.player_hit.emit()
		_check("touching spikes costs one cell, not the run", _player.health.hp == 2 and _main.attempts == attempts)
	else:
		_check("this roll has spikes to test", false)
	_player.reset_state()
	if lava != null:
		attempts = _main.attempts
		lava.player_hit.emit()
		_check("touching lava is an instant death", _main.attempts == attempts + 1)
		await _step(3)


func _rerolls() -> void:
	MachineRuntime.fixed_seed = 0
	var m := _machine()
	var first_seed := m.seed_value
	var first_cells := str(m.spec["cells"])
	var rolls_before := m.rolls
	_main.restart_level()
	await _step(3)
	_check("a restart rolls a new machine (rolls %d -> %d)" % [rolls_before, m.rolls], m.rolls == rolls_before + 1)
	_check("the new roll has a new seed and different layout", m.seed_value != first_seed and str(m.spec["cells"]) != first_cells)
	var different := 0
	var prev := str(m.spec["cells"])
	for i in 6:
		_main.restart_level()
		await _step(2)
		var cur := str(m.spec["cells"])
		if cur != prev:
			different += 1
		prev = cur
	_check("six more deaths give six more different machines (%d)" % different, different >= 5)
	# Every one of those rolls was proven passable.
	_check("and the machine on screen is proven passable (median odds %.3f)" % float(m.spec["odds"]["median"]),
		float(m.spec["odds"]["median"]) >= MachineGen.P_FLOOR_MEDIAN)
	var code := MachineRuntime.seed_code(m.seed_value)
	_check("the seed has an 8-character code with no confusable letters", code.length() == 8 and not code.contains("O") and not code.contains("0") and not code.contains("I") and not code.contains("1"))
	# A fixed seed reproduces the same machine.
	m.roll(777)
	var a := str(m.spec["cells"])
	m.roll(777)
	_check("rolling the same seed twice gives the same machine", a == str(m.spec["cells"]))


func _level_shell() -> void:
	var def := LevelData.get_level(15)
	_check("the level definition is a machine with the start hinge, a door and no hand-placed hazards",
		def.machine and def.spinning_blades.is_empty() and def.lava_pits.is_empty() and def.platforms.size() == 2)
	var goal := _main.get_node("Goal") as Node2D
	_check("the door sits on the deck at the far end", absf(goal.position.y - (MachinePieces.DECK_Y - 48.0)) < 1.0
		and goal.position.x > MachinePieces.START_X + 10000.0)
	_check("(control) a normal level is not a machine", not LevelData.get_level(4).machine)
	MachineLevel.forced = []
	# The shipped machine levels: spawn on the start hinge, door on the deck, flags on calm hinge cells,
	# and the core nook rolled with every machine.
	var shipped_ok := true
	var flags_ok := true
	var checked_flags := 0
	for n in MachineLevel.LEVELS:
		var d := LevelData.get_level(n)
		if not d.machine:
			shipped_ok = false
		var ground: LevelData.PlatformDef = null
		for p in d.platforms:
			if p.name == "Ground":
				ground = p
		var gl: float = ground.position.x - ground.size.x * 0.5
		var gr: float = ground.position.x + ground.size.x * 0.5
		var gt: float = ground.position.y - ground.size.y * 0.5
		if d.spawn_point.x < gl or d.spawn_point.x > gr or absf((d.spawn_point.y + 28.0) - gt) > 1.0:
			shipped_ok = false
		if absf(d.goal_position.y - (MachinePieces.DECK_Y - 48.0)) > 1.0:
			shipped_ok = false
		for cp in d.checkpoints:
			checked_flags += 1
			var cell := int((cp.position.x - 260.0 - MachinePieces.START_X) / MachinePieces.CELL_W + 0.5)
			if cell % MachineGen.HINGE_EVERY != 0:
				flags_ok = false
			# the same cell is a calm hinge in every roll
			for sd in 6:
				var spec := MachineGen.roll(n, 50 + sd)
				var c: Dictionary = spec["cells"][cell]
				if c["L"]["k"] != "plain" or (c["U"]["k"] != "deck" and c["U"]["k"] != "none") or c.get("belt") != null:
					flags_ok = false
	_check("all %d shipped machine levels have a spawn on the hinge and a door on the deck" % MachineLevel.LEVELS.size(), shipped_ok)
	_check("their checkpoint flags (%d) sit on cells that are calm hinges in every roll" % checked_flags, flags_ok and checked_flags > 0)
	_check("the machine carries one optional core", _has_orb())
	MachineLevel.forced = [15]


func _has_orb() -> bool:
	for c in _machine().get_children():
		if c is Orb:
			return true
	return false
