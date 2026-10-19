extends SceneTree
## LIVE verification in a real window (not headless): real mouse clicks on real buttons, real
## key and gamepad events through the engine's input path, real rendering. Screenshots go to
## .cap/live/. Run (windowed): Godot --path <project> --script res://tools/live_verify.gd
## Always run with APPDATA redirected so the real save is untouched.

var _fails: int = 0
var _shots: int = 0
var _game: Node
var _gm: Node
var _gs: Node


func _initialize() -> void:
	_go()


func _ok(label: String, ok: bool) -> void:
	print(("[LIVE PASS] " if ok else "[LIVE FAIL] ") + label)
	if not ok:
		_fails += 1


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


func _phys(n: int) -> void:
	for _i in n:
		await physics_frame


func _shot(name: String) -> void:
	await _wait(2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.cap/live"))
	var img := root.get_texture().get_image()
	_shots += 1
	img.save_png(ProjectSettings.globalize_path("res://.cap/live/%02d_%s.png" % [_shots, name]))


# ── real input helpers ──────────────────────────────────────────────

func _key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	e.keycode = code as Key
	e.pressed = down
	Input.parse_input_event(e)


func _pad(button: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button as JoyButton
	e.pressed = down
	Input.parse_input_event(e)


func _click(ctl: Control) -> void:
	var pos := ctl.get_global_rect().get_center()
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
	await _wait(2)
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.position = pos
		b.global_position = pos
		b.pressed = down
		Input.parse_input_event(b)
		await _wait(2)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for c in node.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null


func _level() -> Node:
	var lv = _game.get_node_or_null("LevelContainer")
	if lv != null and lv.get_child_count() > 0:
		return lv.get_child(lv.get_child_count() - 1)
	return null


func _player() -> Player:
	var l := _level()
	return l.get_node_or_null("Player") as Player if l != null else null


# ── the run ─────────────────────────────────────────────────────────

func _go() -> void:
	await _wait(5)
	_gm = root.get_node("GameManager")
	_gs = root.get_node("GameSettings")
	_gs.intro_seen = true
	_gs.tutorial_done = false
	_game = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	await _wait(60)
	_game.call("go_home")
	await _wait(30)
	var menu: Node = _game.get_node_or_null("StartMenu")
	_ok("title screen is showing", menu != null)
	await _shot("title")
	var tut := _find_button(menu, "TUTORIAL") if menu != null else null
	_ok("TUTORIAL button is on the title", tut != null)
	if tut == null:
		quit(1)
		return
	await _click(tut)
	for _i in 300:
		await _wait(1)
		var l := _level()
		if l != null and int(l.get("level_number")) == 0 and l.get_node_or_null("TutorialGuide") != null:
			break
	_ok("a real click on TUTORIAL opens level 0 (not level 1)", _level() != null and int(_level().get("level_number")) == 0)
	await _wait(40)
	await _shot("tutorial_start")
	var guide: TutorialGuide = _level().get_node("TutorialGuide")
	_ok("PIP shows the first lesson: %s" % guide.current_text(), guide.current_text().to_upper().contains("RUN"))
	await _live_pause_checks()
	await _play_tutorial(guide)
	await _live_dash_check()
	await _live_settings_check()
	print("[live_verify] fails=%d screenshots=%d" % [_fails, _shots])
	quit(1 if _fails > 0 else 0)


## Escape pauses, pad B (menu back / slide) does not, START pauses.
func _live_pause_checks() -> void:
	_pad(JOY_BUTTON_B, true)
	await _wait(6)
	_pad(JOY_BUTTON_B, false)
	await _wait(6)
	_ok("pressing pad B (slide) during play does NOT pause", not _gm.is_paused)
	_key(KEY_ESCAPE, true)
	await _wait(4)
	_key(KEY_ESCAPE, false)
	await _wait(20)
	_ok("Escape pauses", _gm.is_paused)
	await _shot("paused")
	_key(KEY_ESCAPE, true)
	await _wait(4)
	_key(KEY_ESCAPE, false)
	await _wait(20)
	_ok("Escape resumes", not _gm.is_paused)
	_pad(JOY_BUTTON_START, true)
	await _wait(4)
	_pad(JOY_BUTTON_START, false)
	await _wait(20)
	_ok("START (pad) pauses", _gm.is_paused)
	_pad(JOY_BUTTON_B, true)
	await _wait(4)
	_pad(JOY_BUTTON_B, false)
	await _wait(20)
	_ok("pad B resumes from the pause menu", not _gm.is_paused)


## The tutorial, driven with real key presses from spawn to the door.
func _play_tutorial(guide: TutorialGuide) -> void:
	var p := _player()
	var lessons_seen := {}
	var held := {}
	var hold := func(code: int, down: bool):
		if held.get(code, false) != down:
			held[code] = down
			_key(code, down)
	var frames := 0
	var shaft_side := 1
	var entered := false
	var jump_frames := 0
	var dashed_gap := false
	var sliding_done := false
	var ledge_y := CourseGen.ROAD_Y - 84.0 - 290.0
	while frames < 6000:
		await physics_frame
		frames += 1
		if _gm.tutorial_active == false and _game.get_node_or_null("StartMenu") != null:
			break
		p = _player()
		if p == null or not is_instance_valid(p):
			continue
		var x := p.global_position.x
		var y := p.global_position.y
		if not lessons_seen.has(guide.index):
			lessons_seen[guide.index] = true
			await _shot("lesson_%d" % guide.index)
		# Default: run right.
		var want_right := true
		var want_jump := false
		var want_dash := false
		var want_slide := false
		if x < 1100.0:
			pass
		elif x < 2060.0:
			# Jump the first gap at its lip.
			if x >= 1478.0 and x < 1560.0 and p.is_on_floor():
				want_jump = true
			elif jump_frames > 0:
				want_jump = true
		elif x < 2560.0:
			# The high step: take off early and HOLD jump.
			if x >= 2040.0 and x < 2110.0 and p.is_on_floor():
				jump_frames = 34
			want_jump = jump_frames > 0
		elif x < 3160.0:
			# Too far to jump: jump at the lip, dash at the top.
			if x >= 2530.0 and p.is_on_floor() and x < 2600.0:
				jump_frames = 14
			want_jump = jump_frames > 0
			if not dashed_gap and not p.is_on_floor() and p.velocity.y > -60.0 and x > 2560.0:
				want_dash = true
				dashed_gap = true
		elif x < 4150.0:
			# Run, then slide.
			if x > 3500.0 and not sliding_done and p.is_on_floor():
				want_slide = true
				if p.is_sliding():
					sliding_done = true
		else:
			# The shaft: walk in under the left wall, then kick from wall to wall.
			if x >= 4540.0:
				entered = true
			var on_wall: bool = entered and p.is_on_wall_only()
			if on_wall:
				shaft_side = int(p.get_wall_normal().x)
			want_right = shaft_side > 0
			if jump_frames > 0:
				pass
			elif entered and (on_wall or p.is_on_floor()):
				jump_frames = 8
			want_jump = jump_frames > 0
			# Above the shaft: aim for the ledge on the right.
			if entered and y < ledge_y + 10.0:
				want_right = true
		if jump_frames > 0:
			jump_frames -= 1
		hold.call(KEY_D, want_right)
		hold.call(KEY_A, not want_right)
		hold.call(KEY_SPACE, want_jump)
		hold.call(KEY_SHIFT, want_dash)
		hold.call(KEY_S, want_slide)
	for k in [KEY_D, KEY_A, KEY_SPACE, KEY_SHIFT, KEY_S]:
		_key(k, false)
	_ok("all six lessons were taught and completed (index %d)" % guide.index, guide.index >= TutorialGuide.LESSONS.size() or _game.get_node_or_null("StartMenu") != null)
	await _wait(30)
	_ok("finishing the tutorial returned to the title screen", _game.get_node_or_null("StartMenu") != null)
	_ok("the tutorial is marked done and left real progress alone", _gs.tutorial_done and not _gm.tutorial_active)
	await _shot("after_tutorial")


## A second dash on the ground works (it used to be one per jump).
func _live_dash_check() -> void:
	var menu: Node = _game.get_node_or_null("StartMenu")
	if menu != null:
		var play := _find_button(menu, "PLAY")
		if play != null:
			await _click(play)
	await _wait(60)
	var p := _player()
	if p == null:
		_ok("a level is playable after the tutorial", false)
		return
	var dashes := [0]
	p.dashed.connect(func(): dashes[0] += 1)
	_key(KEY_D, true)
	await _wait(40)
	for i in 3:
		_key(KEY_SHIFT, true)
		await _wait(3)
		_key(KEY_SHIFT, false)
		await _wait(42)       # past the ground cooldown
	_key(KEY_D, false)
	_ok("three ground dashes in a row all fire (%d)" % dashes[0], dashes[0] >= 3)


## Settings: Text size LARGE applies and the page still lays out.
func _live_settings_check() -> void:
	var page := SettingsPage.new()
	_game.add_child(page)
	await _wait(10)
	page._select_tab(SettingsPage.TABS.find("ACCESS"))
	await _wait(5)
	await _shot("settings_access_normal")
	var large := _find_button(page, "LARGE")
	_ok("the Text size row is on the ACCESS page", large != null)
	if large != null:
		await _click(large)
		await _wait(30)
		_ok("choosing LARGE saves the setting", _gs.get_reg("ui_text_scale") == 1)
		_ok("the UI scale is now 1.25x", is_equal_approx(UITheme.text_scale, 1.25))
		page = _game.get_node_or_null("SettingsPage") if _game.get_node_or_null("SettingsPage") != null else page
		await _shot("settings_access_large")
	_gs.reset_settings()
	UITheme.set_text_scale_index(0)
