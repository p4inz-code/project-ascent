extends SceneTree
## Captures the title screen and PIP's briefing as they render. Run WITHOUT --headless, APPDATA redirected:
##   Godot --path . --script res://tools/capture_title.gd -- <out dir>
func _initialize() -> void:
	_go()


func _go() -> void:
	var out := "user://title"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for i in 5:
		await process_frame
	var menu := StartMenu.new()
	root.add_child(menu)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(out + "/title.png")
	menu.queue_free()
	paused = false
	await process_frame
	var br := BriefingScreen.new()
	root.add_child(br)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(out + "/briefing_typing.png")
	for i in 260:
		await process_frame
	root.get_texture().get_image().save_png(out + "/briefing.png")
	quit(0)
