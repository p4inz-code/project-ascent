extends SceneTree
## Capture one gameplay frame per Act, to check the skies actually read as
## different places rather than one place recoloured.
##
## Run WITHOUT --headless (needs a real renderer):
##   Godot --path <project> --script res://tools/capture_acts.gd -- <out_dir> [levels...]

const WINDOW_SIZE := Vector2i(1600, 900)

var _out_dir: String = "user://act_captures"
var _levels: Array = [1, 6, 12, 17, 23]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	if args.size() > 1:
		_levels = []
		for i in range(1, args.size()):
			_levels.append(int(args[i]))
	_run()


func _run() -> void:
	DisplayServer.window_set_size(WINDOW_SIZE)
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var gm := root.get_node_or_null("GameManager")
	var scene: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)

	for lvl in _levels:
		if gm != null:
			gm.current_level = int(lvl)
			gm.level_changed.emit(int(lvl))
		# The level card animates for ~2.4s before the level actually swaps in;
		# capturing earlier would photograph the transition, not the level.
		for _i in 260:
			await process_frame
		await _grab("act_level_%02d" % int(lvl))

	print("[acts] done -> ", _out_dir)
	quit(0)


func _grab(name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("[acts] FAILED to read viewport for ", name)
		return
	var path := "%s/%s.png" % [_out_dir, name]
	img.save_png(path)
	print("[acts] %s -> %s" % [name, path])
