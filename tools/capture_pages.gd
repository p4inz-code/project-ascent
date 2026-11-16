extends SceneTree
## Captures every menu page as it renders (title, settings tabs, about, support, studio, controls, pause views,
## briefing). Run WITHOUT --headless, APPDATA redirected:  Godot --path . --script res://tools/capture_pages.gd -- <out>
var _out := "user://pages"


func _initialize() -> void:
	_go()


func _shot(name: String) -> void:
	for i in 24:
		await process_frame
	root.get_texture().get_image().save_png(_out + "/" + name + ".png")
	print("saved ", name)


func _go() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for i in 5:
		await process_frame
	var menu := StartMenu.new()
	root.add_child(menu)
	await _shot("00_title")
	for spec in [["about", AboutPage], ["support", SupportPage], ["studio", StudioPage], ["controls", ControlsPage]]:
		var page: Node = spec[1].new()
		menu.add_child(page)
		await _shot("10_" + spec[0])
		page.queue_free()
		await process_frame
	var settings := SettingsPage.new()
	menu.add_child(settings)
	await _shot("20_settings_0")
	for i in range(1, 6):
		settings._select_tab(i)
		await _shot("20_settings_%d" % i)
	settings.queue_free()
	menu.queue_free()
	paused = false
	await process_frame
	var pm: Node = (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
	root.add_child(pm)
	pm.visible = true
	await _shot("30_pause_main")
	pm._show_view("levels")
	await _shot("30_pause_levels")
	pm._show_view("progress")
	await _shot("30_pause_progress")
	pm.queue_free()
	quit(0)
