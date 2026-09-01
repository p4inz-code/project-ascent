extends SceneTree
## Boss chase countdown and berserk escalation.
##
## The design rule this enforces: expiry must make the boss FASTER, never kill
## the player. A run ending to a number you could not fight is a different and
## much worse game than one ending to a chaser you could not outrun.
##
## Also covers the reset path, because the obvious bug here is a player who
## dies late respawning into an already-expired chase and being instantly
## berserked — which reads as the game cheating.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await _run()
	print("[test_boss_timer] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _run() -> void:
	await physics_frame
	_check_config()
	await _check_countdown_and_berserk()


func _check_config() -> void:
	var boss_levels := [5, 10, 15, 20, 25]
	var missing := 0
	for lvl in boss_levels:
		var def = LevelData.get_level(lvl)
		if def == null or not def.boss_config.enabled:
			missing += 1
			continue
		if def.boss_config.time_limit <= 0.0:
			missing += 1
		if def.boss_config.berserk_multiplier <= 1.0:
			missing += 1
	_check("every boss level has a positive limit and a >1 multiplier (%d issues)"
		% missing, missing == 0)

	# Non-boss levels must not carry a chase clock at all.
	var stray := 0
	for lvl in range(1, 26):
		if lvl in boss_levels:
			continue
		var def = LevelData.get_level(lvl)
		if def != null and def.boss_config.enabled:
			stray += 1
	_check("no non-boss level has a chase enabled (%d)" % stray, stray == 0)


func _check_countdown_and_berserk() -> void:
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 5)
	root.add_child(scene)
	await _step(8)

	# The clock is a deadline for the LEVEL, not for the chase. Arming it only
	# at the trigger point meant the countdown was invisible for the whole
	# approach, so the only timer on screen was the run timer counting UP —
	# which reads as no deadline at all. It now runs from level load.
	_check("clock is armed from level load (%.1f)" % scene.boss_time_left(),
		scene.boss_time_left() > 0.0)
	var at_load: float = scene.boss_time_left()
	await _step(20)
	_check("...and is actually ticking down (%.1f -> %.1f)"
		% [at_load, scene.boss_time_left()], scene.boss_time_left() < at_load)

	# Move the player well clear before triggering. Left at spawn, the chasers
	# activate essentially on top of them, register a catch within a frame or
	# two, and the resulting respawn resets the clock to dormant — so the
	# "clock never started" failure was the catch firing, not the timer.
	var p1 = scene.get_node_or_null("Player")
	if p1 != null:
		p1.global_position = Vector2(3200, 100)
	await _step(2)
	scene._trigger_boss_chase()
	await _step(4)
	var started: float = scene.boss_time_left()
	_check("clock starts with the chase (%.1fs)" % started, started > 0.0)

	if p1 != null:
		p1.global_position = Vector2(3200, 100)
	await _step(20)
	_check("clock actually counts down (%.1f -> %.1f)" % [started, scene.boss_time_left()],
		scene.boss_time_left() < started)
	_check("not berserk while time remains", not scene.is_berserk())

	# Capture speeds, then force expiry.
	var boss = scene.get("_boss")
	var speed_before: float = boss.base_speed if boss != null else 0.0
	scene.set("_chase_time_left", 0.05)
	if p1 != null:
		p1.global_position = Vector2(3200, 100)
	await _step(10)

	_check("berserk engages once the limit expires", scene.is_berserk())
	if boss != null:
		_check("berserk makes the boss faster (%.0f -> %.0f)"
			% [speed_before, boss.base_speed], boss.base_speed > speed_before)

	# The player must still be alive — expiry escalates, it does not kill.
	var player = scene.get_node_or_null("Player")
	_check("expiry does not kill the player outright", player != null)

	# And a death must reset the clock rather than respawning into berserk.
	scene._respawn(0)
	await _step(4)
	_check("death clears berserk", not scene.is_berserk())
	# A death re-arms the deadline at full rather than clearing it: respawning
	# into an already-expired clock would drop the player straight back into a
	# berserk chase, which reads as the game cheating.
	_check("death re-arms the clock at full (%.1f)" % scene.boss_time_left(),
		scene.boss_time_left() > 60.0)

	scene.queue_free()
	await _step(2)
