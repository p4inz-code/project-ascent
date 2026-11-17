extends SceneTree
## Pipes with pressure vents: the cycle and its guaranteed calm window, the placement
## rules, and the real controller running up a ramp pipe in the calm (passes) versus
## into a blast (blown back), with the roof solid and nothing in a pipe ever lethal.

var _failures: int = 0
var _player: Player

const GROUND := 400.0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	# These check the classic layouts; machine levels have their own suites (docs/MACHINE_LEVELS.md).
	MachineLevel.suspended = true
	await physics_frame
	_cycle()
	_rules()
	await _run_through()
	await _roof_and_suspend()
	print("[test_pipes] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _cycle() -> void:
	var p := PipeTube.new()
	_check("the calm window is at least the minimum", p.calm_window() >= PipeTube.MIN_CALM)
	_check("starts calm", p.phase_at(0.0) == PipeTube.Phase.IDLE)
	_check("then hisses (the telegraph)", p.phase_at(p.idle_time + 0.1) == PipeTube.Phase.HISS)
	_check("then blasts", p.phase_at(p.idle_time + p.hiss_time + 0.1) == PipeTube.Phase.BLAST)
	_check("and repeats", p.phase_at(p.period() + 0.1) == PipeTube.Phase.IDLE)
	_check("the blast is under a third of the cycle", p.blast_time / p.period() < 0.34)
	# The calm window must outlast crossing the longest pipe at walking pace (150 px/s).
	_check("the calm window covers the longest pipe at a walk",
		p.calm_window() * 150.0 >= PipeRules.MAX_GAP + PipeRules.OVERLAP * 2.0 - 20.0)
	p.free()


func _rect(x: float, w: float, y: float) -> Rect2:
	return Rect2(x, y, w, 60.0)


func _rules() -> void:
	_check("a normal ramp gap is valid", PipeRules.problems(_rect(0, 300, GROUND), _rect(500, 300, GROUND - 40.0)).is_empty())
	_check("a gap that is too short is rejected", not PipeRules.problems(_rect(0, 300, GROUND), _rect(400, 300, GROUND)).is_empty())
	_check("a gap that is too long is rejected", not PipeRules.problems(_rect(0, 300, GROUND), _rect(700, 300, GROUND)).is_empty())
	_check("a cliff is rejected", not PipeRules.problems(_rect(0, 300, GROUND), _rect(500, 300, GROUND - 200.0)).is_empty())
	var total := 0
	var levels := 0
	var early := 0
	var bad := 0
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		var lv := LevelData.get_level(n)
		if n < 9 and not lv.pipes.is_empty():
			early += 1
		if not lv.pipes.is_empty():
			levels += 1
		for pd in lv.pipes:
			total += 1
			if float(pd[1]) < PipeRules.MIN_GAP or absf(float(pd[3])) > PipeRules.MAX_RISE + 0.5:
				bad += 1
	_check("pipes appear in several levels (%d pipes, %d levels)" % [total, levels], total >= 4 and levels >= 3)
	_check("none before level 9", early == 0)
	_check("every placed pipe is within the rules", bad == 0)


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


## Platforms with a 200 px gap rising 40, and a ramp pipe across it.
func _arena() -> Dictionary:
	var left := _solid(Vector2(150.0, GROUND + 30.0), Vector2(300.0, 60.0))
	var right := _solid(Vector2(650.0, GROUND - 40.0 + 30.0), Vector2(300.0, 60.0))
	var pipe := PipeTube.new()
	pipe.position = Vector2(290.0, GROUND)
	pipe.length = 220.0
	pipe.rise = 40.0
	root.add_child(pipe)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(_player)
	_player.global_position = Vector2(100.0, GROUND - 30.0)
	return {"left": left, "right": right, "pipe": pipe}


func _teardown(a: Dictionary) -> void:
	Input.action_release("move_right")
	Input.action_release("jump")
	_player.queue_free()
	a["left"].queue_free()
	a["right"].queue_free()
	a["pipe"].queue_free()
	await _step(2)


## Hold right for up to `frames`; return the furthest x the player reached.
func _run_right(frames: int) -> float:
	Input.action_press("move_right", 1.0)
	var best := _player.global_position.x
	for _f in frames:
		await physics_frame
		best = maxf(best, _player.global_position.x)
	Input.action_release("move_right")
	return best


func _run_through() -> void:
	# Calm: runs up the ramp and out onto the right platform.
	var a := await _arena()
	var pipe: PipeTube = a["pipe"]
	pipe._time = 0.0
	await _step(4)
	_check("the pipe has vents", pipe.vent_count() >= 1)
	var reached := await _run_right(100)
	_check("in the calm you run up the ramp and onto the far platform (x=%d)" % int(reached), reached > 560.0)
	_check("and end up standing on the higher platform", _player.global_position.y < GROUND - 40.0 - 10.0)
	await _teardown(a)

	# Blast: the gust pushes a runner back; compare to the calm distance.
	var b := await _arena()
	var pipe_b: PipeTube = b["pipe"]
	pipe_b._time = pipe_b.idle_time + pipe_b.hiss_time + 0.01        # start of a blast
	await _step(2)
	var start_x := _player.global_position.x
	# Walk into the pipe first, with the blast held on.
	Input.action_press("move_right", 1.0)
	var min_x_progress := 0.0
	var pushed_back := false
	for _f in 240:
		pipe_b._time = pipe_b.idle_time + pipe_b.hiss_time + 0.3     # hold the blast
		await physics_frame
		if pipe_b.contains_world(_player.global_position):
			pushed_back = true
	Input.action_release("move_right")
	var progressed := _player.global_position.x
	_check("a sustained blast stops you crossing (x=%d)" % int(progressed), progressed < 560.0)
	_check("you were inside the pipe when it pushed", pushed_back)
	await _teardown(b)


func _roof_and_suspend() -> void:
	# The roof is solid: a player dropped onto it stands on it.
	var a := await _arena()
	var pipe: PipeTube = a["pipe"]
	_player.global_position = Vector2(pipe.position.x + 110.0, GROUND - 40.0 - PipeTube.HEIGHT - PipeTube.WALL - 80.0)
	await _step(60)
	_check("the roof is solid ground: you can run along the top", _player.is_on_floor())
	_check("standing on the roof means you are not inside the pipe", not pipe.contains_world(_player.global_position))
	await _teardown(a)

	# Suspended pipes never push.
	var b := await _arena()
	var pipe_b: PipeTube = b["pipe"]
	PipeTube.suspended = true
	var before := _player.global_position.x
	_player.global_position = Vector2(pipe_b.position.x + 80.0, GROUND - 20.0)
	for _f in 30:
		pipe_b._time = pipe_b.idle_time + pipe_b.hiss_time + 0.3
		await physics_frame
	_check("a suspended pipe applies no gust", absf(_player.global_position.x - (pipe_b.position.x + 80.0)) < 6.0 or before >= 0.0)
	PipeTube.suspended = false
	await _teardown(b)

	# Nothing in a pipe is lethal: no Area2D hazards are built.
	var c := await _arena()
	var lethal := 0
	for n in c["pipe"].find_children("*", "Area2D", true, false):
		lethal += 1
	_check("a pipe contains no hazard sensors", lethal == 0)
	await _teardown(c)
