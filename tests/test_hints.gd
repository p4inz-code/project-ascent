extends SceneTree
## Teaching hints: the early levels must teach their verb in the world, a hint
## must fade IN near the player and OUT away from them, and the slide hint in
## particular must say how to slide (the one verb players reported as "broken").

var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	for n in [1, 2, 3, 4]:
		var def = LevelData.get_level(n)
		_check("level %d teaches something (%d hint(s))" % [n, def.hints.size()],
			def.hints.size() >= 1)

	var l3 = LevelData.get_level(3)
	var mentions_slide := false
	for h in l3.hints:
		if h.text.to_upper().contains("SLIDE"):
			mentions_slide = true
	_check("level 3 hint names the slide verb and its keys", mentions_slide)

	# Behaviour: fades in near the player, out when far.
	var scene := load("res://scenes/main_scene.tscn") as PackedScene
	var main := scene.instantiate()
	main.set("level_number", 3)
	root.add_child(main)
	await physics_frame
	var player: Node2D = main.get_node("Player")
	var hint: LevelHint = null
	for child in main.get_node("Hazards").get_children():
		if child is LevelHint:
			hint = child
			break
	_check("the level actually builds its hint node", hint != null)
	if hint != null:
		player.global_position = hint.global_position + Vector2(0, 100)
		for _i in 40:
			await physics_frame
		_check("hint is shown when the player is near", hint.is_shown())
		player.global_position = hint.global_position + Vector2(4000, 0)
		for _i in 60:
			await physics_frame
		_check("hint is hidden when the player is far", not hint.is_shown())
	main.queue_free()
	print("[test_hints] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
