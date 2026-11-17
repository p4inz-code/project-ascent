extends SceneTree
## Screenshots of each kind of hazard in a real level. Run WITHOUT --headless:
##   Godot --path . --script res://tools/capture_hazards.gd -- <out_dir> [level]


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://hazards"
	var level := 22
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1:
		level = int(a[1])
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", level)
	root.add_child(scene)
	for i in 20:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var player: Node2D = scene.get_node("Player")
	var seen := {}
	for child in scene.get_node("Hazards").get_children():
		var kind := ""
		if child is SpinningBlade:
			kind = "blade"
		elif child is Pendulum:
			kind = "pendulum"
		elif child is ShooterTrap:
			kind = "shooter"
		elif child is TimedGate:
			kind = "gate"
		elif child is PipeTube:
			kind = "pipe"
		if kind == "" or seen.has(kind):
			continue
		seen[kind] = true
		for k in 12:
			player.global_position = child.global_position + Vector2(-260, -140)
			player.velocity = Vector2.ZERO
			await process_frame
		root.get_texture().get_image().save_png("%s/hz_%s.png" % [out, kind])
		print("[hazard] saved ", kind)
	quit(0)
