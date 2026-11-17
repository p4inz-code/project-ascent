extends SceneTree
## Per-act music flavour: every act has a pitch inside a listenable range, neighbouring acts differ, and a
## real level applies its act's pitch to the music player.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	_check("eight acts have a flavour", GameAudio.ACT_FLAVOR.size() == 8)
	var in_range := true
	for f in GameAudio.ACT_FLAVOR:
		if float(f["pitch"]) < 0.85 or float(f["pitch"]) > 1.10:
			in_range = false
	_check("every pitch is within 0.85-1.10 (nothing chipmunk or sludge)", in_range)
	var differ := true
	for i in range(1, 8):
		if is_equal_approx(float(GameAudio.ACT_FLAVOR[i]["pitch"]), float(GameAudio.ACT_FLAVOR[i - 1]["pitch"])):
			differ = false
	_check("neighbouring acts sound different (except the identical cinder and forge, which are not neighbours)", differ)
	_check("levels map to acts: 1-5 cinder, 26-30 underworks, 40 core, 99 stays on the last act", GameAudio.flavor_for(3)["name"] == "cinder" and GameAudio.flavor_for(28)["name"] == "underworks" and GameAudio.flavor_for(40)["name"] == "core" and GameAudio.flavor_for(99)["name"] == "core")
	await physics_frame
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 28)
	root.add_child(main)
	for i in 5:
		await physics_frame
	var audio: Node = null
	for n in main.get_children():
		if n is GameAudio:
			audio = n
	var pitch: float = audio._music_player.pitch_scale if audio != null else -1.0
	_check("a level in act VI plays the underworks pitch (%.2f)" % pitch, audio != null and is_equal_approx(pitch, 0.90))
	main.queue_free()
	print("[test_music_flavor] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
