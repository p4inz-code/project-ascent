extends SceneTree
## Screenshots of the weird hazards in a rolled machine: ambush spikes (flat, then risen), a fake-floor
## pit, the fake End door, a piston, hail. Run without --headless:
##   Godot --path <project> --script res://tools/capture_tricks.gd -- <out dir> <level> <seed>
var _out := "user://tricks"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	_run(int(a[1]) if a.size() > 1 else 16, int(a[2]) if a.size() > 2 else 77)
func _shot(name: String) -> void:
	for i in 4: await process_frame
	get_root().get_texture().get_image().save_png(_out + "/" + name + ".png")
	print("[tricks] ", name)
func _run(level: int, seed: int) -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(_out)
	for i in 3: await process_frame
	MachineRuntime.fixed_seed = seed
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", level)
	get_root().add_child(scene)
	for i in 30: await physics_frame
	var p: Player = scene.get_node("Player")
	var m: MachineRuntime = scene.get_node("Machine")
	p.set_physics_process(false)
	var targets: Array = []
	for cell in m.spec["cells"]:
		for pc in MachinePieces.cell_pieces(cell):
			if pc.get("ambush", false) and targets.filter(func(t): return t[0] == "ambush").size() < 1:
				targets.append(["ambush", float(pc["x"]), pc["lane"]])
			if pc.get("fake", false) and targets.filter(func(t): return t[0] == "fakepit").size() < 1:
				targets.append(["fakepit", float(pc["x"]), pc["lane"]])
			if String(pc["k"]) == "crusher" and targets.filter(func(t): return t[0] == "crusher").size() < 1:
				targets.append(["crusher", float(pc["x"]), pc["lane"]])
			if String(pc["k"]) == "hail" and targets.filter(func(t): return t[0] == "hail").size() < 1:
				targets.append(["hail", float(pc["x"]), pc["lane"]])
	if m.spec.has("fake_goal"):
		targets.append(["fakedoor", m.spec["fake_goal"].x, "U"])
	for t in targets:
		var y: float = MachinePieces.DECK_Y - 40.0 if t[2] == "U" else MachinePieces.FLOOR_Y - 40.0
		# far away: flat ambush spikes, then close: risen
		p.global_position = Vector2(float(t[1]) - 700.0, y)
		for i in 20: await physics_frame
		await _shot("%s_far" % t[0])
		p.global_position = Vector2(float(t[1]) - 260.0, y)
		for i in 30: await physics_frame
		await _shot("%s_near" % t[0])
	quit(0)
