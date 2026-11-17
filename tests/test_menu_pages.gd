extends SceneTree
## The full-page menus: SettingsPage (tabs, rebinding capture, feel presets,
## dead-zone), ControlsPage (reads the live InputMap) and the "suit computer"
## pause menu that opens them. Drives the real controls through their handlers
## and synthetic input events, then checks the stored settings and InputMap.

var _failures: int = 0
var _gs: Node


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_gs = root.get_node("GameSettings")
	InputBindings.snapshot_defaults()
	await _settings_page()
	await _controls_page()
	await _pause_menu()
	_gs.reset_settings()
	print("[test_menu_pages] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _action(name: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	e.pressed = true
	return e


func _visible_page_count(page: SettingsPage) -> int:
	var n := 0
	for p in page._pages:
		if p.visible:
			n += 1
	return n


func _free_key() -> int:
	for code in [KEY_J, KEY_K, KEY_U, KEY_I, KEY_O, KEY_P, KEY_N, KEY_M]:
		if InputBindings.conflict("jump", code) == "" and code not in InputBindings.keys_for("jump"):
			return code
	return 0


func _settings_page() -> void:
	var page := SettingsPage.new()
	root.add_child(page)
	await _step(3)
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)

	_check("six tabs", page._tab_buttons.size() == 6 and page._pages.size() == 6)
	_check("exactly one tab page is visible", _visible_page_count(page) == 1)
	page._input(_key(KEY_E))
	_check("E moves to the next tab", page._tab == 1 and _visible_page_count(page) == 1)
	page._input(_key(KEY_Q))
	page._input(_key(KEY_Q))
	_check("Q wraps from the first tab to the last", page._tab == 5)
	page._select_tab(0)

	# Feel presets write through to the stored setting.
	page._pick_feel(Feel.Preset.INSTANT)
	_check("picking INSTANT stores it", _gs.feel_preset == Feel.Preset.INSTANT)
	_check("only the chosen preset button is pressed",
		page._feel_buttons[Feel.Preset.INSTANT].button_pressed and not page._feel_buttons[Feel.Preset.PRECISE].button_pressed)
	_check("the description follows the preset",
		page._feel_desc.text == String(Feel.DESCRIPTIONS[Feel.Preset.INSTANT]))
	page._pick_feel(Feel.Preset.SNAPPY)

	# Rebinding capture.
	var key := _free_key()
	var jump_before := InputBindings.keys_for("jump")
	page._begin_listen("jump")
	_check("the bind button prompts for a key", page._bind_buttons["jump"].text == "PRESS A KEY...")
	page._input(_key(KEY_ESCAPE))
	_check("Escape cancels the capture without closing the page",
		page._listening_action == "" and not closed[0] and InputBindings.keys_for("jump") == jump_before)
	page._begin_listen("jump")
	page._input(_key(key))
	_check("a captured key rebinds the action", InputBindings.keys_for("jump")[0] == key)
	_check("the button shows the new key", InputBindings.key_name(key) in page._bind_buttons["jump"].text)
	_check("the rebind is persisted in settings", _gs.key_bindings.get("jump", [])[0] == key)
	var dash_key: int = InputBindings.keys_for("dash")[0]
	page._begin_listen("jump")
	page._input(_key(dash_key))
	_check("taking another action's key tells the player about the swap", "now uses" in page._notice.text)
	_check("the other action is not left unbound", not InputBindings.keys_for("dash").is_empty())
	page._reset_keys()
	_check("RESET KEYS restores the shipped layout", InputBindings.keys_for("jump") == jump_before)

	# Dead-zone.
	page._set_deadzone(0.35)
	_check("dead-zone is stored", is_equal_approx(_gs.stick_deadzone, 0.35))
	_check("dead-zone reaches the InputMap", is_equal_approx(InputMap.action_get_deadzone("move_left"), 0.35))
	page._set_deadzone(0.2)

	# Escape closes the page.
	page._input(_action("ui_cancel"))
	await _step(2)
	_check("ui_cancel closes the page and signals it", closed[0])
	_check("the closed page is freed", not is_instance_valid(page) or page.is_queued_for_deletion())


func _controls_page() -> void:
	var key := _free_key()
	var page := ControlsPage.new()
	root.add_child(page)
	await _step(3)
	_check("controls page lists keys from the live InputMap",
		ControlsPage.key_text("jump") == InputBindings.key_name(InputBindings.keys_for("jump")[0]) \
		or "/" in ControlsPage.key_text("jump"))
	_gs.rebind_key("jump", key)
	_check("key_text follows a rebind", InputBindings.key_name(key) in ControlsPage.key_text("jump"))
	_gs.reset_key_bindings()
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page._input(_action("ui_cancel"))
	await _step(2)
	_check("ui_cancel closes the controls page", closed[0])


func _pause_menu() -> void:
	var scene: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var pm: Node = null
	for _i in 120:
		await physics_frame
		pm = scene.get_node_or_null("PauseMenu")
		if pm != null:
			break
	_check("pause menu exists", pm != null)
	if pm == null:
		scene.queue_free()
		return
	await _step(20)
	pm.visible = true
	await _step(3)
	_check("opens on the main view", pm._view == "main" and pm._views["main"].visible)
	_check("the main view has the expected actions", pm._main_buttons.size() >= 7)

	pm._on_levels()
	_check("LEVELS shows the grid, hides main", pm._view == "levels" and not pm._views["main"].visible)
	_check("level 1 is selectable", not pm._level_buttons[0].disabled)
	_check("a never-reached level is locked", pm._level_buttons[24].disabled)
	pm._input(_action("ui_cancel"))
	_check("Escape inside a sub-view goes back to main (not unpause)", pm._view == "main" and pm.visible)

	pm._on_progress()
	_check("PROGRESS fills its readouts", pm._progress_lines["Completed"].text.contains("/"))
	pm._show_view("main")

	pm._on_settings()
	await _step(3)
	_check("SETTINGS hides the dock and opens the page", not pm._dock.visible and is_instance_valid(pm._page))
	pm._on_settings_back()
	await _step(3)
	_check("closing the page restores the dock on the main view", pm._dock.visible and pm._view == "main")

	pm._on_controls()
	await _step(3)
	_check("CONTROLS opens its own page", pm._page is ControlsPage)
	pm._page.close()
	await _step(3)
	_check("controls page closes back to the dock", pm._dock.visible)

	pm._on_reset()
	_check("RESET asks first", pm._view == "reset")
	pm._on_reset_no()
	_check("declining keeps progress and returns", pm._view == "main")
	scene.queue_free()
	await _step(2)
