extends SceneTree
## Screenshots of the main page and the support page. Run WITHOUT --headless: Godot --path . --script res://tools/capture_support.gd -- <out dir>
func _initialize() -> void:
	_run()

func _run() -> void:
	var out := "user://support"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	for i in 3: await process_frame
	var menu := StartMenu.new()
	root.add_child(menu)
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(out + "/main.png")
	var page := SupportPage.new()
	root.add_child(page)
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(out + "/support.png")
	quit()
