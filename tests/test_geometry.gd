extends SceneTree
## Pure-geometry hygiene gate for every level.
##
## This game is built entirely out of rectangles placed by hand in
## level_data.gd, and the existing suites each look at ONE relationship:
## test_all_levels_reachable proves gaps are crossable, test_level_rhythm
## proves steps are within the measured jump envelope, test_hazard_placement
## proves lethal hazards sit below the route. None of them look at whether the
## shapes themselves are sane — so a platform with a negative height, two solid
## bodies fused into each other, or a checkpoint floating in empty space all
## pass the entire gate today.
##
## Every check here is about geometry ALONE: no simulation, no routing. If it
## fails, the level is malformed on paper.
##
## Run with:
##   Godot --headless --path <project> --script res://tests/test_geometry.gd

var _failures: int = 0

## How deeply two solid bodies may interpenetrate before it counts as a real
## overlap. Authored levels butt platforms flush against each other on purpose
## (a wall meeting a floor), and float error can put that a hair either side of
## exact, so touching and near-touching must stay legal.
const OVERLAP_TOLERANCE: float = 2.0

## A checkpoint flag must be standing ON something. This is the largest drop
## from the flag's origin to a platform's top surface that still reads as
## "planted on that platform" rather than "hovering above it".
const CHECKPOINT_GROUND_REACH: float = 96.0

## Pickups and the goal may sit close to a surface but must never be buried
## inside a solid body — a pickup inside a platform is uncollectable and a goal
## inside one is unreachable.
const EMBED_MARGIN: float = 4.0


func _initialize() -> void:
	for level_num in range(1, LevelData.TOTAL_LEVELS + 1):
		_check_level(level_num)
	print("[test_geometry] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _fail(msg: String) -> void:
	print("[FAIL] " + msg)
	_failures += 1


## Platform rects are CENTRE-anchored: platform.gd sizes its RectangleShape2D
## to `size` around `position`, so the body spans position +/- size/2.
func _rect_of(pos: Vector2, size: Vector2) -> Rect2:
	return Rect2(pos - size * 0.5, size)


func _shrink(r: Rect2, by: float) -> Rect2:
	return Rect2(r.position + Vector2(by, by), r.size - Vector2(by, by) * 2.0)


func _check_level(level_num: int) -> void:
	var level := LevelData.get_level(level_num)
	if level == null:
		_fail("L%d: LevelData.get_level returned null" % level_num)
		return

	var rects: Array[Rect2] = []
	var names: Array[String] = []

	# --- 1. No degenerate shapes -------------------------------------------
	for pdef in level.platforms:
		if pdef.size.x <= 0.0 or pdef.size.y <= 0.0:
			_fail("L%d '%s': non-positive size %s — the collider would be\n"
				% [level_num, pdef.name, pdef.size]
				+ "         inverted or zero-area, so it is drawn but not solid.")
			continue
		rects.append(_rect_of(pdef.position, pdef.size))
		names.append(pdef.name)

	# --- 2. Solid bodies must not interpenetrate ---------------------------
	# Two overlapping StaticBody2Ds produce a seam the player can catch on and
	# an edge highlight drawn over solid rock. Flush contact is fine; genuine
	# interpenetration is an authoring mistake.
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a := _shrink(rects[i], OVERLAP_TOLERANCE)
			var b := _shrink(rects[j], OVERLAP_TOLERANCE)
			if a.size.x <= 0.0 or a.size.y <= 0.0 or b.size.x <= 0.0 or b.size.y <= 0.0:
				continue
			if a.intersects(b):
				var o := a.intersection(b)
				_fail("L%d: '%s' and '%s' interpenetrate by %.0fx%.0fpx"
					% [level_num, names[i], names[j], o.size.x, o.size.y])

	# --- 3. Checkpoints must be planted on a platform ----------------------
	for ci in level.checkpoints.size():
		var cpos: Vector2 = level.checkpoints[ci].position
		var grounded := false
		for r in rects:
			var surface := r.position.y  # top edge
			var drop := surface - cpos.y
			if drop >= -EMBED_MARGIN and drop <= CHECKPOINT_GROUND_REACH \
					and cpos.x >= r.position.x and cpos.x <= r.end.x:
				grounded = true
				break
		if not grounded:
			_fail("L%d checkpoint %d at %s: no platform surface within %.0fpx below it"
				% [level_num, ci, cpos, CHECKPOINT_GROUND_REACH])

	# --- 4. Pickups must not be buried in solid geometry -------------------
	for ai in level.abilities.size():
		var apos: Vector2 = level.abilities[ai].position
		for i in rects.size():
			if _shrink(rects[i], EMBED_MARGIN).has_point(apos):
				_fail("L%d ability %d at %s is inside platform '%s' — uncollectable"
					% [level_num, ai, apos, names[i]])

	# --- 5. Spawn and goal must be in open space ---------------------------
	for i in rects.size():
		var solid := _shrink(rects[i], EMBED_MARGIN)
		if solid.has_point(level.spawn_point):
			_fail("L%d: spawn %s is inside platform '%s'"
				% [level_num, level.spawn_point, names[i]])
		if solid.intersects(_rect_of(level.goal_position, level.goal_size)):
			_fail("L%d: goal at %s overlaps platform '%s'"
				% [level_num, level.goal_position, names[i]])

	# --- 6. Nothing may be authored below the kill plane -------------------
	# A platform, pickup or checkpoint under kill_depth is unusable: the player
	# dies on the way to it.
	for i in rects.size():
		if rects[i].position.y > level.kill_depth:
			_fail("L%d: platform '%s' top (%.0f) is below kill_depth (%.0f)"
				% [level_num, names[i], rects[i].position.y, level.kill_depth])
	for ci in level.checkpoints.size():
		if level.checkpoints[ci].position.y > level.kill_depth:
			_fail("L%d: checkpoint %d is below kill_depth" % [level_num, ci])
