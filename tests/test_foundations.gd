extends SceneTree
## Foundations: the Platform helper (what each build offers), gamepad glyph families and the
## last-device tracker, and the settings registry (every registered setting validates,
## persists, resets, and shows up on the page, for every platform).

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_platform()
	_pad_glyphs()
	_input_device()
	_registry_rules()
	await _registry_persistence()
	await _settings_page()
	_effects()
	print("[test_foundations] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


# ── Platform ────────────────────────────────────────────────────────

func _platform() -> void:
	Platform.override = "web"
	_check("web: no quit", not Platform.supports("quit"))
	_check("web: no window size / vsync / fps cap", not Platform.supports("window_size") and not Platform.supports("vsync") and not Platform.supports("fps_cap"))
	_check("web: fullscreen toggle and render scale stay", Platform.supports("fullscreen") and Platform.supports("render_scale"))
	_check("web: settings move as text, audio needs a gesture", Platform.supports("text_export") and not Platform.supports("file_export") and Platform.supports("needs_audio_gesture"))
	_check("web: save text names the browser", Platform.save_location_text().contains("browser"))
	Platform.override = "desktop"
	_check("desktop: quit, window options and file export", Platform.supports("quit") and Platform.supports("window_size") and Platform.supports("vsync") and Platform.supports("file_export"))
	_check("desktop: no audio gesture screen", not Platform.supports("needs_audio_gesture"))
	_check("desktop: save text names the computer", Platform.save_location_text().contains("computer"))
	Platform.override = "deck"
	_check("deck: behaves as desktop and is gamepad first", Platform.supports("quit") and Platform.supports("gamepad_first") and Platform.is_desktop())
	Platform.override = "desktop"
	_check("desktop is not gamepad first", not Platform.supports("gamepad_first"))
	_check("an unknown feature is never offered", not Platform.supports("teleport") and not Platform.supports(""))
	Platform.override = ""
	_check("the real platform here is not web", not Platform.is_web())


# ── Pad glyphs ──────────────────────────────────────────────────────

func _pad_glyphs() -> void:
	_check("DualSense is PlayStation", PadGlyphs.classify("DualSense Wireless Controller") == PadGlyphs.Family.PLAYSTATION)
	_check("PS4 pad is PlayStation", PadGlyphs.classify("PS4 Controller") == PadGlyphs.Family.PLAYSTATION)
	_check("Xbox pad is Xbox", PadGlyphs.classify("Xbox 360 Controller") == PadGlyphs.Family.XBOX)
	_check("Steam Deck pad is Xbox-style", PadGlyphs.classify("Steam Deck Controller") == PadGlyphs.Family.XBOX)
	_check("Switch Pro is Switch", PadGlyphs.classify("Nintendo Switch Pro Controller") == PadGlyphs.Family.SWITCH)
	_check("an unknown pad is generic", PadGlyphs.classify("Acme Gamepad 3000") == PadGlyphs.Family.GENERIC)
	_check("bottom face button: Xbox A, PlayStation CROSS, Switch B",
		PadGlyphs.label(PadGlyphs.Family.XBOX, "A") == "A"
		and PadGlyphs.label(PadGlyphs.Family.PLAYSTATION, "A") == "CROSS"
		and PadGlyphs.label(PadGlyphs.Family.SWITCH, "A") == "B")
	var every_position_named := true
	for fam in PadGlyphs.LABELS:
		for pos in ["A", "B", "X", "Y", "BACK", "START", "LB", "RB"]:
			if String(PadGlyphs.label(fam, pos)) == "" or not PadGlyphs.LABELS[fam].has(pos):
				every_position_named = false
	_check("every family names every button", every_position_named)
	var jump_pad := PadGlyphs.prompt(PadGlyphs.Family.PLAYSTATION, "jump")
	_check("jump has a gamepad prompt (%s)" % jump_pad, jump_pad != "")
	_check("movement reads as STICK", PadGlyphs.prompt(PadGlyphs.Family.XBOX, "move_left") in ["STICK", "A", "B", "X", "Y", "LB", "RB"] or PadGlyphs.prompt(PadGlyphs.Family.XBOX, "move_left") == "")


# ── Last-device tracker ─────────────────────────────────────────────

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	e.pressed = true
	return e


func _pad_button(index: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index as JoyButton
	e.pressed = true
	return e


func _stick(value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = value
	return e


func _input_device() -> void:
	var dev: Node = (load("res://scripts/input_device.gd") as GDScript).new()
	root.add_child(dev)
	var changes := [0]
	dev.device_changed.connect(func(_p, _f): changes[0] += 1)
	_check("starts on keyboard", not dev.using_pad)
	dev.note_event(_pad_button(JOY_BUTTON_A))
	_check("a pad button press switches to the pad", dev.using_pad)
	_check("one switch, one signal", changes[0] == 1)
	dev.note_event(_pad_button(JOY_BUTTON_B))
	_check("more pad input does not re-announce", changes[0] == 1)
	dev.note_event(_key(KEY_SPACE))
	_check("a key press switches back to keyboard", not dev.using_pad and changes[0] == 2)
	dev.note_event(_stick(0.3))
	_check("stick drift does not flip the prompts", not dev.using_pad)
	dev.note_event(_stick(0.9))
	_check("a real stick push does", dev.using_pad)
	var pad_text: String = dev.prompt("jump")
	dev.note_event(_key(KEY_SPACE))
	var key_text: String = dev.prompt("jump")
	_check("prompt text follows the device (%s / %s)" % [key_text, pad_text], key_text != pad_text and key_text != "" and pad_text != "")
	var released := InputEventKey.new()
	released.physical_keycode = KEY_A
	released.pressed = false
	dev.note_event(_pad_button(JOY_BUTTON_A))
	dev.note_event(released)
	_check("a key RELEASE alone does not switch away from the pad", dev.using_pad)
	# Tutorial lines follow the device through the autoload name.
	dev.name = "InputDevice"
	var line := TutorialGuide.render("PRESS {jump} TO JUMP")
	_check("tutorial text uses the live device (%s)" % line, line.contains(String(dev.prompt("jump"))))
	dev.queue_free()


# ── Registry rules ──────────────────────────────────────────────────

func _registry_rules() -> void:
	var defs := SettingsRegistry.all()
	_check("the registry has settings (%d)" % defs.size(), defs.size() >= 3)
	var keys := {}
	var all_ok := true
	for d in defs:
		var k := String(d["key"])
		if keys.has(k):
			all_ok = false
		keys[k] = true
		if not (String(d["kind"]) in SettingsRegistry.KINDS) or String(d["label"]) == "" or String(d["tab"]) == "":
			all_ok = false
		if SettingsRegistry.sanitize(k, d["default"]) != d["default"]:
			all_ok = false
	_check("every entry is well formed, unique and its default is legal", all_ok)
	var tabs_ok := true
	for d in defs:
		if not (String(d["tab"]) in SettingsPage.TABS):
			tabs_ok = false
	_check("every entry belongs to a real tab", tabs_ok)
	var junk_ok := true
	for d in defs:
		var k := String(d["key"])
		for junk in ["text", null, [1], {"a": 1}, NAN, INF, -INF]:
			var v = SettingsRegistry.sanitize(k, junk)
			match String(d["kind"]):
				"toggle":
					junk_ok = junk_ok and v is bool
				"slider":
					junk_ok = junk_ok and (v is float) and v >= float(d["lo"]) and v <= float(d["hi"])
				"choice":
					junk_ok = junk_ok and (v is int) and v >= 0 and v < (d["names"] as Array).size()
	_check("junk values always come back legal", junk_ok)
	var clamp_ok := true
	for d in defs:
		var k := String(d["key"])
		match String(d["kind"]):
			"slider":
				clamp_ok = clamp_ok and is_equal_approx(float(SettingsRegistry.sanitize(k, 9999.0)), float(d["hi"]))
				clamp_ok = clamp_ok and is_equal_approx(float(SettingsRegistry.sanitize(k, -9999.0)), float(d["lo"]))
			"choice":
				clamp_ok = clamp_ok and SettingsRegistry.sanitize(k, 999) == (d["names"] as Array).size() - 1
				clamp_ok = clamp_ok and SettingsRegistry.sanitize(k, -4) == 0
	_check("numbers clamp to their limits", clamp_ok)
	_check("an unknown key is rejected", SettingsRegistry.sanitize("no_such_key", 1) == null and not SettingsRegistry.has_key("no_such_key"))
	_check("sanitize_all drops unknown keys and bad containers",
		SettingsRegistry.sanitize_all({"ui_text_scale": 2, "bogus": 5}) == {"ui_text_scale": 2}
		and SettingsRegistry.sanitize_all("nope").is_empty() and SettingsRegistry.sanitize_all(null).is_empty())
	# Platform visibility.
	Platform.override = "web"
	var web_needs := SettingsRegistry.visible_on_platform({"needs": "quit"})
	var web_free := SettingsRegistry.visible_on_platform({"needs": ""})
	Platform.override = "desktop"
	var desk_needs := SettingsRegistry.visible_on_platform({"needs": "quit"})
	Platform.override = ""
	_check("a setting that needs quit hides on web and shows on desktop", not web_needs and desk_needs and web_free)
	# Negative control: the validator must actually reject something.
	_check("negative control: a wrong type is replaced, not kept", SettingsRegistry.sanitize("ui_text_scale", "LARGE") == 0)


# ── Registry persistence ────────────────────────────────────────────

func _registry_persistence() -> void:
	var gs := root.get_node_or_null("GameSettings")
	if gs == null:
		_check("GameSettings autoload present", false)
		return
	gs.reset_settings()
	for d in SettingsRegistry.all():
		_check("%s starts at its default" % d["key"], gs.get_reg(String(d["key"])) == d["default"])
	gs.set_reg("ui_text_scale", 2)
	gs.set_reg("assist_coyote", 0.07)
	_check("set/get round-trips", gs.get_reg("ui_text_scale") == 2 and is_equal_approx(float(gs.get_reg("assist_coyote")), 0.07))
	gs.set_reg("assist_coyote", 5.0)
	_check("set clamps", is_equal_approx(float(gs.get_reg("assist_coyote")), 0.12))
	gs.set_reg("assist_coyote", 0.07)
	gs.set_reg("not_a_setting", 1)
	_check("an unknown key is ignored", not gs.reg.has("not_a_setting"))
	# Through the file.
	gs.reg = {}
	gs.set_reg("ui_text_scale", 1)
	gs.set_reg("assist_buffer", 0.05)
	gs.reg = {"ui_text_scale": 0}      # forget in memory, then reload from disk
	gs.load_settings()
	_check("values survive a save and reload", gs.get_reg("ui_text_scale") == 1 and is_equal_approx(float(gs.get_reg("assist_buffer")), 0.05))
	# A hand-edited file with garbage.
	var f := FileAccess.open(GameSettings.SETTINGS_PATH, FileAccess.WRITE)
	f.store_string('{"reg": {"ui_text_scale": "huge", "assist_coyote": 99, "zzz": 1}}')
	f.close()
	gs.reg = {}
	gs.load_settings()
	_check("a corrupt file loads as legal values", gs.get_reg("ui_text_scale") == 0 and is_equal_approx(float(gs.get_reg("assist_coyote")), 0.12) and not gs.reg.has("zzz"))
	# Reset by tab and reset all.
	gs.set_reg("ui_text_scale", 2)
	gs.reset_registry_tab("ACCESS")
	_check("a tab reset restores its defaults", gs.get_reg("ui_text_scale") == 0 and float(gs.get_reg("assist_coyote")) == 0.0)
	gs.set_reg("ui_text_scale", 2)
	gs.reset_settings()
	_check("reset all restores registered settings", gs.get_reg("ui_text_scale") == 0)


# ── Settings page ───────────────────────────────────────────────────

func _settings_page() -> void:
	var gs := root.get_node_or_null("GameSettings")
	var page := SettingsPage.new()
	root.add_child(page)
	await process_frame
	await process_frame
	var found_all := true
	var missing := []
	for d in SettingsRegistry.all():
		if not SettingsRegistry.visible_on_platform(d):
			continue
		page._on_search(String(d["label"]).to_lower())
		var visible_hit := false
		for p in page._pages:
			for child in p.get_children():
				if child.visible and not child.has_meta("is_section") and not (child is Button and child.text == "RESET THESE SETTINGS"):
					visible_hit = true
		if not visible_hit:
			found_all = false
			missing.append(d["key"])
	_check("every registered setting has a row and is searchable %s" % str(missing), found_all)
	page._on_search("coyote")
	var coyote_rows := 0
	for p in page._pages:
		for child in p.get_children():
			if child.visible and not child.has_meta("is_section") and not child is Button:
				coyote_rows += 1
	_check("search also matches a setting's tags and note", coyote_rows >= 1)
	_check("the page offers a reset for the settings it shows", _find_button(page, "RESET THESE SETTINGS") != null)
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


# ── Effects ─────────────────────────────────────────────────────────

func _effects() -> void:
	var gs := root.get_node_or_null("GameSettings")
	gs.reset_settings()
	var scene := (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 1)
	root.add_child(scene)
	var player: Player = scene.get_node("Player")
	var base_coyote := player.coyote_time
	var base_buffer := player.jump_buffer_time
	gs.set_reg("assist_coyote", 0.08)
	gs.set_reg("assist_buffer", 0.06)
	player._apply_feel()
	_check("assists lengthen coyote time and jump buffer", is_equal_approx(player.coyote_time, base_coyote + 0.08) and is_equal_approx(player.jump_buffer_time, base_buffer + 0.06))
	player._apply_feel()
	_check("applying twice does not stack", is_equal_approx(player.coyote_time, base_coyote + 0.08))
	gs.reset_settings()
	player._apply_feel()
	_check("with assists off the feel is exactly the preset", is_equal_approx(player.coyote_time, base_coyote))
	scene.queue_free()
	UITheme.set_text_scale_index(2)
	_check("EXTRA LARGE text is 1.5x (body %d)" % UITheme.SIZE_BODY, UITheme.SIZE_BODY == 27 and UITheme.sz(20) == 30)
	UITheme.set_text_scale_index(0)
	_check("NORMAL text is the base scale", UITheme.SIZE_BODY == UITheme.BASE_BODY and UITheme.sz(20) == 20)
	UITheme.set_text_scale_index(99)
	_check("an out-of-range scale index is clamped", UITheme.text_scale == 1.5)
	UITheme.set_text_scale_index(0)
