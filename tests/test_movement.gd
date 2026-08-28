extends SceneTree
## Headless runtime test for the player controller and level respawn.
## Instantiates the real main scene, drives the real physics engine, and
## asserts on actual runtime behaviour. Run with:
##   Godot --headless --path <project> --script res://tests/test_movement.gd
## Exit code 0 = all checks passed, 1 = a check failed.
##
## Implemented as a coroutine on _initialize that awaits `physics_frame`, so the
## normal SceneTree loop keeps processing the game nodes between steps.

var _main: Node
var _player: CharacterBody2D
var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _press_key(physical: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = physical
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _step(frames: int) -> void:
	for _i in frames:
		await physics_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	_main = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await physics_frame
	_player = _main.get_node("Player")
	var spawn := _player.global_position

	# Binding test: a real device-0 Space keydown must satisfy "jump".
	_press_key(KEY_SPACE, true)
	_check("device-0 Space matches 'jump' action binding", Input.is_action_pressed("jump"))
	_press_key(KEY_SPACE, false)
	_check("all five actions exist", InputMap.has_action("move_left")
		and InputMap.has_action("move_right") and InputMap.has_action("jump")
		and InputMap.has_action("dash") and InputMap.has_action("restart"))

	# Phase 1: settle on the ground.
	await _step(40)
	_check("player settles on floor", _player.is_on_floor())
	_check("player rests with ~zero vertical speed", absf(_player.velocity.y) < 5.0)

	# Phase 2: run right.
	var run_start_x := _player.global_position.x
	Input.action_press("move_right", 1.0)
	await _step(40)
	_check("running builds rightward speed", _player.velocity.x > 250.0)
	_check("player actually moved right", _player.global_position.x > run_start_x + 100.0)
	Input.action_release("move_right")

	# Phase 3: decelerate to rest.
	await _step(30)
	_check("player decelerates to near rest", absf(_player.velocity.x) < 20.0)

	# Phase 4: jump from the ground. Press and hold, let a few frames elapse,
	# then confirm the player has committed to a rising arc. Checking the exact
	# press frame is racy against input/physics ordering, so we validate the
	# observable outcome (left the floor, moving up, gained height).
	_check("on floor before jump", _player.is_on_floor())
	var jump_start_y := _player.global_position.y
	_press_key(KEY_SPACE, true)
	await _step(5)
	_check("jump leaves the floor", not _player.is_on_floor())
	_check("jump produces a rising arc", _player.velocity.y < -50.0)
	_press_key(KEY_SPACE, false)

	# Phase 5: confirm airborne rise past the launch height.
	await _step(6)
	_check("player rose above jump origin", _player.global_position.y < jump_start_y - 20.0)

	# Phase 6: fall-death respawn. Checked one frame later, before gravity has
	# had time to rebuild speed, so we can assert the fall velocity was cleared.
	_player.global_position.y = _main.kill_depth + 100.0
	await physics_frame
	_check("respawn returns player to spawn", _player.global_position.distance_to(spawn) < 2.0)
	_check("respawn clears fall velocity", _player.velocity.y < 100.0)

	print("[test_movement] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
