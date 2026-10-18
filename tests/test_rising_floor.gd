extends SceneTree
## Boss levels: the biome floor (ground, water, ice, lava) climbs as the boss
## countdown runs out. It starts at the level floor, never reaches the goal, kills
## a player who is below it, resets with the countdown on every attempt, and does
## not exist on ordinary levels.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	for lvl in [5, 10, 15, 20, 25]:
		await _boss_level(lvl)
	await _ordinary_level()
	print("[test_rising_floor] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _load(level_num: int) -> MainScene:
	var scene := (load("res://scenes/main_scene.tscn") as PackedScene).instantiate() as MainScene
	scene.set("level_number", level_num)
	root.add_child(scene)
	await _step(6)
	return scene


func _boss_level(lvl: int) -> void:
	var scene := await _load(lvl)
	var notice := scene.get_node_or_null("RisingFloorNotice")
	_check("L%d tells the player the floor is rising" % lvl, notice != null)
	_check("L%d has a warning glow that starts dark" % lvl, scene.get("_rise_glow") != null and scene.get("_rise_glow").modulate.a < 0.05)
	var def := LevelData.get_level(lvl)
	var limit: float = def.boss_config.time_limit
	var global_y: float = scene.get("_plane_global_y")
	var plane: Node2D = scene.get_node("Hazards/DeathPlane")

	scene.set("_chase_time_left", limit)
	var at_start: float = scene.rising_floor_y()
	_check("L%d the floor starts at the level floor" % lvl, absf(at_start - global_y) < 8.0)

	scene.set("_chase_time_left", limit * 0.5)
	var half: float = scene.rising_floor_y()
	scene.set("_chase_time_left", 0.001)
	var end: float = scene.rising_floor_y()
	_check("L%d it has risen at half time and more at the end" % lvl, half < at_start - 100.0 and end < half - 100.0)
	_check("L%d it never reaches the goal (ends %.0f below it)" % [lvl, end - def.goal_position.y],
		end > def.goal_position.y + 0.2 * (global_y - def.goal_position.y))
	# It accelerates: the second half of the countdown raises the floor more than the first.
	_check("L%d it accelerates (first half rises %.0f, second half %.0f)" % [lvl, at_start - half, half - end],
		(half - end) > (at_start - half) * 1.5)

	# The visible floor follows it: with the countdown at zero the plane is raised.
	scene.set("_chase_time_left", 0.001)
	scene.set("_berserk", true)
	scene.set("_chase_triggered", true)
	# Park the player well above the final floor so the climb itself does not kill them.
	var parked: Node2D = scene.get_node("Player")
	parked.global_position = Vector2(parked.global_position.x, end - 500.0)
	parked.velocity = Vector2.ZERO
	parked.set_physics_process(false)
	await _step(90)
	# The clock ran out before the chase began, so the chase restarted the countdown.
	# The floor must not drop back with it.
	_check("L%d the floor does not fall back when the clock restarts" % lvl,
		scene.rising_floor_y() <= end + 2.0)
	_check("L%d the visible floor has climbed with the clock" % lvl, plane.position.y < global_y - 200.0)
	_check("L%d and sits on the rising line (or the local one, whichever is higher)" % lvl,
		plane.position.y <= end + 2.0)

	parked.set_physics_process(true)
	# Close to the floor: the glow is strong.
	parked.global_position = Vector2(parked.global_position.x, plane.position.y - 60.0)
	parked.set_physics_process(false)
	await _step(4)
	_check("L%d the warning glow is strong when the floor is near" % lvl, scene.get("_rise_glow").modulate.a > 0.7)
	parked.set_physics_process(true)
	# Below the risen floor means death; above it is fine.
	var attempts_before: int = scene.get("attempts")
	var player: Node2D = scene.get_node("Player")
	player.global_position = Vector2(player.global_position.x, plane.position.y + 150.0)
	player.velocity = Vector2.ZERO
	await _step(20)
	_check("L%d a player under the risen floor is killed" % lvl, int(scene.get("attempts")) > attempts_before)
	# The attempt restarts the countdown, and with it the floor.
	await _step(4)
	var after: float = scene.rising_floor_y()
	_check("L%d a new attempt resets the countdown and the floor" % lvl,
		after > end + 100.0 and float(scene.call("boss_time_left")) > limit * 0.5)
	scene.queue_free()
	await _step(2)


func _ordinary_level() -> void:
	var scene := await _load(3)
	scene.set("_chase_time_left", 0.5)
	_check("ordinary levels have no rising floor", scene.rising_floor_y() == INF)
	_check("and no rising-floor notice", scene.get_node_or_null("RisingFloorNotice") == null)
	scene.queue_free()
	await _step(2)
