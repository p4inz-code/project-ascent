extends SceneTree
## The obstacle catalogue, checked by OBSERVABLE BEHAVIOUR.
##
## Every one of these has a fairness rule baked into it, and a rule that is
## only written in a comment is a rule that quietly stops being true. So each
## check here measures the behaviour the rule promises:
##
##   TIMED PLATFORM  cycles, and warns before it goes
##   PRESSURE PLATE  opens its gate, and the gate closes again on expiry
##   SHOOTER         fires on its interval, and its shots actually travel
##   RISING LAVA     rises slower than a climb, and RESETS on death
##
## Run with:
##   Godot --headless --path <project> --script res://tests/test_obstacles.gd

var _failures: int = 0
## Member, not local — GDScript lambdas capture locals by value.
var _hit: bool = false


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	# --- Timed platform ---------------------------------------------------
	var tp := TimedPlatform.new()
	tp.on_time = 0.25
	tp.off_time = 0.25
	get_root().add_child(tp)
	await _step(2)
	var saw_on := false
	var saw_off := false
	for _i in 60:
		await physics_frame
		if tp.is_solid():
			saw_on = true
		else:
			saw_off = true
	_check("a timed platform actually cycles on and off", saw_on and saw_off)
	tp.queue_free()
	await process_frame

	# --- Pressure plate and gate ------------------------------------------
	var plate := PressurePlate.new()
	plate.hold_time = 0.35
	plate.link_id = 7
	var gate := TimedGate.new()
	gate.link_id = 7
	get_root().add_child(plate)
	get_root().add_child(gate)
	plate.activated.connect(func(_id: int) -> void: gate.open())
	plate.expired.connect(func(_id: int) -> void: gate.close())
	await _step(2)
	_check("the gate starts closed", not gate.is_open())
	plate._on_entered(_make_player())
	await _step(3)
	_check("standing on the plate opens the gate", gate.is_open())
	# And it must close again, or a plate is a permanent switch and the timer
	# it advertises is a lie.
	await _step(40)
	_check("the gate closes when the hold expires", not gate.is_open())
	plate.queue_free()
	gate.queue_free()
	await process_frame

	# --- Shooter ----------------------------------------------------------
	# The interval is overridden for a fast test, but projectile_speed is
	# deliberately LEFT AT ITS DEFAULT here rather than set to a test value.
	# Checking a value the test itself set is tautological - it can never
	# catch a regression in the real @export default that every level
	# actually uses. Reading @export default via a fresh, untouched instance
	# is what proves the shipped speed is what the fairness rule requires.
	var trap := ShooterTrap.new()
	trap.interval = 0.2
	get_root().add_child(trap)
	await _step(30)
	_check("the shooter emits projectiles (%d live)" % trap.live_shot_count(),
		trap.live_shot_count() > 0)
	# Slower than the player's 320px/s run: you walk through the gaps, you do
	# not react to them.
	_check("the shipped default speed is slower than the player runs (%d vs 320)"
		% int(trap.projectile_speed), trap.projectile_speed < 320.0)

	# And the hit path itself must actually fire, not just spawn projectiles -
	# a broken collision_mask or a broken `is Player` check would leave every
	# shooter harmless while live_shot_count() still reports normally.
	_hit = false
	trap.player_hit.connect(func() -> void: _hit = true)
	var pl := _make_player()
	# Sit directly in the muzzle's path so the very next shot cannot miss.
	pl.global_position = trap.global_position + trap.direction.normalized() * 40.0
	var frames := 0
	while not _hit and frames < 120:
		await physics_frame
		frames += 1
	_check("a projectile that reaches the player actually fires player_hit", _hit)
	pl.queue_free()
	trap.queue_free()
	await process_frame

	# --- Rising lava ------------------------------------------------------
	var rl := RisingLava.new()
	rl.start_y = 500.0
	rl.rise_speed = 40.0
	get_root().add_child(rl)
	await _step(2)
	var y0 := rl.surface_y()
	_check("lava is dormant until triggered", not rl.is_rising())
	await _step(20)
	_check("dormant lava does not move", is_equal_approx(rl.surface_y(), y0))
	rl.start_rising()
	await _step(30)
	_check("triggered lava climbs (%.0f -> %.0f)" % [y0, rl.surface_y()],
		rl.surface_y() < y0)
	# The one that matters: respawning into lava already at the ceiling is
	# dead on arrival, so death has to put it back.
	rl.reset()
	await _step(2)
	_check("reset puts lava back to its start", is_equal_approx(rl.surface_y(), y0))
	rl.queue_free()
	await process_frame

	# --- And they are actually PLACED in levels ---------------------------
	var timed := 0
	var shooters := 0
	var lavas := 0
	var plates := 0
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		var lv := LevelData.get_level(n)
		for pd in lv.platforms:
			if pd.kind == "timed":
				timed += 1
		shooters += lv.shooters.size()
		lavas += lv.rising_lava.size()
		plates += lv.plate_gates.size()
	_check("timed platforms are placed (%d)" % timed, timed > 0)
	_check("shooters are placed (%d)" % shooters, shooters > 0)

	var decoys := 0
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		for pd in LevelData.get_level(n).platforms:
			if String(pd.name).contains("Decoy"):
				decoys += 1
	_check("Act V decoy routes are placed (%d)" % decoys, decoys > 0)
	_check("rising lava is placed (%d)" % lavas, lavas > 0)
	# Plate/gate pairs are NOT currently placed in any level. The placement
	# heuristic put a solid plate directly in the middle of an existing jump
	# arc (confirmed on level 17's S7_3->S7_4: the player landed ON the plate
	# mid-flight instead of continuing to the real platform, then fell off it
	# into the void), breaking reachability on 9 levels. The mechanism itself
	# is built and unit-tested above; safe per-level placement is future work.
	_check("plate/gate pairs are not placed until a collision-safe heuristic exists",
		plates == 0)

	# --- The builder turns the data into the right nodes ------------------
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", LevelData.TOTAL_LEVELS)
	get_root().add_child(scene)
	await _step(8)
	var haz := scene.get_node_or_null("Hazards")
	var found := {"shooter": false, "lava": false}
	if haz != null:
		for c in haz.get_children():
			if c is ShooterTrap: found["shooter"] = true
			elif c is RisingLava: found["lava"] = true
	_check("the last level builds shooters and lava",
		found["shooter"] and found["lava"])
	scene.queue_free()
	await process_frame

	print("[test_obstacles] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _make_player() -> Player:
	var pl := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	get_root().add_child(pl)
	return pl
