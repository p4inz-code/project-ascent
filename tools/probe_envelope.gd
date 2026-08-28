extends SceneTree
## Movement-envelope probe (tuning aid, not a pass/fail test).
## Measures the player's real reachability on flat ground so level geometry can
## be checked against it instead of guessed:
##   * flat jump  — horizontal distance of a running jump, same takeoff/landing height
##   * dash-jump  — same, with a mid-air dash for maximum carry
##   * jump peak  — max rise of a standing jump (sanity vs jump_height)
## Run: Godot --headless --path <proj> --script res://tools/probe_envelope.gd

var _main: Node
var _player: CharacterBody2D


func _tap(physical: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = physical
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _step(frames: int) -> void:
	for _i in frames:
		await physics_frame


func _reground() -> void:
	_player.global_position = Vector2(350.0, 680.0)
	_player.velocity = Vector2.ZERO
	Input.action_release("move_right")
	Input.action_release("move_left")
	_tap(KEY_SPACE, false)
	_tap(KEY_J, false)
	await _step(20)


func _initialize() -> void:
	_run()


func _run() -> void:
	_main = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await physics_frame
	_player = _main.get_node("Player")

	var flat := await _measure_jump(false)
	await _reground()
	var dash := await _measure_jump(true)

	print("[probe] flat running jump: horizontal=%.0f px, peak_rise=%.0f px" % [flat.x, flat.y])
	print("[probe] dash running jump: horizontal=%.0f px, peak_rise=%.0f px" % [dash.x, dash.y])
	quit(0)


## Run right to top speed, jump off, optionally dash mid-air, and measure the
## horizontal distance covered between leaving the floor and landing again
## (same height on flat ground) plus the peak rise. Jump is HELD for the whole
## flight so variable-height damping never trims it (we want the max envelope).
func _measure_jump(use_dash: bool) -> Vector2:
	Input.action_press("move_right", 1.0)
	await _step(45) # reach max_speed
	var takeoff_x := 0.0
	var takeoff_y := 0.0
	var peak_rise := 0.0
	var dashed := false
	_tap(KEY_SPACE, true) # held until after landing
	# Detect leaving the floor.
	for _i in 8:
		await physics_frame
		if not _player.is_on_floor():
			takeoff_x = _player.global_position.x
			takeoff_y = _player.global_position.y
			break
	# Fly until landing, tracking peak rise and firing one dash right at the apex
	# (vy crossing zero) for maximum horizontal carry.
	for _i in 120:
		await physics_frame
		peak_rise = maxf(peak_rise, takeoff_y - _player.global_position.y)
		if use_dash and not dashed and _player.velocity.y > -30.0:
			_tap(KEY_J, true)
			dashed = true
			await physics_frame
			_tap(KEY_J, false)
		if _player.is_on_floor():
			break
	var landing_x := _player.global_position.x
	_tap(KEY_SPACE, false)
	Input.action_release("move_right")
	return Vector2(absf(landing_x - takeoff_x), peak_rise)
