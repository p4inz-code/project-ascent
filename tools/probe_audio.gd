extends "res://tests/test_level.gd"
## Real-window audio probe: drives real input through the actual level and checks
## that every audio event fires and every bus/volume behaves. This is the closest
## a non-listening harness can get to the "actually play it and hear each SFX"
## playtest step, and it also catches wiring regressions (a signal never emitted,
## a stream never routed to its bus) that screenshots cannot.
##
## Needs a real window (the headless audio driver plays nothing). Run with:
##   Godot --path <project> --script res://tools/probe_audio.gd

func _suite_name() -> String:
	return "probe_audio"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_check("running with a real display server (drop --headless)", false)
		return

	var audio := _main.get_node("Audio")
	_check("main scene has an Audio node", audio != null)
	if audio == null:
		return

	_check_buses(audio)
	await _check_autoplay_gate(audio)
	await _check_jump_and_land(audio)
	await _check_dash(audio)
	await _check_wall(audio)
	await _check_restart(audio)
	await _check_death(audio)
	await _check_goal(audio)
	_check_volume_keys(audio)
	_check_ui_blip(audio)
	await _step_frames(3)


func _check_buses(audio: Node) -> void:
	var master := AudioServer.get_bus_index("Master")
	var music := AudioServer.get_bus_index("Music")
	var sfx := AudioServer.get_bus_index("SFX")
	_check("Master bus exists (%d)" % master, master >= 0)
	_check("Music bus exists (%d)" % music, music >= 0)
	_check("SFX bus exists (%d)" % sfx, sfx >= 0)
	if music >= 0 and sfx >= 0:
		var md: float = AudioServer.get_bus_volume_db(music)
		var sd: float = AudioServer.get_bus_volume_db(sfx)
		_check("default music volume is quieter than sfx (%.1f < %.1f)" % [md, sd], md < sd)
		_check("default volumes applied (music %.1f, sfx %.1f)" % [md, sd],
			is_equal_approx(md, audio.music_volume_db)
				and is_equal_approx(sd, audio.sfx_volume_db))


func _music_playing(audio: Node) -> bool:
	var mp: AudioStreamPlayer = audio.get("_music_player")
	return mp != null and mp.playing


func _reset_player() -> void:
	_player.global_position = _main._spawn_point
	_player.reset_state()
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("restart")
	Input.action_release("toggle_help")


func _step_frames(n: int) -> void:
	for _i in n:
		await physics_frame


## True if any pooled one-shot player is currently playing the named stream.
func _did_play(audio: Node, id: String) -> bool:
	var want: AudioStream = audio.get("_streams")[id]
	for p in audio.get("_sfx_pool"):
		if p.playing and p.stream == want:
			return true
	return false


func _check_autoplay_gate(audio: Node) -> void:
	_reset_player()
	await _step_frames(15)
	_check("music does NOT start before any input (autoplay-safe)", not _music_playing(audio))
	# First real input unlocks the music (the browser-activation-safe moment).
	Input.action_press("move_right", 1.0)
	await _step_frames(8)
	_check("music starts on first input", _music_playing(audio))
	Input.action_release("move_right")
	await _step_frames(2)


func _check_jump_and_land(audio: Node) -> void:
	_reset_player()
	await _step_frames(10)
	# A jump while grounded should fire the jump SFX.
	Input.action_press("jump", 1.0)
	await _step_frames(2)
	Input.action_release("jump")
	await _step_frames(1)
	_check("jump fires the jump SFX", _did_play(audio, "jump"))
	# Let the jump arc land (it will be a while; wait for a landing).
	var landed := false
	for _i in 90:
		await physics_frame
		if _player.is_on_floor():
			landed = true
			break
	_check("player landed after the test jump (%s)" % ("yes" if landed else "no"), landed)
	await _step_frames(1)
	_check("landing fires the landing SFX", _did_play(audio, "land"))


func _check_dash(audio: Node) -> void:
	_reset_player()
	await _step_frames(10)
	Input.action_press("dash", 1.0)
	await _step_frames(2)
	Input.action_release("dash")
	await _step_frames(1)
	_check("dash fires the dash SFX", _did_play(audio, "dash"))


func _check_wall(audio: Node) -> void:
	# Find a wall dynamically (same approach as test_movement.gd).
	var wall_left := -INF
	var wall_top := 0.0
	var found_wall := false
	for child in _main.get_node("Terrain").get_children():
		if child is GreyboxPlatform and child.edge_thickness == 0.0 and child.size.x < 60.0:
			var left: float = child.global_position.x - child.size.x * 0.5
			if not found_wall or left > wall_left:
				wall_left = left
				wall_top = child.global_position.y
				found_wall = true
	if not found_wall and _main.has_node("Terrain/ShaftWall"):
		var w: Node2D = _main.get_node("Terrain/ShaftWall")
		wall_left = w.global_position.x - w.size.x * 0.5
		wall_top = w.global_position.y
		found_wall = true
	if not found_wall:
		wall_left = 3900.0
		wall_top = 480.0
	# Put the player airborne, just beside the wall, falling
	# and pressing into the wall so the slide engages quickly.
	_player.global_position = Vector2(wall_left - 20.0, wall_top - 10.0)
	_player.velocity = Vector2(0, 240)
	_player.reset_state()
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_press("move_right", 1.0)
	var sliding := false
	for _i in 45:
		await physics_frame
		var wv: Variant = audio.get("_wall_player")
		if wv != null and wv.playing:
			sliding = true
			break
	_check("wall slide starts the sliding loop (%s)" % (
		"yes" if sliding else "no"), sliding)
	# Hold the slide past the length of the one-shot (0.6 s) so the loop re-arms:
	# the `finished` handler must restart the hiss or `playing` would go false.
	await _step_frames(45)
	var sustained: bool = audio.get("_wall_player") != null \
		and audio.get("_wall_player").playing
	_check("wall slide hiss sustains past the one-shot (loops) (%s)" % (
		"yes" if sustained else "no"), sustained)
	# A jump while sliding against the wall is a wall jump.
	Input.action_press("jump", 1.0)
	await _step_frames(2)
	Input.action_release("jump")
	await _step_frames(1)
	_check("wall jump fires the wall-jump SFX", _did_play(audio, "walljump"))
	Input.action_release("move_right")
	_reset_player()
	await _step_frames(6)
	_check("wall slide stops the sliding loop after the player leaves",
		not audio.get("_wall_player").playing)


func _check_restart(audio: Node) -> void:
	_reset_player()
	await _step_frames(8)
	Input.action_press("restart", 1.0)
	await _step_frames(2)
	Input.action_release("restart")
	await _step_frames(1)
	_check("manual restart fires the restart SFX", _did_play(audio, "restart"))


func _check_death(audio: Node) -> void:
	_reset_player()
	_player.global_position.y = _main.kill_depth + 400.0
	await _step_frames(3)
	_check("fall death fires the death SFX", _did_play(audio, "death"))
	await _step_frames(5)


func _check_goal(audio: Node) -> void:
	_reset_player()
	_player.global_position = (_main.get_node("Goal") as Node2D).global_position
	await _step_frames(3)
	_check("goal completion fires the goal SFX", _did_play(audio, "goal"))
	await _step_frames(5)


func _check_volume_keys(audio: Node) -> void:
	var music := AudioServer.get_bus_index("Music")
	var before: float = AudioServer.get_bus_volume_db(music)
	Input.action_press("audio_music_down", 1.0)
	await _step_frames(1)
	Input.action_release("audio_music_down")
	await _step_frames(1)
	var after_down: float = AudioServer.get_bus_volume_db(music)
	Input.action_press("audio_music_up", 1.0)
	await _step_frames(1)
	Input.action_release("audio_music_up")
	await _step_frames(1)
	var after_up: float = AudioServer.get_bus_volume_db(music)
	_check("music volume key lowers then raises the bus (%.1f -> %.1f -> %.1f)"
		% [before, after_down, after_up],
		after_down < before and is_equal_approx(after_up, before))
	# Mute toggle mutes and unmutes the master bus.
	Input.action_press("audio_mute", 1.0)
	await _step_frames(1)
	Input.action_release("audio_mute")
	await _step_frames(1)
	var muted: bool = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	Input.action_press("audio_mute", 1.0)
	await _step_frames(1)
	Input.action_release("audio_mute")
	await _step_frames(1)
	var unmuted: bool = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	_check("mute toggles the master bus off then on (%s -> %s)" % [muted, not unmuted],
		muted and not unmuted)


func _check_ui_blip(audio: Node) -> void:
	_reset_player()
	await _step_frames(4)
	Input.action_press("toggle_help", 1.0)
	await _step_frames(1)
	Input.action_release("toggle_help")
	await _step_frames(1)
	_check("controls toggle fires the UI blip", _did_play(audio, "ui"))

