extends SceneTree
## The door at the end of a level: it shows banked cores in ten sockets, drains open
## when the player arrives, and replaces the old flat goal visual without breaking it.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_sockets()
	await _in_level()
	print("[test_goal_gate] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _sockets() -> void:
	var g := GoalGate.new()
	g.core_goal = 100
	g.cores = 0
	_check("no cores: no sockets lit", g.lit_sockets() == 0)
	g.cores = 9
	_check("9 cores: still none (10 per socket)", g.lit_sockets() == 0)
	g.cores = 10
	_check("10 cores: one socket", g.lit_sockets() == 1)
	g.cores = 55
	_check("55 cores: five sockets", g.lit_sockets() == 5)
	g.cores = 99
	_check("99 cores: nine sockets, not full", g.lit_sockets() == 9 and not g.is_full())
	g.cores = 100
	_check("100 cores: all ten, full", g.lit_sockets() == 10 and g.is_full())
	g.cores = 400
	_check("more than the goal never lights more than ten", g.lit_sockets() == GoalGate.SOCKETS)
	g.core_goal = 0
	_check("a zero goal is safe", g.lit_sockets() == 0)
	g.free()


func _in_level() -> void:
	var scene := (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 25)
	root.add_child(scene)
	await _step(6)
	var gate: GoalGate = scene.get_node_or_null("Goal/GoalGate")
	_check("the level builds a gate at the goal", gate != null)
	_check("level 25's gate is the final one", gate != null and gate.is_final)
	_check("the old goal visuals are hidden, not removed",
		scene.get_node("Goal/GoalVisual") != null and not scene.get_node("Goal/GoalVisual").visible)
	_check("the door matches the goal size", gate != null and gate.door_size == LevelData.get_level(25).goal_size)
	var player: Node2D = scene.get_node("Player")
	var before := gate.is_open()
	# Walk the player onto the door: it opens.
	player.global_position = LevelData.get_level(25).goal_position
	await _step(40)
	_check("it was closed before the player arrived", not before)
	_check("and drains open when they arrive", gate._open > 0.5 or gate.is_open() or gate._opening)
	scene.queue_free()
	await _step(2)

	var early := (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	early.set("level_number", 3)
	root.add_child(early)
	await _step(6)
	var g3: GoalGate = early.get_node_or_null("Goal/GoalGate")
	_check("ordinary levels get the door too, not marked final", g3 != null and not g3.is_final)
	early.queue_free()
	await _step(2)
