extends SceneTree
## Key art background: the title scene (moon, Spire skyline, Trevor on his ledge) with NO menu, at 1920x1080,
## for the marketing kit (tools/make_itch_assets.py). Run WITHOUT --headless, APPDATA redirected:
##   Godot --path . --script res://tools/capture_keyart.gd -- docs/itch/src
func _initialize() -> void:
	_go()


func _go() -> void:
	var out := "docs/itch/src"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for i in 5:
		await process_frame
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var world := TitleWorld.new()
	layer.add_child(world)
	for i in 90:
		await process_frame
	# the kit draws Trevor itself (one hero per asset, at the asset's own scale): hide him and PIP here
	world.set_process(false)
	world._sprite.visible = false
	world._pip = Vector2(-9999.0, -9999.0)
	world.queue_redraw()
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out + "/keyart_bg.png")
	print("ledge_y ", world.ledge_y())
	print("saved keyart_bg")
	quit(0)
