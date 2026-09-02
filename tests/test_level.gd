extends "res://tests/test_base.gd"
## Headless level-integrity tests: the greybox's geometry contract and the one
## question that matters most — can the course actually be finished?
##
## These guard the class of bug that is invisible in a screenshot and invisible to
## per-gap reachability checks: a slab hanging so low over a landing surface that
## the body does not fit (which also silently kills the jump button), a goal left
## behind when its platform moves, a spawn inside geometry, or a level edit that
## quietly makes the route unbeatable.
## Run: Godot --headless --path <project> --script res://tests/test_level.gd
## Exit code 0 = all checks passed, 1 = a check failed.

## Intended route, in order; each entry is a Terrain child name.
## Derived from LevelData at boot rather than hardcoded. The literal list this
## replaced ended at TopLedge and silently skipped every platform added since
## it was written, so the autopilot never even tried to navigate them and the
## level simply "could not be completed". Same rot as a printed control list —
## a lesson hud.gd already learned.
var ROUTE: Array = []


func _build_route() -> void:
	ROUTE.clear()
	for p in LevelData.get_level(1).platforms:
		if not String(p.name).contains("Wall"):
			ROUTE.append(p.name)
## Measured flat running-jump reach (tools/probe_envelope.gd). Wider needs a dash.
const FLAT_REACH := 175.0

var _body := Vector2(28.0, 52.0)


func _suite_name() -> String:
	return "test_level"


func _run() -> void:
	_build_route()
	var shape: RectangleShape2D = _player.get_node("CollisionShape2D").shape
	_body = shape.size
	_check_headroom()
	_check_goal_placement()
	_check_spawn()
	_check_kill_depth()
	_check_intro_gap()
	await _check_completable()


## Axis-aligned world-space bounds of a Terrain child.
func _bounds(n: Node2D) -> Dictionary:
	var half: Vector2 = n.size * 0.5
	return {
		"name": String(n.name),
		"left": n.global_position.x - half.x,
		"right": n.global_position.x + half.x,
		"top": n.global_position.y - half.y,
		"bottom": n.global_position.y + half.y,
	}


func _terrain() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child in _main.get_node("Terrain").get_children():
		out.append(_bounds(child))
	return out


## Every surface the player can land on must have room to stand. A slab hanging
## lower than the body height leaves a strip where the collider intersects the
## ceiling: the player is squeezed and a jump is eaten on its first frame.
func _check_headroom() -> void:
	# Was `worst = ...` (plain overwrite): only the LAST violation found in
	# iteration order ever survived to be reported, silently discarding every
	# earlier one in the same level. A level with five real violations would
	# print exactly one and pass everything else through undetected - found
	# when a broader manual scan turned up 203 candidate violations right
	# after this check had reported only a single failure.
	var found: Array[String] = []
	for surface in _terrain():
		for slab in _terrain():
			if slab["name"] == surface["name"] or slab["bottom"] >= surface["top"]:
				continue
			var lo: float = maxf(surface["left"], slab["left"])
			var hi: float = minf(surface["right"], slab["right"])
			if hi <= lo:
				continue
			var clearance: float = surface["top"] - slab["bottom"]
			if clearance < _body.y:
				found.append("%s under %s x[%.0f..%.0f] clearance=%.0f < body %.0f" % [
					surface["name"], slab["name"], lo, hi, clearance, _body.y])
	for f in found:
		print("[FAIL] headroom violation: %s" % f)
	_check("every landable surface has standing headroom (%d violation(s))" % found.size(),
		found.is_empty())


## The goal must rest on a platform. It is a separate node from the terrain, so
## moving the final ledge without moving the goal leaves an unreachable win
## condition floating in the air — exactly the mistake this catches.
func _check_goal_placement() -> void:
	var goal: Node2D = _main.get_node("Goal")
	var shape: RectangleShape2D = goal.get_node("GoalShape").shape
	var half: Vector2 = shape.size * 0.5
	var bottom: float = goal.global_position.y + half.y
	var left: float = goal.global_position.x - half.x
	var right: float = goal.global_position.x + half.x
	var resting_on := ""
	for p in _terrain():
		if absf(bottom - float(p["top"])) < 8.0 and left >= float(p["left"]) \
				and right <= float(p["right"]):
			resting_on = String(p["name"])
			break
	_check("goal rests on a platform (%s)" % (
		resting_on if not resting_on.is_empty() else "FLOATING"), not resting_on.is_empty())
	# It also has to be tall enough for a standing player to touch it.
	_check("goal is tall enough to touch while standing", shape.size.y >= _body.y * 0.75)


## The spawn must be clear of geometry with ground under it, so a fresh life never
## starts embedded in a wall or falling into the void.
func _check_spawn() -> void:
	var spawn: Vector2 = _main._spawn_point
	var half: Vector2 = _body * 0.5
	var embedded := ""
	var ground_below := false
	for p in _terrain():
		var overlaps_x: bool = spawn.x + half.x > float(p["left"]) \
				and spawn.x - half.x < float(p["right"])
		if overlaps_x and spawn.y + half.y > float(p["top"]) \
				and spawn.y - half.y < float(p["bottom"]):
			embedded = String(p["name"])
		if overlaps_x and float(p["top"]) >= spawn.y + half.y \
				and float(p["top"]) - (spawn.y + half.y) < 200.0:
			ground_below = true
	_check("spawn is not inside terrain (%s)" % (
		"clear" if embedded.is_empty() else embedded), embedded.is_empty())
	_check("spawn has ground beneath it", ground_below)


## The kill plane must sit below the whole level, so it only ever catches a fall
## out of the world — never a platform the player is standing on.
func _check_kill_depth() -> void:
	var lowest := -INF
	for p in _terrain():
		lowest = maxf(lowest, float(p["bottom"]))
	_check("kill depth is below every platform (%.0f > %.0f)" % [_main.kill_depth, lowest],
		_main.kill_depth > lowest)


## The opening platform is intentionally separated from the spawn ground. This
## keeps the first jump in the route instead of allowing a flat-ground bypass.
func _check_intro_gap() -> void:
	var ground := _bounds(_main.get_node("Terrain/Ground"))
	var first_platform := _bounds(_main.get_node("Terrain/S1_1"))
	var gap: float = float(first_platform["left"]) - float(ground["right"])
	_check("intro gap teaches the first jump (%.0f px)" % gap, gap >= 40.0)


## The load-bearing check: drive the real controller from spawn to the goal in one
## continuous run. Per-gap reachability (tools/probe_reach.gd) teleports the player
## to a clean takeoff spot for every jump, so it cannot catch composition failures
## — landing so close to the next edge that no run-up is left, or arriving with the
## dash already spent. The autopilot only holds "run right", jumps near each lip,
## and spends the dash on the one gap too wide to clear flat.
func _check_completable() -> void:
	var goals := [0]
	var _cb := func() -> void: goals[0] += 1
	_main.level_completed.connect(_cb)
	var frames := 0
	# The dash trigger is the one beat a fixed script cannot guess, so try a few
	# points (dash once vertical velocity passes this value) in turn.
	for trigger in [-200.0, -30.0, 100.0, -400.0, 250.0]:
		frames = await _autopilot(trigger, goals)
		if frames > 0:
			break
	_main.level_completed.disconnect(_cb)
	_check("the course can be completed from spawn (%s)" % (
		"%d frames" % frames if frames > 0 else "NEVER FINISHED"), frames > 0)


## One autopilot attempt. Returns the frame count on completion, 0 on failure.
func _autopilot(dash_trigger: float, goals: Array) -> int:
	_player.global_position = _main._spawn_point
	_player.reset_state()
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("move_left")
	var goals_before: int = goals[0]
	await _step(20)
	Input.action_press("move_right", 1.0)

	var idx := 0
	var furthest := 0
	var dashed_this_flight := false
	var frames := 0
	# 5000 frames (~83s). Was 3000 (~50s), which was ample before ground-fill
	# terrain added roughly 5-10 more named segments to every level's route -
	# more platforms to sequentially recognise "which one am I standing on"
	# across, not a harder or longer PLAY (test_full_campaign's autopilot
	# completes every level in far less real time); this budget is simply
	# tracking how many named lips this specific step-by-step strategy walks.
	for _i in 5000:
		await physics_frame
		frames += 1
		if goals[0] > goals_before:
			Input.action_release("jump")
			Input.action_release("move_right")
			return frames

		var feet: float = _player.global_position.y + _body.y * 0.5
		var px: float = _player.global_position.x
		if _player.is_on_floor():
			dashed_this_flight = false
			# Which route platform are we standing on? Never go backwards.
			#
			# Used to break on the FIRST match from `furthest` onward. With many
			# short, flush-touching platforms (ground-fill terrain) the body's
			# half-width tolerance means the player can satisfy the bounds check
			# for TWO adjacent platforms at once near their shared seam - taking
			# the first one repeatedly pinned idx to the platform being LEFT,
			# never advancing to the one actually being stood on, which then
			# fed a stale takeoff point into the jump decision forever. Taking
			# the LAST (furthest forward) match instead always resolves ties in
			# the direction of travel.
			for r in range(furthest, ROUTE.size()):
				var p := _bounds(_main.get_node("Terrain/" + ROUTE[r]))
				if absf(feet - float(p["top"])) < 8.0 \
						and px >= float(p["left"]) - _body.x * 0.5 \
						and px <= float(p["right"]) + _body.x * 0.5:
					idx = r
					furthest = r
		if idx >= ROUTE.size() - 1:
			continue

		var src := _bounds(_main.get_node("Terrain/" + ROUTE[idx]))
		var dst := _bounds(_main.get_node("Terrain/" + ROUTE[idx + 1]))
		var gap: float = float(dst["left"]) - float(src["right"])
		# Where to leave the ground: at the lip of a real gap, or a little before
		# the destination's face when it sits on top of the current surface.
		var takeoff: float = float(src["right"]) - 24.0
		if gap <= 0.0:
			takeoff = float(dst["left"]) - 70.0

		if _player.is_on_floor():
			if px >= takeoff:
				Input.action_press("jump", 1.0)
			else:
				# Only ever release while grounded — releasing mid-rise would trip
				# variable-jump-height damping and cut the arc short.
				Input.action_release("jump")
		elif gap > FLAT_REACH and not dashed_this_flight \
				and _player.velocity.y >= dash_trigger:
			Input.action_press("dash", 1.0)
			dashed_this_flight = true
			await physics_frame
			frames += 1
			Input.action_release("dash")

	Input.action_release("jump")
	Input.action_release("move_right")
	return 0
