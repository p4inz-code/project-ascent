extends SceneTree
## THE TEMPEST (level 20): the arena is built from the def, the four rods only count a real ground pound
## onto their cap, lightning never touches a player who keeps moving (and does touch one who stands still),
## and pounding all four opens the gate and stops the storm.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	var def := LevelData.get_level(20)
	_check("level 20 is the tempest arena with no chasers", def.tempest and not def.boss_config.enabled)
	_check("four rod pillars and a gate", def.plate_gates.size() == 1 and def.platforms.size() == 4 + TempestDirector.ROD_X.size())
	_check("every pillar can be jumped onto from the floor (a pound needs height above the cap)", TempestDirector.ROD_H.max() < 96.0)
	await physics_frame
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 20)
	root.add_child(main)
	for i in 6:
		await physics_frame
	var tempest := main.get_node_or_null("Tempest") as TempestDirector
	_check("the director is built", tempest != null)
	if tempest == null:
		quit(1)
		return
	var player := main.get_node("Player") as Player
	player.set_physics_process(false)
	# 1: a player who keeps moving is never hit in 12 s (the tell is 1.25 s, the strike is 0.9 s wide)
	tempest.reset()
	var x := 300.0
	var dir := 1.0
	for i in 720:
		x += dir * 200.0 / 60.0
		if x > 1500.0:
			dir = -1.0
		elif x < 300.0:
			dir = 1.0
		player.global_position = Vector2(x, TempestDirector.FLOOR_Y - 30.0)
		await physics_frame
	_check("a player who keeps moving is never struck (%d strikes fell, %d chips)" % [tempest.strikes_fired, tempest.chips], tempest.chips == 0)
	# control: standing still is struck
	tempest.reset()
	player.global_position = Vector2(400.0, TempestDirector.FLOOR_Y - 30.0)
	for i in 480:
		await physics_frame
	_check("(control) a player who stands still is struck (%d chips)" % tempest.chips, tempest.chips >= 1)
	# 2: rods. A pound beside the rod does not count (control), a pound onto the cap does.
	tempest.reset()
	tempest._t = -1000.0      # the rods are tested without the storm
	player.heal_full()
	player.set_physics_process(true)
	await physics_frame
	var rod_x: float = TempestDirector.ROD_X[0]
	_pound_at(player, rod_x + 260.0, TempestDirector.FLOOR_Y - 220.0)
	for i in 40:
		await physics_frame
	_release()
	_check("(control) a pound beside the rod does not count", tempest.rods_done() == 0)
	for r in TempestDirector.ROD_X.size():
		var rx: float = TempestDirector.ROD_X[r]
		var cy: float = TempestDirector.FLOOR_Y - TempestDirector.ROD_H[r]
		_pound_at(player, rx, cy - 200.0)
		for i in 40:
			await physics_frame
		_release()
		for i in 12:
			await physics_frame
	_check("a real ground pound onto each cap lights all four rods (%s)" % str(tempest.pounded), tempest.rods_done() == 4)
	_check("the gate to the door opens when the fourth rod is pounded", tempest._open)
	main.queue_free()
	print("[test_tempest] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _pound_at(player: Player, x: float, y: float) -> void:
	player.global_position = Vector2(x, y)
	player.velocity = Vector2.ZERO
	Input.action_press("slide")
	Input.action_press("jump")


func _release() -> void:
	Input.action_release("slide")
	Input.action_release("jump")
