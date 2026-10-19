extends SceneTree
## Windowed: saves a frame of the opening cutscene every `step` seconds of film time.
##   Godot --path . --script res://tools/capture_story.gd -- <out_dir> [step_seconds]
func _initialize() -> void:
	_go()
func _go() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://story"
	var step := float(a[1]) if a.size() > 1 else 1.5
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var cs := Cutscene.new()
	cs.scene_changed.connect(func(i): print("scene ", i + 1))
	root.add_child(cs)
	var next := 0.0
	var n := 0
	while is_instance_valid(cs) and cs.elapsed() < 45.0:
		await process_frame
		if not is_instance_valid(cs):
			break
		if cs.elapsed() >= next:
			root.get_texture().get_image().save_png("%s/f%02d_t%04.1f_s%d.png" % [out, n, cs.elapsed(), cs.scene_index() + 1])
			n += 1
			next += step
	print("[story] frames=%d" % n)
	quit()
