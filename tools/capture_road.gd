extends SceneTree
## Frames of a plain-road level with forced obstacle types. Run WITHOUT --headless:
##   Godot --path . --script res://tools/capture_road.gd -- <out_dir> [level]


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://road"
	var level := 13
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
	for i in 15:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var course: RoadCourse = scene.get_node("Hazards/RoadCourse")
	var player: Node2D = scene.get_node("Player")
	var sets := [
		{2: RoadCourse.Cell.LASER, 3: RoadCourse.Cell.PENDULUM},
		{2: RoadCourse.Cell.CRUSHER, 3: RoadCourse.Cell.SHOOTER},
		{2: RoadCourse.Cell.PIT, 3: RoadCourse.Cell.CRUMBLE},
		{2: RoadCourse.Cell.ICE, 3: RoadCourse.Cell.PIPE},
	]
	var k := 0
	for types in sets:
		course.force(types, 5 + k)
		for f in 25:
			player.global_position = Vector2(course.cell_left(2) - 60.0, course.cell_y(2) - 30.0)
			player.velocity = Vector2.ZERO
			await process_frame
		# Let timed hazards reach an interesting phase.
		for f in 70:
			player.global_position = Vector2(course.cell_left(2) - 60.0, course.cell_y(2) - 30.0)
			player.velocity = Vector2.ZERO
			await process_frame
		root.get_texture().get_image().save_png("%s/road_%d.png" % [out, k])
		print("[road] saved ", k)
		k += 1
	quit(0)
