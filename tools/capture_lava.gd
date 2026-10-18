extends SceneTree
## Renders a Lava pool alone on a dark backdrop, for eyeballing the look.
## Run WITHOUT --headless: Godot --path . --script res://tools/capture_lava.gd -- <out_dir>


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://lava"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DisplayServer.window_set_size(Vector2i(1200, 500))
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.12)
	bg.size = Vector2(1200, 500)
	root.add_child(bg)
	var lava := Lava.new()
	lava.size = Vector2(520, 120)
	lava.position = Vector2(500, 300)
	root.add_child(lava)
	var small := Lava.new()
	small.size = Vector2(160, 60)
	small.position = Vector2(1000, 330)
	root.add_child(small)
	for i in 150:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	root.get_texture().get_image().save_png(out + "/lava.png")
	print("[lava] saved")
	quit(0)
