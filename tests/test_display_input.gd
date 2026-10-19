extends SceneTree
## Display options per platform, controller rumble, button-prompt style, and settings backup.

var _failures: int = 0
var _gs: Node


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_gs = root.get_node("GameSettings")
	_gs.reset_settings()
	_display_plan()
	_display_visibility()
	await _haptics()
	_prompt_style()
	await _hud_labels()
	_backup()
	await _backup_page()
	print("[test_display_input] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame
	await process_frame


# ── display ─────────────────────────────────────────────────────────

func _display_plan() -> void:
	var desk := DisplayApply.plan({}, false)
	_check("desktop defaults: windowed, vsync on, no frame cap, size left alone",
		desk["mode"] == "windowed" and desk["size"] == Vector2i.ZERO and desk["vsync"] == true and desk["max_fps"] == 0)
	var p := DisplayApply.plan({"disp_window_mode": 0, "disp_window_size": 2}, false)
	_check("windowed 1600 x 900", p["size"] == Vector2i(1600, 900))
	p = DisplayApply.plan({"disp_window_mode": 1, "disp_window_size": 3}, false)
	_check("borderless ignores the window size", p["mode"] == "borderless" and p["size"] == Vector2i.ZERO)
	p = DisplayApply.plan({"disp_window_mode": 2}, false)
	_check("fullscreen is fullscreen", p["mode"] == "fullscreen")
	p = DisplayApply.plan({"disp_vsync": false, "disp_fps_cap": 3}, false)
	_check("vsync off and a 120 cap", p["vsync"] == false and p["max_fps"] == 120)
	p = DisplayApply.plan({"disp_window_mode": 99, "disp_window_size": -4, "disp_fps_cap": 77}, false)
	_check("out-of-range values are clamped, never an error", p["mode"] == "fullscreen" and p["max_fps"] == 144)
	var web := DisplayApply.plan({"disp_window_mode": 2, "disp_window_size": 4, "disp_vsync": false, "disp_fps_cap": 4}, true)
	_check("the web ignores window mode, size, vsync and frame cap",
		web["mode"] == "windowed" and web["size"] == Vector2i.ZERO and web["vsync"] == null and web["max_fps"] == -1)
	_check("the web only has the fullscreen toggle", DisplayApply.plan({"disp_fullscreen": true}, true)["mode"] == "fullscreen")


func _display_visibility() -> void:
	var web_shown := []
	var desk_shown := []
	Platform.override = "web"
	for d in SettingsRegistry.for_tab("VIDEO"):
		if String(d["section"]) == "DISPLAY" and SettingsRegistry.shown(d):
			web_shown.append(d["key"])
	Platform.override = "desktop"
	for d in SettingsRegistry.for_tab("VIDEO"):
		if String(d["section"]) == "DISPLAY" and SettingsRegistry.shown(d):
			desk_shown.append(d["key"])
	Platform.override = ""
	_check("web shows only the fullscreen toggle %s" % str(web_shown), web_shown == ["disp_fullscreen"])
	_check("desktop shows mode, size, vsync and frame cap %s" % str(desk_shown),
		desk_shown == ["disp_window_mode", "disp_window_size", "disp_vsync", "disp_fps_cap"])
	_check("desktop never shows the web-only toggle", not ("disp_fullscreen" in desk_shown))


# ── haptics ─────────────────────────────────────────────────────────

func _haptics() -> void:
	var sent: Array = []
	Haptics.sink = func(w, s, t): sent.append([w, s, t])
	Haptics.assume_pad = true
	_gs.set_reg("ctl_vibration", 1.0)
	Haptics.pulse(0.4, 0.8, 0.1)
	_check("full strength sends the values as asked", sent.size() == 1 and is_equal_approx(sent[0][0], 0.4) and is_equal_approx(sent[0][1], 0.8))
	sent.clear()
	_gs.set_reg("ctl_vibration", 0.5)
	Haptics.pulse(0.4, 0.8, 0.1)
	_check("half strength halves them", sent.size() == 1 and is_equal_approx(sent[0][0], 0.2) and is_equal_approx(sent[0][1], 0.4))
	sent.clear()
	_gs.set_reg("ctl_vibration", 0.0)
	Haptics.pulse(1.0, 1.0, 0.5)
	Haptics.death()
	_check("strength zero is silent", sent.is_empty())
	_gs.set_reg("ctl_vibration", 1.0)
	Haptics.assume_pad = false
	Haptics.pulse(1.0, 1.0, 0.5)
	_check("with no controller connected nothing is sent", sent.is_empty() or not Input.get_connected_joypads().is_empty())
	Haptics.assume_pad = true
	# The player's own events reach it.
	var player: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await _step(4)
	var h := player.get_node_or_null("Haptics")
	_check("the player carries a haptics node", h != null)
	sent.clear()
	player.dashed.emit()
	_check("a dash gives a light tap", sent.size() == 1 and sent[0][0] > 0.0 and sent[0][1] == 0.0)
	sent.clear()
	player.landed.emit(100.0)
	_check("a soft landing is silent", sent.is_empty())
	player.landed.emit(1200.0)
	_check("a hard landing thumps", sent.size() == 1 and sent[0][1] > 0.4)
	sent.clear()
	player.ground_pounded.emit()
	_check("a ground pound is the strongest of the movement cues", sent.size() == 1 and sent[0][1] >= 0.9)
	sent.clear()
	player.wall_jumped.emit()
	_check("a wall kick gives a small tap", sent.size() == 1)
	sent.clear()
	Haptics.death()
	_check("a death thumps hard", sent.size() == 1 and sent[0][1] >= 1.0 and sent[0][2] >= 0.3)
	player.queue_free()
	Haptics.sink = Callable()
	Haptics.assume_pad = false
	_gs.reset_settings()


# ── prompt style ────────────────────────────────────────────────────

func _prompt_style() -> void:
	var dev: Node = (load("res://scripts/input_device.gd") as GDScript).new()
	root.add_child(dev)
	dev.name = "InputDevice"
	_gs.set_reg("ctl_prompt_style", 0)
	var key_text: String = dev.prompt("jump")
	_check("AUTO on the keyboard shows a key (%s)" % key_text, key_text != "" and key_text != "CROSS" and key_text != "A")
	_gs.set_reg("ctl_prompt_style", 3)
	_check("PLAYSTATION forces pad prompts even from the keyboard (%s)" % dev.prompt("jump"), dev.prompt("jump") == "CROSS")
	_gs.set_reg("ctl_prompt_style", 2)
	_check("XBOX says A", dev.prompt("jump") == "A")
	_gs.set_reg("ctl_prompt_style", 4)
	_check("SWITCH says B for the bottom button", dev.prompt("jump") == "B")
	_gs.set_reg("ctl_prompt_style", 1)
	dev.note_event(_pad_press())
	_check("KEYBOARD stays on keys even after a pad press", dev.prompt("jump") == key_text)
	_gs.set_reg("ctl_prompt_style", 0)
	_check("AUTO follows the pad again", dev.prompt("jump") != key_text)
	var line := TutorialGuide.render("PRESS {jump} TO JUMP")
	_check("the tutorial text follows the style (%s)" % line, line.contains(String(dev.prompt("jump"))))
	_gs.set_reg("ctl_prompt_style", 3)
	dev.queue_free()
	_gs.reset_settings()


func _hud_labels() -> void:
	var dev: Node = (load("res://scripts/input_device.gd") as GDScript).new()
	dev.name = "InputDevice"
	root.add_child(dev)
	var scene := (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 1)
	root.add_child(scene)
	await _step(6)
	var hud: Node = scene.get_node("Hud")
	_gs.set_reg("ctl_prompt_style", 3)
	_check("the controls panel writes PlayStation labels when chosen", hud._pad_label("A") == "CROSS" and hud._pad_label("START") == "OPTIONS")
	_gs.set_reg("ctl_prompt_style", 4)
	_check("and Switch labels", hud._pad_label("A") == "B" and hud._pad_label("START") == "+")
	_gs.set_reg("ctl_prompt_style", 2)
	_check("and Xbox labels", hud._pad_label("A") == "A" and hud._pad_label("BACK") == "VIEW")
	scene.queue_free()
	dev.queue_free()
	_gs.reset_settings()
	await _step(2)


func _pad_press() -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A as JoyButton
	e.pressed = true
	return e


# ── backup ──────────────────────────────────────────────────────────

func _backup() -> void:
	_gs.reset_settings()
	_gs.set_reg("ui_text_scale", 2)
	_gs.set_reg("assist_coyote", 0.09)
	_gs.set_reg("cam_zoom", 0)
	_gs.master_volume = 0.35
	_gs.accessory = 2
	var text: String = _gs.export_text()
	_check("the export is JSON text", text.begins_with("{") and text.length() > 100)
	_gs.reset_settings()
	_check("reset really cleared them", _gs.get_reg("ui_text_scale") == 0 and is_equal_approx(_gs.master_volume, 1.0))
	var err: String = _gs.import_text(text)
	_check("importing the copy succeeds", err == "")
	_check("and restores registered settings, volumes and the character",
		_gs.get_reg("ui_text_scale") == 2 and is_equal_approx(float(_gs.get_reg("assist_coyote")), 0.09)
		and _gs.get_reg("cam_zoom") == 0 and is_equal_approx(_gs.master_volume, 0.35) and _gs.accessory == 2)
	# Junk is rejected without touching anything.
	var before: Dictionary = _gs.settings_dict().duplicate(true)
	for junk in ["", "   ", "not json at all", "[1, 2, 3]", "{\"hello\": 1}", "42", "{\"reg\": "]:
		var e: String = _gs.import_text(junk)
		_check("bad paste is refused with a message: %s" % junk.left(18).replace("\n", " "), e != "")
	_check("a refused paste changes nothing", _gs.settings_dict() == before)
	# Hostile values inside a valid file are clamped, not trusted.
	var hostile := {"reg": {"ui_text_scale": 999, "assist_coyote": "lots", "cam_zoom": -5, "nope": 1},
		"master_volume": 7.0, "accessory": 9999, "key_bindings": {"jump": [999999999, "x"]}}
	var e2: String = _gs.import_text(JSON.stringify(hostile))
	_check("a hostile but well-formed paste is accepted and clamped", e2 == ""
		and _gs.get_reg("ui_text_scale") == 2 and is_equal_approx(float(_gs.get_reg("assist_coyote")), 0.0)
		and _gs.get_reg("cam_zoom") == 0 and _gs.master_volume <= 1.0 and not _gs.reg.has("nope"))
	_gs.reset_settings()


func _backup_page() -> void:
	var page := SettingsPage.new()
	root.add_child(page)
	await _step(3)
	_check("the ACCESS page has COPY and PASTE buttons",
		_find_button(page, "COPY MY SETTINGS") != null and _find_button(page, "PASTE SETTINGS FROM CLIPBOARD") != null)
	page._on_search("backup")
	var shown := 0
	for p in page._pages:
		for child in p.get_children():
			if child.visible and not child.has_meta("is_section"):
				shown += 1
	_check("backup is searchable", shown >= 2)
	page.queue_free()
	await process_frame


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for c in node.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null
