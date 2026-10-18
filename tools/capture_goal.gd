extends SceneTree
## The goal door at 0, 55 and 100 cores. Run WITHOUT --headless.


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://goal"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DisplayServer.window_set_size(Vector2i(900, 700))
	await process_frame
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 25)
	root.add_child(scene)
	for i in 10:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var player: Node2D = scene.get_node("Player")
	var gate: GoalGate = scene.get_node("Goal/GoalGate")
	for cores in [0, 55, 100]:
		gate.cores = cores
		for k in 12:
			player.global_position = gate.global_position + Vector2(-190, -20)
			player.velocity = Vector2.ZERO
			await process_frame
		root.get_texture().get_image().save_png("%s/goal_%d.png" % [out, cores])
		print("[goal] saved ", cores)
	quit(0)
