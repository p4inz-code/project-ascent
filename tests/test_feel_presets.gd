extends SceneTree
## Control feel ("sensitivity"): the three presets must differ in the ways their
## names promise, apply live to a real Player, and the two forgiveness mechanics
## (ceiling corner correction, wall-jump grace) must actually change outcomes.
## Measured on the real controller, in physics frames, not asserted on constants.

var _failures: int = 0
var _player: Player


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await _run()
	print("[test_feel_presets] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _solid(pos: Vector2, size: Vector2) -> StaticBody2D:
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


func _release_all() -> void:
	for a in ["move_left", "move_right", "jump", "dash", "slide"]:
		Input.action_release(a)


## Frames from lifting the key (at full speed) until the player is nearly still.
func _frames_to_stop(preset: int) -> int:
	var ground := _solid(Vector2(0, 400), Vector2(4000, 40))
	_player = _spawn(Vector2(-900, 340))
	Feel.apply(_player, preset)
	await _step(6)
	Input.action_press("move_right", 1.0)
	await _step(50)
	Input.action_release("move_right")
	var frames := 0
	while absf(_player.velocity.x) > 12.0 and frames < 120:
		await physics_frame
		frames += 1
	_player.queue_free()
	ground.queue_free()
	await _step(2)
	return frames


func _frames_to_90pct(preset: int) -> int:
	var ground := _solid(Vector2(0, 400), Vector2(4000, 40))
	_player = _spawn(Vector2(-900, 340))
	Feel.apply(_player, preset)
	await _step(6)
	Input.action_press("move_right", 1.0)
	var frames := 0
	while absf(_player.velocity.x) < _player.max_speed * 0.9 and frames < 120:
		await physics_frame
		frames += 1
	Input.action_release("move_right")
	_player.queue_free()
	ground.queue_free()
	await _step(2)
	return frames


## Jump from under the slab's corner and return the highest point the head
## reached (smaller y = higher).
func _jump_apex_head_top(correction: float) -> float:
	_player = _spawn(Vector2(-8, 340))
	_player.corner_correction = correction
	await _step(8)
	# Hold jump through the whole rise: releasing early would trim the jump
	# (variable height) and it would never reach the ceiling at all.
	Input.action_press("jump", 1.0)
	var top := INF
	for _i in 40:
		await physics_frame
		top = minf(top, _player.global_position.y - 26.0)
	Input.action_release("jump")
	_player.queue_free()
	_release_all()
	await _step(2)
	return top


func _run() -> void:
	await physics_frame

	# 1. The presets are real, ordered data.
	var stop_precise: int = await _frames_to_stop(Feel.Preset.PRECISE)
	var stop_snappy: int = await _frames_to_stop(Feel.Preset.SNAPPY)
	var stop_instant: int = await _frames_to_stop(Feel.Preset.INSTANT)
	_check("PRECISE stops slower than SNAPPY (%d > %d frames)" % [stop_precise, stop_snappy],
		stop_precise > stop_snappy)
	_check("SNAPPY stops slower than INSTANT (%d > %d frames)" % [stop_snappy, stop_instant],
		stop_snappy > stop_instant)
	_check("INSTANT stops within 4 frames (got %d)" % stop_instant, stop_instant <= 4)

	var up_precise: int = await _frames_to_90pct(Feel.Preset.PRECISE)
	var up_instant: int = await _frames_to_90pct(Feel.Preset.INSTANT)
	_check("INSTANT reaches speed faster than PRECISE (%d < %d frames)" % [up_instant, up_precise],
		up_instant < up_precise)

	_check("forgiveness windows widen from PRECISE to INSTANT",
		Feel.values_for(0)["coyote_time"] < Feel.values_for(2)["coyote_time"]
		and Feel.values_for(0)["jump_buffer_time"] < Feel.values_for(2)["jump_buffer_time"])
	_check("an out-of-range preset clamps instead of crashing",
		Feel.clamp_preset(99) == 2 and Feel.clamp_preset(-5) == 0)

	# 2. A preset applies to a live Player.
	var p := _spawn(Vector2(0, -2000))
	Feel.apply(p, Feel.Preset.INSTANT)
	_check("applying INSTANT writes the player's accel time",
		is_equal_approx(p.ground_accel_time, Feel.values_for(2)["ground_accel_time"]))
	p.queue_free()
	await _step(2)

	# 3. Corner correction: a jump that only clips a ceiling corner slips past it.
	var floor_ := _solid(Vector2(0, 400), Vector2(2000, 40))
	# A ceiling slab: bottom face at y=250, left edge at x=0.
	var ceiling := _solid(Vector2(300, 230), Vector2(600, 40))
	# The player (28 wide) at x=-8 overlaps the slab's left edge by 6 px, so a
	# straight jump clips its corner. Higher apex = a smaller y, so the head top
	# (y-26) going above 250 means it got past the slab's bottom face.
	var apex_with := await _jump_apex_head_top(12.0)
	_check("a corner-clipping jump slips past the ceiling (head reached y=%.0f)" % apex_with,
		apex_with < 250.0 - 4.0)
	# Negative control: with the correction off, the SAME jump bonks.
	var apex_without := await _jump_apex_head_top(0.0)
	_check("without correction the same jump bonks (head only reached y=%.0f)" % apex_without,
		apex_without > 250.0 - 4.0)
	_release_all()
	floor_.queue_free()
	ceiling.queue_free()
	await _step(2)

	# 4. Wall-jump grace: a jump pressed just after leaving the wall still works.
	var ground2 := _solid(Vector2(0, 1200), Vector2(2000, 40))
	var wall := _solid(Vector2(100, 600), Vector2(40, 1200))
	_player = _spawn(Vector2(60, 300))
	await _step(30)
	# Slide down the wall pressing into it, then let go and step away.
	Input.action_press("move_right", 1.0)
	await _step(25)
	var on_wall := _player.is_on_wall_only()
	_check("player is on the wall before the grace test", on_wall)
	Input.action_release("move_right")
	_player.velocity.x = -120.0
	await _step(3)  # now off the wall, inside the grace window
	var vy_before := _player.velocity.y
	Input.action_press("jump", 1.0)
	await _step(2)
	Input.action_release("jump")
	_check("a wall-jump pressed just after leaving the wall still fires (vy %.0f -> %.0f)"
		% [vy_before, _player.velocity.y], _player.velocity.y < vy_before - 200.0)
	_player.queue_free()
	_release_all()
	ground2.queue_free()
	wall.queue_free()
	await _step(2)
