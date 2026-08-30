extends SceneTree
## Plays all 25 levels back-to-back in a REAL window (run this WITHOUT
## --headless so it's visible/recordable), using the same technique already
## proven correct gap-by-gap in tests/test_all_levels_reachable.gd: hold
## right, jump near the edge, dash when the upcoming gap needs it, and
## re-press jump the instant a wall is touched (player.gd's wall-jump is
## edge-triggered, so a held press never re-fires it on its own).
##
## The difference from that test suite is continuity: instead of teleporting
## to each gap in isolation, this drives one continuous run per level from
## spawn to goal, the way a real player would, then advances to the next
## level on `level_completed`.
##
## Run (note: NO --headless):
##   Godot --path <project> --script res://tools/autopilot_full_game.gd
## Optional: -- <start_level> <end_level>  (defaults to 1 25)

const TOTAL_LEVELS := 25
const FLAT_REACH := 190.0
const MAX_FRAMES_PER_LEVEL := 1800  # ~30s at 60fps; a stuck level gets skipped, not hung forever

var _main: Node = null
var _player: CharacterBody2D = null
var _completions: int = 0
var _route: Array = []


func _initialize() -> void:
	_run()


func _level_range() -> Array:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0].is_valid_int() and args[1].is_valid_int():
		return [int(args[0]), int(args[1])]
	return [1, TOTAL_LEVELS]


func _run() -> void:
	var bounds := _level_range()
	for level_num in range(bounds[0], bounds[1] + 1):
		print("\n=== LEVEL %d ===" % level_num)
		await _play_level(level_num)
	print("\nAll requested levels finished.")
	quit(0)


func _play_level(level_num: int) -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await process_frame

	var scene := load("res://scenes/main_scene.tscn") as PackedScene
	_main = scene.instantiate()
	_main.set("level_number", level_num)
	root.add_child(_main)
	await physics_frame
	_player = _main.get_node("Player")
	_completions = 0
	_main.level_completed.connect(func() -> void: _completions += 1)

	_route = _landable_route()
	if _route.size() < 2:
		print("  (no landable route found, skipping)")
		return

	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("move_left")
	Input.action_press("move_right", 1.0)

	var idx := 0
	var furthest := 0
	var dashed_this_flight := false
	var was_on_wall := false
	var frames := 0

	while frames < MAX_FRAMES_PER_LEVEL:
		await physics_frame
		frames += 1
		if _completions > 0:
			print("  complete in %d frames" % frames)
			break

		var feet: float = _player.global_position.y + 26.0
		var px: float = _player.global_position.x

		# Wall-jump on fresh contact, same edge-trigger logic the validator uses.
		var on_wall: bool = _player.is_on_wall_only()
		if on_wall and not was_on_wall and not _player.is_on_floor():
			Input.action_release("jump")
			await physics_frame
			Input.action_press("jump", 1.0)
			frames += 1
		was_on_wall = on_wall

		if _player.is_on_floor():
			dashed_this_flight = false
			for r in range(furthest, _route.size()):
				var p: Dictionary = _route[r]
				if absf(feet - float(p["top"])) < 10.0 and px >= float(p["left"]) - 20.0 \
						and px <= float(p["right"]) + 20.0:
					idx = r
					furthest = r
					break

		if idx >= _route.size() - 1:
			continue

		var src: Dictionary = _route[idx]
		var dst: Dictionary = _route[idx + 1]
		var gap: float = float(dst["left"]) - float(src["right"])
		var takeoff: float = float(src["right"]) - 24.0
		if gap <= 0.0:
			takeoff = float(dst["left"]) - 70.0

		if _player.is_on_floor():
			if px >= takeoff:
				Input.action_press("jump", 1.0)
			else:
				Input.action_release("jump")
		elif gap > FLAT_REACH and not dashed_this_flight and _player.velocity.y >= -30.0:
			Input.action_press("dash", 1.0)
			dashed_this_flight = true
			await physics_frame
			frames += 1
			Input.action_release("dash")

	if frames >= MAX_FRAMES_PER_LEVEL:
		print("  did not finish within %d frames, moving on" % MAX_FRAMES_PER_LEVEL)

	Input.action_release("jump")
	Input.action_release("move_right")


## Same extraction the reachability suite uses: Terrain children in build
## order, minus the non-landable boundary wall every level carries.
func _landable_route() -> Array:
	var out: Array = []
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
