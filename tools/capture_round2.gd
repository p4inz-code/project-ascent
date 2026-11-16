extends SceneTree
## Round-2 visual pass through the REAL game scene (HUD, backdrop, transitions and all), for checking fixes
## against the owner's screenshots. Run WITHOUT --headless, with APPDATA redirected:
##   Godot --path . --script res://tools/capture_round2.gd -- <out dir> <shot> <shot> ...
## Shots:
##   card:N          the level card of level N on its closed cover
##   play:N:x:y      level N with the player parked at x,y   (x "start" = the spawn, y ignored)
##   death:N         level N a few frames into the respawn shutter
##   perf:N:x:y      like play, and prints the average frame time over 180 frames
##   endless         the ENDLESS stage card, then the stage at a section boundary
var _game: Node
var _gm: Node
var _out := "user://round2"


func _initialize() -> void:
	_go()


func _save(name: String) -> void:
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(_out + "/" + name + ".png")
	print("saved ", name)


func _level() -> Node:
	return _game.get("_current_level_scene")


func _label() -> Label:
	return _game.get("_transition_label") as Label


## Jump to a level through the real transition; returns once the screen is clear. Saves the card if asked.
func _goto(lv: int, card_name: String = "") -> void:
	_gm.current_level = lv
	_gm.level_changed.emit(lv)
	await _ride_transition(card_name)


func _ride_transition(card_name: String) -> void:
	var saved := card_name == ""
	for _i in 900:
		await process_frame
		if not saved and _label().visible and _label().modulate.a > 0.97:
			saved = true
			await _save(card_name)
		if _i > 20 and _game.get("_transitioning") == false and _game.get("_hold_player") == false:
			break
	for _i in 20:
		await physics_frame


## Store shots: 1920x1080 and no controls overlay (shot "media" switches it on for the rest of the run).
var _media := false


func _park(xs: String, ys: String) -> void:
	if _media:
		var c := _level().get_node_or_null("Hud/Controls") as CanvasItem
		if c != null:
			c.visible = false
	var p: Player = _level().get_node("Player")
	if xs != "start":
		p.set_physics_process(false)
		p.global_position = Vector2(float(xs), float(ys))
	for _i in 60:
		await physics_frame


func _go() -> void:
	await process_frame
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	DirAccess.make_dir_recursive_absolute(_out)
	var gs: Node = root.get_node("GameSettings")
	_gm = root.get_node("GameManager")
	gs.intro_seen = true
	gs.tutorial_done = true
	DisplayServer.window_set_size(Vector2i(1280, 720))
	MachineRuntime.fixed_seed = 4242
	_game = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	for _i in 60:
		await process_frame
	var menu: Node = _game.get_node_or_null("StartMenu")
	if menu != null:
		menu.queue_free()
		paused = false
		_gm.is_paused = false
	for k in range(1, a.size()):
		var parts := String(a[k]).split(":")
		match parts[0]:
			"media":
				_media = true
				DisplayServer.window_set_size(Vector2i(1920, 1080))
				for _i in 10:
					await process_frame
			"card":
				await _goto(int(parts[1]), "card_L%s" % parts[1])
			"play":
				await _goto(int(parts[1]))
				await _park(parts[2], parts[3] if parts.size() > 3 else "0")
				await _save("play_L%s_%s" % [parts[1], parts[2]])
			"death":
				await _goto(int(parts[1]))
				_level().restart_level()
				for _i in 9:
					await process_frame
				await _save("death_L%s" % parts[1])
				for _i in 40:
					await process_frame
				var p: Player = _level().get_node("Player")
				print("after the shutter: player locked=%s cover=%.2f" % [str(p.input_locked), float(_game.get_node("TransitionLayer/TransitionFx").cover)])
			"perf":
				await _goto(int(parts[1]))
				await _park(parts[2], parts[3])
				var t0 := Time.get_ticks_usec()
				for _i in 180:
					await process_frame
				var ms := float(Time.get_ticks_usec() - t0) / 180.0 / 1000.0
				print("PERF level %s at x=%s: %.2f ms per frame (%.0f fps), physics %.2f ms" % [parts[1], parts[2], ms, 1000.0 / maxf(ms, 0.001),
					Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
				await _save("perf_L%s_%s" % [parts[1], parts[2]])
			"endless":
				MachineRuntime.fixed_seed = 0
				_gm.start_endless()
				await _ride_transition("endless_card")
				var machine := _level().get_node_or_null("Machine") as MachineRuntime
				print("endless stage: base slot %d, mix %s, segments %s" % [_gm.current_level, str(_gm.endless_mix), str(machine.spec["recipe"].get("segments", []))])
				var n: int = machine.spec["cells"].size()
				for s in [1, 2, 3]:
					var bx := MachinePieces.START_X + float(n * s / 4) * MachinePieces.CELL_W
					await _park(str(bx), str(MachinePieces.FLOOR_Y - 120.0))
					await _save("endless_boundary_%d" % s)
				_gm.end_endless()
				MachineRuntime.fixed_seed = 4242
	quit(0)
