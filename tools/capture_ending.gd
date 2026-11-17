extends SceneTree
## Frames of the 100-core ending. Run WITHOUT --headless.


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://ending"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var e := EndingScreen.new()
	e.total = 100
	e.skip_animation = true
	root.add_child(e)
	await process_frame
	e._options_shown = false
	e._choices.visible = false
	DirAccess.make_dir_recursive_absolute(out)
	for t in [7.5, 8.6, 11.0]:
		e._time = t
		e._step_cinematic()
		e._refresh()
		for k in 8:
			await process_frame
		root.get_texture().get_image().save_png("%s/end_%d.png" % [out, int(t * 10)])
		print("[ending] saved ", t)
	quit(0)
