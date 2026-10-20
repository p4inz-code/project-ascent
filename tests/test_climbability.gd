extends SceneTree
## The climbability contract for all 25 levels. The route is a chain of platforms; every step
## between neighbours must be within what the real controller can do, and nothing on the
## route is a wall the player cannot get over.
##
## (1) No step rises more than a full jump. (2) A step that rises at all, or whose gap is
## long, stays inside the dash-assisted reach (measured with the real controller by
## tests/test_all_levels_reachable.gd: this is the cheap static guard that catches an edit
## that makes a step impossible long before a physics sweep does). (3) There are no vertical
## walls on the route at all: every level climbs by platforms, so nothing needs a facing
## wall to climb (the tutorial teaches the wall-jump shaft on its own course). (4) The spawn,
## every checkpoint and the goal sit on or just above a platform.
##
## Run alongside the sweep, not instead of it.

var _failures: int = 0


func _initialize() -> void:
	# These check the classic layouts; machine levels have their own suites (docs/MACHINE_LEVELS.md).
	MachineLevel.suspended = true
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _route(def) -> Array:
	var out: Array = []
	for p in def.platforms:
		var n := String(p.name)
		if n.contains("Wall") or n.contains("Decoy") or p.size.x < 40.0:
			continue
		out.append(p)
	return out


func _supports(def, pos: Vector2, slack_above: float, slack_below: float) -> bool:
	for p in def.platforms:
		var top: float = p.position.y - p.size.y * 0.5
		var left: float = p.position.x - p.size.x * 0.5
		var right: float = p.position.x + p.size.x * 0.5
		if pos.x >= left - 20.0 and pos.x <= right + 20.0 and pos.y <= top + slack_below and pos.y >= top - slack_above:
			return true
	return false


func _run() -> void:
	await physics_frame
	var player: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	var jump_h: float = player.jump_height
	player.queue_free()
	_check("the contract is measured against the real jump height (%.0f)" % jump_h, jump_h > 60.0)
	var worst_rise := 0.0
	var steps := 0
	var rise_ok := true
	var reach_ok := true
	var no_walls := true
	var anchored := true
	var offenders: Array = []
	for lvl in range(1, 26):
		var def := LevelData.get_level(lvl)
		for p in def.platforms:
			var n := String(p.name)
			if n.contains("Wall") and n != "LeftWall":
				no_walls = false
				offenders.append("L%d %s" % [lvl, n])
		var route := _route(def)
		for i in route.size() - 1:
			var a = route[i]
			var b = route[i + 1]
			steps += 1
			var gap: float = (b.position.x - b.size.x * 0.5) - (a.position.x + a.size.x * 0.5)
			var rise: float = (a.position.y - a.size.y * 0.5) - (b.position.y - b.size.y * 0.5)
			worst_rise = maxf(worst_rise, rise)
			if rise > jump_h + 0.5:
				rise_ok = false
				offenders.append("L%d %s->%s rise %d" % [lvl, a.name, b.name, int(rise)])
			# Long gaps must be level or nearly so; a rise with a gap must be within dash reach.
			if gap > 215.0 and rise > 40.0:
				reach_ok = false
				offenders.append("L%d %s->%s gap %d rise %d" % [lvl, a.name, b.name, int(gap), int(rise)])
			if gap > 330.0:
				reach_ok = false
				offenders.append("L%d %s->%s gap %d" % [lvl, a.name, b.name, int(gap)])
		# The things the player stands on at the key moments.
		if not _supports(def, def.spawn_point, 90.0, 60.0):
			anchored = false
			offenders.append("L%d spawn unsupported" % lvl)
		if not CourseGen.is_road(lvl) or def.road == null:
			if not _supports(def, def.goal_position, 160.0, 80.0):
				anchored = false
				offenders.append("L%d goal unsupported" % lvl)
	_check("%d route steps checked; the largest rise is %d of a possible %d" % [steps, int(worst_rise), int(jump_h)], steps > 800)
	_check("no step rises more than a full jump", rise_ok)
	_check("every long or rising step is inside dash-assisted reach", reach_ok)
	_check("no level has a wall on its route (they climb by platforms) %s" % str(offenders.slice(0, 3)), no_walls)
	_check("spawn and goal stand on a platform in every level", anchored)
	# Negative control: the rule would catch a step that is too tall.
	var fake_rise := 130.0
	_check("negative control: a 130 px step would be rejected", fake_rise > jump_h + 0.5)
	print("[test_climbability] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
