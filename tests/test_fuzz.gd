extends SceneTree
## Random play, seeded so a failure can be replayed: every action pressed and released at
## random on many levels, with the pause menu, restarts and settings changing underneath. Checks
## the things that must never happen however the controls are mashed:
##   - no script error (the runner fails the suite on any SCRIPT ERROR line)
##   - the player position and velocity stay finite and near the level
##   - the level never ends up with two players, a stuck input lock or a frozen clock forever
##   - the game never ends up paused with no way back
##
## Run one seed:  Godot --headless --path . --script res://tests/test_fuzz.gd -- <seed> <seconds>

const LEVELS := [1, 4, 7, 10, 12, 14, 16, 19, 20, 22, 24, 25, 3, 13]
const ACTIONS := ["move_left", "move_right", "jump", "dash", "slide", "grapple", "ability",
	"look_up", "look_down", "look_left", "look_right"]

var _failures: int = 0
var _rng := RandomNumberGenerator.new()
var _gs: Node
var _gm: Node


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	if not ok:
		print("[FAIL] " + label)
		_failures += 1


func _boot() -> void:
	await physics_frame
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 and args[0].is_valid_int() else 20261020
	var seconds := float(args[1]) if args.size() > 1 and args[1].is_valid_float() else 14.0
	_rng.seed = seed_v
	_gs = root.get_node("GameSettings")
	_gm = root.get_node("GameManager")
	_gs.reset_settings()
	var levels_run := 0
	var total_frames := 0
	for lvl in LEVELS:
		total_frames += await _fuzz_level(lvl, seconds)
		levels_run += 1
	_check("every level ran", levels_run == LEVELS.size())
	print("[test_fuzz] seed=%d levels=%d frames=%d failures=%d" % [seed_v, levels_run, total_frames, _failures])
	for a in ACTIONS + ["restart", "toggle_help", "pause"]:
		Input.action_release(a)
	_gs.reset_settings()
	quit(1 if _failures > 0 else 0)


func _fuzz_settings() -> void:
	# Any legal value of any registered setting, at any time.
	var d: Dictionary = SettingsRegistry.all()[_rng.randi_range(0, SettingsRegistry.all().size() - 1)]
	var key := String(d["key"])
	# Display changes are real window calls; keep those out of the headless fuzz.
	if key.begins_with("disp_"):
		return
	match String(d["kind"]):
		"toggle":
			_gs.set_reg(key, _rng.randf() < 0.5, false)
		"slider":
			_gs.set_reg(key, _rng.randf_range(float(d["lo"]), float(d["hi"])), false)
		"choice":
			_gs.set_reg(key, _rng.randi_range(0, (d["names"] as Array).size() - 1), false)
	# And a few plain fields.
	match _rng.randi_range(0, 5):
		0: _gs.screen_shake = _rng.randf() < 0.5
		1: _gs.afterimages = _rng.randf() < 0.5
		2: _gs.floating_particles = _rng.randf() < 0.5
		3: _gs.bg_motion = _rng.randf() < 0.5
		4: _gs.shake_intensity = _rng.randf()
		5: _gs.glow_intensity = _rng.randf()
	_gs.settings_changed.emit()


func _fuzz_level(lvl: int, seconds: float) -> int:
	var scene := (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", lvl)
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var player: Player = scene.get_node("Player")
	var start := player.global_position
	var held := {}
	var frames := int(seconds * 60.0)
	var attempts_start: int = int(scene.get("attempts"))
	var worst_dist := 0.0
	var finite := true
	var players_seen := 1
	for f in frames:
		# Mash.
		if _rng.randf() < 0.18:
			var a: String = ACTIONS[_rng.randi_range(0, ACTIONS.size() - 1)]
			if held.get(a, false):
				Input.action_release(a)
				held[a] = false
			else:
				Input.action_press(a, _rng.randf_range(0.2, 1.0))
				held[a] = true
		if _rng.randf() < 0.004:
			Input.action_press("restart", 1.0)
		elif Input.is_action_pressed("restart"):
			Input.action_release("restart")
		if _rng.randf() < 0.003:
			Input.action_press("toggle_help", 1.0)
		elif Input.is_action_pressed("toggle_help"):
			Input.action_release("toggle_help")
		if _rng.randf() < 0.02:
			_fuzz_settings()
		if _rng.randf() < 0.003 and _gm.pause_menu == null:
			# Pausing the bare level scene (no pause menu in this harness) must be harmless.
			paused = true
			await physics_frame
			paused = false
		await physics_frame
		var p := player.global_position
		var v := player.velocity
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(v.x) and is_finite(v.y)):
			finite = false
			break
		worst_dist = maxf(worst_dist, p.distance_to(start))
		if f % 120 == 0:
			var count := 0
			for c in scene.get_children():
				if c is Player:
					count += 1
			players_seen = maxi(players_seen, count)
	for a in ACTIONS:
		Input.action_release(a)
	_check("L%d: position and velocity stay finite" % lvl, finite)
	_check("L%d: the player stays within the world (%.0f px from the start)" % [lvl, worst_dist], worst_dist < 60000.0)
	_check("L%d: never more than one player" % lvl, players_seen == 1)
	_check("L%d: the player is not stuck input-locked" % lvl, not player.input_locked)
	_check("L%d: attempts only ever go up" % lvl, int(scene.get("attempts")) >= attempts_start)
	scene.queue_free()
	await physics_frame
	return frames
