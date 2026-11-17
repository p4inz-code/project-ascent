extends SceneTree
## The way back to the title screen: a corner home icon and the pause menu's
## MAIN MENU both return to the title, leave the run exactly where it was, and
## PLAY resumes it. Escape on the title must not pause or un-pause the game
## underneath.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	await _run()
	print("[test_home] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _cancel() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	return e


func _run() -> void:
	var gs: Node = root.get_node("GameSettings")
	gs.intro_seen = true
	var gm: Node = root.get_node("GameManager")
	var scene: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player: Node2D = null
	for _i in 200:
		await physics_frame
		var lv = scene.get_node_or_null("LevelContainer")
		if lv != null and lv.get_child_count() > 0:
			player = lv.get_child(0).get_node_or_null("Player")
			if player != null:
				break
	_check("the game scene loads a level", player != null)
	await _step(30)

	var home: HomeButton = scene.get_node_or_null("HomeLayer/HomeButton")
	_check("a home icon is on screen", home != null and home.is_visible_in_tree())
	_check("it takes no keyboard focus, so Space and Enter never press it", home.focus_mode == Control.FOCUS_NONE)
	_check("it is in the bottom-right corner",
		home.anchor_left == 1.0 and home.anchor_top == 1.0 and home.offset_right < 0.0)

	var level_before: int = gm.current_level
	var pos_before: Vector2 = player.global_position
	_check("no title screen yet", scene.get_node_or_null("StartMenu") == null)
	home.pressed.emit()
	await _step(4)
	var menu: StartMenu = scene.get_node_or_null("StartMenu")
	_check("the home icon opens the title screen", menu != null)
	_check("the game is paused behind it", paused)
	_check("the run is untouched: same level and position",
		gm.current_level == level_before and player.global_position.distance_to(pos_before) < 1.0)

	home.pressed.emit()
	await _step(2)
	var count := 0
	for c in scene.get_children():
		if c is StartMenu:
			count += 1
	_check("pressing home again never stacks a second title screen", count == 1)

	# Escape on the title must leave the game paused and the pause menu closed.
	gm.pause_menu._input(_cancel())
	await _step(2)
	_check("Escape on the title does not unpause the game", paused)
	_check("and does not open the pause menu under it", not gm.pause_menu.visible)

	menu._on_play()
	await _step(4)
	_check("PLAY dismisses the title", scene.get_node_or_null("StartMenu") == null or scene.get_node("StartMenu").is_queued_for_deletion())
	_check("and resumes the game", not paused)
	_check("on the same level", gm.current_level == level_before)

	# The pause menu has its own way home.
	gm.pause_game()
	await _step(3)
	var has_item := false
	for b in gm.pause_menu._main_buttons:
		if b.text == "MAIN MENU":
			has_item = true
	_check("the pause menu lists MAIN MENU", has_item)
	gm.pause_menu._on_home()
	await _step(4)
	_check("MAIN MENU returns to the title", scene.get_node_or_null("StartMenu") != null)
	_check("and closes the pause menu", not gm.pause_menu.visible)
	_check("the game is still paused behind the title", paused)
	scene.get_node("StartMenu")._on_play()
	await _step(4)
	_check("PLAY from there resumes too", not paused)
	scene.queue_free()
	await _step(2)
