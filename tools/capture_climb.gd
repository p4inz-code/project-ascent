extends SceneTree
## Screenshot a level at several heights, to catch layer drift that only shows
## up after a long ascent.
const WINDOW_SIZE := Vector2i(1280, 720)
var _out := "user://climb"
var _level := 11
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	if a.size() > 1: _level = int(a[1])
	_run()
func _run() -> void:
	DisplayServer.window_set_size(WINDOW_SIZE)
	for i in 3: await process_frame
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", _level)
	get_root().add_child(scene)
	for i in 20: await process_frame
	var p = scene.get_node_or_null("Player")
	if p == null: quit(1)
	p.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(_out)
	var lv := LevelData.get_level(_level)
	var top := 0.0
	for pl in lv.platforms:
		top = minf(top, pl.position.y)
	var start: Vector2 = lv.spawn_point
	for i in 3:
		var t := float(i) / 2.0
		p.global_position = Vector2(start.x + 900.0 * t, lerpf(start.y, top + 100.0, t))
		for j in 25: await process_frame
		get_root().get_texture().get_image().save_png("%s/climb_%d.png" % [_out, i])
	print("[climb] saved")
	quit(0)
