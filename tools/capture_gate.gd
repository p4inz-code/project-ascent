extends SceneTree
## Frames of a laser gate and a crusher in a real level. Run WITHOUT --headless.


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://gates"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 14)
	root.add_child(scene)
	for i in 20:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var player: Node2D = scene.get_node("Player")
	var hazards := scene.get_node("Hazards")
	var shots := 0
	for child in hazards.get_children():
		if not (child is TimedGate) or shots >= 4:
			continue
		var gate: TimedGate = child
		player.global_position = gate.global_position + Vector2(-230, -60)
		player.velocity = Vector2.ZERO
		for phase_name in ["warn", "active"]:
			var t := gate.safe_time + 0.2 if phase_name == "warn" else gate.safe_time + gate.warn_time + 0.1
			for k in 6:
				gate._time = t
				player.global_position = gate.global_position + Vector2(-230, -60)
				player.velocity = Vector2.ZERO
				await process_frame
			root.get_texture().get_image().save_png("%s/gate_%d_%s.png" % [out, shots, phase_name])
		print("[gate] saved ", shots, " kind=", gate.kind)
		shots += 1
	quit(0)
