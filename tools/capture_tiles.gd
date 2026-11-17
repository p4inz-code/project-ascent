extends SceneTree
## Renders every patterned special tile side by side for eyeballing.
## Run WITHOUT --headless: Godot --path . --script res://tools/capture_tiles.gd -- <out_dir>


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://tiles"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.12)
	bg.size = Vector2(1200, 700)
	root.add_child(bg)
	var y := 60.0
	for kind in TileDecor.KINDS:
		var base := Polygon2D.new()
		base.polygon = PackedVector2Array([Vector2(-160, -24), Vector2(160, -24), Vector2(160, 24), Vector2(-160, 24)])
		base.color = Color(0.25, 0.27, 0.36)
		base.position = Vector2(220, y)
		root.add_child(base)
		var d := TileDecor.new()
		d.kind = kind
		d.size = Vector2(320, 48)
		base.add_child(d)
		var l := Label.new()
		l.text = kind
		l.position = Vector2(420, y - 10)
		root.add_child(l)
		y += 90.0
	for i in 30:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	root.get_texture().get_image().save_png(out + "/tiles.png")
	print("[tiles] saved")
	quit(0)
