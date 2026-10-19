extends SceneTree
## Windowed: captures each act's between-level cover mid-transition and the level card, so the
## five looks can be checked by eye. Output: .cap/trans/. Run with APPDATA redirected.
var _game: Node
func _initialize() -> void:
	_go()
func _go() -> void:
	await process_frame
	var gs: Node = root.get_node("GameSettings")
	var gm: Node = root.get_node("GameManager")
	gs.intro_seen = true
	gs.tutorial_done = true
	_game = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	_game.set("fade_out_time", 0.9)
	_game.set("level_card_hold", 1.2)
	root.add_child(_game)
	for _i in 60: await process_frame
	var menu: Node = _game.get_node_or_null("StartMenu")
	if menu != null:
		menu.queue_free()
		paused = false
		gm.is_paused = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.cap/trans"))
	var fx: TransitionFx = _game.get_node("TransitionLayer/TransitionFx")
	var n := 0
	for lvl in [2, 7, 12, 17, 22]:
		n += 1
		gm.current_level = lvl
		gm.level_changed.emit(lvl)
		var got := false
		for _i in 400:
			await process_frame
			if not got and fx.cover >= 0.55:
				got = true
				_save("%d_cover_%s" % [n, TransitionFx.STYLE_NAMES[fx.style]])
			if got and _game.get("_transitioning") == true and _game.get_node("TransitionLayer").get_child(2).visible and (_game.get_node("TransitionLayer").get_child(2) as Label).modulate.a > 0.95:
				_save("%d_card" % n)
				break
		for _i in 240:
			await process_frame
			if _game.get("_transitioning") == false:
				break
		print("level %d: style %s, locked after=%s" % [lvl, TransitionFx.STYLE_NAMES[fx.style], str(_game.get("_hold_player"))])
	quit(0)
func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.cap/trans/%s.png" % name))
	print("saved ", name)
