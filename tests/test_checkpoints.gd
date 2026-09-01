extends SceneTree
## Mid-level checkpoints (Acts IV–V only).
##
## Asserts the three properties that make this feature honest:
##   1. Acts I–III have NO checkpoints. Those levels are short, and removing
##      the cost of a mistake there would strip the tension the whole genre
##      runs on. This is a design guarantee, so it gets a test.
##   2. Acts IV–V each have one, and it sits on real footing.
##   3. Claiming one actually changes where a death puts you — the only thing
##      a player can observe, and therefore the only thing worth asserting.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await _run()
	print("[test_checkpoints] failures=%d" % _failures)
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
	_check_distribution()
	await _check_respawn_moves()


## Acts I–III must stay checkpoint-free; Acts IV–V must each have one.
func _check_distribution() -> void:
	var early_with := 0
	var late_without := 0
	for lvl in range(1, 26):
		var def = LevelData.get_level(lvl)
		if def == null:
			_check("Level %d loaded" % lvl, false)
			return
		if lvl <= 15 and def.checkpoints.size() > 0:
			early_with += 1
		if lvl >= 16 and def.checkpoints.size() == 0:
			late_without += 1
	_check("Acts I-III have no checkpoints (%d violations)" % early_with,
		early_with == 0)
	_check("every Act IV-V level has one (%d missing)" % late_without,
		late_without == 0)

	# A flag floating in space would be unreachable and therefore pointless.
	var orphans := 0
	for lvl in range(16, 26):
		var def = LevelData.get_level(lvl)
		for cp in def.checkpoints:
			var supported := false
			for p in def.platforms:
				var top: float = p.position.y - p.size.y * 0.5
				var left: float = p.position.x - p.size.x * 0.5
				var right: float = p.position.x + p.size.x * 0.5
				# Within the platform's span and sitting just above its surface.
				if cp.position.x >= left - 20.0 and cp.position.x <= right + 20.0 \
						and absf(cp.position.y - (top - 45.0)) < 30.0:
					supported = true
					break
			if not supported:
				orphans += 1
	_check("every checkpoint sits on real footing (%d floating)" % orphans,
		orphans == 0)


## The observable behaviour: die after claiming a flag, respawn at the flag.
func _check_respawn_moves() -> void:
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 16)
	root.add_child(scene)
	await _step(8)

	var player = scene.get_node_or_null("Player")
	var flag = scene.get_node_or_null("Hazards/Checkpoint_0")
	if player == null or flag == null:
		_check("level 16 built a player and a checkpoint", false)
		scene.queue_free()
		return

	# Baseline: dying with no checkpoint claimed returns to spawn.
	var spawn: Vector2 = scene.get("_spawn_point")
	scene._respawn(0)
	await _step(4)
	# Compare RELATIVELY, not to the spawn coordinate exactly. The spawn point
	# sits below the ground surface, so the player is resolved upward onto it
	# and settles ~126px above the literal spawn Y — checking for an exact
	# match failed on that alone, which says nothing about checkpoints.
	var d_spawn: float = player.global_position.distance_to(spawn)
	var d_flag: float = player.global_position.distance_to(flag.global_position)
	_check("without a checkpoint, death returns near spawn, not the flag (%.0f vs %.0f)"
		% [d_spawn, d_flag], d_spawn < d_flag * 0.1)

	# Claim it, then die again.
	flag._on_body_entered(player)
	await _step(2)
	_check("the flag registers as claimed", flag.is_active())

	scene._respawn(0)
	await _step(4)
	var at_flag: bool = player.global_position.distance_to(flag.global_position) < 8.0
	_check("after claiming, death returns to the checkpoint (not spawn %.0fpx away)"
		% spawn.distance_to(flag.global_position), at_flag)

	scene.queue_free()
	await _step(2)
