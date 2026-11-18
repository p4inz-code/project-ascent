extends SceneTree
## The soundtrack: every place has its own track, the files exist and loop, levels map to the right act, a boss
## chase / endless override it, and reloading a level does not restart the music.

const Rules := preload("res://scripts/soundtrack.gd")
var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	_check("thirteen tracks", Rules.ALL_TRACKS.size() == 13)
	var all_there := true
	var all_loop := true
	for t in Rules.ALL_TRACKS:
		var s := load("res://audio/music/%s.ogg" % t) as AudioStream
		if s == null:
			all_there = false
		elif not (s is AudioStreamOggVorbis) or s.get_length() < 10.0:
			all_loop = false
	_check("every track file exists and loads as Ogg", all_there)
	_check("every track is a real length (10 s or more)", all_loop)
	_check("eight act tracks", Rules.ACT_TRACKS.size() == 8)
	_check("levels map to acts: 1-5 cinder, 26-30 underworks, 40 core, 99 stays on the last act",
		Rules.track_for_level(3) == "cinder" and Rules.track_for_level(28) == "underworks"
		and Rules.track_for_level(40) == "core" and Rules.track_for_level(99) == "core" and Rules.track_for_level(0) == "cinder")
	_check("a boss chase and endless override the act", Rules.track_for_level(3, false, true) == "boss"
		and Rules.track_for_level(3, true) == "endless" and Rules.track_for_level(3, true, true) == "boss")
	await physics_frame
	var st: Node = root.get_node_or_null("Soundtrack")
	_check("the Soundtrack autoload exists", st != null)
	if st == null:
		quit(1)
		return
	st.play("title", 0.0)
	_check("title plays", st.is_playing("title"))
	st.play("story", 0.0)
	_check("story replaces it", st.is_playing("story") and not st.is_playing("title"))
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 28)
	root.add_child(main)
	for i in 5:
		await physics_frame
	var audio: Node = null
	for n in main.get_children():
		if n is GameAudio:
			audio = n
	_check("a level in act VI asks for the underworks track", audio != null and audio.level_track() == "underworks")
	_check("and it is the one playing (%s)" % st.current, st.current == "underworks" and st.is_playing("underworks"))
	var before: float = st._players[st._front].get_playback_position()
	st.play("underworks", 1.0)
	_check("asking again for the same track changes nothing (no restart)", st._players[st._front].get_playback_position() >= before)
	audio.on_boss_chase_started()
	_check("a boss chase switches to the boss track", st.current == "boss")
	audio.on_boss_chase_ended()
	_check("and back to the act's track when it ends", st.current == "underworks")
	st.play("nonsense", 0.0)
	_check("an unknown track is ignored", st.current == "underworks")
	st.stop(0.0)
	_check("stop silences it", not st.is_playing())
	main.queue_free()
	print("[test_music_flavor] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
