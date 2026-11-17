extends SceneTree
## Impact effects: dust and the death burst spawn, draw, free themselves, and stay off under reduced motion.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	await physics_frame
	var holder := Node2D.new()
	root.add_child(holder)
	var gs := root.get_node_or_null("GameSettings")
	var fx := ImpactFx.spawn(holder, Vector2(100, 100), ImpactFx.Kind.DUST, 1.0)
	_check("dust spawns", fx != null and fx.get_parent() == holder)
	var burst := ImpactFx.spawn(holder, Vector2(100, 100), ImpactFx.Kind.BURST, 1.0)
	_check("a burst spawns with more bits than dust", burst != null)
	for i in 4:
		await process_frame
	_check("they have bits and are drawing", fx._bits.size() > 0 and burst._bits.size() > fx._bits.size())
	await create_timer(0.7).timeout
	_check("both free themselves after their life", not is_instance_valid(fx) and not is_instance_valid(burst))
	if gs != null:
		var before: bool = gs.bg_motion
		gs.bg_motion = false
		_check("(control) reduced motion (background motion off) spawns nothing", ImpactFx.spawn(holder, Vector2.ZERO, ImpactFx.Kind.BURST) == null)
		gs.bg_motion = before
	# in a real level a hard landing makes dust and a death makes a burst
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 2)
	root.add_child(main)
	for i in 6:
		await physics_frame
	var count := func() -> int:
		var n := 0
		for c in main.get_children():
			if c is ImpactFx:
				n += 1
		return n
	main._on_player_landed(600.0)
	_check("a hard landing spawns dust in the level", count.call() == 1)
	var c1: int = count.call()
	main._on_player_landed(100.0)
	_check("(control) a soft landing spawns none", count.call() == c1)
	main.queue_free()
	holder.queue_free()
	print("[test_impact_fx] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
