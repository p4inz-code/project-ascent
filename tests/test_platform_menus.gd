extends SceneTree
## Every menu built as each platform: the web has no quit and no window options, desktop has them,
## the Steam Deck is desktop plus gamepad-first, and nothing is ever offered that the platform
## cannot do.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await process_frame


func _texts(node: Node, out: Array = []) -> Array:
	if node is Button:
		out.append((node as Button).text)
	elif node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_texts(c, out)
	return out


func _has(texts: Array, needle: String) -> bool:
	for t in texts:
		if String(t).contains(needle):
			return true
	return false


func _boot() -> void:
	await process_frame
	for plat in ["desktop", "web", "deck"]:
		Platform.override = plat
		var web: bool = (plat == "web")
		# Title menu.
		var menu := StartMenu.new()
		root.add_child(menu)
		await _step(3)
		var t := _texts(menu)
		_check("%s title: PLAY, TUTORIAL, STORY, SETTINGS, ABOUT" % plat,
			_has(t, "PLAY") and _has(t, "TUTORIAL") and _has(t, "STORY") and _has(t, "SETTINGS") and _has(t, "ABOUT"))
		_check("%s title: QUIT is %s" % [plat, "hidden" if web else "shown"], _has(t, "QUIT") != web)
		menu.queue_free()
		root.get_tree().paused = false
		await _step(2)
		# Pause menu (inside a real game scene so it has its level).
		var gs: Node = root.get_node("GameSettings")
		gs.intro_seen = true
		var game: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
		root.add_child(game)
		await _step(40)
		var start: Node = game.get_node_or_null("StartMenu")
		if start != null:
			start.queue_free()
			root.get_tree().paused = false
		var pause: Node = game.get_node_or_null("PauseMenu")
		_check("%s: a pause menu exists" % plat, pause != null)
		if pause != null:
			var pt := _texts(pause)
			_check("%s pause: QUIT TO DESKTOP is %s" % [plat, "hidden" if web else "shown"], _has(pt, "QUIT TO DESKTOP") != web)
		game.queue_free()
		await _step(3)
		# Settings page: which display rows are offered.
		var page := SettingsPage.new()
		root.add_child(page)
		await _step(3)
		var st := _texts(page)
		var window_rows := _has(st, "WINDOWED") and _has(st, "BORDERLESS")
		var size_rows := _has(st, "1280 X 720")
		var vsync_row := _has(st, "Vertical sync")
		var fps_row := _has(st, "Frame rate limit")
		var fullscreen_toggle := _has(st, "Fullscreen")
		_check("%s settings: window mode rows %s" % [plat, "absent" if web else "present"], window_rows != web)
		_check("%s settings: window size, vsync and frame cap %s" % [plat, "absent" if web else "present"],
			(size_rows and vsync_row and fps_row) != web and (size_rows or vsync_row or fps_row) != web)
		_check("%s settings: the fullscreen toggle is %s" % [plat, "present" if web else "absent"], fullscreen_toggle == web)
		_check("%s settings: backup note names where saves live (%s)" % [plat, Platform.save_location_text().left(24)],
			_has(st, "Saved in this browser") == web)
		_check("%s settings: shared options are always there (quality, text size, assists)",
			_has(st, "Quality preset") and _has(st, "Text size") and _has(st, "Hazard speed"))
		page.queue_free()
		await _step(2)
		# About page: the update line.
		var about := AboutPage.new()
		root.add_child(about)
		await _step(40)
		if web:
			for b in about.find_children("*", "Button", true, false):
				if String((b as Button).text).to_upper().contains("UPDATE"):
					(b as Button).pressed.emit()
			await _step(3)
		var at := _texts(about)
		_check("%s about: %s" % [plat, "always up to date in a browser" if web else "no browser-only wording"],
			_has(at, "always up to date") == web)
		about.queue_free()
		await _step(2)
		# Ending screen: its buttons (home / reset / continue) exist on every platform.
		var ending := EndingScreen.new()
		ending.total = SaveSystem.ORB_GOAL
		ending.goal = SaveSystem.ORB_GOAL
		ending.skip_animation = true
		root.add_child(ending)
		await _step(4)
		var et := _texts(ending)
		_check("%s ending: continue, home and reset are offered and no quit" % plat,
			_has(et, "CONTINUE") and not _has(et, "QUIT"))
		ending.queue_free()
		await _step(2)
	Platform.override = ""
	# Deck specifics.
	Platform.override = "deck"
	_check("deck is gamepad first", Platform.supports("gamepad_first") and Platform.is_desktop())
	Platform.override = ""
	print("[test_platform_menus] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
