extends SceneTree
## Frames from the coming-soon card. Run WITHOUT --headless.


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://soon"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var c := ComingSoon.new()
	c.skip_animation = true
	root.add_child(c)
	DirAccess.make_dir_recursive_absolute(out)
	for t in [1.5, 7.0, 12.5]:
		c.time = t
		c._apply()
		for k in 4:
			await process_frame
		root.get_texture().get_image().save_png("%s/soon_%d.png" % [out, int(t * 10)])
		print("[soon] saved ", t)
	quit(0)
