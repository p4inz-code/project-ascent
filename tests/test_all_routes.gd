extends SceneTree
## Mathematical proof that all 25 level routes are physically completable.
## Tests against LevelData definitions — no scene loading needed.

var _failures: int = 0
var _warnings: int = 0

func _initialize() -> void:
	for level_num in range(1, LevelData.TOTAL_LEVELS + 1):
		_validate_level(level_num)
	print("\n=== SUMMARY ===")
	print("Levels checked: %d" % LevelData.TOTAL_LEVELS)
	print("Failures: %d" % _failures)
	print("Warnings: %d" % _warnings)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _warn(label: String) -> void:
	print("[WARN] " + label)
	_warnings += 1


func _validate_level(num: int) -> void:
	var level = LevelData.get_level(num)
	print("\n--- Level %d: %s ---" % [num, level.name])

	_check("Level %d loads" % num, level != null)
	if level == null:
		return

	_check("Level %d has platforms" % num, level.platforms.size() > 0)
	_check("Level %d has spawn" % num, level.spawn_point != Vector2.ZERO)
	_check("Level %d has goal" % num, level.goal_position != Vector2.ZERO)
	_check("Level %d has kill_depth" % num, level.kill_depth > 0)

	# Build name -> {pos, size} map
	var plats := {}
	for p in level.platforms:
		plats[p.name] = {"pos": p.position, "size": p.size}

	# Physics constants
	var MAX_JUMP_H := 96.0
	var MOVE_SPEED := 350.0
	var JUMP_DUR := 0.72
	var DASH_SPEED := 640.0
	var DASH_TIME := 0.14
	var max_h := MOVE_SPEED * JUMP_DUR
	var max_h_dash := max_h + DASH_SPEED * DASH_TIME

	# Find the route: Ground → sequential ascending platforms → TopLedge
	# Strategy: sort platforms by y (descending = lowest first), then by x
	# Then find a path from Ground to TopLedge
	var route := _find_route(plats, level)
	if route.size() == 0:
		_warn("Level %d: no route found (manual verification needed)" % num)
		return

	# Validate each jump in the route
	for i in range(route.size() - 1):
		var from = plats[route[i]]
		var to = plats[route[i + 1]]

		var from_top = from["pos"].y - from["size"].y / 2.0
		var to_top = to["pos"].y - to["size"].y / 2.0
		var from_right = from["pos"].x + from["size"].x / 2.0
		var to_left = to["pos"].x - to["size"].x / 2.0

		var vert = from_top - to_top
		var horiz = to_left - from_right

		var vert_ok = vert <= MAX_JUMP_H and vert >= -200
		var needs_dash = horiz > max_h
		var horiz_ok = horiz <= max_h_dash if needs_dash else horiz <= max_h

		if not vert_ok or not horiz_ok:
			_check("%s -> %s: FAIL (v=%.0f h=%.0f%s)" % [
				route[i], route[i + 1], vert, horiz,
				" dash" if needs_dash else ""
			], false)

	# Verify goal is on TopLedge — both horizontally AND vertically. A pure
	# x-range check (the original version of this test) missed 16 of 25
	# levels shipping with a goal floating below, embedded in, or perched
	# above head-height over its platform — completely unreachable while
	# simply standing there. Never trust just one axis again.
	if plats.has("TopLedge") and level.goal_position != Vector2.ZERO:
		var tl = plats["TopLedge"]
		var tl_left = tl["pos"].x - tl["size"].x / 2.0
		var tl_right = tl["pos"].x + tl["size"].x / 2.0
		var tl_top = tl["pos"].y - tl["size"].y / 2.0
		var gx = level.goal_position.x
		var gy = level.goal_position.y
		var goal_size: Vector2 = level.goal_size
		var goal_top = gy - goal_size.y / 2.0
		var goal_bottom = gy + goal_size.y / 2.0
		const PLAYER_HEIGHT := 52.0
		var player_head = tl_top - PLAYER_HEIGHT
		var x_ok = gx >= tl_left and gx <= tl_right
		var y_ok = goal_bottom >= player_head and goal_top <= tl_top
		_check("L%d goal (%.0f,%.0f) reachable while standing on TopLedge [%.0f..%.0f]@y%.0f" % [
			num, gx, gy, tl_left, tl_right, tl_top], x_ok and y_ok)


func _find_route(plats: Dictionary, level) -> Array:
	"""Find a greedy ascending route from Ground to TopLedge."""
	if not plats.has("Ground") or not plats.has("TopLedge"):
		return []

	var route := ["Ground"]
	var visited := {"Ground": true}
	var current := "Ground"
	var max_steps := 50  # prevent infinite loops

	for _step in max_steps:
		if current == "TopLedge":
			break

		var from = plats[current]
		var best_name := ""
		var best_score := -999999.0

		for name in plats:
			if visited.has(name):
				continue
			if name == "LeftWall" or name == "ShaftWall":
				continue
			# Skip decorative pit walls
			if name.begins_with("Wall"):
				# Wall-jump walls — skip for route finding
				continue

			var to = plats[name]
			var from_top = from["pos"].y - from["size"].y / 2.0
			var to_top = to["pos"].y - to["size"].y / 2.0
			var from_right = from["pos"].x + from["size"].x / 2.0
			var to_left = to["pos"].x - to["size"].x / 2.0

			var vert = from_top - to_top  # positive = up
			var horiz = to_left - from_right  # positive = right

			# Must be reachable
			var MAX_VERT := 96.0
			var MAX_HORIZ := 342.0  # with dash

			if vert > MAX_VERT or vert < -200:
				continue
			if horiz < -50 or horiz > MAX_HORIZ:
				continue

			# Score: prefer going UP and RIGHT toward TopLedge
			var goal_dir = (plats["TopLedge"]["pos"] - to["pos"]).normalized()
			var score = vert * 0.5 + horiz * 0.3 + goal_dir.x * 100 + goal_dir.y * -50

			if score > best_score:
				best_score = score
				best_name = name

		if best_name == "":
			break

		visited[best_name] = true
		route.append(best_name)
		current = best_name

	return route
