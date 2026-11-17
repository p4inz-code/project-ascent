extends SceneTree
## Contact sheet of the reaction cards. Run WITHOUT --headless: Godot --path <project> --script res://tools/capture_cards.gd -- <out png>
func _initialize() -> void:
	var out := "user://cards.png"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	DisplayServer.window_set_size(Vector2i(900, 260))
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.14)
	bg.size = Vector2(900, 260)
	root.add_child(bg)
	var i := 0
	for k in ReactionCard.ALL_KINDS:
		var c := ReactionCard.new()
		c.kind = k
		c.scale = Vector2(1.6, 1.6)
		c.position = Vector2(20 + (i % 7) * 125, 20 + (i / 7) * 120)
		root.add_child(c)
		var l := Label.new()
		l.text = k
		l.position = c.position + Vector2(0, 80)
		root.add_child(l)
		i += 1
	for f in 6: await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
