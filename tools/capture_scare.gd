extends SceneTree
## Screenshots of the three harmless scares (cue, then pop). Run without --headless.
##   Godot --path <project> --script res://tools/capture_scare.gd -- <out dir>
var _out := "user://scare"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	_run()
func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(_out)
	for i in 3: await process_frame
	MachineLevel.forced = [15]
	MachineRuntime.fixed_seed = 4321
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 15)
	get_root().add_child(scene)
	for i in 30: await physics_frame
	var p: Player = scene.get_node("Player")
	var sc: ScareDirector = scene.get_node("Scares")
	sc.forced_setting = 0
	p.global_position = Vector2(300, 770)
	for kind in ["vent_face", "roar", "shadow"]:
		sc.rules.since_last = 100.0
		sc.fire("forced", kind)
		for i in 30: await physics_frame
		await process_frame
		get_root().get_texture().get_image().save_png(_out + "/" + kind + ".png")
		print("[scare] ", kind)
		for i in 60: await physics_frame
	quit(0)
