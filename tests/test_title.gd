extends SceneTree
## The title screen: the live pixel world reacts to the pointer (Trevor walks
## to it, a click hops and rings, PIP follows), the framed menu opens SETTINGS
## and ABOUT as pages and restores itself afterwards, and PLAY unpauses.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	await _world()
	await _menu()
	print("[test_title] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _world() -> void:
	# A CanvasLayer host, as in the real StartMenu, so the full-rect world is laid
	# out against the viewport. Pin the viewport size the test relies on.
	var host := CanvasLayer.new()
	root.add_child(host)
	var w := TitleWorld.new()
	host.add_child(w)
	await _step(3)
	w.advance(0.0)
	_check("the world has a real size", w.size.x > 100.0 and w.size.y > 100.0)

	var start_x := w.trevor_position().x
	var target := Vector2(w.trevor_range().y - 40.0, 600.0)
	w.set_pointer(target)
	# Walk speed is 150/s and the ledge can be ~1000px wide: give it time.
	for _i in 480:
		w.advance(1.0 / 60.0)
	_check("Trevor walks toward the pointer", w.trevor_position().x > start_x + 100.0)
	_check("and stops near it", absf(w.trevor_position().x - target.x) < 30.0)
	_check("and settles into idle", w.current_animation() == "idle")

	var y0 := w.trevor_position().y
	w.click(target)
	_check("a click spawns a ring", w.ring_count() == 1)
	var peak := 0.0
	for _i in 30:
		w.advance(1.0 / 60.0)
		peak = maxf(peak, y0 - w.trevor_position().y)
	_check("a click makes Trevor hop", peak > 40.0)
	for _i in 120:
		w.advance(1.0 / 60.0)
	_check("he lands back on the ledge", is_equal_approx(w.trevor_position().y, y0))
	_check("rings fade out", w.ring_count() == 0)

	_check("PIP follows the pointer",
		w.pip_position().distance_to(target + Vector2(18, -18)) < 40.0)

	# Left-column pointer must not drag Trevor off the ledge into the menu.
	w.set_pointer(Vector2(100, 400))
	for _i in 200:
		w.advance(1.0 / 60.0)
	_check("a pointer over the menu does not pull Trevor off the ledge",
		w.trevor_position().x >= w.trevor_range().x - 1.0)

	# Everything he does stays inside the ledge range.
	_check("Trevor never leaves the ledge range",
		w.trevor_position().x >= w.trevor_range().x - 1.0 and w.trevor_position().x <= w.trevor_range().y + 1.0)
	host.queue_free()
	await _step(2)


func _menu() -> void:
	var menu := StartMenu.new()
	root.add_child(menu)
	await _step(4)
	_check("title pauses the game", paused)
	_check("PLAY has focus", menu._play_btn.has_focus() or menu._play_btn.is_inside_tree())
	_check("the world and the column exist", menu._world != null and menu._column != null)

	menu._on_settings()
	await _step(3)
	_check("SETTINGS hides the title column", not menu._column.visible and not menu._world.visible)
	var page: SettingsPage = null
	for c in menu.get_children():
		if c is SettingsPage:
			page = c
	_check("SETTINGS opens the settings page", page != null)
	page.close()
	await _step(3)
	_check("closing it restores the title", menu._column.visible and menu._world.visible)

	menu._on_about()
	await _step(3)
	var about: AboutPage = null
	for c in menu.get_children():
		if c is AboutPage:
			about = c
	_check("ABOUT opens its own page", about != null and not menu._column.visible)
	about._input_cancel_for_test() if about.has_method("_input_cancel_for_test") else about.close()
	await _step(3)
	_check("closing ABOUT restores the title", menu._column.visible)

	_check("update message: same version", AboutPage.update_message("v1.2.3", "1.2.3").begins_with("up to date"))
	_check("update message: newer version", "1.2.4 available" in AboutPage.update_message("v1.2.4", "1.2.3"))

	# PLAY (intro already seen) unpauses and removes the title.
	var gs: Node = root.get_node("GameSettings")
	gs.intro_seen = true
	var dismissed := [false]
	menu.dismissed.connect(func(): dismissed[0] = true)
	menu._on_play()
	await _step(3)
	_check("PLAY dismisses the title", dismissed[0])
	_check("PLAY unpauses the game", not paused)
	gs.reset_settings()
