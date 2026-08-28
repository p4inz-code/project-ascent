extends "res://tests/test_base.gd"
## Headless runtime test for the player controller and level respawn.
## Instantiates the real main scene, drives the real physics engine, and
## asserts on actual runtime behaviour. Run with:
##   Godot --headless --path <project> --script res://tests/test_movement.gd
## Exit code 0 = all checks passed, 1 = a check failed.
##
## Implemented as a coroutine on _run that awaits `physics_frame`, so the
## normal SceneTree loop keeps processing the game nodes between steps.


func _suite_name() -> String:
	return "test_movement"


func _run() -> void:
	var spawn := _player.global_position

	# Binding test: a real device-0 Space keydown must satisfy "jump".
	_press_key(KEY_SPACE, true)
	_check("device-0 Space matches 'jump' action binding", Input.is_action_pressed("jump"))
	_press_key(KEY_SPACE, false)
	_check("all six actions exist", InputMap.has_action("move_left")
		and InputMap.has_action("move_right") and InputMap.has_action("jump")
		and InputMap.has_action("dash") and InputMap.has_action("restart")
		and InputMap.has_action("toggle_help"))

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

	# Phase 7: dash. Let the player settle, then dash right and confirm it
	# reaches dash speed horizontally, then ends and bleeds back to the cap.
	await _step(20)
	_check("grounded before dash", _player.is_on_floor())
	Input.action_press("move_right", 1.0)
	await physics_frame
	_press_key(KEY_J, true)
	# Scan a few frames so the check isn't sensitive to the exact frame the
	# dash fires on.
	var dashed := false
	var peak_vx := 0.0
	for _i in 4:
		await physics_frame
		if _player._is_dashing:
			dashed = true
		peak_vx = maxf(peak_vx, _player.velocity.x)
	_check("dash triggers", dashed)
	_check("dash reaches dash speed", peak_vx > _player.dash_speed - 40.0)
	_press_key(KEY_J, false)
	Input.action_release("move_right")
	await _step(20)
	_check("dash ends", not _player._is_dashing)
	_check("dash bleeds back to speed cap", absf(_player.velocity.x) <= _player.max_speed + 1.0)

	# Phase 8: wall slide + wall jump. Park the player just left of the
	# rightmost wall's face in open air, hold into the wall, and let gravity pull.
	var wall_left := -INF
	var wall_top := 0.0
	var found_wall := false
	for child in _main.get_node("Terrain").get_children():
		if child is GreyboxPlatform and child.edge_thickness == 0.0 and child.size.x < 60.0:
			var left: float = child.global_position.x - child.size.x * 0.5
			if not found_wall or left > wall_left:
				wall_left = left
				wall_top = child.global_position.y
				found_wall = true
	# Fallback to legacy ShaftWall coordinate if no wall found.
	if not found_wall and _main.has_node("Terrain/ShaftWall"):
		var w: Node2D = _main.get_node("Terrain/ShaftWall")
		wall_left = w.global_position.x - w.size.x * 0.5
		wall_top = w.global_position.y
		found_wall = true
	if not found_wall:
		wall_left = 2620.0
		wall_top = 480.0
	_player.global_position = Vector2(wall_left - 20.0, wall_top - 10.0)
	_player.velocity = Vector2.ZERO
	Input.action_press("move_right", 1.0)
	await _step(12)
	_check("player is on the wall (airborne)", _player.is_on_wall_only())
	_check("wall slide caps fall speed", _player.velocity.y <= _player.wall_slide_speed + 5.0)

	# Wall jump: launch up and away (to the left, off a right-hand wall).
	_press_key(KEY_SPACE, true)
	await _step(2)
	_check("wall jump launches away from wall", _player.velocity.x < -100.0)
	_check("wall jump launches upward", _player.velocity.y < -100.0)
	_press_key(KEY_SPACE, false)
	Input.action_release("move_right")

	# Phase 9: landing signal reports the real impact speed. The signal is read
	# after move_and_slide zeroes velocity.y on contact, so it must be captured
	# pre-collision — otherwise it always emits ~0. Drop from a height and assert
	# the emitted fall speed matches a genuine impact, not zero. (Capture via a
	# one-element Array: a lambda can't write back to an outer local.)
	var landed_box := [-1.0]
	var _cb := func(fs: float) -> void: landed_box[0] = fs
	_player.landed.connect(_cb)
	_player.global_position = Vector2(600.0, 400.0) # above the wide Ground
	_player.velocity = Vector2.ZERO
	for _i in 90:
		await physics_frame
		if landed_box[0] >= 0.0:
			break
	_player.landed.disconnect(_cb)
	var landed_speed: float = landed_box[0]
	_check("landing signal fires on touchdown", landed_speed >= 0.0)
	_check("landing signal reports real impact speed (not zeroed)", landed_speed > 200.0)

	# Phase 10: respawn clears transient state. Start a dash, then fall-kill the
	# player mid-dash; the new life must not inherit the dash (which, with velocity
	# zeroed by respawn, would otherwise freeze it for the rest of dash_time).
	await _step(20)
	_check("grounded before mid-dash respawn", _player.is_on_floor())
	Input.action_press("move_right", 1.0)
	await physics_frame
	_press_key(KEY_J, true)
	await _step(2)
	_check("dash active before respawn", _player._is_dashing)
	_player.global_position.y = _main.kill_depth + 100.0
	await _step(3) # let main_scene respawn and a frame settle
	_press_key(KEY_J, false)
	Input.action_release("move_right")
	_check("respawn clears dash state", not _player._is_dashing)
	_check("respawn returns to spawn (mid-dash)", _player.global_position.distance_to(spawn) < 60.0)
