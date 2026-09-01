extends SceneTree
## Every developer tool, exercised end to end.
##
## test_dev_console.gd covers the UNLOCK: that ordinary play cannot stumble
## into it and that the right sequence works. This suite covers what the tools
## actually DO once unlocked, because "the key is bound" and "the key works"
## are different claims and only the second one matters to a tester who is
## stuck on Level 14 at midnight.
##
## Fly mode gets the most attention: it is the newest tool, it is the one that
## silently does nothing if it cannot locate the player node, and locating the
## player is exactly the kind of thing that breaks when a scene is
## reorganised.
##
## Run with:
##   Godot --headless --path <project> --script res://tests/test_dev_tools.gd

var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _press(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await physics_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await physics_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	await physics_frame
	var dev := root.get_node_or_null("DevConsole")
	if dev == null:
		_check("DevConsole autoload present", false)
		quit(1)
		return

	# Bring up a real level so the tools have something to act on.
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 3)
	root.add_child(scene)
	current_scene = scene
	await _step(8)

	# --- Unlock -----------------------------------------------------------
	for code in dev.SEQUENCE:
		await _press(code)
	_check("the sequence unlocks the console", dev.is_unlocked())

	var player = scene.get_node_or_null("Player")
	if player == null:
		_check("level 3 built a player", false)
		quit(1)
		return

	# --- The tool that silently no-ops if this breaks ---------------------
	_check("the console can locate the player node", dev._find_player() != null)

	# --- Fly mode: INSERT -------------------------------------------------
	_check("fly starts off", not dev.is_flying())
	await _press(KEY_INSERT)
	_check("Insert turns fly ON", dev.is_flying())
	_check("fly suspends the player's own physics",
		not player.is_physics_processing())

	# It must actually MOVE the player, not merely set a flag.
	var before: Vector2 = player.global_position
	Input.action_press("move_right")
	await _step(20)
	Input.action_release("move_right")
	await _step(2)
	var moved: float = player.global_position.x - before.x
	_check("flying right actually moves the player (%.0fpx)" % moved, moved > 50.0)

	# Rising is the whole point — it is what walking a route requires.
	var y_before: float = player.global_position.y
	Input.action_press("jump")
	await _step(20)
	Input.action_release("jump")
	await _step(2)
	var rose: float = y_before - player.global_position.y
	_check("flying up actually lifts the player (%.0fpx)" % rose, rose > 50.0)

	# And with physics off, gravity must not drag the player down.
	var hold: Vector2 = player.global_position
	await _step(30)
	_check("a flying player does not fall",
		absf(player.global_position.y - hold.y) < 2.0)

	await _press(KEY_INSERT)
	_check("Insert turns fly OFF", not dev.is_flying())
	_check("physics resumes when fly is turned off", player.is_physics_processing())

	# --- Skips: PAGEUP / PAGEDOWN ----------------------------------------
	var gm := root.get_node_or_null("GameManager")
	if gm != null:
		# Start well below the last level, or PageUp has nowhere to go and the
		# check measures the clamp instead of the skip.
		gm.current_level = 3
		var start: int = gm.current_level
		await _press(KEY_PAGEUP)
		_check("PageUp advances the level (%d -> %d)" % [start, gm.current_level],
			gm.current_level == start + 1)
		await _press(KEY_PAGEDOWN)
		_check("PageDown goes back (%d)" % gm.current_level,
			gm.current_level == start)

		# --- Unlock all: HOME --------------------------------------------
		await _press(KEY_HOME)
		var all_done := true
		for i in range(1, LevelData.TOTAL_LEVELS + 1):
			if not gm.save_system.levels_completed.has(i):
				all_done = false
				break
		_check("Home unlocks every level", all_done)
	else:
		_check("GameManager present", false)

	# --- Overlay: END -----------------------------------------------------
	var overlay = dev._overlay
	if overlay != null:
		var vis_before: bool = overlay.visible
		await _press(KEY_END)
		_check("End toggles the dev overlay", overlay.visible != vis_before)
		await _press(KEY_END)
		_check("End toggles it back", overlay.visible == vis_before)
	else:
		_check("the dev overlay exists once unlocked", false)

	scene.queue_free()
	await process_frame
	print("[test_dev_tools] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
