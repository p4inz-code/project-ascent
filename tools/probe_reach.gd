extends SceneTree
## Level solvability probe: for each consecutive platform on the intended route,
## drop the player on the source platform's right edge, run + jump (searching a
## few dash timings), and report whether it can land on the next platform.
## This checks the greybox is actually beatable with the real physics.
## Run: Godot --headless --path <proj> --script res://tools/probe_reach.gd

var _main: Node
var _player: CharacterBody2D

# Route in order; each entry is a Terrain child name.
const ROUTE := ["Ground", "P1", "P2", "P3", "P4", "LaunchPad", "DashPad", "TopLedge"]


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
func _attempt(a: Dictionary, b: Dictionary, use_dash: bool, vy_trigger: float) -> bool:
	# Start a little back from the edge so we hit max speed before takeoff.
	_player.global_position = Vector2(a["right"] - 60.0, a["top"] - 30.0)
	_player.velocity = Vector2.ZERO
	Input.action_release("move_left")
	_tap(KEY_SPACE, false)
	_tap(KEY_J, false)
	await _step(16)
	Input.action_press("move_right", 1.0)
	await _step(10)
	var dashed := false
	_tap(KEY_SPACE, true)
	var landed_on_b := false
	for _i in 130:
		await physics_frame
		if use_dash and not dashed and _player.velocity.y >= vy_trigger:
			_tap(KEY_J, true)
			dashed = true
			await physics_frame
			_tap(KEY_J, false)
		var px := _player.global_position.x
		var feet := _player.global_position.y + 26.0
		if _player.is_on_floor() and px >= b["left"] - 14.0 and px <= b["right"] + 14.0 \
				and absf(feet - b["top"]) < 8.0:
			landed_on_b = true
			break
		# Bail if we've fallen well below the destination (missed).
		if feet > b["top"] + 200.0:
			break
	_tap(KEY_SPACE, false)
	Input.action_release("move_right")
	return landed_on_b
