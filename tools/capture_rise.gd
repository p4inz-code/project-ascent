extends SceneTree
## A boss level with the biome floor risen part-way. Run WITHOUT --headless.


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://rise"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 20)
	root.add_child(scene)
	for i in 10:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var def := LevelData.get_level(20)
	var limit: float = def.boss_config.time_limit
	scene.set("_chase_triggered", true)
	scene.set("_chase_time_left", limit * 0.55)
	var player: Node2D = scene.get_node("Player")
	# Stand on a platform about 40% of the way up the route.
	var p = def.platforms[int(def.platforms.size() * 0.55)]
	for k in 90:
		player.global_position = p.position + Vector2(0, -p.size.y * 0.5 - 40.0)
		player.velocity = Vector2.ZERO
		await process_frame
	root.get_texture().get_image().save_png(out + "/rise.png")
	print("[rise] saved")
	quit(0)
