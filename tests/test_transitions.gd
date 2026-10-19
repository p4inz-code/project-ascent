extends SceneTree
## Between levels: each act has its own cover (airlock, heat flash, frost wipe, warp streak,
## dawn ascent), and the player cannot move from the moment a level is completed until the
## next level's screen is clear. (The old completion only zeroed velocity once, so the player
## could run around under the "LEVEL COMPLETE" banner.)

var _failures: int = 0
var _game: Node
var _gm: Node


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_styles()
	await _fx_draws()
	await _lock_through_transition()
	print("[test_transitions] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


# ── styles ──────────────────────────────────────────────────────────

func _styles() -> void:
	var per_style := {}
	var monotonic := true
	var last := -1
	for lvl in range(1, 26):
		var st: int = TransitionFx.style_for_level(lvl)
		per_style[st] = int(per_style.get(st, 0)) + 1
		monotonic = monotonic and st >= last
		last = st
	_check("five acts give five distinct covers", per_style.size() == 5 and TransitionFx.STYLE_NAMES.size() == 5)
	_check("each act's five levels share one cover, in act order", monotonic and per_style.values().all(func(n): return n == 5))
	_check("level 1 is the airlock and level 25 is the dawn ascent",
		TransitionFx.style_for_level(1) == TransitionFx.Style.AIRLOCK and TransitionFx.style_for_level(25) == TransitionFx.Style.DAWN_ASCENT)


func _fx_draws() -> void:
	for st in 5:
		var fx := TransitionFx.new()
		fx.size = Vector2(1920, 1080)
		root.add_child(fx)
		fx.style = st
		fx.cover = 0.0
		await process_frame
		var hidden_at_zero := not fx.visible
		var drawn_all := true
		for c in [0.25, 0.5, 0.75, 1.0]:
			fx.cover = c
			await process_frame
			await process_frame
			drawn_all = drawn_all and fx.visible and fx.draw_calls > 0
		_check("%s draws at every stage and hides at zero" % TransitionFx.STYLE_NAMES[st], hidden_at_zero and drawn_all)
		fx.queue_free()
	# Negative control: a style that is NOT set up draws nothing at cover 0.
	var idle := TransitionFx.new()
	idle.size = Vector2(1920, 1080)
	root.add_child(idle)
	await process_frame
	_check("negative control: at cover 0 nothing is drawn", idle.draw_calls == 0 and not idle.visible)
	idle.queue_free()


# ── input lock ──────────────────────────────────────────────────────

func _level() -> Node:
	var lv = _game.get_node_or_null("LevelContainer")
	if lv != null and lv.get_child_count() > 0:
		return lv.get_child(lv.get_child_count() - 1)
	return null


func _level_number() -> int:
	var l := _level()
	return int(l.get("level_number")) if l != null else -1


func _lock_through_transition() -> void:
	_gm = root.get_node("GameManager")
	var gs: Node = root.get_node("GameSettings")
	gs.intro_seen = true
	gs.tutorial_done = true
	_gm.end_tutorial()
	_gm.current_level = 1
	_game = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	_game.set("completion_banner_time", 1.5)
	_game.set("fade_out_time", 0.15)
	_game.set("level_card_hold", 0.5)
	_game.set("fade_in_time", 0.3)
	root.add_child(_game)
	for _i in 200:
		await physics_frame
		if _level() != null and _level().get_node_or_null("Player") != null:
			break
	await _step(20)
	var menu: Node = _game.get_node_or_null("StartMenu")
	if menu != null:
		menu.queue_free()
		paused = false
		_gm.is_paused = false
	await _step(10)
	var level := _level()
	var player: Player = level.get_node("Player")

	# Control: before completion the player moves normally.
	var x0 := player.global_position.x
	Input.action_press("move_right", 1.0)
	await _step(25)
	_check("before completion the player moves (control)", player.global_position.x > x0 + 40.0)
	Input.action_release("move_right")
	await _step(10)

	# Complete the level by touching the goal, then try to move.
	level.call("_on_goal_body_entered", player)
	await _step(3)
	_check("completing a level locks the player", player.input_locked)
	var spawn_x := player.global_position.x
	Input.action_press("move_right", 1.0)
	Input.action_press("jump", 1.0)
	Input.action_press("dash", 1.0)
	await _step(36)
	_check("held keys do nothing under the banner (x %.0f -> %.0f)" % [spawn_x, player.global_position.x],
		absf(player.global_position.x - spawn_x) < 2.0 and player.velocity.length() < 1.0)
	_check("the run clock does not start while frozen", not bool(level.get("_clock_running")))

	var loads := [0]
	_game.get_node("LevelContainer").child_entered_tree.connect(func(_n): loads[0] += 1)
	# Wait for the next level, keys still held.
	var saw_new_locked := false
	var moved_while_covered := false
	var new_player: Player = null
	var new_start_x := 0.0
	for _i in 400:
		await physics_frame
		if _level_number() == 2 and _level() != level:
			var np: Player = _level().get_node_or_null("Player")
			if np != null:
				if new_player == null:
					new_player = np
					new_start_x = np.global_position.x
					saw_new_locked = np.input_locked
				elif np.input_locked and absf(np.global_position.x - new_start_x) > 3.0:
					moved_while_covered = true
				if not np.input_locked:
					break
	_check("the next level loads and its player starts frozen", new_player != null and saw_new_locked)
	_check("keys held through the card and fade do not move it", not moved_while_covered)
	_check("it is released once the screen is clear", new_player != null and not new_player.input_locked and not bool(_game.get("_hold_player")))
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("dash")
	# And then it plays normally.
	await _step(10)
	var nx := new_player.global_position.x
	Input.action_press("move_right", 1.0)
	await _step(30)
	_check("the next level is loaded exactly once (%d)" % loads[0], loads[0] == 1)
	_check("after the transition the new level plays normally", new_player.global_position.x > nx + 30.0)
	Input.action_release("move_right")
	_game.queue_free()
	await _step(3)
