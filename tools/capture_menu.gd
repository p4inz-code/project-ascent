extends SceneTree
const WINDOW_SIZE := Vector2i(1600, 900)
var _out := "user://menu"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	_run()
func _run() -> void:
	DisplayServer.window_set_size(WINDOW_SIZE)
	for i in 4: await process_frame
	change_scene_to_file("res://scenes/game_scene.tscn")
	for i in 120: await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	var img := get_root().get_texture().get_image()
	img.save_png(_out + "/start_menu.png")
	print("[menu] saved")
	quit(0)
