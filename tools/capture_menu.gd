extends SceneTree
## Captures the title screen (and the ABOUT page) from a real renderer.
## Run WITHOUT --headless:
##   Godot --path <project> --script res://tools/capture_menu.gd -- <out_dir>

const WINDOW_SIZE := Vector2i(1600, 900)
var _out := "user://menu"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	_run()


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _grab(name: String) -> void:
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[menu] saved ", name)


func _run() -> void:
	DisplayServer.window_set_size(WINDOW_SIZE)
	await _frames(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var menu := StartMenu.new()
	root.add_child(menu)
	await _frames(40)
	await _grab("title_idle")
	# Point out over the ledge, then click: Trevor walks over and hops, PIP follows.
	var world: TitleWorld = menu._world
	world.set_pointer(Vector2(1250, 560))
	await _frames(90)
	world.click(Vector2(1250, 560))
	await _frames(14)
	await _grab("title_interact")
	menu._on_about()
	await _frames(10)
	await _grab("about_page")
	print("[menu] done")
	quit(0)
