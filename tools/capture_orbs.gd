extends SceneTree
const WINDOW_SIZE := Vector2i(1280, 720)
var _out := "user://orbs"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	_run()
func _run() -> void:
	DisplayServer.window_set_size(WINDOW_SIZE)
	for i in 3: await process_frame
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 9)
	get_root().add_child(scene)
	for i in 20: await process_frame
	var p = scene.get_node("Player")
	p.set_physics_process(false)
	var orb = scene.get_node_or_null("Hazards/Orb_2")
	if orb != null:
		p.global_position = orb.global_position + Vector2(-120, 20)
	for i in 40: await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	get_root().get_texture().get_image().save_png(_out + "/orbs.png")
	print("[orbs] saved")
	quit(0)
