extends "res://tests/test_base.gd"
## Headless gameplay-loop tests: the systems that tie a play session together
## and tend to fail silently — goal completion, manual restart, repeated
## respawn stability, and the "one dash per grounding" refresh rule.
## Run: Godot --headless --path <project> --script res://tests/test_loop.gd
## Exit code 0 = all checks passed, 1 = a check failed.


func _suite_name() -> String:
	return "test_loop"


func _run() -> void:
	var spawn := _player.global_position
	await _step(20) # settle

	# --- Goal completion: entering the Goal area emits level_completed and loops
	# the player back to spawn (the greybox win condition). ---
	var goal_box := [0]
	var _goal_cb := func() -> void: goal_box[0] += 1
	_main.level_completed.connect(_goal_cb)
	var goal: Node2D = _main.get_node("Goal")
	_player.velocity = Vector2.ZERO
	_player.global_position = goal.global_position # drop the player into the goal
	await _step(4)
	_main.level_completed.disconnect(_goal_cb)
	_check("goal emits level_completed on entry", goal_box[0] >= 1)
	_check("goal loops player back to spawn", _player.global_position.distance_to(spawn) < 60.0)

	# --- Manual restart: the restart action (R) returns the player to spawn from
	# anywhere, sharing the respawn path. ---
	await _step(10)
	_player.global_position = Vector2(1200.0, 300.0)
	_player.velocity = Vector2(200.0, -150.0)
	await physics_frame
	_press_key(KEY_R, true)
	await _step(3)
	_press_key(KEY_R, false)
	_check("restart action returns player to spawn", _player.global_position.distance_to(spawn) < 60.0)

	# --- Repeated respawn stability: falling into the kill plane many times must
	# always land back at the same spawn with cleared momentum (no drift/accrual). ---
	var stable := true
	for _i in 5:
		_player.global_position.y = _main.kill_depth + 200.0
		_player.velocity = Vector2(300.0, 400.0)
		await _step(2)
		if _player.global_position.distance_to(spawn) > 60.0:
			stable = false
	_check("repeated fall-respawn stays anchored to spawn", stable)
	_check("repeated respawn leaves state clean (not dashing)", not _player._is_dashing)

	# --- Dash refresh rule: one dash per grounding. A second dash while still
	# airborne must be refused; landing refreshes it. ---
	await _step(20)
	_check("dash available on the ground", _player._dash_available)
	# Jump into the air.
	_press_key(KEY_SPACE, true)
	await _step(6)
	_press_key(KEY_SPACE, false)
	_check("airborne for dash-refresh check", not _player.is_on_floor())
	# First airborne dash: should consume the dash.
	_press_key(KEY_J, true)
	await _step(3)
	_press_key(KEY_J, false)
	_check("airborne dash consumes availability", not _player._dash_available)
	# Second airborne dash attempt: must be refused (no double dash mid-air).
	await _step(3)
	var dashing_before: bool = _player._is_dashing
	_press_key(KEY_J, true)
	await _step(3)
	_press_key(KEY_J, false)
	_check("second airborne dash refused", not (_player._is_dashing and not dashing_before))
	# Land and confirm the dash is refreshed.
	await _step(60)
	_check("grounded again after dash test", _player.is_on_floor())
	_check("dash refreshed on landing", _player._dash_available)
