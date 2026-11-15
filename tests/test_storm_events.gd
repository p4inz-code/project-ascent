extends SceneTree
## Storm lightning on levels 16-19: it only ever marks the calm cells, at most two marks live, a walking player is
## not hit and a standing one is, and other levels have none.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	_check("it applies to 16-19 only", StormEvents.applies_to(16) and StormEvents.applies_to(19) and not StormEvents.applies_to(15) and not StormEvents.applies_to(20) and not StormEvents.applies_to(22))
	var spec := MachineGen.roll(17, 55)
	var ranges := StormEvents.calm_ranges_of(spec)
	var calm_ok := true
	for r in ranges:
		var ci := int((float(r[0]) - MachinePieces.START_X) / MachinePieces.CELL_W)
		var n: int = spec["cells"].size()
		if not (ci == 0 or ci >= n - 3 or ci % MachineGen.HINGE_EVERY == 0):
			calm_ok = false
	_check("the calm ranges are exactly the calm cells (%d ranges)" % ranges.size(), calm_ok and ranges.size() >= 4)
	await physics_frame
	MachineRuntime.fixed_seed = 55
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 17)
	root.add_child(main)
	for i in 6:
		await physics_frame
	var se: StormEvents = null
	for c in main.get_node("Machine").get_children():
		if c is StormEvents:
			se = c
	_check("level 17 has storm lightning", se != null)
	if se == null:
		quit(1)
		return
	var player := main.get_node("Player") as Player
	player.set_physics_process(false)
	se.player = player
	var calm: Array = se.calm_ranges[1]
	# outside the calm cells: nothing ever marks
	var busy_x := float(calm[1]) + 300.0
	for i in 300:
		player.global_position = Vector2(busy_x, MachinePieces.FLOOR_Y - 26.0)
		await physics_frame
	_check("(control) standing in a busy cell is never marked (%d marks)" % se.marks_made, se.marks_made == 0)
	# standing still in a calm cell: struck
	for i in 400:
		player.global_position = Vector2(float(calm[0]) + 200.0, MachinePieces.FLOOR_Y - 26.0)
		await physics_frame
	_check("standing still on a calm cell is struck (%d chips, %d marks)" % [se.chips, se.marks_made], se.chips >= 1)
	_check("never more than two marks alive", se._marks.size() <= StormEvents.MAX_MARKS)
	# walking through the calm cell at a steady pace: not struck
	se._marks.clear()
	for i in 10:
		player.global_position = Vector2(float(calm[0]) - 200.0, MachinePieces.FLOOR_Y - 26.0)
		await physics_frame
	var chips_before := se.chips
	var x := float(calm[0])
	while x < float(calm[1]):
		x += 200.0 / 60.0
		player.global_position = Vector2(x, MachinePieces.FLOOR_Y - 26.0)
		await physics_frame
	for i in 120:
		player.global_position = Vector2(float(calm[1]) + 400.0, MachinePieces.FLOOR_Y - 26.0)
		await physics_frame
	_check("walking through a calm cell is not struck (%d -> %d)" % [chips_before, se.chips], se.chips == chips_before)
	main.queue_free()
	MachineRuntime.fixed_seed = 12
	var other: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	other.set("level_number", 12)
	root.add_child(other)
	for i in 5:
		await physics_frame
	var found := false
	for c in other.get_node("Machine").get_children():
		if c is StormEvents:
			found = true
	_check("(control) a freezer level has no storm lightning", not found)
	other.queue_free()
	MachineRuntime.fixed_seed = 0
	print("[test_storm_events] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
