extends SceneTree
## Presentation sheet: one of every obstacle, side by side at gameplay scale.
##
## Each obstacle is readable in isolation when you go looking for it. What
## matters is whether a player can tell them APART at a glance, mid-run, which
## is only answerable by putting them next to each other.
##
## Run WITHOUT --headless:
##   Godot --path <project> --script res://tools/capture_obstacles.gd -- <out_dir>

const WINDOW_SIZE := Vector2i(1500, 560)
var _out := "user://obstacles"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	_run()


func _label(parent: Node, text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
	parent.add_child(l)


func _run() -> void:
	DisplayServer.window_set_size(WINDOW_SIZE)
	for _i in 3:
		await process_frame

	var world := Node2D.new()
	get_root().add_child(world)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.10)
	bg.size = Vector2(WINDOW_SIZE)
	get_root().add_child(bg)
	get_root().move_child(bg, 0)

	var ui := CanvasLayer.new()
	get_root().add_child(ui)

	var col := 0
	var row_y := [150.0, 380.0]

	var entries: Array = [
		["SOLID", "solid"], ["ICE", "ice"], ["STICKY", "sticky"],
		["CRUMBLE", "crumble"], ["BOUNCE", "bounce"],
		["CONVEYOR", "conveyor"], ["FAKE", "fake"], ["ONE-WAY", "one_way"],
	]
	for e in entries:
		var x := 110.0 + float(col % 4) * 350.0
		var y: float = row_y[col / 4]
		var node: Node2D
		match e[1]:
			"ice", "sticky":
				node = SurfacePlatform.new()
				node.kind = (SurfacePlatform.Kind.ICE if e[1] == "ice"
					else SurfacePlatform.Kind.STICKY)
			"crumble": node = CrumblePlatform.new()
			"bounce": node = BouncePad.new()
			"conveyor": node = ConveyorBelt.new()
			"fake": node = FakePlatform.new()
			"one_way": node = OneWayPlatform.new()
			_: node = (preload("res://scenes/platform.tscn") as PackedScene).instantiate()
		node.size = Vector2(180, 24)
		node.position = Vector2(x, y)
		world.add_child(node)
		_label(ui, String(e[0]), Vector2(x - 90.0, y - 46.0))
		col += 1

	# Hazards get their own row.
	var blade := SpinningBlade.new()
	blade.radius = 62.0
	blade.position = Vector2(1290, 150)
	world.add_child(blade)
	_label(ui, "BLADE", Vector2(1200, 62))

	var lava := Lava.new()
	lava.size = Vector2(180, 60)
	lava.position = Vector2(1290, 380)
	world.add_child(lava)
	_label(ui, "LAVA", Vector2(1200, 334))

	for _i in 45:
		await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	get_root().get_texture().get_image().save_png(_out + "/obstacles.png")
	print("[obstacles] saved")
	quit(0)
