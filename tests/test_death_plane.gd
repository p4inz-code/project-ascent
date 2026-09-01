extends SceneTree
## The floor of the world, checked for the two things that can go wrong.
##
## It has one job — end a fall fast — and two ways to fail at it: sitting so
## high that it becomes an accidental wall under the route, or so low that the
## fall it was meant to shorten is just as long as before.
##
## Run with:
##   Godot --headless --path <project> --script res://tests/test_death_plane.gd

var _failures: int = 0
## Must be a MEMBER, not a local. GDScript lambdas capture locals by VALUE, so
## `var caught := false` + `func(): caught = true` sets a copy and the outer
## variable never changes — the signal fires and the test never sees it.
var _caught: bool = false

## The longest a fall may take before hitting the floor. The old behaviour was
## over a second on the taller levels, which is the thing this exists to fix.
const MAX_FALL_SECONDS: float = 0.85


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run()


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _run() -> void:
	# --- Every level builds one, themed to its act ------------------------
	# Includes the ACT BOUNDARIES (5/6, 10/11, 15/16), not just one sample per
	# act - an off-by-one in kind_for_level's <= comparisons (e.g. "<= 5"
	# silently becoming "< 5") would reclassify a boundary level's theme and
	# every mid-act sample would still pass.
	var expected := {1: DeathPlane.Kind.GROUND, 5: DeathPlane.Kind.GROUND,
		6: DeathPlane.Kind.WATER, 10: DeathPlane.Kind.WATER,
		11: DeathPlane.Kind.ICE, 15: DeathPlane.Kind.ICE,
		16: DeathPlane.Kind.LAVA, 25: DeathPlane.Kind.LAVA}
	for lvl in expected:
		_check("L%d maps to the right surface" % lvl,
			DeathPlane.kind_for_level(lvl) == expected[lvl])

	for level_num in [1, 8, 14, 20, 25]:
		var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
		scene.set("level_number", level_num)
		get_root().add_child(scene)
		await _step(8)

		var plane = scene.get_node_or_null("Hazards/DeathPlane")
		if plane == null:
			_check("L%d builds a death plane" % level_num, false)
			scene.queue_free()
			await process_frame
			continue

		# --- It must be BELOW everything, or it is a wall -----------------
		var lvd := LevelData.get_level(level_num)
		var lowest := -INF
		for pdef in lvd.platforms:
			if String(pdef.name).contains("Wall"):
				continue
			lowest = maxf(lowest, pdef.position.y + pdef.size.y * 0.5)
		_check("L%d plane sits below the lowest platform (%.0f > %.0f)"
			% [level_num, plane.position.y, lowest], plane.position.y > lowest)

		# --- And it must be reached QUICKLY, which is the whole point -----
		var player: Player = scene.get_node("Player")
		_caught = false
		plane.player_hit.connect(func() -> void: _caught = true)
		# Drop in OPEN AIR, past the right edge of the level but still inside
		# the plane's span. Dropping at the level's centre just lands on the
		# lowest platform, which measures nothing.
		var rightmost := -INF
		for pdef in lvd.platforms:
			if String(pdef.name).contains("Wall"):
				continue
			rightmost = maxf(rightmost, pdef.position.x + pdef.size.x * 0.5)
		player.global_position = Vector2(rightmost + 400.0, lowest - 40.0)
		player.velocity = Vector2.ZERO
		await _step(2)
		var frames := 0
		while not _caught and frames < 240:
			await physics_frame
			frames += 1
		var seconds := float(frames) / 60.0
		_check("L%d a fall reaches the floor in %.2fs (must be under %.2fs)"
			% [level_num, seconds, MAX_FALL_SECONDS],
			_caught and seconds < MAX_FALL_SECONDS)

		scene.queue_free()
		await process_frame

	print("[test_death_plane] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
