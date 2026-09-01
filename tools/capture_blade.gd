extends SceneTree
const WINDOW_SIZE := Vector2i(1280, 720)
var _out := "user://blade"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	_run()
func _run() -> void:
	DisplayServer.window_set_size(WINDOW_SIZE)
	for i in 3: await process_frame
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 16)
	get_root().add_child(scene)
	for i in 20: await process_frame
	# Park the camera on the first blade so it fills the frame.
	var lv := LevelData.get_level(16)
	if lv.spinning_blades.size() > 0:
		var p = scene.get_node_or_null("Player")
		if p != null:
			p.global_position = lv.spinning_blades[0].position + Vector2(0, -140)
			p.set_physics_process(false)
	for i in 40: await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	get_root().get_texture().get_image().save_png(_out + "/blade.png")
	print("[blade] saved")
	quit(0)
