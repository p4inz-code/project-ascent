extends SceneTree
## Real level-clear transition: finish level 7 in the real game scene and capture the results card, the closed
## cover with the level card, and the next level once open. Run WITHOUT --headless, APPDATA redirected.
func _initialize() -> void:
	_go()
func _go() -> void:
	DirAccess.make_dir_recursive_absolute(".cap/clear")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var gs: Node = root.get_node("GameSettings")
	var gm: Node = root.get_node("GameManager")
	gs.intro_seen = true
	gs.tutorial_done = true
	var game: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for i in 60:
		await process_frame
	var menu := game.get_node_or_null("StartMenu")
	if menu != null:
		menu.queue_free()
		paused = false
		gm.is_paused = false
	gm.current_level = 7
	gm.level_changed.emit(7)
	for i in 240:
		await process_frame
	var lvl: Node = game.get("_current_level_scene")
	lvl.set("attempts", 6)
	lvl.set("run_time", 47.3)
	lvl._on_goal_body_entered(lvl.get_node("Player"))
	var shots := {40: "1_card", 140: "2_cover_card", 400: "3_next_level"}
	for f in 420:
		await process_frame
		if shots.has(f):
			root.get_texture().get_image().save_png(".cap/clear/%s.png" % shots[f])
			print("saved ", shots[f], " level now ", gm.current_level)
	quit(0)
