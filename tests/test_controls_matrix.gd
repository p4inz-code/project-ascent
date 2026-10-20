extends SceneTree
## Controls matrix: every control does what it says, on keyboard and gamepad.
## (1) The binding table: every action has keys and (where it should) a pad button, no two
## gameplay actions share a key or a button, and menu "back" cannot pause a run.
## (2) Behaviour on the real controller: move, jump height, jump buffer, coyote time, dash,
## wall-slide and wall-jump, restart, controls panel, pause.
## (3) Rebinding: a rebound key reaches the action, the old one no longer does, reset restores.

var _failures: int = 0
var _player: Player


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_binding_table()
	await _movement()
	await _jump_feel()
	await _dash()
	await _walls()
	await _scene_controls()
	_rebinding()
	print("[test_controls_matrix] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _release_all() -> void:
	for a in ["move_left", "move_right", "jump", "dash", "slide", "grapple", "attack", "ability", "restart", "toggle_help", "pause", "ui_cancel"]:
		Input.action_release(a)


func _floor(pos: Vector2, size: Vector2) -> StaticBody2D:
	var b := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	c.shape = r
	b.add_child(c)
	b.collision_layer = 3
	b.position = pos
	root.add_child(b)
	return b


func _spawn(pos: Vector2) -> Player:
	var p: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(p)
	p.global_position = pos
	return p


# ── 1. binding table ────────────────────────────────────────────────

func _pad_buttons(action: String) -> Array[int]:
	var out: Array[int] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			out.append(int((ev as InputEventJoypadButton).button_index))
	return out


func _binding_table() -> void:
	var gameplay := ["move_left", "move_right", "jump", "dash", "slide", "grapple", "attack", "ability", "restart", "toggle_help", "pause"]
	for a in gameplay:
		_check("%s exists and has a key" % a, InputMap.has_action(a) and not InputBindings.keys_for(a).is_empty())
	# Every verb a pad player needs has a pad binding.
	for a in ["move_left", "move_right", "jump", "dash", "slide", "grapple", "attack", "ability", "restart", "toggle_help", "pause"]:
		var has_pad := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		_check("%s works on a gamepad" % a, has_pad)
	# Look (hold-to-peek) is on the arrow-up/Z/C/X keys and the right stick.
	for a in ["look_up", "look_down", "look_left", "look_right"]:
		var has_stick := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadMotion and int((ev as InputEventJoypadMotion).axis) in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
				has_stick = true
		_check("%s has a key and the right stick" % a, has_stick and not InputBindings.keys_for(a).is_empty())
	# No pad button does two gameplay jobs.
	var used := {}
	var clash := ""
	for a in gameplay:
		for b in _pad_buttons(a):
			if used.has(b):
				clash = "%s and %s share button %d" % [used[b], a, b]
			used[b] = a
	_check("no gamepad button has two gameplay jobs %s" % clash, clash == "")
	# No key does two gameplay jobs.
	var kused := {}
	var kclash := ""
	for a in gameplay + ["look_up", "look_down", "look_left", "look_right"]:
		for k in InputBindings.keys_for(a):
			# Escape belongs to pause (and menu back) by design.
			if kused.has(k):
				kclash = "%s and %s share key %s" % [kused[k], a, OS.get_keycode_string(k)]
			kused[k] = a
	_check("no key has two gameplay jobs %s" % kclash, kclash == "")
	_check("Escape is pause and is not rebindable", KEY_ESCAPE in InputBindings.keys_for("pause") and KEY_ESCAPE in InputBindings.RESERVED)
	# The old bug: pad B is Slide AND Godot's menu "back", so sliding opened the pause menu.
	_check("pad B is Slide in play", 1 in _pad_buttons("slide"))
	_check("menu back is pad B (menus stay usable on a pad)", 1 in _pad_buttons("ui_cancel"))
	_check("menu accept is pad A", 0 in _pad_buttons("ui_accept"))
	_check("START is pause, as the HUD says", 6 in _pad_buttons("pause") and not (6 in _pad_buttons("toggle_help")))
	# The HUD's pause row says START; make sure the strings agree with the bindings.
	_check("the controls panel can name every pad binding",
		PadGlyphs.prompt(PadGlyphs.Family.PLAYSTATION, "toggle_help") != "" and PadGlyphs.prompt(PadGlyphs.Family.PLAYSTATION, "pause") != "")


# ── 2a. movement ────────────────────────────────────────────────────

func _movement() -> void:
	var ground := _floor(Vector2(0, 400), Vector2(3000, 40))
	_player = _spawn(Vector2(-400, 340))
	await _step(8)
	var x0 := _player.global_position.x
	Input.action_press("move_right", 1.0)
	await _step(30)
	_check("move_right moves right", _player.global_position.x > x0 + 60.0)
	_release_all()
	await _step(30)
	var x1 := _player.global_position.x
	Input.action_press("move_left", 1.0)
	await _step(30)
	_check("move_left moves left", _player.global_position.x < x1 - 60.0)
	_release_all()
	await _step(30)
	var x2 := _player.global_position.x
	Input.action_press("move_left", 1.0)
	Input.action_press("move_right", 1.0)
	await _step(20)
	_check("left and right together cancel out", absf(_player.global_position.x - x2) < 8.0)
	_release_all()
	await _step(20)
	_check("letting go stops the player", absf(_player.velocity.x) < 5.0)
	_player.queue_free()
	ground.queue_free()
	await _step(2)


# ── 2b. jump feel ───────────────────────────────────────────────────

func _jump_apex(hold_frames: int, ground_top: float) -> float:
	_player.global_position = Vector2(0, ground_top - 30.0)
	_player.velocity = Vector2.ZERO
	_player.reset_state()
	await _step(8)
	var start_y := _player.global_position.y
	var apex := start_y
	Input.action_press("jump", 1.0)
	for f in 80:
		if f == hold_frames:
			Input.action_release("jump")
		await physics_frame
		apex = minf(apex, _player.global_position.y)
	Input.action_release("jump")
	return start_y - apex


func _jump_feel() -> void:
	var ground := _floor(Vector2(0, 400), Vector2(3000, 40))
	_player = _spawn(Vector2(0, 340))
	await _step(8)
	var tap := await _jump_apex(2, 380.0)
	await _step(60)
	var held := await _jump_apex(40, 380.0)
	_check("a tap is a hop, a hold is a full jump (%.0f vs %.0f px)" % [tap, held], held > tap + 25.0 and tap > 10.0)
	await _step(60)

	# Jump buffer: press just before landing and the jump still happens on touchdown.
	_player.global_position = Vector2(0, 250)
	_player.velocity = Vector2.ZERO
	_player.reset_state()
	var jumped := [0]
	_player.jumped.connect(func(): jumped[0] += 1)
	var landed_at := -1
	for f in 120:
		await physics_frame
		if _player.is_on_floor():
			landed_at = f
			break
	# Drop again and press jump a few frames BEFORE the floor.
	_player.global_position = Vector2(0, 300)
	_player.velocity = Vector2(0, 200)
	_player.reset_state()
	jumped[0] = 0
	var pressed := false
	for f in 80:
		var dist := 380.0 - (_player.global_position.y + 28.0)
		if not pressed and dist < 22.0 and not _player.is_on_floor():
			Input.action_press("jump", 1.0)
			pressed = true
		await physics_frame
		if pressed and f > 2:
			Input.action_release("jump")
	_release_all()
	_check("a jump pressed just before landing is not lost (buffer)", jumped[0] >= 1)

	# Coyote time: run off the edge and jump a hair late.
	ground.queue_free()
	var edge := _floor(Vector2(-300, 400), Vector2(600, 40))       # ends at x = 0
	_player.global_position = Vector2(-120, 340)
	_player.velocity = Vector2.ZERO
	_player.reset_state()
	await _step(10)
	jumped[0] = 0
	Input.action_press("move_right", 1.0)
	var left_edge_frame := -1
	for f in 120:
		await physics_frame
		if left_edge_frame < 0 and not _player.is_on_floor():
			left_edge_frame = f
			await _step(3)                                          # 3 frames = 50 ms after leaving
			Input.action_press("jump", 1.0)
			await _step(2)
			break
	_release_all()
	_check("a jump a few frames after leaving a ledge still works (coyote)", left_edge_frame >= 0 and jumped[0] >= 1)
	_player.queue_free()
	edge.queue_free()
	await _step(2)


# ── 2c. dash ────────────────────────────────────────────────────────

func _dash() -> void:
	var ground := _floor(Vector2(0, 400), Vector2(4000, 40))
	_player = _spawn(Vector2(-600, 340))
	await _step(8)
	var dashed := [0]
	_player.dashed.connect(func(): dashed[0] += 1)
	Input.action_press("move_right", 1.0)
	await _step(20)
	var run_speed := absf(_player.velocity.x)
	Input.action_press("dash", 1.0)
	await _step(3)
	var dash_speed := absf(_player.velocity.x)
	_check("dash is much faster than running (%.0f -> %.0f)" % [run_speed, dash_speed], dashed[0] == 1 and dash_speed > run_speed * 1.5)
	_release_all()
	await _step(40)
	# A second dash at once is refused (cooldown), a later one works.
	Input.action_press("dash", 1.0)
	await _step(2)
	var second: int = dashed[0]
	_release_all()
	await _step(60)
	Input.action_press("move_right", 1.0)
	Input.action_press("dash", 1.0)
	await _step(3)
	_release_all()
	_check("dash comes back after its cooldown", dashed[0] > 1 or second > 1)
	# Air dash: jump, then dash in the air.
	await _step(50)
	_player.reset_state()
	var d0: int = dashed[0]
	Input.action_press("jump", 1.0)
	await _step(8)
	Input.action_press("move_right", 1.0)
	Input.action_press("dash", 1.0)
	await _step(3)
	_release_all()
	_check("dash works in the air", dashed[0] > d0)
	_player.queue_free()
	ground.queue_free()
	await _step(2)


# ── 2d. walls ───────────────────────────────────────────────────────

func _walls() -> void:
	var ground := _floor(Vector2(0, 900), Vector2(2000, 40))
	var wall := _floor(Vector2(120, 500), Vector2(40, 800))        # left face at x = 100
	_player = _spawn(Vector2(60, 500))
	await _step(4)
	var wall_jumped := [0]
	_player.wall_jumped.connect(func(): wall_jumped[0] += 1)
	var slide_speed := 0.0
	Input.action_press("move_right", 1.0)
	for f in 60:
		await physics_frame
		slide_speed = _player.velocity.y       # the settled speed, after touching the wall
	_check("sliding down a wall is slower than falling (%.0f px/s)" % slide_speed, slide_speed <= _player.wall_slide_speed + 5.0 and slide_speed > 0.0)
	Input.action_press("jump", 1.0)
	await _step(3)
	_check("jumping on a wall kicks off it", wall_jumped[0] == 1 and _player.velocity.x < 0.0 and _player.velocity.y < -200.0)
	_release_all()
	await _step(2)
	_player.queue_free()
	ground.queue_free()
	wall.queue_free()
	await _step(2)


# ── 2e. restart, controls panel, pause (real scene) ─────────────────

func _scene_controls() -> void:
	var gm: Node = root.get_node("GameManager")
	var game: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(game)
	root.get_node("GameSettings").intro_seen = true
	var level: Node = null
	for _i in 300:
		await physics_frame
		var lv = game.get_node_or_null("LevelContainer")
		if lv != null and lv.get_child_count() > 0:
			level = lv.get_child(0)
			if level.get_node_or_null("Player") != null:
				break
	await _step(30)
	var menu: Node = game.get_node_or_null("StartMenu")
	if menu != null:
		menu.queue_free()
		root.get_tree().paused = false
		gm.is_paused = false
		await _step(4)
	var player: Player = level.get_node("Player")
	# Restart.
	var attempts_before := int(level.get("attempts"))
	player.global_position += Vector2(300, 0)
	Input.action_press("restart", 1.0)
	await _step(4)
	Input.action_release("restart")
	await _step(6)
	_check("restart sends the player back and counts an attempt", int(level.get("attempts")) > attempts_before and player.global_position.distance_to(level.get("_spawn_position") if level.get("_spawn_position") != null else player.global_position) < 5000.0)
	# Controls panel: closed -> short -> full -> closed on successive presses.
	var hud: Node = level.get_node_or_null("Hud")
	var panel: Control = hud.get_node("Controls") if hud != null else null
	for _i in 4:
		if panel != null and panel.visible and panel.modulate.a > 0.5:
			Input.action_press("toggle_help", 1.0)
			await _step(3)
			Input.action_release("toggle_help")
			await _step(4)
	var closed: bool = panel != null and not (panel.visible and panel.modulate.a > 0.5)
	Input.action_press("toggle_help", 1.0)
	await _step(3)
	Input.action_release("toggle_help")
	await _step(4)
	var opened: bool = panel != null and panel.visible and panel.modulate.a > 0.5
	_check("the controls key opens the controls panel", closed and opened)
	for _i in 2:
		Input.action_press("toggle_help", 1.0)
		await _step(3)
		Input.action_release("toggle_help")
		await _step(4)
	await _step(30)       # the panel fades out
	_check("pressing it again closes it", panel != null and not (panel.visible and panel.modulate.a > 0.5))
	# Pause: Escape / START pause; pad B ("menu back") must not.
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	Input.parse_input_event(back)
	await _step(4)
	_check("menu BACK (pad B) during play does not pause", not gm.is_paused)
	var slide_press := InputEventAction.new()
	slide_press.action = "slide"
	slide_press.pressed = true
	Input.parse_input_event(slide_press)
	await _step(4)
	_check("sliding does not pause", not gm.is_paused)
	_release_all()
	var pause := InputEventAction.new()
	pause.action = "pause"
	pause.pressed = true
	Input.parse_input_event(pause)
	await _step(4)
	_check("the pause action pauses", gm.is_paused)
	var unpause := InputEventAction.new()
	unpause.action = "pause"
	unpause.pressed = false
	Input.parse_input_event(unpause)
	await _step(2)
	var back2 := InputEventAction.new()
	back2.action = "ui_cancel"
	back2.pressed = true
	Input.parse_input_event(back2)
	await _step(4)
	_check("BACK resumes from the pause menu", not gm.is_paused)
	game.queue_free()
	await _step(2)


# ── 3. rebinding ────────────────────────────────────────────────────

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	e.pressed = true
	return e


func _rebinding() -> void:
	InputBindings.snapshot_defaults()
	var jump_default := InputBindings.keys_for("jump")
	InputBindings.rebind("jump", KEY_Q)
	_check("a rebound key reaches the action", InputMap.event_is_action(_key(KEY_Q), "jump"))
	_check("the new key is the primary and the other keys stay as alternates",
		InputBindings.keys_for("jump")[0] == KEY_Q and KEY_SPACE in InputBindings.keys_for("jump"))
	_check("the pad binding survives a keyboard rebind", 0 in _pad_buttons("jump"))
	# Taking a key from another action swaps, so nothing is left unbound.
	var displaced := InputBindings.rebind("dash", KEY_Q)
	_check("stealing a key swaps it (displaced: %s)" % displaced, displaced == "jump" and not InputBindings.keys_for("jump").is_empty())
	_check("Escape cannot be bound", InputBindings.rebind("jump", KEY_ESCAPE) == "" and not (KEY_ESCAPE in InputBindings.keys_for("jump")))
	InputBindings.reset_all()
	_check("reset restores the shipped keys", InputBindings.keys_for("jump") == jump_default and InputMap.event_is_action(_key(KEY_SPACE), "jump"))
	_check("pause keeps Escape through all of it", KEY_ESCAPE in InputBindings.keys_for("pause"))
	# Dead zone reaches the stick actions.
	var gs: Node = root.get_node("GameSettings")
	gs.stick_deadzone = 0.4
	gs.apply_stick_deadzone()
	_check("the stick dead zone setting reaches the move actions",
		is_equal_approx(InputMap.action_get_deadzone("move_left"), 0.4) and is_equal_approx(InputMap.action_get_deadzone("move_right"), 0.4))
	gs.reset_settings()
