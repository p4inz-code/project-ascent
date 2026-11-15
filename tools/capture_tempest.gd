extends SceneTree
## Screenshots of THE TEMPEST. Run WITHOUT --headless:  Godot --path <project> --script res://tools/capture_tempest.gd -- <out dir>
var _out := "user://tempest"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	_run()

func _shot(name: String) -> void:
	for i in 6: await process_frame
	get_root().get_texture().get_image().save_png(_out + "/" + name + ".png")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(_out)
	for i in 3: await process_frame
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 20)
	get_root().add_child(scene)
	for i in 30: await physics_frame
	var p: Player = scene.get_node("Player")
	p.set_physics_process(false)
	p.global_position = Vector2(900.0, 700.0)
	for i in 230: await physics_frame
	await _shot("storm")
	quit()
