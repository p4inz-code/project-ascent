extends SceneTree
## Capture UI screenshots from inside the engine, at a real window size.
##
## Replaces driving Win32 screen-capture from PowerShell, which proved
## untrustworthy: GetWindowRect includes Windows 11's invisible resize
## borders, so captures came out offset from the client area and made a
## correctly-centred panel look 639px off-centre. Grabbing the viewport
## texture captures exactly what the game draws, with no window-manager
## geometry in the way.
##
## Run WITHOUT --headless (needs a real renderer):
##   Godot --path <project> --script res://tools/capture_ui.gd -- <out_dir>

const WINDOW_SIZE := Vector2i(1920, 1080)

var _out_dir: String = "user://ui_captures"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	_run()


func _run() -> void:
	DisplayServer.window_set_size(WINDOW_SIZE)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await process_frame
	await process_frame

	DirAccess.make_dir_recursive_absolute(_out_dir)

	var scene: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)

	var pm: Node = null
	for _i in 300:
		await process_frame
		pm = scene.get_node_or_null("PauseMenu")
		if pm != null and pm.get_node_or_null("Panel") != null:
			break
	if pm == null:
		print("[capture] PauseMenu never appeared")
		quit(1)
		return

	# Let the level card transition finish so the backdrop behind the menu is
	# the real level, not a mid-fade frame.
	for _i in 180:
		await process_frame

	pm.visible = true
	await _settle()
	await _grab("pause_main")

	pm._on_levels()
	await _settle()
	await _grab("pause_levels")
	pm._show_view("progress")
	await _settle()
	await _grab("pause_progress")
	pm._on_reset()
	await _settle()
	await _grab("pause_reset_confirm")
	pm._show_view("main")

	pm._on_settings()
	await _settle()
	await _grab("settings_controls")
	var page: Node = pm._page
	for i in range(1, 6):
		page._select_tab(i)
		await _settle()
		await _grab("settings_tab_%d" % i)
	page.close()
	await _settle()

	pm._on_controls()
	await _settle()
	await _grab("controls_page")
	pm._page.close()
	await _settle()

	pm.visible = false
	await _settle()
	await _grab("gameplay")

	print("[capture] done -> ", _out_dir)
	quit(0)


func _settle() -> void:
	for _i in 8:
		await process_frame


## Godot renders into the viewport texture; reading it back must happen after
## the frame is actually drawn, hence the explicit await on process_frame
## before get_image().
func _grab(name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("[capture] FAILED to read viewport for ", name)
		return
	var path := "%s/%s.png" % [_out_dir, name]
	var err := img.save_png(path)
	print("[capture] %s -> %s (%dx%d) err=%d" % [name, path, img.get_width(), img.get_height(), err])
