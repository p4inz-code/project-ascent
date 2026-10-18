extends SceneTree
## Renders the pools alone (lava, acid, water) and a pit lava next to platforms.
## Run WITHOUT --headless: Godot --path . --script res://tools/capture_lava.gd -- <out_dir>


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://lava"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DisplayServer.window_set_size(Vector2i(1200, 700))
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.12)
	bg.size = Vector2(1200, 700)
	root.add_child(bg)
	var lava := Lava.new()
	lava.size = Vector2(520, 160)
	lava.position = Vector2(330, 300)
	root.add_child(lava)
	for kind in [DeathPlane.Kind.LAVA, DeathPlane.Kind.ACID, DeathPlane.Kind.WATER]:
		var plane := DeathPlane.new()
		plane.kind = kind
		plane.width = 340.0
		plane.height = 120.0
		plane.position = Vector2(180.0 + float(kind % 3) * 400.0 if kind != DeathPlane.Kind.LAVA else 180.0, 560.0)
		if kind == DeathPlane.Kind.ACID:
			plane.position = Vector2(620.0, 560.0)
		elif kind == DeathPlane.Kind.WATER:
			plane.position = Vector2(1020.0, 560.0)
		root.add_child(plane)
	for i in 120:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	root.get_texture().get_image().save_png(out + "/pools.png")
	print("[pools] saved")
	quit(0)
