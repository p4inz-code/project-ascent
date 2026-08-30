extends SceneTree
## Cross-level physics reachability gate: for LevelData entries, drives the
## REAL player controller across every consecutive platform gap and fails if
## any gap cannot be crossed by walking, a flat jump, a dash-jump, or a
## wall-jump (fired the instant a real player would feel wall contact).
##
## This is the process fix for the root cause behind the repeated level
## rewrites in git history (Level 3 alone was rewritten six times): geometry
## was authored from prose first and checked against the actual movement
## envelope after, sometimes never. tools/probe_reach.gd already does this for
## Level 1 specifically; this suite generalizes it to all levels and turns it
## into a pass/fail gate instead of a manual report.
##
## Existing per-level checks (test_all_routes.gd) only assert structural
## presence (platforms/spawn/goal/kill_depth exist) — they do not check that
## consecutive platforms are actually reachable with the real controller. This
## suite is the missing piece.
##
## Run (all 25 levels):
##   Godot --headless --path <project> --script res://tests/test_all_levels_reachable.gd
## Run a subset while iterating on specific levels:
##   Godot --headless --path <project> --script res://tests/test_all_levels_reachable.gd -- 6 9
## (checks levels 6 through 9 inclusive). Exit code 0 = all reachable, 1 = not.

const TOTAL_LEVELS := 25

var _failures: int = 0
var _main: Node = null
var _player: CharacterBody2D = null
var _completions: int = 0


func _initialize() -> void:
	_run()


func _level_range() -> Array:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0].is_valid_int() and args[1].is_valid_int():
		return [int(args[0]), int(args[1])]
	return [1, TOTAL_LEVELS]


func _run() -> void:
	var range_bounds := _level_range()
	for level_num in range(range_bounds[0], range_bounds[1] + 1):
		await _check_level(level_num)
	print("[test_all_levels_reachable] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check_level(level_num: int) -> void:
	var scene := load("res://scenes/main_scene.tscn") as PackedScene
	_main = scene.instantiate()
	_main.set("level_number", level_num)
	root.add_child(_main)
	await physics_frame
	_player = _main.get_node("Player")
	_completions = 0
	_main.level_completed.connect(func() -> void: _completions += 1)

	var route := _landable_route()
	var level_ok := true
	for i in route.size() - 1:
		var a: Dictionary = route[i]
		var b: Dictionary = route[i + 1]
		if not await _try_gap(a, b):
			level_ok = false
			var gap: float = b["left"] - a["right"]
			var rise: float = a["top"] - b["top"]
			print("[FAIL] L%d %s -> %s: UNREACHABLE (gap=%.0f rise=%.0f)" % [
				level_num, a["name"], b["name"], gap, rise])

	_check("Level %d — every gap reachable (%d platforms)" % [level_num, route.size()], level_ok)

	_main.queue_free()
	await process_frame


## Terrain children in build order (LevelData.platforms order), excluding the
## non-landable boundary wall every level carries.
func _landable_route() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child in _main.get_node("Terrain").get_children():
		var n := String(child.name)
		if n.contains("Wall"):
			continue
		var half: Vector2 = child.size * 0.5
		out.append({
			"name": n,
			"left": child.global_position.x - half.x,
			"right": child.global_position.x + half.x,
			"top": child.global_position.y - half.y,
		})
	return out


## Whether b is reachable from a by walking, a flat jump, a dash-jump, or a
## wall-jump. Tried cheapest-first. Works for descending steps, overlapping
## vertical hops, and rightward gaps alike — no special-cased geometry math,
## just the real controller doing what a player would actually try.
func _try_gap(a: Dictionary, b: Dictionary) -> bool:
	# A meaningful upward step can never be crossed by walking alone — skip
	# straight to "jump" for those. This also matters for stateful hazards
	# like CrumblePlatform: every attempt here reuses the same live platform
	# instance (unlike a real player, who gets a full level reset on death),
	# so burning an attempt we already know must fail eats into a crumble
	# platform's give-way timer and can produce a false "unreachable" that
	# has nothing to do with the actual gap.
	var rise: float = float(a["top"]) - float(b["top"])
	if rise <= 10.0 and await _attempt(a, b, "walk"):
		return true
	if await _attempt(a, b, "jump"):
		return true
	for vy_trigger in [-400.0, -200.0, -30.0, 100.0, 250.0]:
		if await _attempt(a, b, "dash", vy_trigger):
			return true
	return false


## style: "walk" (no jump at all), "jump" (flat jump), or "dash" (jump + dash
## at vy_trigger). All three also fire a wall-jump the instant a real player
## would feel wall contact (player.gd's wall-jump is edge-triggered on a
## fresh jump press, so a single held press would never re-trigger it).
func _attempt(a: Dictionary, b: Dictionary, style: String, vy_trigger: float = 0.0) -> bool:
	_player.global_position = Vector2(a["right"] - 60.0, a["top"] - 30.0)
	_player.velocity = Vector2.ZERO
	_player.reset_state()
	Input.action_release("move_left")
	Input.action_release("jump")
	Input.action_release("dash")
	for _i in 14:
		await physics_frame
	# Steer toward the destination's own x, not blindly right — a corridor step
	# can legitimately require a leftward hop (a small zigzag climb), and a
	# validator that only ever holds right would wrongly call that unreachable.
	var b_center: float = (float(b["left"]) + float(b["right"])) * 0.5
	if b_center >= _player.global_position.x:
		Input.action_press("move_right", 1.0)
	else:
		Input.action_press("move_left", 1.0)
	for _i in 8:
		await physics_frame

	var dashed := false
	var launched := false
	var was_on_wall := false
	var landed_on_b := false
	var goals_before := _completions

	if style != "walk":
		Input.action_press("jump", 1.0)

	for _i in 150:
		await physics_frame
		if _player.velocity.y < -50.0:
			launched = true

		var on_wall: bool = _player.is_on_wall_only()
		if on_wall and not was_on_wall and not _player.is_on_floor():
			Input.action_release("jump")
			await physics_frame
			Input.action_press("jump", 1.0)
		was_on_wall = on_wall

		if style == "dash" and not dashed and launched and _player.velocity.y >= vy_trigger:
			Input.action_press("dash", 1.0)
			dashed = true
			await physics_frame
			Input.action_release("dash")

		if _completions > goals_before:
			landed_on_b = true
			break

		var px: float = _player.global_position.x
		var feet: float = _player.global_position.y + 26.0
		if _player.is_on_floor() and px >= float(b["left"]) - 14.0 \
				and px <= float(b["right"]) + 14.0 and absf(feet - float(b["top"])) < 8.0:
			landed_on_b = true
			break
		if feet > float(b["top"]) + 300.0:
			break
		# Overshot the destination entirely (past it in the direction of travel)
		# without ever touching down on it.
		if _player.is_on_floor() and ((b_center >= a["right"] and px > float(b["right"]) + 40.0) \
				or (b_center < a["right"] and px < float(b["left"]) - 40.0)):
			break

	Input.action_release("jump")
	Input.action_release("move_right")
	Input.action_release("move_left")
	return landed_on_b


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1
