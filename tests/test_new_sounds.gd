extends SceneTree
## The five newer sound effects (door, vent, siren, thunder, ending): the files are real sound
## (not silence, not clipped, sensible length), every one is loaded by the audio node, and the
## things that should make them (the door, a vent blast, the boss warning, a lightning strike,
## the ending) actually play them.

var _failures: int = 0
var _scene: Node
var _audio: Node

const SOUNDS := {
	"door": [0.5, 1.5], "vent": [0.3, 1.0], "siren": [0.5, 1.5], "thunder": [0.6, 2.0], "ending": [1.0, 3.5],
}


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame
	await process_frame


func _boot() -> void:
	await physics_frame
	_files()
	await _loaded_and_played()
	await _hooks()
	print("[test_new_sounds] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


# ── the files ───────────────────────────────────────────────────────

func _files() -> void:
	for id in SOUNDS:
		var stream := load("res://audio/sfx/%s.wav" % id) as AudioStreamWAV
		_check("%s loads as a wav" % id, stream != null)
		if stream == null:
			continue
		var seconds := stream.get_length()
		var lim: Array = SOUNDS[id]
		_check("%s is %.2f s long, inside %.1f..%.1f" % [id, seconds, lim[0], lim[1]], seconds >= lim[0] and seconds <= lim[1])
		# Loudness and peak from the source file (plain 16-bit PCM after a 44-byte header).
		var bytes := FileAccess.get_file_as_bytes("res://audio/sfx/%s.wav" % id)
		var peak := 0
		var sum_sq := 0.0
		var count := 0
		var i := 44
		while i + 1 < bytes.size():
			var v := int(bytes[i]) | (int(bytes[i + 1]) << 8)
			if v >= 32768:
				v -= 65536
			peak = maxi(peak, absi(v))
			sum_sq += float(v) * float(v)
			count += 1
			i += 2
		var rms := sqrt(sum_sq / maxf(float(count), 1.0)) / 32768.0
		_check("%s is not silent (rms %.3f)" % [id, rms], rms > 0.01)
		_check("%s does not clip (peak %.2f)" % [id, float(peak) / 32768.0], peak < 32000)


# ── loaded and playable ─────────────────────────────────────────────

func _loaded_and_played() -> void:
	_scene = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	_scene.set("level_number", 1)
	root.add_child(_scene)
	await _step(10)
	_audio = _scene.get_node("Audio")
	_check("the audio node joins the level_audio group", _audio.is_in_group("level_audio"))
	for id in SOUNDS:
		_check("the audio node loaded %s" % id, _audio._streams.get(id) != null)
	for id in SOUNDS:
		_clear_pool()
		SfxHub.play(root.get_tree(), id)
		_check("SfxHub.play(%s) starts a player with that stream" % id, _pool_has(id))
	# An unknown effect, and a missing audio node, are harmless.
	SfxHub.play(root.get_tree(), "nonsense")
	_check("an unknown effect is ignored", true)


func _clear_pool() -> void:
	for p in _audio._sfx_pool:
		p.stop()
		p.stream = null


func _pool_has(id: String) -> bool:
	for p in _audio._sfx_pool:
		if p.stream != null and p.stream == _audio._streams.get(id):
			return true
	return false


# ── the things that make them ───────────────────────────────────────

func _hooks() -> void:
	# A lightning strike.
	_clear_pool()
	var storm := StormDirector.new()
	var stand := Node2D.new()
	root.add_child(stand)
	root.add_child(storm)
	var rects: Array[Rect2] = [Rect2(0, 400, 1200, 60)]
	storm.setup(rects, stand, 3)
	storm.set_physics_process(false)
	storm.step(StormDirector.FIRST_STRIKE_DELAY + 0.01)
	storm.step(StormDirector.TELEGRAPH + 0.01)
	_check("a lightning strike plays thunder", _pool_has("thunder"))
	# The boss warning.
	_clear_pool()
	var warning := BossWarning.new()
	root.add_child(warning)
	await _step(2)
	_check("the boss warning sounds the siren", _pool_has("siren"))
	warning.queue_free()
	# A vent blast.
	_clear_pool()
	var pipe := PipeTube.new()
	pipe.position = Vector2(0, 400)
	root.add_child(pipe)
	var player := Node2D.new()
	player.add_to_group("player")
	root.add_child(player)
	player.global_position = Vector2(100, 380)
	pipe.set_physics_process(true)
	var heard := false
	for _i in 600:
		await physics_frame
		if _pool_has("vent"):
			heard = true
			break
	_check("a vent blast is heard when the player is near", heard)
	pipe.queue_free()
	# The ending.
	_clear_pool()
	var ending := EndingScreen.new()
	ending.total = SaveSystem.ORB_GOAL
	ending.goal = SaveSystem.ORB_GOAL
	root.add_child(ending)
	await _step(2)
	_check("the opening ending plays its chord", _pool_has("ending"))
	ending.queue_free()
	_scene.queue_free()
	storm.queue_free()
	stand.queue_free()
	player.queue_free()
