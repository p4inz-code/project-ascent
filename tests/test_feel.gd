extends "res://tests/test_base.gd"
## Headless regression tests for the game-feel affordances that are easy to
## break silently: coyote time, jump buffering, and variable jump height.
## Drives the real physics engine on the real main scene.
##   Godot --headless --path <project> --script res://tests/test_feel.gd
## Exit code 0 = all checks passed, 1 = a check failed.

var _ground_top: float = 0.0


func _suite_name() -> String:
	return "test_feel"


func _reground() -> void:
	# Return to the flat spawn area over solid ground and let the player settle.
	_player.global_position = Vector2(350.0, 680.0)
	_player.velocity = Vector2.ZERO
	await _step(20)


func _run() -> void:
	var ground := _main.get_node("Terrain/Ground")
	_ground_top = ground.global_position.y - (ground.size.y * 0.5)

	await _feel_coyote_positive()
	await _feel_coyote_expiry()
	await _feel_jump_buffer()
	await _feel_variable_height()


## A jump pressed within the coyote window just after leaving a ledge fires.
func _feel_coyote_positive() -> void:
	await _stand_on_p4()
	await _walk_off_right()
	# We are 0-1 frames into the coyote window (~6 frames) here. Hold jump and
	# scan a few frames so the check isn't sensitive to the exact frame the
	# synthetic press registers on.
	_press_key(KEY_SPACE, true)
	var peak_vy := 0.0
	for _i in 5:
		await physics_frame
		peak_vy = minf(peak_vy, _player.velocity.y)
	_press_key(KEY_SPACE, false)
	_check("coyote: jump fires just after leaving a ledge", peak_vy < -100.0)


## After the coyote window expires, a late jump press must NOT fire.
func _feel_coyote_expiry() -> void:
	await _stand_on_p4()
	await _walk_off_right()
	# coyote_time is 0.1s (~6 frames); wait well past it while still airborne.
	await _step(14)
	var vy_before := _player.velocity.y
	_press_key(KEY_SPACE, true)
	await physics_frame
	_press_key(KEY_SPACE, false)
	_check("coyote: expired press does not jump", _player.velocity.y >= vy_before - 5.0)


## Drop the player onto P4 (a floating ledge with open air to its right) and
## let it settle so the coyote timer is freshly charged.
func _stand_on_p4() -> void:
	_player.global_position = Vector2(1500.0, 470.0)
	_player.velocity = Vector2.ZERO
	Input.action_release("move_right")
	Input.action_release("move_left")
	_press_key(KEY_SPACE, false)
	await _step(18)


## Hold right until the player walks off the ledge into open air, then release.
func _walk_off_right() -> void:
	Input.action_press("move_right", 1.0)
	for _i in 40:
		await physics_frame
		if not _player.is_on_floor():
			break
	Input.action_release("move_right")


## A jump pressed a few frames before touchdown is buffered and fires on landing.
func _feel_jump_buffer() -> void:
	_player.global_position = Vector2(350.0, 560.0)
	_player.velocity = Vector2.ZERO
	await physics_frame
	var buffered := false
	var jumped := false
	for _i in 60:
		await physics_frame
		var feet := _player.global_position.y + 26.0
		if not buffered and not _player.is_on_floor() and _player.velocity.y > 0.0 \
				and (_ground_top - feet) < 12.0:
			# About to land: tap jump now, release next frame (a real buffered tap).
			_press_key(KEY_SPACE, true)
			buffered = true
			await physics_frame
			_press_key(KEY_SPACE, false)
		if buffered and _player.velocity.y < -100.0:
			jumped = true
			break
	_check("jump buffer: pre-landing press fires on touchdown", jumped)


## Holding jump climbs meaningfully higher than tapping it (variable height).
func _feel_variable_height() -> void:
	await _reground()
	var tap_rise := await _measure_rise(1)
	await _reground()
	var hold_rise := await _measure_rise(40)
	_check("variable height: full hold rises higher than a tap",
		hold_rise > tap_rise + 40.0)


## Jump, release after `hold_frames`, and return peak rise above the launch point.
func _measure_rise(hold_frames: int) -> float:
	var start_y := _player.global_position.y
	var min_y := start_y
	_press_key(KEY_SPACE, true)
	for i in 45:
		await physics_frame
		if i == hold_frames:
			_press_key(KEY_SPACE, false)
		min_y = minf(min_y, _player.global_position.y)
	_press_key(KEY_SPACE, false)
	return start_y - min_y
