extends SceneTree
## Mathematical proof that Level 3 route is physically completable.
## Tests against LevelData definitions directly — no scene loading needed.

var _failures: int = 0

func _initialize() -> void:
	_check_level3_route()
	print("[test_level3_route] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _check_level3_route() -> void:
	var level = LevelData.get_level(3)
	_check("Level 3 loads", level != null)
	if level == null:
		return

	# Build a name -> {pos, size} map
	var plats := {}
	for p in level.platforms:
		plats[p.name] = {"pos": p.position, "size": p.size}

	# Derive the route from LevelData's own order rather than hardcoding it.
	# The hardcoded list ended "S5_2", "TopLedge" — once extension steps were
	# inserted between them it skipped straight over them and reported a
	# phantom 1991px gap. A printed list of level geometry rots the same way a
	# printed control list does, which this project already learned once in
	# hud.gd.
	var route: Array = []
	for p in level.platforms:
		if not String(p.name).contains("Wall"):
			route.append(p.name)

	# Physics constants (from player.gd)
	var MAX_JUMP_HEIGHT := 96.0   # pixels upward
	var JUMP_DURATION := 0.72     # seconds
	var MOVE_SPEED := 350.0       # px/s
	var DASH_SPEED := 640.0       # px/s
	var DASH_TIME := 0.14         # seconds

	var max_horiz := MOVE_SPEED * JUMP_DURATION  # ~252
	var max_horiz_dash := max_horiz + DASH_SPEED * DASH_TIME  # ~342

	for i in range(route.size() - 1):
		var from_name = route[i]
		var to_name = route[i + 1]

		if not plats.has(from_name):
			_check("'%s' exists in LevelData" % from_name, false)
			continue
		_check("'%s' exists" % from_name, true)

		if not plats.has(to_name):
			_check("'%s' exists in LevelData" % to_name, false)
			continue
		_check("'%s' exists" % to_name, true)

		var from = plats[from_name]
		var to = plats[to_name]

		# Top of platform = center_y - height/2
		var from_top = from["pos"].y - from["size"].y / 2.0
		var to_top = to["pos"].y - to["size"].y / 2.0
		# Right edge of from, left edge of to
		var from_right = from["pos"].x + from["size"].x / 2.0
		var to_left = to["pos"].x - to["size"].x / 2.0

		var vert = from_top - to_top  # positive = target is above
		var horiz = to_left - from_right  # positive = target is to the right

		var vert_ok = vert <= MAX_JUMP_HEIGHT and vert >= -200  # allow drops (falling is fine)
		var needs_dash = horiz > max_horiz
		var horiz_ok = horiz <= max_horiz_dash if needs_dash else horiz <= max_horiz

		var label = "%s -> %s: vert=%.0f horiz=%.0f%s" % [
			from_name, to_name, vert, horiz,
			" (needs dash)" if needs_dash else ""
		]
		_check(label, vert_ok and horiz_ok)

	# Verify goal is on TopLedge
	if plats.has("TopLedge"):
		var tl = plats["TopLedge"]
		var goal = level.goal_position
		var tl_left = tl["pos"].x - tl["size"].x / 2.0
		var tl_right = tl["pos"].x + tl["size"].x / 2.0
		_check("Goal (%.0f) on TopLedge [%.0f..%.0f]" % [goal.x, tl_left, tl_right],
			goal.x >= tl_left and goal.x <= tl_right)

	# Summary
	print("\n=== Level 3 Route Summary ===")
	for i in range(route.size() - 1):
		var from = plats.get(route[i], {"pos": Vector2.ZERO, "size": Vector2.ZERO})
		var to = plats.get(route[i + 1], {"pos": Vector2.ZERO, "size": Vector2.ZERO})
		var vert = (from["pos"].y - from["size"].y/2) - (to["pos"].y - to["size"].y/2)
		var horiz = (to["pos"].x - to["size"].x/2) - (from["pos"].x + from["size"].x/2)
		print("  %s -> %s: up=%.0f right=%.0f" % [route[i], route[i+1], vert, horiz])
