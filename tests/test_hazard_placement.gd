extends SceneTree
## Geometric safety gate for lethal hazards (spinning blades, pendulums, lava).
##
## test_all_levels_reachable.gd proves every GAP is crossable, but it drives a
## player through empty space — it never notices a lethal hazard parked in the
## middle of the route. Without this suite, a blade whose swept circle covers
## the only landing spot would ship as a silently impossible level and pass
## every other test.
##
## The invariant enforced here is deliberately conservative: a swinging or
## spinning hazard must sit entirely BELOW the surface line of the platforms
## flanking its gap. That makes it lethal to a missed jump (you fall into it)
## while provably never blocking a clean one, so "hard" can never tip into
## "impossible" as levels get retuned later. Lava is checked for the same
## thing plus non-overlap with any platform body.
##
## Run with:
##   Godot --headless --path <project> --script res://tests/test_hazard_placement.gd

var _failures: int = 0

## Vertical slack (px) a hazard must clear the lowest flanking platform
## surface by, so a player running along that surface is never clipped by a
## hazard that is technically-but-barely underneath it.
const SURFACE_MARGIN: float = 12.0


func _initialize() -> void:
	for level_num in range(1, LevelData.TOTAL_LEVELS + 1):
		_check_level(level_num)
	print("[test_hazard_placement] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


## The y of the LOWEST (largest-y) platform surface horizontally overlapping
## the span x_min..x_max. Returns INF when nothing overlaps, meaning the
## hazard hangs over open space and cannot block a route.
##
## Lowest, not highest, is the load-bearing choice. A player crossing a gap
## leaves from one surface and lands on another, and the jump arc rises above
## BOTH; clearing only the higher of the two still leaves the hazard sitting
## in the arc launched from the lower one. Requiring the hazard to sit below
## every flanking surface is the only bound that holds regardless of which
## direction the gap is crossed in.
func _lowest_surface_over_span(level, x_min: float, x_max: float) -> float:
	var lowest := -INF
	var found := false
	for p in level.platforms:
		var p_left: float = p.position.x - p.size.x * 0.5
		var p_right: float = p.position.x + p.size.x * 0.5
		if p_right < x_min or p_left > x_max:
			continue
		var surface: float = p.position.y - p.size.y * 0.5
		lowest = maxf(lowest, surface)
		found = true
	return lowest if found else INF


## Same bound as above, but for a hazard sitting in a gap it does not
## horizontally overlap: the surfaces that matter are those of the nearest
## platform on each side, which are what the player actually walks and jumps
## from. Returns the lower (larger-y) of the two.
func _nearest_flanking_surface(level, x_min: float, x_max: float) -> float:
	var left_surface := INF
	var left_dist := INF
	var right_surface := INF
	var right_dist := INF
	for p in level.platforms:
		var p_left: float = p.position.x - p.size.x * 0.5
		var p_right: float = p.position.x + p.size.x * 0.5
		var surface: float = p.position.y - p.size.y * 0.5
		if p_right <= x_min:
			var d: float = x_min - p_right
			if d < left_dist:
				left_dist = d
				left_surface = surface
		elif p_left >= x_max:
			var d2: float = p_left - x_max
			if d2 < right_dist:
				right_dist = d2
				right_surface = surface
	if left_surface == INF and right_surface == INF:
		return INF
	if left_surface == INF:
		return right_surface
	if right_surface == INF:
		return left_surface
	return maxf(left_surface, right_surface)


func _check_level(level_num: int) -> void:
	var level = LevelData.get_level(level_num)

	for i in level.spinning_blades.size():
		var b = level.spinning_blades[i]
		# A blade sweeps a full circle of `radius` around its position.
		var top: float = b.position.y - b.radius
		var surface := _lowest_surface_over_span(level,
			b.position.x - b.radius, b.position.x + b.radius)
		if surface == INF:
			continue
		_check("L%d blade %d clears platform surface (blade_top=%.0f surface=%.0f)"
			% [level_num, i, top, surface], top > surface + SURFACE_MARGIN)

	for i in level.pendulums.size():
		var p = level.pendulums[i]
		# The bob rides HIGHEST at the extremes of its arc, where its vertical
		# drop from the pivot shrinks to arm_length * cos(max_angle).
		var highest_bob_y: float = p.position.y + p.arm_length * cos(deg_to_rad(p.max_angle_deg))
		var half_span: float = p.arm_length * sin(deg_to_rad(p.max_angle_deg))
		var surface := _lowest_surface_over_span(level,
			p.position.x - half_span, p.position.x + half_span)
		if surface == INF:
			continue
		_check("L%d pendulum %d clears platform surface (bob_top=%.0f surface=%.0f)"
			% [level_num, i, highest_bob_y, surface], highest_bob_y > surface + SURFACE_MARGIN)

	for i in level.lava_pits.size():
		var l = level.lava_pits[i]
		var l_left: float = l.position.x - l.size.x * 0.5
		var l_right: float = l.position.x + l.size.x * 0.5
		var l_top: float = l.position.y - l.size.y * 0.5
		var l_bottom: float = l.position.y + l.size.y * 0.5
		# Lava must sit in a real gap: never overlapping a platform's body.
		var overlaps_platform := false
		var offender := ""
		for p in level.platforms:
			var p_left: float = p.position.x - p.size.x * 0.5
			var p_right: float = p.position.x + p.size.x * 0.5
			var p_top: float = p.position.y - p.size.y * 0.5
			var p_bottom: float = p.position.y + p.size.y * 0.5
			if l_right <= p_left or l_left >= p_right:
				continue
			if l_bottom <= p_top or l_top >= p_bottom:
				continue
			overlaps_platform = true
			offender = p.name
			break
		_check("L%d lava %d does not overlap any platform (hit=%s)"
			% [level_num, i, offender if overlaps_platform else "none"],
			not overlaps_platform)

		# A lava pit normally sits in a gap it does NOT horizontally overlap,
		# so the span check above skips it. Its lethal sensor still has to
		# clear the surfaces the player actually walks on either side of that
		# gap, or running off the near edge kills before the jump even starts.
		# Check against the nearest platform surface on each side, using the
		# same top-of-sensor geometry lava.gd builds (see its _ready()).
		var sensor_top: float = l.position.y - l.size.y * 0.1
		var flank := _nearest_flanking_surface(level, l_left, l_right)
		if flank == INF:
			continue
		_check("L%d lava %d sensor clears flanking walk surfaces (sensor_top=%.0f surface=%.0f)"
			% [level_num, i, sensor_top, flank], sensor_top > flank + SURFACE_MARGIN)
