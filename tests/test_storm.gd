extends SceneTree
## The storm level's lightning: always announced, always room to step aside, one bolt at a time,
## never right after a respawn, and slowed by the hazard-speed assist. A bot on the real
## controller that reacts to the warning is never struck; one that ignores it is.

var _failures: int = 0
var _player: Player


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_rules()
	await _level_wiring()
	await _bot()
	print("[test_storm] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _director(rects: Array[Rect2], player: Node2D, seed_v: int) -> StormDirector:
	var d := StormDirector.new()
	root.add_child(d)
	d.setup(rects, player, seed_v)
	d.set_physics_process(false)         # the test drives it with exact time steps
	return d


# ── the rules, on the state machine itself ──────────────────────────

func _rules() -> void:
	_check("every bolt is announced for at least a full second", StormDirector.TELEGRAPH >= 1.0)
	_check("the bolt itself is brief", StormDirector.STRIKE_TIME <= 0.3)
	var stand := Node2D.new()
	root.add_child(stand)
	stand.global_position = Vector2(500, 380)
	var rects: Array[Rect2] = [Rect2(100, 400, 800, 60), Rect2(1000, 400, 800, 60), Rect2(1900, 400, 90, 60)]
	var d := _director(rects, stand, 5)
	# A long quiet before the first bolt.
	d.step(StormDirector.FIRST_STRIKE_DELAY - 0.2)
	_check("nothing happens during the opening quiet", d.phase == StormDirector.Phase.QUIET and d.strikes_fired == 0)
	# Walk the whole machine for a long time, checking every transition.
	var warned_before_strike := true
	var warning_len := 0.0
	var max_warning := 0.0
	var last_phase: int = d.phase
	var bolts_overlap := false
	var xs: Array = []
	var too_narrow := false
	var t := 0.0
	for _i in 60000:
		d.step(0.01)
		t += 0.01
		if d.phase == StormDirector.Phase.WARNING:
			warning_len += 0.01
			if last_phase != StormDirector.Phase.WARNING:
				xs.append(d.column_x)
				var on_wide := false
				for r in rects:
					if d.column_x >= r.position.x + 55.0 - 0.01 and d.column_x <= r.end.x - 55.0 + 0.01 and r.size.x >= StormDirector.MIN_PLATFORM_WIDTH:
						on_wide = true
				too_narrow = too_narrow or not on_wide
		if d.phase == StormDirector.Phase.STRIKE and last_phase != StormDirector.Phase.WARNING and last_phase != StormDirector.Phase.STRIKE:
			warned_before_strike = false
		if d.phase == StormDirector.Phase.STRIKE and last_phase == StormDirector.Phase.WARNING:
			max_warning = maxf(max_warning, warning_len)
			if warning_len < StormDirector.TELEGRAPH - 0.02:
				warned_before_strike = false
			warning_len = 0.0
		last_phase = d.phase
	_check("a bolt only ever follows a full warning (%d bolts)" % d.strikes_fired, warned_before_strike and d.strikes_fired > 20)
	_check("columns are only chosen on platforms wide enough to step aside", not too_narrow)
	var spaced := true
	for i in range(1, xs.size()):
		spaced = spaced and absf(float(xs[i]) - float(xs[i - 1])) >= StormDirector.MIN_SPACING - 0.01
	_check("consecutive columns are far apart", spaced)
	# The narrow platform (90 wide) is never struck.
	var struck_narrow := false
	for x in xs:
		if float(x) > 1900.0:
			struck_narrow = true
	_check("a 90 px platform is never a target", not struck_narrow)
	# Lethality: only inside the strike, only inside the beam.
	var d2 := _director(rects, stand, 9)
	d2.step(StormDirector.FIRST_STRIKE_DELAY + 0.01)
	_check("a warning is not lethal", d2.phase == StormDirector.Phase.WARNING and not d2.hits(d2.column_x, d2.column_y - 20.0))
	d2.step(StormDirector.TELEGRAPH + 0.01)
	_check("the strike is lethal at its column", d2.is_lethal() and d2.hits(d2.column_x, d2.column_y - 20.0))
	_check("and not 100 px to the side", not d2.hits(d2.column_x + 100.0, d2.column_y - 20.0))
	_check("and not on the far side of the surface", not d2.hits(d2.column_x, d2.column_y + 300.0))
	# Respawn grace.
	d2.reset()
	d2.step(StormDirector.FIRST_STRIKE_DELAY - 0.3)
	_check("a respawn starts a long quiet again", d2.phase == StormDirector.Phase.QUIET)
	# No platform in range -> the storm waits rather than striking nothing.
	var far := Node2D.new()
	root.add_child(far)
	far.global_position = Vector2(50000, 0)
	var d3 := _director(rects, far, 1)
	d3.step(20.0)
	_check("with nowhere to strike the storm waits", d3.strikes_fired == 0)
	# The slow-hazards assist slows the storm clock.
	HazardSpeed.set_index(2)
	var d4 := _director(rects, stand, 3)
	d4.set_physics_process(true)
	var gs: Node = root.get_node("GameSettings")
	gs.set_reg("assist_hazard_speed", 2)
	var before: float = d4._timer
	await _step(30)
	var burned: float = before - d4._timer
	_check("hazard speed SLOWEST slows the storm (%.2f of 0.5 s)" % burned, burned < 0.4 and burned > 0.2)
	gs.reset_settings()
	for n in [stand, far, d, d2, d3, d4]:
		n.queue_free()


# ── wired into level 20 only ────────────────────────────────────────

func _level_wiring() -> void:
	for lvl in range(1, 26):
		var def := LevelData.get_level(lvl)
		if (lvl == 20) != def.storm:
			_check("storm flag on level %d" % lvl, false)
	_check("only level 20 has a storm", LevelData.get_level(20).storm and not LevelData.get_level(19).storm and not LevelData.get_level(25).storm)
	var scene := (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 20)
	root.add_child(scene)
	await _step(8)
	var d: StormDirector = scene.get_node_or_null("Hazards/StormDirector")
	_check("level 20 builds a storm", d != null)
	var l19 := (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	l19.set("level_number", 19)
	root.add_child(l19)
	await _step(4)
	_check("level 19 does not", l19.get_node_or_null("Hazards/StormDirector") == null)
	l19.queue_free()
	if d != null:
		var player: Player = scene.get_node("Player")
		# A hit reaches the level as a death.
		var attempts_before := int(scene.get("attempts"))
		d.player_hit.emit()
		await _step(4)
		_check("a bolt that hits costs an attempt", int(scene.get("attempts")) > attempts_before)
		_check("and the respawn calms the storm", d.phase == StormDirector.Phase.QUIET)
	scene.queue_free()
	await _step(3)


# ── a bot on the real controller ────────────────────────────────────

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


## Stand on a 900 px platform for a long while. `dodge` decides whether the bot reacts to the
## warning by stepping away from the column.
func _survive(dodge: bool, seed_v: int, seconds: float) -> int:
	var ground := _floor(Vector2(600, 430), Vector2(900, 60))     # surface y = 400, x 150..1050
	var player: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	player.global_position = Vector2(600, 360)
	await _step(8)
	var rects: Array[Rect2] = [Rect2(150, 400, 900, 60)]
	var d := _director(rects, player, seed_v)
	d.set_physics_process(true)
	var hits := [0]
	d.player_hit.connect(func(): hits[0] += 1)
	var frames := int(seconds * 60.0)
	for _f in frames:
		if dodge and d.phase == StormDirector.Phase.WARNING:
			var dx: float = player.global_position.x - d.column_x
			if absf(dx) < 90.0:
				var away := 1.0 if dx >= 0.0 else -1.0
				# If the way away is a wall (the platform edge), go the other way.
				if player.global_position.x + away * 120.0 > 1040.0 or player.global_position.x + away * 120.0 < 160.0:
					away = -away
				Input.action_release("move_left")
				Input.action_release("move_right")
				Input.action_press("move_right" if away > 0.0 else "move_left", 1.0)
			else:
				Input.action_release("move_left")
				Input.action_release("move_right")
		elif dodge:
			Input.action_release("move_left")
			Input.action_release("move_right")
		await physics_frame
	Input.action_release("move_left")
	Input.action_release("move_right")
	var struck: int = d.strikes_fired
	print("   bot dodge=%s: %d bolts, %d hits" % [str(dodge), struck, hits[0]])
	d.queue_free()
	player.queue_free()
	ground.queue_free()
	await _step(2)
	return hits[0]


func _bot() -> void:
	var total_hits := 0
	for sd in [11, 12, 13]:
		total_hits += await _survive(true, sd, 70.0)
	_check("a bot that steps away from each warning is never struck", total_hits == 0)
	# Negative control: standing still in the same storm does get struck.
	var still_hits := 0
	for sd in [11, 12, 13]:
		still_hits += await _survive(false, sd, 70.0)
	_check("negative control: standing still is struck (%d hits)" % still_hits, still_hits > 0)
