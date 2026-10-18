extends SceneTree
## The boss warning banner and the pursuer arrows. Run WITHOUT --headless.


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://boss"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 10)
	root.add_child(scene)
	for i in 15:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var def := LevelData.get_level(10)
	var player: Node2D = scene.get_node("Player")
	player.global_position = def.platforms[6].position + Vector2(0, -80)
	scene.call("_trigger_boss_chase")
	for i in 40:
		player.velocity = Vector2.ZERO
		await process_frame
	root.get_texture().get_image().save_png(out + "/boss_warning.png")
	print("[boss] warning saved")
	# Let the banner leave, then put the pursuers a bit behind.
	for i in 220:
		player.velocity = Vector2.ZERO
		await process_frame
	root.get_texture().get_image().save_png(out + "/boss_arrows.png")
	print("[boss] arrows saved")
	quit(0)
