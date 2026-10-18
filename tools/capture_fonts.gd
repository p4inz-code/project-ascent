extends SceneTree
## Renders a sample line in every interface font. Run without --headless:
##   Godot --path . --script res://tools/capture_fonts.gd -- <out_dir>


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://fonts"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.09)
	bg.size = Vector2(1200, 700)
	root.add_child(bg)
	var y := 20.0
	for i in UITheme.FONT_NAMES.size():
		var l := Label.new()
		l.add_theme_font_override("font", UITheme.make_font(i))
		l.add_theme_font_size_override("font_size", 30)
		l.text = "%s  JUMP DASH SLIDE  Level 25 - 99/100 cores" % UITheme.FONT_NAMES[i]
		l.position = Vector2(30, y)
		root.add_child(l)
		y += 100.0
	for k in 20:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	root.get_texture().get_image().save_png(out + "/fonts.png")
	print("[fonts] saved")
	quit(0)
