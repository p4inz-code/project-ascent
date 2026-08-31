extends SceneTree
## Probe: do the FX settings do anything through the REAL paths a player uses —
## dying, and dragging a slider mid-level — rather than a test poking internals?
##
## Deliberately drives each setting from a known state to its opposite and back,
## because an earlier version of this probe reported glow as DEAD when the value
## was simply already at the target (left there by its own previous run), and
## looked up the parallax container by a node name that never existed.

var _out: Array[String] = []


func _initialize() -> void:
	_run()


func _say(s: String) -> void:
	print("[fx] " + s)


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _await_player(scene: Node) -> Node:
	for _i in 240:
		await physics_frame
		var p := scene.find_child("Player", true, false)
		if p != null and p.get_node_or_null("Body") != null:
			await physics_frame
			await physics_frame
			return p
	return null


func _run() -> void:
	await physics_frame
	await physics_frame
	var gs := root.get_node_or_null("GameSettings")

	# Start from a known-on state so every check below measures a real change.
	gs.screen_shake = true
	gs.shake_intensity = 1.0
	gs.bg_motion = true
	gs.parallax_intensity = 1.0
	gs.glow_intensity = 1.0
	gs.save_settings()
	await _step(10)

	var scene: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := await _await_player(scene)
	if player == null:
		_say("FAIL: no player")
		quit(1)
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	var main := player.get_parent()

	# ── 1. Death shake, via the real respawn path ───────────────────
	var peak := 0.0
	if main.has_method("_respawn"):
		main._respawn(0)  # RespawnCause.FALL
		for _i in 30:
			await physics_frame
			peak = maxf(peak, cam.offset.length())
	_say("death shake peak = %.1f px -> %s" % [peak, "WORKS" if peak > 0.5 else "DEAD"])

	# ── 2. Parallax depth, on the real Parallax2D layers ────────────
	var backdrop := scene.find_child("Backdrop", true, false)
	var layer := backdrop.get_node_or_null("MidRidge") as Parallax2D if backdrop != null else null
	if layer != null:
		var before: Vector2 = layer.scroll_scale
		gs.parallax_intensity = 0.0
		gs.save_settings()
		await _step(20)
		var after: Vector2 = layer.scroll_scale
		_say("parallax scroll_scale %s -> %s : %s" % [before, after,
			"WORKS" if before != after else "DEAD"])
		gs.parallax_intensity = 1.0
		gs.save_settings()
		await _step(10)
	else:
		_say("FAIL: no MidRidge Parallax2D layer found")

	# ── 3. bg_motion toggle, dead since it shipped ──────────────────
	if layer != null:
		var before2: Vector2 = layer.scroll_scale
		gs.bg_motion = false
		gs.save_settings()
		await _step(20)
		_say("bg_motion off: scroll_scale %s -> %s : %s" % [before2, layer.scroll_scale,
			"WORKS" if before2 != layer.scroll_scale else "DEAD"])
		gs.bg_motion = true
		gs.save_settings()
		await _step(10)

	# ── 4. Glow intensity, live ─────────────────────────────────────
	var terrain := scene.find_child("Terrain", true, false)
	var plat: Node = null
	if terrain != null:
		for c in terrain.get_children():
			if "edge_color" in c:
				plat = c
				break
	if plat != null:
		var before3: Color = plat.edge_color
		gs.glow_intensity = 0.0
		gs.save_settings()
		await _step(20)
		_say("glow edge_color %s -> %s : %s" % [before3, plat.edge_color,
			"WORKS" if before3 != plat.edge_color else "DEAD"])
		gs.glow_intensity = 1.0
		gs.save_settings()
		await _step(10)
	else:
		_say("FAIL: no platform with edge_color")

	_say("settings_changed listeners = %d" % gs.get_signal_connection_list("settings_changed").size())
	quit(0)
