extends SceneTree
## Trevor's orbs: the arithmetic, the persistence, and the final door.
##
## Three things can quietly ruin a collectible economy, and each has a check
## here:
##
##   1. The totals not adding up. If the game contains 99 orbs and the door
##      costs 100, the game is unfinishable and nothing else will say so.
##   2. Replaying a level banking the same orb twice, which makes the door
##      payable without playing the content.
##   3. The final door refusing a player who HAS paid, or opening for one who
##      has not.
##
## Run with:
##   Godot --headless --path <project> --script res://tests/test_orbs.gd

var _failures: int = 0
## Member, not a local: GDScript lambdas capture locals by value, so a signal
## flag written inside a closure never reaches the outer scope.
var _banked: int = -1


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
	# --- 1. The economy must be exact -------------------------------------
	var total := 0
	var per_level_wrong := 0
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		var defs: Array = LevelData.orbs_for(n)
		var expect_orbs: bool = (n >= SaveSystem.FIRST_ORB_LEVEL
			and n <= SaveSystem.LAST_ORB_LEVEL)
		if expect_orbs and defs.size() != SaveSystem.ORBS_PER_LEVEL:
			per_level_wrong += 1
		if not expect_orbs and not defs.is_empty():
			per_level_wrong += 1
		total += defs.size()
	_check("every orb level carries exactly %d orbs" % SaveSystem.ORBS_PER_LEVEL,
		per_level_wrong == 0)
	_check("the game contains exactly the %d orbs the door costs (found %d)"
		% [SaveSystem.ORB_GOAL, total], total == SaveSystem.ORB_GOAL)

	# --- The route/optional split -----------------------------------------
	var route := 0
	var optional := 0
	for d in LevelData.orbs_for(SaveSystem.FIRST_ORB_LEVEL):
		if d.kind == 0:
			route += 1
		else:
			optional += 1
	_check("orbs split into route (%d) and optional (%d)" % [route, optional],
		route > 0 and optional > 0)

	# --- Deterministic placement ------------------------------------------
	# The save record is keyed by index, so a position that moved between runs
	# would make it meaningless.
	var a: Array = LevelData.orbs_for(9)
	var b: Array = LevelData.orbs_for(9)
	var same := true
	for i in a.size():
		if a[i].position != b[i].position or a[i].kind != b[i].kind:
			same = false
	_check("placement is deterministic across calls", same)

	# --- 2. Persistence must not double-count -----------------------------
	var save := SaveSystem.new()
	save.collected_orbs.clear()
	_check("a fresh save has no orbs", save.orb_total() == 0)
	_check("first pickup banks", save.collect_orb(7, 2))
	_check("the same orb refuses to bank twice", not save.collect_orb(7, 2))
	_check("total counts it once (%d)" % save.orb_total(), save.orb_total() == 1)
	save.collect_orb(7, 3)
	save.collect_orb(8, 0)
	_check("total across levels (%d)" % save.orb_total(), save.orb_total() == 3)
	_check("remaining is derived (%d)" % save.orbs_remaining(),
		save.orbs_remaining() == SaveSystem.ORB_GOAL - 3)
	_check("has_orb reports accurately",
		save.has_orb(7, 2) and not save.has_orb(7, 4))

	# --- Orbs exist in a real level, and collecting one banks it ----------
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 9)
	get_root().add_child(scene)
	await _step(8)
	var orb0 = scene.get_node_or_null("Hazards/Orb_0")
	_check("a level builds its orbs", orb0 != null)
	if orb0 != null:
		_banked = -1
		scene.orb_collected.connect(func(t: int) -> void: _banked = t)
		var player: Player = scene.get_node("Player")
		player.global_position = orb0.global_position
		await _step(6)
		_check("touching an orb banks it (total now %d)" % _banked, _banked > 0)
	scene.queue_free()
	await process_frame

	# --- 3. The final door ------------------------------------------------
	var gm := root.get_node_or_null("GameManager")
	if gm != null and gm.save_system != null:
		var backup: Dictionary = gm.save_system.collected_orbs.duplicate(true)

		gm.save_system.collected_orbs.clear()
		var last: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
		last.set("level_number", LevelData.TOTAL_LEVELS)
		get_root().add_child(last)
		await _step(8)
		var p2: Player = last.get_node("Player")
		var lvd := LevelData.get_level(LevelData.TOTAL_LEVELS)
		p2.global_position = lvd.goal_position
		await _step(8)
		_check("the final door refuses a player with no orbs",
			not bool(last.get("_level_complete")))
		last.queue_free()
		await process_frame

		# Now pay in full.
		gm.save_system.collected_orbs.clear()
		for lvl in range(SaveSystem.FIRST_ORB_LEVEL, SaveSystem.LAST_ORB_LEVEL + 1):
			for i in SaveSystem.ORBS_PER_LEVEL:
				gm.save_system.collect_orb(lvl, i)
		_check("paying every orb reaches the goal exactly (%d)"
			% gm.save_system.orb_total(),
			gm.save_system.orb_total() == SaveSystem.ORB_GOAL)

		var last2: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
		last2.set("level_number", LevelData.TOTAL_LEVELS)
		get_root().add_child(last2)
		await _step(8)
		var p3: Player = last2.get_node("Player")
		p3.global_position = LevelData.get_level(LevelData.TOTAL_LEVELS).goal_position
		await _step(8)
		_check("the final door opens once it is paid",
			bool(last2.get("_level_complete")))
		last2.queue_free()
		await process_frame

		gm.save_system.collected_orbs = backup

	print("[test_orbs] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
