extends SceneTree
## Visual audit of the updater's screens: the title card in each state, the About page in each state, and the
## Settings > Gameplay updates row. States are forced on the GameUpdater autoload; nothing touches the network.
## Run WITHOUT --headless, APPDATA redirected:
##   Godot --path . --script res://tools/capture_update_ui.gd -- <out dir>
var _out := "user://update_ui"
var _u: Node = null


func _initialize() -> void:
	_go()


func _shot(name: String) -> void:
	for i in 24:
		await process_frame
	root.get_texture().get_image().save_png(_out + "/" + name + ".png")
	print("saved ", name)


func _state(s: int, extra: Dictionary = {}) -> void:
	_u.force_supported = bool(extra.get("supported", true))
	_u._plan = {"ok": true, "version": "0.18.0", "asset": "Project-Ascent-v0.18.0-Windows.zip"}
	_u.latest = "0.18.0"
	_u.notes = ""
	_u.error = String(extra.get("error", ""))
	_u.received = int(extra.get("received", 0))
	_u.total = int(extra.get("total", 0))
	_u.last_result = extra.get("result", {})
	_u.mode = int(extra.get("mode", 1))
	_u.state = s
	_u.state_changed.emit()


func _go() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for i in 5:
		await process_frame
	_u = root.get_node("GameUpdater")
	var menu := StartMenu.new()
	root.add_child(menu)
	await process_frame
	var notice: UpdateNotice = menu.get_node("UpdateNotice")
	_state(3, {"mode": 1})
	notice.refresh()
	await _shot("title_available")
	_state(3, {"mode": 1, "supported": false})
	notice.refresh()
	await _shot("title_available_page_only")
	_state(4, {"mode": 0, "received": 21 * 1048576, "total": 54 * 1048576})
	notice.refresh()
	await _shot("title_downloading")
	_state(5, {"mode": 0, "received": 54 * 1048576, "total": 54 * 1048576})
	notice.refresh()
	await _shot("title_ready")
	_state(2, {"result": {"ok": true, "version": "0.18.0", "message": "Updated to 0.18.0."}})
	notice.refresh()
	await _shot("title_updated")
	notice._shown_result = false
	_state(2, {"result": {"ok": false, "version": "0.18.0", "message": "The update did not match its checksum, so it was refused. Your old version was kept."}})
	notice.refresh()
	await _shot("title_failed")
	_state(2)
	notice.refresh()
	# About page in each state
	var about := AboutPage.new()
	menu.add_child(about)
	await process_frame
	_state(3, {"mode": 1})
	await _shot("about_available")
	_state(4, {"mode": 0, "received": 21 * 1048576, "total": 54 * 1048576})
	await _shot("about_downloading")
	_state(5, {"mode": 0})
	await _shot("about_ready")
	_state(6, {"error": "The connection failed (error 2)."})
	await _shot("about_failed")
	about.queue_free()
	await process_frame
	var settings := SettingsPage.new()
	menu.add_child(settings)
	settings._select_tab(3)
	await _shot("settings_gameplay")
	quit(0)
