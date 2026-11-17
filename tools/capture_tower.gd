extends SceneTree
## Screenshots of THE COMPACTOR. Run WITHOUT --headless:  Godot --path <project> --script res://tools/capture_tower.gd -- <out dir> <seed>
var _out := "user://tower"
var _seed := 4242

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	if a.size() > 1: _seed = int(a[1])
	_run()

func _shot(name: String) -> void:
	for i in 6: await process_frame
	get_root().get_texture().get_image().save_png(_out + "/" + name + ".png")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(_out)
	for i in 3: await process_frame
	MachineRuntime.fixed_seed = _seed
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 10)
	get_root().add_child(scene)
	for i in 30: await physics_frame
	var p: Player = scene.get_node("Player")
	var m: MachineRuntime = scene.get_node("Machine")
	p.set_physics_process(false)
	await _shot("0_start")
	var pl: Array = m.spec["tower"]["plats"]
	for k in [5, 12, 20, 29]:
		var r: Rect2 = pl[k]["rect"]
		p.global_position = Vector2(r.get_center().x, r.position.y - 30.0)
		await _shot("step_%d" % k)
	quit()
