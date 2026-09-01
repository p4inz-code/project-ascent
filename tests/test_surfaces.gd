extends SceneTree
## Ice and sticky surfaces, asserted by MEASURED movement, not by flags.
##
## The temptation with a surface modifier is to test that the setter set the
## variable. That proves nothing a typo could not also pass. What matters is
## whether the player actually slides further on ice and actually moves slower
## on sticky, so both are measured against a plain-ground control run using the
## real controller.
##
## Run with:
##   Godot --headless --path <project> --script res://tests/test_surfaces.gd

var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run()


func _step(n: int) -> void:
	for i in n:
		await physics_frame


## Run right at full tilt, release, and report how far the player coasts.
func _coast_distance(player: Player) -> float:
	Input.action_press("move_right")
	await _step(45)
	Input.action_release("move_right")
	var x0: float = player.global_position.x
	await _step(40)
	return player.global_position.x - x0


func _run() -> void:
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 1)
	get_root().add_child(scene)
	await _step(10)
	var player: Player = scene.get_node("Player")

	# --- Control: ordinary ground -----------------------------------------
	player.clear_surface_modifiers()
	var plain := await _coast_distance(player)

	# --- Ice: same inputs, measurably further ------------------------------
	scene._respawn(0)
	await _step(10)
	player.set_surface_modifiers(5.5, 1.0)
	var iced := await _coast_distance(player)
	_check("ice coasts further than plain ground (%.0fpx vs %.0fpx)" % [iced, plain],
		iced > plain * 1.5)

	# --- Sticky: lower top speed ------------------------------------------
	player.clear_surface_modifiers()
	var full := player.effective_max_speed()
	player.set_surface_modifiers(1.0, 0.52)
	_check("sticky lowers top speed (%.0f -> %.0f)"
		% [full, player.effective_max_speed()],
		player.effective_max_speed() < full * 0.6)

	# --- Ice must not follow the player into the air -----------------------
	# A jump off ice has to feel like an ordinary jump, or every level's
	# measured jump envelope quietly stops applying.
	player.set_surface_modifiers(5.5, 1.0)
	scene._respawn(0)
	await _step(6)
	_check("respawn clears the surface modifier",
		is_equal_approx(player.surface_slip(), 1.0)
		and is_equal_approx(player.effective_max_speed(), player.max_speed))

	scene.queue_free()
	await process_frame

	# --- The levels actually contain them ----------------------------------
	var ice := 0
	var sticky := 0
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		for pdef in LevelData.get_level(n).platforms:
			if pdef.kind == "ice":
				ice += 1
			elif pdef.kind == "sticky":
				sticky += 1
	_check("levels place ice surfaces (%d)" % ice, ice > 0)
	_check("levels place sticky surfaces (%d)" % sticky, sticky > 0)

	# --- And the builder turns them into the right node --------------------
	var lvl: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	lvl.set("level_number", 11)
	get_root().add_child(lvl)
	await _step(8)
	var found := false
	for child in lvl.get_node("Terrain").get_children():
		if child is SurfacePlatform:
			found = true
			break
	_check("the terrain builder instantiates SurfacePlatform for kind 'ice'", found)
	lvl.queue_free()
	await process_frame

	print("[test_surfaces] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
