extends SceneTree
## Plain-road levels. (1) The layout rules and the randomness: different every roll, never
## stacked, never unfair in shape. (2) Every obstacle type is passable: a bot that waits
## for the safe window (or jumps, or just runs) gets through each type on the real
## controller, many seeds each, and nothing in the road is a wall.

var _failures: int = 0
var _scene: MainScene
var _course: RoadCourse
var _player: Player

const SEEDS := [3, 17, 29, 41]
const CELL := 4          # the cell the bot is tested against


func _initialize() -> void:
	_boot()


func _boot() -> void:
	# These check the classic layouts; machine levels have their own suites (docs/MACHINE_LEVELS.md).
	MachineLevel.suspended = true
	await physics_frame
	_layouts()
	_levels()
	await _all_types()
	await _rerolls_on_death()
	print("[test_road_course] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


# ── 1. layouts ──────────────────────────────────────────────────────

func _layouts() -> void:
	var def := LevelData.get_level(13)
	var road := def.road
	_check("level 13 is a plain-road level", road != null and road.cells.size() >= 12)
	var distinct := {}
	var rules_ok := true
	var start_end_ok := true
	var variety := {}
	for sd in 120:
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		var layout := RoadCourse.choose_layout(road, rng)
		distinct[str(layout)] = true
		start_end_ok = start_end_ok and layout[0] == RoadCourse.Cell.PLAIN and layout[layout.size() - 1] == RoadCourse.Cell.PLAIN
		var hard_run := 0
		var busy_run := 0
		for i in layout.size():
			variety[layout[i]] = true
			if layout[i] in RoadCourse.HARD:
				hard_run += 1
			else:
				hard_run = 0
			busy_run = busy_run + 1 if layout[i] != RoadCourse.Cell.PLAIN else 0
			if hard_run > RoadCourse.MAX_HARD_RUN or busy_run > RoadCourse.MAX_BUSY_RUN:
				rules_ok = false
			if i > 0 and layout[i] == layout[i - 1] and layout[i] != RoadCourse.Cell.PLAIN:
				rules_ok = false
	_check("120 rolls give %d different layouts" % distinct.size(), distinct.size() >= 115)
	_check("every roll opens and closes on plain road", start_end_ok)
	_check("no more than two hard cells in a row, three busy in a row, no repeats", rules_ok)
	_check("a hard-tier road uses many obstacle types (%d)" % variety.size(), variety.size() >= 10)
	var easy := LevelData.get_level(3).road
	var easy_types := {}
	for sd in 60:
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = sd
		for t in RoadCourse.choose_layout(easy, rng2):
			easy_types[t] = true
	_check("the easy road never rolls the nastiest types",
		not easy_types.has(RoadCourse.Cell.CRUSHER) and not easy_types.has(RoadCourse.Cell.PENDULUM)
		and not easy_types.has(RoadCourse.Cell.LASER))
	# Same cell, different attempts: the type at a given cell changes.
	var at_cell := {}
	for sd in 80:
		var rng3 := RandomNumberGenerator.new()
		rng3.seed = sd * 7 + 1
		at_cell[RoadCourse.choose_layout(road, rng3)[6]] = true
	_check("the same cell holds different obstacles on different attempts (%d types)" % at_cell.size(), at_cell.size() >= 6)


func _levels() -> void:
	var roads := CourseGen.ROADS.keys()
	_check("seven plain-road levels exist", roads.size() == 7)
	var ok := true
	for n in roads:
		var d := LevelData.get_level(int(n))
		var max_step := 0.0
		var last_y := -INF
		for c in d.road.cells:
			if last_y != -INF:
				max_step = maxf(max_step, absf(float(c["y"]) - last_y))
			last_y = float(c["y"])
		# No wall: a step between cells never exceeds a comfortable jump.
		if max_step > 60.0 or d.road.cells.size() < 12:
			ok = false
	_check("every road is flat apart from steps of at most 60 px (no walls)", ok)
	_check("level 5 is the auto-run boss road", LevelData.get_level(5).auto_run and LevelData.get_level(5).boss_config.enabled)
	_check("level 15 is a boss road without auto-run", LevelData.get_level(15).boss_config.enabled and not LevelData.get_level(15).auto_run)
	_check("boss roads set where the rising floor ends", LevelData.get_level(5).rise_end_y != INF)


# ── 2. every obstacle type is passable ──────────────────────────────

func _load_road() -> void:
	_scene = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate() as MainScene
	_scene.set("level_number", 13)
	root.add_child(_scene)
	await _step(8)
	_course = _scene.get_node("Hazards/RoadCourse")
	_player = _scene.get_node("Player")


func _place_player() -> void:
	var y := _course.cell_y(CELL)
	_player.global_position = Vector2(_course.cell_left(CELL) - 150.0, y - 28.0)
	_player.velocity = Vector2.ZERO


func _release() -> void:
	for a in ["move_right", "jump"]:
		Input.action_release(a)


## Predicted bob position of a pendulum at time `dt` from now.
func _bob_at(pend: Pendulum, dt: float) -> Vector2:
	var t: float = pend._time + dt
	var ang := deg_to_rad(pend.max_angle_deg) * sin(pend.swing_speed * t + pend.phase_offset)
	return pend.global_position + Vector2(sin(ang), cos(ang)) * pend.arm_length


func _pendulum_safe_to_go(pend: Pendulum) -> bool:
	var floor_y := _course.cell_y(CELL)
	var px := _player.global_position.x
	var dt := 0.0
	while dt <= 1.7:
		var bob := _bob_at(pend, dt)
		var player_centre := Vector2(px + 320.0 * dt, floor_y - 26.0)
		if bob.distance_to(player_centre) < pend.bob_radius + 34.0:
			return false
		dt += 0.04
	return true


## Run the policy for the given type; true if the bot clears the cell alive.
func _drive(type: int) -> bool:
	var attempts_before := int(_scene.get("attempts"))
	var goal_x := _course.cell_left(CELL + 1) + 60.0
	var hold := 0
	var started := false
	var jump_at := {}
	var gate: TimedGate = null
	var pend: Pendulum = null
	var pipe: PipeTube = null
	var shooter: ShooterTrap = null
	var slots: Array[TrapSlot] = []
	for n in _course.hazards.get_children():
		if n is TimedGate:
			gate = n
		elif n is Pendulum:
			pend = n
		elif n is PipeTube:
			pipe = n
		elif n is ShooterTrap:
			shooter = n
		elif n is TrapGroup:
			for s in n.slots:
				slots.append(s)
	var wait_x := _course.cell_left(CELL) - 90.0
	var trace: Array = []
	for _f in 1200:
		# Hold jump through the rise (releasing early trims it to a hop).
		if hold > 0:
			hold -= 1
			if hold == 0:
				Input.action_release("jump")
		var x := _player.global_position.x
		# Approach at a run; at the wait line, hold still until the obstacle's safe window
		# is long enough to cross, then go and keep going.
		var at_line := x >= wait_x - 20.0
		var safe := true
		match type:
			RoadCourse.Cell.LASER, RoadCourse.Cell.CRUSHER:
				safe = gate != null and gate.seconds_until_active() >= 1.7
			RoadCourse.Cell.PENDULUM:
				safe = pend != null and _pendulum_safe_to_go(pend)
			RoadCourse.Cell.PIPE:
				safe = pipe != null and pipe.calm_remaining() >= 1.9
		var timed := type in [RoadCourse.Cell.LASER, RoadCourse.Cell.CRUSHER, RoadCourse.Cell.PENDULUM, RoadCourse.Cell.PIPE]
		if timed and at_line and not started and not safe:
			Input.action_release("move_right")
		else:
			if timed and at_line:
				started = true
			Input.action_press("move_right", 1.0)
		# Jumps for spikes, pits and darts.
		if _player.is_on_floor() and hold == 0:
			var do_jump := false
			if type == RoadCourse.Cell.SPIKES:
				for s in slots:
					var sx := s.global_position.x
					if x >= sx - 22.0 - 60.0 and x < sx - 22.0 - 20.0 and not jump_at.has(sx):
						jump_at[sx] = true
						do_jump = true
			elif type == RoadCourse.Cell.PIT:
				var edge: float = _course.cell_left(CELL) + float(_course.road.piece_widths[0])
				if x >= edge - 18.0 and x < edge + 8.0 and not jump_at.has("pit"):
					jump_at["pit"] = true
					do_jump = true
			elif type == RoadCourse.Cell.SHOOTER and shooter != null:
				for shot in shooter._shots:
					if is_instance_valid(shot):
						var dx: float = x - (shooter.position + shot.position).x
						if dx > -190.0 and dx < -80.0:
							do_jump = true
			if do_jump:
				Input.action_press("jump", 1.0)
				hold = 26
		if shooter != null:
			var nearest := 9999.0
			for shot in shooter._shots:
				if is_instance_valid(shot):
					var d: float = (shooter.position + shot.position).x - x
					if absf(d) < absf(nearest):
						nearest = d
			trace.append("%d|%s|%d|%s" % [int(x), "F" if _player.is_on_floor() else "A", int(nearest), "J" if hold > 0 else "-"])
			if trace.size() > 30:
				trace.pop_front()
		await physics_frame
		if int(_scene.get("attempts")) > attempts_before:
			if shooter != null and OS.get_cmdline_user_args().has("debug"):
				var info := []
				for shot in shooter._shots:
					if is_instance_valid(shot):
						info.append(int((shooter.position + shot.position).x))
				print("   died; trace(x|floor|dart_dx|jumping): ", " ".join(trace))
			_release()
			return false
		if _player.global_position.x >= goal_x and _player.is_on_floor():
			_release()
			return true
	_release()
	return false


func _all_types() -> void:
	await _load_road()
	var types := [
		[RoadCourse.Cell.SPIKES, "spikes"], [RoadCourse.Cell.LASER, "laser gate"],
		[RoadCourse.Cell.CRUSHER, "crusher"], [RoadCourse.Cell.PENDULUM, "pendulum"],
		[RoadCourse.Cell.SHOOTER, "dart turret"], [RoadCourse.Cell.PIT, "pool pit"],
		[RoadCourse.Cell.CRUMBLE, "crumble bridge"], [RoadCourse.Cell.ICE, "ice"],
		[RoadCourse.Cell.STICKY, "sticky"], [RoadCourse.Cell.CONVEYOR, "conveyor"],
		[RoadCourse.Cell.PIPE, "vent pipe"], [RoadCourse.Cell.WIND, "wind"],
	]
	for t in types:
		var passed := 0
		for sd in SEEDS:
			_course.force({CELL: t[0]}, sd)
			await _step(4)
			_place_player()
			await _step(3)
			var ok := await _drive(t[0])
			if ok:
				passed += 1
			else:
				print("   %s failed with seed %d" % [t[1], sd])
			_release()
		_check("%s: the bot clears it with every seed (%d of %d)" % [t[1], passed, SEEDS.size()], passed == SEEDS.size())

	# Negative controls: the hazards are real. Running blindly through a lethal type dies
	# at least sometimes; the safe ones never kill.
	var deaths := 0
	for sd in SEEDS:
		_course.force({CELL: RoadCourse.Cell.SPIKES}, sd)
		await _step(4)
		_place_player()
		await _step(3)
		# Walk straight through without jumping.
		var attempts := int(_scene.get("attempts"))
		Input.action_press("move_right", 1.0)
		for _f in 400:
			await physics_frame
			if int(_scene.get("attempts")) > attempts:
				deaths += 1
				break
		_release()
	# A turret never spawns a dart on top of the player (a spawn kill is not a dodge).
	_course.force({CELL: RoadCourse.Cell.SHOOTER}, 17)
	await _step(4)
	var turret: ShooterTrap = null
	for n in _course.hazards.get_children():
		if n is ShooterTrap:
			turret = n
	var attempts0 := int(_scene.get("attempts"))
	_player.global_position = Vector2(turret.global_position.x - 40.0, _course.cell_y(CELL) - 28.0)
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	await _step(60 * 7)
	_check("standing next to a turret for seven seconds never gets you shot", int(_scene.get("attempts")) == attempts0)
	_check("and the turret holds its fire while you are that close", turret.live_shot_count() == 0)
	_player.set_physics_process(true)

	_check("negative control: walking blindly through spikes kills (%d of %d)" % [deaths, SEEDS.size()], deaths >= 1)
	_scene.queue_free()
	await _step(2)


# ── 3. a death re-rolls the road ────────────────────────────────────

func _rerolls_on_death() -> void:
	await _load_road()
	var first: Array[int] = _course.layout.duplicate()
	var rolls_before := _course.rolls()
	_scene.call("_respawn", MainScene.RespawnCause.MANUAL)
	await _step(4)
	_check("an attempt re-rolls the obstacles", _course.rolls() > rolls_before)
	var changed := 0
	var last: Array[int] = first
	for i in 8:
		_scene.call("_respawn", MainScene.RespawnCause.MANUAL)
		await _step(2)
		if str(_course.layout) != str(last):
			changed += 1
		last = _course.layout.duplicate()
	_check("and the layout differs from attempt to attempt (%d of 8 changed)" % changed, changed >= 6)
	_scene.queue_free()
	await _step(2)
