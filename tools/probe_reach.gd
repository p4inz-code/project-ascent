extends SceneTree
## Level solvability probe: for each consecutive platform on the intended route,
## drop the player on the source platform's right edge, run + jump (searching a
## few dash timings), and report whether it can land on the next platform.
## This checks the greybox is actually beatable with the real physics.
## Run: Godot --headless --path <proj> --script res://tools/probe_reach.gd

var _main: Node
var _player: CharacterBody2D
## Bumped whenever the level's goal fires. The goal sits on the last platform, so
## an attempt at the final transition can complete the level in mid-air — which
## respawns the player and would otherwise read as a miss.
var _completions: int = 0

# Route in order; each entry is a Terrain child name.
const ROUTE := ["Ground", "S1_1", "S1_2", "S2_1", "S2_2", "S2_3", "S3_1", "S4_A", "S4_B", "S5_1", "S6_1", "S6_2", "TopLedge"]


func _tap(physical: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = physical
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _step(frames: int) -> void:
	for _i in frames:
		await physics_frame


func _rect(name: String) -> Dictionary:
	var n := _main.get_node("Terrain/" + name)
	var top: float = n.global_position.y - n.size.y * 0.5
	return {
		"left": n.global_position.x - n.size.x * 0.5,
		"right": n.global_position.x + n.size.x * 0.5,
		"top": top,
	}


func _initialize() -> void:
	_run()


func _run() -> void:
	_main = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await physics_frame
	_player = _main.get_node("Player")
	_main.level_completed.connect(func() -> void: _completions += 1)

	for i in ROUTE.size() - 1:
		var a := _rect(ROUTE[i])
		var b := _rect(ROUTE[i + 1])
		var gap: float = b["left"] - a["right"]
		var rise: float = a["top"] - b["top"] # positive = destination is higher
		# The right-run model only fits a clean rightward gap. When the destination
		# overlaps or sits above the source (P atop a wide floor, an overlapping
		# ledge) it's a near-vertical hop instead — reachable iff rise < jump peak.
		if gap <= 0.0:
			var ok := rise > 0.0 and rise < 88.0
			print("[reach] %-9s -> %-9s gap=%4.0f rise=%4.0f  OVERLAP hop  %s" % [
				ROUTE[i], ROUTE[i + 1], gap, rise, "ok" if ok else "*** TOO HIGH ***"])
			continue
		var reached := await _try_gap(a, b)
		var need := "trivial"
		if not reached.flat and reached.dash:
			need = "DASH"
		elif not reached.flat and not reached.dash:
			need = "*** UNREACHABLE ***"
		print("[reach] %-9s -> %-9s gap=%4.0f rise=%4.0f  flat=%s dash=%s  %s" % [
			ROUTE[i], ROUTE[i + 1], gap, rise, reached.flat, reached.dash, need])

	quit(0)


## Returns {flat: bool, dash: bool} — whether the destination is reachable with a
## plain running jump, and with a dash-jump (searched over dash timings).
func _try_gap(a: Dictionary, b: Dictionary) -> Dictionary:
	var flat := await _attempt(a, b, false, 0.0)
	var dash := false
	# Search dash trigger points (by vy threshold) for one that lands it.
	for vy_trigger in [-400.0, -200.0, -30.0, 100.0, 250.0]:
		if await _attempt(a, b, true, vy_trigger):
			dash = true
			break
	return {"flat": flat, "dash": dash}


## Place the player on the source right edge, run right, hold jump, optionally
## dash when vy passes vy_trigger, and check whether it lands on destination b.
##
## Input goes through `Input.action_press` rather than synthetic key events: a
## synthetic `InputEventKey` can register a frame late (or be swallowed) under the
## headless pump, which silently turned "ran off the edge without jumping" into a
## false UNREACHABLE and made the whole report non-deterministic. Action-level
## presses are what the run input already used, and they are reliable. The test
## suites keep using real key events on purpose — they also verify the bindings.
func _attempt(a: Dictionary, b: Dictionary, use_dash: bool, vy_trigger: float) -> bool:
	# Start a little back from the edge so we hit max speed before takeoff.
	_player.global_position = Vector2(a["right"] - 60.0, a["top"] - 30.0)
	_player.velocity = Vector2.ZERO
	_player.reset_state()
	Input.action_release("move_left")
	Input.action_release("jump")
	Input.action_release("dash")
	await _step(16)
	Input.action_press("move_right", 1.0)
	await _step(10)
	var dashed := false
	var launched := false
	var landed_on_b := false
	var goals_before := _completions
	Input.action_press("jump", 1.0)
	for _i in 160:
		await physics_frame
		if _player.velocity.y < -50.0:
			launched = true
		if use_dash and not dashed and launched and _player.velocity.y >= vy_trigger:
			Input.action_press("dash", 1.0)
			dashed = true
			await physics_frame
			Input.action_release("dash")
		# Touching the goal counts as arriving: it sits on the final platform, so a
		# clean final hop trips it before touchdown (and the level then respawns).
		if _completions > goals_before:
			landed_on_b = true
			break
		var px := _player.global_position.x
		var feet := _player.global_position.y + 26.0
		if launched and _player.is_on_floor() and px >= b["left"] - 14.0 \
				and px <= b["right"] + 14.0 and absf(feet - b["top"]) < 8.0:
			landed_on_b = true
			break
		# Bail if we've fallen well below the destination (missed).
		if feet > b["top"] + 200.0:
			break
	Input.action_release("jump")
	Input.action_release("move_right")
	return landed_on_b
