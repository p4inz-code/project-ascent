extends SceneTree
## Evaluation (not a gate test): does the controller feel the same at 120 Hz physics as at 60?
## Measures the quantities a player feels, at the rate given as the first argument.
##   Godot --headless --path . --script res://tests/probe_physics_rate.gd -- 60
##   Godot --headless --path . --script res://tests/probe_physics_rate.gd -- 120

var _p: Player
var _hz: int = 60


func _initialize() -> void:
	_go()


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


func _frames(seconds: float) -> int:
	return int(round(seconds * _hz))


func _go() -> void:
	var a := OS.get_cmdline_user_args()
	_hz = int(a[0]) if a.size() > 0 else 60
	Engine.physics_ticks_per_second = _hz
	await physics_frame
	var ground := _floor(Vector2(0, 400), Vector2(8000, 40))
	_p = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	_p.global_position = Vector2(0, 340)
	for _i in _frames(0.3):
		await physics_frame
	var out := {}
	# Full jump apex.
	var y0 := _p.global_position.y
	var apex := y0
	Input.action_press("jump", 1.0)
	for _i in _frames(1.2):
		await physics_frame
		apex = minf(apex, _p.global_position.y)
	Input.action_release("jump")
	out["jump_apex_px"] = y0 - apex
	for _i in _frames(0.6):
		await physics_frame
	# Tap jump apex.
	y0 = _p.global_position.y
	apex = y0
	Input.action_press("jump", 1.0)
	for _i in _frames(0.05):
		await physics_frame
	Input.action_release("jump")
	for _i in _frames(1.0):
		await physics_frame
		apex = minf(apex, _p.global_position.y)
	out["tap_apex_px"] = y0 - apex
	for _i in _frames(0.6):
		await physics_frame
	# Time to top speed, and top speed.
	_p.global_position.x = 0
	_p.velocity = Vector2.ZERO
	Input.action_press("move_right", 1.0)
	var t_top := -1.0
	for f in _frames(1.5):
		await physics_frame
		if t_top < 0.0 and absf(_p.velocity.x) >= _p.max_speed * 0.99:
			t_top = float(f + 1) / float(_hz)
	out["time_to_top_speed_s"] = t_top
	out["top_speed"] = _p.velocity.x
	# Running jump reach (flat).
	var x0 := _p.global_position.x
	Input.action_press("jump", 1.0)
	var landed := false
	var airborne := false
	for _i in _frames(2.0):
		await physics_frame
		if not _p.is_on_floor():
			airborne = true
		if airborne and _p.is_on_floor():
			landed = true
			break
	Input.action_release("jump")
	out["running_jump_reach_px"] = _p.global_position.x - x0
	Input.action_release("move_right")
	for _i in _frames(0.8):
		await physics_frame
	# Dash distance.
	_p.velocity = Vector2.ZERO
	await physics_frame
	var dx0 := _p.global_position.x
	Input.action_press("move_right", 1.0)
	Input.action_press("dash", 1.0)
	for _i in 2:
		await physics_frame
	Input.action_release("dash")
	for _i in _frames(0.4):
		await physics_frame
	out["dash_then_run_0.4s_px"] = _p.global_position.x - dx0
	Input.action_release("move_right")
	print("RATE %d Hz: %s" % [_hz, JSON.stringify(out)])
	quit()
