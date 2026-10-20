extends SceneTree
## Screenshots of a machine level at several points along it.
## Run WITHOUT --headless:  Godot --path <project> --script res://tools/capture_machine.gd -- <out dir> <level> <seed>
const WINDOW_SIZE := Vector2i(1280, 720)
var _out := "user://machine"
var _level := 15
var _seed := 4242

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	if a.size() > 1: _level = int(a[1])
	if a.size() > 2: _seed = int(a[2])
	_run()

func _shot(name: String) -> void:
	for i in 4: await process_frame
	get_root().get_texture().get_image().save_png(_out + "/" + name + ".png")
	print("[machine] ", name)

func _run() -> void:
	DisplayServer.window_set_size(WINDOW_SIZE)
	DirAccess.make_dir_recursive_absolute(_out)
	for i in 3: await process_frame
	MachineLevel.forced = [_level]
	MachineRuntime.fixed_seed = _seed
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", _level)
	get_root().add_child(scene)
	for i in 30: await physics_frame
	var p: Player = scene.get_node("Player")
	var m: MachineRuntime = scene.get_node("Machine")
	print("[machine] odds ", m.spec["odds"])
	p.set_physics_process(false)
	await _shot("0_start")
	var xs: Array = []
	for i in m.spec["cells"].size():
		var cell: Dictionary = m.spec["cells"][i]
		if i in [3, 6, 9, 12, 15, 18]:
			xs.append(float(cell["x"]) + 260.0)
	var n := 0
	for x in xs:
		n += 1
		p.global_position = Vector2(x, MachinePieces.FLOOR_Y - 40.0)
		p.velocity = Vector2.ZERO
		for i in 25: await physics_frame
		await _shot("%d_x%d" % [n, int(x)])
	quit(0)
